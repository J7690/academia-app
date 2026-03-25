/// Base de données de questions de microéconomie pour les jeux Kellenge
/// Contient des questions classées par type et difficulté

/// Niveaux de difficulté pour les questions
enum QuestionDifficulty {
  easy,
  medium,
  hard,
}
class MicroeconomicQuestions {
  static MicroeconomicQuestions? _instance;
  static MicroeconomicQuestions get instance => _instance ??= MicroeconomicQuestions._();
  
  MicroeconomicQuestions._();
  
  // Questions par type de jeu
  final List<MicroeconomicQuestion> _marketMasterQuestions = [];
  final List<MicroeconomicQuestion> _consumerChoiceQuestions = [];
  final List<MicroeconomicQuestion> _firmTycoonQuestions = [];
  final List<MicroeconomicQuestion> _marketStructuresQuestions = [];
  
  void initializeQuestions() {
    _initializeMarketMasterQuestions();
    _initializeConsumerChoiceQuestions();
    _initializeFirmTycoonQuestions();
    _initializeMarketStructuresQuestions();
  }
  
  void _initializeMarketMasterQuestions() {
    _marketMasterQuestions.addAll([
      MicroeconomicQuestion(
        id: 'mm_001',
        question: 'What happens to quantity demanded when price increases?',
        options: ['Increases', 'Decreases', 'Stays the same', 'Cannot determine'],
        correctAnswer: 1,
        explanation: 'According to the law of demand, quantity demanded decreases when price increases, ceteris paribus.',
        difficulty: QuestionDifficulty.easy,
        category: 'Demand Theory',
      ),
      MicroeconomicQuestion(
        id: 'mm_002',
        question: 'At market equilibrium, what is true about supply and demand?',
        options: [
          'Supply > Demand',
          'Demand > Supply', 
          'Supply = Demand',
          'Both are zero'
        ],
        correctAnswer: 2,
        explanation: 'Market equilibrium occurs where quantity supplied equals quantity demanded.',
        difficulty: QuestionDifficulty.easy,
        category: 'Market Equilibrium',
      ),
      MicroeconomicQuestion(
        id: 'mm_003',
        question: 'If a price ceiling is set below equilibrium price, what results?',
        options: ['Surplus', 'Shortage', 'No effect', 'Increased supply'],
        correctAnswer: 1,
        explanation: 'A price ceiling below equilibrium creates a shortage as quantity demanded exceeds quantity supplied.',
        difficulty: QuestionDifficulty.medium,
        category: 'Price Controls',
      ),
      MicroeconomicQuestion(
        id: 'mm_004',
        question: 'What is the effect of a subsidy on market supply?',
        options: ['Supply shifts left', 'Supply shifts right', 'Demand shifts left', 'No effect on supply'],
        correctAnswer: 1,
        explanation: 'A subsidy decreases production costs, shifting the supply curve to the right.',
        difficulty: QuestionDifficulty.medium,
        category: 'Government Intervention',
      ),
      MicroeconomicQuestion(
        id: 'mm_005',
        question: 'In a competitive market, who determines the price?',
        options: ['Individual firms', 'Consumers', 'Market forces', 'Government'],
        correctAnswer: 2,
        explanation: 'In competitive markets, price is determined by the interaction of supply and demand.',
        difficulty: QuestionDifficulty.easy,
        category: 'Market Dynamics',
      ),
    ]);
  }
  
  void _initializeConsumerChoiceQuestions() {
    _consumerChoiceQuestions.addAll([
      MicroeconomicQuestion(
        id: 'cc_001',
        question: 'What is utility maximization subject to?',
        options: ['No constraints', 'Budget constraint', 'Time constraint', 'Price constraint'],
        correctAnswer: 1,
        explanation: 'Consumers maximize utility subject to their budget constraint.',
        difficulty: QuestionDifficulty.easy,
        category: 'Consumer Theory',
      ),
      MicroeconomicQuestion(
        id: 'cc_002',
        question: 'What does the marginal utility per dollar represent?',
        options: ['Total utility', 'Additional satisfaction per dollar spent', 'Price elasticity', 'Budget limit'],
        correctAnswer: 1,
        explanation: 'Marginal utility per dollar shows the additional satisfaction gained from spending one more dollar.',
        difficulty: QuestionDifficulty.medium,
        category: 'Marginal Analysis',
      ),
      MicroeconomicQuestion(
        id: 'cc_003',
        question: 'When should a consumer stop purchasing a good?',
        options: [
          'When total utility is maximized',
          'When marginal utility equals price',
          'When marginal utility is zero',
          'When budget is exhausted'
        ],
        correctAnswer: 1,
        explanation: 'Optimal consumption occurs when marginal utility equals the price of the good.',
        difficulty: QuestionDifficulty.medium,
        category: 'Optimal Choice',
      ),
      MicroeconomicQuestion(
        id: 'cc_004',
        question: 'What is the income effect?',
        options: [
          'Change in quantity demanded due to price change',
          'Change in purchasing power due to price change',
          'Change in consumer income',
          'Change in producer revenue'
        ],
        correctAnswer: 1,
        explanation: 'The income effect is the change in quantity demanded due to the change in real purchasing power.',
        difficulty: QuestionDifficulty.hard,
        category: 'Consumer Behavior',
      ),
      MicroeconomicQuestion(
        id: 'cc_005',
        question: 'What are normal goods?',
        options: [
          'Goods whose demand decreases when income falls',
          'Goods whose demand increases when income falls',
          'Goods with constant demand regardless of income',
          'Luxury goods only'
        ],
        correctAnswer: 0,
        explanation: 'Normal goods are goods for which demand increases when consumer income rises.',
        difficulty: QuestionDifficulty.easy,
        category: 'Goods Classification',
      ),
    ]);
  }
  
