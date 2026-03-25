import 'dart:math';

/// Modèle d'une question psychotechnique générée algorithmiquement.
class PsychotechQuestion {
  final String type;
  final int difficulty;
  final String questionText;
  final dynamic questionData;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String method;

  const PsychotechQuestion({
    required this.type,
    required this.difficulty,
    required this.questionText,
    this.questionData,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.method,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'difficulty': difficulty,
    'questionText': questionText,
    'options': options,
    'correctIndex': correctIndex,
  };
}

/// Générateur algorithmique de tests psychotechniques.
/// Produit des questions illimitées pour 8 types de tests.
class PsychotechGenerator {
  static final _rng = Random();

  // ═══════════════════════════════════════════════════════════════
  // 1. SUITES NUMÉRIQUES
  // ═══════════════════════════════════════════════════════════════

  static PsychotechQuestion generateNumericSequence({int difficulty = 1}) {
    final types = <String>[
      if (difficulty <= 2) 'arithmetic',
      if (difficulty <= 3) 'geometric',
      if (difficulty >= 2) 'squares',
      if (difficulty >= 2) 'fibonacci',
      if (difficulty >= 3) 'triangular',
      if (difficulty >= 3) 'increasing_ops',
      if (difficulty >= 4) 'interleaved',
      if (difficulty >= 4) 'primes',
    ];
    if (types.isEmpty) types.add('arithmetic');
    final subType = types[_rng.nextInt(types.length)];

    List<int> sequence;
    String explanation;
    String method;

    switch (subType) {
      case 'arithmetic':
        final start = _rng.nextInt(10) + 1;
        final step = _rng.nextInt(5) + 2;
        sequence = List.generate(7, (i) => start + step * i);
        explanation = 'Suite arithmétique de raison +$step. Chaque terme augmente de $step.';
        method = 'Cherchez la différence constante entre chaque terme.';
        break;

      case 'geometric':
        final start = _rng.nextInt(3) + 2;
        final ratio = _rng.nextInt(3) + 2;
        sequence = List.generate(6, (i) => start * pow(ratio, i).toInt());
        explanation = 'Suite géométrique de raison ×$ratio. Chaque terme est multiplié par $ratio.';
        method = 'Divisez chaque terme par le précédent pour trouver la raison.';
        break;

      case 'squares':
        final offset = _rng.nextInt(3);
        sequence = List.generate(7, (i) => (i + 1 + offset) * (i + 1 + offset));
        explanation = 'Suite des carrés parfaits : ${sequence.map((s) => '${sqrt(s.toDouble()).round()}²=$s').join(', ')}.';
        method = 'Vérifiez si chaque nombre est un carré parfait (1, 4, 9, 16, 25...).';
        break;

      case 'fibonacci':
        final a = _rng.nextInt(3) + 1;
        final b = _rng.nextInt(3) + 1;
        sequence = [a, b];
        for (var i = 2; i < 7; i++) {
          sequence.add(sequence[i - 1] + sequence[i - 2]);
        }
        explanation = 'Suite de type Fibonacci : chaque terme = somme des 2 précédents.';
        method = 'Additionnez les 2 termes précédents pour obtenir le suivant.';
        break;

      case 'triangular':
        sequence = List.generate(7, (i) => (i + 1) * (i + 2) ~/ 2);
        explanation = 'Suite triangulaire : les écarts augmentent de +1 à chaque pas (+2, +3, +4, +5...).';
        method = 'Calculez les écarts entre termes consécutifs : ils augmentent de 1.';
        break;

      case 'increasing_ops':
        final start = _rng.nextInt(5) + 1;
        sequence = [start];
        for (var i = 1; i < 7; i++) {
          sequence.add(sequence[i - 1] + i + 1);
        }
        explanation = 'Les écarts augmentent : +2, +3, +4, +5, +6, +7.';
        method = 'Calculez les écarts : s\'ils augmentent régulièrement, c\'est une suite à opérateurs croissants.';
        break;

      case 'interleaved':
        final startA = _rng.nextInt(5) + 1;
        final startB = _rng.nextInt(5) + 10;
        final stepA = _rng.nextInt(3) + 2;
        final stepB = _rng.nextInt(3) + 2;
        sequence = [];
        for (var i = 0; i < 4; i++) {
          sequence.add(startA + stepA * i);
          sequence.add(startB + stepB * i);
        }
        explanation = 'Deux suites imbriquées : positions impaires (+$stepA) et positions paires (+$stepB).';
        method = 'Séparez les termes en 2 sous-suites (positions paires/impaires) et analysez chacune.';
        break;

      case 'primes':
        sequence = [2, 3, 5, 7, 11, 13, 17];
        explanation = 'Suite des nombres premiers : divisibles uniquement par 1 et eux-mêmes.';
        method = 'Vérifiez si chaque nombre est premier (pas de diviseur autre que 1 et lui-même).';
        break;

      default:
        final start = _rng.nextInt(10) + 1;
        sequence = List.generate(7, (i) => start + 3 * i);
        explanation = 'Suite arithmétique +3.';
        method = 'Différence constante.';
    }

    final hideIndex = sequence.length - 1;
    final correctAnswer = sequence[hideIndex];
    final displaySeq = sequence.sublist(0, hideIndex).map((e) => '$e').join(', ');

    final distractors = _generateDistractors(correctAnswer, 3);
    final allOptions = [correctAnswer, ...distractors]..shuffle(_rng);
    final correctIdx = allOptions.indexOf(correctAnswer);

    return PsychotechQuestion(
      type: 'suites_numeriques',
      difficulty: difficulty,
      questionText: 'Complétez la suite : $displaySeq, ?',
      questionData: {'sequence': sequence, 'subType': subType},
      options: allOptions.map((e) => '$e').toList(),
      correctIndex: correctIdx,
      explanation: '$explanation\nLa réponse est $correctAnswer.',
      method: method,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 2. SUITES ALPHABÉTIQUES
  // ═══════════════════════════════════════════════════════════════

  static PsychotechQuestion generateAlphaSequence({int difficulty = 1}) {
    final step = difficulty <= 2 ? (_rng.nextInt(3) + 1) : (_rng.nextInt(5) + 2);
    final startCode = _rng.nextInt(10) + 65; // A-J
    final ascending = _rng.nextBool();

    final sequence = <String>[];
    for (var i = 0; i < 7; i++) {
      final code = ascending
          ? ((startCode + step * i - 65) % 26) + 65
          : ((startCode - step * i - 65) % 26 + 26) % 26 + 65;
      sequence.add(String.fromCharCode(code));
    }

    final hideIndex = sequence.length - 1;
    final correct = sequence[hideIndex];
    final display = sequence.sublist(0, hideIndex).join(', ');

    final distractors = <String>[];
    for (var d = 1; distractors.length < 3; d++) {
      final c1 = String.fromCharCode(((correct.codeUnitAt(0) + d - 65) % 26) + 65);
      final c2 = String.fromCharCode(((correct.codeUnitAt(0) - d - 65) % 26 + 26) % 26 + 65);
      if (c1 != correct && !distractors.contains(c1)) distractors.add(c1);
      if (c2 != correct && !distractors.contains(c2) && distractors.length < 3) distractors.add(c2);
    }

    final allOptions = [correct, ...distractors.take(3)]..shuffle(_rng);

    return PsychotechQuestion(
      type: 'suites_alphabetiques',
      difficulty: difficulty,
      questionText: 'Complétez : $display, ?',
      questionData: {'sequence': sequence, 'step': step, 'ascending': ascending},
      options: allOptions,
      correctIndex: allOptions.indexOf(correct),
      explanation: 'Suite ${ascending ? "croissante" : "décroissante"} avec un intervalle de $step lettre(s). La réponse est $correct.',
      method: 'Comptez le nombre de lettres entre chaque terme pour trouver l\'intervalle.',
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 3. DOMINOS (format texte — le visuel sera en Phase B)
  // ═══════════════════════════════════════════════════════════════

  static PsychotechQuestion generateDomino({int difficulty = 1}) {
    final patterns = <String>[
      'progression',
      if (difficulty >= 2) 'cross_progression',
      if (difficulty >= 3) 'operation',
      if (difficulty >= 3) 'zigzag',
    ];
    final pattern = patterns[_rng.nextInt(patterns.length)];

    List<List<int>> dominos;
    String explanation;

    switch (pattern) {
      case 'progression':
        final startTop = _rng.nextInt(5);
        final startBot = _rng.nextInt(5);
        final stepTop = _rng.nextInt(2) + 1;
        final stepBot = _rng.nextInt(2) + 1;
        dominos = List.generate(5, (i) => [
          (startTop + stepTop * i) % 7,
          (startBot + stepBot * i) % 7,
        ]);
        explanation = 'Progression : face haute +$stepTop, face basse +$stepBot (modulo 7).';
        break;

      case 'cross_progression':
        final startTop = _rng.nextInt(5);
        final startBot = _rng.nextInt(5);
        final stepTop = _rng.nextInt(2) + 1;
        final stepBot = -(_rng.nextInt(2) + 1);
        dominos = List.generate(5, (i) => [
          (startTop + stepTop * i) % 7,
          ((startBot + stepBot * i) % 7 + 7) % 7,
        ]);
        explanation = 'Progression croisée : face haute +$stepTop, face basse $stepBot (modulo 7).';
        break;

      case 'operation':
        dominos = [];
        for (var i = 0; i < 5; i++) {
          if (i < 2) {
            dominos.add([_rng.nextInt(5) + 1, _rng.nextInt(5) + 1]);
          } else {
            dominos.add([
              (dominos[i - 1][0] + dominos[i - 2][0]) % 7,
              (dominos[i - 1][1] + dominos[i - 2][1]) % 7,
            ]);
          }
        }
        explanation = 'Opération : chaque domino = somme des 2 précédents (modulo 7).';
        break;

      case 'zigzag':
        final startTop = _rng.nextInt(5);
        final step = _rng.nextInt(2) + 1;
        dominos = List.generate(5, (i) => [
          (startTop + step * i) % 7,
          (startTop + step * (i + 1)) % 7,
        ]);
        explanation = 'Suite en Z : la face basse d\'un domino = la face haute du suivant, +$step.';
        break;

      default:
        dominos = List.generate(5, (i) => [(i + 1) % 7, (i + 2) % 7]);
        explanation = 'Progression simple +1 par face.';
    }

    final correctTop = dominos.last[0];
    final correctBot = dominos.last[1];
    final correctStr = '[$correctTop|$correctBot]';

    final displayDominos = dominos.sublist(0, dominos.length - 1)
        .map((d) => '[${d[0]}|${d[1]}]').join('  ');

    final distractorDominos = <String>[
      '[$correctTop|${(correctBot + 1) % 7}]',
      '[${(correctTop + 1) % 7}|$correctBot]',
      '[${(correctTop + 2) % 7}|${(correctBot + 2) % 7}]',
    ];

    final allOptions = [correctStr, ...distractorDominos]..shuffle(_rng);

    return PsychotechQuestion(
      type: 'dominos',
      difficulty: difficulty,
      questionText: 'Quel domino complète la série ?\n$displayDominos  [?|?]',
      questionData: {'dominos': dominos, 'pattern': pattern},
      options: allOptions,
      correctIndex: allOptions.indexOf(correctStr),
      explanation: '$explanation\nLa réponse est $correctStr.',
      method: 'Analysez séparément la face haute et la face basse. Les valeurs vont de 0 à 6 (après 6 → 0).',
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 4. CARTES À JOUER (format texte)
  // ═══════════════════════════════════════════════════════════════

  static PsychotechQuestion generatePlayingCard({int difficulty = 1}) {
    final suits = ['♠', '♥', '♦', '♣'];
    final valueNames = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10'];

    final stepVal = _rng.nextInt(3) + 1;
    final stepSuit = difficulty >= 2 ? 1 : 0;
    final startVal = _rng.nextInt(7);
    final startSuit = _rng.nextInt(4);

    final cards = List.generate(6, (i) {
      final v = (startVal + stepVal * i) % 10;
      final s = (startSuit + stepSuit * i) % 4;
      return '${valueNames[v]}${suits[s]}';
    });

    final correct = cards.last;
    final display = cards.sublist(0, cards.length - 1).join('  ');

    final distractors = <String>[];
    for (var d = 1; distractors.length < 3; d++) {
      final v = (startVal + stepVal * (5) + d) % 10;
      final s = (startSuit + stepSuit * (5) + d) % 4;
      final c = '${valueNames[v]}${suits[s]}';
      if (c != correct) distractors.add(c);
    }

    final allOptions = <String>[correct, ...distractors.take(3)]..shuffle(_rng);

    return PsychotechQuestion(
      type: 'cartes',
      difficulty: difficulty,
      questionText: 'Quelle carte complète la série ?\n$display  ?',
      questionData: {'cards': cards, 'stepVal': stepVal, 'stepSuit': stepSuit},
      options: allOptions,
      correctIndex: allOptions.indexOf(correct),
      explanation: 'La valeur augmente de +$stepVal${stepSuit > 0 ? " et la couleur alterne" : ""}. La réponse est $correct.',
      method: 'Analysez séparément la valeur (A=1, 2, 3...) et la couleur (♠♥♦♣). Chacune suit sa propre logique.',
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 5. ANALOGIES VERBALES (statiques — IA en Phase D)
  // ═══════════════════════════════════════════════════════════════

  static PsychotechQuestion generateVerbalAnalogy({int difficulty = 1}) {
    final analogiesWords = <List<String>>[
      ['CHAUD', 'FROID', 'GRAND'], ['MÉDECIN', 'HÔPITAL', 'ENSEIGNANT'], ['EAU', 'SOIF', 'NOURRITURE'],
      ['LIVRE', 'BIBLIOTHÈQUE', 'VOITURE'], ['PEINTRE', 'TABLEAU', 'MUSICIEN'], ['JOUR', 'NUIT', 'LUMIÈRE'],
      ['AVION', 'CIEL', 'BATEAU'], ['ŒIL', 'VOIR', 'OREILLE'], ['ARBRE', 'FORÊT', 'MAISON'],
      ['BOULANGER', 'PAIN', 'BOUCHER'], ['LUNDI', 'MARDI', 'JANVIER'], ['CHENILLE', 'PAPILLON', 'TÊTARD'],
    ];
    final analogiesCorrect = <String>[
      'Petit', 'École', 'Faim', 'Garage', 'Mélodie', 'Obscurité',
      'Mer', 'Entendre', 'Ville', 'Viande', 'Février', 'Grenouille',
    ];
    final analogiesDists = <List<String>>[
      ['Gros', 'Large', 'Immense'], ['Bureau', 'Mairie', 'Tribunal'], ['Cuisine', 'Restaurant', 'Manger'],
      ['Route', 'Parking', 'Station'], ['Instrument', 'Concert', 'Note'], ['Ombre', 'Noir', 'Soleil'],
      ['Port', 'Eau', 'Rivière'], ['Son', 'Bruit', 'Écouter'], ['Rue', 'Quartier', 'Pays'],
      ['Couteau', 'Marché', 'Animal'], ['Mars', 'Dimanche', 'Semaine'], ['Poisson', 'Eau', 'Larve'],
    ];
    final analogiesExpl = <String>[
      'Antonymes : chaud/froid = grand/petit.', 'Lieu de travail : médecin→hôpital = enseignant→école.',
      'Besoin satisfait : eau→soif = nourriture→faim.', 'Lieu de rangement : livre→bibliothèque = voiture→garage.',
      'Création : peintre→tableau = musicien→mélodie.', 'Antonymes : jour/nuit = lumière/obscurité.',
      'Milieu de déplacement : avion→ciel = bateau→mer.', 'Fonction sensorielle : œil→voir = oreille→entendre.',
      'Ensemble : arbre→forêt = maison→ville.', 'Produit : boulanger→pain = boucher→viande.',
      'Succession : lundi→mardi = janvier→février.', 'Métamorphose : chenille→papillon = têtard→grenouille.',
    ];

    final idx = _rng.nextInt(analogiesWords.length);
    final words = analogiesWords[idx];
    final correct = analogiesCorrect[idx];
    final dists = analogiesDists[idx];
    final expl = analogiesExpl[idx];

    final allOptions = [correct, ...dists]..shuffle(_rng);

    return PsychotechQuestion(
      type: 'analogies',
      difficulty: difficulty,
      questionText: '${words[0]} est à ${words[1]} ce que ${words[2]} est à :',
      options: allOptions,
      correctIndex: allOptions.indexOf(correct),
      explanation: '$expl La réponse est $correct.',
      method: 'Identifiez la relation entre les 2 premiers mots, puis appliquez la même relation au 3ème.',
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 6. INTRUS
  // ═══════════════════════════════════════════════════════════════

  static PsychotechQuestion generateIntruder({int difficulty = 1}) {
    final groupsItems = <List<String>>[
      ['Pomme', 'Banane', 'Carotte', 'Orange', 'Mangue'],
      ['Paris', 'Londres', 'Berlin', 'Lyon', 'Tokyo'],
      ['Triangle', 'Carré', 'Cercle', 'Rectangle', 'Losange'],
      ['Chien', 'Chat', 'Serpent', 'Lapin', 'Hamster'],
      ['Ouagadougou', 'Bobo-Dioulasso', 'Abidjan', 'Koudougou', 'Banfora'],
      ['Fer', 'Or', 'Bois', 'Cuivre', 'Argent'],
      ['Violon', 'Guitare', 'Tambour', 'Harpe', 'Piano'],
      ['Mars', 'Mercure', 'Soleil', 'Jupiter', 'Saturne'],
      ['Mouhoun', 'Nakambé', 'Niger', 'Tamise', 'Nazinon'],
      ['ENAREF', 'ENS', 'UNESCO', 'ENAM', 'ENSET'],
    ];
    final groupsIdx = <int>[2, 3, 2, 2, 2, 2, 2, 2, 3, 2];
    final groupsExpl = <String>[
      'Carotte est un légume, les autres sont des fruits.',
      'Lyon n\'est pas une capitale nationale.',
      'Le cercle n\'a pas de côtés.',
      'Le serpent est un reptile, les autres sont des mammifères.',
      'Abidjan est en Côte d\'Ivoire, les autres au Burkina Faso.',
      'Le bois n\'est pas un métal.',
      'Le tambour est un instrument à percussion, les autres à cordes.',
      'Le Soleil est une étoile, les autres sont des planètes.',
      'La Tamise est en Angleterre, les autres en Afrique de l\'Ouest.',
      'L\'UNESCO est internationale, les autres sont des écoles nationales.',
    ];

    final idx = _rng.nextInt(groupsItems.length);
    final items = groupsItems[idx];
    final intruderIdx = groupsIdx[idx];
    final expl = groupsExpl[idx];

    return PsychotechQuestion(
      type: 'intrus',
      difficulty: difficulty,
      questionText: 'Trouvez l\'intrus :',
      questionData: {'items': items},
      options: items,
      correctIndex: intruderIdx,
      explanation: '$expl La réponse est ${items[intruderIdx]}.',
      method: 'Cherchez le point commun entre 4 éléments. Celui qui ne partage pas cette caractéristique est l\'intrus.',
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 7. CALCUL MENTAL
  // ═══════════════════════════════════════════════════════════════

  static PsychotechQuestion generateMentalCalc({int difficulty = 1}) {
    int a, b, result;
    String op, question;

    if (difficulty <= 2) {
      a = _rng.nextInt(50) + 10;
      b = _rng.nextInt(30) + 5;
      if (_rng.nextBool()) {
        result = a + b; op = '+'; question = '$a + $b = ?';
      } else {
        if (a < b) { final t = a; a = b; b = t; }
        result = a - b; op = '-'; question = '$a - $b = ?';
      }
    } else if (difficulty <= 3) {
      a = _rng.nextInt(15) + 5;
      b = _rng.nextInt(10) + 3;
      result = a * b; op = '×'; question = '$a × $b = ?';
    } else {
      a = _rng.nextInt(20) + 5;
      b = _rng.nextInt(50) + 10;
      final price = a * 1000;
      final pct = [5, 10, 15, 20, 25][_rng.nextInt(5)];
      result = (price * pct) ~/ 100;
      question = '$pct% de $price FCFA = ?';
      op = '%';
    }

    final distractors = _generateDistractors(result, 3);
    final allOptions = [result, ...distractors]..shuffle(_rng);

    return PsychotechQuestion(
      type: 'calcul_mental',
      difficulty: difficulty,
      questionText: question,
      questionData: {'a': a, 'b': b, 'op': op},
      options: allOptions.map((e) => '$e').toList(),
      correctIndex: allOptions.indexOf(result),
      explanation: 'Le résultat de $question est $result.',
      method: op == '%' ? 'Pour calculer X% de N : multipliez N par X puis divisez par 100.'
          : 'Posez le calcul mentalement ou décomposez en étapes simples.',
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // GÉNÉRATION PRINCIPALE — par type ou aléatoire
  // ═══════════════════════════════════════════════════════════════

  static const allTypes = [
    'suites_numeriques',
    'suites_alphabetiques',
    'dominos',
    'cartes',
    'analogies',
    'intrus',
    'calcul_mental',
  ];

  static PsychotechQuestion generate({String? type, int difficulty = 1}) {
    final t = type ?? allTypes[_rng.nextInt(allTypes.length)];
    switch (t) {
      case 'suites_numeriques': return generateNumericSequence(difficulty: difficulty);
      case 'suites_alphabetiques': return generateAlphaSequence(difficulty: difficulty);
      case 'dominos': return generateDomino(difficulty: difficulty);
      case 'cartes': return generatePlayingCard(difficulty: difficulty);
      case 'analogies': return generateVerbalAnalogy(difficulty: difficulty);
      case 'intrus': return generateIntruder(difficulty: difficulty);
      case 'calcul_mental': return generateMentalCalc(difficulty: difficulty);
      default: return generateNumericSequence(difficulty: difficulty);
    }
  }

  /// Génère une série de N questions pour un mode d'entraînement.
  static List<PsychotechQuestion> generateSession({
    int count = 10,
    String? type,
    int difficulty = 1,
    bool mixed = false,
  }) {
    return List.generate(count, (_) => generate(
      type: mixed ? null : type,
      difficulty: difficulty,
    ));
  }

  /// Génère un exam blanc paramilitaire complet (format concours BF).
  static List<PsychotechQuestion> generateExamBlanc() {
    return [
      ...List.generate(10, (_) => generateNumericSequence(difficulty: 2)),
      ...List.generate(6, (_) => generateDomino(difficulty: 2)),
      ...List.generate(4, (_) => generatePlayingCard(difficulty: 2)),
      ...List.generate(5, (_) => generateVerbalAnalogy(difficulty: 2)),
      ...List.generate(3, (_) => generateIntruder(difficulty: 2)),
      ...List.generate(7, (_) => generateMentalCalc(difficulty: 2)),
    ];
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════

  static List<int> _generateDistractors(int correct, int count) {
    final distractors = <int>{};
    final range = max(5, (correct * 0.3).abs().toInt());
    while (distractors.length < count) {
      final d = correct + _rng.nextInt(range * 2 + 1) - range;
      if (d != correct && d > 0) distractors.add(d);
    }
    return distractors.toList();
  }

  static String typeLabel(String type) {
    switch (type) {
      case 'suites_numeriques': return 'Suites numériques';
      case 'suites_alphabetiques': return 'Suites alphabétiques';
      case 'dominos': return 'Dominos';
      case 'cartes': return 'Cartes à jouer';
      case 'analogies': return 'Analogies verbales';
      case 'intrus': return 'Intrus';
      case 'calcul_mental': return 'Calcul mental';
      default: return type;
    }
  }

  static String typeIcon(String type) {
    switch (type) {
      case 'suites_numeriques': return '🔢';
      case 'suites_alphabetiques': return '🔤';
      case 'dominos': return '🎲';
      case 'cartes': return '🃏';
      case 'analogies': return '🔗';
      case 'intrus': return '🔍';
      case 'calcul_mental': return '🧮';
      default: return '❓';
    }
  }
}
