// Génère les icônes de l'application ZAYA à partir du logo officiel.
// La flamme blanche (au-dessus du mot « Zaya ») est extraite en transparence puis posée sur le dégradé de marque.
// Usage : cd mobile/flutter_app/tool/icons && npm install && npm run icons
import sharp from 'sharp';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const app = process.argv[2] ?? join(import.meta.dirname, '..', '..');
const logo = join(app, 'assets', 'brand', 'zaya_logo.png');
const res = join(app, 'android', 'app', 'src', 'main', 'res');

const { data, info } = await sharp(logo).raw().toBuffer({ resolveWithObject: true });
const W = info.width;
const C = info.channels;
const green = (x, y) => data[(y * W + x) * C + 1];

// 1. Boîte englobante de la flamme : pixels blancs au-dessus du mot « Zaya », dans la zone centrale
//    (les bords du logo contiennent des reflets clairs qui ne font pas partie de la flamme).
const textTop = 1172; // ligne vide entre la flamme (fin ≈ 1167) et le mot « Zaya » (début ≈ 1188)
const minX = Math.round(W * 0.15), maxX = Math.round(W * 0.85);
let x0 = W, x1 = 0, y0 = textTop, y1 = 0;
for (let y = 20; y < textTop; y++) { // les 20 premières lignes du logo contiennent un liseré clair
  for (let x = minX; x < maxX; x++) {
    if (green(x, y) > 60) {
      x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y);
    }
  }
}
const m = 10;
x0 = Math.max(0, x0 - m); y0 = Math.max(20, y0 - m); x1 = Math.min(W - 1, x1 + m); y1 = Math.min(textTop - 1, y1 + m);
const cw = x1 - x0 + 1, ch = y1 - y0 + 1;
console.log(`flamme : x ${x0}–${x1}, y ${y0}–${y1} (${cw}×${ch})`);

// 2. Flamme en blanc, opacité déduite du canal vert (fond rose ≈ 0–20, blanc = 255) :
//    le « Z » rose devient transparent et laisse voir le fond, l'ombrage clair est conservé.
const flame = Buffer.alloc(cw * ch * 4);
for (let y = 0; y < ch; y++) {
  for (let x = 0; x < cw; x++) {
    const a = Math.max(0, Math.min(1, (green(x0 + x, y0 + y) - 50) / 205)); // fond rose (vert ≤ 45) → transparent
    const i = (y * cw + x) * 4;
    flame[i] = 255; flame[i + 1] = 255; flame[i + 2] = 255; flame[i + 3] = Math.round(a * 255);
  }
}
const flamePng = await sharp(flame, { raw: { width: cw, height: ch, channels: 4 } }).png().toBuffer();

/** Flamme centrée sur un carré transparent de `size` px, hauteur = `ratio` × size. */
async function flameLayer(size, ratio) {
  const h = Math.round(size * ratio);
  const w = Math.round((cw / ch) * h);
  const scaled = await sharp(flamePng).resize({ width: w, height: h }).png().toBuffer();
  return sharp({ create: { width: size, height: size, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } } })
    .composite([{ input: scaled, left: Math.round((size - w) / 2), top: Math.round((size - h) / 2) }])
    .png()
    .toBuffer();
}

/** Dégradé de marque #FF2D55 → #EC0677 (haut-gauche → bas-droite), coins arrondis facultatifs. */
function gradientSvg(size, radius) {
  return Buffer.from(
    `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}">` +
      `<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">` +
      `<stop offset="0" stop-color="#FF2D55"/><stop offset="1" stop-color="#EC0677"/></linearGradient></defs>` +
      `<rect width="${size}" height="${size}" rx="${radius}" ry="${radius}" fill="url(#g)"/></svg>`,
  );
}

async function composite(size, { radius = 0, ratio = 0.6 } = {}) {
  return sharp(gradientSvg(size, radius))
    .composite([{ input: await flameLayer(size, ratio) }])
    .png()
    .toBuffer();
}

const written = [];
async function save(path, buffer) {
  mkdirSync(join(path, '..'), { recursive: true });
  writeFileSync(path, buffer);
  written.push(path.replace(app, '').replaceAll('\\', '/'));
}

// 3. Android : icône adaptative (Android 8+) et icône classique (versions antérieures).
const densities = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };
for (const [name, scale] of Object.entries(densities)) {
  // Premier plan 108 dp ; la flamme reste dans la zone sûre de 66 dp (≈ 61 %).
  await save(join(res, `mipmap-${name}`, 'ic_launcher_foreground.png'), await flameLayer(Math.round(108 * scale), 0.58));
  const legacy = Math.round(48 * scale);
  await save(join(res, `mipmap-${name}`, 'ic_launcher.png'), await composite(legacy, { radius: legacy * 0.22, ratio: 0.62 }));
}

// 4. iOS : carrés pleins sans transparence (iOS applique son propre arrondi).
const iosDir = join(app, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset');
const contents = JSON.parse(readFileSync(join(iosDir, 'Contents.json'), 'utf8'));
const done = new Set();
for (const image of contents.images) {
  if (!image.filename || done.has(image.filename)) continue;
  const px = Math.round(parseFloat(image.size) * parseFloat(image.scale));
  const png = await sharp(await composite(px, { ratio: 0.6 })).flatten({ background: '#F5075E' }).png().toBuffer();
  await save(join(iosDir, image.filename), png);
  done.add(image.filename);
}

// 5. Web : icônes arrondies, icônes « maskable » (zone sûre de 80 %) et favicon.
const web = join(app, 'web');
await save(join(web, 'icons', 'Icon-192.png'), await composite(192, { radius: 42, ratio: 0.62 }));
await save(join(web, 'icons', 'Icon-512.png'), await composite(512, { radius: 112, ratio: 0.62 }));
await save(join(web, 'icons', 'Icon-maskable-192.png'), await composite(192, { ratio: 0.5 }));
await save(join(web, 'icons', 'Icon-maskable-512.png'), await composite(512, { ratio: 0.5 }));
await save(join(web, 'favicon.png'), await composite(48, { radius: 10, ratio: 0.66 }));

console.log(`${written.length} fichiers écrits :`);
for (const f of written) console.log('  ' + f);
