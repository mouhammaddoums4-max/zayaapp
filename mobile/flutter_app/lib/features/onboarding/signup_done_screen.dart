import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../profile/verification_screen.dart';

/// Fin d'inscription (CARTE_ECRANS B12) : le profil n'est proposé qu'après vérification.
/// « Ajouter mes photos » mène aux photos et au selfie (F04) ; « Plus tard » ouvre l'application.
class SignupDoneScreen extends StatelessWidget {
  const SignupDoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      body: SafeArea(
        child: FillOrScroll(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const FadeSlideIn(
              child: Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: ZColors.primarySoft,
                  child: Icon(Icons.verified_user_outlined, size: 44, color: ZColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(s.signupDoneTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text(s.signupDoneBody, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 22),
            for (final tip in s.photoTips)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.check_circle_outline, size: 20, color: ZColors.success),
                  const SizedBox(width: 10),
                  Expanded(child: Text(tip, style: Theme.of(context).textTheme.bodyMedium)),
                ]),
              ),
            const Spacer(),
            const SizedBox(height: 20),
            GradientButton(
              label: s.signupDoneAddPhotos,
              icon: Icons.add_a_photo_outlined,
              onPressed: () => Navigator.of(context).pushReplacement(zRoute<void>(const VerificationScreen())),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(s.signupDoneLater)),
          ]),
        ),
      ),
    );
  }
}
