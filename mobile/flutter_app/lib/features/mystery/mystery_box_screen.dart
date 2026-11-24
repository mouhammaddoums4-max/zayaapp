import 'dart:math' as math;

import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/l10n/l10n.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'mystery_box_service.dart';

/// Boîte mystère de bienvenue (0033). L'écran ne décide rien : le serveur tire le lot, décompte le stock, crédite et
/// garantit une seule ouverture. Les lots et leurs chances réelles sont affichés avant l'ouverture.
class MysteryBoxScreen extends StatefulWidget {
  const MysteryBoxScreen({super.key, this.service, this.initial});
  final MysteryBoxService? service;
  final MysteryBoxState? initial;

  @override
  State<MysteryBoxScreen> createState() => _MysteryBoxScreenState();
}

class _MysteryBoxScreenState extends State<MysteryBoxScreen> with TickerProviderStateMixin {
  late final MysteryBoxService _service = widget.service ?? MysteryBoxService.forRepository(Session.read(context).repo);
  late final AnimationController _float =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  late final AnimationController _burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  MysteryBoxState? _state;
  bool _busy = false;
  bool _openedHere = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _state = widget.initial;
    if (_state == null) _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ZMotion.reduced(context)) {
      _float.stop();
    } else if (!_float.isAnimating) {
      _float.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _float.dispose();
    _shake.dispose();
    _burst.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final st = await _service.status();
      if (mounted) setState(() => _state = st);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _open() async {
    if (_busy) return;
    final reduced = ZMotion.reduced(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Le tirage se fait sur le serveur pendant que la boîte tremble.
      final result = _service.open();
      if (!reduced) await _shake.forward(from: 0);
      final st = await result;
      if (!mounted) return;
      if (!reduced) await _burst.forward(from: 0);
      if (mounted) {
        setState(() {
          _state = st;
          _openedHere = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final lang = LanguageScope.maybeOf(context)?.language.code ?? 'fr';
    final st = _state;
    final prize = st?.opened == true ? st!.prize : null;
    return Scaffold(
      appBar: AppBar(title: Text(s.mysteryEntry)),
      body: st == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 28 + MediaQuery.paddingOf(context).bottom),
              children: [
                Text(s.mysteryTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(s.mysterySubtitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 28),
                SizedBox(
                  height: 230,
                  child: Center(
                    child: prize != null
                        ? _PrizeReveal(prize: prize, lang: lang)
                        : _AnimatedBox(float: _float, shake: _shake, burst: _burst, onTap: _busy ? null : _open),
                  ),
                ),
                const SizedBox(height: 20),
                if (_error != null) ...[
                  InfoBanner(tone: BannerTone.danger, icon: Icons.error_outline, text: _error!),
                  const SizedBox(height: 12),
                ],
                if (prize != null) ...[
                  if (!_openedHere) ...[
                    Text(s.mysteryAlreadyOpened,
                        textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 6),
                  ],
                  Text(s.mysteryCredited, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 18),
                  GradientButton(label: s.mysteryContinue, onPressed: () => Navigator.of(context).pop()),
                ] else if (st != null && st.available) ...[
                  GradientButton(
                    label: _busy ? s.mysteryOpening : s.mysteryOpen,
                    icon: Icons.card_giftcard,
                    busy: _busy,
                    onPressed: _busy ? null : _open,
                  ),
                  const SizedBox(height: 22),
                  Text(s.mysteryChances, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final p in st.prizes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        Icon(_iconFor(p.kind), size: 20, color: ZColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                              s.mysteryChance(p.label(lang), (p.probabilityPercent ?? 0).toStringAsFixed(
                                  (p.probabilityPercent ?? 0) % 1 == 0 ? 0 : 1)),
                              style: Theme.of(context).textTheme.bodyMedium),
                        ),
                      ]),
                    ),
                ],
              ],
            ),
    );
  }
}

IconData _iconFor(String kind) => switch (kind) {
      'premium_days' => Icons.workspace_premium,
      'boost_credit' => Icons.rocket_launch_outlined,
      _ => Icons.style,
    };

/// La boîte : flotte doucement, tremble pendant le tirage, puis s'ouvre en grandissant et en s'effaçant.
class _AnimatedBox extends StatelessWidget {
  const _AnimatedBox({required this.float, required this.shake, required this.burst, required this.onTap});
  final Animation<double> float;
  final Animation<double> shake;
  final Animation<double> burst;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([float, shake, burst]),
        builder: (context, child) {
          final dy = -8 * Curves.easeInOut.transform(float.value);
          final angle = math.sin(shake.value * math.pi * 8) * 0.12 * (1 - shake.value * 0.3);
          final scale = 1 + 0.35 * Curves.easeOut.transform(burst.value);
          final opacity = (1 - burst.value).clamp(0.0, 1.0);
          return Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(0, dy),
              child: Transform.rotate(angle: angle, child: Transform.scale(scale: scale, child: child)),
            ),
          );
        },
        child: Semantics(
          button: onTap != null,
          label: context.s.mysteryOpen,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                gradient: ZColors.brandGradient,
                borderRadius: BorderRadius.circular(36),
                boxShadow: [
                  BoxShadow(color: ZColors.primary.withValues(alpha: 0.35), blurRadius: 28, offset: const Offset(0, 14)),
                ],
              ),
              child: const Icon(Icons.card_giftcard, color: Colors.white, size: 92),
            ),
          ),
        ),
      );
}

/// Le lot obtenu, révélé avec un léger effet d'apparition.
class _PrizeReveal extends StatelessWidget {
  const _PrizeReveal({required this.prize, required this.lang});
  final MysteryPrize prize;
  final String lang;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.6, end: 1),
        duration: ZMotion.of(context, const Duration(milliseconds: 500)),
        curve: Curves.elasticOut,
        builder: (context, v, child) => Transform.scale(scale: v, child: child),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(color: ZColors.primarySoft, shape: BoxShape.circle),
            child: Icon(_iconFor(prize.kind), size: 60, color: ZColors.primary),
          ),
          const SizedBox(height: 14),
          Text(context.s.mysteryWon, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 4),
          Text(prize.label(lang),
              textAlign: TextAlign.center,
              style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w700, color: ZColors.primaryDark)),
        ]),
      );
}
