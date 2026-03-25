import 'dart:math';

import 'package:flutter/foundation.dart';
import '../services/td_service.dart';

/// Modèle d'une flashcard avec algorithme SM-2.
class PrepFlashcard {
  final String id;
  final String front;
  final String back;
  final String subject;
  final String? imageUrl;

  // SM-2 state
  double easeFactor;
  int interval; // jours
  int repetitions;
  DateTime nextReview;

  PrepFlashcard({
    required this.id,
    required this.front,
    required this.back,
    this.subject = '',
    this.imageUrl,
    this.easeFactor = 2.5,
    this.interval = 1,
    this.repetitions = 0,
    DateTime? nextReview,
  }) : nextReview = nextReview ?? DateTime.now();

  /// SM-2 : met à jour la carte selon la qualité de la réponse (0-5).
  /// 0-2 = échec, 3 = difficile, 4 = bien, 5 = facile
  void review(int quality) {
    if (quality < 3) {
      repetitions = 0;
      interval = 1;
    } else {
      if (repetitions == 0) {
        interval = 1;
      } else if (repetitions == 1) {
        interval = 6;
      } else {
        interval = (interval * easeFactor).round();
      }
      repetitions++;
    }
    easeFactor = max(1.3, easeFactor + 0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    nextReview = DateTime.now().add(Duration(days: interval));
  }

  bool get isDueForReview => DateTime.now().isAfter(nextReview) || DateTime.now().isAtSameMomentAs(nextReview);
}

class PrepFlashcardProvider extends ChangeNotifier {
  final TdService _service = TdService();

  List<PrepFlashcard> _allCards = [];
  List<PrepFlashcard> _dueCards = [];
  int _currentIndex = 0;
  int _reviewedToday = 0;
  bool _isFlipped = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _decks = [];

  List<PrepFlashcard> get allCards => List.unmodifiable(_allCards);
  List<PrepFlashcard> get dueCards => List.unmodifiable(_dueCards);
  int get currentIndex => _currentIndex;
  int get reviewedToday => _reviewedToday;
  bool get isFlipped => _isFlipped;
  bool get isLoading => _isLoading;
  List<Map<String, dynamic>> get decks => _decks;

  PrepFlashcard? get currentCard =>
      _currentIndex < _dueCards.length ? _dueCards[_currentIndex] : null;

  bool get hasNext => _currentIndex < _dueCards.length - 1;
  bool get isSessionComplete => _currentIndex >= _dueCards.length && _dueCards.isNotEmpty;

