import React from "react";
import { useCurrentFrame, interpolate, spring, useVideoConfig, staticFile, OffthreadVideo } from "remotion";
import katex from "katex";
import type { Block } from "./types";
import type { Theme } from "./theme";
import { KenBurns, SpotLight } from "./effects";
import { Emphasis } from "./Annotation";

const resolveSrc = (s?: string): string | undefined => {
  if (!s) return undefined;
  return /^https?:\/\//.test(s) ? s : staticFile(s);
};

// Chaque bloc apparaît avec un léger décalage (stagger) porté par `delay` (frames).

interface BlockProps {
  block: Block;
  theme: Theme;
  delay: number;
}

// Titre = TITRE DE CHAPITRE mis en valeur : plaquette/bulle colorée, CENTRÉE,
// en gras (style présentation / entête de cours).
export const TitleBlock: React.FC<BlockProps> = ({ block, theme, delay }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = spring({ frame: frame - delay, fps, config: { damping: 14, mass: 0.7 } });
  const scale = interpolate(p, [0, 1], [0.85, 1]);
  const opacity = interpolate(p, [0, 1], [0, 1]);
  return (
    <div style={{ display: "flex", justifyContent: "center", margin: "6px 0 30px" }}>
      <div
        style={{
          opacity,
          transform: `scale(${scale})`,
          maxWidth: "94%",
          textAlign: "center",
          fontFamily: "Inter",
          fontSize: 56,
          fontWeight: 800,
          color: "#ffffff",
          lineHeight: 1.15,
          padding: "22px 34px",
          borderRadius: 22,
          background: `linear-gradient(135deg, ${theme.accent2}, ${theme.accent})`,
          boxShadow: "0 14px 34px rgba(0,0,0,0.20)",
          letterSpacing: "0.01em",
        }}
      >
        {block.content}
      </div>
    </div>
  );
};

// Apparition en fondu + montée.
const FadeUp: React.FC<{
  delay: number;
  children: React.ReactNode;
  style?: React.CSSProperties;
}> = ({ delay, children, style }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = spring({ frame: frame - delay, fps, config: { damping: 200 } });
  const opacity = interpolate(p, [0, 1], [0, 1]);
  const y = interpolate(p, [0, 1], [18, 0]);
  return (
    <div style={{ opacity, transform: `translateY(${y}px)`, ...style }}>
      {children}
    </div>
  );
};

// Paragraphe révélé LIGNE PAR LIGNE (chaque ligne monte en fondu en cascade).
export const ParagraphBlock: React.FC<BlockProps> = ({ block, theme, delay }) => {
  const lines = (block.content || "").split("\n").flatMap((l) => wrapApprox(l, 26));
  return (
    <div style={{ marginBottom: 18 }}>
      {lines.map((line, i) => (
        <FadeUp key={i} delay={delay + i * 8}>
          <div style={{ fontFamily: "Inter", fontSize: 46, color: theme.ink, lineHeight: 1.5, fontWeight: 500 }}>
            {line}
          </div>
        </FadeUp>
      ))}
    </div>
  );
};

// Découpe approximative en lignes (par nombre de caractères) pour la révélation.
function wrapApprox(text: string, maxChars: number): string[] {
  const words = (text || "").split(" ");
  const out: string[] = [];
  let cur = "";
  for (const w of words) {
    const cand = cur ? `${cur} ${w}` : w;
    if (cand.length > maxChars && cur) {
      out.push(cur);
      cur = w;
    } else cur = cand;
  }
  if (cur) out.push(cur);
  return out.length ? out : [text];
}

// Illustration/photo avec zoom Ken Burns + halo lumineux (style CapCut).
export const ImageBlock: React.FC<BlockProps> = ({ block, delay }) => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();
  const p = spring({ frame: frame - delay, fps, config: { damping: 200 } });
  const opacity = interpolate(p, [0, 1], [0, 1]);
  const src = resolveSrc(block.src) ?? resolveSrc(block.content);
  if (!src) return null;
  return (
    <div style={{ position: "relative", margin: "8px 0 20px", opacity }}>
      <SpotLight />
      <div style={{ position: "relative", height: 360, borderRadius: 16, overflow: "hidden", boxShadow: "0 12px 30px rgba(0,0,0,0.18)" }}>
        <KenBurns src={src} durationInFrames={durationInFrames} />
      </div>
    </div>
  );
};

// Liste à puces révélées une par une.
export const ListBlock: React.FC<BlockProps> = ({ block, theme, delay }) => {
  const items = block.items && block.items.length ? block.items : (block.content || "").split("\n").filter(Boolean);
  return (
    <div style={{ marginBottom: 18 }}>
      {items.map((it, i) => (
        <FadeUp key={i} delay={delay + i * 12}>
          <div style={{ display: "flex", gap: 12, alignItems: "flex-start", marginBottom: 10 }}>
            <span style={{ flex: "0 0 auto", width: 12, height: 12, borderRadius: 3, background: theme.accent, marginTop: 12 }} />
            <span style={{ fontFamily: "Inter", fontSize: 46, color: theme.ink, lineHeight: 1.45 }}>{it}</span>
          </div>
        </FadeUp>
      ))}
    </div>
  );
};

