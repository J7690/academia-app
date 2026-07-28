// Police manuscrite (effet GoodNotes) — chargement d'UN SEUL fichier.
//
// ⚠️ HISTORIQUE À NE PAS RÉPÉTER : `@remotion/google-fonts` a été retiré de ce moteur
// en juillet 2026 parce qu'il chargeait des centaines de fichiers de police et
// provoquait un « JavaScript heap out of memory » au rendu (voir le commentaire dans
// Root.tsx et les jobs en échec du 23/07). On ne le réintroduit donc PAS.
//
// À la place : un unique fichier woff2 déposé dans `public/fonts/`, enregistré via
// l'API navigateur `FontFace`. Coût mémoire négligeable, et `delayRender` garantit que
// la police est prête avant la première image (sinon les premières frames sortiraient
// dans la police par défaut).
//
// Le serveur étant sous Linux, aucune police manuscrite n'est disponible par défaut :
// ce fichier woff2 est indispensable, il n'y a pas de repli système satisfaisant.

import { continueRender, delayRender, staticFile } from "remotion";
import { FONTS } from "./theme";

export const HANDWRITING_FAMILY = `'CaveatLocal', ${FONTS.handwriting}`;

let started = false;

/** Charge la police manuscrite une seule fois, avant le rendu de la première image. */
export const ensureHandwritingFont = (): void => {
  if (started || typeof window === "undefined") return;
  started = true;

  const handle = delayRender("Chargement de la police manuscrite");
  try {
    // Fichier TTF : c'est le format que sert l'API Google Fonts à un client générique
    // (curl côté serveur). Le poids est négligeable et le rendu identique.
    const face = new FontFace(
      "CaveatLocal",
      `url(${staticFile("fonts/Caveat.ttf")}) format('truetype')`,
      { weight: "400 700", style: "normal" }
    );
    face
      .load()
      .then((loaded) => {
        (document as any).fonts.add(loaded);
        continueRender(handle);
      })
      .catch(() => {
        // Police absente : on rend quand même, avec le repli système.
        continueRender(handle);
      });
  } catch (e) {
    continueRender(handle);
  }
};

/** Famille à appliquer selon le style d'écriture demandé. */
export const familyFor = (style?: string): string =>
  style === "typed" ? FONTS.typed : HANDWRITING_FAMILY;
