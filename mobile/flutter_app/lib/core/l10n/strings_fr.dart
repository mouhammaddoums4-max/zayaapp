import 'l10n.dart';

/// Textes français (langue de référence de ZAYA).
class ZStringsFr extends ZStrings {
  const ZStringsFr();

  // ── Commun
  @override
  String get cancel => 'Annuler';
  @override
  String get close => 'Fermer';
  @override
  String get send => 'Envoyer';
  @override
  String get retry => 'Réessayer';
  @override
  String get comingSoon => 'Bientôt disponible';
  @override
  String get loadError => 'Impossible de charger. Vérifiez votre connexion.';
  @override
  String get signOut => 'Se déconnecter';
  @override
  String get signOutConfirmTitle => 'Se déconnecter ?';
  @override
  String get signOutConfirmBody => 'Vous pourrez vous reconnecter à tout moment avec votre numéro de téléphone.';
  @override
  String get demoModeNotice => 'Mode démo — données fictives, rien n’est enregistré.';
  @override
  String genderLabel(String gender) => switch (gender) {
        'femme' => 'Femme',
        'homme' => 'Homme',
        _ => 'Non renseigné',
      };

  // ── Réglages
  @override
  String get settingsTitle => 'Réglages';
  @override
  String get settingsEntrySubtitle => 'Compte, confidentialité, langue, aide';
  @override
  String get settingsPersonalInfo => 'Informations personnelles';
  @override
  String get settingsDisplayName => 'Nom affiché';
  @override
  String get settingsBirthDate => 'Date de naissance';
  @override
  String get settingsGender => 'Genre';
  @override
  String get settingsPhone => 'Numéro de téléphone';
  @override
  String get settingsFixedInfoTitle => 'Information non modifiable';
  @override
  String get settingsFixedInfoBody =>
      'Votre date de naissance et votre genre sont fixés à l’inscription, pour protéger '
      'les membres contre les faux profils. En cas d’erreur, écrivez à l’assistance.';
  @override
  String get settingsPhoneInfoTitle => 'Votre numéro de téléphone';
  @override
  String get settingsPhoneInfoBody => 'Il sert uniquement à vous connecter et à sécuriser votre compte. Il n’apparaît '
      'jamais sur votre profil. Pour le changer, écrivez à l’assistance.';
  @override
  String get settingsApp => 'Application';
  @override
  String get settingsLanguage => 'Langue';
  @override
  String get settingsPrivacySection => 'Confidentialité';
  @override
  String get settingsPrivacy => 'Confidentialité et sécurité';
  @override
  String get settingsPrivacySubtitle => 'Visibilité, personnes bloquées, mes données';
  @override
  String get settingsSafetyTips => 'Conseils de sécurité';
  @override
  String get settingsSafetyTipsSubtitle => 'Rencontres, arnaques, signalement';
  @override
  String get settingsPurchases => 'Achats';
  @override
  String get settingsSubscriptions => 'Mes abonnements';
  @override
  String get settingsSubscriptionPremium => 'Premium';
  @override
  String get settingsSubscriptionFree => 'Offre Gratuit';
  @override
  String get settingsPayments => 'Mes paiements';
  @override
  String get settingsPaymentsSubtitle => 'Historique et reçus';
  @override
  String get settingsHelpSection => 'Aide';
  @override
  String get settingsHelp => 'Aide et assistance';
  @override
  String get settingsHelpSubtitle => 'Questions fréquentes, écrire à l’assistance';
  @override
  String get settingsLegal => 'Documents légaux';
  @override
  String get settingsLegalSubtitle => 'Conditions, confidentialité, règles communautaires';
  @override
  String get settingsAccount => 'Compte';
  @override
  String get settingsManageAccount => 'Gérer mon compte';
  @override
  String get settingsManageAccountSubtitle => 'Mettre en pause ou supprimer mon compte';
  @override
  String settingsVersion(String version) => 'Version $version';

