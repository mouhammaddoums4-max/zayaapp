import 'l10n.dart';

/// English texts. Offered to members only once every screen is translated (see `englishInterfaceComplete`).
class ZStringsEn extends ZStrings {
  const ZStringsEn();

  // ── Common
  @override
  String get cancel => 'Cancel';
  @override
  String get close => 'Close';
  @override
  String get send => 'Send';
  @override
  String get retry => 'Try again';
  @override
  String get comingSoon => 'Coming soon';
  @override
  String get loadError => 'Unable to load. Check your connection.';
  @override
  String get signOut => 'Sign out';
  @override
  String get signOutConfirmTitle => 'Sign out?';
  @override
  String get signOutConfirmBody => 'You can sign in again at any time with your phone number.';
  @override
  String get demoModeNotice => 'Demo mode — sample data, nothing is saved.';
  @override
  String genderLabel(String gender) => switch (gender) {
        'femme' => 'Woman',
        'homme' => 'Man',
        _ => 'Not specified',
      };

  // ── Settings
  @override
  String get settingsTitle => 'Settings';
  @override
  String get settingsEntrySubtitle => 'Account, privacy, language, help';
  @override
  String get settingsPersonalInfo => 'Personal information';
  @override
  String get settingsDisplayName => 'Display name';
  @override
  String get settingsBirthDate => 'Date of birth';
  @override
  String get settingsGender => 'Gender';
  @override
  String get settingsPhone => 'Phone number';
  @override
  String get settingsFixedInfoTitle => 'This cannot be changed';
  @override
  String get settingsFixedInfoBody => 'Your date of birth and gender are set when you sign up, to protect members '
      'from fake profiles. If there is a mistake, write to support.';
  @override
  String get settingsPhoneInfoTitle => 'Your phone number';
  @override
  String get settingsPhoneInfoBody => 'It is only used to sign you in and secure your account. It never appears on '
      'your profile. To change it, write to support.';
  @override
  String get settingsApp => 'App';
  @override
  String get settingsLanguage => 'Language';
  @override
  String get settingsPrivacySection => 'Privacy';
  @override
  String get settingsPrivacy => 'Privacy and safety';
  @override
  String get settingsPrivacySubtitle => 'Visibility, blocked people, my data';
  @override
  String get settingsSafetyTips => 'Safety tips';
  @override
  String get settingsSafetyTipsSubtitle => 'Meeting up, scams, reporting';
  @override
  String get settingsPurchases => 'Purchases';
  @override
  String get settingsSubscriptions => 'My subscriptions';
  @override
  String get settingsSubscriptionPremium => 'Premium';
  @override
  String get settingsSubscriptionFree => 'Free plan';
  @override
  String get settingsPayments => 'My payments';
  @override
  String get settingsPaymentsSubtitle => 'History and receipts';
  @override
  String get settingsHelpSection => 'Help';
  @override
  String get settingsHelp => 'Help and support';
  @override
  String get settingsHelpSubtitle => 'Frequently asked questions, write to support';
  @override
  String get settingsLegal => 'Legal documents';
  @override
  String get settingsLegalSubtitle => 'Terms, privacy, community rules';
  @override
  String get settingsAccount => 'Account';
  @override
  String get settingsManageAccount => 'Manage my account';
  @override
  String get settingsManageAccountSubtitle => 'Pause or delete my account';
  @override
  String settingsVersion(String version) => 'Version $version';

