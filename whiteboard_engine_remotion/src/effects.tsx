import React from "react";
import { AbsoluteFill, Img, useCurrentFrame, useVideoConfig, interpolate } from "remotion";

// Zoom Ken Burns : lente montée d'échelle + léger panoramique. Donne du mouvement
// cinématographique aux images/fonds (style CapCut).
export const KenBurns: React.FC<{
  src: string;
  durationInFrames: number;
  from?: number;
  to?: number;
  opacity?: number;
}> = ({ src, durationInFrames, from = 1.06, to = 1.18, opacity = 1 }) => {
  const frame = useCurrentFrame();
  const scale = interpolate(frame, [0, durationInFrames], [from, to], {
    extrapolateRight: "clamp",
  });
  const x = interpolate(frame, [0, durationInFrames], [-8, 8], { extrapolateRight: "clamp" });
  return (
    <AbsoluteFill style={{ overflow: "hidden", opacity }}>
      <Img
        src={src}
        style={{
          width: "100%",
          height: "100%",
          objectFit: "cover",
          transform: `scale(${scale}) translateX(${x}px)`,
        }}
      />
    </AbsoluteFill>
  );
};

// Balayage lumineux (light sweep) qui traverse l'écran une fois — effet "premium".
export const GlowSweep: React.FC<{ delay?: number; color?: string }> = ({
  delay = 0,
  color = "rgba(255,255,255,0.35)",
}) => {
  const frame = useCurrentFrame();
  const { width, fps } = useVideoConfig();
  const x = interpolate(frame - delay, [0, fps * 1.2], [-width * 0.6, width * 1.2], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return (
    <AbsoluteFill style={{ pointerEvents: "none", overflow: "hidden" }}>
      <div
        style={{
          position: "absolute",
          top: 0,
          bottom: 0,
          left: x,
          width: 160,
          transform: "skewX(-18deg)",
          background: `linear-gradient(90deg, transparent, ${color}, transparent)`,
          filter: "blur(6px)",
        }}
      />
    </AbsoluteFill>
  );
};

// Halo lumineux doux derrière un élément clé (glow).
export const SpotLight: React.FC<{ color?: string; size?: number; x?: string; y?: string }> = ({
  color = "rgba(76,110,245,0.25)",
  size = 520,
  x = "50%",
  y = "38%",
}) => (
  <AbsoluteFill style={{ pointerEvents: "none" }}>
    <div
      style={{
        position: "absolute",
        left: x,
        top: y,
        width: size,
        height: size,
        transform: "translate(-50%, -50%)",
        background: `radial-gradient(circle, ${color} 0%, transparent 70%)`,
        filter: "blur(12px)",
      }}
    />
  </AbsoluteFill>
);
