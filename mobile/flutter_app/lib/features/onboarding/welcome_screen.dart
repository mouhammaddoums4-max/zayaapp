import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'onboarding_flow.dart';
import 'phone_login_screen.dart';

/// Écran d'accueil : présentation de ZAYA et de sa promesse.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDemo = Session.of(context).repo.isDemo;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: ZColors.brandGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            child: Column(children: [
              SizedBox(
                height: 28,
                child: isDemo
                    ? Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(99)),
                          child: Text('Mode démo',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                      )
                    : null,
              ),
              const Spacer(),
              const FadeSlideIn(child: ZayaLogo(size: 128)),
              const SizedBox(height: 26),
              FadeSlideIn(
                index: 1,
                child: Text('Des rencontres sérieuses,\npour construire à deux',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sora(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white, height: 1.25)),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                index: 2,
                child: Text(
                  'ZAYA réunit des adultes qui souhaitent une relation sincère pouvant conduire au mariage, '
                  'dans le respect de chacun.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 15, color: Colors.white.withValues(alpha: 0.95), height: 1.45),
                ),
              ),
              const Spacer(),
              const FadeSlideIn(
                index: 3,
                child: Column(children: [
                  _Promise(icon: Icons.verified_user_outlined, text: 'Profils vérifiés avant publication'),
                  _Promise(icon: Icons.favorite_border, text: 'Aucun match sans intérêt réciproque'),
                  _Promise(icon: Icons.lock_outline, text: 'Votre numéro reste toujours privé'),
                ]),
              ),
              const SizedBox(height: 22),
              FadeSlideIn(
                index: 4,
                child: Column(children: [
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: ZColors.primaryDark),
                    onPressed: () => Navigator.of(context).push(zRoute<void>(const OnboardingFlow())),
                    child: const Text('Créer mon profil'),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
                    onPressed: () => Navigator.of(context).push(zRoute<void>(const PhoneLoginScreen())),
                    child: const Text('J’ai déjà un compte'),
                  ),
                  Text('Réservé aux personnes de 18 ans et plus.',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.9))),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Promise extends StatelessWidget {
  const _Promise({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
          ),
        ]),
      );
}
