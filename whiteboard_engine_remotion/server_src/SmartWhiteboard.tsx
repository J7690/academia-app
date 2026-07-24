import React from "react";
import {
  AbsoluteFill,
  Audio,
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
import { AnnotationOverlay } from "./Annotation";

const MIN_SCENE_SEC = 3;
const TAIL_SEC = 0.6;
const RECALL_SEC = 4.0; // budget d'un rappel (remonter + maintenir + redescendre)

const PAD_LEFT = 80;
const PAD_RIGHT = 48;
const GAP = 36;
const CONTENT_W = VIDEO.width - PAD_LEFT - PAD_RIGHT;

const hasRecall = (s: Scene) =>
  !!s.recall && typeof s.recall.target === "number" && s.recall.target >= 0;

// ── Durées ────────────────────────────────────────────────────────────────
export const sceneDurationInFrames = (
  scene: Scene,
  narration: NarrationEntry | undefined,
  fps: number
): number => {
  const storyboardSec = (scene.duration_ms ?? 0) / 1000;
  const narrSec = narration?.duration_sec ?? 0;
  const base = Math.max(storyboardSec, narrSec > 0 ? narrSec + TAIL_SEC : 0, MIN_SCENE_SEC);
  const recall = hasRecall(scene) ? RECALL_SEC : 0;
  return Math.max(1, Math.round((base + recall) * fps));
};

export const totalDurationInFrames = (props: SmartWhiteboardProps): number => {
  const { storyboard, narration, fps } = props;
  return storyboard.scenes.reduce(
    (sum, sc, i) => sum + sceneDurationInFrames(sc, narration[i], fps),
    0
  );
};

// ── Estimation de hauteur d'un bloc (px) ────────────────────────────────────
const lineCount = (text: string, perLine: number) =>
  Math.max(1, Math.ceil((text || "").length / perLine));

function estimateHeight(b: Block): number {
  switch (b.type) {
    case "title":
      return 200;
    case "formula":
      return b.videoSrc ? 320 : 230;
    case "definition":
      return lineCount(b.content, 24) * 72 + 34;
    case "exercise":
    case "correction":
      return lineCount(b.content, 24) * 70 + 64;
    case "list": {
      const items = b.items?.length ?? (b.content || "").split("\n").filter(Boolean).length;
      return Math.max(1, items) * 72 + 20;
    }
    case "image":
      return 380;
    default:
      return lineCount(b.content, 22) * 72 + 24;
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
  appear: number;
  sceneIndex: number;
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

  // 1) Timeline des scènes.
  const sceneFrames = scenes.map((s, i) => sceneDurationInFrames(s, narration[i], fps));
  const sceneStart: number[] = [];
  sceneFrames.reduce((acc, f, i) => ((sceneStart[i] = acc), acc + f), 0);

  // 2) Items (blocs) : Y cumulé + frame d'apparition. Les scènes à rappel
  //    décalent l'apparition de leurs blocs après le budget de rappel.
  const items: Item[] = [];
  const firstItemOfScene: number[] = [];
  let y = 40;
  let lastAppear = 0;
  scenes.forEach((scene, si) => {
    const blocks = scene.blocks || [];
    const start = sceneStart[si] + (hasRecall(scene) ? RECALL_SEC * fps : 0);
    const dur = sceneFrames[si] - (hasRecall(scene) ? RECALL_SEC * fps : 0);
    const step = dur / (blocks.length + 0.8);
    firstItemOfScene[si] = items.length;
    // Bloc clé à mettre en valeur (auto) si le modèle n'a pas fourni d'emphasis.
    const keyIdx = pickKeyBlockIndex(blocks);
    blocks.forEach((block, bi) => {
      let b = block;
      if (bi === keyIdx && !block.emphasis) {
        const kind = block.type === "formula" ? "circle" : "underline";
        b = { ...block, emphasis: kind };
      }
      const h = estimateHeight(b);
      let appear = Math.round(start + (bi + 0.4) * step);
      appear = Math.max(appear, lastAppear + 2);
      lastAppear = appear;
      items.push({ block: b, y, h, appear, sceneIndex: si });
      y += h + GAP;
    });
  });
  const docHeight = y + 220;

  const writeTarget = (it: Item) => Math.max(0, it.y + it.h - H * 0.6);

  // 3) Keyframes de défilement (écriture) + détours de rappel.
  const kf: Array<{ f: number; y: number }> = [{ f: 0, y: 0 }];
  items.forEach((it) => kf.push({ f: it.appear, y: writeTarget(it) }));

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
  const scroll = interpolate(frame, xs, ys, {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
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
              {renderBlock(it.block, theme, it.appear, i)}
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
