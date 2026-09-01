import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/game_constants.dart';

/// Callback signatures pour les jeux Flutter
typedef ScoreCallback = void Function(int points);
typedef GameEventCallback = void Function(String event);

// ═══════════════════════════════════════════════════════════════════
// 1. MARKET MASTER — Offre & Demande
// ═══════════════════════════════════════════════════════════════════

class FlutterMarketMasterView extends StatefulWidget {
  final ScoreCallback onAddScore;
  final ScoreCallback onSubtractScore;
  final GameEventCallback onGameEvent;
  final VoidCallback onGameEnd;

  const FlutterMarketMasterView({
    super.key,
    required this.onAddScore,
    required this.onSubtractScore,
    required this.onGameEvent,
    required this.onGameEnd,
  });

  @override
  State<FlutterMarketMasterView> createState() => _FlutterMarketMasterViewState();
}

class _FlutterMarketMasterViewState extends State<FlutterMarketMasterView> {
  double _currentPrice = 50.0;
  double _equilibriumPrice = 50.0;
  int _demandQuantity = 100;
  int _supplyQuantity = 100;
  int _marketPhase = 0;

  @override
  void initState() {
    super.initState();
    _generateScenario();
  }

  void _generateScenario() {
    final rng = Random();
    _equilibriumPrice = 30.0 + rng.nextInt(40).toDouble();
    _currentPrice = _equilibriumPrice + rng.nextInt(20).toDouble() - 10;
    _updateQuantities();
    setState(() {});
  }

  void _adjustPrice(double delta) {
    setState(() {
      _currentPrice = (_currentPrice + delta).clamp(5.0, 100.0);
      _updateQuantities();
    });
  }

  void _updateQuantities() {
    _demandQuantity = (200 - (_currentPrice * 2)).round().clamp(20, 180);
    _supplyQuantity = (_currentPrice * 2).round().clamp(20, 180);
    final diff = (_demandQuantity - _supplyQuantity).abs();
    _marketPhase = diff <= 5 ? 2 : (diff <= 15 ? 1 : 0);
  }

