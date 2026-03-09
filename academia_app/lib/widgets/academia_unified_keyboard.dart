import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Academia Unified Scientific Keyboard
//
// A single all-in-one keyboard that merges:
//   • Normal text input (ABC / 123)
//   • Smart math templates (integrals with bounds, fractions, areas, etc.)
//   • Physics & Chemistry symbols
//   • Greek letters & units
//   • Formatting (color, size, bold/italic)
//
// Design philosophy:
//   - ONE tap = complete structure with navigable placeholders (▫)
//   - ←/→ arrows jump between placeholders
//   - Live LaTeX preview at the top
//   - No external dependencies beyond flutter_math_fork
// ═══════════════════════════════════════════════════════════════════════════

/// Placeholder marker used inside templates.
/// The user fills these in; ←/→ arrows jump between them.
const String _ph = '◻'; // U+25FB white medium square

class AcademiaUnifiedKeyboard extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onChanged;
  final VoidCallback? onDone;

  /// Current text color for the equation overlay.
  final Color initialColor;

  /// Current font size for the equation overlay.
  final double initialFontSize;

  /// Called when the user changes color or size.
  final void Function(Color color, double fontSize)? onStyleChanged;

  const AcademiaUnifiedKeyboard({
    super.key,
    required this.controller,
    this.onChanged,
    this.onDone,
    this.initialColor = Colors.white,
    this.initialFontSize = 22,
    this.onStyleChanged,
  });

  @override
  State<AcademiaUnifiedKeyboard> createState() =>
      _AcademiaUnifiedKeyboardState();
}

