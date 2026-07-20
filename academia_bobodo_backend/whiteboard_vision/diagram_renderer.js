/**
 * Diagram Renderer (Mermaid)
 * Smart Whiteboard Vision Engine
 * 
 * Usage: node diagram_renderer.js '<mermaid definition>' output.svg
 * Returns: SVG string of the rendered diagram
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

/**
 * Render a Mermaid diagram definition to SVG string
 * @param {string} mermaidDef - Mermaid diagram definition
 * @returns {string} SVG content
 */
function renderDiagram(mermaidDef) {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'mermaid-'));
  const inputFile = path.join(tmpDir, 'input.mmd');
  const outputFile = path.join(tmpDir, 'output.svg');

  try {
    fs.writeFileSync(inputFile, mermaidDef, 'utf-8');

    // Use mmdc (mermaid-cli) to render
    const mmdc = path.join(__dirname, 'node_modules', '.bin', 'mmdc');
    execSync(`${mmdc} -i "${inputFile}" -o "${outputFile}" -b transparent --width 900`, {
      timeout: 30000,
      stdio: 'pipe'
    });

    if (fs.existsSync(outputFile)) {
      return fs.readFileSync(outputFile, 'utf-8');
    }
    return `<svg><text x="10" y="30">Diagram render failed</text></svg>`;
  } catch (e) {
    return `<svg><text x="10" y="30">Error: ${e.message.slice(0, 100)}</text></svg>`;
  } finally {
    // Cleanup
    try {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    } catch (_) {}
  }
}

// CLI mode
if (require.main === module) {
  const input = process.argv[2];
  if (!input) {
    console.error('Usage: node diagram_renderer.js "<mermaid definition>"');
    process.exit(1);
  }
  console.log(renderDiagram(input));
}

module.exports = { renderDiagram };
