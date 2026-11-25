import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../discovery/profile_widgets.dart';
import '../zaya2/questions_screen.dart';
import 'edit_profile_screen.dart';
import 'verification_screen.dart';

/// Mon profil, en deux onglets : « Modifier » (mes photos, la complétude, mes informations) et « Aperçu » (ce que
/// les autres membres voient). Je vois toutes mes photos, y compris celles encore en vérification.
class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key, this.initialTab = 1});

  /// 0 = Aperçu, 1 = Modifier.
  final int initialTab;

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  late Future<List<MyPhoto>> _photos = Session.read(context).repo.myPhotos();
  final _picker = ImagePicker();
  bool _busy = false;

  /// Nombre maximal de photos, lu dans les réglages publics (max_profile_photos, 0023).
  int get _max {
    final v = Session.read(context).publicConfigCache['max_profile_photos'];
    return v is num && v > 0 ? v.toInt() : 6;
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final session = Session.read(context);
    setState(() {
      _photos = session.repo.myPhotos();
    });
    await session.refresh();
  }

  Future<void> _add() async {
    if (_busy) return;
    final session = Session.read(context);
    try {
      // Compression sur le téléphone : moins de données à l'envoi.
      final file =
          await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 82);
      if (file == null || !mounted) return;
      setState(() => _busy = true);
      await session.repo.addPhoto(await file.readAsBytes());
      if (!mounted) return;
      showZayaSnack(context, 'Photo ajoutée. Elle est visible tout de suite et sera vérifiée par la modération.');
      await _reload();
    } catch (e) {
      if (mounted) showZayaSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _photoActions(MyPhoto photo, bool isMain, int count) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!isMain)
            ListTile(
              leading: const Icon(Icons.star_outline_rounded),
              title: const Text('Mettre en photo principale'),
              onTap: () => Navigator.of(sheet).pop('main'),
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: ZColors.danger),
            title: const Text('Supprimer cette photo', style: TextStyle(color: ZColors.danger)),
            onTap: () => Navigator.of(sheet).pop('delete'),
          ),
        ]),
      ),
    );
    if (action == null || !mounted) return;
    final repo = Session.read(context).repo;
    if (action == 'delete') {
      final min = Session.read(context).publicConfigCache['min_profile_photos'];
      final minPhotos = min is num ? min.toInt() : 3;
      final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('Supprimer cette photo ?'),
          content: Text(count - 1 < minPhotos
              ? 'Avec moins de $minPhotos photos, votre profil ne sera plus proposé aux autres membres.'
              : 'Elle disparaîtra de votre profil.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Annuler')),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: ZColors.danger),
              onPressed: () => Navigator.of(d).pop(true),
              child: const Text('Supprimer'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      if (action == 'main') {
        await repo.setMainPhoto(photo.id);
      } else {
        await repo.deleteMyPhoto(photo.id);
      }
      await _reload();
    } catch (e) {
      if (mounted) showZayaSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _photoTips() => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Des photos qui inspirent confiance', style: Theme.of(sheet).textTheme.titleMedium),
              const SizedBox(height: 12),
              for (final tip in const [
                'Votre visage bien visible, seul(e), sur la photo principale.',
                'Des photos récentes et naturelles, sans filtre qui vous transforme.',
                'Aucun numéro de téléphone, lien ou adresse sur la photo.',
                'Pas de photo d’une autre personne : elle serait refusée par la modération.',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.check_circle_outline, size: 18, color: ZColors.success),
                    const SizedBox(width: 8),
                    Expanded(child: Text(tip, style: Theme.of(sheet).textTheme.bodyLarge)),
                  ]),
                ),
            ]),
          ),
        ),
      );

  void _push(Widget screen) => Navigator.of(context).push(zRoute<void>(screen)).then((_) {
        if (mounted) _reload();
      });

  @override
  Widget build(BuildContext context) {
    final me = Session.of(context).me;
    if (me == null) return const Scaffold(body: SizedBox.shrink());
    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: Text(me.displayName, overflow: TextOverflow.ellipsis)),
          if (me.isVerified) ...[const SizedBox(width: 6), const VerifiedBadge(size: 20)],
        ]),
        bottom: TabBar(
          controller: _tabs,
          labelColor: ZColors.ink,
          unselectedLabelColor: ZColors.muted,
          indicatorColor: ZColors.ink,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'Aperçu'), Tab(text: 'Modifier')],
        ),
      ),
      body: FutureBuilder<List<MyPhoto>>(
        future: _photos,
        builder: (context, snap) {
          final photos = snap.data ?? const <MyPhoto>[];
          final loading = snap.connectionState != ConnectionState.done;
          return TabBarView(controller: _tabs, children: [
            _Preview(me: me, photos: photos),
            _EditTab(
              me: me,
              photos: photos,
              loading: loading,
              busy: _busy,
              max: _max,
              onAdd: _add,
              onPhoto: (p, i) => _photoActions(p, i == 0, photos.length),
              onTips: _photoTips,
              onInfo: () => _push(const EditProfileScreen()),
              onQuestions: () => _push(const QuestionsScreen()),
              onVerify: () => _push(const VerificationScreen()),
            ),
          ]);
        },
      ),
    );
  }
}