  // ── Mises à jour et avis
  @override
  String get updateUnavailable => 'La mise à jour n’est pas encore disponible sur Google Play.';
  @override
  String get updateRequiredTitle => 'Mise à jour nécessaire';
  @override
  String updateRequiredBody(String current, String latest) => 'Votre version ($current) n’est plus prise en '
      'charge. Installez la version $latest pour continuer à utiliser ZAYA en toute sécurité.';
  @override
  String get updateNow => 'Mettre à jour';
  @override
  String get updateLater => 'Plus tard';
  @override
  String get updateAvailableTitle => 'Nouvelle version disponible';
  @override
  String updateAvailableBody(String latest) =>
      'La version $latest de ZAYA est disponible, avec des améliorations et des corrections.';
  @override
  String get storeUnavailable => 'ZAYA n’est pas encore publiée sur Google Play.';
  @override
  String get settingsRate => 'Noter ZAYA';
  @override
  String get settingsRateSubtitle => 'Votre avis sur Google Play nous aide à améliorer l’application';
  @override
  String get settingsUpdates => 'Mises à jour';
  @override
  String get settingsUpToDate => 'Vous avez la dernière version';
  @override
  String settingsUpdateAvailable(String latest) => 'Version $latest disponible : mettre à jour';

  // ── Profil (menu)
  @override
  String get profileTitle => 'Profil';
  @override
  String get profileEdit => 'Modifier';
  @override
  String get profileShare => 'Partager';
  @override
  String get profileIncomplete => 'Profil incomplet';
  @override
  String get chipSubscription => 'Abonnement';
  @override
  String get chipInvite => 'Inviter';
  @override
  String get chipHelp => 'Aide';
  @override
  String get chipSafety => 'Sécurité & conseils';
  @override
  String get planFreeTitle => 'Offre Gratuit';
  @override
  String planFreeSwipes(int count, int hours) => '$count swipes toutes les $hours h';
  @override
  String get planFreeEssentials => 'Découvrir, matcher, discuter et vous protéger restent gratuits.';
  @override
  String get planDiscoverPremium => 'Découvrir Premium';
  @override
  String get planPremiumTitle => 'Vous êtes Premium';
  @override
  String get planPremiumBody => 'Retrouvez vos avantages et les dates de votre abonnement.';
  @override
  String get planMySubscription => 'Mon abonnement';
  @override
  String get likesLeftTitle => 'Swipes restants';
  @override
  String likesRenewAt(String time) => 'nouvelle période à $time';
  @override
  String get likesMore => 'Plus de swipes avec Premium';
  @override
  String get likesUnlimitedPremium => 'Avec Premium, vous disposez de davantage de likes chaque jour.';
  @override
  String inviteMessage(String url) =>
      'Je t’invite à découvrir ZAYA, l’application de rencontres sérieuses en vue du mariage : $url';

  // ── Publicité
  @override
  String get adSponsored => 'Sponsorisé';
  @override
  String get adLearnMore => 'En savoir plus';
  @override
  String get adLabel => 'Publicité';

