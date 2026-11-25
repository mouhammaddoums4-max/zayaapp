import 'package:material_ui/material_ui.dart';

import 'l10n.dart';

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

  // ── Mises à jour et avis
  String get updateUnavailable;
  String get updateRequiredTitle;
  String updateRequiredBody(String current, String latest);
  String get updateNow;
  String get updateLater;
  String get updateAvailableTitle;
  String updateAvailableBody(String latest);
  String get storeUnavailable;
  String get settingsRate;
  String get settingsRateSubtitle;
  String get settingsUpdates;
  String get settingsUpToDate;
  String settingsUpdateAvailable(String latest);

  // ── Profil (menu)
  String get profileTitle;
  String get profileEdit;
  String get profileShare;
  String get profileIncomplete;
  String get chipSubscription;
  String get chipInvite;
  String get chipHelp;
  String get chipSafety;
  String get planFreeTitle;
  String planFreeSwipes(int count, int hours);
  String get planFreeEssentials;
  String get planDiscoverPremium;
  String get planPremiumTitle;
  String get planPremiumBody;
  String get planMySubscription;
  String get likesLeftTitle;
  String likesRenewAt(String time);
  String get likesMore;
  String get likesUnlimitedPremium;
  String inviteMessage(String url);

  // ── Publicité
  String get adSponsored;
  String get adLearnMore;

  /// Mention des annonces Google (bannières) : distinctes des profils et des publications.
  String get adLabel;

  // ── Portefeuille et publicités récompensées
  String get walletTitle;
  String get walletSubtitle;
  String get walletAdCredits;
  String get walletAdCreditsBody;
  String walletSwipes(int n);
  String walletBoosts(int n);
  String get walletCoins;
  String walletCoinsBalance(int n);
  String get walletCoinsClosed;
  String get walletPremium;
  String walletPremiumUntil(String date);
  String get walletPremiumNone;
  String get walletHistory;
  String get walletEmpty;
  String rewardedCta(String label, int amount);
  String rewardedRemaining(int n);
  String get rewardedConfirmTitle;
  String rewardedConfirmBody(String label, int amount);
  String get rewardedWatch;
  String get rewardedPending;
  String rewardedCredited(String label, int amount);
  String get rewardedUnavailable;

  // ── Boîte mystère de bienvenue
  String get mysteryTitle;
  String get mysterySubtitle;
  String get mysteryChances;
  String mysteryChance(String label, String percent);
  String get mysteryOpen;
  String get mysteryOpening;
  String get mysteryWon;
  String get mysteryCredited;
  String get mysteryAlreadyOpened;
  String get mysteryContinue;
  String get mysteryEntry;
  String get mysteryEntrySubtitle;
  String get walletBonus;
  String get walletBonusBody;
  String walletBonusPremiumDays(int n);

  // ── Verrouillage de l'application (code PIN, empreinte, Face ID)
  String get lockTitle;
  String get lockEnterPin;
  String get lockWrongPin;
  String get lockUseDevice;
  String get lockReason;
  String get lockForgot;
  String get lockForgotBody;
  String get lockForgotConfirm;
  String get lockSettingsTitle;
  String get lockSettingsSubtitle;
  String get lockSwitch;
  String get lockBiometricSwitch;
  String get lockBiometricUnavailable;
  String get lockDelayTitle;
  String get lockChangePin;
  String get lockPrivacyNote;
  String get lockNewPin;
  String get lockConfirmPin;
  String get lockPinMismatch;
  String get lockCurrentPin;
  String get lockEnabled;
  String lockWait(int seconds);
  String lockDelay(int seconds);

  // ── Boutique : cadeaux et compliments (0035)
  String get shopTitle;
  String get shopSubtitle;
  String get shopGifts;
  String get shopCompliments;
  String get shopBuyCoins;
  String get shopNotOnSale;
  String get shopSend;
  String get shopSent;
  String get shopInsufficient;
  String get shopLimit;
  String get shopUnavailable;
  String get shopDisabled;
  String get shopBrowseHint;
  String get shopHistoryTitle;
  String get shopReceived;
  String get shopSentTab;
  String get shopHistoryEmpty;
  String get shopGiveGift;
  String shopPrice(int n);
  String shopSendTo(String name);
  String shopConfirm(String item, String name);
  String shopConfirmBody(int price);
  String shopFrom(String name);
  String shopTo(String name);

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
  String get chatPhotoAction;
  String get chatFileAction;
  String get chatPlusAction;
  String get chatAnimatedStickerAction;
  String get chatAnimatedStickerHint;
  String chatAnimatedStickerName(String stickerId);
  String get chatReplySuggestionsTitle;
  List<String> chatReplySuggestions(String incomingMessage);
  String get chatVoiceAction;
  String get chatAudioCallAction;
  String get chatVideoCallAction;
  String get chatMediaUnavailableTitle;
  String get chatMediaUnavailableBody;
  String get chatCallsInactiveTitle;
  String get chatCallsInactiveBody;

  // ── Documents légaux
  String get legalTitle;
  String legalKind(String kind);
  String legalVersion(String version, String date);
  String get legalDraftNotice;
  String get legalMissing;
  String get legalFrenchOnly;

  // ── Mariage : recherche animée avant l'affichage des profils
  String get radarSearchTitle;
  String get radarSearchSubtitle;

  // ── Niveau d'études et enfants : inscription et filtres Premium (0052)
  String get onbEducationTitle;
  String get onbEducationSubtitle;
  String get onbChildrenTitle;
  String get onbChildrenSubtitle;
  String get childrenNone;
  String childrenCount(int count);
  String get childrenFiveOrMore;
  String get prefsEducation;
  String get prefsChildren;
  String get prefsChildrenAny;
  String prefsChildrenAtMost(int count);
}
