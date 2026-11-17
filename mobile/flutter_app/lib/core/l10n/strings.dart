import 'package:material_ui/material_ui.dart';

import 'l10n.dart';

/// Une question fréquente de l'aide.
class FaqItem {
  const FaqItem(this.question, this.answer);
  final String question;
  final String answer;
}

/// Une rubrique de questions fréquentes.
class FaqSection {
  const FaqSection(this.title, this.items);
  final String title;
  final List<FaqItem> items;
}

/// Tous les textes de l'interface (AGENTS.md : textes centralisés, français puis anglais).
/// Chaque langue implémente cette classe : une traduction manquante empêche la compilation.
abstract class ZStrings {
  const ZStrings();

  /// Textes de la langue choisie par le membre (français si aucune langue n'est fournie).
  static ZStrings of(BuildContext context) => context.s;

  // ── Commun
  String get cancel;
  String get close;
  String get send;
  String get retry;
  String get comingSoon;
  String get loadError;
  String get signOut;
  String get signOutConfirmTitle;
  String get signOutConfirmBody;
  String get demoModeNotice;
  String genderLabel(String gender);

  // ── Réglages
  String get settingsTitle;
  String get settingsEntrySubtitle;
  String get settingsPersonalInfo;
  String get settingsDisplayName;
  String get settingsBirthDate;
  String get settingsGender;
  String get settingsPhone;
  String get settingsFixedInfoTitle;
  String get settingsFixedInfoBody;
  String get settingsPhoneInfoTitle;
  String get settingsPhoneInfoBody;
  String get settingsApp;
  String get settingsLanguage;
  String get settingsPrivacySection;
  String get settingsPrivacy;
  String get settingsPrivacySubtitle;
  String get settingsSafetyTips;
  String get settingsSafetyTipsSubtitle;
  String get settingsPurchases;
  String get settingsSubscriptions;
  String get settingsSubscriptionPremium;
  String get settingsSubscriptionFree;
  String get settingsPayments;
  String get settingsPaymentsSubtitle;
  String get settingsHelpSection;
  String get settingsHelp;
  String get settingsHelpSubtitle;
  String get settingsLegal;
  String get settingsLegalSubtitle;
  String get settingsAccount;
  String get settingsManageAccount;
  String get settingsManageAccountSubtitle;
  String settingsVersion(String version);

  // ── Langue
  String get languageTitle;
  String get languageIntro;
  String languageName(AppLanguage language);
  String get languageComingSoon;
  String get languageInPreparation;
  String get languageChanged;
  String get languageReportTitle;
  String get languageReportButton;

  // ── Aide et assistance
  String get helpTitle;
  String get helpFaqTitle;
  List<FaqSection> get faq;
  String get helpContactTitle;
  String get helpWriteSupport;
  String get helpWriteSupportSubtitle;
  String get helpMyRequests;
  String get helpMyRequestsSubtitle;
  String get helpWhatsapp;
  String get helpWhatsappSubtitle;
  String get helpSafetyTitle;
  String get helpSafetyBody;
  String get helpSafetyButton;
  String get helpEmergency;

  // ── Demandes à l'assistance
  String get supportTitle;
  String get supportCategoryLabel;
  String supportCategory(String category);
  String get supportMessageHint;
  String get supportTranslationHint;
  String get supportSafetyNotice;
  String get supportCodeWarning;
  String get supportSent;
  String get supportRateLimited;
  String get supportMessageTooShort;
  String get myRequestsTitle;
  String get myRequestsEmptyTitle;
  String get myRequestsEmptyBody;
  String supportStatus(String status);
  String get supportReplyLabel;

  // ── Inscription : nationalité et profession (B07, B08)
  String get onbNationalityTitle;
  String get onbNationalitySubtitle;
  String get onbProfessionTitle;
  String get onbProfessionSubtitle;
  String get onbProfessionSearch;
  String get onbProfessionNoResult;
  String get onbProfessionOther;
  String get onbListUnavailable;

  // ── Fin d'inscription et code de connexion
  String get signupDoneTitle;
  String get signupDoneBody;
  List<String> get photoTips;
  String get signupDoneAddPhotos;
  String get signupDoneLater;
  String otpResendIn(int seconds);
  String get otpResend;
  String get otpResent;

  // ── Matchs terminés
  String get endedMatchesTitle;
  String get endedMatchesEntrySubtitle;
  String get endedMatchesExplain;
  String get endedMatchesEmptyTitle;
  String get endedMatchesEmptyBody;
  String endedMatchSubtitle(String date, {required bool byMe});
  String get accountClosed;
  String get endedChatBanner;
  String get endedChatEmpty;

  // ── Documents légaux
  String get legalTitle;
  String legalKind(String kind);
  String legalVersion(String version, String date);
  String get legalDraftNotice;
  String get legalMissing;
  String get legalFrenchOnly;
}
