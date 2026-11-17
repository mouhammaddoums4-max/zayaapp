// ZAYA — floutage d'une image RVBA, sans dépendance (testable aussi avec Node).
// 1. Réduction à `petiteLargeur` pixels de large par moyenne de zones : les détails de l'original sont détruits,
//    l'image floutée ne permet pas de le reconstituer.
// 2. Agrandissement bilinéaire jusqu'à `sortieLargeur`, puis deux passes de flou en boîte pour effacer les traces
//    de la grille.

export interface ImageRvba {
  data: Uint8ClampedArray;
  width: number;
  height: number;
}

export function flouterRvba(
  src: Uint8Array | Uint8ClampedArray,
  w: number,
  h: number,
  sortieLargeur = 360,
  petiteLargeur = 12,
): ImageRvba {
  const pw = Math.min(petiteLargeur, w);
  const ph = Math.max(1, Math.round((h * pw) / w));

  // 1. Moyenne par zones
  const petit = new Float32Array(pw * ph * 3);
  for (let y = 0; y < ph; y++) {
    const y0 = Math.floor((y * h) / ph);
    const y1 = Math.max(y0 + 1, Math.floor(((y + 1) * h) / ph));
    for (let x = 0; x < pw; x++) {
      const x0 = Math.floor((x * w) / pw);
      const x1 = Math.max(x0 + 1, Math.floor(((x + 1) * w) / pw));
      let r = 0, g = 0, b = 0, n = 0;
      for (let yy = y0; yy < y1; yy++) {
        for (let xx = x0; xx < x1; xx++) {
          const i = (yy * w + xx) * 4;
          r += src[i];
          g += src[i + 1];
          b += src[i + 2];
          n++;
        }
      }
      const o = (y * pw + x) * 3;
      petit[o] = r / n;
      petit[o + 1] = g / n;
      petit[o + 2] = b / n;
    }
  }

  // 2. Agrandissement bilinéaire
  const W = sortieLargeur;
  const H = Math.max(1, Math.round((h * W) / w));
  const grand = new Float32Array(W * H * 3);
  for (let y = 0; y < H; y++) {
    const fy = Math.min(ph - 1, Math.max(0, ((y + 0.5) * ph) / H - 0.5));
    const ya = Math.floor(fy), yb = Math.min(ph - 1, ya + 1), ty = fy - ya;
    for (let x = 0; x < W; x++) {
      const fx = Math.min(pw - 1, Math.max(0, ((x + 0.5) * pw) / W - 0.5));
      const xa = Math.floor(fx), xb = Math.min(pw - 1, xa + 1), tx = fx - xa;
      for (let c = 0; c < 3; c++) {
        const p = (xx: number, yy: number) => petit[(yy * pw + xx) * 3 + c];
        const haut = p(xa, ya) + (p(xb, ya) - p(xa, ya)) * tx;
        const bas = p(xa, yb) + (p(xb, yb) - p(xa, yb)) * tx;
        grand[(y * W + x) * 3 + c] = haut + (bas - haut) * ty;
      }
    }
  }

  // 3. Lissage : flou en boîte séparable, deux passes
  const rayon = Math.max(2, Math.round(W / 24));
  const tampon = new Float32Array(grand.length);
  for (let passe = 0; passe < 2; passe++) {
    boite(grand, tampon, W, H, rayon, true);
    boite(tampon, grand, W, H, rayon, false);
  }

  const data = new Uint8ClampedArray(W * H * 4);
  for (let i = 0, j = 0; i < W * H; i++, j += 3) {
    data[i * 4] = grand[j];
    data[i * 4 + 1] = grand[j + 1];
    data[i * 4 + 2] = grand[j + 2];
    data[i * 4 + 3] = 255;
  }
  return { data, width: W, height: H };
}

/** Moyenne glissante sur 2·rayon+1 pixels, horizontalement ou verticalement, bords prolongés. */
function boite(src: Float32Array, dst: Float32Array, W: number, H: number, rayon: number, horizontal: boolean) {
  const longueur = horizontal ? W : H;
  const lignes = horizontal ? H : W;
  const n = 2 * rayon + 1;
  const indice = (ligne: number, k: number) => {
    const kk = Math.min(longueur - 1, Math.max(0, k));
    return (horizontal ? ligne * W + kk : kk * W + ligne) * 3;
  };
  for (let ligne = 0; ligne < lignes; ligne++) {
    for (let c = 0; c < 3; c++) {
      let somme = 0;
      for (let k = -rayon; k <= rayon; k++) somme += src[indice(ligne, k) + c];
      for (let k = 0; k < longueur; k++) {
        dst[indice(ligne, k) + c] = somme / n;
        somme += src[indice(ligne, k + rayon + 1) + c] - src[indice(ligne, k - rayon) + c];
      }
    }
  }
}