  void _initializeFirmTycoonQuestions() {
    _firmTycoonQuestions.addAll([
      MicroeconomicQuestion(
        id: 'ft_001',
        question: 'What is the primary goal of a profit-maximizing firm?',
        options: ['Maximize revenue', 'Minimize costs', 'Maximize profit', 'Maximize market share'],
        correctAnswer: 2,
        explanation: 'The primary goal is to maximize the difference between total revenue and total costs.',
        difficulty: QuestionDifficulty.easy,
        category: 'Firm Objectives',
      ),
      MicroeconomicQuestion(
        id: 'ft_002',
        question: 'When does a firm shut down in the short run?',
        options: [
          'When price equals average total cost',
          'When price is below average variable cost',
          'When price is below average total cost',
          'When marginal cost equals marginal revenue'
        ],
        correctAnswer: 1,
        explanation: 'A firm shuts down when price falls below average variable cost, as it cannot cover variable costs.',
        difficulty: QuestionDifficulty.medium,
        category: 'Production Decisions',
      ),
      MicroeconomicQuestion(
        id: 'ft_003',
        question: 'What is marginal cost?',
        options: [
          'Cost of producing one more unit',
          'Average cost per unit',
          'Total cost of production',
          'Fixed cost per unit'
        ],
        correctAnswer: 0,
        explanation: 'Marginal cost is the additional cost incurred by producing one more unit of output.',
        difficulty: QuestionDifficulty.easy,
        category: 'Cost Theory',
      ),
      MicroeconomicQuestion(
        id: 'ft_004',
        question: 'In perfect competition, how does a firm determine output?',
        options: [
          'Where marginal cost equals marginal revenue',
          'Where average cost is minimized',
          'Where total revenue is maximized',
          'Where price equals average total cost'
        ],
        correctAnswer: 0,
        explanation: 'Firms produce where marginal cost equals marginal revenue (price in perfect competition).',
        difficulty: QuestionDifficulty.medium,
        category: 'Production Theory',
      ),
      MicroeconomicQuestion(
        id: 'ft_005',
        question: 'What are economies of scale?',
        options: [
          'Increasing average costs as output increases',
          'Decreasing average costs as output increases',
          'Constant average costs regardless of output',
          'Increasing marginal costs as output increases'
        ],
        correctAnswer: 1,
        explanation: 'Economies of scale occur when average costs decrease as production increases.',
        difficulty: QuestionDifficulty.medium,
        category: 'Cost Structure',
      ),
    ]);
  }
  
  void _initializeMarketStructuresQuestions() {
    _marketStructuresQuestions.addAll([
      MicroeconomicQuestion(
        id: 'ms_001',
        question: 'What is a key characteristic of perfect competition?',
        options: [
          'Many firms, identical products',
          'Few firms, differentiated products',
          'One firm, unique product',
          'Two firms, strategic interaction'
        ],
        correctAnswer: 0,
        explanation: 'Perfect competition features many firms selling identical products with no market power.',
        difficulty: QuestionDifficulty.easy,
        category: 'Market Types',
      ),
      MicroeconomicQuestion(
        id: 'ms_002',
        question: 'What prevents entry in a monopoly?',
        options: [
          'Low prices',
          'High competition',
          'Barriers to entry',
          'Consumer preferences'
        ],
        correctAnswer: 2,
        explanation: 'Monopolies maintain their position through barriers to entry that prevent competition.',
        difficulty: QuestionDifficulty.easy,
        category: 'Monopoly',
      ),
      MicroeconomicQuestion(
        id: 'ms_003',
        question: 'What is strategic interdependence in oligopoly?',
        options: [
          'Firms act independently',
          'Firms consider rivals\' reactions',
          'Firms ignore competition',
          'Firms cooperate always'
        ],
        correctAnswer: 1,
        explanation: 'Strategic interdependence means each firm considers the potential reactions of its rivals.',
        difficulty: QuestionDifficulty.medium,
        category: 'Oligopoly',
      ),
      MicroeconomicQuestion(
        id: 'ms_004',
        question: 'How do firms differentiate products in monopolistic competition?',
        options: [
          'Price competition only',
          'Quality, branding, location',
          'Government regulation',
          'No differentiation'
        ],
        correctAnswer: 1,
        explanation: 'Firms differentiate through product quality, branding, location, and other non-price factors.',
        difficulty: QuestionDifficulty.medium,
        category: 'Product Differentiation',
      ),
      MicroeconomicQuestion(
        id: 'ms_005',
        question: 'What is the kinked demand curve theory?',
        options: [
          'Explains price rigidity in oligopoly',
          'Describes perfect competition',
          'Models monopoly pricing',
          'Explains consumer behavior'
        ],
        correctAnswer: 0,
        explanation: 'The kinked demand curve explains price rigidity in oligopolistic markets.',
        difficulty: QuestionDifficulty.hard,
        category: 'Oligopoly Theory',
      ),
    ]);
  }
  