  // ── Portefeuille et publicités récompensées
  @override
  String get walletTitle => 'Mon portefeuille';
  @override
  String get walletSubtitle => 'Crédits publicitaires, pièces, Premium';
  @override
  String get walletAdCredits => 'Crédits publicitaires';
  @override
  String get walletAdCreditsBody => 'Gagnés en regardant volontairement une publicité. Personnels, non transférables, '
      'jamais convertibles en argent.';
  @override
  String walletSwipes(int n) => '$n swipes supplémentaires gagnés';
  @override
  String walletBoosts(int n) => '$n crédits de boost';
  @override
  String get walletCoins => 'Pièces';
  @override
  String walletCoinsBalance(int n) => 'Solde : $n pièces';
  @override
  String get walletCoinsClosed => 'L’achat de pièces n’est pas encore ouvert.';
  @override
  String get walletPremium => 'Premium';
  @override
  String walletPremiumUntil(String date) => 'Actif jusqu’au $date';
  @override
  String get walletPremiumNone => 'Offre Gratuit';
  @override
  String get walletHistory => 'Historique';
  @override
  String get walletEmpty => 'Aucune opération pour le moment.';
  @override
  String rewardedCta(String label, int amount) => 'Regarder une publicité : $label +$amount';
  @override
  String rewardedRemaining(int n) => 'encore $n aujourd’hui';
  @override
  String get rewardedConfirmTitle => 'Regarder une publicité ?';
  @override
  String rewardedConfirmBody(String label, int amount) => 'Une courte publicité, puis $label +$amount, '
      'crédités après vérification par Google. La récompense est personnelle et non transférable.';
  @override
  String get rewardedWatch => 'Regarder';
  @override
  String get rewardedPending => 'Récompense en cours de vérification…';
  @override
  String rewardedCredited(String label, int amount) => '$label +$amount ajoutés.';
  @override
  String get rewardedUnavailable => 'Aucune publicité disponible pour le moment. Réessayez plus tard.';

  // ── Boîte mystère de bienvenue
  @override
  String get mysteryTitle => 'Votre boîte mystère de bienvenue';
  @override
  String get mysterySubtitle => 'Offerte aux premiers membres de ZAYA. Gratuite, une seule ouverture par compte.';
  @override
  String get mysteryChances => 'Ce que la boîte peut contenir (chances réelles)';
  @override
  String mysteryChance(String label, String percent) => '$label : $percent %';
  @override
  String get mysteryOpen => 'Ouvrir ma boîte';
  @override
  String get mysteryOpening => 'Ouverture…';
  @override
  String get mysteryWon => 'Vous avez gagné';
  @override
  String get mysteryCredited => 'C’est déjà ajouté à votre compte. Récompense personnelle, non transférable.';
  @override
  String get mysteryAlreadyOpened => 'Votre boîte est déjà ouverte.';
  @override
  String get mysteryContinue => 'Continuer';
  @override
  String get mysteryEntry => 'Boîte mystère de bienvenue';
  @override
  String get mysteryEntrySubtitle => 'Un cadeau vous attend';
  @override
  String get walletBonus => 'Cadeaux ZAYA';
  @override
  String get walletBonusBody => 'Offerts par ZAYA (boîte mystère de bienvenue). Personnels, non transférables.';
  @override
  String walletBonusPremiumDays(int n) => '$n jours de Premium offerts';

  // ── Verrouillage de l'application
  @override
  String get lockTitle => 'ZAYA est verrouillé';
  @override
  String get lockEnterPin => 'Saisissez votre code';
  @override
  String get lockWrongPin => 'Code incorrect';
  @override
  String get lockUseDevice => 'Empreinte ou visage';
  @override
  String get lockReason => 'Déverrouiller ZAYA';
  @override
  String get lockForgot => 'Code oublié ?';
  @override
  String get lockForgotBody =>
      'Pour protéger votre compte, le verrouillage sera désactivé et vous devrez vous reconnecter avec votre numéro de téléphone.';
  @override
  String get lockForgotConfirm => 'Me reconnecter';
  @override
  String get lockSettingsTitle => 'Verrouillage de l’application';
  @override
  String get lockSettingsSubtitle => 'Code PIN, empreinte digitale, Face ID';
  @override
  String get lockSwitch => 'Verrouiller ZAYA par un code';
  @override
  String get lockBiometricSwitch => 'Empreinte digitale ou reconnaissance faciale';
  @override
  String get lockBiometricUnavailable => 'Aucune empreinte ni aucun visage enregistré sur ce téléphone.';
  @override
  String get lockDelayTitle => 'Verrouiller';
  @override
  String get lockChangePin => 'Changer le code';
  @override
  String get lockPrivacyNote => 'Votre code et votre empreinte restent sur ce téléphone : ZAYA ne les reçoit jamais.';
  @override
  String get lockNewPin => 'Choisissez un code à 4 chiffres';
  @override
  String get lockConfirmPin => 'Confirmez le code';
  @override
  String get lockPinMismatch => 'Les deux codes ne correspondent pas.';
  @override
  String get lockCurrentPin => 'Saisissez votre code actuel';
  @override
  String get lockEnabled => 'Verrouillage activé';
  @override
  String lockWait(int seconds) => 'Trop d’essais. Réessayez dans $seconds s.';
  @override
  String lockDelay(int seconds) => seconds == 0
      ? 'Immédiatement'
      : seconds < 120
          ? 'Après 1 minute'
          : 'Après ${seconds ~/ 60} minutes';

