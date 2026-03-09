import 'package:flutter/material.dart';
import 'package:math_keyboard/math_keyboard.dart';

/// Widget réutilisable pour la saisie d'expressions mathématiques.
///
/// Fournit un bouton toggle "∑" qui ouvre un clavier mathématique spécialisé.
/// L'utilisateur peut basculer entre le clavier texte normal et le clavier math.
///
/// Le résultat est une chaîne LaTeX encadrée par `$...$` prête à être
/// stockée dans le champ `content` TEXT de Supabase.
///
/// Usage dans un chat :
/// ```dart
/// AcademiaMathInput(
///   onInsertFormula: (latex) {
///     // latex = r"\frac{x^2}{2}"
///     // Insérer "$\frac{x^2}{2}$" dans le message
///   },
/// )
/// ```
class AcademiaMathInput extends StatefulWidget {
  const AcademiaMathInput({
    super.key,
    required this.onInsertFormula,
    this.buttonColor,
    this.buttonSize = 24.0,
  });

  /// Callback appelé quand l'utilisateur valide une formule.
  /// Reçoit la chaîne LaTeX brute (sans les délimiteurs $).
  final ValueChanged<String> onInsertFormula;

  /// Couleur du bouton toggle.
  final Color? buttonColor;

  /// Taille de l'icône du bouton.
  final double buttonSize;

  @override
  State<AcademiaMathInput> createState() => _AcademiaMathInputState();
}

class _AcademiaMathInputState extends State<AcademiaMathInput> {
  bool _showMathField = false;
  final MathFieldEditingController _mathController =
      MathFieldEditingController();

  @override
  void dispose() {
    _mathController.dispose();
    super.dispose();
  }

  void _toggleMathField() {
    setState(() {
      _showMathField = !_showMathField;
      if (!_showMathField) {
        _mathController.clear();
      }
    });
  }

