// Construit les fichiers « à coller » dans Supabase > SQL Editor pour une suite de migrations :
//   supabase/deploy/mise_a_jour_<première>_<dernière>.sql
// Chaque migration ne s'exécute que si l'objet qu'elle crée est absent : le fichier est rejouable, et sûr même si une
// partie a déjà été appliquée en ligne. Une seule transaction : en cas d'erreur, rien n'est modifié.
// Usage : node supabase/deploy/build_mise_a_jour.mjs   (régénère les deux fichiers ci-dessous)
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');

/** Objet créé par chaque migration : s'il existe déjà, la migration est considérée comme appliquée. */
const marqueurs = {
  '0060_jetons_notifications': `to_regclass('public.member_push_tokens') is not null`,
  '0061_webhook_notifications': `exists (select 1 from pg_trigger where tgname = 'member_signals_push_webhook')`,
  '0062_messages_vocaux': `exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'messages' and column_name = 'message_kind')`,
  '0063_statuts_reception_messages': `exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'messages' and column_name = 'delivered_at')`,
  '0064_stickers_animes': `exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'messages' and column_name = 'sticker_id')`,
  '0065_badge_messages': `exists (select 1 from pg_proc where proname = 'unread_message_count')`,
  '0066_reactions_reponses': `exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'messages' and column_name = 'reply_to_id')`,
  '0067_socle_zaya2': `to_regclass('public.reward_ledger') is not null`,
  '0068_lot1_match_pulse_invitation': `to_regclass('public.daily_matches') is not null`,
  '0069_lot2_questions_surprise_challenge': `to_regclass('public.marriage_questions') is not null`,
  '0070_fleur_conversations_en_ligne': `to_regclass('public.conversation_hidden') is not null`,
  '0071_connexion_par_code': `to_regclass('private.member_pins') is not null`,
};

const lots = [
  {
    fichier: 'mise_a_jour_0060_0065.sql',
    titre: 'migrations 0060 à 0065 (notifications push, notes vocales, accusés de réception, animations, badge)',
    prealable: [
      [`to_regclass('public.member_signals') is null`, `Il manque la mise à jour 0055 à 0059 : collez-la d''abord.`],
    ],
    migrations: ['0060_jetons_notifications', '0061_webhook_notifications', '0062_messages_vocaux',
      '0063_statuts_reception_messages', '0064_stickers_animes', '0065_badge_messages'],
    apres: [],
  },
  {
    fichier: 'mise_a_jour_0066_0071.sql',
    titre: 'migrations 0066 à 0071 (réactions et réponses, ZAYA+, fleur, conversations, en ligne, connexion par code)',
    prealable: [
      [`not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'messages' and column_name = 'sticker_id')`,
        `Il manque la mise à jour 0060 à 0065 (notes vocales, animations) : collez-la d''abord.`],
    ],
    migrations: ['0066_reactions_reponses', '0067_socle_zaya2', '0068_lot1_match_pulse_invitation',
      '0069_lot2_questions_surprise_challenge', '0070_fleur_conversations_en_ligne', '0071_connexion_par_code'],
    apres: [
      '-- Secret « poivre » des codes de connexion, créé dans le coffre Vault s\'il n\'existe pas (valeur aléatoire,',
      '-- jamais écrite dans Git ni affichée).',
      'do $zaya$',
      'begin',
      "  if not exists (select 1 from vault.decrypted_secrets where name = 'zaya_pin_pepper') then",
      "    perform vault.create_secret(replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''),",
      "                                'zaya_pin_pepper');",
      '  end if;',
      'end $zaya$;',
    ],
  },
];

for (const lot of lots) {
  const out = [
    `-- ZAYA — MISE À JOUR : ${lot.titre}.`,
    '-- FICHIER GÉNÉRÉ par supabase/deploy/build_mise_a_jour.mjs : ne pas le modifier à la main.',
    '--',
    '-- Utilisation : Supabase > SQL Editor > New query, coller TOUT le contenu, puis « Run ».',
    '-- Une seule transaction : en cas d’erreur, rien n’est modifié. Chaque migration déjà présente est ignorée',
    '-- (voir les notes « déjà présente » dans les résultats) : le fichier peut être rejoué sans risque.',
    '',
    'begin;',
    '',
  ];
  if (lot.prealable.length) {
    out.push('do $zaya$', 'begin');
    for (const [cond, message] of lot.prealable) out.push(`  if ${cond} then raise exception '${message}'; end if;`);
    out.push('end $zaya$;', '');
  }
  for (const m of lot.migrations) {
    const sql = readFileSync(join(root, 'migrations', `${m}.sql`), 'utf8').replace(/\r\n/g, '\n').trim();
    const tag = `$m${m.slice(0, 4)}$`;
    if (sql.includes(tag)) throw new Error(`le marqueur ${tag} apparaît dans ${m}`);
    out.push(`-- ═════════════════════════════ ${m}.sql`);
    out.push('do $zaya$', 'begin');
    out.push(`  if ${marqueurs[m]} then`);
    out.push(`    raise notice '${m} : déjà présente, ignorée';`);
    out.push('  else');
    out.push(`    execute ${tag}`);
    out.push(sql);
    out.push(`${tag};`);
    out.push(`    raise notice '${m} : appliquée';`);
    out.push('  end if;');
    out.push('end $zaya$;', '');
  }
  out.push(...lot.apres);
  if (lot.apres.length) out.push('');
  out.push('commit;', '');
  writeFileSync(join(root, 'deploy', lot.fichier), out.join('\n'));
  console.log(`Fichier généré : supabase/deploy/${lot.fichier}`);
}
