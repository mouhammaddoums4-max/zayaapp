import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import 'package:just_audio/just_audio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../../core/l10n/l10n.dart';
import '../../core/motion.dart';
import '../../core/phone_mask.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../discovery/profile_detail_screen.dart';
import '../discovery/profile_widgets.dart';
import '../premium/premium_screens.dart';
import '../safety/safety_sheets.dart';

const _infoSeenKey = 'zaya_chat_info_seen';
const _animatedStickerEmojis = <String, String>{
  'heart_bounce': '💖',
  'laugh_shake': '😂',
  'kiss_pulse': '😘',
  'hug_squeeze': '🤗',
  'party_spin': '🎉',
  'prayer_bounce': '🙏',
  'rose_sway': '🌹',
  'fire_flicker': '🔥',
};

/// Messages du plus ancien au plus récent, quel que soit l’ordre de la source (le flux temps réel de Supabase
/// trie par défaut du plus récent au plus ancien) : affichés en liste inversée, le dernier message reste en bas.
List<ChatMessage> chronologique(List<ChatMessage> messages) =>
    [...messages]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

const _joursSemaine = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
const _mois = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// Séparateur de date de la messagerie : « Aujourd’hui », « Hier », le jour de la semaine pendant une semaine,
/// puis la date (avec l’année si elle diffère).
String libelleJour(DateTime jour, {DateTime? maintenant}) {
  final n = maintenant ?? DateTime.now();
  final aujourdhui = DateTime(n.year, n.month, n.day);
  final d = DateTime(jour.year, jour.month, jour.day);
  final ecart = aujourdhui.difference(d).inDays;
  if (ecart == 0) return 'Aujourd’hui';
  if (ecart == 1) return 'Hier';
  if (ecart > 1 && ecart < 7) {
    final nom = _joursSemaine[d.weekday - 1];
    return nom[0].toUpperCase() + nom.substring(1);
  }
  final date = '${d.day == 1 ? '1er' : d.day} ${_mois[d.month - 1]}';
  return d.year == aujourdhui.year ? date : '$date ${d.year}';
}

/// Pictogrammes emoji (smileys, personnes, objets, symboles, drapeaux, tons de peau).
bool _estEmoji(int r) =>
    (r >= 0x1F000 && r <= 0x1FAFF) ||
    (r >= 0x2600 && r <= 0x27BF) ||
    (r >= 0x2300 && r <= 0x23FF) ||
    (r >= 0x2B00 && r <= 0x2BFF) ||
    (r >= 0xE0020 && r <= 0xE007F);

/// Liants d’emoji : jonction (ZWJ), sélecteur de présentation, touche de clavier, espace.
bool _liantEmoji(int r) => r == 0x200D || r == 0xFE0F || r == 0x20E3 || r == 0x20;

/// Message composé uniquement d’emojis (au plus 6 caractères visibles) : affiché en grand, dans sa bulle.
bool queDesEmojis(String texte) {
  final t = texte.trim();
  return t.isNotEmpty &&
      t.characters.length <= 6 &&
      t.runes.any(_estEmoji) &&
      t.runes.every((r) => _estEmoji(r) || _liantEmoji(r));
}

