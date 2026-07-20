/**
 * KaTeX Server-Side Renderer
 * Smart Whiteboard Vision Engine
 * 
 * Usage: node katex_renderer.js '\\frac{a}{b}'
 * Returns: HTML string with KaTeX rendering
 */

const katex = require('katex');

function renderFormula(latex) {
  try {
    const html = katex.renderToString(latex, {
      throwOnError: false,
      displayMode: true,
      strict: false,
      trust: true,
      macros: {
        "\\R": "\\mathbb{R}",
        "\\N": "\\mathbb{N}",
        "\\Z": "\\mathbb{Z}",
        "\\Q": "\\mathbb{Q}",
        "\\C": "\\mathbb{C}",
        "\\vec": "\\overrightarrow",
      }
    });
    return html;
  } catch (e) {
    // Fallback: render as text if KaTeX fails
    return `<span class="katex-error">${latex}</span>`;
  }
}

// CLI mode: render formula passed as argument
if (require.main === module) {
  const input = process.argv[2];
  if (!input) {
    console.error('Usage: node katex_renderer.js "<latex expression>"');
    process.exit(1);
  }
  console.log(renderFormula(input));
}

module.exports = { renderFormula };
