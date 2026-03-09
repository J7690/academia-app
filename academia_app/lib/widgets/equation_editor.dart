import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Academia WYSIWYG Equation Editor
//
// Recursive visual equation editor with clickable slots.
// Each slot can contain text AND nested structures (recursive).
// ═══════════════════════════════════════════════════════════════════════════

// ── Data model ─────────────────────────────────────────────────────────

/// A fillable slot that can contain a mix of text and nested structures.
class EqSlot {
  final String id;
  final List<EqNode> children;
  final String hint;

  EqSlot({required this.id, List<EqNode>? children, this.hint = ''})
      : children = children ?? [];

  bool get isEmpty => children.isEmpty;

  String toLatex() {
    if (children.isEmpty) return r'\square';
    return children.map((n) => n.toLatex()).join(' ');
  }
}

/// Base class for equation nodes.
abstract class EqNode {
  String toLatex();
  List<EqSlot> get slots => [];
}

/// Fixed text/symbol (not editable).
class EqFixed extends EqNode {
  final String latex;
  EqFixed(this.latex);

  @override
  String toLatex() => latex;
}

/// Fraction: \frac{num}{den}
class EqFraction extends EqNode {
  final EqSlot numerator;
  final EqSlot denominator;
  EqFraction()
      : numerator = EqSlot(id: _uid(), hint: 'num'),
        denominator = EqSlot(id: _uid(), hint: 'den');

  @override
  String toLatex() => '\\frac{${numerator.toLatex()}}{${denominator.toLatex()}}';
  @override
  List<EqSlot> get slots => [numerator, denominator];
}

/// Power: base^{exp}
class EqPower extends EqNode {
  final EqSlot base;
  final EqSlot exponent;
  EqPower()
      : base = EqSlot(id: _uid(), hint: 'base'),
        exponent = EqSlot(id: _uid(), hint: 'n');

  @override
  String toLatex() => '{${base.toLatex()}}^{${exponent.toLatex()}}';
  @override
  List<EqSlot> get slots => [base, exponent];
}

/// Subscript: base_{sub}
class EqSubscript extends EqNode {
  final EqSlot base;
  final EqSlot subscript;
  EqSubscript()
      : base = EqSlot(id: _uid(), hint: 'base'),
        subscript = EqSlot(id: _uid(), hint: 'ind');

  @override
  String toLatex() => '{${base.toLatex()}}_{${subscript.toLatex()}}';
  @override
  List<EqSlot> get slots => [base, subscript];
}

/// Square root: \sqrt{content}
class EqSqrt extends EqNode {
  final EqSlot content;
  EqSqrt() : content = EqSlot(id: _uid(), hint: 'x');

  @override
  String toLatex() => '\\sqrt{${content.toLatex()}}';
  @override
  List<EqSlot> get slots => [content];
}

/// Nth root: \sqrt[n]{content}
class EqNthRoot extends EqNode {
  final EqSlot degree;
  final EqSlot content;
  EqNthRoot()
      : degree = EqSlot(id: _uid(), hint: 'n'),
        content = EqSlot(id: _uid(), hint: 'x');

  @override
  String toLatex() => '\\sqrt[${degree.toLatex()}]{${content.toLatex()}}';
  @override
  List<EqSlot> get slots => [degree, content];
}

/// Definite integral: \int_{a}^{b} f(x) \, dx
class EqIntegral extends EqNode {
  final EqSlot lower, upper, body, variable;
  EqIntegral()
      : lower = EqSlot(id: _uid(), hint: 'a'),
        upper = EqSlot(id: _uid(), hint: 'b'),
        body = EqSlot(id: _uid(), hint: 'f(x)'),
        variable = EqSlot(id: _uid(), hint: 'x');

  @override
  String toLatex() =>
      '\\int_{${lower.toLatex()}}^{${upper.toLatex()}} ${body.toLatex()} \\, d${variable.toLatex()}';
  @override
  List<EqSlot> get slots => [lower, upper, body, variable];
}

/// Simple integral: \int f(x) \, dx
class EqSimpleIntegral extends EqNode {
  final EqSlot body, variable;
  EqSimpleIntegral()
      : body = EqSlot(id: _uid(), hint: 'f(x)'),
        variable = EqSlot(id: _uid(), hint: 'x');

  @override
  String toLatex() => '\\int ${body.toLatex()} \\, d${variable.toLatex()}';
  @override
  List<EqSlot> get slots => [body, variable];
}

/// Evaluation brackets: [F(x)]_a^b
class EqBracketEval extends EqNode {
  final EqSlot content, lower, upper;
  EqBracketEval()
      : content = EqSlot(id: _uid(), hint: 'F(x)'),
        lower = EqSlot(id: _uid(), hint: 'a'),
        upper = EqSlot(id: _uid(), hint: 'b');