class _AcademiaUnifiedKeyboardState extends State<AcademiaUnifiedKeyboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Color _currentColor;
  late double _currentFontSize;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _currentColor = widget.initialColor;
    _currentFontSize = widget.initialFontSize;
    // Listen to text changes for live preview refresh
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ── Insertion helpers ────────────────────────────────────────────────

  /// Insert [latex] at cursor.
  ///
  /// **Key behavior:**
  /// - If the current selection is exactly a ◻ placeholder AND [latex] does
  ///   NOT itself contain ◻ (i.e. it's a simple symbol/char), replace the ◻
  ///   with [latex] and auto-jump to the next ◻.
  /// - If [latex] contains ◻ placeholders (i.e. it's a template), insert it
  ///   and select the first ◻ so the user can fill it in.
  void _insert(String latex) {
    final ctrl = widget.controller;
    final text = ctrl.text;
    final sel = ctrl.selection;
    int pos = sel.isValid ? sel.baseOffset : text.length;
    if (pos < 0 || pos > text.length) pos = text.length;

    final bool isTemplate = latex.contains(_ph);
    final bool selIsPlaceholder = sel.isValid &&
        sel.start != sel.end &&
        sel.end - sel.start == 1 &&
        sel.start < text.length &&
        text[sel.start] == _ph;

    if (selIsPlaceholder && !isTemplate) {
      // Replace the selected ◻ with the typed character/symbol
      final newText = text.replaceRange(sel.start, sel.end, latex);
      final afterInsert = sel.start + latex.length;
      // Auto-jump to next ◻
      final nextPh = newText.indexOf(_ph, afterInsert);
      final fallbackPh = newText.indexOf(_ph);
      final targetPh = nextPh >= 0 ? nextPh : fallbackPh;
      ctrl.value = TextEditingValue(
        text: newText,
        selection: targetPh >= 0
            ? TextSelection(baseOffset: targetPh, extentOffset: targetPh + 1)
            : TextSelection.collapsed(offset: afterInsert),
      );
    } else if (sel.isValid && sel.start != sel.end) {
      // Replace selection with the latex (template or not)
      final newText = text.replaceRange(sel.start, sel.end, latex);
      final insertedEnd = sel.start + latex.length;
      final firstPh = newText.indexOf(_ph, sel.start);
      ctrl.value = TextEditingValue(
        text: newText,
        selection: (firstPh >= 0 && firstPh < insertedEnd)
            ? TextSelection(baseOffset: firstPh, extentOffset: firstPh + 1)
            : TextSelection.collapsed(offset: insertedEnd),
      );
    } else {
      // No selection — insert at cursor
      final newText =
          text.substring(0, pos) + latex + text.substring(pos);
      final insertedEnd = pos + latex.length;
      final firstPh = newText.indexOf(_ph, pos);
      ctrl.value = TextEditingValue(
        text: newText,
        selection: (firstPh >= 0 && firstPh < insertedEnd)
            ? TextSelection(baseOffset: firstPh, extentOffset: firstPh + 1)
            : TextSelection.collapsed(offset: insertedEnd),
      );
    }
    // Re-focus the text field so the cursor stays visible
    _focusNode.requestFocus();
    _notify();
  }

  /// Navigate to the next ◻ placeholder after the cursor.
  void _nextPlaceholder() {
    final ctrl = widget.controller;
    final text = ctrl.text;
    final sel = ctrl.selection;
    final from = sel.isValid ? sel.extentOffset : 0;
    var idx = text.indexOf(_ph, from);
    if (idx < 0) idx = text.indexOf(_ph); // wrap around
    if (idx >= 0) {
      ctrl.selection =
          TextSelection(baseOffset: idx, extentOffset: idx + 1);
      _focusNode.requestFocus();
      setState(() {});
    }
  }

  /// Navigate to the previous ◻ placeholder before the cursor.
  void _prevPlaceholder() {
    final ctrl = widget.controller;
    final text = ctrl.text;
    final sel = ctrl.selection;
    final from = sel.isValid ? sel.baseOffset - 1 : text.length;
    var idx = text.lastIndexOf(_ph, from.clamp(0, text.length));
    if (idx < 0) idx = text.lastIndexOf(_ph); // wrap around
    if (idx >= 0) {
      ctrl.selection =
          TextSelection(baseOffset: idx, extentOffset: idx + 1);
      _focusNode.requestFocus();
      setState(() {});
    }
  }

  void _backspace() {
    final ctrl = widget.controller;
    final text = ctrl.text;
    final sel = ctrl.selection;
    if (!sel.isValid) return;

    if (sel.start != sel.end) {
      final newText = text.replaceRange(sel.start, sel.end, '');
      ctrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: sel.start),
      );
    } else if (sel.baseOffset > 0) {
      // Try to delete a whole LaTeX command (e.g. \frac)
      int deleteFrom = sel.baseOffset - 1;
      // If char before is a letter and preceded by \, delete the whole command
      if (deleteFrom > 0) {
        int cmdStart = deleteFrom;
        while (cmdStart > 0 &&
            text[cmdStart].contains(RegExp(r'[a-zA-Z]'))) {
          cmdStart--;
        }
        if (cmdStart >= 0 && text[cmdStart] == '\\') {
          deleteFrom = cmdStart;
        }
      }
      final newText =
          text.substring(0, deleteFrom) + text.substring(sel.baseOffset);
      ctrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: deleteFrom),
      );
    }
    _notify();
  }

  void _clear() {
    widget.controller.clear();
    _notify();
  }

  void _notify() {
    widget.onChanged?.call();
    setState(() {});
  }

  // ── Key definitions ──────────────────────────────────────────────────

  // --- Tab 1: TEMPLATES (smart structures) ---
  static final List<_UKey> _templateKeys = [
    // Fractions
    _UKey('a/b', r'\frac{◻}{◻}', subtitle: 'Fraction'),
    // Powers & indices
    _UKey('x²', r'^{◻}', subtitle: 'Puissance'),
    _UKey('xₙ', r'_{◻}', subtitle: 'Indice'),
    _UKey('xₙᵐ', r'_{◻}^{◻}', subtitle: 'Indice+Puiss.'),
    // Roots
    _UKey('√x', r'\sqrt{◻}', subtitle: 'Racine carrée'),
    _UKey('ⁿ√x', r'\sqrt[◻]{◻}', subtitle: 'Racine n-ième'),
    // Integrals — smart: bounds pre-filled
    _UKey('∫ᵃᵇ', r'\int_{◻}^{◻} ◻ \, d◻', subtitle: 'Intégrale bornée'),
    _UKey('∫', r'\int ◻ \, d◻', subtitle: 'Intégrale simple'),
    // Area with brackets
    _UKey('[F]ᵃᵇ', r'\left[ ◻ \right]_{◻}^{◻}', subtitle: 'Aire / Crochet'),
    // Sums & Products
    _UKey('Σ', r'\sum_{◻}^{◻} ◻', subtitle: 'Somme'),
    _UKey('Π', r'\prod_{◻}^{◻} ◻', subtitle: 'Produit'),
    // Limits
    _UKey('lim', r'\lim_{◻ \to ◻} ◻', subtitle: 'Limite'),
    // Derivatives
    _UKey('d/dx', r'\frac{d}{d◻} ◻', subtitle: 'Dérivée'),
    _UKey('∂/∂x', r'\frac{\partial}{\partial ◻} ◻', subtitle: 'Dérivée part.'),
    // Systems
    _UKey('{=', r'\begin{cases} ◻ \\ ◻ \end{cases}', subtitle: 'Système 2 éq.'),
    _UKey('{≡', r'\begin{cases} ◻ \\ ◻ \\ ◻ \end{cases}', subtitle: 'Système 3 éq.'),
    // Matrices
    _UKey('[ ]₂', r'\begin{pmatrix} ◻ & ◻ \\ ◻ & ◻ \end{pmatrix}', subtitle: 'Matrice 2×2'),
    // Absolute value
    _UKey('|x|', r'\left| ◻ \right|', subtitle: 'Valeur absolue'),
    // Parentheses
    _UKey('()', r'\left( ◻ \right)', subtitle: 'Parenthèses'),
    _UKey('[]', r'\left[ ◻ \right]', subtitle: 'Crochets'),
    _UKey('{}', r'\left\{ ◻ \right\}', subtitle: 'Accolades'),
    // Chemistry: balanced equation
    _UKey('→', r'◻ \rightarrow ◻', subtitle: 'Réaction chimique'),
    _UKey('⇌', r'◻ \rightleftharpoons ◻', subtitle: 'Équilibre'),
    // Vectors
    _UKey('→v', r'\vec{◻}', subtitle: 'Vecteur'),
    _UKey('‖v‖', r'\left\| ◻ \right\|', subtitle: 'Norme'),
    // Overline / underline
    _UKey('x̄', r'\overline{◻}', subtitle: 'Barre sup.'),
    _UKey('x̲', r'\underline{◻}', subtitle: 'Souligné'),
    // Angles
    _UKey('∠', r'\angle ◻', subtitle: 'Angle'),
    // Binomial
    _UKey('C(n,k)', r'\binom{◻}{◻}', subtitle: 'Combinaison'),
    // Log
    _UKey('logₐ', r'\log_{◻} ◻', subtitle: 'Logarithme'),
  ];

  // --- Tab 2: SYMBOLS (math + physics + chemistry) ---
  static const List<_UKey> _symbolKeys = [
    // Operators
    _UKey('=', r'='), _UKey('≠', r'\neq'), _UKey('<', r'<'), _UKey('>', r'>'),
    _UKey('≤', r'\leq'), _UKey('≥', r'\geq'), _UKey('≈', r'\approx'),
    _UKey('±', r'\pm'), _UKey('×', r'\times'), _UKey('÷', r'\div'),
    _UKey('·', r'\cdot'), _UKey('∝', r'\propto'),
    // Sets
    _UKey('∈', r'\in'), _UKey('∉', r'\notin'),
    _UKey('⊂', r'\subset'), _UKey('∪', r'\cup'), _UKey('∩', r'\cap'),
    _UKey('∅', r'\emptyset'),
    _UKey('ℝ', r'\mathbb{R}'), _UKey('ℤ', r'\mathbb{Z}'),
    _UKey('ℕ', r'\mathbb{N}'), _UKey('ℚ', r'\mathbb{Q}'),
    _UKey('ℂ', r'\mathbb{C}'),
    // Logic
    _UKey('∀', r'\forall'), _UKey('∃', r'\exists'),
    _UKey('⇒', r'\Rightarrow'), _UKey('⇔', r'\Leftrightarrow'),
    // Constants
    _UKey('π', r'\pi'), _UKey('∞', r'\infty'), _UKey('ℏ', r'\hbar'),
    // Trig
    _UKey('sin', r'\sin'), _UKey('cos', r'\cos'), _UKey('tan', r'\tan'),
    _UKey('ln', r'\ln'), _UKey('exp', r'\exp'),
    // Arrows
    _UKey('→', r'\to'), _UKey('↑', r'\uparrow'), _UKey('↓', r'\downarrow'),
    // Chemistry states
    _UKey('(aq)', r'\text{(aq)}'), _UKey('(s)', r'\text{(s)}'),
    _UKey('(l)', r'\text{(l)}'), _UKey('(g)', r'\text{(g)}'),
    // Chemistry ions
    _UKey('+', r'^{+}'), _UKey('−', r'^{-}'),
    _UKey('2+', r'^{2+}'), _UKey('2−', r'^{2-}'),
    // Common molecules
    _UKey('H₂O', r'\text{H}_2\text{O}'),
    _UKey('CO₂', r'\text{CO}_2'),
    _UKey('O₂', r'\text{O}_2'),
    // Dots
    _UKey('…', r'\ldots'), _UKey('⋯', r'\cdots'),
    _UKey('°', r'^{\circ}'), _UKey('Δ', r'\Delta'),
  ];

  // --- Tab 3: GREEK + UNITS ---
  static const List<_UKey> _greekUnitsKeys = [
    // Greek lowercase
    _UKey('α', r'\alpha'), _UKey('β', r'\beta'), _UKey('γ', r'\gamma'),
    _UKey('δ', r'\delta'), _UKey('ε', r'\varepsilon'), _UKey('ζ', r'\zeta'),
    _UKey('η', r'\eta'), _UKey('θ', r'\theta'), _UKey('λ', r'\lambda'),
    _UKey('μ', r'\mu'), _UKey('ν', r'\nu'), _UKey('ξ', r'\xi'),
    _UKey('ρ', r'\rho'), _UKey('σ', r'\sigma'), _UKey('τ', r'\tau'),
    _UKey('φ', r'\varphi'), _UKey('ψ', r'\psi'), _UKey('ω', r'\omega'),
    // Greek uppercase
    _UKey('Γ', r'\Gamma'), _UKey('Δ', r'\Delta'), _UKey('Θ', r'\Theta'),
    _UKey('Λ', r'\Lambda'), _UKey('Σ', r'\Sigma'), _UKey('Φ', r'\Phi'),
    _UKey('Ψ', r'\Psi'), _UKey('Ω', r'\Omega'),
    // Units
    _UKey('m/s', r'\,\text{m/s}'), _UKey('m/s²', r'\,\text{m/s}^2'),
    _UKey('N', r'\,\text{N}'), _UKey('J', r'\,\text{J}'),
    _UKey('W', r'\,\text{W}'), _UKey('Pa', r'\,\text{Pa}'),
    _UKey('kg', r'\,\text{kg}'), _UKey('mol', r'\,\text{mol}'),
    _UKey('L', r'\,\text{L}'), _UKey('°C', r'\,°\text{C}'),
    _UKey('K', r'\,\text{K}'), _UKey('V', r'\,\text{V}'),
    _UKey('A', r'\,\text{A}'), _UKey('Ω', r'\,\Omega'),
    _UKey('Hz', r'\,\text{Hz}'), _UKey('eV', r'\,\text{eV}'),
    _UKey('M', r'\,\text{M}'), _UKey('g', r'\,\text{g}'),
    _UKey('pH', r'\text{pH}'), _UKey('Ka', r'K_a'), _UKey('Kb', r'K_b'),
  ];

  // --- Tab 4: ABC / 123 ---
  static const List<_UKey> _abcKeys = [
    _UKey('1', r'1'), _UKey('2', r'2'), _UKey('3', r'3'),
    _UKey('4', r'4'), _UKey('5', r'5'), _UKey('6', r'6'),
    _UKey('7', r'7'), _UKey('8', r'8'), _UKey('9', r'9'),
    _UKey('0', r'0'), _UKey('.', r'.'), _UKey(',', r','),
    _UKey('+', r'+'), _UKey('−', r'-'), _UKey('=', r'='),
    _UKey('(', r'('), _UKey(')', r')'), _UKey('/', r'/'),
    _UKey('a', r'a'), _UKey('b', r'b'), _UKey('c', r'c'),
    _UKey('d', r'd'), _UKey('e', r'e'), _UKey('f', r'f'),
    _UKey('x', r'x'), _UKey('y', r'y'), _UKey('z', r'z'),
    _UKey('n', r'n'), _UKey('t', r't'), _UKey('k', r'k'),
    _UKey('i', r'i'), _UKey('m', r'm'), _UKey('p', r'p'),
    _UKey('r', r'r'), _UKey('s', r's'), _UKey('u', r'u'),
    _UKey(' ', r'\,', subtitle: 'espace'),
  ];

  // ── Colors ───────────────────────────────────────────────────────────

  static const List<Color> _colors = [
    Colors.white,
    Color(0xFFFF2D55), // red
    Color(0xFFFF9500), // orange
    Color(0xFFFFCC00), // yellow
    Color(0xFF34C759), // green
    Color(0xFF00D2FF), // cyan
    Color(0xFF5856D6), // purple
    Color(0xFFFF6B9D), // pink
    Colors.black,
  ];

  static const List<double> _fontSizes = [14, 18, 22, 28, 36, 48];

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ──
          const SizedBox(height: 8),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 6),

          // ── Live preview ──
          _buildPreview(),

          // ── Editable text field ──
          _buildTextField(),

          // ── Formatting bar (color + size) ──
          _buildFormattingBar(),

          // ── Tab bar ──
          _buildTabBar(),

          // ── Key grid ──
          SizedBox(
            height: 240,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTemplateGrid(),
                _buildSymbolGrid(),
                _buildSimpleGrid(_greekUnitsKeys),
                _buildSimpleGrid(_abcKeys),
              ],
            ),
          ),

          // ── Action bar ──
          _buildActionBar(),
          SizedBox(height: bottomPad + 4),
        ],
      ),
    );
  }

  // ── Editable text field ────────────────────────────────────────────

  Widget _buildTextField() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        autofocus: true,
        maxLines: 2,
        minLines: 1,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontFamily: 'monospace',
        ),
        // Use a transparent keyboard type to avoid the system keyboard
        // popping up — our custom keyboard handles all input.
        readOnly: true,
        showCursor: true,
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          hintText: r'Ex: \frac{a}{b} ou tape un template…',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.2),
            fontSize: 13,
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF00D2FF), width: 1.5),
          ),
        ),
      ),
    );
  }

  // ── Preview ──────────────────────────────────────────────────────────

  Widget _buildPreview() {
    final latex = widget.controller.text.trim();
    // Replace placeholder with a visible box for preview
    final displayLatex = latex.replaceAll(_ph, r'\square');

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 52),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: latex.isEmpty
          ? Text(
              'Tape une équation, formule ou texte…',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 16,
                fontStyle: FontStyle.italic,
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Math.tex(
                displayLatex,
                textStyle: TextStyle(
                  color: _currentColor,
                  fontSize: _currentFontSize,
                ),
                onErrorFallback: (err) => Text(
                  latex,
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: _currentFontSize * 0.8,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
    );
  }

  // ── Formatting bar ───────────────────────────────────────────────────

  Widget _buildFormattingBar() {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          // Color dots
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _colors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final c = _colors[i];
                final selected = c.value == _currentColor.value;
                return GestureDetector(
                  onTap: () {
                    setState(() => _currentColor = c);
                    widget.onStyleChanged?.call(_currentColor, _currentFontSize);
                  },
                  child: Container(
                    width: 26, height: 26,
                    margin: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF00D2FF)
                            : (c == Colors.black ? Colors.white24 : Colors.transparent),
                        width: selected ? 2.5 : 1,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          // Font size selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<double>(
                value: _currentFontSize,
                dropdownColor: const Color(0xFF1A1A2E),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                iconEnabledColor: Colors.white54,
                items: _fontSizes.map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Text('${s.toInt()}',
                        style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _currentFontSize = v);
                    widget.onStyleChanged
                        ?.call(_currentColor, _currentFontSize);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab bar ──────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      isScrollable: false,
      indicatorColor: const Color(0xFF00D2FF),
      indicatorWeight: 3,
      labelColor: const Color(0xFF00D2FF),
      unselectedLabelColor: Colors.white38,
      labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(fontSize: 10),
      labelPadding: EdgeInsets.zero,
      tabs: const [
        Tab(icon: Icon(Icons.auto_awesome, size: 16), text: 'TEMPLATES'),
        Tab(icon: Icon(Icons.functions, size: 16), text: 'SYMBOLES'),
        Tab(icon: Icon(Icons.science, size: 16), text: 'GREC/UNITÉS'),
        Tab(icon: Icon(Icons.keyboard, size: 16), text: 'ABC 123'),
      ],
    );
  }

  // ── Template grid (with subtitles) ───────────────────────────────────

  Widget _buildTemplateGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          mainAxisSpacing: 5,
          crossAxisSpacing: 5,
          childAspectRatio: 1.0,
        ),
        itemCount: _templateKeys.length,
        itemBuilder: (context, index) {
          final key = _templateKeys[index];
          return _TemplateKeyButton(
            label: key.label,
            subtitle: key.subtitle,
            onTap: () => _insert(key.latex),
          );
        },
      ),
    );
  }

  // ── Symbol grid ──────────────────────────────────────────────────────

  Widget _buildSymbolGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 1.2,
        ),
        itemCount: _symbolKeys.length,
        itemBuilder: (context, index) {
          final key = _symbolKeys[index];
          return _SimpleKeyButton(
            label: key.label,
            onTap: () => _insert(key.latex),
          );
        },
      ),
    );
  }

  // ── Simple grid (greek/units, abc) ───────────────────────────────────

  Widget _buildSimpleGrid(List<_UKey> keys) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 1.2,
        ),
        itemCount: keys.length,
        itemBuilder: (context, index) {
          final key = keys[index];
          return _SimpleKeyButton(
            label: key.label,
            onTap: () => _insert(key.latex),
          );
        },
      ),
    );
  }

  // ── Action bar ───────────────────────────────────────────────────────

  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          _ActionBtn(icon: Icons.delete_outline, onTap: _clear,
              tooltip: 'Tout effacer'),
          const SizedBox(width: 6),
          _ActionBtn(icon: Icons.backspace_outlined, onTap: _backspace,
              onLongPress: _clear, tooltip: 'Supprimer'),
          const SizedBox(width: 6),
          _ActionBtn(icon: Icons.chevron_left, onTap: _prevPlaceholder,
              tooltip: '◻ précédent'),
          const SizedBox(width: 6),
          _ActionBtn(icon: Icons.chevron_right, onTap: _nextPlaceholder,
              tooltip: '◻ suivant'),
          const Spacer(),
          // Placeholder count indicator
          Builder(builder: (_) {
            final count = _ph.allMatches(widget.controller.text).length;
            if (count > 0) {
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  '$count ◻',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          }),
          // Done
          FilledButton.icon(
            onPressed: widget.onDone,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('OK'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00D2FF),
              foregroundColor: Colors.black,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Data model
// ═══════════════════════════════════════════════════════════════════════════

class _UKey {
  final String label;
  final String latex;
  final String? subtitle;

  const _UKey(this.label, this.latex, {this.subtitle});
}

// ═══════════════════════════════════════════════════════════════════════════
// Template key button (larger, with subtitle)
// ═══════════════════════════════════════════════════════════════════════════

class _TemplateKeyButton extends StatelessWidget {
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _TemplateKeyButton({
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1A2E),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        splashColor: const Color(0xFF00D2FF).withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    subtitle!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 8,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Simple key button
// ═══════════════════════════════════════════════════════════════════════════

class _SimpleKeyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SimpleKeyButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        splashColor: const Color(0xFF00D2FF).withValues(alpha: 0.3),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Action button
// ═══════════════════════════════════════════════════════════════════════════

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? tooltip;

  const _ActionBtn({
    required this.icon,
    required this.onTap,
    this.onLongPress,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Icon(icon, color: Colors.white60, size: 20),
          ),
        ),
      ),
    );
  }
}