  /// Load flashcard decks from Supabase.
  Future<void> loadDecks() async {
    _isLoading = true;
    notifyListeners();
    try {
      _decks = await _service.prepListFlashcardDecks();
    } catch (e) {
      debugPrint('[PrepFlashcardProvider] loadDecks error: $e');
      _decks = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load flashcards for a specific deck from Supabase; fallback to demo.
  Future<void> loadCardsFromServer({String? deckId}) async {
    _isLoading = true;
    notifyListeners();
    try {
      if (deckId != null) {
        final cards = await _service.prepListFlashcards(deckId);
        if (cards.isNotEmpty) {
          _allCards = cards.map((m) {
            final nextReview = m['next_review_at'] != null
                ? DateTime.tryParse(m['next_review_at'].toString())
                : null;
            return PrepFlashcard(
              id: (m['id'] ?? '').toString(),
              front: (m['front_text'] ?? '').toString(),
              back: (m['back_text'] ?? '').toString(),
              subject: (m['subject'] ?? '').toString(),
              imageUrl: m['image_url']?.toString(),
              easeFactor: (m['ease_factor'] as num?)?.toDouble() ?? 2.5,
              interval: (m['interval_days'] as int?) ?? 1,
              repetitions: (m['repetitions'] as int?) ?? 0,
              nextReview: nextReview,
            );
          }).toList();
          _dueCards = _allCards.where((c) => c.isDueForReview).toList();
          _currentIndex = 0;
          _reviewedToday = 0;
          _isFlipped = false;
          _isLoading = false;
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('[PrepFlashcardProvider] loadCardsFromServer error: $e');
    }
    // Fallback to demo
    loadDemoCards();
    _isLoading = false;
    notifyListeners();
  }

  void loadDemoCards() {
    _allCards = _generateDemoCards();
    _dueCards = _allCards.where((c) => c.isDueForReview).toList();
    _currentIndex = 0;
    _reviewedToday = 0;
    _isFlipped = false;
    notifyListeners();
  }

  void flipCard() {
    _isFlipped = !_isFlipped;
    notifyListeners();
  }

  void reviewCurrent(int quality) {
    if (_currentIndex >= _dueCards.length) return;
    final card = _dueCards[_currentIndex];
    card.review(quality);
    _reviewedToday++;
    _isFlipped = false;

    // Save review to Supabase (fire-and-forget)
    _saveReviewToServer(card, quality);

    if (_currentIndex < _dueCards.length - 1) {
      _currentIndex++;
    } else {
      _currentIndex = _dueCards.length; // session complete
    }
    notifyListeners();
  }

  Future<void> _saveReviewToServer(PrepFlashcard card, int quality) async {
    try {
      await _service.prepSaveFlashcardReview(
        flashcardId: card.id,
        quality: quality,
        easeFactor: card.easeFactor,
        intervalDays: card.interval,
        repetitions: card.repetitions,
      );
    } catch (e) {
      debugPrint('[PrepFlashcardProvider] saveReview error: $e');
    }
  }

  void resetSession() {
    _dueCards = _allCards.where((c) => c.isDueForReview).toList();
    _currentIndex = 0;
    _reviewedToday = 0;
    _isFlipped = false;
    notifyListeners();
  }

  static List<PrepFlashcard> _generateDemoCards() {
    return [
      PrepFlashcard(
        id: 'fc1',
        front: 'Quel est le principe de légalité en droit administratif ?',
        back: 'L\'administration doit agir conformément au droit. Tout acte administratif doit avoir une base légale et respecter la hiérarchie des normes.',
        subject: 'Droit Administratif',
      ),
      PrepFlashcard(
        id: 'fc2',
        front: 'Qu\'est-ce que le PIB ?',
        back: 'Le Produit Intérieur Brut est la valeur totale de tous les biens et services produits dans un pays pendant une période donnée (généralement un an).',
        subject: 'Économie',
      ),
      PrepFlashcard(
        id: 'fc3',
        front: 'Formule de la loi d\'Ohm',
        back: 'U = R × I\n\nU = tension (Volts)\nR = résistance (Ohms)\nI = intensité (Ampères)',
        subject: 'Physique',
      ),
      PrepFlashcard(
        id: 'fc4',
        front: 'Quelles sont les 3 branches du pouvoir selon Montesquieu ?',
        back: '1. Pouvoir Législatif (faire les lois)\n2. Pouvoir Exécutif (appliquer les lois)\n3. Pouvoir Judiciaire (juger selon les lois)\n\nŒuvre : "De l\'Esprit des Lois" (1748)',
        subject: 'Droit Constitutionnel',
      ),
      PrepFlashcard(
        id: 'fc5',
        front: 'Qu\'est-ce que la mitose ?',
        back: 'Division cellulaire qui produit 2 cellules filles identiques à la cellule mère.\n\nPhases : Prophase → Métaphase → Anaphase → Télophase',
        subject: 'Biologie',
      ),
      PrepFlashcard(
        id: 'fc6',
        front: 'Quelle est la différence entre État unitaire et État fédéral ?',
        back: 'État unitaire : un seul centre de décision politique (ex: Cameroun, France)\n\nÉtat fédéral : pouvoir partagé entre État central et États fédérés (ex: USA, Nigeria)',
        subject: 'Droit Constitutionnel',
      ),
      PrepFlashcard(
        id: 'fc7',
        front: 'Théorème de Pythagore',
        back: 'Dans un triangle rectangle :\na² + b² = c²\n\noù c est l\'hypoténuse (côté opposé à l\'angle droit) et a, b sont les deux autres côtés.',
        subject: 'Mathématiques',
      ),
      PrepFlashcard(
        id: 'fc8',
        front: 'Quels sont les objectifs de la CEMAC ?',
        back: 'Communauté Économique et Monétaire de l\'Afrique Centrale :\n- Union monétaire (franc CFA)\n- Marché commun\n- Convergence des politiques économiques\n- Libre circulation des personnes et des biens\n\nMembres : Cameroun, Gabon, Congo, Tchad, RCA, Guinée Équatoriale',
        subject: 'Relations Internationales',
      ),
      PrepFlashcard(
        id: 'fc9',
        front: 'Qu\'est-ce que l\'inflation ?',
        back: 'Hausse généralisée et durable du niveau des prix dans une économie.\n\nConséquences :\n- Perte de pouvoir d\'achat\n- Dévaluation de la monnaie\n- Redistribution des richesses\n\nMesurée par l\'IPC (Indice des Prix à la Consommation)',
        subject: 'Économie',
      ),
      PrepFlashcard(
        id: 'fc10',
        front: 'Quelle est la structure de l\'ADN ?',
        back: 'Double hélice composée de :\n- Deux brins de nucléotides\n- Bases azotées complémentaires : A-T et G-C\n- Squelette sucre-phosphate\n\nDécouverte par Watson et Crick (1953)',
        subject: 'Biologie',
      ),
    ];
  }
}