  @override
  String toLatex() =>
      '\\left[ ${content.toLatex()} \\right]_{${lower.toLatex()}}^{${upper.toLatex()}}';
  @override
  List<EqSlot> get slots => [content, lower, upper];
}

/// Sum: \sum_{i=a}^{b} expr
class EqSum extends EqNode {
  final EqSlot lower, upper, body;
  EqSum()
      : lower = EqSlot(id: _uid(), hint: 'i=0'),
        upper = EqSlot(id: _uid(), hint: 'n'),
        body = EqSlot(id: _uid(), hint: 'expr');

  @override
  String toLatex() =>
      '\\sum_{${lower.toLatex()}}^{${upper.toLatex()}} ${body.toLatex()}';
  @override
  List<EqSlot> get slots => [lower, upper, body];
}

/// Product: \prod_{i=a}^{b} expr
class EqProduct extends EqNode {
  final EqSlot lower, upper, body;
  EqProduct()
      : lower = EqSlot(id: _uid(), hint: 'i=1'),
        upper = EqSlot(id: _uid(), hint: 'n'),
        body = EqSlot(id: _uid(), hint: 'expr');

  @override
  String toLatex() =>
      '\\prod_{${lower.toLatex()}}^{${upper.toLatex()}} ${body.toLatex()}';
  @override
  List<EqSlot> get slots => [lower, upper, body];
}

/// Limit: \lim_{x \to a} expr
class EqLimit extends EqNode {
  final EqSlot variable, target, body;
  EqLimit()
      : variable = EqSlot(id: _uid(), hint: 'x'),
        target = EqSlot(id: _uid(), hint: '0'),
        body = EqSlot(id: _uid(), hint: 'expr');

  @override
  String toLatex() =>
      '\\lim_{${variable.toLatex()} \\to ${target.toLatex()}} ${body.toLatex()}';
  @override
  List<EqSlot> get slots => [variable, target, body];
}

/// Derivative: \frac{d}{dx} f
class EqDerivative extends EqNode {
  final EqSlot variable, body;
  EqDerivative()
      : variable = EqSlot(id: _uid(), hint: 'x'),
        body = EqSlot(id: _uid(), hint: 'f(x)');

  @override
  String toLatex() =>
      '\\frac{d}{d${variable.toLatex()}} ${body.toLatex()}';
  @override
  List<EqSlot> get slots => [variable, body];
}

/// Vector: \vec{v}
class EqVector extends EqNode {
  final EqSlot content;
  EqVector() : content = EqSlot(id: _uid(), hint: 'v');

  @override
  String toLatex() => '\\vec{${content.toLatex()}}';
  @override
  List<EqSlot> get slots => [content];
}

/// Absolute value: |x|
class EqAbsValue extends EqNode {
  final EqSlot content;
  EqAbsValue() : content = EqSlot(id: _uid(), hint: 'x');

  @override
  String toLatex() => '\\left| ${content.toLatex()} \\right|';
  @override
  List<EqSlot> get slots => [content];
}

/// Binomial: \binom{n}{k}
class EqBinomial extends EqNode {
  final EqSlot n, k;
  EqBinomial()
      : n = EqSlot(id: _uid(), hint: 'n'),
        k = EqSlot(id: _uid(), hint: 'k');

  @override
  String toLatex() => '\\binom{${n.toLatex()}}{${k.toLatex()}}';
  @override
  List<EqSlot> get slots => [n, k];
}

/// Chemical reaction: A → B
class EqReaction extends EqNode {
  final EqSlot reactants, products;
  final bool equilibrium;
  EqReaction({this.equilibrium = false})
      : reactants = EqSlot(id: _uid(), hint: 'réactifs'),
        products = EqSlot(id: _uid(), hint: 'produits');

  @override
  String toLatex() {
    final arrow = equilibrium ? r'\rightleftharpoons' : r'\rightarrow';
    return '${reactants.toLatex()} $arrow ${products.toLatex()}';
  }
  @override
  List<EqSlot> get slots => [reactants, products];
}

/// Log: \log_{base} expr
class EqLog extends EqNode {
  final EqSlot base, body;
  EqLog()
      : base = EqSlot(id: _uid(), hint: 'base'),
        body = EqSlot(id: _uid(), hint: 'x');

  @override
  String toLatex() => '\\log_{${base.toLatex()}} ${body.toLatex()}';
  @override
  List<EqSlot> get slots => [base, body];
}

