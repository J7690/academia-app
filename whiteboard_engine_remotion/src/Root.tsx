import React from "react";
import { Composition } from "remotion";
import { SmartWhiteboard, totalDurationInFrames } from "./SmartWhiteboard";
import type { SmartWhiteboardProps } from "./types";
import { VIDEO } from "./theme";
import sample from "./sample_storyboard.json";

// Polices : on N'utilise PLUS @remotion/google-fonts (chargeait des centaines de
// fichiers -> OOM au rendu). On s'appuie sur les polices système via font-family
// (sans-serif moderne). Une vraie police pourra être ajoutée via un seul woff2 plus tard.

const defaultProps: SmartWhiteboardProps = {
  storyboard: sample as SmartWhiteboardProps["storyboard"],
  narration: (sample.scenes as unknown[]).map((_, i) => ({
    scene_index: i,
    audio_path: null,
    duration_sec: 0,
  })),
  fps: VIDEO.fps,
};

// `Composition` type ses props via un schéma Zod (absent ici) et retombe donc sur
// `Record<string, unknown>`. Les deux conversions ci-dessous relient ce type générique
// à nos props réelles ; elles n'ont aucun effet à l'exécution, elles rendent seulement
// l'intention explicite pour TypeScript.
const CompositionComponent = SmartWhiteboard as unknown as React.FC<
  Record<string, unknown>
>;

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="SmartWhiteboard"
      component={CompositionComponent}
      durationInFrames={300}
      fps={VIDEO.fps}
      width={VIDEO.width}
      height={VIDEO.height}
      defaultProps={defaultProps as unknown as Record<string, unknown>}
      calculateMetadata={({ props }) => {
        const p = props as unknown as SmartWhiteboardProps;
        return {
          durationInFrames: totalDurationInFrames(p),
          fps: p.fps ?? VIDEO.fps,
        };
      }}
    />
  );
};
