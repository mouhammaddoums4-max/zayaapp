import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
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
import '../safety/safety_sheets.dart';

const _infoSeenKey = 'zaya_chat_info_seen';

/// Messages du plus ancien au plus récent, quel que soit l’ordre de la source (le flux temps réel de Supabase
/// trie par défaut du plus récent au plus ancien) : affichés en liste inversée, le dernier message reste en bas.
List<ChatMessage> chronologique(List<ChatMessage> messages) =>
    [...messages]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

const _joursSemaine = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
const _mois = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
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

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  late final Stream<List<ChatMessage>> _messages = Session.read(context).repo.watchMessages(widget.match.matchId);

  /// Numéros révélés volontairement par le membre (clé = identifiant du message + numéro).
  final Set<String> _revealed = <String>{};
  String? _blockedCategory;
  ChatMessage? _editing;
  bool _sending = false;
  bool _showInfo = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted && prefs.getBool(_infoSeenKey) != true) setState(() => _showInfo = true);
    }, onError: (_) {});
  }

  @override
  void dispose() {
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
          ? await repo.sendMessage(widget.match.matchId, text)
          : await repo.editMessage(editing.id, text);
      if (!mounted) return;
      if (result.isBlocked) {
        // Le message n'est pas transmis : il reste dans le champ de saisie pour être corrigé.
        setState(() => _blockedCategory = result.blockedCategory);
      } else {
        _input.clear();
        setState(() {
          _blockedCategory = null;
          _editing = null;
        });
      }
    } catch (e) {
      if (mounted) showZayaSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startEditing(ChatMessage message) {
    setState(() {
      _editing = message;
      _blockedCategory = null;
    });
    _input.text = message.body;
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
    _focus.requestFocus();
  }

  void _cancelEditing() {
    _input.clear();
    setState(() {
      _editing = null;
      _blockedCategory = null;
    });
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

  void _messageActions(ChatMessage message, bool mine) {
    final repo = Session.read(context).repo;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (mine && !message.unsent && !widget.ended) ...[
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
              RemoteAvatar(name: match.displayName, photoPath: match.photoPath, size: 38),
              const SizedBox(width: 10),
              Flexible(
                child: Text(match.displayName,
                    overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
              ),
              if (match.isVerified) ...[const SizedBox(width: 4), const VerifiedBadge(size: 18)],
            ]),
          ),
        ),
        actions: [
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
                final items = chronologique(recus);
                if (items.isEmpty && widget.ended) {
                  return EmptyState(icon: Icons.forum_outlined, title: context.s.endedChatEmpty, message: '');
                }
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.waving_hand_outlined,
                    title: 'Dites bonjour à ${match.displayName}',
                    message: 'Un premier message simple et sincère est souvent le meilleur.',
                  );
                }
                // Séparateur de date avant le premier message de chaque jour (« Aujourd’hui », « Hier »…).
                final lignes = <Object>[];
                DateTime? jourPrecedent;
                for (final m in items) {
                  final local = m.createdAt.toLocal();
                  final jour = DateTime(local.year, local.month, local.day);
                  if (jour != jourPrecedent) lignes.add(jour);
                  jourPrecedent = jour;
                  lignes.add(m);
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  itemCount: lignes.length,
                  itemBuilder: (context, i) {
                    final ligne = lignes[lignes.length - 1 - i];
                    if (ligne is DateTime) return _SeparateurJour(libelle: libelleJour(ligne));
                    final message = ligne as ChatMessage;
                    final mine = message.senderId == myId;
                    return FadeSlideIn(
                      key: ValueKey<String>(message.id),
                      index: i,
                      distance: 10,
                      child: _Bubble(
                        message: message,
                        mine: mine,
                        revealed: _revealed,
                        onReveal: _revealPhone,
                        onLongPress: () => _messageActions(message, mine),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (widget.ended)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: InfoBanner(icon: Icons.lock_outline, text: context.s.endedChatBanner),
            )
          else ...[
            if (blocked != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: InfoBanner(
                  tone: BannerTone.danger,
                  icon: Icons.error_outline,
                  text: 'Votre message n’a pas été envoyé : la charte ZAYA interdit '
                      '${blockedCategoryLabels[blocked] ?? 'ce type de contenu'}. '
                      'Modifiez votre message avant de l’envoyer.',
                ),
              ),
            if (_editing != null)
              Padding(
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
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
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
                    onChanged: (_) {
                      if (_blockedCategory != null) setState(() => _blockedCategory = null);
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
                  onPressed: _sending ? null : _send,
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
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
  });
  final ChatMessage message;
  final bool mine;
  final Set<String> revealed;
  final void Function(String key) onReveal;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final foreground = mine ? Colors.white : ZColors.ink;
    final style = GoogleFonts.inter(fontSize: 15, color: foreground, height: 1.4);
    final time = formatTime(message.createdAt);

    Widget content;
    if (message.unsent) {
      content = Text('Message retiré',
          style: style.copyWith(fontStyle: FontStyle.italic, color: foreground.withValues(alpha: 0.7)));
    } else if (queDesEmojis(message.body)) {
      // Emojis seuls : en grand, toujours dans la bulle.
      content = Text(message.body.trim(), style: style.copyWith(fontSize: 34, height: 1.2));
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

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            gradient: mine ? ZColors.brandGradient : null,
            color: mine ? null : Colors.white,
            border: mine ? null : Border.all(color: ZColors.line),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 4),
              bottomRight: Radius.circular(mine ? 4 : 18),
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            content,
            const SizedBox(height: 3),
            Text(message.edited && !message.unsent ? 'Modifié · $time' : time,
                style: GoogleFonts.inter(fontSize: 11, color: foreground.withValues(alpha: 0.75))),
          ]),
        ),
      ),
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
