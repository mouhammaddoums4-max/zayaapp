import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../ads/rewarded_ads.dart';
import '../settings/settings_widgets.dart';

/// Mon portefeuille (régie v1 §8) : crédits publicitaires, pièces achetées et Premium, toujours séparés ; soldes et
/// historique calculés par le serveur (my_wallet).
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, this.service});
  final RewardsService? service;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late final RewardsService _rewards = widget.service ?? RewardsService.forRepository(Session.read(context).repo);
  late Future<Wallet> _wallet = _rewards.wallet();

  void _reload() {
    final next = _rewards.wallet();
    setState(() {
      _wallet = next;
    });
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
              _Section(
                icon: Icons.ondemand_video,
                title: s.walletAdCredits,
                body: s.walletAdCreditsBody,
                lines: [s.walletSwipes(w.adSwipes), if (w.adBoosts > 0) s.walletBoosts(w.adBoosts)],
              ),
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
                      leading: Icon(e.category == 'coins' ? Icons.toll_outlined : Icons.ondemand_video,
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