  void _submitFormula() {
    final tex = _mathController.currentEditingValue();
    if (tex.isNotEmpty) {
      widget.onInsertFormula(tex);
      _mathController.clear();
      setState(() => _showMathField = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.buttonColor ?? const Color(0xFF2E7D32);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showMathField) _buildMathEditor(theme, color),
      ],
    );
  }

  /// Bouton toggle à utiliser dans la barre d'outils du chat.
  /// Exposé via une méthode statique pour être placé librement.
  Widget buildToggleButton() {
    final color = widget.buttonColor ?? const Color(0xFF2E7D32);
    return IconButton(
      onPressed: _toggleMathField,
      icon: Icon(
        _showMathField ? Icons.keyboard : Icons.functions,
        color: _showMathField ? color : Colors.grey[600],
        size: widget.buttonSize,
      ),
      tooltip: _showMathField ? 'Clavier texte' : 'Formule mathématique',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }

  Widget _buildMathEditor(ThemeData theme, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header avec titre et boutons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.functions, color: color, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Formule mathématique',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // Bouton Insérer
                TextButton.icon(
                  onPressed: _submitFormula,
                  icon: Icon(Icons.check, size: 16, color: color),
                  label: Text(
                    'Insérer',
                    style: TextStyle(color: color, fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                // Bouton Fermer
                IconButton(
                  onPressed: _toggleMathField,
                  icon: const Icon(Icons.close, size: 16),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Champ de saisie math avec clavier intégré
          Padding(
            padding: const EdgeInsets.all(8),
            child: MathField(
              controller: _mathController,
              variables: const ['x', 'y', 'z', 'n', 't', 'a', 'b', 'c'],
              decoration: InputDecoration(
                hintText: 'Tapez votre formule...',
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: color, width: 1.5),
                ),
              ),
              onSubmitted: (_) => _submitFormula(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton simple "∑" à intégrer dans n'importe quelle barre d'outils.
///
/// Ouvre un dialog modal avec le clavier mathématique.
/// Plus simple à intégrer que [AcademiaMathInput] inline.
class AcademiaMathButton extends StatelessWidget {
  const AcademiaMathButton({
    super.key,
    required this.onInsertFormula,
    this.color,
    this.iconSize = 22.0,
  });

  final ValueChanged<String> onInsertFormula;
  final Color? color;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _showMathDialog(context),
      icon: Icon(
        Icons.functions,
        color: color ?? Colors.grey[600],
        size: iconSize,
      ),
      tooltip: 'Insérer une formule',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }

  void _showMathDialog(BuildContext context) {
    final controller = MathFieldEditingController();
    final accentColor = color ?? const Color(0xFF2E7D32);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MathInputSheet(
        controller: controller,
        accentColor: accentColor,
        onInsert: (tex) {
          onInsertFormula(tex);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }
}

class _MathInputSheet extends StatefulWidget {
  const _MathInputSheet({
    required this.controller,
    required this.accentColor,
    required this.onInsert,
  });

  final MathFieldEditingController controller;
  final Color accentColor;
  final ValueChanged<String> onInsert;

  @override
  State<_MathInputSheet> createState() => _MathInputSheetState();
}

class _MathInputSheetState extends State<_MathInputSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final TextEditingController _rawTexCtrl = TextEditingController();

  static const _tabs = ['Maths', 'Physique', 'Chimie', 'Stats'];

  static const _mathSymbols = <_QuickSymbol>[
    _QuickSymbol(r'\frac{a}{b}', 'a/b'),
    _QuickSymbol(r'\sqrt{x}', '√x'),
    _QuickSymbol(r'\sqrt[n]{x}', 'ⁿ√x'),
    _QuickSymbol(r'x^{2}', 'x²'),
    _QuickSymbol(r'x^{n}', 'xⁿ'),
    _QuickSymbol(r'x_{i}', 'xᵢ'),
    _QuickSymbol(r'\int_{a}^{b}', '∫'),
    _QuickSymbol(r'\sum_{i=1}^{n}', '∑'),
    _QuickSymbol(r'\prod_{i=1}^{n}', '∏'),
    _QuickSymbol(r'\lim_{x \to \infty}', 'lim'),
    _QuickSymbol(r'\infty', '∞'),
    _QuickSymbol(r'\pi', 'π'),
    _QuickSymbol(r'\pm', '±'),
    _QuickSymbol(r'\leq', '≤'),
    _QuickSymbol(r'\geq', '≥'),
    _QuickSymbol(r'\neq', '≠'),
    _QuickSymbol(r'\approx', '≈'),
    _QuickSymbol(r'\times', '×'),
    _QuickSymbol(r'\div', '÷'),
    _QuickSymbol(r'\cdot', '·'),
    _QuickSymbol(r'\sin', 'sin'),
    _QuickSymbol(r'\cos', 'cos'),
    _QuickSymbol(r'\tan', 'tan'),
    _QuickSymbol(r'\log', 'log'),
    _QuickSymbol(r'\ln', 'ln'),
    _QuickSymbol(r'\binom{n}{k}', 'C(n,k)'),
    _QuickSymbol(r'\left(\right)', '( )'),
    _QuickSymbol(r'\left[\right]', '[ ]'),
    _QuickSymbol(r'\begin{pmatrix} a & b \\ c & d \end{pmatrix}', '[mat]'),
  ];

  static const _physicsSymbols = <_QuickSymbol>[
    _QuickSymbol(r'\vec{F}', 'F⃗'),
    _QuickSymbol(r'\vec{v}', 'v⃗'),
    _QuickSymbol(r'\vec{a}', 'a⃗'),
    _QuickSymbol(r'\Delta', 'Δ'),
    _QuickSymbol(r'\nabla', '∇'),
    _QuickSymbol(r'\partial', '∂'),
    _QuickSymbol(r'\alpha', 'α'),
    _QuickSymbol(r'\beta', 'β'),
    _QuickSymbol(r'\gamma', 'γ'),
    _QuickSymbol(r'\lambda', 'λ'),
    _QuickSymbol(r'\mu', 'μ'),
    _QuickSymbol(r'\omega', 'ω'),
    _QuickSymbol(r'\theta', 'θ'),
    _QuickSymbol(r'\epsilon', 'ε'),
    _QuickSymbol(r'\rho', 'ρ'),
    _QuickSymbol(r'\sigma', 'σ'),
    _QuickSymbol(r'\tau', 'τ'),
    _QuickSymbol(r'\phi', 'φ'),
    _QuickSymbol(r'\hbar', 'ℏ'),
    _QuickSymbol(r'\text{m/s}^2', 'm/s²'),
    _QuickSymbol(r'\text{kg}', 'kg'),
    _QuickSymbol(r'\text{N}', 'N'),
    _QuickSymbol(r'\text{J}', 'J'),
    _QuickSymbol(r'\text{W}', 'W'),
    _QuickSymbol(r'\text{Pa}', 'Pa'),
    _QuickSymbol(r'\text{Hz}', 'Hz'),
    _QuickSymbol(r'\text{V}', 'V'),
    _QuickSymbol(r'\text{A}', 'A'),
    _QuickSymbol(r'\Omega', 'Ω'),
    _QuickSymbol(r'\rightarrow', '→'),
  ];

  static const _chemistrySymbols = <_QuickSymbol>[
    _QuickSymbol(r'\rightarrow', '→'),
    _QuickSymbol(r'\leftarrow', '←'),
    _QuickSymbol(r'\rightleftharpoons', '⇌'),
    _QuickSymbol(r'\uparrow', '↑'),
    _QuickSymbol(r'\downarrow', '↓'),
    _QuickSymbol(r'_{2}', '₂'),
    _QuickSymbol(r'_{3}', '₃'),
    _QuickSymbol(r'_{4}', '₄'),
    _QuickSymbol(r'^{+}', '⁺'),
    _QuickSymbol(r'^{-}', '⁻'),
    _QuickSymbol(r'^{2+}', '²⁺'),
    _QuickSymbol(r'^{2-}', '²⁻'),
    _QuickSymbol(r'\text{H}_2\text{O}', 'H₂O'),
    _QuickSymbol(r'\text{CO}_2', 'CO₂'),
    _QuickSymbol(r'\text{NaCl}', 'NaCl'),
    _QuickSymbol(r'\text{H}_2\text{SO}_4', 'H₂SO₄'),
    _QuickSymbol(r'\text{NaOH}', 'NaOH'),
    _QuickSymbol(r'\text{mol}', 'mol'),
    _QuickSymbol(r'\text{g/mol}', 'g/mol'),
    _QuickSymbol(r'\text{pH}', 'pH'),
    _QuickSymbol(r'\text{pOH}', 'pOH'),
    _QuickSymbol(r'\Delta H', 'ΔH'),
    _QuickSymbol(r'\Delta G', 'ΔG'),
    _QuickSymbol(r'\Delta S', 'ΔS'),
    _QuickSymbol(r'K_{eq}', 'Keq'),
    _QuickSymbol(r'K_a', 'Ka'),
    _QuickSymbol(r'K_b', 'Kb'),
  ];

  static const _statsSymbols = <_QuickSymbol>[
    _QuickSymbol(r'\bar{x}', 'x̄'),
    _QuickSymbol(r'\hat{p}', 'p̂'),
    _QuickSymbol(r'\mu', 'μ'),
    _QuickSymbol(r'\sigma', 'σ'),
    _QuickSymbol(r'\sigma^2', 'σ²'),
    _QuickSymbol(r'P(X)', 'P(X)'),
    _QuickSymbol(r'P(A|B)', 'P(A|B)'),
    _QuickSymbol(r'P(A \cap B)', 'P(A∩B)'),
    _QuickSymbol(r'P(A \cup B)', 'P(A∪B)'),
    _QuickSymbol(r'\binom{n}{k}', 'C(n,k)'),
    _QuickSymbol(r'n!', 'n!'),
    _QuickSymbol(r'E(X)', 'E(X)'),
    _QuickSymbol(r'V(X)', 'V(X)'),
    _QuickSymbol(r'\chi^2', 'χ²'),
    _QuickSymbol(r'\sum_{i=1}^{n} x_i', '∑xᵢ'),
    _QuickSymbol(r'\frac{1}{n}\sum_{i=1}^{n}', '1/n·∑'),
    _QuickSymbol(r'\sqrt{\frac{\sum(x_i - \bar{x})^2}{n-1}}', 's'),
    _QuickSymbol(r'\mathcal{N}(\mu, \sigma^2)', 'N(μ,σ²)'),
    _QuickSymbol(r'\in', '∈'),
    _QuickSymbol(r'\subset', '⊂'),
    _QuickSymbol(r'\cup', '∪'),
    _QuickSymbol(r'\cap', '∩'),
    _QuickSymbol(r'\emptyset', '∅'),
    _QuickSymbol(r'\forall', '∀'),
    _QuickSymbol(r'\exists', '∃'),
    _QuickSymbol(r'\Rightarrow', '⇒'),
    _QuickSymbol(r'\Leftrightarrow', '⇔'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _rawTexCtrl.dispose();
    super.dispose();
  }

  List<_QuickSymbol> _symbolsForTab(int index) {
    switch (index) {
      case 0:
        return _mathSymbols;
      case 1:
        return _physicsSymbols;
      case 2:
        return _chemistrySymbols;
      case 3:
        return _statsSymbols;
      default:
        return _mathSymbols;
    }
  }

  void _insertSymbol(String tex) {
    _rawTexCtrl.text = _rawTexCtrl.text + tex;
  }

  void _submit() {
    // Try math_keyboard first, then raw TeX
    final mathTex = widget.controller.currentEditingValue();
    final rawTex = _rawTexCtrl.text.trim();
    final tex = mathTex.isNotEmpty ? mathTex : rawTex;
    if (tex.isNotEmpty) {
      widget.onInsert(tex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Icon(Icons.functions, color: accent, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Formule scientifique',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _submit,
                    child: Text(
                      'Insérer',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Math field (math_keyboard)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: MathField(
                controller: widget.controller,
                variables: const ['x', 'y', 'z', 'n', 't', 'a', 'b', 'c'],
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Clavier math...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: accent, width: 1.5),
                  ),
                ),
                onSubmitted: (tex) {
                  if (tex.isNotEmpty) widget.onInsert(tex);
                },
              ),
            ),
            // Raw LaTeX field (for advanced symbols not in math_keyboard)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: TextField(
                controller: _rawTexCtrl,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: r'LaTeX brut (ex: \vec{F} = m\vec{a})',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: accent.withOpacity(0.5)),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.check_circle, color: accent, size: 20),
                    onPressed: _submit,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            // Tabs
            TabBar(
              controller: _tabCtrl,
              labelColor: accent,
              unselectedLabelColor: Colors.grey[500],
              indicatorColor: accent,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'Maths'),
                Tab(text: 'Physique'),
                Tab(text: 'Chimie'),
                Tab(text: 'Stats'),
              ],
            ),
            // Symbol grid
            SizedBox(
              height: 160,
              child: TabBarView(
                controller: _tabCtrl,
                children: List.generate(_tabs.length, (tabIndex) {
                  final symbols = _symbolsForTab(tabIndex);
                  return GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 1.6,
                    ),
                    itemCount: symbols.length,
                    itemBuilder: (context, i) {
                      final sym = symbols[i];
                      return _SymbolButton(
                        symbol: sym,
                        accentColor: accent,
                        onTap: () => _insertSymbol(sym.latex),
                      );
                    },
                  );
                }),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _QuickSymbol {
  final String latex;
  final String display;
  const _QuickSymbol(this.latex, this.display);
}

class _SymbolButton extends StatelessWidget {
  final _QuickSymbol symbol;
  final Color accentColor;
  final VoidCallback onTap;

  const _SymbolButton({
    required this.symbol,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Center(
          child: Text(
            symbol.display,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