  // ── Boutique
  @override
  String get shopTitle => 'Boutique';
  @override
  String get shopSubtitle => 'Cadeaux et compliments';
  @override
  String get shopGifts => 'Cadeaux';
  @override
  String get shopCompliments => 'Compliments';
  @override
  String get shopBuyCoins => 'Acheter des pièces';
  @override
  String get shopNotOnSale => 'Bientôt';
  @override
  String get shopSend => 'Offrir';
  @override
  String get shopSent => 'Envoyé !';
  @override
  String get shopInsufficient => 'Solde de pièces insuffisant.';
  @override
  String get shopLimit => 'Limite du jour atteinte. Réessayez demain.';
  @override
  String get shopUnavailable => 'Ce membre ne peut pas recevoir de cadeau.';
  @override
  String get shopDisabled => 'La boutique n’est pas encore ouverte.';
  @override
  String get shopBrowseHint => 'Ouvrez le profil d’un membre pour lui offrir un cadeau ou un compliment.';
  @override
  String get shopHistoryTitle => 'Mes cadeaux';
  @override
  String get shopReceived => 'Reçus';
  @override
  String get shopSentTab => 'Envoyés';
  @override
  String get shopHistoryEmpty => 'Aucun cadeau pour le moment.';
  @override
  String get shopGiveGift => 'Offrir un cadeau';
  @override
  String shopPrice(int n) => '$n pièces';
  @override
  String shopSendTo(String name) => 'Offrir à $name';
  @override
  String shopConfirm(String item, String name) => 'Offrir « $item » à $name ?';
  @override
  String shopConfirmBody(int price) => '$price pièces seront débitées de votre solde. Cet envoi est définitif.';
  @override
  String shopFrom(String name) => 'De $name';
  @override
  String shopTo(String name) => 'À $name';

  // ── Langue
  @override
  String get languageTitle => 'Langue de l’application';
  @override
  String get languageIntro => 'Choisissez la langue des écrans de ZAYA. Elle ne change pas les langues parlées '
      'indiquées sur votre profil.';
  @override
  String languageName(AppLanguage language) => switch (language) {
        AppLanguage.fr => 'Français',
        AppLanguage.en => 'Anglais',
        AppLanguage.pular => 'Poular',
        AppLanguage.maninka => 'Malinké',
        AppLanguage.soso => 'Soussou',
      };
  @override
  String get languageComingSoon => 'Bientôt disponible';
  @override
  String get languageInPreparation => 'Bientôt disponible : traduction en préparation, puis relue par des locuteurs';
  @override
  String get languageChanged => 'Langue modifiée.';
  @override
  String get languageReportTitle => 'Une traduction vous semble incorrecte ?';
  @override
  String get languageReportButton => 'Signaler une erreur de traduction';

