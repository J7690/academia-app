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
