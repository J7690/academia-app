import React from "react";
import { AbsoluteFill, Audio, staticFile, useVideoConfig, useCurrentFrame, interpolate } from "remotion";
import type { Scene as SceneT, NarrationEntry } from "./types";
import type { Theme } from "./theme";
import { renderBlock } from "./blocks";
import { KenBurns, GlowSweep } from "./effects";

const resolveSrc = (s?: string): string | undefined =>
  !s ? undefined : /^https?:\/\//.test(s) ? s : staticFile(s);

interface Props {
  scene: SceneT;
  theme: Theme;
  narration?: NarrationEntry;
  index: number;
  total: number;
}

// Une scène : fond "cahier", blocs animés en cascade, voix off + sous-titre.
export const SceneView: React.FC<Props> = ({ scene, theme, narration, index, total }) => {
  const { fps } = useVideoConfig();
  const frame = useCurrentFrame();

  // Cascade : chaque bloc démarre 12 frames après le précédent.
  const STAGGER = 12;

  // Fond papier avec lignes horizontales BIEN visibles (style cahier) : trait de
  // 2px toutes les `ruleGap` px.
  const g = theme.ruleGap;
  const paperBg =
    `repeating-linear-gradient(${theme.paper} 0px, ${theme.paper} ${g - 2}px, ` +
    `${theme.rule} ${g - 2}px, ${theme.rule} ${g}px)`;

  const captionText = scene.narration ?? "";
  const captionOpacity = interpolate(frame, [3, 12], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill style={{ background: theme.background }}>
      <AbsoluteFill style={{ background: paperBg, backgroundColor: theme.paper }} />

      {/* Fond illustré optionnel en Ken Burns (voilé pour garder le texte lisible) */}
      {scene.background_image ? (
        <KenBurns src={resolveSrc(scene.background_image)!} durationInFrames={9999} opacity={0.16} />
      ) : null}

      {/* Marge verticale rouge (style cahier) */}
      <div style={{ position: "absolute", top: 0, bottom: 0, left: 58, width: 3, background: theme.margin, opacity: 0.7 }} />

      {/* Balayage lumineux d'entrée (effet premium) */}
      <GlowSweep delay={2} />

      {/* Bandeau haut : matière + n° de scène */}
      <div
        style={{
          position: "absolute",
          top: 34,
          left: 40,
          right: 40,
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
        }}
      >
        <span
          style={{
            fontFamily: "Inter",
            fontSize: 20,
            fontWeight: 700,
            color: "#fff",
            background: theme.accent2,
            padding: "6px 16px",
            borderRadius: 30,
          }}
        >
          {scene.title ?? "Smart Whiteboard"}
        </span>
        <span style={{ fontFamily: "Inter", fontSize: 20, fontWeight: 600, color: theme.muted }}>
          {index + 1}/{total}
        </span>
      </div>

      {/* Contenu */}
      <div
        style={{
          position: "absolute",
          top: 150,
          left: 80,
          right: 48,
          bottom: 170,
          display: "flex",
          flexDirection: "column",
          justifyContent: "center", // remplit la feuille verticalement
          gap: 14,
          overflow: "hidden",
        }}
      >
        {scene.blocks.map((b, i) => renderBlock(b, theme, i * STAGGER, i))}
      </div>

      {/* Voix off (narration) */}
      {narration?.audio_path ? <Audio src={staticFile(narration.audio_path)} /> : null}

      {/* Sous-titre de narration */}
      {captionText ? (
        <div
          style={{
            position: "absolute",
            left: 24,
            right: 24,
            bottom: 40,
            padding: "14px 18px",
            borderRadius: 14,
            background: "rgba(11,18,32,0.82)",
            color: "#eef2ff",
            fontFamily: "Inter",
            fontSize: 22,
            fontWeight: 600,
            textAlign: "center",
            opacity: captionOpacity,
          }}
        >
          {captionText}
        </div>
      ) : null}
    </AbsoluteFill>
  );
};
