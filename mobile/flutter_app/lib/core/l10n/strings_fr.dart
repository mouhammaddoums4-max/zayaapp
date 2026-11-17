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
  List<FaqSection> get faq => const [
        FaqSection('Compte et profil', [
          FaqItem(
            'Pourquoi mon profil n’apparaît-il pas dans Découvrir ?',
            'Un profil n’est proposé aux autres membres qu’une fois vérifié par l’équipe ZAYA : il faut le nombre '
                'minimum de photos demandé et un selfie de contrôle (Profil → Vérification du profil). Un profil en '
                'pause ou masqué n’est pas proposé non plus.',
          ),
          FaqItem(
            'Mon numéro de téléphone est-il visible ?',
            'Non. Il sert uniquement à vous connecter et à sécuriser votre compte. Il n’apparaît jamais sur votre '
                'profil ni dans vos conversations.',
          ),
          FaqItem(
            'Puis-je modifier ma date de naissance ou mon genre ?',
            'Non : ils sont fixés à l’inscription pour protéger les membres contre les faux profils. En cas '
                'd’erreur, écrivez à l’assistance.',
          ),
        ]),
        FaqSection('Rencontres et messages', [
          FaqItem(
            'Comment se crée un match ?',
            'Un match se crée seulement lorsque deux personnes s’aiment mutuellement. La conversation s’ouvre alors '
                'pour vous deux.',
          ),
          FaqItem(
            'Pourquoi mon message a-t-il été refusé ?',
            'Avant l’envoi, ZAYA bloque les messages contraires à la charte, par exemple une demande d’argent ou des '
                'insultes. Les numéros de téléphone sont masqués pour vous protéger. Reformulez votre message.',
          ),
          FaqItem(
            'Que se passe-t-il quand un match prend fin ?',
            'La conversation se ferme pour les deux personnes. Le match apparaît ensuite dans « Matchs terminés », '
                'dans l’onglet Messages.',
          ),
        ]),
        FaqSection('Sécurité', [
          FaqItem(
            'Comment signaler ou bloquer quelqu’un ?',
            'Depuis son profil ou la conversation, ouvrez le menu ⋯ puis choisissez « Signaler » ou « Bloquer ». La '
                'personne n’est pas prévenue. Après un blocage, vous ne vous voyez plus.',
          ),
          FaqItem(
            'Quelqu’un me demande de l’argent : que faire ?',
            'Ne transférez jamais d’argent à une personne que vous n’avez pas rencontrée, et ne communiquez jamais '
                'un code reçu par SMS. Signalez la personne : notre équipe examine chaque signalement.',
          ),
        ]),
        FaqSection('Abonnement et compte', [
          FaqItem(
            'Que puis-je faire gratuitement ?',
            'Créer votre profil, découvrir des profils, aimer dans la limite quotidienne, obtenir des matchs et '
                'discuter avec eux restent gratuits. Premium ajoute des avantages, sans jamais fermer une conversation '
                'après un match.',
          ),
          FaqItem(
            'Comment supprimer mon compte ?',
            'Réglages → Gérer mon compte. Votre profil est masqué immédiatement et vous pouvez annuler pendant le '
                'délai indiqué. Vous pouvez aussi simplement mettre votre profil en pause.',
          ),
        ]),
      ];
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
}
