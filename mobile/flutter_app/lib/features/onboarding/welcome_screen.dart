import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'onboarding_flow.dart';
import 'phone_login_screen.dart';

/// Écran d'accueil : fond blanc, la photo de marque, une phrase et deux boutons (demande du propriétaire :
/// peu de texte au démarrage). Les engagements de ZAYA sont expliqués plus loin, dans l'inscription.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDemo = Session.of(context).repo.isDemo;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FillOrScroll(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(children: [
            SizedBox(
              height: 28,
              child: isDemo
                  ? Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: ZColors.primarySoft, borderRadius: BorderRadius.circular(99)),
                        child: Text('Mode démo',
                            style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w600, color: ZColors.primaryDark)),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            // Photo de marque, dans un cadre arrondi : un peu plus de 40 % de la hauteur de l'écran.
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.44,
              child: FadeSlideIn(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset(
                    _photo,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0.1, -0.35),
                    gaplessPlayback: true,
                    excludeFromSemantics: true,
                    frameBuilder: (context, child, frame, synchrone) => synchrone
                        ? child
                        : AnimatedOpacity(
                            opacity: frame == null ? 0 : 1,
                            duration: ZMotion.of(context, ZMotion.medium),
                            child: child,
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const FadeSlideIn(index: 1, child: ZayaLogo(size: 52)),
            const SizedBox(height: 14),
            FadeSlideIn(
              index: 2,
              child: Text('Des rencontres sérieuses,\npour construire à deux',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w700, color: ZColors.ink, height: 1.25)),
            ),
            const Spacer(),
            const SizedBox(height: 20),
            FadeSlideIn(
              index: 3,
              child: Column(children: [
                FilledButton(
                  onPressed: () => Navigator.of(context).push(zRoute<void>(const OnboardingFlow())),
                  child: const Text('Créer mon profil'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(zRoute<void>(const PhoneLoginScreen())),
                  child: const Text('J’ai déjà un compte'),
                ),
                const SizedBox(height: 10),
                Text('Réservé aux personnes de 18 ans et plus.',
                    style: GoogleFonts.inter(fontSize: 12, color: ZColors.muted)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Photo de l'écran d'accueil (assets/brand/demarrage.webp, 1024 × 1536, allégée de 3,3 Mo à 520 Ko).
const _photo = 'assets/brand/demarrage.webp';
