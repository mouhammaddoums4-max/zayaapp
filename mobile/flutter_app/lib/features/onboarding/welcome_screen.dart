import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'onboarding_flow.dart';
import 'phone_login_screen.dart';

/// Écran d'accueil : photo de marque en plein écran (demande du propriétaire, 25/11/2026), voilée en haut pour la
/// barre d'état et en bas pour la lecture ; logo, une phrase et deux boutons par-dessus (peu de texte au démarrage).
/// Les engagements de ZAYA sont expliqués plus loin, dans l'inscription.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDemo = Session.of(context).repo.isDemo;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Icônes de la barre d'état en blanc sur la photo.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(fit: StackFit.expand, children: [
          Image.asset(
            _photo,
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
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.16, 0.42, 0.72, 1],
                  colors: [Color(0x73000000), Color(0x00000000), Color(0x00000000), Color(0xB3000000), Color(0xEB000000)],
                ),
              ),
            ),
          ),
          SafeArea(
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
                            decoration:
                                BoxDecoration(color: ZColors.primarySoft, borderRadius: BorderRadius.circular(99)),
                            child: Text('Mode démo',
                                style: GoogleFonts.inter(
                                    fontSize: 12, fontWeight: FontWeight.w600, color: ZColors.primaryDark)),
                          ),
                        )
                      : null,
                ),
                const Spacer(),
                const FadeSlideIn(index: 1, child: ZayaLogo(size: 56)),
                const SizedBox(height: 14),
                FadeSlideIn(
                  index: 2,
                  child: Text('Des rencontres sérieuses,\npour construire à deux',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.sora(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.25,
                        shadows: const [Shadow(color: Color(0x66000000), blurRadius: 12)],
                      )),
                ),
                const SizedBox(height: 26),
                FadeSlideIn(
                  index: 3,
                  child: Column(children: [
                    FilledButton(
                      onPressed: () => Navigator.of(context).push(zRoute<void>(const OnboardingFlow())),
                      child: const Text('Créer mon profil'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.black.withValues(alpha: 0.18),
                        side: const BorderSide(color: Colors.white, width: 1.4),
                      ),
                      onPressed: () => Navigator.of(context).push(zRoute<void>(const PhoneLoginScreen())),
                      child: const Text('J’ai déjà un compte'),
                    ),
                    const SizedBox(height: 12),
                    Text('Réservé aux personnes de 18 ans et plus.',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
                  ]),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Photo de l'écran d'accueil (assets/brand/demarrage.webp, 1024 × 1536, allégée de 3,3 Mo à 520 Ko).
const _photo = 'assets/brand/demarrage.webp';