  // ── Updates and rating
  @override
  String get updateUnavailable => 'The update is not available on Google Play yet.';
  @override
  String get updateRequiredTitle => 'Update required';
  @override
  String updateRequiredBody(String current, String latest) =>
      'Your version ($current) is no longer supported. Install version $latest to keep using ZAYA safely.';
  @override
  String get updateNow => 'Update';
  @override
  String get updateLater => 'Later';
  @override
  String get updateAvailableTitle => 'New version available';
  @override
  String updateAvailableBody(String latest) => 'ZAYA version $latest is available, with improvements and fixes.';
  @override
  String get storeUnavailable => 'ZAYA is not published on Google Play yet.';
  @override
  String get settingsRate => 'Rate ZAYA';
  @override
  String get settingsRateSubtitle => 'Your review on Google Play helps us improve the app';
  @override
  String get settingsUpdates => 'Updates';
  @override
  String get settingsUpToDate => 'You have the latest version';
  @override
  String settingsUpdateAvailable(String latest) => 'Version $latest available: update';

  // ── Profile (menu)
  @override
  String get profileTitle => 'Profile';
  @override
  String get profileEdit => 'Edit';
  @override
  String get profileShare => 'Share';
  @override
  String get profileIncomplete => 'Profile incomplete';
  @override
  String get chipSubscription => 'Subscription';
  @override
  String get chipInvite => 'Invite';
  @override
  String get chipHelp => 'Help';
  @override
  String get chipSafety => 'Safety & tips';
  @override
  String get planFreeTitle => 'Free plan';
  @override
  String planFreeSwipes(int count, int hours) => '$count swipes every $hours h';
  @override
  String get planFreeEssentials => 'Discovering, matching, chatting and staying safe remain free.';
  @override
  String get planDiscoverPremium => 'Discover Premium';
  @override
  String get planPremiumTitle => 'You are Premium';
  @override
  String get planPremiumBody => 'See your benefits and your subscription dates.';
  @override
  String get planMySubscription => 'My subscription';
  @override
  String get likesLeftTitle => 'Swipes left';
  @override
  String likesRenewAt(String time) => 'new period at $time';
  @override
  String get likesMore => 'More swipes with Premium';
  @override
  String get likesUnlimitedPremium => 'With Premium, you get more likes every day.';
  @override
  String inviteMessage(String url) => 'Join me on ZAYA, the app for serious relationships leading to marriage: $url';

  // ── Advertising
  @override
  String get adSponsored => 'Sponsored';
  @override
  String get adLearnMore => 'Learn more';
  @override
  String get adLabel => 'Advertisement';

  // ── Wallet and rewarded ads
  @override
  String get walletTitle => 'My wallet';
  @override
  String get walletSubtitle => 'Ad credits, coins, Premium';
  @override
  String get walletAdCredits => 'Ad credits';
  @override
  String get walletAdCreditsBody => 'Earned by choosing to watch an ad. Personal, not transferable, never convertible '
      'into money.';
  @override
  String walletSwipes(int n) => '$n extra swipes earned';
  @override
  String walletBoosts(int n) => '$n boost credits';
  @override
  String get walletCoins => 'Coins';
  @override
  String walletCoinsBalance(int n) => 'Balance: $n coins';
  @override
  String get walletCoinsClosed => 'Buying coins is not open yet.';
  @override
  String get walletPremium => 'Premium';
  @override
  String walletPremiumUntil(String date) => 'Active until $date';
  @override
  String get walletPremiumNone => 'Free plan';
  @override
  String get walletHistory => 'History';
  @override
  String get walletEmpty => 'No transactions yet.';
  @override
  String rewardedCta(String label, int amount) => 'Watch an ad: $label +$amount';
  @override
  String rewardedRemaining(int n) => '$n left today';
  @override
  String get rewardedConfirmTitle => 'Watch an ad?';
  @override
  String rewardedConfirmBody(String label, int amount) => 'A short ad, then $label +$amount, credited after Google '
      'verifies it. The reward is personal and not transferable.';
  @override
  String get rewardedWatch => 'Watch';
  @override
  String get rewardedPending => 'Checking your reward…';
  @override
  String rewardedCredited(String label, int amount) => '$label +$amount added.';
  @override
  String get rewardedUnavailable => 'No ad available right now. Try again later.';

