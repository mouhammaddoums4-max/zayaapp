import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import 'profile_widgets.dart';

/// Photos d'un profil en plein écran, telles que le serveur les autorise (migration 0009) : nettes (zoom à deux
/// doigts) ou floutées (version fabriquée par le serveur). Les photos privées ne sont pas affichées.
/// Aucun bouton d'enregistrement : les photos ne sont pas téléchargeables depuis l'application (addendum V6.4 §3.1).
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({super.key, required this.name, required this.photos, this.initialPhotoId, this.onUnlock});
  final String name;
  final List<ProfilePhoto> photos;
  final String? initialPhotoId;

  /// Ouvre l'offre Premium depuis une photo floutée par la règle du forfait.
  final VoidCallback? onUnlock;

  /// Photos visibles (nettes ou floutées), dans l'ordre du profil.
  static List<ProfilePhoto> viewable(List<ProfilePhoto> photos) => [
        for (final p in photos)
          if (!p.isHidden) p,
      ];

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final List<ProfilePhoto> _photos = PhotoViewerScreen.viewable(widget.photos);
  late final PageController _pages = PageController(initialPage: _initialIndex);
  late int _index = _initialIndex;

  int get _initialIndex {
    final i = _photos.indexWhere((p) => p.id == widget.initialPhotoId);
    return i < 0 ? 0 : i;
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: zSystemUiOnBrand, // icônes claires sur le fond noir
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          PageView.builder(
            controller: _pages,
            itemCount: _photos.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => _page(_photos[i]),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'Fermer',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                if (_photos.length > 1)
                  Text('${_index + 1} / ${_photos.length}',
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(width: 16),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _page(ProfilePhoto p) {
    final image = ProfilePhotoView(
      name: widget.name,
      photoPath: p.isBlurred ? p.blurPath : p.path,
      blurred: p.isBlurred,
      initialSize: 160,
      fit: BoxFit.contain,
    );
    if (!p.isBlurred) {
      return Semantics(
        label: 'Photo de ${widget.name}',
        child: InteractiveViewer(minScale: 1, maxScale: 4, child: image),
      );
    }
    final premium = !p.blurredByOwner;
    return Stack(fit: StackFit.expand, children: [
      image,
      Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline, color: Colors.white, size: 40),
            const SizedBox(height: 12),
            Text(
              premium
                  ? 'Cette photo est visible nette avec ZAYA Premium.'
                  : '${widget.name} a choisi de flouter cette photo.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (premium && widget.onUnlock != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: ZColors.premium, foregroundColor: Colors.white),
                onPressed: widget.onUnlock,
                child: const Text('Découvrir Premium'),
              ),
            ],
          ]),
        ),
      ),
    ]);
  }
}