/// Conversation avec un match : filtre avant envoi, numéros masqués, bouclier de sécurité,
/// modification / annulation d'envoi / suppression pour soi.
/// Avec [ended], match terminé (CDC §32) : lecture seule, ni saisie ni accès au profil ; signaler et bloquer restent
/// possibles.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.match, this.ended = false});
  final MatchSummary match;
  final bool ended;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _input = TextEditingController();
  final _focus = FocusNode();
  late final Stream<List<ChatMessage>> _messages = Session.read(context).repo.watchMessages(widget.match.matchId);
  late final Stream<List<MessageReaction>> _reactions = Session.read(context).repo.watchReactions(widget.match.matchId);

  /// Message auquel je réponds (citation affichée au-dessus du champ, envoyée avec le message).
  ChatMessage? _replyingTo;

  /// Premier message non lu à l'ouverture : fixé une seule fois, pour afficher « Messages non lus ».
  String? _firstUnreadId;
  bool _unreadResolved = false;
  final Set<String> _initialIds = <String>{};

  /// Numéros révélés volontairement par le membre (clé = identifiant du message + numéro).
  final Set<String> _revealed = <String>{};
  String? _blockedCategory;
  ChatMessage? _editing;
  bool _sending = false;
  bool _showInfo = false;
  String? _draftKey;
  String? _draftBeforeEdit;
  Timer? _draftSaveTimer;
  bool _draftRestoreStarted = false;
  bool _draftSaved = false;
  bool _composerHasText = false;
  bool _voiceConfigLoaded = false;
  int _voiceMaxSeconds = 60;
  int _voiceMaxBytes = 1048576;
  final _recorder = AudioRecorder();
  Timer? _recordTimer;
  Stopwatch? _recordStopwatch;
  String? _recordingPath;
  bool _recording = false;
  bool _voiceSending = false;
  bool _voiceFinalizing = false;
  int _recordSeconds = 0;
  bool _searchOpen = false;
  String _searchQuery = '';

  /// La personne est en ligne (0070) : point vert et « En ligne » dans l'en-tête, relu régulièrement.
  bool _online = false;
  Timer? _onlineTimer;

  Future<void> _refreshOnline() async {
    if (widget.ended) return;
    try {
      final online = await Session.read(context).repo.onlineMatches();
      final value = online.contains(widget.match.userId);
      if (mounted && value != _online) setState(() => _online = value);
    } catch (_) {
      // Présence indisponible : pas de point vert, rien de bloquant.
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SharedPreferences.getInstance().then((prefs) {
      if (mounted && prefs.getBool(_infoSeenKey) != true) setState(() => _showInfo = true);
    }, onError: (_) {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Présence (0070) : seulement si le serveur la propose.
      if (!Session.read(context).publicConfigCache.containsKey('flowers_enabled')) return;
      unawaited(_refreshOnline());
      _onlineTimer = Timer.periodic(const Duration(seconds: 45), (_) => unawaited(_refreshOnline()));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_draftRestoreStarted) return;
    _draftRestoreStarted = true;
    final userId = Session.read(context).repo.userId ?? 'local';
    _draftKey = 'zaya_chat_draft_${userId}_${widget.match.matchId}';
    unawaited(_restoreDraft());
    if (!_voiceConfigLoaded) {
      _voiceConfigLoaded = true;
      unawaited(_loadVoiceConfig());
    }
  }

  Future<void> _loadVoiceConfig() async {
    try {
      final config = await Session.read(context).repo.publicConfig();
      final seconds = config['voice_message_max_duration_seconds'];
      final bytes = config['voice_message_max_size_bytes'];
      if (mounted && (seconds is num || bytes is num)) {
        setState(() {
          if (seconds is num) _voiceMaxSeconds = seconds.toInt().clamp(1, 60).toInt();
          if (bytes is num) _voiceMaxBytes = bytes.toInt().clamp(1, 1048576).toInt();
        });
      }
    } catch (_) {
      // Les contrôles serveur restent la référence si le réglage public n'est pas disponible.
    }
  }

  Future<void> _startVoiceRecording() async {
    if (_recording || _voiceSending || _sending || _editing != null) return;
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) showZayaSnack(context, 'Autorisez le microphone pour enregistrer une note vocale.', error: true);
        return;
      }
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/zaya_voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 32000, sampleRate: 44100),
        path: path,
      );
      if (!mounted) {
        await _recorder.cancel();
        return;
      }
      _recordingPath = path;
      _recordStopwatch = Stopwatch()..start();
      setState(() {
        _recording = true;
        _recordSeconds = 0;
      });
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        final elapsed = _recordStopwatch?.elapsed.inSeconds ?? 0;
        if (mounted) setState(() => _recordSeconds = elapsed);
        if (elapsed >= _voiceMaxSeconds) unawaited(_stopAndSendVoice());
      });
    } catch (error) {
      if (mounted) showZayaSnack(context, friendlyError(error), error: true);
    }
  }

  Future<void> _cancelVoiceRecording() async {
    if (!_recording || _voiceFinalizing) return;
    _voiceFinalizing = true;
    _recordTimer?.cancel();
    final path = _recordingPath;
    try {
      await _recorder.cancel();
      if (path != null) await _deleteRecordingFile(path);
    } finally {
      _recordStopwatch?.stop();
      if (mounted) setState(() => _recording = false);
      _recordingPath = null;
      _voiceFinalizing = false;
    }
  }

  Future<void> _stopAndSendVoice() async {
    if (!_recording || _voiceFinalizing) return;
    final repo = Session.read(context).repo;
    _voiceFinalizing = true;
    _recordTimer?.cancel();
    final localPath = _recordingPath;
    final duration = (_recordStopwatch?.elapsed.inSeconds ?? _recordSeconds).clamp(1, _voiceMaxSeconds).toInt();
    _recordStopwatch?.stop();
    try {
      final stoppedPath = await _recorder.stop();
      if (!mounted) return;
      setState(() {
        _recording = false;
        _voiceSending = true;
      });
      final path = stoppedPath ?? localPath;
      if (path == null || !await File(path).exists()) throw Exception('Enregistrement indisponible.');
      if (await File(path).length() > _voiceMaxBytes) throw Exception('La note vocale dépasse la taille autorisée.');
      final result = await repo.sendVoiceMessage(widget.match.matchId, path, duration);
      if (!mounted) return;
      if (result.isActiveLimit) await _showActiveLimit(result.activeLimit!);
    } catch (error) {
      if (mounted) showZayaSnack(context, friendlyError(error), error: true);
    } finally {
      final path = localPath;
      if (path != null) await _deleteRecordingFile(path);
      _recordingPath = null;
      _voiceFinalizing = false;
      if (mounted) {
        setState(() {
          _recording = false;
          _voiceSending = false;
        });
      }
    }
  }

  Future<void> _deleteRecordingFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Un fichier temporaire résiduel sera remplacé par le système.
    }
  }

  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draft = prefs.getString(_draftKey!);
      if (!mounted || draft == null || draft.isEmpty || _input.text.isNotEmpty) return;
      _input.value = TextEditingValue(
        text: draft,
        selection: TextSelection.collapsed(offset: draft.length),
      );
      setState(() {
        _draftSaved = true;
        _composerHasText = true;
      });
    } catch (_) {
      // Brouillon local facultatif : un souci de stockage n'empêche pas la conversation.
    }
  }

  void _queueDraftSave(String draft) {
    if (_editing != null || widget.ended || _draftKey == null) return;
    _draftSaveTimer?.cancel();
    if (_draftSaved) setState(() => _draftSaved = false);
    _draftSaveTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(_persistDraft(draft));
    });
  }

  Future<void> _persistDraft(String draft) async {
    final key = _draftKey;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (draft.trim().isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, draft);
      }
      if (mounted && _editing == null && _input.text == draft && _draftSaved != draft.trim().isNotEmpty) {
        setState(() => _draftSaved = draft.trim().isNotEmpty);
      }
    } catch (_) {
      // Le brouillon reste dans le champ si le stockage local est temporairement indisponible.
    }
  }

  Future<void> _openPlusMenu() async {
    if (widget.ended) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.gif_box_outlined, color: ZColors.primary),
            title: Text(sheetContext.s.chatAnimatedStickerAction),
            subtitle: Text(sheetContext.s.chatAnimatedStickerHint),
            onTap: () => Navigator.of(sheetContext).pop('animated'),
          ),
          // Jeux retirés à la demande du propriétaire (fonctionnalité annulée).
        ]),
      ),
    );
    if (!mounted) return;
    if (action == 'animated') await _showAnimatedStickerPicker();
  }

  Future<void> _showAnimatedStickerPicker() async {
    if (_sending || _voiceSending || widget.ended) return;
    final stickerId = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sheetContext.s.chatAnimatedStickerAction, style: Theme.of(sheetContext).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(sheetContext.s.chatAnimatedStickerHint, style: Theme.of(sheetContext).textTheme.bodySmall),
            ]),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (final entry in _animatedStickerEmojis.entries)
                Material(
                  color: ZColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.of(sheetContext).pop(entry.key),
                    child: Semantics(
                      button: true,
                      label: sheetContext.s.chatAnimatedStickerName(entry.key),
                      child: Center(child: _AnimatedSticker(stickerId: entry.key, size: 62)),
                    ),
                  ),
                ),
            ],
          ),
        ]),
      ),
    );
    if (stickerId == null || !mounted || widget.ended) return;
    setState(() => _sending = true);
    try {
      final result = await Session.read(context).repo.sendAnimatedSticker(widget.match.matchId, stickerId);
      if (mounted && result.isActiveLimit) await _showActiveLimit(result.activeLimit!);
    } catch (error) {
      if (mounted) showZayaSnack(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  List<String> _suggestedReplies(List<ChatMessage> messages, String? myId) {
    if (widget.ended || _searchOpen || _composerHasText || _editing != null || messages.isEmpty) return const [];
    final latest = messages.last;
    if (latest.senderId == myId || latest.unsent || latest.kind != 'text' || latest.body.trim().isEmpty) {
      return const [];
    }
    return context.s.chatReplySuggestions(latest.body);
  }

  void _selectReplySuggestion(String suggestion) {
    _input.value = TextEditingValue(
      text: suggestion,
      selection: TextSelection.collapsed(offset: suggestion.length),
    );
    setState(() => _composerHasText = true);
    _queueDraftSave(suggestion);
    _focus.requestFocus();
  }

  Future<void> _showAttachmentsUnavailable() => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.shield_outlined, color: ZColors.primary, size: 34),
          title: Text(dialogContext.s.chatMediaUnavailableTitle),
          content: Text(dialogContext.s.chatMediaUnavailableBody),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(dialogContext.s.close)),
          ],
        ),
      );

  Future<void> _showCallsInactive() => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.call_end_rounded, color: ZColors.muted, size: 34),
          title: Text(dialogContext.s.chatCallsInactiveTitle),
          content: Text(dialogContext.s.chatCallsInactiveBody),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(dialogContext.s.close)),
          ],
        ),
      );

  Widget _composerAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    Color? color,
  }) =>
      IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        onPressed: onPressed,
        icon: Icon(icon, color: color ?? ZColors.muted),
      );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _draftSaveTimer?.cancel();
      if (_editing == null && !widget.ended) unawaited(_persistDraft(_input.text));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _onlineTimer?.cancel();
    _draftSaveTimer?.cancel();
    _recordTimer?.cancel();
    if (_recording) unawaited(_recorder.cancel());
    unawaited(_recorder.dispose());
    if (_editing == null && !widget.ended) unawaited(_persistDraft(_input.text));
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _dismissInfo() async {
    setState(() => _showInfo = false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_infoSeenKey, true);
    } catch (_) {
      // Préférence non enregistrée : l'information sera simplement réaffichée.
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final repo = Session.read(context).repo;
    final editing = _editing;
    setState(() => _sending = true);
    try {
      final result = editing == null
          ? await repo.sendMessage(widget.match.matchId, text, replyToId: _replyingTo?.id)
          : await repo.editMessage(editing.id, text);
      if (!mounted) return;
      if (result.isBlocked) {
        // Le message n'est pas transmis : il reste dans le champ de saisie pour être corrigé.
        setState(() => _blockedCategory = result.blockedCategory);
      } else if (result.isActiveLimit) {
        // Premier message refusé (0040) : le texte reste dans le champ, rien n'est perdu.
        await _showActiveLimit(result.activeLimit!);
      } else {
        final draftAfterEdit = editing == null ? '' : (_draftBeforeEdit ?? '');
        _input.value = TextEditingValue(
          text: draftAfterEdit,
          selection: TextSelection.collapsed(offset: draftAfterEdit.length),
        );
        _draftBeforeEdit = null;
        setState(() {
          _blockedCategory = null;
          _editing = null;
          if (editing == null) _replyingTo = null;
          _composerHasText = draftAfterEdit.trim().isNotEmpty;
        });
        _draftSaveTimer?.cancel();
        unawaited(_persistDraft(draftAfterEdit));
      }
    } catch (e) {
      if (mounted) showZayaSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startEditing(ChatMessage message) {
    _draftSaveTimer?.cancel();
    _draftBeforeEdit = _editing == null ? _input.text : _draftBeforeEdit;
    setState(() {
      _editing = message;
      _blockedCategory = null;
      _composerHasText = true;
    });
    _input.text = message.body;
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
    _focus.requestFocus();
  }

  /// Toutes les places de conversation sont prises : terminer une conversation ou passer à Premium.
  Future<void> _showActiveLimit(int limit) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.forum_outlined, color: ZColors.primary, size: 36),
          title: Text('Vos $limit conversations actives sont ouvertes'),
          content: Text(
            'Pour écrire à ${widget.match.displayName}, terminez d’abord l’une de vos conversations en cours. '
            'Avec ZAYA Premium, vous disposez de plus de conversations actives à la fois.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).push(zRoute<void>(const PremiumScreen()));
              },
              child: const Text('Découvrir Premium'),
            ),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Compris')),
          ],
        ),
      );

  void _cancelEditing() {
    final draft = _draftBeforeEdit ?? '';
    _input.value = TextEditingValue(text: draft, selection: TextSelection.collapsed(offset: draft.length));
    _draftBeforeEdit = null;
    setState(() {
      _editing = null;
      _blockedCategory = null;
      _composerHasText = draft.trim().isNotEmpty;
    });
    unawaited(_persistDraft(draft));
  }

  Future<void> _revealPhone(String key) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.shield_outlined, color: ZColors.primary, size: 36),
        title: const Text('Votre sécurité est notre priorité'),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Text('Avant de poursuivre la conversation en dehors de ZAYA :'),
            const SizedBox(height: 10),
            for (final tip in safetyTips)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(
                      padding: EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 6, color: ZColors.primary)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(tip)),
                ]),
              ),
            Text('ZAYA n’a pas vérifié l’identité de la personne à qui appartient ce numéro.',
                style: Theme.of(dialogContext).textTheme.bodyMedium),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Afficher le numéro')),
        ],
      ),
    );
    if (ok == true && mounted) setState(() => _revealed.add(key));
  }

  void _startReply(ChatMessage message) {
    setState(() {
      _replyingTo = message;
      _editing = null;
    });
    _focus.requestFocus();
  }

  Future<void> _react(ChatMessage message, String emoji) async {
    try {
      await Session.read(context).repo.reactToMessage(message.id, emoji);
    } catch (e) {
      if (mounted) showZayaSnack(context, friendlyError(e), error: true);
    }
  }

  /// Texte d'aperçu d'un message cité ou répondu.
  String _previewOf(ChatMessage m) {
    if (m.unsent) return 'Message retiré';
    if (m.isVoice) return 'Note vocale';
    if (m.isAnimatedSticker) return 'Animation';
    return m.body;
  }

  void _messageActions(ChatMessage message, bool mine) {
    final repo = Session.read(context).repo;
    // Réactions et réponses (0066) : seulement si le serveur les propose (sinon, rien d'inutilisable affiché).
    final canInteract = !message.unsent && !widget.ended && Session.read(context).zaya2Ready;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (canInteract)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                for (final emoji in messageReactionEmojis)
                  InkResponse(
                    radius: 26,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _react(message, emoji);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
              ]),
            ),
          if (canInteract)
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Répondre'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _startReply(message);
              },
            ),
          if (!message.unsent && message.kind == 'text')
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copier'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await Clipboard.setData(ClipboardData(text: message.body));
                if (mounted) showZayaSnack(context, 'Message copié');
              },
            ),
          if (mine && !message.unsent && !widget.ended) ...[
            if (message.kind == 'text')
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Modifier'),
                subtitle: const Text('Le message portera la mention « Modifié ».'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _startEditing(message);
                },
              ),
            ListTile(
              leading: const Icon(Icons.undo),
              title: const Text('Annuler l’envoi'),
              subtitle: const Text('Retiré pour vous deux. La personne peut l’avoir déjà lu.'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                try {
                  await repo.unsendMessage(message.id);
                } catch (e) {
                  if (mounted) showZayaSnack(context, friendlyError(e), error: true);
                }
              },
            ),
          ],
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Supprimer pour moi'),
            subtitle: const Text('Le message reste visible pour l’autre personne.'),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              try {
                await repo.hideMessage(message.id);
              } catch (e) {
                if (mounted) showZayaSnack(context, friendlyError(e), error: true);
              }
            },
          ),
        ]),
      ),
    );
  }

  /// Bouclier de sécurité : conseils, signalement, blocage, fin du match.
  void _openShield() {
    final match = widget.match;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Bouclier de sécurité', style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final tip in safetyTips)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.check_circle_outline, size: 18, color: ZColors.success),
                  const SizedBox(width: 8),
                  Expanded(child: Text(tip, style: Theme.of(sheetContext).textTheme.bodyLarge)),
                ]),
              ),
            const Divider(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_outlined, color: ZColors.danger),
              title: Text('Signaler ${match.displayName}'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showReportSheet(context,
                    userId: match.userId,
                    name: match.displayName,
                    reportContext: 'conversation',
                    matchId: match.matchId);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.block, color: ZColors.danger),
              title: Text('Bloquer ${match.displayName}'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final navigator = Navigator.of(context);
                if (await confirmBlock(context, userId: match.userId, name: match.displayName)) navigator.pop();
              },
            ),
            if (!widget.ended)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.heart_broken_outlined),
                title: const Text('Mettre fin au match'),
                subtitle: const Text('La conversation sera fermée pour vous deux. Ce n’est pas un blocage.'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmUnmatch();
                },
              ),
          ]),
        ),
      ),
    );
  }

  Future<void> _confirmUnmatch() async {
    final match = widget.match;
    final navigator = Navigator.of(context);
    final repo = Session.read(context).repo;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mettre fin au match ?'),
        content: Text('Vous ne pourrez plus échanger de messages avec ${match.displayName}. '
            'Les éléments nécessaires au traitement d’un éventuel signalement sont conservés pour une durée limitée.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Confirmer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await repo.unmatch(match.matchId);
      navigator.pop();
    } catch (e) {
      if (mounted) showZayaSnack(context, friendlyError(e), error: true);
    }
  }

  void _openProfile() {
    final match = widget.match;
    // La conversation reste ouverte derrière : position de lecture et brouillon sont conservés au retour.
    Navigator.of(context).push(zRoute<void>(ProfileDetailScreen(userId: match.userId, name: match.displayName)));
  }

  @override
  Widget build(BuildContext context) {
    final myId = Session.of(context).repo.userId;
    final match = widget.match;
    final blocked = _blockedCategory;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.ended ? null : _openProfile,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Stack(clipBehavior: Clip.none, children: [
                RemoteAvatar(name: match.displayName, photoPath: match.photoPath, size: 38),
                if (_online) const Positioned(right: -1, bottom: -1, child: OnlineDot(size: 13)),
              ]),
              const SizedBox(width: 10),
              Flexible(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(
                      child: Text(match.displayName,
                          overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                    ),
                    if (match.isVerified) ...[const SizedBox(width: 4), const VerifiedBadge(size: 18)],
                  ]),
                  if (_online)
                    Text('En ligne',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: ZColors.success)),
                ]),
              ),
            ]),
          ),
        ),
        actions: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: context.s.chatAudioCallAction,
            icon: const Icon(Icons.call_outlined, color: ZColors.primary),
            onPressed: _showCallsInactive,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: context.s.chatVideoCallAction,
            icon: const Icon(Icons.videocam_outlined, color: ZColors.primary),
            onPressed: _showCallsInactive,
          ),
          IconButton(
            tooltip: _searchOpen ? 'Fermer la recherche' : 'Rechercher dans la conversation',
            icon: Icon(_searchOpen ? Icons.close : Icons.search_rounded),
            onPressed: () {
              setState(() {
                _searchOpen = !_searchOpen;
                if (!_searchOpen) _searchQuery = '';
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.shield_outlined, color: ZColors.primary),
            tooltip: 'Bouclier de sécurité',
            onPressed: _openShield,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          if (_showInfo && !widget.ended)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: InfoBanner(
                text: 'Les messages sont contrôlés avant envoi pour faire respecter la charte ZAYA : '
                    'respect, pas de demande d’argent, pas de contenu sexuel.',
                action: TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
                  onPressed: _dismissInfo,
                  child: const Text('J’ai compris', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          if (_searchOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
              child: TextField(
                autofocus: true,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Rechercher dans les messages',
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Effacer',
                          onPressed: () => setState(() => _searchQuery = ''),
                          icon: const Icon(Icons.clear),
                        ),
                  isDense: true,
                ),
              ),
            ),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _messages,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const EmptyState(
                    icon: Icons.wifi_off,
                    title: 'Connexion interrompue',
                    message: 'Les messages ne peuvent pas être chargés pour le moment.',
                  );
                }
                final recus = snapshot.data;
                if (recus == null) return const Center(child: CircularProgressIndicator());
                final query = _searchQuery.trim().toLowerCase();
                final items = chronologique(recus)
                    .where((message) => query.isEmpty || message.body.toLowerCase().contains(query))
                    .toList();
                if (items.isEmpty && widget.ended) {
                  return EmptyState(icon: Icons.forum_outlined, title: context.s.endedChatEmpty, message: '');
                }
                if (items.isEmpty) {
                  if (query.isNotEmpty) {
                    return const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Aucun résultat',
                      message: 'Essayez un autre mot ou une autre expression.',
                    );
                  }
                  return EmptyState(
                    icon: Icons.waving_hand_outlined,
                    title: 'Dites bonjour à ${match.displayName}',
                    message: 'Un premier message simple et sincère est souvent le meilleur.',
                  );
                }
                if (!_unreadResolved) {
                  _unreadResolved = true;
                  _initialIds.addAll(recus.map((m) => m.id));
                  for (final m in chronologique(recus)) {
                    if (m.senderId != myId && m.readAt == null && !m.unsent) {
                      _firstUnreadId = m.id;
                      break;
                    }
                  }
                }
                final byId = {for (final m in recus) m.id: m};
                final suggestions = _suggestedReplies(chronologique(recus), myId);
                // Séparateur de date avant le premier message de chaque jour (« Aujourd’hui », « Hier »…).
                final lignes = <Object>[];
                DateTime? jourPrecedent;
                for (final m in items) {
                  final local = m.createdAt.toLocal();
                  final jour = DateTime(local.year, local.month, local.day);
                  if (jour != jourPrecedent) lignes.add(jour);
                  jourPrecedent = jour;
                  if (m.id == _firstUnreadId && query.isEmpty) lignes.add(const _NonLus());
                  lignes.add(m);
                }
                return StreamBuilder<List<MessageReaction>>(
                    stream: _reactions,
                    builder: (context, reactionSnapshot) {
                      final reactions = reactionSnapshot.data ?? const <MessageReaction>[];
                      return Column(children: [
                        Expanded(
                          child: ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                            itemCount: lignes.length,
                            itemBuilder: (context, i) {
                              final ligne = lignes[lignes.length - 1 - i];
                              if (ligne is DateTime) return _SeparateurJour(libelle: libelleJour(ligne));
                              if (ligne is _NonLus) return ligne;
                              final message = ligne as ChatMessage;
                              final mine = message.senderId == myId;
                              final cited = message.replyToId == null ? null : byId[message.replyToId];
                              final bubble = _Bubble(
                                message: message,
                                mine: mine,
                                revealed: _revealed,
                                onReveal: _revealPhone,
                                onLongPress: () => _messageActions(message, mine),
                                // Double appui = ❤️, seulement sur une bulle sans élément interactif : sinon le
                                // geste retarderait d'environ 300 ms l'appui sur « Afficher » (numéro) ou sur la
                                // lecture d'une note vocale.
                                onDoubleTap: widget.ended ||
                                        !Session.read(context).zaya2Ready ||
                                        message.unsent ||
                                        message.isVoice ||
                                        splitPhones(message.body).any((s) => s.isPhone)
                                    ? null
                                    : () => _react(message, '❤️'),
                                quote: message.replyToId == null
                                    ? null
                                    : _Quote(
                                        text: cited == null ? 'Message indisponible' : _previewOf(cited),
                                        author: cited == null
                                            ? null
                                            : (cited.senderId == myId ? 'Vous' : match.displayName),
                                      ),
                                reactions: reactions.where((r) => r.messageId == message.id).toList(),
                                myId: myId,
                                onReact: (emoji) => _react(message, emoji),
                              );
                              // Seuls les messages arrivés pendant la conversation s'animent : l'historique, lui, ne rejoue rien en défilant.
                              if (_initialIds.contains(message.id)) {
                                return KeyedSubtree(key: ValueKey<String>(message.id), child: bubble);
                              }
                              return FadeSlideIn(
                                  key: ValueKey<String>(message.id), index: 0, distance: 10, child: bubble);
                            },
                          ),
                        ),
                        if (suggestions.isNotEmpty)
                          _SuggestedReplies(suggestions: suggestions, onSelect: _selectReplySuggestion),
                      ]);
                    });
              },
            ),
          ),
          if (widget.ended)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                InfoBanner(icon: Icons.lock_outline, text: context.s.endedChatBanner),
                const SizedBox(height: 10),
                _RematchBar(matchId: widget.match.matchId, name: widget.match.displayName),
              ]),
            )
          else ...[
            // Les bandeaux au-dessus du champ ont chacun une clé, et le composeur aussi : sans cela, l'apparition
            // du bandeau « Brouillon enregistré » pendant la frappe faisait reconstruire le champ de saisie,
            // qui perdait le focus et fermait le clavier.
            if (_draftSaved && _editing == null && _input.text.isNotEmpty)
              const Padding(
                key: ValueKey<String>('draft-saved'),
                padding: EdgeInsets.fromLTRB(18, 0, 18, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Brouillon enregistré sur cet appareil',
                      style: TextStyle(fontSize: 12, color: ZColors.muted)),
                ),
              ),
            if (blocked != null)
              Padding(
                key: const ValueKey<String>('blocked-banner'),
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: InfoBanner(
                  tone: BannerTone.danger,
                  icon: Icons.error_outline,
                  text: 'Votre message n’a pas été envoyé : la charte ZAYA interdit '
                      '${blockedCategoryLabels[blocked] ?? 'ce type de contenu'}. '
                      'Modifiez votre message avant de l’envoyer.',
                ),
              ),
            if (_replyingTo != null && _editing == null)
              Container(
                key: const ValueKey<String>('reply-banner'),
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                padding: const EdgeInsets.fromLTRB(12, 6, 2, 6),
                decoration: BoxDecoration(
                  color: ZColors.line.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: const Border(left: BorderSide(color: ZColors.primary, width: 3)),
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        _replyingTo!.senderId == myId ? 'Réponse à vous-même' : 'Réponse à ${match.displayName}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: ZColors.primaryDark),
                      ),
                      Text(_previewOf(_replyingTo!),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                    ]),
                  ),
                  IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: 'Annuler la réponse',
                      onPressed: () => setState(() => _replyingTo = null)),
                ]),
              ),
            if (_editing != null)
              Padding(
                key: const ValueKey<String>('editing-banner'),
                padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
                child: Row(children: [
                  const Icon(Icons.edit_outlined, size: 18, color: ZColors.primaryDark),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Modification du message',
                        style: TextStyle(fontWeight: FontWeight.w600, color: ZColors.primaryDark)),
                  ),
                  IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: 'Annuler la modification',
                      onPressed: _cancelEditing),
                ]),
              ),
            if (_recording)
              Padding(
                key: const ValueKey<String>('voice-recorder'),
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Row(children: [
                  IconButton(
                    tooltip: 'Annuler la note vocale',
                    onPressed: _voiceFinalizing ? null : _cancelVoiceRecording,
                    icon: const Icon(Icons.delete_outline, color: ZColors.danger),
                  ),
                  Expanded(
                    child:
                        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.circle, size: 9, color: ZColors.danger),
                        const SizedBox(width: 8),
                        Text('Enregistrement  00:${_recordSeconds.toString().padLeft(2, '0')}'),
                      ]),
                      const SizedBox(height: 5),
                      LinearProgressIndicator(value: _recordSeconds / _voiceMaxSeconds, minHeight: 3),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Envoyer la note vocale',
                    onPressed: _voiceFinalizing ? null : _stopAndSendVoice,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ]),
              )
            else
              Padding(
                key: const ValueKey<String>('composer'),
                padding: const EdgeInsets.fromLTRB(8, 0, 10, 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  // « + » visible seulement quand le champ est vide : il s'efface pendant la saisie.
                  _ComposerExtra(
                    visible: !_composerHasText && _editing == null,
                    child: _composerAction(
                      icon: Icons.add_circle_outline_rounded,
                      tooltip: context.s.chatPlusAction,
                      onPressed: _openPlusMenu,
                      color: ZColors.primary,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      focusNode: _focus,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(color: blocked != null ? ZColors.danger : ZColors.ink),
                      decoration: InputDecoration(
                        hintText: 'Votre message…',
                        counterText: '',
                        // Icône photo : comme le « + », visible seulement tant que rien n'est saisi.
                        prefixIcon: _ComposerExtra(
                          visible: !_composerHasText && _editing == null,
                          hiddenWidth: 14,
                          child: IconButton(
                            tooltip: context.s.chatPhotoAction,
                            onPressed: _showAttachmentsUnavailable,
                            icon: const Icon(Icons.photo_camera_outlined, color: ZColors.primary),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        suffixIcon: _editing == null
                            ? IconButton(
                                tooltip: context.s.chatVoiceAction,
                                onPressed: _sending || _voiceSending ? null : _startVoiceRecording,
                                icon: const Icon(Icons.mic_none_rounded, color: ZColors.primary),
                              )
                            : null,
                        enabledBorder: blocked == null
                            ? null
                            : OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: ZColors.danger, width: 1.5),
                              ),
                        focusedBorder: blocked == null
                            ? null
                            : OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: ZColors.danger, width: 1.5),
                              ),
                      ),
                      onChanged: (text) {
                        final hasText = text.trim().isNotEmpty;
                        if (_blockedCategory != null || _composerHasText != hasText) {
                          setState(() {
                            _blockedCategory = null;
                            _composerHasText = hasText;
                          });
                        }
                        _queueDraftSave(text);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: ZColors.primary,
                      disabledBackgroundColor: ZColors.primary,
                      minimumSize: const Size(52, 52),
                    ),
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(_editing == null ? Icons.send : Icons.check, color: Colors.white),
                    tooltip: _editing == null ? 'Envoyer' : 'Enregistrer la modification',
                    onPressed: _sending || _voiceSending ? null : _send,
                  ),
                ]),
              ),
          ],
        ]),
      ),
    );
  }
}

