// Tests ZAYA — niveau d'études (liste administrable) et nombre d'enfants ; filtres Premium correspondants (0052).
// Membres dédiés, pour ne pas dépendre de l'état laissé par les autres sections.
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

export async function etudesEnfantsTests({ db, test, assert, as, rpc, fails, U, seedMember }) {
  console.log('\nProfil : niveau d’études et enfants, filtres Premium (0052)');
  const E = {
    nene: '00000000-0000-0000-0000-0000000052a1',
    master: '00000000-0000-0000-0000-0000000052a2', // Master, sans enfant
    bac: '00000000-0000-0000-0000-0000000052a3', // Baccalauréat, 2 enfants
    vide: '00000000-0000-0000-0000-0000000052a4', // rien renseigné
  };
  await seedMember(E.nene, 'Néné', 'femme', '1996-10-10', null);
  await seedMember(E.master, 'Condé', 'homme', '1990-11-11', null);
  await seedMember(E.bac, 'Touré', 'homme', '1989-12-12', null);
  await seedMember(E.vide, 'Keïta', 'homme', '1991-01-01', null);
  await as(E.master, `update profiles set education_key = 'master', children_count = 0 where id = $1`, [E.master]);
  await as(E.bac, `update profiles set education_key = 'bac', children_count = 2 where id = $1`, [E.bac]);

  const prefs = (sql, params = []) => as(E.nene, `update discovery_preferences set ${sql} where user_id = $1`, [E.nene, ...params]);
  const vus = async () => {
    const r = await as(E.nene, `select id from discovery_feed(50)`);
    const ids = new Set(r.rows.map((x) => x.id));
    return ['master', 'bac', 'vide'].filter((k) => ids.has(E[k])).join(',');
  };

  await test('liste des niveaux lue depuis le serveur (membre et visiteur), niveaux inactifs masqués', async () => {
    const m = await as(E.nene, `select key from education_levels order by position`);
    assert(m.rows.length >= 9 && m.rows[0].key === 'none', JSON.stringify(m.rows.map((x) => x.key)));
    const a = await as(null, `select count(*)::int as n from education_levels`);
    assert(a.rows[0].n === m.rows.length, 'visiteur');
    await db.query(`update education_levels set active = false where key = 'none'`);
    try {
      const r = await as(E.nene, `select count(*)::int as n from education_levels where key = 'none'`);
      assert(r.rows[0].n === 0, 'niveau inactif visible');
    } finally {
      await db.query(`update education_levels set active = true where key = 'none'`);
    }
    await fails(as(E.nene, `insert into education_levels (key, label_fr, label_en) values ('x', 'X', 'X')`), /row-level security|permission denied/i);
  });

  await test('libellés exacts, accents compris (0056) : rien d’abîmé dans la liste ni dans les profils', async () => {
    const l = await db.query(`select key, label_fr from education_levels where key in ('none', 'middle', 'bac')`);
    const libelles = Object.fromEntries(l.rows.map((r) => [r.key, r.label_fr]));
    assert(libelles.none === 'Sans diplôme' && libelles.middle === 'Collège (BEPC)' && libelles.bac === 'Baccalauréat',
      JSON.stringify(libelles));
    const abimes = await db.query(
      `select count(*)::int as n from profiles where education_level like '%Ã%' or education_level like '%' || chr(65533) || '%'`,
    );
    assert(abimes.rows[0].n === 0, `${abimes.rows[0].n} profil(s) avec un libellé abîmé`);
  });

  await test('0056 répare des libellés abîmés (encodage) et les recopie dans les profils', async () => {
    // État observé sur la préproduction : accents abîmés dans la liste et dans la copie des profils.
    await db.query(`update education_levels set label_fr = 'Sans diplÃ´me' where key = 'none'`);
    await db.query(`update education_levels set label_fr = 'BaccalaurÃ©at' where key = 'bac'`);
    await db.query(`update profiles set education_key = 'bac' where id = $1`, [E.bac]);
    const avant = await db.query(`select education_level from profiles where id = $1`, [E.bac]);
    assert(avant.rows[0].education_level === 'BaccalaurÃ©at', `préparation : ${avant.rows[0].education_level}`);
    const sql = readFileSync(join(dirname(fileURLToPath(import.meta.url)), '..', 'migrations', '0056_libelles_etudes_et_profils.sql'), 'utf8');
    await db.exec(sql);
    const l = await db.query(`select key, label_fr from education_levels where key in ('none', 'bac') order by key`);
    assert(l.rows.map((r) => r.label_fr).join('|') === 'Baccalauréat|Sans diplôme', JSON.stringify(l.rows));
    const apres = await db.query(`select education_level from profiles where id = $1`, [E.bac]);
    assert(apres.rows[0].education_level === 'Baccalauréat', `profil : ${apres.rows[0].education_level}`);
    await db.exec(sql); // une seconde application ne change rien
  });

  await test('le niveau choisi donne le libellé affiché ; une clé inconnue est refusée ; retrait possible', async () => {
    const r = await db.query(`select education_level from profiles where id = $1`, [E.master]);
    assert(r.rows[0].education_level === 'Master (Bac +5)', r.rows[0].education_level);
    await fails(as(E.vide, `update profiles set education_key = 'inconnu' where id = $1`, [E.vide]), /foreign key|violates/i);
    await as(E.vide, `update profiles set education_key = 'licence' where id = $1`, [E.vide]);
    await as(E.vide, `update profiles set education_key = null where id = $1`, [E.vide]);
    const v = await db.query(`select education_level, education_key from profiles where id = $1`, [E.vide]);
    assert(v.rows[0].education_level === null && v.rows[0].education_key === null, JSON.stringify(v.rows[0]));
  });

  await test('Gratuit : filtres études et enfants refusés', async () => {
    await fails(prefs(`education_keys = '{master}'`), /PREMIUM_REQUIRED/);
    await fails(prefs(`children_max = 0`), /PREMIUM_REQUIRED/);
    assert((await vus()) === 'master,bac,vide', `vus : ${await vus()}`);
  });

  await test('Premium : niveau d’études et nombre d’enfants au plus ; non renseigné = exclu', async () => {
    const g = await rpc(U.admin, 'admin_grant_premium', [E.nene, '2026-01-01T00:00:00Z', '2099-01-01T00:00:00Z', 'Test', 'compte de test']);
    try {
      await prefs(`education_keys = '{master,doctorate}'`);
      assert((await vus()) === 'master', `études : ${await vus()}`);
      await prefs(`education_keys = '{}', children_max = 0`);
      assert((await vus()) === 'master', `sans enfant : ${await vus()}`);
      await prefs(`children_max = 2`);
      assert((await vus()) === 'master,bac', `2 au plus : ${await vus()}`);
      await prefs(`children_max = null`);
      assert((await vus()) === 'master,bac,vide', `sans filtre : ${await vus()}`);
    } finally {
      await rpc(U.admin, 'admin_revoke_premium', [g, 'fin du test']);
      await db.query(`update discovery_preferences set education_keys = '{}', children_max = null where user_id = $1`, [E.nene]);
    }
  });
}