  // ── Aide et assistance
  @override
  String get helpTitle => 'Aide et assistance';
  @override
  String get helpFaqTitle => 'Questions fréquentes';
  @override
  String get helpContactTitle => 'Nous contacter';
  @override
  String get helpWriteSupport => 'Écrire à l’assistance';
  @override
  String get helpWriteSupportSubtitle => 'Réponse dans l’application';
  @override
  String get helpMyRequests => 'Mes demandes';
  @override
  String get helpMyRequestsSubtitle => 'Suivre mes demandes et les réponses';
  @override
  String get helpWhatsapp => 'Assistance sur WhatsApp';
  @override
  String get helpWhatsappSubtitle => 'Numéro officiel de ZAYA';
  @override
  String get helpSafetyTitle => 'Un problème de sécurité ?';
  @override
  String get helpSafetyBody => 'Menace, chantage, demande d’argent, photo diffusée sans accord : signalez-le, '
      'il sera traité en priorité.';
  @override
  String get helpSafetyButton => 'Signaler un problème de sécurité';
  @override
  String get helpEmergency => 'En cas de danger immédiat, contactez d’abord les services d’urgence.';

  // ── Demandes à l'assistance
  @override
  String get supportTitle => 'Écrire à l’assistance';
  @override
  String get supportCategoryLabel => 'Sujet';
  @override
  String supportCategory(String category) => switch (category) {
        'account' => 'Mon compte',
        'verification' => 'Vérification du profil',
        'payment' => 'Abonnement ou paiement',
        'safety' => 'Problème de sécurité',
        'translation' => 'Erreur de traduction',
        'bug' => 'Problème technique',
        _ => 'Autre',
      };
  @override
  String get supportMessageHint => 'Décrivez votre demande…';
  @override
  String get supportTranslationHint => 'Indiquez l’écran, le texte affiché et la correction proposée…';
  @override
  String get supportSafetyNotice => 'Les problèmes de sécurité sont traités en priorité.';
  @override
  String get supportCodeWarning => 'Ne communiquez jamais votre code de connexion, même à l’assistance.';
  @override
  String get supportSent => 'Demande envoyée. Vous suivrez la réponse dans « Mes demandes ».';
  @override
  String get supportRateLimited => 'Vous avez envoyé plusieurs demandes aujourd’hui. Réessayez demain, ou complétez '
      'une demande existante.';
  @override
  String get supportMessageTooShort => 'Décrivez votre demande en quelques mots (10 caractères au moins).';
  @override
  String get myRequestsTitle => 'Mes demandes';
  @override
  String get myRequestsEmptyTitle => 'Aucune demande';
  @override
  String get myRequestsEmptyBody => 'Vos demandes à l’assistance et leurs réponses apparaîtront ici.';
  @override
  String supportStatus(String status) => switch (status) {
        'in_progress' => 'En cours de traitement',
        'answered' => 'Réponse reçue',
        'closed' => 'Clôturée',
        _ => 'Envoyée',
      };
  @override
  String get supportReplyLabel => 'Réponse de l’assistance';

  // ── Inscription : nationalité et profession
  @override
  String get onbNationalityTitle => 'Votre nationalité';
  @override
  String get onbNationalitySubtitle => 'Facultatif. Vous choisissez ce que vous souhaitez indiquer.';
  @override
  String get onbProfessionTitle => 'Quelle est votre profession ?';
  @override
  String get onbProfessionSubtitle => 'Facultatif. Choisissez dans la liste ou précisez la vôtre.';
  @override
  String get onbProfessionSearch => 'Rechercher un métier';
  @override
  String get onbProfessionNoResult => 'Aucun métier ne correspond : précisez le vôtre ci-dessous.';
  @override
  String get onbProfessionOther => 'Autre profession (facultatif)';
  @override
  String get onbListUnavailable => 'La liste n’a pas pu être chargée. Vous pouvez passer cette étape et compléter '
      'votre profil plus tard.';

