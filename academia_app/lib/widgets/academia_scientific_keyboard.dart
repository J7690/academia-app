import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// A fully custom scientific keyboard for Academia.
///
/// 5 tabs: Maths, Physics, Chemistry, Operators, ABC/123.
/// Each button inserts LaTeX into the provided [TextEditingController].
/// A live preview renders the current LaTeX expression at the top.
class AcademiaScientificKeyboard extends StatefulWidget {
  final TextEditingController controller;

  /// Called whenever the user taps a key (after insertion).
  final VoidCallback? onChanged;

  /// Called when the user taps the "Done" / confirm button.
  final VoidCallback? onDone;

  const AcademiaScientificKeyboard({
    super.key,
    required this.controller,
    this.onChanged,
    this.onDone,
  });

  @override
  State<AcademiaScientificKeyboard> createState() =>
      _AcademiaScientificKeyboardState();
}

class _AcademiaScientificKeyboardState
    extends State<AcademiaScientificKeyboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Key insertion logic ──────────────────────────────────────────────

  /// Insert [latex] at the current cursor position.
  /// If [latex] contains `{}` placeholders, place the cursor inside the first one.
  void _insert(String latex) {
    final ctrl = widget.controller;
    final text = ctrl.text;
    final sel = ctrl.selection;

    int insertPos = sel.isValid ? sel.baseOffset : text.length;
    if (insertPos < 0 || insertPos > text.length) insertPos = text.length;

    // If there's a selection, wrap it
    if (sel.isValid && sel.start != sel.end) {
      final selected = text.substring(sel.start, sel.end);
      // Replace first {} with the selected text
      final replaced = latex.replaceFirst('{}', '{$selected}');
      final newText = text.replaceRange(sel.start, sel.end, replaced);
      ctrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: sel.start + replaced.length,
        ),
      );
    } else {
      final newText = text.substring(0, insertPos) +
          latex +
          text.substring(insertPos);

      // Place cursor inside first {} if present
      final firstBrace = latex.indexOf('{}');
      final cursorOffset = firstBrace >= 0
          ? insertPos + firstBrace + 1
          : insertPos + latex.length;

      ctrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursorOffset),
      );
    }

    widget.onChanged?.call();
    setState(() {}); // refresh preview
  }

  void _backspace() {
    final ctrl = widget.controller;
    final text = ctrl.text;
    final sel = ctrl.selection;

    if (!sel.isValid) return;

    if (sel.start != sel.end) {
      // Delete selection
      final newText = text.replaceRange(sel.start, sel.end, '');
      ctrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: sel.start),
      );
    } else if (sel.baseOffset > 0) {
      // Delete one character before cursor
      // But try to delete a whole LaTeX command if the char before is }
      int deleteFrom = sel.baseOffset - 1;

      // Smart delete: if we're after a closing brace of a command like \frac{}{}
      // just delete one char for now (simple approach)
      final newText = text.substring(0, deleteFrom) +
          text.substring(sel.baseOffset);
      ctrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: deleteFrom),
      );
    }

    widget.onChanged?.call();
    setState(() {});
  }

  void _clear() {
    widget.controller.clear();
    widget.onChanged?.call();
    setState(() {});
  }

  // ── Key definitions ──────────────────────────────────────────────────

  /// Each key: (display label, LaTeX to insert, optional TeX preview)
  static const List<_SciKey> _mathKeys = [
    _SciKey('⅟', r'\frac{}{}', texPreview: r'\frac{a}{b}'),
    _SciKey('x²', r'^{}', texPreview: r'x^{2}'),
    _SciKey('x₂', r'_{}', texPreview: r'x_{2}'),
    _SciKey('√', r'\sqrt{}', texPreview: r'\sqrt{x}'),
    _SciKey('ⁿ√', r'\sqrt[{}]{}', texPreview: r'\sqrt[n]{x}'),
    _SciKey('π', r'\pi'),
    _SciKey('∞', r'\infty'),
    _SciKey('∫', r'\int_{}^{}', texPreview: r'\int_{a}^{b}'),
    _SciKey('∑', r'\sum_{}^{}', texPreview: r'\sum_{i=0}^{n}'),
    _SciKey('∏', r'\prod_{}^{}', texPreview: r'\prod_{i=1}^{n}'),
    _SciKey('lim', r'\lim_{}\,', texPreview: r'\lim_{x \to 0}'),
    _SciKey('log', r'\log_{}', texPreview: r'\log_{10}'),
    _SciKey('ln', r'\ln\,'),
    _SciKey('sin', r'\sin\,'),
    _SciKey('cos', r'\cos\,'),
    _SciKey('tan', r'\tan\,'),
    _SciKey('|x|', r'\left|{}\right|', texPreview: r'\left|x\right|'),
    _SciKey('()', r'\left({}\right)', texPreview: r'\left(\right)'),
    _SciKey('[]', r'\left[{}\right]', texPreview: r'\left[\right]'),
    _SciKey('{}', r'\left\{{}\right\}', texPreview: r'\left\{\right\}'),
    _SciKey('→', r'\to'),
    _SciKey('⇒', r'\Rightarrow'),
    _SciKey('⇔', r'\Leftrightarrow'),
    _SciKey('∂', r'\partial'),
    _SciKey('dx', r'\,dx'),
    _SciKey('e', r'e'),
    _SciKey('i', r'i'),
    _SciKey('θ', r'\theta'),
  ];

  static const List<_SciKey> _physicsKeys = [
    _SciKey('→v', r'\vec{}', texPreview: r'\vec{v}'),
    _SciKey('α', r'\alpha'),
    _SciKey('β', r'\beta'),
    _SciKey('γ', r'\gamma'),
    _SciKey('δ', r'\delta'),
    _SciKey('Δ', r'\Delta'),
    _SciKey('ε', r'\varepsilon'),
    _SciKey('λ', r'\lambda'),
    _SciKey('μ', r'\mu'),
    _SciKey('ν', r'\nu'),
    _SciKey('ω', r'\omega'),
    _SciKey('Ω', r'\Omega'),
    _SciKey('σ', r'\sigma'),
    _SciKey('τ', r'\tau'),
    _SciKey('φ', r'\varphi'),
    _SciKey('ρ', r'\rho'),
    _SciKey('η', r'\eta'),
    _SciKey('m/s', r'\,\text{m/s}'),
    _SciKey('m/s²', r'\,\text{m/s}^2'),
    _SciKey('N', r'\,\text{N}'),
    _SciKey('J', r'\,\text{J}'),
    _SciKey('W', r'\,\text{W}'),
    _SciKey('Pa', r'\,\text{Pa}'),
    _SciKey('kg', r'\,\text{kg}'),
    _SciKey('°C', r'\,°\text{C}'),
    _SciKey('K', r'\,\text{K}'),
    _SciKey('V', r'\,\text{V}'),
    _SciKey('A', r'\,\text{A}'),
    _SciKey('F', r'\,\text{F}'),
    _SciKey('Hz', r'\,\text{Hz}'),
    _SciKey('eV', r'\,\text{eV}'),
    _SciKey('ℏ', r'\hbar'),
  ];

  static const List<_SciKey> _chemistryKeys = [
    _SciKey('→', r'\rightarrow'),
    _SciKey('⇌', r'\rightleftharpoons'),
    _SciKey('↑', r'\uparrow'),
    _SciKey('↓', r'\downarrow'),
    _SciKey('H₂O', r'\text{H}_2\text{O}'),
    _SciKey('CO₂', r'\text{CO}_2'),
    _SciKey('O₂', r'\text{O}_2'),
    _SciKey('N₂', r'\text{N}_2'),
    _SciKey('H₂', r'\text{H}_2'),
    _SciKey('sub', r'_{}', texPreview: r'X_{2}'),
    _SciKey('sup', r'^{}', texPreview: r'X^{2+}'),
    _SciKey('+', r'^{+}'),
    _SciKey('−', r'^{-}'),
    _SciKey('2+', r'^{2+}'),
    _SciKey('2−', r'^{2-}'),
    _SciKey('3+', r'^{3+}'),
    _SciKey('(aq)', r'\text{(aq)}'),
    _SciKey('(s)', r'\text{(s)}'),
    _SciKey('(l)', r'\text{(l)}'),
    _SciKey('(g)', r'\text{(g)}'),
    _SciKey('Δ', r'\Delta'),
    _SciKey('°', r'^{\circ}'),
    _SciKey('mol', r'\,\text{mol}'),
    _SciKey('L', r'\,\text{L}'),
    _SciKey('g', r'\,\text{g}'),
    _SciKey('M', r'\,\text{M}'),
    _SciKey('pH', r'\text{pH}'),
    _SciKey('Ka', r'K_a'),
    _SciKey('Kb', r'K_b'),
    _SciKey('Kw', r'K_w'),
    _SciKey('[]', r'\left[{}\right]', texPreview: r'\left[X\right]'),
    _SciKey('n()', r'n({})'),
  ];

  static const List<_SciKey> _operatorKeys = [
    _SciKey('=', r'='),
    _SciKey('≠', r'\neq'),
    _SciKey('<', r'<'),
    _SciKey('>', r'>'),
    _SciKey('≤', r'\leq'),
    _SciKey('≥', r'\geq'),
    _SciKey('≈', r'\approx'),
    _SciKey('±', r'\pm'),
    _SciKey('×', r'\times'),
    _SciKey('÷', r'\div'),
    _SciKey('·', r'\cdot'),
    _SciKey('∈', r'\in'),
    _SciKey('∉', r'\notin'),
    _SciKey('⊂', r'\subset'),
    _SciKey('⊃', r'\supset'),
    _SciKey('∪', r'\cup'),
    _SciKey('∩', r'\cap'),
    _SciKey('∀', r'\forall'),
    _SciKey('∃', r'\exists'),
    _SciKey('∅', r'\emptyset'),
    _SciKey('ℝ', r'\mathbb{R}'),
    _SciKey('ℤ', r'\mathbb{Z}'),
    _SciKey('ℕ', r'\mathbb{N}'),
    _SciKey('ℚ', r'\mathbb{Q}'),
    _SciKey('ℂ', r'\mathbb{C}'),
    _SciKey('∝', r'\propto'),
    _SciKey('‖', r'\|'),
    _SciKey('…', r'\ldots'),
  ];

  static const List<_SciKey> _abcKeys = [
    _SciKey('1', r'1'), _SciKey('2', r'2'), _SciKey('3', r'3'),
    _SciKey('4', r'4'), _SciKey('5', r'5'), _SciKey('6', r'6'),
    _SciKey('7', r'7'), _SciKey('8', r'8'), _SciKey('9', r'9'),
    _SciKey('0', r'0'), _SciKey('.', r'.'), _SciKey(',', r','),
    _SciKey('+', r'+'), _SciKey('−', r'-'), _SciKey('=', r'='),
    _SciKey('(', r'('), _SciKey(')', r')'),
    _SciKey('a', r'a'), _SciKey('b', r'b'), _SciKey('c', r'c'),
    _SciKey('d', r'd'), _SciKey('e', r'e'), _SciKey('f', r'f'),
    _SciKey('x', r'x'), _SciKey('y', r'y'), _SciKey('z', r'z'),
    _SciKey('n', r'n'), _SciKey('t', r't'), _SciKey('k', r'k'),
    _SciKey(' ', r'\,', texPreview: r'\,'),
  ];

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle bar ──
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),

          // ── Live LaTeX preview ──
          _buildPreview(),

          // ── Tab bar ──
          _buildTabBar(),

          // ── Key grid ──
          SizedBox(
            height: 220,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildKeyGrid(_mathKeys),
                _buildKeyGrid(_physicsKeys),
                _buildKeyGrid(_chemistryKeys),
                _buildKeyGrid(_operatorKeys),
                _buildKeyGrid(_abcKeys),
              ],
            ),
          ),

          // ── Bottom action row ──
          _buildActionRow(),
          SizedBox(height: bottomPad + 4),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final latex = widget.controller.text.trim();
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 48),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: latex.isEmpty
          ? Text(
              'Tape une équation…',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 16,
                fontStyle: FontStyle.italic,
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Math.tex(
                latex,
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                ),
                onErrorFallback: (err) => Text(
                  latex,
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 18,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      isScrollable: false,
      indicatorColor: const Color(0xFF00D2FF),
      indicatorWeight: 3,
      labelColor: const Color(0xFF00D2FF),
      unselectedLabelColor: Colors.white54,
      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
      tabs: const [
        Tab(text: 'MATHS'),
        Tab(text: 'PHYSIQUE'),
        Tab(text: 'CHIMIE'),
        Tab(text: 'OPÉRAT.'),
        Tab(text: 'ABC 123'),
      ],
    );
  }

  Widget _buildKeyGrid(List<_SciKey> keys) {
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
          return _KeyButton(
            label: key.label,
            texPreview: key.texPreview,
            onTap: () => _insert(key.latex),
          );
        },
      ),
    );
  }

  Widget _buildActionRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // Clear
          _ActionButton(
            icon: Icons.delete_outline,
            label: 'Effacer',
            onTap: _clear,
          ),
          const SizedBox(width: 8),
          // Backspace
          _ActionButton(
            icon: Icons.backspace_outlined,
            label: 'Suppr',
            onTap: _backspace,
            onLongPress: _clear,
          ),
          const SizedBox(width: 8),
          // Left cursor
          _ActionButton(
            icon: Icons.chevron_left,
            label: '←',
            onTap: () {
              final ctrl = widget.controller;
              final sel = ctrl.selection;
              if (sel.isValid && sel.baseOffset > 0) {
                ctrl.selection = TextSelection.collapsed(
                  offset: sel.baseOffset - 1,
                );
              }
            },
          ),
          const SizedBox(width: 8),
          // Right cursor
          _ActionButton(
            icon: Icons.chevron_right,
            label: '→',
            onTap: () {
              final ctrl = widget.controller;
              final sel = ctrl.selection;
              if (sel.isValid && sel.baseOffset < ctrl.text.length) {
                ctrl.selection = TextSelection.collapsed(
                  offset: sel.baseOffset + 1,
                );
              }
            },
          ),
          const Spacer(),
          // Done button
          FilledButton.icon(
            onPressed: widget.onDone,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('OK'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00D2FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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

// ── Data model ─────────────────────────────────────────────────────────

class _SciKey {
  final String label;
  final String latex;
  final String? texPreview;

  const _SciKey(this.label, this.latex, {this.texPreview});
}

// ── Key button widget ──────────────────────────────────────────────────

class _KeyButton extends StatelessWidget {
  final String label;
  final String? texPreview;
  final VoidCallback onTap;

  const _KeyButton({
    required this.label,
    this.texPreview,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        splashColor: const Color(0xFF00D2FF).withValues(alpha: 0.3),
        child: Center(
          child: texPreview != null
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Math.tex(
                      texPreview!,
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                      onErrorFallback: (_) => Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
              : Text(
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
    );
  }
}

// ── Action button widget ───────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
      ),
    );
  }
}