  void _submitAnswer() {
    final diff = (_demandQuantity - _supplyQuantity).abs();
    int points = 0;
    if (diff <= 5) {
      points = GameConstants.correctAnswerPoints * 3;
    } else if (diff <= 15) {
      points = GameConstants.correctAnswerPoints * 2;
    } else if (diff <= 30) {
      points = GameConstants.correctAnswerPoints;
    }
    if (points > 0) {
      widget.onAddScore(points);
      widget.onGameEvent('Marché équilibré ! +$points pts');
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) _generateScenario();
      });
    } else {
      widget.onSubtractScore(GameConstants.wrongAnswerPenalty);
      widget.onGameEvent('Marché non équilibré, réessayez !');
    }
  }

  @override
  Widget build(BuildContext context) {
    final phaseColor = _marketPhase == 2 ? Colors.green : (_marketPhase == 1 ? Colors.amber : Colors.red);
    final phaseText = _marketPhase == 2 ? 'ÉQUILIBRE !' : (_marketPhase == 1 ? 'Proche' : 'Déséquilibre');
    final maxBar = 180.0;
    final mq = MediaQuery.of(context);
    final isSmall = mq.size.width < 380 || mq.size.height < 700;
    final titleFs = isSmall ? 16.0 : 20.0;
    final priceFs = isSmall ? 22.0 : 28.0;
    final pad = isSmall ? 8.0 : 12.0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: pad, vertical: pad * 0.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Maître du Marché', textAlign: TextAlign.center,
              style: TextStyle(fontSize: titleFs, fontWeight: FontWeight.bold, color: Colors.green[700])),
          SizedBox(height: isSmall ? 2 : 6),
          Text('Ajustez le prix pour équilibrer offre et demande',
              textAlign: TextAlign.center, style: TextStyle(fontSize: isSmall ? 10 : 12, color: Colors.grey[600])),
          SizedBox(height: isSmall ? 6 : 12),
          Card(
            color: Colors.grey[900],
            child: Padding(
              padding: EdgeInsets.all(pad),
              child: Column(children: [
                Text('Prix actuel', style: TextStyle(color: Colors.grey[400], fontSize: isSmall ? 10 : 12)),
                Text('\$${_currentPrice.toStringAsFixed(1)}',
                    style: TextStyle(color: Colors.white, fontSize: priceFs, fontWeight: FontWeight.bold)),
                SizedBox(height: isSmall ? 4 : 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: phaseColor.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: Text(phaseText, style: TextStyle(color: phaseColor, fontWeight: FontWeight.bold, fontSize: isSmall ? 11 : 13)),
                ),
              ]),
            ),
          ),
          SizedBox(height: isSmall ? 4 : 8),
          _buildBar('Demande', _demandQuantity, maxBar, Colors.cyan),
          const SizedBox(height: 3),
          _buildBar('Offre', _supplyQuantity, maxBar, Colors.orange),
          SizedBox(height: isSmall ? 6 : 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              _priceBtn('-\$5', Colors.red, () => _adjustPrice(-5)),
              _priceBtn('-\$1', Colors.red[300]!, () => _adjustPrice(-1)),
              _priceBtn('+\$1', Colors.green[300]!, () => _adjustPrice(1)),
              _priceBtn('+\$5', Colors.green, () => _adjustPrice(5)),
            ],
          ),
          SizedBox(height: isSmall ? 6 : 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitAnswer,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Valider'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: isSmall ? 8 : 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(String label, int value, double maxVal, Color color) {
    return Row(children: [
      SizedBox(width: 60, child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600))),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value / maxVal,
            backgroundColor: color.withOpacity(0.15),
            color: color,
            minHeight: 14,
          ),
        ),
      ),
      SizedBox(width: 36, child: Text(' $value', style: TextStyle(fontSize: 12, color: color))),
    ]);
  }

  Widget _priceBtn(String label, Color color, VoidCallback onTap) {
    return SizedBox(
      width: 68,
      height: 34,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color, foregroundColor: Colors.white,
          padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 2. CONSUMER CHOICE — Choix du consommateur
// ═══════════════════════════════════════════════════════════════════

class _Product {
  final String name;
  final double price;
  final int utility;
  final Color color;
  _Product(this.name, this.price, this.utility, this.color);
  double get utilityPerDollar => utility / price;
}

class FlutterConsumerChoiceView extends StatefulWidget {
  final ScoreCallback onAddScore;
  final ScoreCallback onSubtractScore;
  final GameEventCallback onGameEvent;
  final VoidCallback onGameEnd;

  const FlutterConsumerChoiceView({
    super.key,
    required this.onAddScore,
    required this.onSubtractScore,
    required this.onGameEvent,
    required this.onGameEnd,
  });

  @override
  State<FlutterConsumerChoiceView> createState() => _FlutterConsumerChoiceViewState();
}

class _FlutterConsumerChoiceViewState extends State<FlutterConsumerChoiceView> {
  final _products = <_Product>[
    _Product('Pommes', 2.0, 8, Colors.red),
    _Product('Pain', 3.0, 10, Colors.brown),
    _Product('Lait', 4.0, 12, Colors.blueGrey),
    _Product('Poulet', 8.0, 20, Colors.orange),
    _Product('Riz', 2.5, 9, Colors.teal),
    _Product('Légumes', 5.0, 15, Colors.green),
  ];
  late Map<String, int> _qty;
  double _budget = 100;
  double _remaining = 100;
  int _utility = 0;
  int _target = 0;
  int _round = 1;
  final int _maxRounds = 5;

  @override
  void initState() {
    super.initState();
    _qty = {for (var p in _products) p.name: 0};
    _generateScenario();
  }

  void _generateScenario() {
    _budget = 80.0 + Random().nextInt(40);
    _remaining = _budget;
    _qty.updateAll((_, __) => 0);
    _utility = 0;
    _target = (_meilleurPanier() * 0.85).round();
    setState(() {});
  }

  /// La meilleure utilité RÉELLEMENT atteignable avec le budget de la manche.
  ///
  /// L'ancien calcul additionnait, pour CHAQUE produit, ce qu'on pourrait
  /// acheter avec la TOTALITÉ du budget — comme si le budget était dépensé six
  /// fois. Il donnait un objectif de 676 là où le maximum atteignable est 400.
  ///
  /// Mesuré le 20/08/2026 sur les 40 budgets possibles (80 à 119) : le meilleur
  /// panier ne dépassait jamais 60,2 % de l'objectif, et le seuil de repêchage
  /// à 70 % n'était franchissable dans AUCUN cas. Le jeu était mathématiquement
  /// ingagnable — et il annonçait à l'étudiant « Sous l'objectif », c'est-à-dire
  /// qu'il avait mal optimisé.
  ///
  /// On calcule désormais ce que ferait un étudiant qui raisonne juste : acheter
  /// d'abord le meilleur rapport utilité/prix, puis le suivant avec la monnaie.
  /// Écart mesuré avec l'optimum exact (sac à dos) : 2 points d'utilité au pire
  /// sur les 40 budgets. L'objectif est fixé à 85 % de ce panier — exigeant,
  /// atteignable, et laissant place à l'erreur.
  int _meilleurPanier() {
    final ordre = [..._products]
      ..sort((a, b) => (b.utility / b.price).compareTo(a.utility / a.price));
    var reste = _budget;
    var total = 0;
    for (final p in ordre) {
      final n = (reste / p.price).floor();
      total += n * p.utility;
      reste -= n * p.price;
    }
    return total;
  }

  void _changeQty(String name, int delta) {
    final p = _products.firstWhere((e) => e.name == name);
    final cur = _qty[name] ?? 0;
    final next = (cur + delta).clamp(0, 99);
    final cost = (next - cur) * p.price;
    if (_remaining - cost < -0.01) return;
    setState(() {
      _qty[name] = next;
      _remaining -= cost;
      _utility = 0;
      for (final pr in _products) _utility += (_qty[pr.name] ?? 0) * pr.utility;
    });
  }

  void _reset() {
    setState(() {
      _qty.updateAll((_, __) => 0);
      _remaining = _budget;
      _utility = 0;
    });
  }

  void _submit() {
    if (_utility >= _target) {
      final eff = (_utility / _target).clamp(1.0, 1.5);
      final pts = (GameConstants.correctAnswerPoints * eff).round();
      widget.onAddScore(pts);
      widget.onGameEvent('Objectif atteint ! +$pts pts');
    } else if (_utility >= _target * 0.7) {
      final pts = (GameConstants.correctAnswerPoints * 0.5).round();
      widget.onAddScore(pts);
      widget.onGameEvent('Bon effort ! +$pts pts');
    } else {
      widget.onSubtractScore(GameConstants.wrongAnswerPenalty);
      widget.onGameEvent('Sous l\'objectif');
    }
    _round++;
    if (_round > _maxRounds) {
      widget.onGameEnd();
    } else {
      _generateScenario();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isSmall = mq.size.width < 380 || mq.size.height < 700;
    final pad = isSmall ? 8.0 : 12.0;
    final titleFs = isSmall ? 16.0 : 20.0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: pad, vertical: pad * 0.6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Choix du Consommateur', textAlign: TextAlign.center,
            style: TextStyle(fontSize: titleFs, fontWeight: FontWeight.bold, color: Colors.orange[700])),
        SizedBox(height: isSmall ? 2 : 4),
        Wrap(alignment: WrapAlignment.spaceEvenly, spacing: 4, runSpacing: 3, children: [
          _chip('Budget: \$${_remaining.toStringAsFixed(0)}/\$${_budget.toStringAsFixed(0)}',
              _remaining > 0 ? Colors.green : Colors.red),
          _chip('Utilité: $_utility', Colors.blue),
          _chip('Objectif: $_target', Colors.purple),
          _chip('Manche: $_round/$_maxRounds', Colors.grey),
        ]),
        SizedBox(height: isSmall ? 4 : 8),
        ...(_products.map((p) => _productRow(p))),
        SizedBox(height: isSmall ? 6 : 10),
        Row(children: [
          Expanded(
            child: OutlinedButton(onPressed: _reset, child: Text('Réinit.', style: TextStyle(fontSize: isSmall ? 12 : 14))),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Valider'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: isSmall ? 8 : 12),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _productRow(_Product p) {
    final qty = _qty[p.name] ?? 0;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(children: [
          Container(width: 8, height: 32, decoration: BoxDecoration(color: p.color, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text('\$${p.price.toStringAsFixed(1)}  •  Utilité ${p.utility}',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            ]),
          ),
          IconButton(icon: const Icon(Icons.remove_circle_outline, size: 22), padding: EdgeInsets.zero,
              constraints: const BoxConstraints(), onPressed: qty > 0 ? () => _changeQty(p.name, -1) : null),
          SizedBox(width: 28, child: Text('$qty', textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          IconButton(icon: const Icon(Icons.add_circle_outline, size: 22), padding: EdgeInsets.zero,
              constraints: const BoxConstraints(), onPressed: () => _changeQty(p.name, 1)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 3. FIRM TYCOON — Gestion d'entreprise
// ═══════════════════════════════════════════════════════════════════

class FlutterFirmTycoonView extends StatefulWidget {
  final ScoreCallback onAddScore;
  final ScoreCallback onSubtractScore;
  final GameEventCallback onGameEvent;
  final VoidCallback onGameEnd;

  const FlutterFirmTycoonView({
    super.key,
    required this.onAddScore,
    required this.onSubtractScore,
    required this.onGameEvent,
    required this.onGameEnd,
  });

  @override
  State<FlutterFirmTycoonView> createState() => _FlutterFirmTycoonViewState();
}

class _FlutterFirmTycoonViewState extends State<FlutterFirmTycoonView> {
  double _capital = 1000;
  double _revenue = 0, _costs = 0, _profit = 0;
  int _marketShare = 10, _round = 1;
  final int _maxRounds = 6;
  double _production = 50, _price = 50, _marketing = 50, _quality = 50;

  /// Le meilleur profit atteignable par trimestre, mesuré au démarrage.
  ///
  /// C'est la référence qui rend le score SENSIBLE AUX DÉCISIONS. L'ancien
  /// barème valait `(profit / 50).clamp(1, 10)` : il saturait dès 500 de profit,
  /// or le profit obtenu SANS TOUCHER À RIEN est de 8 712. Mesuré le 20/08/2026
  /// en balayant les 194 481 réglages possibles : ne rien faire donnait 650
  /// points — et jouer parfaitement donnait 650 aussi. Le jeu ne distinguait
  /// aucune décision, tout en promettant « Ajustez production, prix, marketing
  /// et qualité ».
  double _profitOptimal = 1;

  @override
  void initState() {
    super.initState();
    _profitOptimal = _mesurerOptimum();
    _calc();
  }

  /// Balaye les réglages au pas de 10 (14 641 combinaisons, quelques
  /// millisecondes) plutôt que de coder l'optimum en dur : si le modèle
  /// économique change un jour, le barème suit au lieu de mentir.
  double _mesurerOptimum() {
    var meilleur = 1.0;
    for (var p = 0; p <= 100; p += 10) {
      for (var pr = 0; pr <= 100; pr += 10) {
        for (var m = 0; m <= 100; m += 10) {
          for (var q = 0; q <= 100; q += 10) {
            final v = _profitPour(p.toDouble(), pr.toDouble(), m.toDouble(), q.toDouble());
            if (v > meilleur) meilleur = v;
          }
        }
      }
    }
    return meilleur;
  }

  /// Le modèle économique, isolé pour être mesurable — c'est ce qui a permis de
  /// prouver que le barème, et non le modèle, était en cause.
  double _profitPour(double production, double price, double marketing, double quality) {
    final priceEff = (100 - price) / 100;
    final mktEff = marketing / 100;
    final qEff = quality / 100;
    final demand = 1000.0 * priceEff * (1 + mktEff * 0.5) * (1 + qEff * 0.3);
    final prod = demand * (production / 100);
    return prod * (price * 0.5 + 5) - (prod * 2 + marketing * 10 + quality * 15 + 100);
  }

  void _calc() {
    final priceEff = (100 - _price) / 100;
    final mktEff = _marketing / 100;
    final qEff = _quality / 100;
    final demand = 1000.0 * priceEff * (1 + mktEff * 0.5) * (1 + qEff * 0.3);
    final prod = demand * (_production / 100);
    _revenue = prod * (_price * 0.5 + 5);
    _costs = prod * 2 + _marketing * 10 + _quality * 15 + 100;
    _profit = _revenue - _costs;
    _marketShare = (10 + mktEff * 20 + qEff * 15 - (_price - 50) * 0.2).round().clamp(0, 100);
  }

  void _simulate() {
    _capital += _profit;
    if (_profit > 0) {
      // Note la performance RELATIVE au meilleur trimestre possible : 20 points
      // pour un trimestre optimal, 7 pour un réglage laissé par défaut.
      // Mesuré : ne rien faire donne 92 sur la partie, jouer juste 170, un prix
      // trop haut 27. La décision compte enfin.
      final pts = (20 * _profit / _profitOptimal).round().clamp(0, 20);
      widget.onAddScore(pts);
      widget.onGameEvent('Profit \$${_profit.toStringAsFixed(0)} ! +$pts pts');
    } else {
      widget.onSubtractScore(GameConstants.wrongAnswerPenalty);
      widget.onGameEvent('Perte \$${_profit.abs().toStringAsFixed(0)}');
    }
    if (_capital <= 0) {
      widget.onGameEvent('Faillite !');
      widget.onGameEnd();
      return;
    }
    _round++;
    if (_round > _maxRounds) {
      // Paliers relevés en conséquence : l'ancien seuil de 2 000 était franchi
      // dès le premier trimestre sans rien faire, donc toujours acquis.
      if (_capital > 50000) widget.onAddScore(50);
      else if (_capital > 20000) widget.onAddScore(30);
      else if (_capital > 2000) widget.onAddScore(15);
      widget.onGameEnd();
    } else {
      setState(() {
        _production = 50; _price = 50; _marketing = 50; _quality = 50;
        _calc();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isSmall = mq.size.width < 380 || mq.size.height < 700;
    final pad = isSmall ? 8.0 : 12.0;
    final titleFs = isSmall ? 16.0 : 20.0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: pad, vertical: pad * 0.6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Magnat d\'Entreprise', textAlign: TextAlign.center,
            style: TextStyle(fontSize: titleFs, fontWeight: FontWeight.bold, color: Colors.purple[700])),
        SizedBox(height: isSmall ? 2 : 4),
        Text('Trimestre $_round/$_maxRounds', textAlign: TextAlign.center,
            style: TextStyle(fontSize: isSmall ? 10 : 12, color: Colors.grey[600])),
        SizedBox(height: isSmall ? 4 : 8),
        Wrap(alignment: WrapAlignment.center, spacing: 4, runSpacing: 3, children: [
          _kpi('Capital', '\$${_capital.toStringAsFixed(0)}', _capital > 0 ? Colors.green : Colors.red),
          _kpi('Revenus', '\$${_revenue.toStringAsFixed(0)}', Colors.blue),
          _kpi('Coûts', '\$${_costs.toStringAsFixed(0)}', Colors.red[300]!),
          _kpi('Profit', '\$${_profit.toStringAsFixed(0)}', _profit > 0 ? Colors.green : Colors.red),
          _kpi('Marché', '$_marketShare%', Colors.orange),
        ]),
        SizedBox(height: isSmall ? 4 : 10),
        _slider('Production', _production, (v) => setState(() { _production = v; _calc(); }), Colors.blue),
        _slider('Niveau prix', _price, (v) => setState(() { _price = v; _calc(); }), Colors.amber[700]!),
        _slider('Marketing', _marketing, (v) => setState(() { _marketing = v; _calc(); }), Colors.teal),
        _slider('Qualité', _quality, (v) => setState(() { _quality = v; _calc(); }), Colors.purple),
        SizedBox(height: isSmall ? 6 : 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _simulate,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: Text('Simuler le trimestre', style: TextStyle(fontSize: isSmall ? 13 : 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700], foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: isSmall ? 8 : 12),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _kpi(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(fontSize: 9, color: color)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  Widget _slider(String label, double value, ValueChanged<double> onChanged, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(width: 75, child: Text('$label ${value.round()}%', style: TextStyle(fontSize: 11, color: color))),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(activeTrackColor: color, thumbColor: color,
                inactiveTrackColor: color.withOpacity(0.2), trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7)),
            child: Slider(value: value, min: 0, max: 100, divisions: 20, onChanged: onChanged),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 4. MARKET STRUCTURES — QCM Structures de marché
// ═══════════════════════════════════════════════════════════════════

enum _MktStructure { perfectCompetition, monopoly, oligopoly, monopolisticCompetition, duopoly }

class _Scenario {
  final String description;
  final List<String> hints;
  final _MktStructure answer;
  final int difficulty; // 1=easy 2=medium 3=hard
  _Scenario(this.description, this.hints, this.answer, this.difficulty);
}

class FlutterMarketStructuresView extends StatefulWidget {
  final ScoreCallback onAddScore;
  final ScoreCallback onSubtractScore;
  final GameEventCallback onGameEvent;
  final VoidCallback onGameEnd;

  const FlutterMarketStructuresView({
    super.key,
    required this.onAddScore,
    required this.onSubtractScore,
    required this.onGameEvent,
    required this.onGameEnd,
  });

  @override
  State<FlutterMarketStructuresView> createState() => _FlutterMarketStructuresViewState();
}

class _FlutterMarketStructuresViewState extends State<FlutterMarketStructuresView> {
  final _scenarios = <_Scenario>[
    _Scenario('Beaucoup de petites entreprises vendant des produits identiques. Aucune ne peut influencer le prix.',
        ['Nombreuses entreprises', 'Produits identiques', 'Preneurs de prix'], _MktStructure.perfectCompetition, 1),
    _Scenario('Une seule entreprise contrôle tout le marché avec d\'importantes barrières à l\'entrée.',
        ['Une entreprise', 'Produit unique', 'Fixe les prix'], _MktStructure.monopoly, 1),
    _Scenario('Quelques grandes entreprises dominent le marché. Elles tiennent compte des actions des autres.',
        ['Peu d\'entreprises', 'Interdépendantes', 'Barrières à l\'entrée'], _MktStructure.oligopoly, 2),
    _Scenario('Beaucoup d\'entreprises vendent des produits similaires mais différenciés.',
        ['Nombreuses entreprises', 'Différenciation', 'Pouvoir limité'], _MktStructure.monopolisticCompetition, 2),
    _Scenario('Apple et Google dominent le marché des systèmes d\'exploitation mobiles.',
        ['Deux entreprises', 'Effets réseau', 'Coûts R&D élevés'], _MktStructure.duopoly, 3),
    _Scenario('Marché local avec de nombreux vendeurs proposant des légumes similaires.',
        ['Nombreux vendeurs', 'Produits similaires', 'Entrée facile'], _MktStructure.perfectCompetition, 1),
    _Scenario('De Beers contrôlait la majorité de l\'offre mondiale de diamants.',
        ['Vendeur unique', 'Contrôle offre', 'Fixation prix'], _MktStructure.monopoly, 2),
    _Scenario('Fast-food : McDonald\'s, Burger King, Wendy\'s en compétition.',
        ['Peu de grandes entreprises', 'Guerre publicitaire', 'Différenciation'], _MktStructure.oligopoly, 2),
    _Scenario('Restauration : nombreux établissements offrant différentes cuisines.',
        ['Nombreux restaurants', 'Menus uniques', 'Fidélité marque'], _MktStructure.monopolisticCompetition, 1),
    _Scenario('Boeing et Airbus dominent la fabrication d\'avions commerciaux.',
        ['Deux fabricants', 'Coûts d\'entrée élevés', 'Contrats gouvernementaux'], _MktStructure.duopoly, 3),
  ];

  int _current = 0;
  bool _answered = false;
  _MktStructure? _selected;
  late List<_MktStructure> _shuffledOptions;

  @override
  void initState() {
    super.initState();
    _shuffleOptions();
  }

  void _shuffleOptions() {
    _shuffledOptions = List<_MktStructure>.from(_MktStructure.values)..shuffle();
  }

  String _structureName(_MktStructure s) {
    switch (s) {
      case _MktStructure.perfectCompetition: return 'Concurrence parfaite';
      case _MktStructure.monopoly: return 'Monopole';
      case _MktStructure.oligopoly: return 'Oligopole';
      case _MktStructure.monopolisticCompetition: return 'Concurrence monopolistique';
      case _MktStructure.duopoly: return 'Duopole';
    }
  }

  Color _structureColor(_MktStructure s) {
    switch (s) {
      case _MktStructure.perfectCompetition: return Colors.green;
      case _MktStructure.monopoly: return Colors.red;
      case _MktStructure.oligopoly: return Colors.orange;
      case _MktStructure.monopolisticCompetition: return Colors.blue;
      case _MktStructure.duopoly: return Colors.purple;
    }
  }

  void _selectAnswer(_MktStructure s) {
    if (_answered) return;
    final scenario = _scenarios[_current];
    final correct = s == scenario.answer;
    setState(() { _answered = true; _selected = s; });

    if (correct) {
      final pts = GameConstants.correctAnswerPoints * scenario.difficulty;
      widget.onAddScore(pts);
      widget.onGameEvent('Correct ! +$pts pts');
    } else {
      widget.onSubtractScore(GameConstants.wrongAnswerPenalty);
      widget.onGameEvent('Incorrect');
    }
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _current++;
      if (_current >= _scenarios.length) {
        widget.onGameEnd();
      } else {
        setState(() { _answered = false; _selected = null; _shuffleOptions(); });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_current >= _scenarios.length) return const Center(child: Text('Terminé !'));
    final sc = _scenarios[_current];

    final mq = MediaQuery.of(context);
    final isSmall = mq.size.width < 380 || mq.size.height < 700;
    final pad = isSmall ? 8.0 : 12.0;
    final titleFs = isSmall ? 16.0 : 20.0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: pad, vertical: pad * 0.6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Structures de Marché', textAlign: TextAlign.center,
            style: TextStyle(fontSize: titleFs, fontWeight: FontWeight.bold, color: Colors.red[700])),
        SizedBox(height: isSmall ? 2 : 4),
        Text('Scénario ${_current + 1}/${_scenarios.length}', textAlign: TextAlign.center,
            style: TextStyle(fontSize: isSmall ? 10 : 12, color: Colors.grey[600])),
        SizedBox(height: isSmall ? 4 : 10),
        Card(
          color: Colors.grey[100],
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(sc.description, style: const TextStyle(fontSize: 14, height: 1.4)),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 4, children: sc.hints.map((h) =>
            Chip(label: Text(h, style: const TextStyle(fontSize: 10)), padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)).toList()),
        const SizedBox(height: 10),
        const Text('Quelle structure de marché ?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 6),
        ..._shuffledOptions.map((s) {
          final isCorrect = s == sc.answer;
          final isSelected = s == _selected;
          Color? bg;
          if (_answered) {
            if (isCorrect) bg = Colors.green.withOpacity(0.15);
            else if (isSelected) bg = Colors.red.withOpacity(0.15);
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Material(
              color: bg ?? Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: ListTile(
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: _structureColor(s).withOpacity(0.4)),
                ),
                leading: Icon(Icons.circle, color: _structureColor(s), size: 14),
                title: Text(_structureName(s), style: const TextStyle(fontSize: 13)),
                trailing: _answered && isCorrect ? const Icon(Icons.check_circle, color: Colors.green, size: 20) :
                    (_answered && isSelected && !isCorrect ? const Icon(Icons.cancel, color: Colors.red, size: 20) : null),
                onTap: _answered ? null : () => _selectAnswer(s),
              ),
            ),
          );
        }),
        if (_answered) ...[
          const SizedBox(height: 8),
          Card(
            color: _selected == sc.answer ? Colors.green[50] : Colors.red[50],
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                _selected == sc.answer
                    ? '✓ Correct ! C\'est ${_structureName(sc.answer)}.'
                    : '✗ La bonne réponse est ${_structureName(sc.answer)}.',
                style: TextStyle(
                  color: _selected == sc.answer ? Colors.green[800] : Colors.red[800],
                  fontSize: 12, fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}
