import React from "react";
import { useCurrentFrame, useVideoConfig, interpolate, AbsoluteFill } from "remotion";

// Annotations "manuscrites" (style GoodNotes) : cercle, souligné, surlignage.
// Cercle & souligné sont TRANSITOIRES : ils se tracent, tiennent un instant, puis
// s'EFFACENT (le "un-draw" via dashoffset qui revient + fondu). Le surlignage reste.

type Kind = "circle" | "underline" | "highlight";

const DRAW_SEC = 0.6;
const ERASE_SEC = 0.5;

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
  const opacity = interpolate(frame, [t2, t3], [1, 0], {
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
  if (kind === "underline") {
    return (
      <div style={{ position: "absolute", left: 0, right: 0, bottom: "-16%", height: "26%" }}>
        <Drawn viewBox="0 0 100 20" d={UNDERLINE_D} delay={delay} color={color} strokeWidth={2.6} holdSec={holdSec} />
      </div>
    );
  }
  return (
    <div style={{ position: "absolute", inset: "-14% -8%" }}>
      <Drawn viewBox="0 0 100 100" d={CIRCLE_D} delay={delay} color={color} strokeWidth={2.4} holdSec={holdSec} />
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
