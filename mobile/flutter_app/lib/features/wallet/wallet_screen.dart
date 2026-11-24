import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../ads/rewarded_ads.dart';
import '../mystery/mystery_box_screen.dart';
import '../mystery/mystery_box_service.dart';
import '../settings/settings_widgets.dart';

/// Mon portefeuille (régie v1 §8) : crédits publicitaires, pièces achetées et Premium, toujours séparés ; soldes et
/// historique calculés par le serveur (my_wallet).
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, this.service, this.mystery});
  final RewardsService? service;
  final MysteryBoxService? mystery;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late final RewardsService _rewards = widget.service ?? RewardsService.forRepository(Session.read(context).repo);
  late final MysteryBoxService _mystery = widget.mystery ?? MysteryBoxService.forRepository(Session.read(context).repo);
  late Future<Wallet> _wallet = _rewards.wallet();
  MysteryBoxState? _box;

  @override
  void initState() {
    super.initState();
    _loadBox();
  }

  Future<void> _loadBox() async {
    try {
      final st = await _mystery.status();
      if (mounted) setState(() => _box = st);
    } catch (_) {
      // La boîte n'est qu'un raccourci : le portefeuille s'affiche sans elle.
    }
  }

  void _reload() {
    final next = _rewards.wallet();
    setState(() {
      _wallet = next;
    });
    _loadBox();
  }

  Future<void> _openBox() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MysteryBoxScreen(service: _mystery, initial: _box),
    ));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.walletTitle)),
      body: FutureBuilder<Wallet>(
        future: _wallet,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.wifi_off,
              title: s.loadError,
              message: '',
              action: OutlinedButton(onPressed: _reload, child: Text(s.retry)),
            );
          }
          final w = snapshot.data ?? const Wallet();
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child:
                ListView(padding: EdgeInsets.fromLTRB(16, 8, 16, 28 + MediaQuery.paddingOf(context).bottom), children: [
              if (_box?.available ?? false) ...[
                _MysteryTile(onTap: _openBox),
                const SizedBox(height: 12),
              ],
              _Section(
                icon: Icons.ondemand_video,
                title: s.walletAdCredits,
                body: s.walletAdCreditsBody,
                lines: [s.walletSwipes(w.adSwipes), if (w.adBoosts > 0) s.walletBoosts(w.adBoosts)],
              ),
              if (w.hasBonus) ...[
                const SizedBox(height: 12),
                _Section(
                  icon: Icons.card_giftcard,
                  title: s.walletBonus,
                  body: s.walletBonusBody,
                  lines: [
                    if (w.bonusSwipes > 0) s.walletSwipes(w.bonusSwipes),
                    if (w.bonusBoosts > 0) s.walletBoosts(w.bonusBoosts),
                    if (w.bonusPremiumDays > 0) s.walletBonusPremiumDays(w.bonusPremiumDays),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              _Section(
                icon: Icons.toll_outlined,
                title: s.walletCoins,
                body: s.walletCoinsClosed,
                lines: [s.walletCoinsBalance(w.coins)],
              ),
              const SizedBox(height: 12),
              _Section(
                icon: Icons.workspace_premium_outlined,
                title: s.walletPremium,
                lines: [
                  w.premiumActive && w.premiumEndsAt != null
                      ? s.walletPremiumUntil(formatDate(w.premiumEndsAt!))
                      : s.walletPremiumNone,
                ],
              ),
              SettingsSectionTitle(s.walletHistory),
              if (w.history.isEmpty)
                Text(s.walletEmpty, style: Theme.of(context).textTheme.bodyMedium)
              else
                SettingsGroup(children: [
                  for (final e in w.history)
                    ListTile(
                      leading: Icon(
                          switch (e.category) {
                            'coins' => Icons.toll_outlined,
                            'bonus' => Icons.card_giftcard,
                            _ => Icons.ondemand_video,
                          },
                          color: ZColors.primaryDark),
                      title: Text(e.reason),
                      subtitle: Text(formatDate(e.at)),
                      trailing: Text('${e.amount > 0 ? '+' : ''}${e.amount}',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700, color: e.amount > 0 ? ZColors.success : ZColors.danger)),
                    ),
                ]),
            ]),
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.lines, this.body});
  final IconData icon;
  final String title;
  final String? body;
  final List<String> lines;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ZColors.line),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: ZColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              for (final l in lines) ...[
                const SizedBox(height: 4),
                Text(l, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              ],
              if (body != null) ...[
                const SizedBox(height: 6),
                Text(body!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ]),
          ),
        ]),
      );
}

/// Raccourci vers la boîte mystère de bienvenue, tant qu'elle n'est pas ouverte.
class _MysteryTile extends StatelessWidget {
  const _MysteryTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(gradient: ZColors.brandGradient, borderRadius: BorderRadius.circular(20)),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Icon(Icons.card_giftcard, color: Colors.white, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.s.mysteryEntry,
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(context.s.mysteryEntrySubtitle,
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.9))),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ]),
            ),
          ),
        ),
      );
}
