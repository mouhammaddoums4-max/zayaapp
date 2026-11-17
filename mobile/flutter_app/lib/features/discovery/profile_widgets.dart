import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';

/// Photo d'un profil : image (URL signée) si disponible, sinon dégradé de marque avec l'initiale.
class ProfilePhotoView extends StatefulWidget {
  const ProfilePhotoView({
    super.key,
    required this.name,
    this.photoPath,
    this.initialSize = 120,
    this.avatar = false,
  });
  final String name;
  final String? photoPath;
  final double initialSize;

  /// Présentation « avatar » : initiale centrée et opaque (au lieu du grand filigrane des cartes).
  final bool avatar;

  @override
  State<ProfilePhotoView> createState() => _ProfilePhotoViewState();
}

class _ProfilePhotoViewState extends State<ProfilePhotoView> {
  Future<String?>? _url;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(ProfilePhotoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoPath != widget.photoPath) _resolve();
  }

  void _resolve() {
    final path = widget.photoPath;
    _url = path == null ? null : Session.read(context).repo.photoUrl(path);
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.name.isEmpty ? '' : widget.name.characters.first.toUpperCase();
    final placeholder = DecoratedBox(
      decoration: const BoxDecoration(gradient: ZColors.brandGradient),
      child: Align(
        alignment: widget.avatar ? Alignment.center : const Alignment(0, -0.3),
        child: Text(initial,
            style: GoogleFonts.sora(
                fontSize: widget.initialSize,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: widget.avatar ? 1 : 0.35))),
      ),
    );
    final future = _url;
    if (future == null) return placeholder;
    return FutureBuilder<String?>(
      future: future,
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null) return placeholder;
        return Stack(fit: StackFit.expand, children: [
          placeholder,
          Image.network(
            url,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) => wasSynchronouslyLoaded
                ? child
                : AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: ZMotion.of(context, ZMotion.medium),
                    child: child,
                  ),
          ),
        ]);
      },
    );
  }
}

/// Avatar rond d'un membre : sa photo publique si elle est accessible, sinon son initiale.
class RemoteAvatar extends StatelessWidget {
  const RemoteAvatar({super.key, required this.name, this.photoPath, this.size = 52});
  final String name;
  final String? photoPath;
  final double size;

  @override
  Widget build(BuildContext context) => ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: ProfilePhotoView(name: name, photoPath: photoPath, initialSize: size * 0.42, avatar: true),
        ),
      );
}

/// Dégradé sombre en bas d'une photo, pour garder le texte lisible.
class PhotoScrim extends StatelessWidget {
  const PhotoScrim({super.key, this.start = 0.4});
  final double start;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [start, 1],
            colors: const [Colors.transparent, Color(0xE6140A18)],
          ),
        ),
      );
}

/// Vignette de profil pour les grilles (Explorer, Likes).
class ProfileTile extends StatelessWidget {
  const ProfileTile({super.key, required this.profile, required this.onTap, this.heroTag});
  final DiscoveryProfile profile;
  final VoidCallback onTap;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    Widget photo = ProfilePhotoView(name: p.displayName, photoPath: p.photoPath, initialSize: 72);
    final tag = heroTag;
    if (tag != null) photo = Hero(tag: tag, child: photo);
    return Semantics(
      button: true,
      label: '${p.displayName}, ${p.age} ans${p.city == null ? '' : ', ${p.city}'}',
      child: PressScale(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(fit: StackFit.expand, children: [
            photo,
            const PhotoScrim(start: 0.45),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Flexible(
                    child: Text('${p.displayName}, ${p.age}',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                  if (p.isVerified) ...[const SizedBox(width: 5), const VerifiedBadge(size: 16)],
                ]),
                if (p.city != null)
                  Text(p.city!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.9))),
              ]),
            ),
            if (p.isPremium) const Positioned(top: 10, left: 10, child: PremiumBadge()),
          ]),
        ),
      ),
    );
  }
}
