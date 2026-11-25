import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../profile/profile_menu_widgets.dart' show playStoreUrl;
import 'zaya2_api.dart';

/// Invitation : code personnel aléatoire et révocable, partage volontaire, suivi des invitations.
/// La récompense éventuelle est décidée et versée par le serveur, jamais par l'application.
class InvitationScreen extends StatefulWidget {
  const InvitationScreen({super.key});

  @override
  State<InvitationScreen> createState() => _InvitationScreenState();
}

class _InvitationScreenState extends State<InvitationScreen> {
  late final Zaya2Api _api = Zaya2Api.of(context);
  late Future<(String, ReferralSummary)> _data = _load();
  final _codeInput = TextEditingController();
  bool _busy = false;

  Future<(String, ReferralSummary)> _load() async {
    await _api.registerDevice();
    final code = await _api.referralCode();
    return (code, await _api.referralSummary());
  }

  @override
  void dispose() {
    _codeInput.dispose();
    super.dispose();
  }

  Future<String> _link(String code) async {
    try {
      final config = await _api.repo.publicConfig();
      final base = (config['referral_link_base'] ?? '').toString().trim();
      if (base.isNotEmpty) return '$base?code=$code';
      final invite = (config['invite_url'] ?? '').toString().trim();
      if (invite.isNotEmpty) return invite;
    } catch (_) {
      // Lien par défaut.
    }
    return playStoreUrl;
  }

  Future<void> _share(String code) async {
    final english = tr(context, 'fr', 'en') == 'en';
    final link = await _link(code);
    final text = english
        ? 'I’m inviting you to ZAYA, the serious dating app for marriage. My invitation code: $code\n$link'
        : 'Je t’invite sur ZAYA, l’application de rencontres sérieuses en vue du mariage. '
            'Mon code d’invitation : $code\n$link';
    await SharePlus.instance.share(ShareParams(text: text, subject: 'ZAYA'));
  }

  Future<void> _revoke() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr(context, 'Changer de code ?', 'Change your code?')),
        content: Text(tr(
            context,
            'L’ancien code ne fonctionnera plus. Les invitations déjà enregistrées sont conservées.',
            'The old code will stop working. Invitations already recorded are kept.')),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: Text(tr(context, 'Annuler', 'Cancel'))),
          TextButton(onPressed: () => Navigator.of(d).pop(true), child: Text(tr(context, 'Changer', 'Change'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.revokeReferralCode();
      if (mounted) {
        setState(() {
          _data = _load();
        });
      }
    } catch (e) {
      if (mounted) showZayaSnack(context, friendlyError(e), error: true);
    }
  }

  Future<void> _redeem() async {
    final code = _codeInput.text.trim();
    if (code.length < 8 || _busy) return;
    setState(() => _busy = true);
    try {
      await _api.registerDevice();
      final status = await _api.redeemReferral(code);
      if (!mounted) return;
      _codeInput.clear();
      showZayaSnack(
        context,
        status == 'rejected'
            ? tr(context, 'Ce code ne peut pas être utilisé depuis cet appareil.',
                'This code cannot be used from this device.')
            : tr(context, 'Code enregistré. Merci !', 'Code recorded. Thank you!'),
        error: status == 'rejected',
      );
    } catch (e) {
      if (mounted) showZayaSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(tr(context, 'Inviter un proche', 'Invite someone'))),
        body: FutureBuilder<(String, ReferralSummary)>(
          future: _data,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return ListView(padding: const EdgeInsets.all(16), children: const [Skeleton(height: 200)]);
            }
            if (snap.hasError) {
              return EmptyState(
                icon: Icons.person_add_alt_1_rounded,
                title: tr(context, 'Invitation indisponible', 'Invitation unavailable'),
                message: friendlyError(snap.error!),
                action: FilledButton(
                  onPressed: () => setState(() {
                    _data = _load();
                  }),
                  child: Text(tr(context, 'Réessayer', 'Try again')),
                ),
              );
            }
            final (code, s) = snap.data!;
            return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
              FadeSlideIn(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(gradient: ZColors.brandGradient, borderRadius: BorderRadius.circular(22)),
                  child: Column(children: [
                    Text(tr(context, 'Votre code d’invitation', 'Your invitation code'),
                        style:
                            GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    SelectableText(code,
                        style: GoogleFonts.sora(
                            fontSize: 30, letterSpacing: 3, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white, side: const BorderSide(color: Colors.white, width: 1.5)),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: code));
                            if (context.mounted) showZayaSnack(context, tr(context, 'Code copié', 'Code copied'));
                          },
                          icon: const Icon(Icons.copy_rounded),
                          label: Text(tr(context, 'Copier', 'Copy')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor: Colors.white, foregroundColor: ZColors.primaryDark),
                          onPressed: () => _share(code),
                          icon: const Icon(Icons.share_rounded),
                          label: Text(tr(context, 'Partager', 'Share')),
                        ),
                      ),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(
                index: 1,
                child: Row(children: [
                  _Stat(value: s.invited, label: tr(context, 'invités', 'invited')),
                  const SizedBox(width: 10),
                  _Stat(value: s.pending, label: tr(context, 'en attente', 'pending')),
                  const SizedBox(width: 10),
                  _Stat(value: s.rewarded, label: tr(context, 'validés', 'confirmed')),
                ]),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(
                index: 2,
                child: InfoBanner(
                  icon: Icons.verified_user_outlined,
                  text: s.rewardSwipes > 0
                      ? tr(
                          context,
                          'Une invitation est validée quand votre proche a vérifié son profil et est resté actif ${s.minDays} jours. Vous recevez alors ${s.rewardSwipes} swipes.',
                          'An invitation is confirmed once your contact has verified their profile and stayed active for ${s.minDays} days. You then receive ${s.rewardSwipes} swipes.')
                      : tr(
                          context,
                          'Une invitation est validée quand votre proche a vérifié son profil et est resté actif ${s.minDays} jours. Les récompenses ne sont pas encore ouvertes.',
                          'An invitation is confirmed once your contact has verified their profile and stayed active for ${s.minDays} days. Rewards are not open yet.'),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _revoke,
                  icon: const Icon(Icons.autorenew_rounded),
                  label: Text(tr(context, 'Changer de code', 'Change code')),
                ),
              ),
              const SizedBox(height: 12),
              SectionTitle(tr(context, 'On vous a invité ?', 'Were you invited?')),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _codeInput,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 16,
                    decoration: InputDecoration(
                      hintText: tr(context, 'Code reçu', 'Code received'),
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                  onPressed: _busy ? null : _redeem,
                  child: Text(tr(context, 'Valider', 'Apply')),
                ),
              ]),
            ]);
          },
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ZColors.line),
          ),
          child: Column(children: [
            Text('$value', style: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w700, color: ZColors.ink)),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ]),
        ),
      );
}
