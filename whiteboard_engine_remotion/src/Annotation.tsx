import React from "react";
import { useCurrentFrame, useVideoConfig, interpolate, AbsoluteFill } from "remotion";

// Annotations "manuscrites" (style GoodNotes) : cercle, souligné, surlignage.
// Cercle & souligné sont TRANSITOIRES : ils se tracent, tiennent un instant, puis
// s'EFFACENT (le "un-draw" via dashoffset qui revient + fondu). Le surlignage reste.

type Kind = "circle" | "underline" | "highlight";

export const DRAW_SEC = 0.6;
export const ERASE_SEC = 0.5;
/** Durée totale d'une annotation transitoire (tracé + maintien + effacement). */
export const annotationSeconds = (holdSec = 1.6): number =>
  DRAW_SEC + holdSec + ERASE_SEC;

const Drawn: React.FC<{
  viewBox: string;
  d: string;
  delay: number;
  color: string;
  strokeWidth: number;
  holdSec: number; // durée de maintien avant effacement
}> = ({ viewBox, d, delay, color, strokeWidth, holdSec }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t0 = delay;
  const t1 = delay + fps * DRAW_SEC; // tracé fini
  const t2 = t1 + fps * holdSec; // début effacement
  const t3 = t2 + fps * ERASE_SEC; // fin effacement
  // dashoffset : 1 -> 0 (tracé) -> 0 (maintien) -> 1 (effacement inverse)
  const off = interpolate(frame, [t0, t1, t2, t3], [1, 0, 0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  // Opacité 0 AVANT le début du tracé.
  // Correctif 25/07/2026 : `strokeLinecap="round"` dessine des bouts arrondis visibles
  // même quand le trait est entièrement décalé (dashoffset = 1). D'où les « petits
  // tirets verts » qui flottaient dans le vide sur les rendus de test, parfois très
  // longtemps avant l'annotation. On masque donc franchement tant que le tracé n'a pas
  // commencé, et après son effacement.
  const opacity = interpolate(frame, [t0 - 1, t0, t2, t3], [0, 1, 1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return (
    <AbsoluteFill style={{ opacity }}>
      <svg viewBox={viewBox} preserveAspectRatio="none" style={{ width: "100%", height: "100%" }}>
        <path
          d={d}
          fill="none"
          stroke={color}
          strokeWidth={strokeWidth}
          strokeLinecap="round"
          pathLength={1}
          strokeDasharray={1}
          strokeDashoffset={off}
        />
      </svg>
    </AbsoluteFill>
  );
};

const CIRCLE_D =
  "M50 9 C82 6 95 30 92 52 C89 78 60 95 33 92 C9 89 4 58 11 35 C17 15 41 8 63 11";
const UNDERLINE_D = "M2 11 Q 26 4 50 10 T 98 8";

// Overlay d'annotation seul (utilisé pour les RAPPELS sur un bloc plus haut).
export const AnnotationOverlay: React.FC<{
  kind: Kind;
  color: string;
  delay: number;
  holdSec?: number;
}> = ({ kind, color, delay, holdSec = 1.4 }) => {
  // Positions en PIXELS et non en pourcentages.
  // Correctif 25/07/2026 : en pourcentage, l'annotation se calait sur la hauteur du
  // bloc — sur un bloc long, le souligné partait 16 % plus bas (donc très loin sous le
  // texte) et le cercle devenait un ovale démesuré. En pixels, le geste garde la même
  // taille quel que soit le bloc, comme un vrai stylo.
  if (kind === "underline") {
    return (
      <div style={{ position: "absolute", left: -4, right: -4, bottom: -14, height: 38 }}>
        <Drawn viewBox="0 0 100 20" d={UNDERLINE_D} delay={delay} color={color} strokeWidth={3.2} holdSec={holdSec} />
      </div>
    );
  }
  return (
    <div style={{ position: "absolute", top: -18, bottom: -18, left: -16, right: -16 }}>
      <Drawn viewBox="0 0 100 100" d={CIRCLE_D} delay={delay} color={color} strokeWidth={2.8} holdSec={holdSec} />
    </div>
  );
};

// Enveloppe un bloc et superpose l'annotation choisie (transitoire pour cercle/souligné).
export const Emphasis: React.FC<{
  kind: Kind;
  color: string;
  highlight: string;
  delay: number;
  holdSec?: number;
  children: React.ReactNode;
}> = ({ kind, color, highlight, delay, holdSec = 1.6, children }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  if (kind === "highlight") {
    // Le surlignage RESTE (marqueur).
    const w = interpolate(frame - delay, [0, fps * 0.5], [0, 100], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    });
    return (
      <div style={{ position: "relative", display: "block" }}>
        <div
          style={{
            position: "absolute",
            left: -6,
            right: -6,
            top: "12%",
            bottom: "8%",
            background: highlight,
            opacity: 0.55,
            width: `${w}%`,
            transform: "skewX(-3deg)",
            borderRadius: 4,
            zIndex: 0,
          }}
        />
        <div style={{ position: "relative", zIndex: 1 }}>{children}</div>
      </div>
    );
  }

  return (
    <div style={{ position: "relative", display: "block" }}>
      {children}
      <AnnotationOverlay kind={kind} color={color} delay={delay} holdSec={holdSec} />
    </div>
  );
};

export type EmphasisKind = Kind;