  // ── Welcome mystery box
  @override
  String get mysteryTitle => 'Your welcome mystery box';
  @override
  String get mysterySubtitle => 'A gift for ZAYA’s first members. Free, one opening per account.';
  @override
  String get mysteryChances => 'What the box can contain (real chances)';
  @override
  String mysteryChance(String label, String percent) => '$label: $percent %';
  @override
  String get mysteryOpen => 'Open my box';
  @override
  String get mysteryOpening => 'Opening…';
  @override
  String get mysteryWon => 'You won';
  @override
  String get mysteryCredited => 'It is already added to your account. Personal reward, not transferable.';
  @override
  String get mysteryAlreadyOpened => 'Your box is already open.';
  @override
  String get mysteryContinue => 'Continue';
  @override
  String get mysteryEntry => 'Welcome mystery box';
  @override
  String get mysteryEntrySubtitle => 'A gift is waiting for you';
  @override
  String get walletBonus => 'ZAYA gifts';
  @override
  String get walletBonusBody => 'Given by ZAYA (welcome mystery box). Personal, non-transferable.';
  @override
  String walletBonusPremiumDays(int n) => '$n days of Premium offered';

  // ── Language
  @override
  String get languageTitle => 'App language';
  @override
  String get languageIntro => 'Choose the language of the ZAYA screens. It does not change the languages you speak, '
      'shown on your profile.';
  @override
  String languageName(AppLanguage language) => switch (language) {
        AppLanguage.fr => 'French',
        AppLanguage.en => 'English',
        AppLanguage.pular => 'Pular',
        AppLanguage.maninka => 'Maninka',
        AppLanguage.soso => 'Susu',
      };
  @override
  String get languageComingSoon => 'Coming soon';
  @override
  String get languageInPreparation => 'Coming soon: translation being prepared, then reviewed by native speakers';
  @override
  String get languageChanged => 'Language changed.';
  @override
  String get languageReportTitle => 'Does a translation look wrong?';
  @override
  String get languageReportButton => 'Report a translation error';

  // ── Help and support
  @override
  String get helpTitle => 'Help and support';
  @override
  String get helpFaqTitle => 'Frequently asked questions';
  @override
  String get helpContactTitle => 'Contact us';
  @override
  String get helpWriteSupport => 'Write to support';
  @override
  String get helpWriteSupportSubtitle => 'Answer in the app';
  @override
  String get helpMyRequests => 'My requests';
  @override
  String get helpMyRequestsSubtitle => 'Follow my requests and the answers';
  @override
  String get helpWhatsapp => 'Support on WhatsApp';
  @override
  String get helpWhatsappSubtitle => 'Official ZAYA number';
  @override
  String get helpSafetyTitle => 'A safety problem?';
  @override
  String get helpSafetyBody => 'Threats, blackmail, requests for money, photos shared without consent: report it, it '
      'will be handled first.';
  @override
  String get helpSafetyButton => 'Report a safety problem';
  @override
  String get helpEmergency => 'If you are in immediate danger, contact the emergency services first.';

  // ── Support requests
  @override
  String get supportTitle => 'Write to support';
  @override
  String get supportCategoryLabel => 'Subject';
  @override
  String supportCategory(String category) => switch (category) {
        'account' => 'My account',
        'verification' => 'Profile verification',
        'payment' => 'Subscription or payment',
        'safety' => 'Safety problem',
        'translation' => 'Translation error',
        'bug' => 'Technical problem',
        _ => 'Other',
      };
  @override
  String get supportMessageHint => 'Describe your request…';
  @override
  String get supportTranslationHint => 'Tell us the screen, the text shown and your suggested correction…';
  @override
  String get supportSafetyNotice => 'Safety problems are handled first.';
  @override
  String get supportCodeWarning => 'Never share your sign-in code, not even with support.';
  @override
  String get supportSent => 'Request sent. You can follow the answer in “My requests”.';
  @override
  String get supportRateLimited => 'You have sent several requests today. Try again tomorrow, or add to an existing '
      'request.';
  @override
  String get supportMessageTooShort => 'Describe your request in a few words (at least 10 characters).';
  @override
  String get myRequestsTitle => 'My requests';
  @override
  String get myRequestsEmptyTitle => 'No requests';
  @override
  String get myRequestsEmptyBody => 'Your requests to support and their answers will appear here.';
  @override
  String supportStatus(String status) => switch (status) {
        'in_progress' => 'In progress',
        'answered' => 'Answered',
        'closed' => 'Closed',
        _ => 'Sent',
      };
  @override
  String get supportReplyLabel => 'Answer from support';

