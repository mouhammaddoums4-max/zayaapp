# Connecter ZAYA à votre projet Supabase

Projet : `wocgmmwwopzrgleeevof`, à utiliser comme **préproduction** (tests). La production devra être un projet séparé (décision B5).

État relevé le 17/11/2026, en lecture seule avec la clé publique :
- base vide : aucune table ZAYA ;
- connexion par **téléphone désactivée** : seule la connexion par e-mail est active.

---

## 1. Installer la base de données (2 minutes)

1. Ouvrez l'éditeur SQL : <https://supabase.com/dashboard/project/wocgmmwwopzrgleeevof/sql/new>
2. Dans VS Code, ouvrez [supabase/deploy/zaya_installation.sql](../supabase/deploy/zaya_installation.sql), puis `Ctrl+A` et `Ctrl+C`.
3. Collez le contenu dans l'éditeur SQL de Supabase, puis cliquez sur **Run**.
4. Résultat attendu : **Success. No rows returned**.
   - « ZAYA semble déjà installé » : la base était déjà en place, rien n'a été modifié.
   - Toute autre erreur : rien n'a été modifié (installation en un seul bloc). Envoyez-moi le message affiché.
5. Vérification dans **Table Editor** : `communities` contient 8 lignes, `cities` 18 lignes, `profiles` est vide.

Le fichier est généré à partir de `supabase/migrations` et `supabase/seed` ; les tests (`cd supabase/tests && npm test`) vérifient qu'il est à jour et qu'il s'installe d'un seul bloc.

**Base déjà installée :** le fichier d'installation refuse de s'exécuter une seconde fois. Collez seulement, dans l'ordre, les migrations publiées après votre installation :

| Migration | Contenu | Sur `wocgmmwwopzrgleeevof` |
|---|---|---|
| [0007_photos_lecture.sql](../supabase/migrations/0007_photos_lecture.sql) | Un membre peut afficher les photos des autres membres (correction de la règle de stockage) | Appliquée le 17/11/2026 |
| [0008_assistance.sql](../supabase/migrations/0008_assistance.sql) | Demandes à l'assistance, langues de l'interface activables | Appliquée le 17/11/2026 |
| [0009_photos_floutees.sql](../supabase/migrations/0009_photos_floutees.sql) | Floutage des photos côté serveur (§4 bis) | Appliquée le 17/11/2026 |
| [0010_matchs_termines.sql](../supabase/migrations/0010_matchs_termines.sql) | Liste des matchs terminés | Appliquée le 17/11/2026 |

Les migrations précédentes (0001 à 0006) sont comprises dans l'installation du 17/11/2026.

## 2. Activer la connexion par téléphone

**Pour tester tout de suite, sans SMS :**

1. **Authentication → Sign In / Providers → Phone** : activez le fournisseur.
2. Dans **Test Phone Numbers and OTPs**, ajoutez un numéro de test (sans le `+`) et son code, par exemple :
   `224620000001=123456`
3. Enregistrez. Dans l'application, ce numéro (`620 00 00 01`) se connecte avec le code `123456`, sans envoi de SMS.

Si Supabase demande les identifiants d'un fournisseur SMS pour enregistrer, les numéros de test n'envoient de toute façon aucun SMS ; les vrais numéros ne fonctionneront qu'après l'étape 4.

## 3. Lancer l'application connectée

Le fichier `mobile/flutter_app/env.staging.json` contient déjà l'adresse du projet et la clé publique. Il reste sur votre ordinateur : il n'est **pas** envoyé sur GitHub.

```bash
cd mobile/flutter_app
flutter run -d chrome --dart-define-from-file=env.staging.json
```

Sans ce paramètre, l'application démarre en mode démo (profils fictifs, aucun serveur).

> La clé « publishable » (`sb_publishable_…`) est publique par conception : elle est intégrée à l'application et les données restent protégées par les règles d'accès du serveur. La clé **secrète** (`sb_secret_…`) et le mot de passe de la base ne doivent jamais être partagés, ni écrits dans le code ou sur GitHub.

## 4. Envoyer de vrais SMS avec Nimba (décision B3)

Compte Nimba fourni le 17/11/2026 : identifiants valides, expéditeur **« Pinal Group »** accepté par Nimba.
Le solde SMS était à **0** à cette date : achetez du crédit SMS chez Nimba avant tout essai réel.

Dans un terminal, sur votre ordinateur (remplacez `...` par les valeurs de votre espace Nimba, sans jamais les écrire dans un fichier du projet) :

```bash
cd "ZAYA APP"
npx supabase login                                   # ouvre le navigateur
npx supabase functions deploy send-sms-hook --no-verify-jwt --project-ref wocgmmwwopzrgleeevof
npx supabase secrets set --project-ref wocgmmwwopzrgleeevof NIMBA_SERVICE_ID=... NIMBA_SECRET=... "NIMBA_SENDER=Pinal Group"
```

Puis **Authentication → Hooks → Send SMS hook** : type HTTPS, adresse
`https://wocgmmwwopzrgleeevof.supabase.co/functions/v1/send-sms-hook`. Générez le secret proposé, puis enregistrez-le :
`npx supabase secrets set --project-ref wocgmmwwopzrgleeevof SEND_SMS_HOOK_SECRET="v1,whsec_..."`.
Une fois le hook actif, les champs Twilio du fournisseur Phone ne servent plus : c'est le hook qui envoie le SMS.

Enfin, dans **SQL Editor**, fixez le budget SMS : tant qu'il vaut 0, aucun SMS n'est envoyé.