/// Match terminé : demander à reprendre la conversation, ou répondre à la demande de l’autre (migration 0040).
class _RematchBar extends StatefulWidget {
  const _RematchBar({required this.matchId, required this.name});
  final String matchId;
  final String name;

  @override
  State<_RematchBar> createState() => _RematchBarState();
}

class _RematchBarState extends State<_RematchBar> {
  String? _state; // none | sent | received | accepted | declined
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Session.read(context).repo.rematchState(widget.matchId).then((s) {
      if (mounted) setState(() => _state = s);
    }, onError: (Object _) {
      if (mounted) setState(() => _state = 'none');
    });
  }

  Future<void> _run(Future<String> Function() action) async {
    setState(() => _busy = true);
    try {
      final r = await action();
      if (!mounted) return;
      if (r == 'rematched' || r == 'active') {
        showZayaSnack(context, 'Le match avec ${widget.name} a repris : retrouvez la conversation dans Messages.');
        Navigator.of(context).pop();
        return;
      }
      setState(() => _state = r == 'pending' ? 'sent' : r);
    } catch (e) {
      if (mounted) showZayaSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = Session.of(context).repo;
    final style = Theme.of(context).textTheme.bodyMedium;
    switch (_state) {
      case null:
        return const SizedBox(height: 48);
      case 'sent':
        return Text('Demande envoyée à ${widget.name}. Vous serez à nouveau en contact si elle est acceptée.',
            textAlign: TextAlign.center, style: style);
      case 'declined':
        return Text('La demande pour reprendre la conversation a été refusée.',
            textAlign: TextAlign.center, style: style);
      case 'received':
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${widget.name} souhaite reprendre la conversation.', textAlign: TextAlign.center, style: style),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => _run(() => repo.respondRematch(widget.matchId, accept: false)),
                child: const Text('Refuser'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GradientButton(
                label: 'Accepter',
                busy: _busy,
                onPressed: () => _run(() => repo.respondRematch(widget.matchId, accept: true)),
              ),
            ),
          ]),
        ]);
      default:
        return GradientButton(
          label: 'Demander à re-matcher',
          icon: Icons.favorite_border,
          busy: _busy,
          onPressed: () => _run(() => repo.requestRematch(widget.matchId)),
        );
    }
  }
}

