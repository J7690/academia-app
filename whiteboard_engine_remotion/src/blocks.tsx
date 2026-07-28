import React from "react";
import { useCurrentFrame, interpolate, spring, useVideoConfig, staticFile, OffthreadVideo } from "remotion";
import katex from "katex";
// Feuille de style KaTeX : sans elle, la couche MathML n'est pas masquée et la formule
// s'affichait EN DOUBLE (une version italique par-dessus une version droite), défaut vu
// au rendu du 25/07. Un seul fichier CSS + les polices KaTeX (une vingtaine) — sans
// commune mesure avec les centaines de fichiers de @remotion/google-fonts qui avaient
// provoqué le crash mémoire.
import "katex/dist/katex.min.css";
import type { Block, WritingStyle } from "./types";
import type { Theme } from "./theme";
import { fontScaleFor } from "./theme";
import { familyFor } from "./fonts";
import { KenBurns, SpotLight } from "./effects";
import { Emphasis, AnnotationOverlay } from "./Annotation";

const resolveSrc = (s?: string): string | undefined => {
  if (!s) return undefined;
  return /^https?:\/\//.test(s) ? s : staticFile(s);
};

// Chaque bloc apparaît avec un léger décalage (stagger) porté par `delay` (frames).

interface BlockProps {
  block: Block;
  theme: Theme;
  delay: number;
  /** "handwriting" (défaut) = le texte se trace ; "typed" = révélation machine. */
  writingStyle?: WritingStyle;
}

// ── ÉCRITURE PROGRESSIVE ────────────────────────────────────────────────────
// Le cœur de l'effet « professeur au tableau » : le texte ne s'affiche pas d'un
// bloc, il S'ÉCRIT, caractère après caractère.
//
// Chaque caractère apparaît avec un très court fondu (≈3 images) plutôt que d'un
// coup : cumulé, cela donne la fluidité d'une main qui avance, là où une apparition
// nette produirait un effet « machine à écrire » sec.

const CPS: Record<string, number> = {
  slow: 13, // notion clé : le prof ralentit
  normal: 20,
  fast: 30, // transition, texte de liaison
};