  // ── Sign-up: nationality and profession
  @override
  String get onbNationalityTitle => 'Your nationality';
  @override
  String get onbNationalitySubtitle => 'Optional. You choose what you want to share.';
  @override
  String get onbProfessionTitle => 'What is your profession?';
  @override
  String get onbProfessionSubtitle => 'Optional. Choose from the list or describe your own.';
  @override
  String get onbProfessionSearch => 'Search for a job';
  @override
  String get onbProfessionNoResult => 'No job matches: describe yours below.';
  @override
  String get onbProfessionOther => 'Other profession (optional)';
  @override
  String get onbListUnavailable => 'The list could not be loaded. You can skip this step and complete your profile '
      'later.';

  // ── End of sign-up and sign-in code
  @override
  String get signupDoneTitle => 'Your profile is created';
  @override
  String get signupDoneBody => 'It will be shown to other members once the ZAYA team has verified it: add your '
      'photos, then take a check selfie. The selfie never appears on your profile.';
  @override
  List<String> get photoTips => const [
        'Your face clearly visible, no sunglasses',
        'Only you in the main photo',
        'Recent photos, of you only',
        'Nothing suggestive, and no contact details in photos',
      ];
  @override
  String get signupDoneAddPhotos => 'Add my photos';
  @override
  String get signupDoneLater => 'Later';
  @override
  String otpResendIn(int seconds) => 'You can request a new code in $seconds s';
  @override
  String get otpResend => 'Resend the code';
  @override
  String get otpResent => 'New code sent.';

  // ── Ended matches
  @override
  String get endedMatchesTitle => 'Ended matches';
  @override
  String get endedMatchesEntrySubtitle => 'Read an old conversation, report if needed';
  @override
  String get endedMatchesExplain => 'When a match ends, the conversation closes for both of you: no more messages can '
      'be sent. You can read your old messages and report the person if needed. They are kept for safety and for '
      'handling reports.';
  @override
  String get endedMatchesEmptyTitle => 'No ended matches';
  @override
  String get endedMatchesEmptyBody => 'Matches that you or the other person ended will appear here.';
  @override
  String endedMatchSubtitle(String date, {required bool byMe}) =>
      'Ended on $date · ${byMe ? 'by you' : 'by the other person'}';
  @override
  String get accountClosed => 'Account closed';
  @override
  String get endedChatBanner => 'This match has ended: you can no longer send messages.';
  @override
  String get endedChatEmpty => 'No messages in this conversation.';

  // ── Legal documents
  @override
  String get legalTitle => 'Legal documents';
  @override
  String legalKind(String kind) => switch (kind) {
        'tos' => 'Terms of use',
        'privacy' => 'Privacy policy',
        _ => 'Community rules',
      };
  @override
  String legalVersion(String version, String date) => 'Version $version · published on $date';
  @override
  String get legalDraftNotice => 'Draft version, awaiting legal approval.';
  @override
  String get legalMissing => 'This document has not been published yet.';
  @override
  String get legalFrenchOnly => 'This document is not available in your language yet: it is shown in French.';

  // ── Mariage : recherche animée avant l'affichage des profils
  @override
  String get radarSearchTitle => 'Looking for profiles';
  @override
  String get radarSearchSubtitle => 'matching your preferences';
}