/// Séparateur de date centré entre les messages.
class _SeparateurJour extends StatelessWidget {
  const _SeparateurJour({required this.libelle});
  final String libelle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: ZColors.line, borderRadius: BorderRadius.circular(999)),
            child: Text(libelle,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: ZColors.muted)),
          ),
        ),
      );
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.revealed,
    required this.onReveal,
    required this.onLongPress,
    required this.onReact,
    required this.myId,
    this.onDoubleTap,
    this.quote,
    this.reactions = const <MessageReaction>[],
  });
  final ChatMessage message;
  final bool mine;
  final Set<String> revealed;
  final void Function(String key) onReveal;
  final VoidCallback onLongPress;
  final VoidCallback? onDoubleTap;
  final _Quote? quote;
  final List<MessageReaction> reactions;
  final String? myId;
  final void Function(String emoji) onReact;

  @override
  Widget build(BuildContext context) {
    final foreground = mine ? Colors.white : ZColors.ink;
    final style = GoogleFonts.inter(fontSize: 15, color: foreground, height: 1.4);
    final time = formatTime(message.createdAt);
    final emojiOnly = !message.unsent && (message.isAnimatedSticker || queDesEmojis(message.body));

    Widget content;
    if (message.unsent) {
      content = Text('Message retiré',
          style: style.copyWith(fontStyle: FontStyle.italic, color: foreground.withValues(alpha: 0.7)));
    } else if (message.isVoice) {
      content = _VoiceMessagePlayer(
        message: message,
        mine: mine,
        resolveUrl: () => Session.read(context).repo.voiceMessageUrl(message.mediaPath!),
      );
    } else if (message.isAnimatedSticker) {
      content = _AnimatedSticker(stickerId: message.stickerId!, size: 76);
    } else if (emojiOnly) {
      // Emojis seuls : animés, grands et sans bande d'arrière-plan.
      content = _AnimatedSticker(stickerId: 'emoji', emoji: message.body.trim(), size: 56);
    } else {
      // Chez le destinataire, un numéro de téléphone reste masqué jusqu'à une action volontaire.
      content = Text.rich(TextSpan(style: style, children: [
        for (final segment in splitPhones(message.body))
          if (!segment.isPhone || mine || revealed.contains('${message.id}:${segment.text}'))
            TextSpan(text: segment.text)
          else
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: _MaskedPhone(
                masked: maskPhone(segment.text),
                onTap: () => onReveal('${message.id}:${segment.text}'),
              ),
            ),
      ]));
    }

    final bubble = GestureDetector(
      onLongPress: onLongPress,
      onDoubleTap: onDoubleTap,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: emojiOnly ? EdgeInsets.zero : const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: emojiOnly
            ? null
            : BoxDecoration(
                gradient: mine ? ZColors.brandGradient : null,
                // Bulle de l'autre personne : gris clair sans bordure sur le fond blanc (style messagerie courant).
                color: mine ? null : const Color(0xFFF0F0F3),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(mine ? 18 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 18),
                ),
              ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
          if (quote != null && !message.unsent) _QuoteBlock(quote: quote!, mine: mine, foreground: foreground),
          content,
          if (message.scamCategory != null && !message.unsent) _ScamNotice(category: message.scamCategory!, mine: mine),
          const SizedBox(height: 3),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(message.edited && !message.unsent ? 'Modifié · $time' : time,
                style: GoogleFonts.inter(
                    fontSize: 11, color: emojiOnly ? ZColors.muted : foreground.withValues(alpha: 0.75))),
            if (mine && !message.unsent) ...[
              const SizedBox(width: 4),
              Text(
                message.readAt != null
                    ? 'Lu'
                    : message.deliveredAt != null
                        ? 'Reçu'
                        : 'Envoyé',
                style: GoogleFonts.inter(
                    fontSize: 10, color: emojiOnly ? ZColors.muted : foreground.withValues(alpha: 0.82)),
              ),
              const SizedBox(width: 2),
              Icon(
                message.readAt != null
                    ? Icons.done_all_rounded
                    : message.deliveredAt != null
                        ? Icons.done_all_rounded
                        : Icons.check_rounded,
                size: 14,
                color: emojiOnly ? ZColors.muted : foreground.withValues(alpha: 0.82),
              ),
            ],
          ]),
        ]),
      ),
    );
    final counts = <String, int>{};
    for (final r in reactions) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
    }
    final myEmoji = reactions.where((r) => r.userId == myId).map((r) => r.emoji).firstOrNull;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          bubble,
          if (counts.isNotEmpty && !message.unsent)
            Transform.translate(
              offset: const Offset(0, -6),
              child: Wrap(spacing: 4, children: [
                for (final e in counts.entries)
                  Semantics(
                    button: true,
                    excludeSemantics: true,
                    label: 'Réaction ${e.key}, ${e.value}',
                    child: GestureDetector(
                      onTap: () => onReact(e.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: e.key == myEmoji ? ZColors.primary : ZColors.line),
                        ),
                        child: Text(e.value > 1 ? '${e.key} ${e.value}' : e.key, style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                  ),
              ]),
            ),
        ],
      ),
    );
  }
}

