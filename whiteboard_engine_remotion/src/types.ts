// Types du storyboard (compatibles avec app.whiteboard_projects.storyboard_json).
// 1 scène = 1 séquence animée. Chaque bloc a un type qui pilote son animation.

export type BlockType =
  | "title"
  | "paragraph"
  | "definition"
  | "formula"
  | "exercise"
  | "correction"
  | "step"
  | "image" // illustration/photo (Pexels, asset) avec zoom Ken Burns
  | "list"; // puces révélées une par une

export type TransitionKind = "fade" | "slide" | "wipe" | "none";

export interface Block {
  id?: string;
  type: BlockType;
  content: string;
  order?: number;
  // Pour les blocs image : URL/chemin (dans public/) de l'illustration.
  src?: string;
  // Pour les blocs list : items à révéler en cascade (sinon content découpé par \n).
  items?: string[];
  // Pour les formules : clip Manim animé (dans public/) ; si absent -> KaTeX statique.
  videoSrc?: string;
  // Annotation manuscrite sur ce bloc clé : "circle" | "underline" | "highlight".
  emphasis?: "circle" | "underline" | "highlight";
  // Sur QUELS MOTS porte l'annotation. Un professeur entoure un mot, pas un
  // paragraphe entier. Si absent, l'annotation couvre tout le bloc (ancien
  // comportement). Ex. "n'est PAS continue".
  emphasis_target?: string;
  // Vitesse d'écriture de ce bloc : "slow" pour une notion clé (le prof ralentit),
  // "fast" pour une transition. Défaut "normal".
  write_speed?: "slow" | "normal" | "fast";
}

export interface Scene {
  id?: string;
  order?: number;
  title?: string;
  blocks: Block[];
  // Durée demandée par le storyboard (ms). Peut être écrasée par la durée
  // de la narration TTS si celle-ci est plus longue (voir render.mjs).
  duration_ms?: number;
  // Texte de narration (voix off). Si absent, dérivé du contenu des blocs.
  narration?: string;
  // Transition d'ENTRÉE de la scène (montage). Objet { kind } (schéma app) ou
  // chaîne. Défaut : alternance auto si absent/vide.
  transition?: TransitionKind | { kind?: TransitionKind };
  // Fond illustré optionnel (image en Ken Burns derrière le contenu).
  background_image?: string;
  // RAPPEL pédagogique : au début de cette scène, remonter vers une notion vue
  // plus haut, la ré-annoter (transitoire), puis redescendre continuer.
  // target = order (index 0-based) d'une scène PRÉCÉDENTE.
  recall?: { target: number; kind?: "circle" | "underline" };
}

// Style d'écriture choisi par l'étudiant :
//  - "handwriting" : le texte se TRACE, caractère par caractère, en police manuscrite,
//    comme un professeur qui écrit au tableau (effet GoodNotes) ;
//  - "typed" : révélation propre ligne par ligne, en police machine.
export type WritingStyle = "handwriting" | "typed";

export interface Storyboard {
  theme?: string; // "notebook" | "scientific"
  // Sujet du cours (affiché dans le bandeau haut).
  subject?: string;
  // Défaut : "handwriting" (c'est la signature visuelle recherchée).
  writing_style?: WritingStyle;
  scenes: Scene[];
}

// Manifest produit par narrate.py : une entrée par scène.
export interface NarrationEntry {
  scene_index: number;
  audio_path: string | null; // chemin d'un .wav dans public/, ou null
  duration_sec: number; // durée réelle de l'audio (0 si pas de voix)
}

// Props injectées à la composition au moment du rendu.
export interface SmartWhiteboardProps {
  storyboard: Storyboard;
  narration: NarrationEntry[];
  fps: number;
}
