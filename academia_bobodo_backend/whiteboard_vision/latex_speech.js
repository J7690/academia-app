/**
 * latex_speech.js — Verbalisation française d'expressions LaTeX pour le TTS.
 * Smart Whiteboard — Vague C (27/07/2026)
 *
 * Usage : echo '["\\frac{a}{b}", "x^2"]' | node latex_speech.js
 * Sortie : JSON {"status":"ok","speech":["a sur b","x au carré"]}
 *          (un élément `null` = échec sur CETTE expression, repli côté Python)
 *
 * ─── POURQUOI ───────────────────────────────────────────────────────────────
 * Le module maison `math_speech_fr.py` (regex) ne couvrira jamais toutes les
 * mathématiques. Speech Rule Engine (SRE) est LE moteur de verbalisation utilisé
 * par MathJax et ChromeVox, localisé en français, avec les règles ClearSpeak
 * (lecture naturelle de professeur). Chaîne : LaTeX -> MathML (KaTeX, déjà
 * installé pour les formules à l'écran) -> parole française (SRE).
 *
 * Toute erreur est PAR EXPRESSION : une formule exotique ne prive pas les autres
 * de leur verbalisation, et Python garde son repli regex pour celle-là.
 */

const fs = require('fs');
const katex = require('katex');
const sre = require('speech-rule-engine');

function toMathML(latex) {
  // KaTeX produit <span class="katex"><math>...</math></span> : on extrait <math>.
  const html = katex.renderToString(latex, {
    output: 'mathml',
    throwOnError: true,
    strict: 'ignore',
  });
  const m = html.match(/<math[\s\S]*?<\/math>/);
  if (!m) throw new Error('MathML introuvable dans la sortie KaTeX');
  return m[0];
}

async function main() {
  const input = JSON.parse(fs.readFileSync(0, 'utf8'));
  if (!Array.isArray(input)) throw new Error('entrée attendue : tableau JSON de chaînes LaTeX');

  // ClearSpeak français ; si une règle manque, SRE retombe de lui-même sur les
  // règles par défaut de la locale.
  await sre.setupEngine({
    locale: 'fr',
    domain: 'clearspeak',
    modality: 'speech',
    markup: 'none',
    style: 'default',
  });
  await sre.engineReady();

  const speech = input.map((latex) => {
    try {
      const text = sre.toSpeech(toMathML(String(latex)));
      const clean = String(text).replace(/\s+/g, ' ').trim();
      return clean || null;
    } catch (err) {
      return null;
    }
  });

  process.stdout.write(JSON.stringify({ status: 'ok', speech }));
}

main().catch((err) => {
  process.stdout.write(JSON.stringify({ status: 'error', message: err.message }));
  process.exit(1);
});