export const DefinitionBlock: React.FC<BlockProps> = ({ block, theme, delay }) => (
  <FadeUp delay={delay} style={{ marginBottom: 18 }}>
    <div
      style={{
        fontFamily: "Inter",
        fontSize: 46,
        color: theme.accent,
        lineHeight: 1.5,
        paddingLeft: 16,
        borderLeft: `5px solid ${theme.accent}`,
      }}
    >
      {block.content}
    </div>
  </FadeUp>
);

// Formule rendue via KaTeX, apparition "pop" (scale + fondu).
export const FormulaBlock: React.FC<BlockProps> = ({ block, theme, delay }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = spring({ frame: frame - delay, fps, config: { damping: 12, mass: 0.6 } });
  const scale = interpolate(p, [0, 1], [0.8, 1]);
  const opacity = interpolate(p, [0, 1], [0, 1]);

  // Vague 3 : si un clip Manim animé existe, on le composite (écriture animée
  // de la formule). Sinon, repli KaTeX statique.
  const clip = resolveSrc(block.videoSrc);
  if (clip) {
    return (
      <div style={{ margin: "8px 0 20px", opacity }}>
        <OffthreadVideo src={clip} style={{ width: "100%", height: 300, objectFit: "contain" }} />
      </div>
    );
  }

  let html = block.content;
  try {
    html = katex.renderToString(block.content, {
      throwOnError: false,
      displayMode: true,
    });
  } catch (e) {
    html = block.content;
  }
  return (
    <div
      style={{
        margin: "8px 0 20px",
        padding: 22,
        borderRadius: 14,
        background: theme.formulaBg,
        border: `1px solid ${theme.formulaBorder}`,
        textAlign: "center",
        color: theme.ink,
        opacity,
        transform: `scale(${scale})`,
      }}
    >
      <div style={{ fontSize: 40 }} dangerouslySetInnerHTML={{ __html: html }} />
    </div>
  );
};

export const ExerciseBlock: React.FC<BlockProps> = ({ block, theme, delay }) => (
  <FadeUp delay={delay} style={{ marginBottom: 18 }}>
    <div
      style={{
        fontFamily: "Inter",
        fontSize: 46,
        color: theme.ink,
        background: theme.accent2 + "18",
        padding: 16,
        borderRadius: 12,
        lineHeight: 1.45,
      }}
    >
      {block.content}
    </div>
  </FadeUp>
);

// Correction : surlignage qui balaie + puce verte.
export const CorrectionBlock: React.FC<BlockProps> = ({ block, theme, delay }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const local = frame - delay;
  const opacity = interpolate(local, [0, fps * 0.3], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const sweep = interpolate(local, [fps * 0.2, fps * 1.1], [100, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return (
    <div
      style={{
        opacity,
        margin: "6px 0 18px",
        padding: "12px 14px",
        borderRadius: 10,
        fontFamily: "Inter",
        fontSize: 46,
        color: theme.ink,
        background: `linear-gradient(120deg, ${theme.accent}22 ${100 - sweep}%, transparent ${100 - sweep}%)`,
        display: "flex",
        alignItems: "flex-start",
        gap: 10,
      }}
    >
      <span
        style={{
          flex: "0 0 auto",
          width: 30,
          height: 30,
          borderRadius: "50%",
          background: theme.accent,
          color: "#fff",
          textAlign: "center",
          lineHeight: "30px",
          fontSize: 20,
        }}
      >
        ✓
      </span>
      <span>{block.content}</span>
    </div>
  );
};

export const StepBlock = ExerciseBlock;

export const renderBlock = (block: Block, theme: Theme, delay: number, key: number) => {
  const map: Record<string, React.FC<BlockProps>> = {
    title: TitleBlock,
    paragraph: ParagraphBlock,
    definition: DefinitionBlock,
    formula: FormulaBlock,
    exercise: ExerciseBlock,
    correction: CorrectionBlock,
    step: StepBlock,
    image: ImageBlock,
    list: ListBlock,
  };
  const Comp = map[block.type] ?? ParagraphBlock;
  const el = <Comp block={block} theme={theme} delay={delay} />;
  // Annotation manuscrite (cercle / souligné / surligné) sur un bloc clé.
  if (block.emphasis) {
    return (
      <Emphasis
        key={key}
        kind={block.emphasis}
        color={theme.accent}
        highlight={theme.highlight}
        delay={delay + 16}
      >
        {el}
      </Emphasis>
    );
  }
  return <React.Fragment key={key}>{el}</React.Fragment>;
};