/// System of equations
class EqSystem extends EqNode {
  final List<EqSlot> equations;
  EqSystem({int count = 2})
      : equations = List.generate(
            count, (i) => EqSlot(id: _uid(), hint: 'éq ${i + 1}'));

  @override
  String toLatex() {
    final lines = equations.map((s) => s.toLatex()).join(' \\\\ ');
    return '\\begin{cases} $lines \\end{cases}';
  }
  @override
  List<EqSlot> get slots => equations;
}

/// Matrix 2x2
class EqMatrix2x2 extends EqNode {
  final EqSlot a11, a12, a21, a22;
  EqMatrix2x2()
      : a11 = EqSlot(id: _uid(), hint: ''),
        a12 = EqSlot(id: _uid(), hint: ''),
        a21 = EqSlot(id: _uid(), hint: ''),
        a22 = EqSlot(id: _uid(), hint: '');

  @override
  String toLatex() =>
      '\\begin{pmatrix} ${a11.toLatex()} & ${a12.toLatex()} \\\\ ${a21.toLatex()} & ${a22.toLatex()} \\end{pmatrix}';
  @override
  List<EqSlot> get slots => [a11, a12, a21, a22];
}

int _uidCounter = 0;
String _uid() => 'slot_${_uidCounter++}_${DateTime.now().microsecondsSinceEpoch}';

/// Recursively collect ALL EqSlots from a node tree (including nested slots).
List<EqSlot> _allSlotsDeep(EqNode node) {
  final result = <EqSlot>[];
  for (final slot in node.slots) {
    result.add(slot);
    // Recurse into children of this slot
    for (final child in slot.children) {
      result.addAll(_allSlotsDeep(child));
    }
  }
  return result;
}

// ═══════════════════════════════════════════════════════════════════════════
// Main Widget
// ═══════════════════════════════════════════════════════════════════════════

class AcademiaEquationEditor extends StatefulWidget {
  /// The external controller — we sync the final LaTeX into it on every change.
  final TextEditingController controller;
  final VoidCallback? onChanged;
  final VoidCallback? onDone;

  const AcademiaEquationEditor({
    super.key,
    required this.controller,
    this.onChanged,
    this.onDone,
  });

  @override
  State<AcademiaEquationEditor> createState() =>
      _AcademiaEquationEditorState();
}

class _AcademiaEquationEditorState extends State<AcademiaEquationEditor> {
  /// The equation is a list of nodes (blocks).
  final List<EqNode> _nodes = [];

  /// Currently focused slot (the "active case").
  EqSlot? _activeSlot;

  /// Active chip category index.
  int _activeChip = 0;

  // Chip categories: icon + label + color
  static const _chips = [
    ('🧩', 'Structures', Color(0xFF00D2FF)),
    ('🔤', 'abc 123', Color(0xFF34C759)),
    ('🔣', 'Symboles', Color(0xFFFF9500)),
    ('🇬🇷', 'Grec', Color(0xFF5856D6)),
    ('⚗️', 'Chimie', Color(0xFFFF2D55)),
    ('📐', 'Unités', Color(0xFFFFCC00)),
  ];

  @override
  void initState() {
    super.initState();
  }

  void _haptic() => HapticFeedback.lightImpact();

  /// Rebuild the full LaTeX from all nodes and sync to the external controller.
  void _syncLatex() {
    final latex = _nodes.map((n) => n.toLatex()).join(' ');
    widget.controller.text = latex;
    widget.onChanged?.call();
    setState(() {});
  }

  /// Collect all slots recursively from the entire tree.
  List<EqSlot> get _allSlots {
    final result = <EqSlot>[];
    for (final node in _nodes) {
      result.addAll(_allSlotsDeep(node));
    }
    return result;
  }

  /// Insert a character/symbol into the active slot.
  void _typeIntoSlot(String text) {
    _haptic();
    if (_activeSlot == null) {
      _nodes.add(EqFixed(text));
    } else {
      _activeSlot!.children.add(EqFixed(text));
    }
    _syncLatex();
  }

  /// Backspace in the active slot.
  void _backspaceSlot() {
    _haptic();
    if (_activeSlot != null && _activeSlot!.children.isNotEmpty) {
      final last = _activeSlot!.children.last;
      if (last is EqFixed) {
        // Remove last fixed text character by character
        if (last.latex.length > 1) {
          _activeSlot!.children.last =
              EqFixed(last.latex.substring(0, last.latex.length - 1));
        } else {
          _activeSlot!.children.removeLast();
        }
      } else {
        // Remove last nested structure entirely
        _activeSlot!.children.removeLast();
      }
      _syncLatex();
    } else if (_activeSlot != null && _activeSlot!.children.isEmpty) {
      _removeNodeContainingSlot(_activeSlot!);
      _activeSlot = null;
      _syncLatex();
    } else if (_nodes.isNotEmpty) {
      final last = _nodes.last;
      if (last is EqFixed) {
        _nodes.removeLast();
        _syncLatex();
      }
    }
  }

