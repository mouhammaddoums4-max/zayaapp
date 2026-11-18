import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'rewarded_ads.dart';

/// « Regarder une publicité » pour une récompense (régie v1 §3) : affiché seulement si le serveur la propose
/// (AdMob activé, récompense active, limite du jour non atteinte). Récompense annoncée et confirmation demandée avant
/// chaque publicité ; le crédit n'arrive qu'après la vérification de Google côté serveur.
class RewardedAdButton extends StatefulWidget {
  const RewardedAdButton(
      {super.key, required this.reward, required this.onCredited, this.service, this.padding = EdgeInsets.zero});

  /// Code de reward_configurations : extra_swipes | boost_credit.
  final String reward;

  /// Appelé une fois la récompense créditée par le serveur, avec le montant accordé.
  final ValueChanged<int> onCredited;
  final RewardsService? service;

  /// Marge autour du bouton, seulement quand il est affiché.
  final EdgeInsetsGeometry padding;

  @override
  State<RewardedAdButton> createState() => _RewardedAdButtonState();
}

class _RewardedAdButtonState extends State<RewardedAdButton> {
  late final RewardsService _rewards = widget.service ?? RewardsService.forRepository(Session.read(context).repo);
  RewardOffer _offer = const RewardOffer.none();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final offer = await _rewards.offer(widget.reward);
      if (mounted) setState(() => _offer = offer);
    } catch (_) {
      // Sans réponse du serveur, le bouton reste masqué.
    }
  }

  Future<void> _watch() async {
    final s = context.s;
    final lang = LanguageScope.maybeOf(context)?.language.code ?? 'fr';
    final label = _offer.label(lang);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.ondemand_video, color: ZColors.primary, size: 36),
        title: Text(s.rewardedConfirmTitle),
        content: Text(s.rewardedConfirmBody(label, _offer.amount)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(s.cancel)),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(s.rewardedWatch)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final before = _offer.remainingToday;
    try {
      final watched = await _rewards.showRewardedAd(widget.reward);
      if (!watched) {
        messenger.showSnackBar(SnackBar(content: Text(s.rewardedUnavailable), behavior: SnackBarBehavior.floating));
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(s.rewardedPending), behavior: SnackBarBehavior.floating));
      final credited = await _rewards.waitForCredit(widget.reward, remainingBefore: before);
      if (credited) {
        messenger.showSnackBar(
            SnackBar(content: Text(s.rewardedCredited(label, _offer.amount)), behavior: SnackBarBehavior.floating));
        widget.onCredited(_offer.amount);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e)), behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_offer.available) return const SizedBox.shrink();
    final s = context.s;
    final lang = LanguageScope.maybeOf(context)?.language.code ?? 'fr';
    return Padding(
      padding: widget.padding,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        OutlinedButton.icon(
          icon: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.ondemand_video, size: 20),
          label: Text(s.rewardedCta(_offer.label(lang), _offer.amount)),
          onPressed: _busy ? null : _watch,
        ),
        const SizedBox(height: 4),
        Text(s.rewardedRemaining(_offer.remainingToday),
            textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}
