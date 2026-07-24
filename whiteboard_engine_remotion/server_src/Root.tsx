import React from "react";
import { Composition } from "remotion";
import { loadFont as loadCaveat } from "@remotion/google-fonts/Caveat";
import { loadFont as loadInter } from "@remotion/google-fonts/Inter";
import { SmartWhiteboard, totalDurationInFrames } from "./SmartWhiteboard";
import type { SmartWhiteboardProps } from "./types";
import { VIDEO } from "./theme";
import sample from "./sample_storyboard.json";

// Charger UNIQUEMENT les graisses/sous-ensembles nécessaires (sinon Inter charge
// des centaines de fichiers -> saturation mémoire au rendu SSR).
loadCaveat("normal", { weights: ["700"], subsets: ["latin"], ignoreTooManyRequestsWarning: true });
loadInter("normal", { weights: ["400", "500", "700", "800"], subsets: ["latin"], ignoreTooManyRequestsWarning: true });

const defaultProps: SmartWhiteboardProps = {
  storyboard: sample as SmartWhiteboardProps["storyboard"],
  narration: (sample.scenes as unknown[]).map((_, i) => ({
    scene_index: i,
    audio_path: null,
    duration_sec: 0,
  })),
  fps: VIDEO.fps,
};

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="SmartWhiteboard"
      component={SmartWhiteboard}
      durationInFrames={300}
      fps={VIDEO.fps}
      width={VIDEO.width}
      height={VIDEO.height}
      defaultProps={defaultProps}
      calculateMetadata={({ props }) => ({
        durationInFrames: totalDurationInFrames(props),
        fps: props.fps ?? VIDEO.fps,
      })}
    />
  );
};