  // Getters pour accéder aux questions
  List<MicroeconomicQuestion> getMarketMasterQuestions({QuestionDifficulty? difficulty}) {
    if (difficulty == null) return List.from(_marketMasterQuestions);
    return _marketMasterQuestions.where((q) => q.difficulty == difficulty).toList();
  }
  
  List<MicroeconomicQuestion> getConsumerChoiceQuestions({QuestionDifficulty? difficulty}) {
    if (difficulty == null) return List.from(_consumerChoiceQuestions);
    return _consumerChoiceQuestions.where((q) => q.difficulty == difficulty).toList();
  }
  
  List<MicroeconomicQuestion> getFirmTycoonQuestions({QuestionDifficulty? difficulty}) {
    if (difficulty == null) return List.from(_firmTycoonQuestions);
    return _firmTycoonQuestions.where((q) => q.difficulty == difficulty).toList();
  }
  
  List<MicroeconomicQuestion> getMarketStructuresQuestions({QuestionDifficulty? difficulty}) {
    if (difficulty == null) return List.from(_marketStructuresQuestions);
    return _marketStructuresQuestions.where((q) => q.difficulty == difficulty).toList();
  }
  
  // Méthodes utilitaires
  MicroeconomicQuestion? getRandomQuestion(String gameType, {QuestionDifficulty? difficulty}) {
    List<MicroeconomicQuestion> questions;
    
    switch (gameType) {
      case 'Market Master':
        questions = getMarketMasterQuestions(difficulty: difficulty);
        break;
      case 'Consumer Choice':
        questions = getConsumerChoiceQuestions(difficulty: difficulty);
        break;
      case 'Firm Tycoon':
        questions = getFirmTycoonQuestions(difficulty: difficulty);
        break;
      case 'Market Structures':
        questions = getMarketStructuresQuestions(difficulty: difficulty);
        break;
      default:
        return null;
    }
    
    if (questions.isEmpty) return null;
    
    questions.shuffle();
    return questions.first;
  }
  
  List<MicroeconomicQuestion> getRandomQuestions(String gameType, int count, {QuestionDifficulty? difficulty}) {
    List<MicroeconomicQuestion> questions;
    
    switch (gameType) {
      case 'Market Master':
        questions = getMarketMasterQuestions(difficulty: difficulty);
        break;
      case 'Consumer Choice':
        questions = getConsumerChoiceQuestions(difficulty: difficulty);
        break;
      case 'Firm Tycoon':
        questions = getFirmTycoonQuestions(difficulty: difficulty);
        break;
      case 'Market Structures':
        questions = getMarketStructuresQuestions(difficulty: difficulty);
        break;
      default:
        return [];
    }
    
    questions.shuffle();
    return questions.take(count).toList();
  }
}

/// Modèle de question de microéconomie
class MicroeconomicQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctAnswer;
  final String explanation;
  final QuestionDifficulty difficulty;
  final String category;
  
  MicroeconomicQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    required this.difficulty,
    required this.category,
  });
  
  bool isCorrect(int selectedAnswer) => selectedAnswer == correctAnswer;
  
  String get correctOption => options[correctAnswer];
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
      'difficulty': difficulty.name,
      'category': category,
    };
  }
  
  factory MicroeconomicQuestion.fromJson(Map<String, dynamic> json) {
    return MicroeconomicQuestion(
      id: json['id'],
      question: json['question'],
      options: List<String>.from(json['options']),
      correctAnswer: json['correctAnswer'],
      explanation: json['explanation'],
      difficulty: QuestionDifficulty.values.firstWhere((d) => d.name == json['difficulty']),
      category: json['category'],
    );
  }
}