  bool _removeNodeContainingSlot(EqSlot slot) {
    // Try to remove from root nodes
    for (int i = 0; i < _nodes.length; i++) {
      if (_nodes[i].slots.contains(slot)) {
        _nodes.removeAt(i);
        return true;
      }
      // Check recursively in slot children
      for (final s in _nodes[i].slots) {
        if (_removeFromChildren(s.children, slot)) return true;
      }
    }
    return false;
  }

  bool _removeFromChildren(List<EqNode> children, EqSlot slot) {
    for (int i = 0; i < children.length; i++) {
      if (children[i].slots.contains(slot)) {
        children.removeAt(i);
        return true;
      }
      for (final s in children[i].slots) {
        if (_removeFromChildren(s.children, slot)) return true;
      }
    }
    return false;
  }

  void _clearAll() {
    _haptic();
    _nodes.clear();
    _activeSlot = null;
    _syncLatex();
  }

  /// Add a template node. If a slot is active, insert INTO that slot.
  /// Otherwise, add to root.
  void _addTemplate(EqNode node) {
    _haptic();
    if (_activeSlot != null) {
      // Insert the structure INTO the active slot
      _activeSlot!.children.add(node);
    } else {
      _nodes.add(node);
    }
    // Focus the first slot of the new structure
    final newSlots = _allSlotsDeep(node);
    if (newSlots.isNotEmpty) {
      _activeSlot = newSlots.first;
      _activeChip = 1; // Auto-switch to ABC/123
    }
    _syncLatex();
  }

  /// Tap on a slot → activate it and auto-switch to ABC/123.
  void _focusSlot(EqSlot slot) {
    _haptic();
    setState(() {
      _activeSlot = slot;
      _activeChip = 1;
    });
  }

  void _nextSlot() {
    _haptic();
    final all = _allSlots;
    if (all.isEmpty) return;
    if (_activeSlot == null) {
      _activeSlot = all.first;
    } else {
      final idx = all.indexOf(_activeSlot!);
      _activeSlot = all[(idx + 1) % all.length];
    }
    _activeChip = 1;
    setState(() {});
  }

  void _prevSlot() {
    _haptic();
    final all = _allSlots;
    if (all.isEmpty) return;
    if (_activeSlot == null) {
      _activeSlot = all.last;
    } else {
      final idx = all.indexOf(_activeSlot!);
      _activeSlot = all[(idx - 1 + all.length) % all.length];
    }
    _activeChip = 1;
    setState(() {});
  }

  // ── Key definitions ──────────────────────────────────────────────────

  List<_TplDef> get _templates => [
    _TplDef('a/b', 'Fraction', () => _addTemplate(EqFraction())),
    _TplDef('xⁿ', 'Puissance', () => _addTemplate(EqPower())),
    _TplDef('xₙ', 'Indice', () => _addTemplate(EqSubscript())),
    _TplDef('√x', 'Racine', () => _addTemplate(EqSqrt())),
    _TplDef('ⁿ√', 'Racine n', () => _addTemplate(EqNthRoot())),
    _TplDef('∫ᵃᵇ', 'Intégrale', () => _addTemplate(EqIntegral())),
    _TplDef('∫', 'Intég.', () => _addTemplate(EqSimpleIntegral())),
    _TplDef('[F]ᵃᵇ', 'Aire', () => _addTemplate(EqBracketEval())),
    _TplDef('Σ', 'Somme', () => _addTemplate(EqSum())),
    _TplDef('Π', 'Produit', () => _addTemplate(EqProduct())),
    _TplDef('lim', 'Limite', () => _addTemplate(EqLimit())),
    _TplDef('d/dx', 'Dérivée', () => _addTemplate(EqDerivative())),
    _TplDef('→v', 'Vecteur', () => _addTemplate(EqVector())),
    _TplDef('|x|', 'Absolu', () => _addTemplate(EqAbsValue())),
    _TplDef('Cⁿₖ', 'Combin.', () => _addTemplate(EqBinomial())),
    _TplDef('log', 'Log', () => _addTemplate(EqLog())),
    _TplDef('→', 'Réaction', () => _addTemplate(EqReaction())),
    _TplDef('⇌', 'Équilibre', () => _addTemplate(EqReaction(equilibrium: true))),
    _TplDef('{', 'Système', () => _addTemplate(EqSystem(count: 2))),
    _TplDef('[ ]', 'Matrice', () => _addTemplate(EqMatrix2x2())),
  ];

