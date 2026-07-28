import React from "react";
import {
  AbsoluteFill,
  Audio,
  Easing,
  Sequence,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
  interpolate,
} from "remotion";
import type { SmartWhiteboardProps, Scene, Block, NarrationEntry } from "./types";
import { getTheme, VIDEO } from "./theme";
import { renderBlock } from "./blocks";
import { GlowSweep } from "./effects";
import { AnnotationOverlay, annotationSeconds } from "./Annotation";
import { ensureHandwritingFont } from "./fonts";

const MIN_SCENE_SEC = 3;
const TAIL_SEC = 0.6;
const RECALL_SEC = 4.0; // budget d'un rappel (remonter + maintenir + redescendre)

const PAD_LEFT = 80;
const PAD_RIGHT = 48;
const GAP = 36;
// Hauteur réservée en haut : le bandeau (sujet, numéro de scène) est FIXE tandis que
// la feuille défile. Le contenu démarre sous cette zone, et un dégradé de la couleur du
// papier masque ce qui remonte derrière — sinon le texte traverse le bandeau.
const TOP_SAFE = 132;
const CONTENT_W = VIDEO.width - PAD_LEFT - PAD_RIGHT;

const hasRecall = (s: Scene) =>
  !!s.recall && typeof s.recall.target === "number" && s.recall.target >= 0;

// ── Durées et séquencement ─────────────────────────────────────────────────
// Vitesses d'écriture (caractères/seconde) — doivent rester alignées sur CPS
// dans blocks.tsx, qui pilote l'animation réelle.
const CPS_SEC: Record<string, number> = { slow: 13, normal: 20, fast: 30 };
const BLOCK_GAP_SEC = 0.35; // respiration entre deux blocs
const HOLD_SEC = 1.6; // maintien d'une annotation avant effacement

/** Le bloc porte-t-il une annotation (fournie par l'IA ou ajoutée automatiquement) ? */
const blockHasEmphasis = (b: Block, isKey: boolean) => !!b.emphasis || isKey;

/**
 * Plan temporel d'une scène : pour chaque bloc, le temps d'écriture puis, le cas
 * échéant, le temps d'annotation pendant lequel LA CAMÉRA NE BOUGE PAS.
 *
 * Principe (confirmé par les bonnes pratiques de montage pédagogique) : la caméra
 * doit se poser AVANT que le spectateur ait à lire, et ne pas bouger pendant qu'il
 * interprète un détail. On enchaîne donc : écrire → s'arrêter → annoter → avancer.
 */
interface BlockPlan {
  writeF: number;
  annotF: number; // 0 si pas d'annotation
  gapF: number;
}

export const planScene = (
  scene: Scene,
  fps: number,
  handwriting: boolean
): { plans: BlockPlan[]; totalF: number } => {
  const blocks = scene.blocks || [];
  const keyIdx = pickKeyBlockIndex(blocks);
  const plans = blocks.map((b, i) => {
    let writeF: number;
    if (!handwriting) writeF = Math.round(fps * 0.5);
    else if (b.type === "image" || b.type === "formula") writeF = Math.round(fps * 0.8);
    else {
      const cps = CPS_SEC[b.write_speed ?? (b.type === "definition" ? "slow" : "normal")] ?? 20;
      writeF = Math.ceil(((b.content || "").length / cps) * fps);
    }
    const annotF = blockHasEmphasis(b, i === keyIdx)
      ? Math.round(annotationSeconds(HOLD_SEC) * fps)
      : 0;
    return { writeF, annotF, gapF: Math.round(BLOCK_GAP_SEC * fps) };
  });
  const totalF = plans.reduce((s, p) => s + p.writeF + p.annotF + p.gapF, 0);
  return { plans, totalF };
};

export const sceneDurationInFrames = (
  scene: Scene,
  narration: NarrationEntry | undefined,
  fps: number,
  handwriting = true
): number => {
  const narrSec = narration?.duration_sec ?? 0;
  // La scène dure au moins le temps d'écrire ET d'annoter son contenu : sinon la
  // caméra passait à la suite avant la fin du geste, et les soulignements/encerclages
  // n'étaient jamais visibles à l'écran (défaut constaté sur le rendu complet).
  const { totalF } = planScene(scene, fps, handwriting);
  const contentF = totalF + Math.round(TAIL_SEC * fps);
  const base = Math.max(
    contentF,
    narrSec > 0 ? Math.round((narrSec + TAIL_SEC) * fps) : 0,
    Math.round(MIN_SCENE_SEC * fps)
  );
  const recall = hasRecall(scene) ? Math.round(RECALL_SEC * fps) : 0;
  return Math.max(1, base + recall);
};