class _EditTab extends StatelessWidget {
  const _EditTab({
    required this.me,
    required this.photos,
    required this.loading,
    required this.busy,
    required this.max,
    required this.onAdd,
    required this.onPhoto,
    required this.onTips,
    required this.onInfo,
    required this.onQuestions,
    required this.onVerify,
  });
  final MyProfile me;
  final List<MyPhoto> photos;
  final bool loading;
  final bool busy;
  final int max;
  final VoidCallback onAdd;
  final void Function(MyPhoto photo, int index) onPhoto;
  final VoidCallback onTips;
  final VoidCallback onInfo;
  final VoidCallback onQuestions;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final percent = (me.completeness * 100).round();
    final slots = photos.length < max ? photos.length + 1 : photos.length;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 32), children: [
      Row(children: [
        Text('Profil complet', style: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w700, color: ZColors.ink)),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(gradient: ZColors.brandGradient, borderRadius: BorderRadius.circular(99)),
          child: Text('$percent %',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ]),
      const SizedBox(height: 16),
      if (loading)
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 3 / 4,
          children: [for (var i = 0; i < 3; i++) const Skeleton(radius: 14)],
        )
      else
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 3 / 4,
          ),
          itemCount: slots + 1,
          itemBuilder: (context, i) {
            if (i < photos.length) {
              return FadeSlideIn(
                index: i,
                child: _PhotoTile(
                  photo: photos[i],
                  name: me.displayName,
                  main: i == 0,
                  onTap: busy ? null : () => onPhoto(photos[i], i),
                ),
              );
            }
            if (i < slots) return _AddTile(busy: busy, onTap: onAdd);
            return _TipsTile(onTap: onTips);
          },
        ),
      const SizedBox(height: 6),
      Text('${photos.length}/$max photos · touchez une photo pour la mettre en avant ou la supprimer',
          style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 18),
      _Row(
        title: 'Mes informations',
        subtitle: 'Présentation, projet de mariage, langues, centres d’intérêt',
        onTap: onInfo,
      ),
      _Row(
        title: 'Mieux se connaître',
        subtitle: 'Vos réponses sur le mariage, visibles par qui vous choisissez',
        onTap: onQuestions,
      ),
      if (!me.isVerified)
        _Row(
          title: 'Vérifier mon profil',
          subtitle: 'Un selfie suffit : le badge bleu rassure les autres membres',
          onTap: onVerify,
        ),
    ]);
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo, required this.name, required this.main, required this.onTap});
  final MyPhoto photo;
  final String name;
  final bool main;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: main ? 'Photo principale' : 'Photo',
        excludeSemantics: true,
        child: PressScale(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(fit: StackFit.expand, children: [
              ProfilePhotoView(name: name, photoPath: photo.path, initialSize: 36),
              if (photo.pending || photo.rejected)
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: photo.rejected ? ZColors.danger : Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(photo.rejected ? 'Refusée' : 'En vérification',
                        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              if (main)
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 5, 12, 5),
                    decoration: const BoxDecoration(
                      color: ZColors.ink,
                      borderRadius: BorderRadius.only(topRight: Radius.circular(12)),
                    ),
                    child: Text('Principale',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
            ]),
          ),
        ),
      );
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Ajouter une photo',
        excludeSemantics: true,
        child: PressScale(
          onTap: busy ? null : onTap,
          child: CustomPaint(
            painter: _DashedBorder(color: ZColors.muted.withValues(alpha: 0.6)),
            child: Center(
              child: busy
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))
                  : const Icon(Icons.add_a_photo_outlined, size: 30, color: ZColors.ink),
            ),
          ),
        ),
      );
}