  static const List<_SymDef> _abcKeys = [
    _SymDef('1', '1'), _SymDef('2', '2'), _SymDef('3', '3'),
    _SymDef('4', '4'), _SymDef('5', '5'), _SymDef('6', '6'),
    _SymDef('7', '7'), _SymDef('8', '8'), _SymDef('9', '9'),
    _SymDef('0', '0'), _SymDef('.', '.'), _SymDef(',', ','),
    _SymDef('a', 'a'), _SymDef('b', 'b'), _SymDef('c', 'c'),
    _SymDef('d', 'd'), _SymDef('e', 'e'), _SymDef('f', 'f'),
    _SymDef('x', 'x'), _SymDef('y', 'y'), _SymDef('z', 'z'),
    _SymDef('n', 'n'), _SymDef('t', 't'), _SymDef('k', 'k'),
    _SymDef('i', 'i'), _SymDef('m', 'm'), _SymDef('p', 'p'),
    _SymDef('+', '+'), _SymDef('−', '-'), _SymDef('=', '='),
    _SymDef('(', '('), _SymDef(')', ')'), _SymDef('/', '/'),
    _SymDef(' ', r'\,'),
  ];

  static const List<_SymDef> _symbolKeys = [
    _SymDef('=', '='), _SymDef('≠', r'\neq'), _SymDef('<', '<'),
    _SymDef('>', '>'), _SymDef('≤', r'\leq'), _SymDef('≥', r'\geq'),
    _SymDef('≈', r'\approx'), _SymDef('±', r'\pm'), _SymDef('×', r'\times'),
    _SymDef('÷', r'\div'), _SymDef('·', r'\cdot'), _SymDef('∝', r'\propto'),
    _SymDef('∈', r'\in'), _SymDef('∉', r'\notin'), _SymDef('⊂', r'\subset'),
    _SymDef('∪', r'\cup'), _SymDef('∩', r'\cap'), _SymDef('∅', r'\emptyset'),
    _SymDef('ℝ', r'\mathbb{R}'), _SymDef('ℤ', r'\mathbb{Z}'),
    _SymDef('ℕ', r'\mathbb{N}'), _SymDef('ℚ', r'\mathbb{Q}'),
    _SymDef('ℂ', r'\mathbb{C}'), _SymDef('∀', r'\forall'),
    _SymDef('∃', r'\exists'), _SymDef('⇒', r'\Rightarrow'),
    _SymDef('⇔', r'\Leftrightarrow'), _SymDef('π', r'\pi'),
    _SymDef('∞', r'\infty'), _SymDef('→', r'\to'),
    _SymDef('sin', r'\sin'), _SymDef('cos', r'\cos'), _SymDef('tan', r'\tan'),
    _SymDef('ln', r'\ln'), _SymDef('exp', r'\exp'),
    _SymDef('+∞', r'+\infty'), _SymDef('−∞', r'-\infty'),
    _SymDef('°', r'^{\circ}'), _SymDef('∂', r'\partial'),
    _SymDef('ℏ', r'\hbar'), _SymDef('…', r'\ldots'),
  ];

  static const List<_SymDef> _greekKeys = [
    _SymDef('α', r'\alpha'), _SymDef('β', r'\beta'), _SymDef('γ', r'\gamma'),
    _SymDef('δ', r'\delta'), _SymDef('ε', r'\varepsilon'),
    _SymDef('ζ', r'\zeta'), _SymDef('η', r'\eta'), _SymDef('θ', r'\theta'),
    _SymDef('λ', r'\lambda'), _SymDef('μ', r'\mu'), _SymDef('ν', r'\nu'),
    _SymDef('ξ', r'\xi'), _SymDef('ρ', r'\rho'), _SymDef('σ', r'\sigma'),
    _SymDef('τ', r'\tau'), _SymDef('φ', r'\varphi'), _SymDef('ψ', r'\psi'),
    _SymDef('ω', r'\omega'), _SymDef('Γ', r'\Gamma'), _SymDef('Δ', r'\Delta'),
    _SymDef('Θ', r'\Theta'), _SymDef('Λ', r'\Lambda'), _SymDef('Σ', r'\Sigma'),
    _SymDef('Φ', r'\Phi'), _SymDef('Ψ', r'\Psi'), _SymDef('Ω', r'\Omega'),
  ];

