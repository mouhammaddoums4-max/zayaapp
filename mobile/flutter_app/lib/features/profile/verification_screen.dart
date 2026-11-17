import 'package:material_ui/material_ui.dart';
import 'package:image_picker/image_picker.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';

/// Vérification du profil : 3 photos minimum, puis un selfie de contrôle examiné par la modération.
/// Elle est nécessaire pour apparaître dans la découverte (cahier des charges §22.8).
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  static const _minPhotos = 3;
  final _picker = ImagePicker();
  bool _busy = false;
  bool _consent = false;

  Future<void> _addPhoto() async {
    final session = Session.read(context);
    try {
      // Compression côté appareil : limite la consommation de données à l'envoi.
      final file =
          await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 82);
      if (file == null || !mounted) return;
      setState(() => _busy = true);
      await session.repo.addPhoto(await file.readAsBytes());
      await session.refresh();
      if (mounted) showZayaSnack(context, 'Photo ajoutée. Elle sera examinée par la modération.');
    } catch (e) {
      if (mounted) showZayaSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendSelfie() async {
    final session = Session.read(context);
    try {
      final file = await _picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front,
          maxWidth: 1280,
          maxHeight: 1280,
          imageQuality: 85);
      if (file == null || !mounted) return;
      setState(() => _busy = true);
      final status = await session.repo.requestVerification(await file.readAsBytes());
      await session.refresh();
      if (!mounted) return;
      showZayaSnack(
        context,
        switch (status) {
          'not_enough_photos' => 'Ajoutez d’abord $_minPhotos photos de profil.',
          'approved' => 'Profil vérifié (validation simulée en mode démo).',
          _ => 'Demande envoyée. Vous serez prévenu dès qu’elle sera examinée.',
        },
        error: status == 'not_enough_photos',
      );
    } catch (e) {
      if (mounted) showZayaSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = Session.of(context).me;
    if (me == null) return const SizedBox.shrink();
    final photosDone = me.photoCount >= _minPhotos;
    final canRequest = photosDone && !me.isVerified && me.verificationStatus != 'pending';

    return Scaffold(
      appBar: AppBar(title: const Text('Vérification du profil')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
          _statusBanner(me),
          const SizedBox(height: 18),
          _Step(
            number: 1,
            done: photosDone,
            title: 'Ajoutez au moins $_minPhotos photos',
            text:
                'Des photos récentes où votre visage est bien visible. Pas de nudité ni de photo d’une autre personne.',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: (me.photoCount / _minPhotos).clamp(0.0, 1.0).toDouble(),
                  minHeight: 8,
                  backgroundColor: ZColors.line,
                  color: photosDone ? ZColors.success : ZColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text('${me.photoCount} photo${me.photoCount > 1 ? 's' : ''} sur $_minPhotos',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : _addPhoto,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Ajouter une photo'),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          _Step(
            number: 2,
            done: me.isVerified,
            title: 'Prenez un selfie de contrôle',
            text: 'Il est comparé à vos photos de profil par notre équipe de modération. '
                'Il n’apparaît jamais sur votre profil et n’est pas visible des autres membres.',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (canRequest)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _consent,
                  onChanged: (v) => setState(() => _consent = v ?? false),
                  title: const Text(
                    'J’accepte que ZAYA utilise ce selfie uniquement pour vérifier mon profil, '
                    'puis le supprime selon sa politique de conservation.',
                    style: TextStyle(fontSize: 14, height: 1.35),
                  ),
                ),
              const SizedBox(height: 6),
              GradientButton(
                label: me.verificationStatus == 'pending' ? 'Demande en cours d’examen' : 'Prendre le selfie',
                icon: Icons.photo_camera_outlined,
                busy: _busy,
                onPressed: canRequest && _consent ? _sendSelfie : null,
              ),
              if (!photosDone) ...[
                const SizedBox(height: 8),
                Text('Disponible après l’ajout de vos $_minPhotos photos.',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ]),
          ),
          const SizedBox(height: 18),
          Text(
            'Le badge « Profil vérifié » indique uniquement que ce contrôle a été réussi. '
            'Il ne garantit ni l’identité civile complète, ni l’honnêteté, ni les intentions d’une personne. '
            'Si vous passez sous $_minPhotos photos, le badge est retiré et votre profil n’est plus proposé.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ]),
      ),
    );
  }

  Widget _statusBanner(MyProfile me) => switch (me.verificationStatus) {
        'approved' => const InfoBanner(
            tone: BannerTone.success,
            icon: Icons.verified,
            text: 'Votre profil est vérifié et visible dans la découverte.',
          ),
        'pending' => const InfoBanner(
            icon: Icons.hourglass_top,
            text: 'Votre demande est en cours d’examen par notre équipe de modération.',
          ),
        'rejected' => const InfoBanner(
            tone: BannerTone.danger,
            icon: Icons.error_outline,
            text:
                'Votre demande n’a pas pu être validée. Vous pouvez envoyer un nouveau selfie ou demander un réexamen à l’assistance.',
          ),
        'more_info_required' || 'redo' => const InfoBanner(
            tone: BannerTone.warning,
            icon: Icons.refresh,
            text: 'Une nouvelle vérification est nécessaire. Vérifiez vos photos puis reprenez un selfie.',
          ),
        _ => const InfoBanner(
            tone: BannerTone.warning,
            icon: Icons.visibility_off_outlined,
            text:
                'Votre profil n’est pas encore visible des autres membres. Terminez la vérification pour apparaître dans la découverte.',
          ),
      };
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.done, required this.title, required this.text, required this.child});
  final int number;
  final bool done;
  final String title;
  final String text;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ZColors.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: done ? ZColors.success : ZColors.primarySoft, shape: BoxShape.circle),
              child: Center(
                child: done
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : Text('$number', style: const TextStyle(fontWeight: FontWeight.w700, color: ZColors.primaryDark)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          ]),
          const SizedBox(height: 8),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          child,
        ]),
      );
}
