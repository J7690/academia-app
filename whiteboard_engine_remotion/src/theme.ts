// Thèmes visuels. "notebook" = fond papier clair (GoodNotes), "scientific" = fond sombre.

export interface Theme {
  background: string;
  paper: string;
  rule: string; // couleur des lignes du cahier (bien visibles)
  ruleGap: number; // espacement des lignes (px)
  margin: string; // ligne de marge verticale (style cahier)
  ink: string;
  muted: string;
  accent: string;
  accent2: string;
  highlight: string; // couleur de surlignage (feutre)
  formulaBg: string;
  formulaBorder: string;
}

export const THEMES: Record<string, Theme> = {
  notebook: {
    background: "#fbfaf5",
    paper: "#fffdf7", // papier légèrement crème (cahier réel)
    rule: "#a9c7e8", // lignes bleu cahier, BIEN visibles
    ruleGap: 62,
    margin: "#e8896b", // marge rouge
    ink: "#20303f",
    muted: "#5b6472",
    accent: "#1aa179",
    accent2: "#3b6fe0",
    highlight: "#ffe066",
    formulaBg: "#eef5ff",
    formulaBorder: "#cfe0fb",
  },
  scientific: {
    background: "#0a192f",
    paper: "#0a192f",
    rule: "#1c3d68",
    ruleGap: 62,
    margin: "#28527a",
    ink: "#ffffff",
    muted: "#9fb3c8",
    accent: "#69f0ae",
    accent2: "#4c9aff",
    highlight: "#3d5a80",
    formulaBg: "#0f2540",
    formulaBorder: "#1c3d68",
  },
};

export const getTheme = (name?: string): Theme =>
  THEMES[name ?? "notebook"] ?? THEMES.notebook;

export const VIDEO = { width: 720, height: 1280, fps: 30 };

// ── Polices ────────────────────────────────────────────────────────────────
// "handwriting" : police manuscrite lisible, avec repli sur des manuscrites
// courantes puis sur une cursive générique si la police n'est pas chargée.
// "typed" : police machine (lecture confortable, style manuel scolaire).
export const FONTS = {
  handwriting: "'Caveat', 'Patrick Hand', 'Segoe Script', cursive",
  typed: "Inter, 'Helvetica Neue', Arial, sans-serif",
};

/** Famille de police à utiliser selon le style d'écriture du storyboard. */
export const fontFor = (style?: string): string =>
  style === "typed" ? FONTS.typed : FONTS.handwriting;

/**
 * L'écriture manuscrite est plus petite à taille de police égale (hampes courtes,
 * lettres serrées) : on l'agrandit pour conserver la même lisibilité à l'écran.
 */
export const fontScaleFor = (style?: string): number => (style === "typed" ? 1 : 1.28);