  static const List<_SymDef> _chemKeys = [
    _SymDef('→', r'\rightarrow'), _SymDef('⇌', r'\rightleftharpoons'),
    _SymDef('↑', r'\uparrow'), _SymDef('↓', r'\downarrow'),
    _SymDef('H₂O', r'\text{H}_2\text{O}'), _SymDef('CO₂', r'\text{CO}_2'),
    _SymDef('O₂', r'\text{O}_2'), _SymDef('N₂', r'\text{N}_2'),
    _SymDef('+', r'^{+}'), _SymDef('−', r'^{-}'),
    _SymDef('2+', r'^{2+}'), _SymDef('2−', r'^{2-}'),
    _SymDef('3+', r'^{3+}'), _SymDef('(aq)', r'\text{(aq)}'),
    _SymDef('(s)', r'\text{(s)}'), _SymDef('(l)', r'\text{(l)}'),
    _SymDef('(g)', r'\text{(g)}'), _SymDef('pH', r'\text{pH}'),
    _SymDef('Ka', r'K_a'), _SymDef('Kb', r'K_b'), _SymDef('Kw', r'K_w'),
    _SymDef('mol', r'\,\text{mol}'), _SymDef('M', r'\,\text{M}'),
    _SymDef('Δ', r'\Delta'),
  ];

  static const List<_SymDef> _unitKeys = [
    _SymDef('m/s', r'\,\text{m/s}'), _SymDef('m/s²', r'\,\text{m/s}^2'),
    _SymDef('N', r'\,\text{N}'), _SymDef('J', r'\,\text{J}'),
    _SymDef('W', r'\,\text{W}'), _SymDef('Pa', r'\,\text{Pa}'),
    _SymDef('kg', r'\,\text{kg}'), _SymDef('g', r'\,\text{g}'),
    _SymDef('L', r'\,\text{L}'), _SymDef('mL', r'\,\text{mL}'),
    _SymDef('°C', r'\,°\text{C}'), _SymDef('K', r'\,\text{K}'),
    _SymDef('V', r'\,\text{V}'), _SymDef('A', r'\,\text{A}'),
    _SymDef('Ω', r'\,\Omega'), _SymDef('Hz', r'\,\text{Hz}'),
    _SymDef('eV', r'\,\text{eV}'), _SymDef('m', r'\,\text{m}'),
    _SymDef('cm', r'\,\text{cm}'), _SymDef('mm', r'\,\text{mm}'),
    _SymDef('km', r'\,\text{km}'), _SymDef('s', r'\,\text{s}'),
    _SymDef('min', r'\,\text{min}'), _SymDef('h', r'\,\text{h}'),
  ];

  List<_SymDef> get _currentKeys {
    switch (_activeChip) {
      case 1: return _abcKeys;
      case 2: return _symbolKeys;
      case 3: return _greekKeys;
      case 4: return _chemKeys;
      case 5: return _unitKeys;
      default: return _abcKeys;
    }
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
          const SizedBox(height: 8),
          // Handle
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 6),

          // ── Interactive formula (render + clickable □) ──
          _buildInteractiveFormula(),

          // ── Chips bar (scrollable categories) ──
          _buildChipsBar(),