  // ── Fin d'inscription et code de connexion
  @override
  String get signupDoneTitle => 'Votre profil est créé';
  @override
  String get signupDoneBody => 'Il sera proposé aux autres membres une fois vérifié par l’équipe ZAYA : ajoutez vos '
      'photos, puis prenez un selfie de contrôle. Le selfie n’apparaît jamais sur votre profil.';
  @override
  List<String> get photoTips => const [
        'Votre visage bien visible, sans lunettes de soleil',
        'Vous seul(e) sur la photo principale',
        'Des photos récentes, de vous uniquement',
        'Rien de suggestif, ni coordonnées sur les photos',
      ];
  @override
  String get signupDoneAddPhotos => 'Ajouter mes photos';
  @override
  String get signupDoneLater => 'Plus tard';
  @override
  String otpResendIn(int seconds) => 'Vous pourrez demander un nouveau code dans $seconds s';
  @override
  String get otpResend => 'Renvoyer le code';
  @override
  String get otpResent => 'Nouveau code envoyé.';

  // ── Matchs terminés
  @override
  String get endedMatchesTitle => 'Matchs terminés';
  @override
  String get endedMatchesEntrySubtitle => 'Relire une ancienne conversation, signaler si besoin';
  @override
  String get endedMatchesExplain => 'Quand un match prend fin, la conversation est fermée pour vous deux : plus aucun '
      'message ne peut être envoyé. Vous pouvez relire vos anciens messages et signaler la personne si besoin. Ils '
      'sont conservés pour la sécurité et le traitement des signalements.';
  @override
  String get endedMatchesEmptyTitle => 'Aucun match terminé';
  @override
  String get endedMatchesEmptyBody => 'Les matchs auxquels vous ou l’autre personne avez mis fin apparaîtront ici.';
  @override
  String endedMatchSubtitle(String date, {required bool byMe}) =>
      'Terminé le $date · ${byMe ? 'par vous' : 'par l’autre personne'}';
  @override
  String get accountClosed => 'Compte fermé';
  @override
  String get endedChatBanner => 'Ce match est terminé : vous ne pouvez plus envoyer de message.';
  @override
  String get endedChatEmpty => 'Aucun message dans cette conversation.';
  @override
  String get chatPhotoAction => 'Envoyer une photo';
  @override
  String get chatFileAction => 'Joindre un fichier';
  @override
  String get chatPlusAction => 'Plus d’options';
  @override
  String get chatAnimatedStickerAction => 'GIF et emojis animés';
  @override
  String get chatAnimatedStickerHint => 'Touchez une animation pour l’envoyer';
  @override
  String chatAnimatedStickerName(String stickerId) => switch (stickerId) {
        'heart_bounce' => 'Cœur qui bat',
        'laugh_shake' => 'Rire',
        'kiss_pulse' => 'Bisou',
        'hug_squeeze' => 'Câlin',
        'party_spin' => 'Fête',
        'prayer_bounce' => 'Merci',
        'rose_sway' => 'Rose',
        'fire_flicker' => 'Feu',
        _ => 'Animation',
      };
  @override
  String get chatReplySuggestionsTitle => 'Suggestions de réponse';
  @override
  List<String> chatReplySuggestions(String incomingMessage) {
    final text = incomingMessage.toLowerCase();
    if (RegExp(r'\b(bonjour|bonsoir|salut|coucou)\b').hasMatch(text)) {
      return const [
        'Bonjour 😊 Comment se passe votre journée ?',
        'Bonsoir 😊 Ravi(e) de faire votre connaissance.',
        'Salut 🙂 Qu’aimez-vous faire pendant votre temps libre ?',
      ];
    }
    if (RegExp(r'\b(comment ça va|comment ca va|ça va|ca va|comment allez-vous)\b').hasMatch(text)) {
      return const [
        'Je vais bien, merci 😊 Et vous ?',
        'Ça va bien, merci. Comment se passe votre journée ?',
        'Merci de demander 😊 Et votre journée ?',
      ];
    }
    if (RegExp(r'\b(mariage|relation|engagement|sérieux|serieux|projet de vie)\b').hasMatch(text)) {
      return const [
        'Je souhaite construire une relation sincère et sérieuse.',
        'Le respect et la confiance sont essentiels pour moi.',
        'J’aimerais d’abord apprendre à vous connaître.',
      ];
    }
    if (RegExp(r'\b(famille|parents|enfants)\b').hasMatch(text)) {
      return const [
        'La famille est importante pour moi. Et vous ?',
        'J’aimerais en savoir plus sur votre vision de la famille.',
        'Je pense qu’il faut en parler avec sincérité.',
      ];
    }
    if (RegExp(r'\b(travail|études|etudes|métier|metier|profession)\b').hasMatch(text)) {
      return const [
        'C’est intéressant 😊 Depuis combien de temps ?',
        'Qu’est-ce qui vous plaît le plus dans votre activité ?',
        'Vous aimez ce que vous faites ?',
      ];
    }
    if (RegExp(r'\b(merci|remercie)\b').hasMatch(text)) {
      return const ['Avec plaisir 😊', 'Merci à vous pour cet échange !', 'Ça me fait plaisir 🙂'];
    }
    if (text.contains('?')) {
      return const [
        'C’est une bonne question 😊 Et vous, qu’en pensez-vous ?',
        'Je préfère qu’on échange là-dessus tranquillement.',
        'Pouvez-vous m’en dire un peu plus ?',
      ];
    }
    return const [
      'Merci pour votre message 😊',
      'Je suis content(e) d’échanger avec vous.',
      'Et vous, qu’en pensez-vous ?',
    ];
  }