/// Élément facultatif du composeur (« + », photo) : s'efface en douceur pendant la saisie et revient quand le
/// champ est vide. Il garde sa place dans l'arbre des widgets : le champ n'est jamais reconstruit, le clavier
/// reste ouvert.
class _ComposerExtra extends StatelessWidget {
  const _ComposerExtra({required this.visible, required this.child, this.hiddenWidth = 0});
  final bool visible;
  final Widget child;

  /// Largeur gardée quand l'élément est masqué (marge du texte dans le champ).
  final double hiddenWidth;

  @override
  Widget build(BuildContext context) => AnimatedSize(
        duration: ZMotion.of(context, ZMotion.fast),
        curve: ZMotion.emphasized,
        alignment: Alignment.centerLeft,
        child: AnimatedSwitcher(
          duration: ZMotion.of(context, ZMotion.fast),
          transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: a, child: c)),
          child: visible
              ? KeyedSubtree(key: const ValueKey<bool>(true), child: child)
              : SizedBox(key: const ValueKey<bool>(false), width: hiddenWidth, height: 44),
        ),
      );
}

/// Avertissement anti-arnaque sous un message signalé : visible par les deux personnes (migration 0067).
class _ScamNotice extends StatelessWidget {
  const _ScamNotice({required this.category, required this.mine});
  final String category;
  final bool mine;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          color: ZColors.dangerSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.warning_amber_rounded, size: 16, color: ZColors.danger),
          const SizedBox(width: 6),
          Flexible(
            child: Text(scamWarnings[category] ?? scamWarnings['money_request']!,
                style: GoogleFonts.inter(fontSize: 12, height: 1.3, color: ZColors.danger)),
          ),
        ]),
      );
}