class _TipsTile extends StatelessWidget {
  const _TipsTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PressScale(
        onTap: onTap,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.info_outline_rounded, size: 28, color: ZColors.ink),
          const SizedBox(height: 8),
          Text('Conseils photo',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: ZColors.ink)),
        ]),
      );
}

/// Cadre en tirets d'un emplacement libre.
class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)).deflate(1));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 7), paint);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.subtitle, required this.onTap});
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: ZColors.primaryDark)),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: ZColors.ink),
            ]),
          ),
        ),
        const Divider(),
      ]);
}

/// Aperçu : mon profil tel que les autres membres le voient (photos à faire défiler, informations publiques).
class _Preview extends StatefulWidget {
  const _Preview({required this.me, required this.photos});
  final MyProfile me;
  final List<MyPhoto> photos;

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    final visible = [
      for (final p in widget.photos)
        if (!p.rejected) p
    ];
    final chips = <(IconData, String)>[
      if (me.horizon != null && horizonLabels[me.horizon] != null) (Icons.favorite_border, horizonLabels[me.horizon]!),
      if (me.maritalStatus != null && maritalLabels[me.maritalStatus] != null)
        (Icons.diamond_outlined, maritalLabels[me.maritalStatus]!),
      for (final l in me.languages) (Icons.translate_rounded, l),
    ];
    return ListView(padding: EdgeInsets.zero, children: [
      SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.62,
        child: Stack(fit: StackFit.expand, children: [
          if (visible.isEmpty)
            ProfilePhotoView(name: me.displayName)
          else
            PageView.builder(
              itemCount: visible.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => ProfilePhotoView(name: me.displayName, photoPath: visible[i].path),
            ),
          const IgnorePointer(child: PhotoScrim(start: 0.5)),
          if (visible.length > 1)
            Positioned(
              left: 12,
              right: 12,
              top: 10,
              child: Row(children: [
                for (var i = 0; i < visible.length; i++)
                  Expanded(
                    child: AnimatedContainer(
                      duration: ZMotion.of(context, ZMotion.fast),
                      height: 3.5,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: i == _page ? 1 : 0.45),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
              ]),
            ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: IgnorePointer(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (me.isVerified)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(99)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.verified, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text('Profil vérifié',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    ]),
                  ),
                Text(me.age == null ? me.displayName : '${me.displayName}, ${me.age}',
                    style: GoogleFonts.sora(fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white)),
                if (me.city != null)
                  Text(me.city!.toUpperCase(),
                      style: GoogleFonts.inter(
                          fontSize: 14, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text('Voici comment les autres membres voient votre profil.',
            style: Theme.of(context).textTheme.bodyMedium),
      ),
      if (chips.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (icon, text) in chips)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFF0F0F3), borderRadius: BorderRadius.circular(99)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 18, color: ZColors.ink),
                  const SizedBox(width: 6),
                  Text(text, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: ZColors.ink)),
                ]),
              ),
          ]),
        ),
      if (me.bio != null && me.bio!.trim().isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('À propos de moi', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(me.bio!, style: Theme.of(context).textTheme.bodyLarge),
          ]),
        ),
      const SizedBox(height: 32),
    ]);
  }
}