```sql
-- Valeurs d'exemple : à remplacer par le tarif réel de votre contrat Nimba et le plafond choisi.
update app_config set value = '500000' where key = 'sms_monthly_budget_gnf';  -- plafond mensuel en GNF
update app_config set value = '150' where key = 'sms_unit_cost_gnf';          -- coût d'un SMS selon le contrat Nimba
```

Le hook n'a encore envoyé aucun SMS réel : à tester d'abord avec un numéro de l'équipe.

## 4 bis. Floutage des photos (décision C12)

Un visiteur Gratuit voit la photo principale nette et les suivantes floutées ; un visiteur Premium voit les photos publiques nettes ; une photo que sa propriétaire a choisie « floutée » reste floutée pour tous. Le flou est fabriqué par le serveur : l'original n'est jamais envoyé à qui n'y a pas droit.

**Fait le 17/11/2026 sur `wocgmmwwopzrgleeevof`, avec l'accord du propriétaire** : 0007 et 0009 appliquées, fonction déployée, 120 photos sur 120 floutées. Vérifié avec un membre Gratuit : photo principale nette, photos suivantes servies floutées, original refusé même par demande directe.

Pour un autre projet :

1. Base déjà installée : appliquez les migrations manquantes dans l'ordre (tableau du §1), au minimum 0007 puis 0009.
2. Déployez la fonction qui fabrique les versions floutées, puis lancez le rattrapage des photos existantes (3 photos par appel, à cause de la limite de calcul de Supabase : relancer jusqu'à obtenir `"traitees":0`). En cas de « Too many connections », relancer simplement.

```bash
npx supabase functions deploy blur-photos --remote=<ref> --use-api
curl -X POST https://<ref>.supabase.co/functions/v1/blur-photos -H "Authorization: Bearer <clé service_role>" -d "{}"
```

Tant qu'une photo n'a pas encore de version floutée, l'application affiche un emplacement neutre à sa place, jamais l'original. Une version floutée reste dans le stockage après suppression de sa photo, mais n'est plus servie à personne (nettoyage à prévoir).

## 5. Valider un profil de test (préproduction uniquement)

La console d'administration n'est pas encore construite. Pour qu'un profil de test apparaisse dans Découvrir et puisse publier dans la Communauté, sa vérification doit être validée.

**Méthode conseillée :** chaque compte d'essai se connecte, ajoute 3 photos et demande la vérification (Profil → Vérifier mon profil). Collez ensuite [supabase/preproduction/valider_verifications_essai.sql](../supabase/preproduction/valider_verifications_essai.sql) dans **SQL Editor**, adaptez la liste des numéros en tête du fichier, puis cliquez sur **Run**. Le premier numéro devient modérateur, et les demandes validées sont tracées dans le journal d'audit.

**Méthode manuelle** (sans trace dans le journal d'audit), dans **SQL Editor** (remplacez le numéro, sans le `+`) :

```sql
with membre as (select id from auth.users where phone = '224620000001')
update profile_photos set moderation = 'approved' where user_id in (select id from membre);

with membre as (select id from auth.users where phone = '224620000001')
update verification_requests
   set status = 'approved', decided_at = now(), decision_reason = 'Validation manuelle (préproduction)'
 where user_id in (select id from membre) and status = 'pending';

with membre as (select id from auth.users where phone = '224620000001')
update profiles set verification_status = 'approved' where id in (select id from membre);
```

Pour vous donner le rôle d'administrateur (utile pour la future console) :

```sql
insert into staff_roles (user_id, role)
select id, 'super_admin' from auth.users where phone = '224620000001';
```

### Profils d'essai : 20 femmes et 20 hommes fictifs

Pour remplir Découvrir pendant les essais, [supabase/preproduction/profils_essai.mjs](../supabase/preproduction/profils_essai.mjs) crée 40 profils fictifs, actifs et vérifiés, avec 3 photos chacun (silhouettes illustrées générées par le script, aucune photo de personne réelle). Les comptes utilisent une adresse en `.invalid` : aucun vrai numéro de téléphone ne peut tomber sur l'un d'eux. Relancer la création ne fait pas de doublon. Le script ajoute aussi des publications fictives dans la Communauté (questions, conseils, expériences), avec commentaires et réactions ; elles ne contiennent aucune coordonnée.

```bash
# Clé service_role : Project Settings → API Keys. Ne jamais l'écrire dans un fichier du projet.
SUPABASE_URL=https://wocgmmwwopzrgleeevof.supabase.co SUPABASE_SERVICE_ROLE_KEY=... node supabase/preproduction/profils_essai.mjs creer
SUPABASE_URL=https://wocgmmwwopzrgleeevof.supabase.co SUPABASE_SERVICE_ROLE_KEY=... node supabase/preproduction/profils_essai.mjs communaute
SUPABASE_URL=https://wocgmmwwopzrgleeevof.supabase.co SUPABASE_SERVICE_ROLE_KEY=... node supabase/preproduction/profils_essai.mjs supprimer
```

« supprimer » ne retire que les comptes d'essai marqués par le script (jamais les comptes de test par téléphone) ; leurs publications, commentaires et réactions disparaissent avec eux.

Créés le 17/11/2026 sur `wocgmmwwopzrgleeevof` : 40 profils sur 40 visibles dans Découvrir ; 16 publications, 18 commentaires et 75 réactions dans la Communauté. **À supprimer avant toute ouverture au public** : de faux profils présentés à de vrais membres seraient trompeurs.

## 6. Avant la production

- Créer un **projet séparé** pour la production (décision B5), avec sauvegardes et double authentification des administrateurs.
- Remplacer les textes légaux `v0-draft` (décision B1) et compléter la liste des termes interdits avec l'équipe de modération.
- Communauté : ne l'ouvrir au public qu'avec une modération opérationnelle (`community_enabled`, décision C13).