/// Aperçu d'un message cité dans une réponse.
class _Quote {
  const _Quote({required this.text, this.author});
  final String text;
  final String? author;
}

class _QuoteBlock extends StatelessWidget {
  const _QuoteBlock({required this.quote, required this.mine, required this.foreground});
  final _Quote quote;
  final bool mine;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        decoration: BoxDecoration(
          color: mine ? Colors.white.withValues(alpha: 0.18) : ZColors.line.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: mine ? Colors.white : ZColors.primary, width: 3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (quote.author != null)
            Text(quote.author!, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: foreground)),
          Text(quote.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 12.5, color: foreground.withValues(alpha: 0.9))),
        ]),
      );
}

/// Repère « Messages non lus » placé avant le premier message non lu à l'ouverture.
class _NonLus extends StatelessWidget {
  const _NonLus();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          const Expanded(child: Divider(color: ZColors.primary)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('Messages non lus',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: ZColors.primaryDark)),
          ),
          const Expanded(child: Divider(color: ZColors.primary)),
        ]),
      );
}

class _AnimatedSticker extends StatefulWidget {
  const _AnimatedSticker({required this.stickerId, required this.size, this.emoji});
  final String stickerId;
  final double size;
  final String? emoji;

  @override
  State<_AnimatedSticker> createState() => _AnimatedStickerState();
}