export const totalDurationInFrames = (props: SmartWhiteboardProps): number => {
  const { storyboard, narration, fps } = props;
  const hand = (storyboard.writing_style ?? "handwriting") !== "typed";
  return storyboard.scenes.reduce(
    (sum, sc, i) => sum + sceneDurationInFrames(sc, narration[i], fps, hand),
    0
  );
};

// ── Estimation de hauteur d'un bloc (px) ────────────────────────────────────
// L'écriture manuscrite change la métrique : police 28 % plus grande (donc lignes
// plus hautes) mais lettres plus étroites (donc plus de caractères par ligne).
// Sans cet ajustement, les blocs se chevaucheraient en mode manuscrit.
const lineCount = (text: string, perLine: number) =>
  Math.max(1, Math.ceil((text || "").length / perLine));

function estimateHeight(b: Block, hand: boolean): number {
  const perLine = hand ? 30 : 24;
  const lineH = hand ? 84 : 72;
  switch (b.type) {
    case "title":
      return 200;
    case "formula":
      return b.videoSrc ? 320 : 230;
    case "definition":
      return lineCount(b.content, perLine) * lineH + 34;
    case "exercise":
    case "correction":
      return lineCount(b.content, perLine) * lineH + 64;
    case "list": {
      const items = b.items?.length ?? (b.content || "").split("\n").filter(Boolean).length;
      return Math.max(1, items) * lineH + 20;
    }
    case "image":
      return 380;
    default:
      return lineCount(b.content, hand ? 28 : 22) * lineH + 24;
  }
}

// Choix du bloc clé d'une scène pour l'annotation manuscrite auto.
function pickKeyBlockIndex(blocks: Block[]): number {
  for (const t of ["definition", "correction", "formula", "exercise"]) {
    const i = blocks.findIndex((b) => b.type === t);
    if (i >= 0) return i;
  }
  return blocks.findIndex((b) => b.type !== "title");
}

interface Item {
  block: Block;
  y: number;
  h: number;
  appear: number; // début de l'écriture
  sceneIndex: number;
  writeEnd: number; // fin de l'écriture = début de l'annotation
  annotEnd: number; // fin de l'annotation (= writeEnd s'il n'y en a pas)
}

interface RecallEvent {
  start: number; // frame de début du rappel
  targetY: number; // position à l'écran de la notion rappelée
  itemY: number; // top de l'item cible (pour l'annotation)
  itemH: number;
  kind: "circle" | "underline";
}