          // ── Key grid (changes with active chip) ──
          SizedBox(
            height: 200,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _activeChip == 0
                  ? _buildTemplateGrid(key: const ValueKey('tpl'))
                  : _buildSymbolGrid(
                      _currentKeys,
                      key: ValueKey('grid_$_activeChip'),
                    ),
            ),
          ),

          // ── Action bar ──
          _buildActionBar(),
          SizedBox(height: bottomPad + 4),
        ],
      ),
    );
  }

  // ── Interactive formula (single zone: render + clickable □) ─────────

  Widget _buildInteractiveFormula() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 60),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: _nodes.isEmpty
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app,
                    color: Colors.white.withValues(alpha: 0.2), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Choisis une structure ci-dessous',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25),
                    fontSize: 14,
                  ),
                ),
              ],
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: _nodes.expand(_renderNode).toList(),
              ),
            ),
    );
  }

  /// Render a node as inline Flutter widgets with clickable slot boxes.
  List<Widget> _renderNode(EqNode node) {
    if (node is EqFixed) {
      return [_sym(node.latex)];
    }
    if (node is EqFraction) {
      return [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _slot(node.numerator),
            Container(
              width: 40, height: 1.5,
              margin: const EdgeInsets.symmetric(vertical: 2),
              color: Colors.white54,
            ),
            _slot(node.denominator),
          ],
        ),
      ];
    }
    if (node is EqPower) {
      return [
        _slot(node.base),
        Transform.translate(
          offset: const Offset(0, -10),
          child: _slotSmall(node.exponent),
        ),
      ];
    }
    if (node is EqSubscript) {
      return [
        _slot(node.base),
        Transform.translate(
          offset: const Offset(0, 8),
          child: _slotSmall(node.subscript),
        ),
      ];
    }
    if (node is EqSqrt) {
      return [_sym('√'), _slot(node.content)];
    }
    if (node is EqNthRoot) {
      return [
        Transform.translate(
          offset: const Offset(0, -6),
          child: _slotSmall(node.degree),
        ),
        _sym('√'),
        _slot(node.content),
      ];
    }
    if (node is EqIntegral) {
      return [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _slotSmall(node.upper),
            _sym('∫', size: 28),
            _slotSmall(node.lower),
          ],
        ),
        _slot(node.body),
        _sym(' d', size: 16),
        _slot(node.variable),
      ];
    }
    if (node is EqSimpleIntegral) {
      return [
        _sym('∫', size: 28),
        _slot(node.body),
        _sym(' d', size: 16),
        _slot(node.variable),
      ];
    }
    if (node is EqBracketEval) {
      return [
        _sym('[', size: 24),
        _slot(node.content),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _slotSmall(node.upper),
            _sym(']', size: 24),
            _slotSmall(node.lower),
          ],
        ),
      ];
    }
    if (node is EqSum) {
      return [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _slotSmall(node.upper),
            _sym('Σ', size: 24),
            _slotSmall(node.lower),
          ],
        ),
        _slot(node.body),
      ];
    }
    if (node is EqProduct) {
      return [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _slotSmall(node.upper),
            _sym('Π', size: 24),
            _slotSmall(node.lower),
          ],
        ),
        _slot(node.body),
      ];
    }
    if (node is EqLimit) {
      return [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sym('lim', size: 18),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _slotSmall(node.variable),
                _sym('→', size: 12),
                _slotSmall(node.target),
              ],
            ),
          ],
        ),
        const SizedBox(width: 4),
        _slot(node.body),
      ];
    }
    if (node is EqDerivative) {
      return [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sym('d', size: 16),
            Container(width: 24, height: 1.5, color: Colors.white54),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [_sym('d', size: 14), _slotSmall(node.variable)],
            ),
          ],
        ),
        const SizedBox(width: 4),
        _slot(node.body),
      ];
    }
    if (node is EqVector) {
      return [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sym('→', size: 12),
            _slot(node.content),
          ],
        ),
      ];
    }
    if (node is EqAbsValue) {
      return [_sym('|', size: 22), _slot(node.content), _sym('|', size: 22)];
    }
    if (node is EqBinomial) {
      return [
        _sym('(', size: 22),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [_slot(node.n), _slot(node.k)],
        ),
        _sym(')', size: 22),
      ];
    }
    if (node is EqLog) {
      return [
        _sym('log', size: 16),
        Transform.translate(
          offset: const Offset(0, 6),
          child: _slotSmall(node.base),
        ),
        _slot(node.body),
      ];
    }
    if (node is EqReaction) {
      final arrow = node.equilibrium ? '⇌' : '→';
      return [_slot(node.reactants), _sym(' $arrow ', size: 20), _slot(node.products)];
    }
    if (node is EqSystem) {
      return [
        _sym('{', size: 28),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: node.equations.map((s) => _slot(s)).toList(),
        ),
      ];
    }
    if (node is EqMatrix2x2) {
      return [
        _sym('(', size: 28),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              _slotSmall(node.a11), const SizedBox(width: 4), _slotSmall(node.a12),
            ]),
            const SizedBox(height: 2),
            Row(mainAxisSize: MainAxisSize.min, children: [
              _slotSmall(node.a21), const SizedBox(width: 4), _slotSmall(node.a22),
            ]),
          ],
        ),
        _sym(')', size: 28),
      ];
    }
    // Fallback
    return node.slots.map((s) => _slot(s)).toList();
  }

  /// A fixed symbol/text in the formula.
  Widget _sym(String text, {double size = 20}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white70,
          fontSize: size,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// A normal-sized clickable slot box — renders children recursively.
  Widget _slot(EqSlot slot) {
    final isActive = _activeSlot?.id == slot.id;

    return GestureDetector(
      onTap: () => _focusSlot(slot),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        constraints: const BoxConstraints(minWidth: 32, minHeight: 30),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF00D2FF).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? const Color(0xFF00D2FF)
                : Colors.white.withValues(alpha: 0.15),
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive
              ? [BoxShadow(
                  color: const Color(0xFF00D2FF).withValues(alpha: 0.3),
                  blurRadius: 8,
                )]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (slot.isEmpty)
              Text(
                slot.hint.isNotEmpty ? slot.hint : '?',
                style: TextStyle(
                  color: isActive
                      ? const Color(0xFF00D2FF).withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.2),
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              // Render children inline (text + nested structures)
              ...slot.children.expand(_renderNode),
            if (isActive) ...[
              const SizedBox(width: 1),
              const _BlinkingCursor(color: Color(0xFF00D2FF)),
            ],
          ],
        ),
      ),
    );
  }

  /// A small-sized slot (for exponents, indices, bounds) — renders children recursively.
  Widget _slotSmall(EqSlot slot) {
    final isActive = _activeSlot?.id == slot.id;

    return GestureDetector(
      onTap: () => _focusSlot(slot),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        constraints: const BoxConstraints(minWidth: 22, minHeight: 20),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF00D2FF).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: isActive
                ? const Color(0xFF00D2FF)
                : Colors.white.withValues(alpha: 0.12),
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive
              ? [BoxShadow(
                  color: const Color(0xFF00D2FF).withValues(alpha: 0.25),
                  blurRadius: 6,
                )]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (slot.isEmpty)
              Text(
                slot.hint.isNotEmpty ? slot.hint : '?',
                style: TextStyle(
                  color: isActive
                      ? const Color(0xFF00D2FF).withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.15),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              ...slot.children.expand(_renderNode),
            if (isActive) ...[
              const SizedBox(width: 1),
              const _BlinkingCursor(color: Color(0xFF00D2FF)),
            ],
          ],
        ),
      ),
    );
  }

  // ── Chips bar ────────────────────────────────────────────────────────

  Widget _buildChipsBar() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: _chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final (emoji, label, color) = _chips[i];
          final isActive = _activeChip == i;
          return GestureDetector(
            onTap: () {
              _haptic();
              setState(() => _activeChip = i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? color : Colors.transparent,
                  width: isActive ? 2 : 0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: isActive ? color : Colors.white54,
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Template grid ────────────────────────────────────────────────────

  Widget _buildTemplateGrid({Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.all(6),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          mainAxisSpacing: 5,
          crossAxisSpacing: 5,
          childAspectRatio: 1.0,
        ),
        itemCount: _templates.length,
        itemBuilder: (_, i) {
          final t = _templates[i];
          return _TplButton(
            label: t.label,
            subtitle: t.subtitle,
            onTap: t.onTap,
          );
        },
      ),
    );
  }

  // ── Symbol grid ──────────────────────────────────────────────────────

  Widget _buildSymbolGrid(List<_SymDef> keys, {Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.all(6),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 1.15,
        ),
        itemCount: keys.length,
        itemBuilder: (_, i) {
          final k = keys[i];
          return _SymButton(
            label: k.label,
            onTap: () => _typeIntoSlot(k.latex),
          );
        },
      ),
    );
  }

  // ── Action bar ───────────────────────────────────────────────────────

  Widget _buildActionBar() {
    final all = _allSlots;
    final emptyCount = all.where((s) => s.isEmpty).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          _ActBtn(icon: Icons.delete_outline, onTap: _clearAll),
          const SizedBox(width: 4),
          _ActBtn(icon: Icons.backspace_outlined, onTap: _backspaceSlot,
              onLongPress: _clearAll),
          const SizedBox(width: 4),
          _ActBtn(icon: Icons.chevron_left, onTap: _prevSlot),
          const SizedBox(width: 4),
          _ActBtn(icon: Icons.chevron_right, onTap: _nextSlot),
          const Spacer(),
          if (emptyCount > 0)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  '$emptyCount vide${emptyCount > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          GestureDetector(
            onTap: () {
              _haptic();
              widget.onDone?.call();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D2FF), Color(0xFF00B4D8)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D2FF).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 16, color: Colors.black),
                  SizedBox(width: 4),
                  Text('OK', style: TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Blinking cursor widget
// ═══════════════════════════════════════════════════════════════════════════

class _BlinkingCursor extends StatefulWidget {
  final Color color;
  const _BlinkingCursor({required this.color});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 2,
        height: 18,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Helper classes
// ═══════════════════════════════════════════════════════════════════════════

class _TplDef {
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  const _TplDef(this.label, this.subtitle, this.onTap);
}

class _SymDef {
  final String label;
  final String latex;
  const _SymDef(this.label, this.latex);
}

class _TplButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _TplButton({
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1A2E),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
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
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 1),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 8,
                  ),
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SymButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SymButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        splashColor: const Color(0xFF00D2FF).withValues(alpha: 0.25),
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ActBtn({required this.icon, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Icon(icon, color: Colors.white60, size: 20),
        ),
      ),
    );
  }
}