export const Handwrite: React.FC<{
  text: string;
  delay: number;
  speed?: "slow" | "normal" | "fast";
  style?: React.CSSProperties;
}> = ({ text, delay, speed = "normal", style }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const local = frame - delay;
  const charsPerFrame = (CPS[speed] ?? CPS.normal) / fps;
  const written = local * charsPerFrame;
  const total = text.length;

  // ── FENÊTRE D'ÉCRITURE (correctif mémoire du 25/07/2026) ──────────────────
  //
  // Version precedente : CHAQUE caractere avait son propre element, en permanence.
  // Le cahier etant continu, les ~1 650 caracteres d'un cours reel coexistaient des
  // la premiere image -> 6 Go de memoire et « JavaScript heap out of memory ».
  //
  // Or a un instant donne, seuls quelques caracteres sont en train d'apparaitre :
  // ceux sous la « pointe du stylo ». Les autres sont soit deja ecrits (opacite 1),
  // soit pas encore ecrits (opacite 0) — et n'ont aucun besoin d'etre individualises.
  //
  // On ne decoupe donc QUE la fenetre active, et on rend le reste en DEUX blocs de
  // texte simples. Le rendu visuel est identique, le nombre d'elements passe de
  // plusieurs centaines a une quinzaine par bloc.
  //
  // Le texte non encore ecrit est conserve (invisible) plutot que retire : il
  // reserve sa place, sinon la mise en page sauterait a chaque caractere.
  // ── RÉVÉLATION PAR MOTS (optimisation du 25/07/2026) ──────────────────────
  //
  // POURQUOI : animer chaque LETTRE oblige le navigateur a recalculer la mise en page
  // du bloc a chaque image. Sur un cours complet, le rendu passait de 160 s (avant
  // l'ecriture manuscrite) a plus de 15 minutes — inutilisable pour un etudiant qui
  // attend sa video.
  //
  // COMMENT : on revele desormais MOT PAR MOT. A 20 caracteres/seconde, un mot dure
  // ~0,25 s : l'oeil percoit toujours une main qui avance, mais le nombre d'elements
  // qui changent d'opacite est divise par cinq a six.
  //
  // Le decoupage conserve l'espace qui suit chaque mot, pour que le texte ne « saute »
  // pas pendant l'ecriture. Le texte pas encore ecrit reste present mais invisible :
  // il reserve sa place et evite tout deplacement de la mise en page.
  const wrapper: React.CSSProperties = {
    whiteSpace: "pre-wrap",
    overflowWrap: "break-word",
    ...style,
  };

  // Cas rapides : rien d'ecrit, ou tout est ecrit -> UN SEUL element, aucun calcul.
  if (written <= 0) {
    return <span style={{ ...wrapper, opacity: 0 }}>{text}</span>;
  }
  if (written >= total + 2) {
    return <span style={wrapper}>{text}</span>;
  }

  // Decoupage en mots (l'espace reste colle au mot qui precede).
  const words = text.match(/\S+\s*|\s+/g) ?? [text];

  let cursor = 0;
  const parts: Array<{ text: string; start: number }> = [];
  for (const w of words) {
    parts.push({ text: w, start: cursor });
    cursor += w.length;
  }

  // On regroupe les mots deja entierement ecrits en UN SEUL element.
  const doneIdx = parts.findIndex((p) => written < p.start + p.text.length);
  const cut = doneIdx < 0 ? parts.length : doneIdx;
  const doneText = text.slice(0, cut > 0 ? parts[cut - 1].start + parts[cut - 1].text.length : 0);
  const tail = parts.slice(cut);

  return (
    <span style={wrapper}>
      {doneText ? <span>{doneText}</span> : null}
      {tail.map((p, i) => {
        // Le mot apparait en fondu court des que la pointe du stylo l'atteint.
        const o = interpolate(
          written - p.start,
          [0, Math.max(1, p.text.length * 0.6)],
          [0, 1],
          { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
        );
        return (
          <span key={cut + i} style={{ opacity: o }}>
            {p.text}
          </span>
        );
      })}
    </span>
  );
};

/** Nombre d'images nécessaires pour écrire `text` à la vitesse donnée. */
export const writeDurationFrames = (
  text: string,
  fps: number,
  speed: "slow" | "normal" | "fast" = "normal"
): number => Math.ceil(((text || "").length / (CPS[speed] ?? CPS.normal)) * fps);

// ── ANNOTATION CIBLÉE SUR DES MOTS ──────────────────────────────────────────
// Un professeur entoure UN MOT, pas un paragraphe entier. Jusqu'ici l'annotation
// couvrait tout le bloc, d'où des ovales démesurés englobant plusieurs lignes.
//
// Astuce de mise en œuvre : plutôt que de MESURER la position des mots (impossible
// de façon fiable au rendu image par image), on enveloppe les mots visés dans un
// `inline-block` et on place l'annotation À L'INTÉRIEUR. Elle épouse alors
// automatiquement leur largeur et leur hauteur réelles, sans aucun calcul.

/** Découpe un texte autour de la cible (insensible à la casse). Null si absente. */
const splitOnTarget = (
  text: string,
  target?: string
): { before: string; hit: string; after: string } | null => {
  if (!target || !target.trim()) return null;
  const i = text.toLowerCase().indexOf(target.trim().toLowerCase());
  if (i < 0) return null;
  return {
    before: text.slice(0, i),
    hit: text.slice(i, i + target.trim().length),
    after: text.slice(i + target.trim().length),
  };
};

/**
 * Texte manuscrit avec, le cas échéant, une annotation portant SUR DES MOTS PRÉCIS.
 * Si la cible est absente du texte, on retombe silencieusement sur le texte simple
 * (le rendu ne doit jamais échouer à cause d'une cible mal formulée par l'IA).
 */
export const HandwriteTargeted: React.FC<{
  text: string;
  delay: number;
  speed?: "slow" | "normal" | "fast";
  style?: React.CSSProperties;
  target?: string;
  kind?: "circle" | "underline" | "highlight";
  color: string;
  highlight: string;
  fps: number;
}> = ({ text, delay, speed = "normal", style, target, kind, color, highlight, fps }) => {
  const parts = kind ? splitOnTarget(text, target) : null;
  if (!parts) {
    return <Handwrite text={text} delay={delay} speed={speed} style={style} />;
  }
  // L'annotation se déclenche quand les mots visés viennent d'être écrits.
  const hitEnd = delay + writeDurationFrames(parts.before + parts.hit, fps, speed);
  return (
    <span style={{ whiteSpace: "pre-wrap", overflowWrap: "break-word", ...style }}>
      <Handwrite text={parts.before} delay={delay} speed={speed} />
      <span style={{ position: "relative", display: "inline-block" }}>
        <Handwrite
          text={parts.hit}
          delay={delay + writeDurationFrames(parts.before, fps, speed)}
          speed={speed}
        />
        {kind === "highlight" ? (
          <HighlightSweep delay={hitEnd} color={highlight} />
        ) : (
          <AnnotationOverlay kind={kind!} color={color} delay={hitEnd} holdSec={1.6} />
        )}
      </span>
      <Handwrite
        text={parts.after}
        delay={delay + writeDurationFrames(parts.before + parts.hit, fps, speed)}
        speed={speed}
      />
    </span>
  );
};

/** Surlignage au feutre : balaie de gauche à droite, puis RESTE (c'est un marqueur). */
const HighlightSweep: React.FC<{ delay: number; color: string }> = ({ delay, color }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const w = interpolate(frame - delay, [0, fps * 0.45], [0, 100], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return (
    <span
      style={{
        position: "absolute",
        left: -4,
        right: -4,
        top: "10%",
        bottom: "6%",
        width: `${w}%`,
        background: color,
        opacity: 0.5,
        borderRadius: 4,
        transform: "skewX(-3deg)",
        zIndex: -1,
      }}
    />
  );
};

// Titre = TITRE DE CHAPITRE mis en valeur : plaquette/bulle colorée, CENTRÉE,
// en gras (style présentation / entête de cours).
export const TitleBlock: React.FC<BlockProps> = ({ block, theme, delay, writingStyle }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = spring({ frame: frame - delay, fps, config: { damping: 14, mass: 0.7 } });
  const scale = interpolate(p, [0, 1], [0.85, 1]);
  const opacity = interpolate(p, [0, 1], [0, 1]);
  const hand = writingStyle !== "typed";
  return (
    <div style={{ display: "flex", justifyContent: "center", margin: "6px 0 30px" }}>
      <div
        style={{
          opacity,
          transform: `scale(${scale})`,
          maxWidth: "94%",
          textAlign: "center",
          // Le titre aussi passe à la main : tout le cahier doit être manuscrit.
          fontFamily: hand ? familyFor(writingStyle) : "Inter",
          fontSize: hand ? 64 : 56,
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

// Paragraphe : en mode manuscrit, le texte S'ÉCRIT ligne après ligne, la ligne
// suivante ne démarrant qu'une fois la précédente terminée (comme une vraie main).
// En mode "typed", on garde la révélation en fondu, ligne par ligne.
export const ParagraphBlock: React.FC<BlockProps> = ({ block, theme, delay, writingStyle }) => {
  const { fps } = useVideoConfig();
  const family = familyFor(writingStyle);
  const scale = fontScaleFor(writingStyle);
  const hand = writingStyle !== "typed";
  // La police manuscrite étant plus étroite, on met plus de caractères par ligne.
  const lines = (block.content || "").split("\n").flatMap((l) => wrapApprox(l, hand ? 32 : 26));
  const speed = block.write_speed ?? "normal";

  let acc = 0;
  return (
    <div style={{ marginBottom: 18 }}>
      {lines.map((line, i) => {
        const lineDelay = delay + acc;
        acc += hand ? writeDurationFrames(line, fps, speed) + 2 : 8;
        const css: React.CSSProperties = {
          fontFamily: family,
          fontSize: 46 * scale,
          color: theme.ink,
          lineHeight: hand ? 1.35 : 1.5,
          fontWeight: hand ? 600 : 500,
          display: "block",
        };
        return hand ? (
          <Handwrite key={i} text={line} delay={lineDelay} speed={speed} style={css} />
        ) : (
          <FadeUp key={i} delay={lineDelay}>
            <div style={css}>{line}</div>
          </FadeUp>
        );
      })}
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
export const ListBlock: React.FC<BlockProps> = ({ block, theme, delay, writingStyle }) => {
  const { fps } = useVideoConfig();
  const hand = writingStyle !== "typed";
  const items = block.items && block.items.length ? block.items : (block.content || "").split("\n").filter(Boolean);
  const speed = block.write_speed ?? "normal";
  const css: React.CSSProperties = {
    fontFamily: familyFor(writingStyle),
    fontSize: 46 * fontScaleFor(writingStyle),
    color: theme.ink,
    lineHeight: hand ? 1.35 : 1.45,
    fontWeight: hand ? 600 : 500,
  };
  let acc = 0;
  return (
    <div style={{ marginBottom: 18 }}>
      {items.map((it, i) => {
        const d = delay + acc;
        acc += hand ? writeDurationFrames(it, fps, speed) + 3 : 12;
        const row = (
          <div style={{ display: "flex", gap: 12, alignItems: "flex-start", marginBottom: 10 }}>
            <span style={{ flex: "0 0 auto", width: 12, height: 12, borderRadius: 3, background: theme.accent, marginTop: 12 }} />
            {hand ? (
              <Handwrite text={it} delay={d} speed={speed} style={css} />
            ) : (
              <span style={css}>{it}</span>
            )}
          </div>
        );
        return hand ? <div key={i}>{row}</div> : <FadeUp key={i} delay={d}>{row}</FadeUp>;
      })}
    </div>
  );
};

export const DefinitionBlock: React.FC<BlockProps> = ({ block, theme, delay, writingStyle }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const hand = writingStyle !== "typed";
  const text: React.CSSProperties = {
    fontFamily: familyFor(writingStyle),
    fontSize: 46 * fontScaleFor(writingStyle),
    color: theme.accent,
    lineHeight: hand ? 1.35 : 1.5,
    fontWeight: hand ? 600 : 500,
    display: "block",
  };
  // Une définition est une notion clé : le professeur l'écrit lentement.
  const speed = block.write_speed ?? "slow";

  if (!hand) {
    return (
      <FadeUp delay={delay} style={{ marginBottom: 18 }}>
        <div style={{ ...text, paddingLeft: 16, borderLeft: `5px solid ${theme.accent}` }}>
          {block.content}
        </div>
      </FadeUp>
    );
  }

  // La barre verticale se TRACE de haut en bas en même temps que l'écriture, au lieu
  // d'apparaître d'un coup sur une zone encore vide (défaut vu au premier rendu).
  const total = writeDurationFrames(block.content || "", fps, speed);
  const grow = interpolate(frame - delay, [0, Math.max(1, total)], [0, 100], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <div style={{ marginBottom: 18, position: "relative", paddingLeft: 16 }}>
      <div
        style={{
          position: "absolute",
          left: 0,
          top: 0,
          width: 5,
          height: `${grow}%`,
          background: theme.accent,
          borderRadius: 3,
        }}
      />
      <HandwriteTargeted
        text={block.content}
        delay={delay}
        speed={speed}
        style={text}
        target={block.emphasis_target}
        kind={block.emphasis_target ? block.emphasis : undefined}
        color={theme.accent}
        highlight={theme.highlight}
        fps={fps}
      />
    </div>
  );
};

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
      // "html" seul : on ne génère PAS la couche MathML, donc aucun risque de voir la
      // formule en double si la CSS venait à manquer. Ceinture et bretelles.
      output: "html",
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

export const ExerciseBlock: React.FC<BlockProps> = ({ block, theme, delay, writingStyle }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const hand = writingStyle !== "typed";
  // Le cadre coloré n'apparaît qu'au moment où l'écriture commence : sinon on voyait
  // une boîte grise VIDE plusieurs secondes avant le texte (défaut du rendu du 25/07).
  const boxOpacity = interpolate(frame - delay, [0, 8], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const inner: React.CSSProperties = {
    fontFamily: familyFor(writingStyle),
    fontSize: 46 * fontScaleFor(writingStyle),
    color: theme.ink,
    lineHeight: hand ? 1.35 : 1.45,
    fontWeight: hand ? 600 : 500,
    display: "block",
  };
  const box: React.CSSProperties = {
    background: theme.accent2 + "18",
    padding: 16,
    borderRadius: 12,
  };
  const speed = block.write_speed ?? "normal";
  return hand ? (
    <div style={{ marginBottom: 18, ...box, opacity: boxOpacity }}>
      <HandwriteTargeted
        text={block.content}
        delay={delay}
        speed={speed}
        style={inner}
        target={block.emphasis_target}
        kind={block.emphasis_target ? block.emphasis : undefined}
        color={theme.accent}
        highlight={theme.highlight}
        fps={fps}
      />
    </div>
  ) : (
    <FadeUp delay={delay} style={{ marginBottom: 18 }}>
      <div style={{ ...box, ...inner }}>{block.content}</div>
    </FadeUp>
  );
};

// Correction : surlignage qui balaie + puce verte, texte écrit à la main.
export const CorrectionBlock: React.FC<BlockProps> = ({ block, theme, delay, writingStyle }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const hand = writingStyle !== "typed";
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
        fontFamily: familyFor(writingStyle),
        fontSize: 46 * fontScaleFor(writingStyle),
        fontWeight: hand ? 600 : 500,
        lineHeight: hand ? 1.35 : 1.45,
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
      {hand ? (
        <HandwriteTargeted
          text={block.content}
          delay={delay + Math.round(fps * 0.2)}
          speed={block.write_speed ?? "normal"}
          target={block.emphasis_target}
          kind={block.emphasis_target ? block.emphasis : undefined}
          color={theme.accent}
          highlight={theme.highlight}
          fps={fps}
        />
      ) : (
        <span>{block.content}</span>
      )}
    </div>
  );
};

export const StepBlock = ExerciseBlock;

/**
 * Durée totale d'écriture d'un bloc (frames) — sert à ne déclencher l'annotation
 * qu'UNE FOIS LE TEXTE ÉCRIT. Un professeur souligne après avoir écrit, jamais avant.
 */
export const blockWriteFrames = (
  block: Block,
  fps: number,
  writingStyle?: WritingStyle
): number => {
  if (writingStyle === "typed") return 16;
  if (block.type === "image" || block.type === "formula") return Math.round(fps * 0.6);
  const speed = block.write_speed ?? (block.type === "definition" ? "slow" : "normal");
  return writeDurationFrames(block.content || "", fps, speed);
};

export const renderBlock = (
  block: Block,
  theme: Theme,
  delay: number,
  key: number,
  writingStyle?: WritingStyle,
  emphasisDelay?: number
) => {
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
  const el = <Comp block={block} theme={theme} delay={delay} writingStyle={writingStyle} />;

  // Si l'IA a désigné des MOTS précis (`emphasis_target`), l'annotation est déjà
  // dessinée à l'intérieur du texte, au plus près des mots : on n'ajoute donc PAS
  // l'annotation de niveau bloc, qui produirait un second tracé, bien trop large.
  if (block.emphasis && block.emphasis_target) {
    return <React.Fragment key={key}>{el}</React.Fragment>;
  }
  // Annotation manuscrite (cercle / souligné / surligné) sur un bloc clé.
  if (block.emphasis) {
    return (
      <Emphasis
        key={key}
        kind={block.emphasis}
        color={theme.accent}
        highlight={theme.highlight}
        // L'annotation attend la fin de l'écriture (cf. blockWriteFrames).
        delay={emphasisDelay ?? delay + 16}
      >
        {el}
      </Emphasis>
    );
  }
  return <React.Fragment key={key}>{el}</React.Fragment>;
};
