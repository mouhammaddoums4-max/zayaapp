// Construit supabase/deploy/zaya_installation.sql : toutes les migrations puis les données de référence,
// dans une seule transaction, prêt à coller dans l'éditeur SQL d'un projet Supabase.
// Usage : cd supabase/tests && npm run build:install
import { readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
export const installPath = join(root, 'deploy', 'zaya_installation.sql');

/** Fins de ligne unifiées : Git sous Windows peut convertir les fichiers en CRLF. */
export const normalizeEol = (text) => text.replace(/\r\n/g, '\n');
const read = (...path) => normalizeEol(readFileSync(join(root, ...path), 'utf8')).trim();

export function buildInstallSql() {
  const migrations = readdirSync(join(root, 'migrations'))
    .filter((f) => f.endsWith('.sql'))
    .sort();
  const parts = [
    '-- ZAYA — installation complète de la base de données.',
    '-- FICHIER GÉNÉRÉ AUTOMATIQUEMENT : ne pas le modifier à la main.',
    '-- Source : supabase/migrations/*.sql puis supabase/seed/seed.sql.',
    '-- Régénérer : cd supabase/tests && npm run build:install',
    '--',
    '-- Utilisation : Supabase > SQL Editor > New query, coller tout le contenu, puis « Run ».',
    '-- Tout est appliqué en une seule transaction : en cas d’erreur, rien n’est modifié.',
    '',
    'begin;',
    '',
    [
      'do $zaya$',
      'begin',
      "  if to_regclass('public.profiles') is not null then",
      "    raise exception 'ZAYA semble déjà installé (la table public.profiles existe). Aucune modification n''a été faite.';",
      '  end if;',
      'end;',
      '$zaya$;',
    ].join('\n'),
  ];
  for (const file of migrations) {
    parts.push('', `-- ════════════════════════ ${file}`, read('migrations', file));
  }
  parts.push('', '-- ════════════════════════ seed.sql', read('seed', 'seed.sql'));
  parts.push('', 'commit;', '');
  return parts.join('\n');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  writeFileSync(installPath, buildInstallSql(), 'utf8');
  console.log(`Fichier généré : ${installPath}`);
}
