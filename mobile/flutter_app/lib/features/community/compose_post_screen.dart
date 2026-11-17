import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../profile/verification_screen.dart';
import 'community_widgets.dart';

/// Rédaction d'une publication (ou modification si [editing] est fourni).
/// Le texte est contrôlé par le serveur avant publication : un contenu refusé n'est jamais diffusé
/// et reste dans le champ pour être corrigé. Se ferme en renvoyant `true` une fois publié.
class ComposePostScreen extends StatefulWidget {
  const ComposePostScreen({super.key, this.communities = const <Community>[], this.initialCommunityId, this.editing});

  final List<Community> communities;
  final String? initialCommunityId;
  final CommunityPost? editing;

  @override
  State<ComposePostScreen> createState() => _ComposePostScreenState();
}

class _ComposePostScreenState extends State<ComposePostScreen> {
  late final TextEditingController _body = TextEditingController(text: widget.editing?.body ?? '');
  late String? _communityId = widget.editing?.communityId ?? widget.initialCommunityId;
  late String _kind = widget.editing?.kind ?? 'question';
  bool _busy = false;
  String? _blockedCategory;

  /// Erreur affichée au-dessus du bouton (un message en bas d'écran le masquerait).
  String? _error;

  bool get _isEditing => widget.editing != null;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  String get _hint => switch (_kind) {
        'advice' => 'Partagez un conseil qui vous a aidé…',
        'experience' => 'Racontez votre expérience…',
        _ => 'Posez votre question à la communauté…',
      };

  bool get _canSubmit => !_busy && _communityId != null && _body.text.trim().isNotEmpty;

  Future<void> _submit() async {
    final repo = Session.read(context).repo;
    final navigator = Navigator.of(context);
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _blockedCategory = null;
      _error = null;
    });
    try {
      final editing = widget.editing;
      final result = editing == null
          ? await repo.createPost(communityId: _communityId!, kind: _kind, body: _body.text)
          : await repo.editPost(editing.id, _body.text);
      if (!mounted) return;
      if (result.isBlocked) {
        setState(() {
          _busy = false;
          _blockedCategory = result.blockedCategory;
        });
        return;
      }
      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = Session.of(context).me;
    final blocked = _blockedCategory;
    final editing = widget.editing;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.close), tooltip: 'Fermer', onPressed: () => Navigator.of(context).pop()),
        title: Text(_isEditing ? 'Modifier la publication' : 'Nouvelle publication'),
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16), children: [
              if (me != null && !me.isVerified) ...[
                InfoBanner(
                  tone: BannerTone.warning,
                  icon: Icons.verified_outlined,
                  text: 'Pour publier, votre profil doit d’abord être vérifié.',
                  action: TextButton(
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                        foregroundColor: const Color(0xFF5C4100)),
                    onPressed: () => Navigator.of(context).push(zRoute<void>(const VerificationScreen())),
                    child: const Text('Vérifier mon profil  →', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (editing == null)
                ZPickerField<String>(
                  label: 'Choisir une communauté',
                  options: {for (final c in widget.communities) c.id: c.name},
                  value: _communityId,
                  onChanged: (v) => setState(() => _communityId = v),
                )
              else
                Text('Dans « ${editing.communityName} »', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 18),
              Text('Type de publication', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in postKindLabels.entries)
                  ChoiceChip(
                    avatar: Icon(postKindIcon(e.key), size: 18),
                    label: Text(e.value),
                    selected: _kind == e.key,
                    selectedColor: ZColors.primarySoft,
                    onSelected: _isEditing ? null : (_) => setState(() => _kind = e.key),
                  ),
              ]),
              const SizedBox(height: 18),
              TextField(
                controller: _body,
                minLines: 5,
                maxLines: 10,
                maxLength: 2000,
                autofocus: _isEditing,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: blocked != null ? ZColors.danger : ZColors.ink),
                decoration: InputDecoration(hintText: _hint, alignLabelWithHint: true),
                onChanged: (_) => setState(() {
                  _blockedCategory = null;
                  _error = null;
                }),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                InfoBanner(tone: BannerTone.danger, icon: Icons.error_outline, text: _error!),
              ],
              if (blocked != null) ...[
                const SizedBox(height: 4),
                InfoBanner(
                  tone: BannerTone.danger,
                  icon: Icons.error_outline,
                  text: 'Votre publication n’a pas été publiée : la charte ZAYA interdit '
                      '${blockedCategoryLabels[blocked] ?? 'ce type de contenu'}. Modifiez-la avant de la publier.',
                ),
              ],
              const SizedBox(height: 12),
              const InfoBanner(
                icon: Icons.shield_outlined,
                text: 'Restez bienveillant. Pas de coordonnées (numéro, e-mail, lien), pas de demande d’argent, '
                    'pas de recherche de partenaire : les rencontres se font dans Découvrir.',
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: GradientButton(
              label: _isEditing ? 'Enregistrer' : 'Publier',
              icon: _isEditing ? Icons.check : Icons.send,
              busy: _busy,
              onPressed: _canSubmit ? _submit : null,
            ),
          ),
        ]),
      ),
    );
  }
}