  @override
  String get chatVoiceAction => 'Enregistrer une note vocale';
  @override
  String get chatAudioCallAction => 'Appel audio';
  @override
  String get chatVideoCallAction => 'Appel vidéo';
  @override
  String get chatMediaUnavailableTitle => 'Pièces jointes indisponibles';
  @override
  String get chatMediaUnavailableBody =>
      'L’envoi de photos et de fichiers sera activé après la configuration de leur contrôle de sécurité et de leur '
      'modération. Vous pouvez déjà envoyer des messages, des emojis et des notes vocales.';
  @override
  String get chatCallsInactiveTitle => 'Appels désactivés';
  @override
  String get chatCallsInactiveBody => 'Les appels audio et vidéo sont désactivés pour le moment.';

  // ── Documents légaux
  @override
  String get legalTitle => 'Documents légaux';
  @override
  String legalKind(String kind) => switch (kind) {
        'tos' => 'Conditions d’utilisation',
        'privacy' => 'Politique de confidentialité',
        _ => 'Règles communautaires',
      };
  @override
  String legalVersion(String version, String date) => 'Version $version · publiée le $date';
  @override
  String get legalDraftNotice => 'Version provisoire, en attente de validation juridique.';
  @override
  String get legalMissing => 'Ce document n’est pas encore publié.';
  @override
  String get legalFrenchOnly => 'Ce document n’existe pas encore dans votre langue : il est affiché en français.';

  // ── Mariage : recherche animée avant l'affichage des profils
  @override
  String get radarSearchTitle => 'Recherche de profils';
  @override
  String get radarSearchSubtitle => 'selon vos préférences';

  // ── Niveau d'études et enfants : inscription et filtres Premium (0052)
  @override
  String get onbEducationTitle => 'Votre niveau d’études';
  @override
  String get onbEducationSubtitle => 'Facultatif. Il sera affiché sur votre profil.';
  @override
  String get onbChildrenTitle => 'Avez-vous des enfants ?';
  @override
  String get onbChildrenSubtitle => 'Facultatif. Le nombre sera affiché sur votre profil.';
  @override
  String get childrenNone => 'Aucun enfant';
  @override
  String childrenCount(int count) => count == 1 ? '1 enfant' : '$count enfants';
  @override
  String get childrenFiveOrMore => '5 enfants ou plus';
  @override
  String get prefsEducation => 'Niveau d’études';
  @override
  String get prefsChildren => 'Enfants';
  @override
  String get prefsChildrenAny => 'Peu importe';
  @override
  String prefsChildrenAtMost(int count) => count == 0 ? 'Sans enfant' : '$count au plus';
}