export const SmartWhiteboard: React.FC<SmartWhiteboardProps> = ({
  storyboard,
  narration,
  fps,
}) => {
  const theme = getTheme(storyboard.theme);
  const frame = useCurrentFrame();
  const { height: H } = useVideoConfig();
  const scenes = storyboard.scenes;
  // Style d'écriture choisi par l'étudiant. Défaut : manuscrit (signature visuelle).
  const writingStyle = storyboard.writing_style ?? "handwriting";
  // Charge la police manuscrite (un seul fichier) avant la première image.
  ensureHandwritingFont();

  // 1) Timeline des scènes.
  const hand = writingStyle !== "typed";
  const sceneFrames = scenes.map((s, i) => sceneDurationInFrames(s, narration[i], fps, hand));
  const sceneStart: number[] = [];
  sceneFrames.reduce((acc, f, i) => ((sceneStart[i] = acc), acc + f), 0);

  // 2) Items (blocs) : Y cumulé + frame d'apparition. Les scènes à rappel
  //    décalent l'apparition de leurs blocs après le budget de rappel.
  const items: Item[] = [];
  const firstItemOfScene: number[] = [];
  // Marge haute : le contenu commence SOUS le bandeau fixe (sujet + numéro de scène).
  // Sans elle, le titre de la première scène chevauchait la pastille du bandeau.
  let y = TOP_SAFE;
  scenes.forEach((scene, si) => {
    const blocks = scene.blocks || [];
    // Le curseur avance bloc par bloc : écriture, puis annotation, puis respiration.
    // (Auparavant les blocs étaient répartis uniformément dans la scène, sans lien
    // avec le temps réel d'écriture — d'où des annotations déclenchées hors champ.)
    let cursor = sceneStart[si] + (hasRecall(scene) ? Math.round(RECALL_SEC * fps) : 0);
    const { plans } = planScene(scene, fps, hand);
    firstItemOfScene[si] = items.length;
    const keyIdx = pickKeyBlockIndex(blocks);
    blocks.forEach((block, bi) => {
      let b = block;
      if (bi === keyIdx && !block.emphasis) {
        const kind = block.type === "formula" ? "circle" : "underline";
        b = { ...block, emphasis: kind };
      }
      const h = estimateHeight(b, hand);
      const p = plans[bi];
      items.push({
        block: b,
        y,
        h,
        appear: cursor,
        sceneIndex: si,
        writeEnd: cursor + p.writeF,
        annotEnd: cursor + p.writeF + p.annotF,
      });
      cursor += p.writeF + p.annotF + p.gapF;
      y += h + GAP;
    });
  });
  const docHeight = y + 220;

  // Position de défilement pour que la ligne en cours d'écriture reste dans la zone
  // confortable de lecture (≈60 % de la hauteur), sans jamais remonter le contenu
  // au-dessus de la zone protégée par le bandeau.
  const writeTarget = (it: Item) => Math.max(0, it.y + it.h - H * 0.6);

  // 3) Keyframes de défilement (écriture) + détours de rappel.
  //
  // La caméra se POSE sur le bloc au début de son écriture, puis reste IMMOBILE
  // jusqu'à la fin de son annotation. C'est la règle de montage : « le plan se pose
  // avant qu'on ait à lire, et ne bouge plus pendant qu'on interprète un détail ».
  const kf: Array<{ f: number; y: number }> = [{ f: 0, y: 0 }];
  items.forEach((it) => {
    const target = writeTarget(it);
    kf.push({ f: it.appear, y: target });
    // Immobilité pendant l'écriture ET l'annotation.
    kf.push({ f: Math.max(it.appear + 1, it.annotEnd), y: target });
  });

  const recalls: RecallEvent[] = [];
  scenes.forEach((scene, si) => {
    if (!hasRecall(scene)) return;
    const target = scene.recall!.target;
    if (target < 0 || target >= si) return; // doit référencer une scène précédente
    const idx = firstItemOfScene[target];
    const targetItem = items[idx];
    if (!targetItem) return;
    const rs = sceneStart[si];
    // position de base (là où on était) = dernier item écrit avant rs
    let basePos = 0;
    for (const it of items) {
      if (it.appear <= rs) basePos = writeTarget(it);
      else break;
    }
    const recallY = Math.max(0, targetItem.y - H * 0.28);
    kf.push({ f: rs, y: basePos });
    kf.push({ f: rs + Math.round(fps * 0.9), y: recallY });
    kf.push({ f: rs + Math.round(fps * 2.7), y: recallY });
    kf.push({ f: rs + Math.round(fps * 3.6), y: basePos });
    recalls.push({
      start: rs,
      targetY: recallY,
      itemY: targetItem.y,
      itemH: targetItem.h,
      kind: scene.recall!.kind === "underline" ? "underline" : "circle",
    });
  });

  // Tri + monotonie stricte des keyframes.
  kf.sort((a, b) => a.f - b.f);
  const xs: number[] = [];
  const ys: number[] = [];
  for (const k of kf) {
    if (xs.length && k.f <= xs[xs.length - 1]) {
      ys[ys.length - 1] = k.y; // même frame -> garder la dernière valeur
    } else {
      xs.push(k.f);
      ys.push(k.y);
    }
  }
  // Adoucissement du mouvement : une interpolation linéaire donne un défilement
  // mécanique, « de machine ». L'accélération/décélération progressive imite le geste
  // d'un opérateur — c'est ce qui distingue un mouvement de caméra soigné.
  const scroll = interpolate(frame, xs, ys, {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.inOut(Easing.cubic),
  });

  // 4) Scène active (sous-titre).
  const activeScene = sceneStart.findIndex(
    (st, i) => frame >= st && frame < st + sceneFrames[i]
  );
  const activeNarration = activeScene >= 0 ? scenes[activeScene]?.narration : undefined;

  const g = theme.ruleGap;
  const paperBg =
    `repeating-linear-gradient(${theme.paper} 0px, ${theme.paper} ${g - 2}px, ` +
    `${theme.rule} ${g - 2}px, ${theme.rule} ${g}px)`;

  return (
    <AbsoluteFill style={{ background: theme.background }}>
      {/* Couche papier qui défile */}
      <AbsoluteFill style={{ overflow: "hidden" }}>
        <div
          style={{
            position: "absolute",
            top: 0,
            left: 0,
            right: 0,
            height: docHeight,
            backgroundColor: theme.paper,
            backgroundImage: paperBg,
            transform: `translateY(${-scroll}px)`,
          }}
        >
          <div style={{ position: "absolute", top: 0, bottom: 0, left: 58, width: 3, background: theme.margin, opacity: 0.7 }} />

          {items.map((it, i) => (
            <div key={i} style={{ position: "absolute", top: it.y, left: PAD_LEFT, width: CONTENT_W }}>
              {renderBlock(
                it.block,
                theme,
                it.appear,
                i,
                writingStyle,
                // L'annotation démarre exactement à la fin de l'écriture du bloc :
                // c'est le geste du professeur qui relit puis souligne. La caméra est
                // immobile pendant tout ce temps (cf. keyframes ci-dessus).
                it.writeEnd
              )}
            </div>
          ))}

          {/* Annotations de RAPPEL (transitoires) sur les notions rappelées */}
          {recalls.map((r, i) => (
            <div key={`r${i}`} style={{ position: "absolute", top: r.itemY, left: PAD_LEFT, width: CONTENT_W, height: r.itemH }}>
              <AnnotationOverlay kind={r.kind} color={theme.accent} delay={r.start + Math.round(fps * 0.9)} holdSec={1.4} />
            </div>
          ))}
        </div>
      </AbsoluteFill>

      {/* Masque haut : le contenu qui remonte disparaît PROGRESSIVEMENT derrière le
          bandeau, au lieu de le traverser. Dégradé de la couleur du papier. */}
      <div
        style={{
          position: "absolute",
          top: 0,
          left: 0,
          right: 0,
          height: TOP_SAFE - 18,
          background: `linear-gradient(${theme.paper} 62%, ${theme.paper}00 100%)`,
          pointerEvents: "none",
        }}
      />

      {/* Bandeau haut FIXE */}
      <div style={{ position: "absolute", top: 30, left: 24, right: 24, display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <span style={{ fontFamily: "Inter", fontSize: 20, fontWeight: 700, color: "#fff", background: theme.accent2, padding: "6px 16px", borderRadius: 30 }}>
          {storyboard.subject ?? "Smart Whiteboard"}
        </span>
        <span style={{ fontFamily: "Inter", fontSize: 20, fontWeight: 600, color: theme.muted }}>
          {activeScene >= 0 ? activeScene + 1 : 1}/{scenes.length}
        </span>
      </div>

      {/* Ornement : cadre décoratif + lueur ambiante (feuille moins fade) */}
      <AbsoluteFill style={{ pointerEvents: "none" }}>
        <div style={{ position: "absolute", inset: 14, borderRadius: 22, border: `3px solid ${theme.accent2}`, opacity: 0.5 }} />
        <div style={{ position: "absolute", inset: 20, borderRadius: 18, border: `1px solid ${theme.accent}`, opacity: 0.35 }} />
        <div style={{ position: "absolute", top: -120, left: "50%", width: 520, height: 320, transform: "translateX(-50%)", background: `radial-gradient(ellipse, ${theme.accent2}22, transparent 70%)`, filter: "blur(8px)" }} />
      </AbsoluteFill>

      <GlowSweep delay={2} />

      {/* Sous-titre de narration FIXE */}
      {activeNarration ? (
        <div style={{ position: "absolute", left: 24, right: 24, bottom: 40, padding: "14px 18px", borderRadius: 14, background: "rgba(11,18,32,0.82)", color: "#eef2ff", fontFamily: "Inter", fontSize: 22, fontWeight: 600, textAlign: "center" }}>
          {activeNarration}
        </div>
      ) : null}

      {/* Voix off : une piste par scène */}
      {scenes.map((s, i) => {
        const n = narration[i];
        if (!n?.audio_path) return null;
        return (
          <Sequence key={`a${i}`} from={sceneStart[i]} durationInFrames={sceneFrames[i]}>
            <Audio src={/^https?:\/\//.test(n.audio_path) ? n.audio_path : staticFile(n.audio_path)} />
          </Sequence>
        );
      })}
    </AbsoluteFill>
  );
};