class _AnimatedStickerState extends State<_AnimatedSticker> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 760),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final phase = _controller.value * math.pi * 2;
          final value = _controller.value;
          final scale = switch (widget.stickerId) {
            'laugh_shake' => 1.0,
            'party_spin' => 0.94 + value * 0.12,
            'rose_sway' => 1,
            'fire_flicker' => 0.92 + value * 0.12,
            _ => 0.9 + value * 0.2,
          };
          final angle = switch (widget.stickerId) {
            'laugh_shake' => math.sin(phase * 2) * 0.07,
            'party_spin' => math.sin(phase) * 0.28,
            'rose_sway' => math.sin(phase) * 0.18,
            'fire_flicker' => math.sin(phase) * 0.04,
            _ => math.sin(phase) * 0.025,
          };
          final x = widget.stickerId == 'laugh_shake' ? math.sin(phase * 2) * 3 : 0.0;
          final y = widget.stickerId == 'party_spin' ? -math.sin(phase) * 5 : 0.0;
          final emoji = widget.emoji ?? _animatedStickerEmojis[widget.stickerId] ?? '✨';
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Center(
              child: Transform.translate(
                offset: Offset(x, y),
                child: Transform.rotate(
                  angle: angle,
                  child: Transform.scale(
                    scale: scale.toDouble(),
                    child: Text(emoji, style: TextStyle(fontSize: widget.size * 0.7, height: 1)),
                  ),
                ),
              ),
            ),
          );
        },
      );
}

