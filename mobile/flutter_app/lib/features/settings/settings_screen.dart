import 'package:in_app_review/in_app_review.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/app_info.dart';
import '../../core/l10n/l10n.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../app/app_update.dart';
import '../auth/pin_screens.dart';
import '../premium/premium_screens.dart';
import '../profile/edit_profile_screen.dart';
import '../profile/privacy_center_screen.dart';
import '../safety/safety_sheets.dart';
import '../security/app_lock_settings_screen.dart';
import '../shop/shop_screen.dart';
import 'help_screen.dart';
import 'language_screen.dart';
import '../wallet/wallet_screen.dart';
import 'legal_screen.dart';
import 'settings_widgets.dart';
import 'support_screens.dart';

/// Numéro affiché au membre lui-même : « +224 620 00 00 01 ». Jamais montré aux autres membres.
String formatOwnPhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('224')) {
    final local = digits.substring(3);
    return '+224 ${local.substring(0, 3)} ${local.substring(3, 5)} ${local.substring(5, 7)} ${local.substring(7)}';
  }
  return digits.isEmpty ? raw : '+$digits';
}

/// Réglages (CARTE_ECRANS F06–F16) : informations personnelles, langue, confidentialité, achats, aide, compte.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _push(BuildContext context, Widget screen) => Navigator.of(context).push(zRoute<void>(screen));

  Future<void> _confirmSignOut(BuildContext context) async {
    final s = context.s;
    final session = Session.read(context);
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.signOutConfirmTitle),
        content: Text(s.signOutConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(s.cancel)),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(s.signOut)),
        ],
      ),
    );
    if (ok != true) return;
    navigator.popUntil((route) => route.isFirst);
    await session.signOut();
  }

  /// Fiche Google Play pour laisser un avis (choix volontaire du membre, sans condition).
  Future<void> _rate(BuildContext context) async {
    final s = context.s;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await InAppReview.instance.openStoreListing();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(s.storeUnavailable), behavior: SnackBarBehavior.floating));
    }
  }

  void _explain(BuildContext context, {required String title, required String body}) {
    final s = context.s;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(body, style: Theme.of(sheetContext).textTheme.bodyLarge),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.support_agent, size: 20),
                label: Text(s.helpWriteSupport),
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _push(context, const SupportRequestScreen(initialCategory: 'account'));
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final session = Session.of(context);
    final me = session.me;
    final language = LanguageScope.maybeOf(context)?.language ?? AppLanguage.fr;
    final phone = session.repo.phoneNumber;
    if (me == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: Text(s.settingsTitle)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 28), children: [
        SettingsSectionTitle(s.settingsPersonalInfo),
        SettingsGroup(children: [
          SettingsTile(
            icon: Icons.badge_outlined,
            title: s.settingsDisplayName,
            subtitle: me.displayName,
            onTap: () => _push(context, const EditProfileScreen()),
          ),
          SettingsTile(
            icon: Icons.cake_outlined,
            title: s.settingsBirthDate,
            subtitle: me.birthDate == null ? '—' : formatDate(me.birthDate!),
            trailing: const Icon(Icons.lock_outline, size: 18, color: ZColors.muted),
            onTap: () => _explain(context, title: s.settingsFixedInfoTitle, body: s.settingsFixedInfoBody),
          ),
          SettingsTile(
            icon: Icons.person_outline,
            title: s.settingsGender,
            subtitle: s.genderLabel(me.gender ?? ''),
            trailing: const Icon(Icons.lock_outline, size: 18, color: ZColors.muted),
            onTap: () => _explain(context, title: s.settingsFixedInfoTitle, body: s.settingsFixedInfoBody),
          ),
          if (phone != null)
            SettingsTile(
              icon: Icons.phone_outlined,
              title: s.settingsPhone,
              subtitle: formatOwnPhone(phone),
              trailing: const Icon(Icons.info_outline, size: 18, color: ZColors.muted),
              onTap: () => _explain(context, title: s.settingsPhoneInfoTitle, body: s.settingsPhoneInfoBody),
            ),
        ]),
        SettingsSectionTitle(s.settingsApp),
        SettingsGroup(children: [
          SettingsTile(
            icon: Icons.translate,
            title: s.settingsLanguage,
            subtitle: language.nativeName,
            onTap: () => _push(context, const LanguageScreen()),
          ),
          SettingsTile(
            icon: Icons.system_update_outlined,
            title: s.settingsUpdates,
            subtitle: session.update.level == UpdateLevel.none
                ? s.settingsUpToDate
                : s.settingsUpdateAvailable(session.update.latest),
            onTap: session.update.level == UpdateLevel.none ? null : () => openAppUpdate(context, session.update.url),
          ),
          SettingsTile(
            icon: Icons.star_outline,
            title: s.settingsRate,
            subtitle: s.settingsRateSubtitle,
            onTap: () => _rate(context),
          ),
        ]),
        SettingsSectionTitle(s.settingsPrivacySection),
        SettingsGroup(children: [
          SettingsTile(
            icon: Icons.lock_outline,
            title: s.settingsPrivacy,
            subtitle: s.settingsPrivacySubtitle,
            onTap: () => _push(context, const PrivacyCenterScreen()),
          ),
          // Code de connexion à 4 chiffres (0071) : le même code sert au verrou de l'application.
          SettingsTile(
            icon: Icons.password_rounded,
            title: 'Code de connexion',
            subtitle: 'Changer votre code à 4 chiffres',
            onTap: () => _push(context, const PinSetupScreen(mode: PinSetupMode.change)),
          ),
          SettingsTile(
            icon: Icons.pin_outlined,
            title: s.lockSettingsTitle,
            subtitle: s.lockSettingsSubtitle,
            onTap: () => _push(context, const AppLockSettingsScreen()),
          ),
          SettingsTile(
            icon: Icons.health_and_safety_outlined,
            title: s.settingsSafetyTips,
            subtitle: s.settingsSafetyTipsSubtitle,
            onTap: () => _push(context, const SafetyTipsScreen()),
          ),
        ]),
        SettingsSectionTitle(s.settingsPurchases),
        SettingsGroup(children: [
          SettingsTile(
            icon: Icons.card_membership_outlined,
            title: s.settingsSubscriptions,
            subtitle: me.isPremium ? s.settingsSubscriptionPremium : s.settingsSubscriptionFree,
            onTap: () => _push(context, const SubscriptionsScreen()),
          ),
          SettingsTile(
            icon: Icons.account_balance_wallet_outlined,
            title: s.walletTitle,
            subtitle: s.walletSubtitle,
            onTap: () => _push(context, const WalletScreen()),
          ),
          SettingsTile(
            icon: Icons.storefront_outlined,
            title: s.shopTitle,
            subtitle: s.shopSubtitle,
            onTap: () => _push(context, const ShopScreen()),
          ),
          SettingsTile(
            icon: Icons.receipt_long_outlined,
            title: s.settingsPayments,
            subtitle: s.settingsPaymentsSubtitle,
            onTap: () => _push(context, const PaymentsScreen()),
          ),
        ]),
        SettingsSectionTitle(s.settingsHelpSection),
        SettingsGroup(children: [
          SettingsTile(
            icon: Icons.help_outline,
            title: s.settingsHelp,
            subtitle: s.settingsHelpSubtitle,
            onTap: () => _push(context, const HelpScreen()),
          ),
          SettingsTile(
            icon: Icons.gavel_outlined,
            title: s.settingsLegal,
            subtitle: s.settingsLegalSubtitle,
            onTap: () => _push(context, const LegalScreen()),
          ),
        ]),
        SettingsSectionTitle(s.settingsAccount),
        SettingsGroup(children: [
          SettingsTile(
            icon: Icons.manage_accounts_outlined,
            title: s.settingsManageAccount,
            subtitle: s.settingsManageAccountSubtitle,
            onTap: () => _push(context, const PrivacyCenterScreen()),
          ),
        ]),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () => _confirmSignOut(context),
          icon: const Icon(Icons.logout, size: 20),
          label: Text(s.signOut),
        ),
        const SizedBox(height: 18),
        Text(s.settingsVersion(appVersionLabel),
            textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        if (session.repo.isDemo) ...[
          const SizedBox(height: 6),
          Text(s.demoModeNotice, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ],
      ]),
    );
  }
}