class _SuggestedReplies extends StatelessWidget {
  const _SuggestedReplies({required this.suggestions, required this.onSelect});
  final List<String> suggestions;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Icon(Icons.auto_awesome_rounded, size: 15, color: ZColors.primary),
            const SizedBox(width: 6),
            Text(context.s.chatReplySuggestionsTitle,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: ZColors.muted)),
          ]),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final suggestion in suggestions)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(suggestion),
                    onPressed: () => onSelect(suggestion),
                  ),
                ),
            ]),
          ),
        ]),
      );
}

class _VoiceMessagePlayer extends StatefulWidget {
  const _VoiceMessagePlayer({required this.message, required this.mine, required this.resolveUrl});
  final ChatMessage message;
  final bool mine;
  final Future<String?> Function() resolveUrl;

  @override
  State<_VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<_VoiceMessagePlayer> {
  final _player = AudioPlayer();
  bool _loaded = false;
  bool _loading = false;
  String? _error;

  Future<void> _toggle() async {
    if (_player.playing) {
      await _player.pause();
      return;
    }
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!_loaded) {
        final url = await widget.resolveUrl();
        if (url == null) throw Exception('Impossible de charger cette note vocale.');
        await _player.setUrl(url);
        _loaded = true;
      }
      if (_player.processingState == ProcessingState.completed) await _player.seek(Duration.zero);
      unawaited(_player.play());
    } catch (error) {
      _error = friendlyError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foreground = widget.mine ? Colors.white : ZColors.ink;
    final duration = Duration(seconds: widget.message.mediaDurationSeconds ?? 0);
    return SizedBox(
      width: 230,
      child: Row(children: [
        StreamBuilder<PlayerState>(
          stream: _player.playerStateStream,
          builder: (context, snapshot) {
            final playing = snapshot.data?.playing == true;
            return IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 38, height: 38),
              tooltip: playing ? 'Mettre en pause' : 'Écouter la note vocale',
              onPressed: _toggle,
              icon: _loading
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: foreground))
                  : Icon(playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                      color: foreground, size: 32),
            );
          },
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Note vocale', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: foreground)),
            const SizedBox(height: 5),
            StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, snapshot) {
                final totalMs = (_player.duration ?? duration).inMilliseconds;
                final positionMs = snapshot.data?.inMilliseconds ?? 0;
                final progress = totalMs <= 0 ? 0.0 : (positionMs / totalMs).clamp(0.0, 1.0).toDouble();
                return LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  color: foreground,
                  backgroundColor: foreground.withValues(alpha: 0.25),
                );
              },
            ),
            const SizedBox(height: 4),
            if (_error != null)
              Text(_error!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 10, color: foreground))
            else
              Text(
                  '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
                  style: GoogleFonts.inter(fontSize: 10, color: foreground.withValues(alpha: 0.8))),
          ]),
        ),
      ]),
    );
  }
}

class _MaskedPhone extends StatelessWidget {
  const _MaskedPhone({required this.masked, required this.onTap});
  final String masked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Numéro de téléphone masqué. Appuyez pour l’afficher.',
        excludeSemantics: true,
        onTap: onTap,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(color: ZColors.primarySoft, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.visibility_off_outlined, size: 14, color: ZColors.primaryDark),
              const SizedBox(width: 5),
              Text('$masked · Afficher',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: ZColors.primaryDark)),
            ]),
          ),
        ),
      );
}
