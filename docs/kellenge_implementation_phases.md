# 🚀 **KELLENGE - PLAN D'IMPLÉMENTATION PAR PHASES**

## 📋 **TABLE DES MATIÈRES**
1. Méthodologie d'Audit et Implémentation
2. Phase 1 : Infrastructure de Base (2 jours)
3. Phase 2 : Core Game Engine (3 jours)
4. Phase 3 : Single Player Games (4 jours)
5. Phase 4 : Multiplayer Foundation (3 jours)
6. Phase 5 : Competitive Features (4 jours)
7. Phase 6 : Tournament System (3 jours)
8. Phase 7 : Integration & Testing (2 jours)
9. Phase 8 : Production Deployment (2 jours)

---

## 🎯 **MÉTHODOLOGIE D'AUDIT ET IMPLÉMENTATION**

### **📋 Processus par Phase**
Chaque phase suit strictement :
1. **Audit Flutter** : Analyse code existant
2. **Audit Supabase** : Commandes RPC via .windsurf
3. **Implémentation** : Modifications ciblées
4. **Vérification** : Tests et validation
5. **Bilan** : Point avant phase suivante

### **🔍 Audit Flutter**
```bash
# Recherche des fichiers existants
find lib/ -name "*.dart" | grep -E "(game|challenge|competition)"
grep -r "flame" lib/ --include="*.dart" || echo "Aucune référence flame trouvée"
grep -r "multiplayer" lib/ --include="*.dart" || echo "Aucune référence multiplayer trouvée"
```

### **🗄️ Audit Supabase**
```bash
# Via .windsurf RPCs
cd .windsurf
python -c "
from supabase_auto_manager import SupabaseAutoManager
manager = SupabaseAutoManager()
# Vérifier tables existantes
result = manager.execute_sql_auto('SELECT table_name FROM information_schema.tables WHERE table_schema = \'app\' ORDER BY table_name;')
print('Tables app.* existantes:', result)
# Vérifier RPCs existantes  
result = manager.execute_sql_auto('SELECT routine_name FROM information_schema.routines WHERE routine_schema = \'app\' AND routine_name LIKE \'app_%\' ORDER BY routine_name;')
print('RPCs app_* existantes:', result)
"
```

---

## 📦 **PHASE 1 : INFRASTRUCTURE DE BASE (2 jours)**

### **🎯 Objectifs**
- Installer packages Flame Engine
- Créer structure dossiers jeux
- Configurer assets et dépendances
- Ne **PAS** impacter l'application existante

### **🔍 Étape 1 : Audit Flutter (30 min)**
```bash
# Vérifier pubspec.yaml actuel
grep -A 20 "dependencies:" pubspec.yaml
# Vérifier structure dossiers existante
find lib/ -type d | head -20
# Vérifier assets existants
find assets/ -type f | head -10
```

### **🗄️ Étape 2 : Audit Supabase (30 min)**
```bash
cd .windsurf
python -c "
from supabase_auto_manager import SupabaseAutoManager
manager = SupabaseAutoManager()
# Vérifier si tables jeux existent déjà
result = manager.execute_sql_auto('SELECT table_name FROM information_schema.tables WHERE table_schema = \'app\' AND table_name LIKE \'%game%\' OR table_name LIKE \'%challenge%\' ORDER BY table_name;')
print('Tables jeux existantes:', result)
# Vérifier buckets assets
result = manager.execute_sql_auto('SELECT bucket_name FROM storage.buckets ORDER BY bucket_name;')
print('Buckets storage:', result)
"
```

### **🛠️ Étape 3 : Implémentation (1 jour)**

#### **3.1 Ajout Packages Flame**
```yaml
# pubspec.yaml - ajouter après ligne 35
  # Game Engine
  flame: ^1.36.0
  flame_audio: ^2.12.0
  forge2d: ^0.2.0
  flame_forge2d: ^0.2.0
  games_services: ^3.0.0
  
  # Game Assets
  - assets/images/game/
  - assets/audio/game/
  - assets/sprites/
```

#### **3.2 Création Structure Dossiers**
```bash
mkdir -p lib/games/economics/components
mkdir -p lib/games/economics/systems  
mkdir -p lib/games/economics/ui
mkdir -p lib/games/shared/audio
mkdir -p lib/games/shared/assets
mkdir -p lib/providers/game_provider.dart
mkdir -p lib/widgets/game_wrapper.dart
mkdir -p assets/images/game/economics
mkdir -p assets/audio/game/economics
mkdir -p assets/sprites/economics
```

#### **3.3 Fichiers de Base**
```dart
// lib/games/economics/economics_game.dart
import 'package:flame/game.dart';

class EconomicsGame extends FlameGame {
  @override
  Future<void> onLoad() async {
    // Initialisation plus tard
  }
}

// lib/providers/game_provider.dart
import 'package:flutter/material.dart';

class GameProvider extends ChangeNotifier {
  bool _isGameActive = false;
  
  bool get isGameActive => _isGameActive;
  
  void launchGame(String gameType) {
    _isGameActive = true;
    notifyListeners();
  }
}

// lib/widgets/game_wrapper.dart
import 'package:flutter/material.dart';

class GameWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Text('Game Engine Ready'),
    );
  }
}
```

### **✅ Étape 4 : Vérification (30 min)**
```bash
flutter pub get
flutter analyze
flutter test
# Vérifier que l'application compile toujours
flutter build apk --debug
```

### **📊 Étape 5 : Bilan Phase 1**
- ✅ Packages Flame installés
- ✅ Structure dossiers créée
- ✅ Application compile toujours
- ✅ Aucun impact sur fonctionnalités existantes

---

## 🎮 **PHASE 2 : CORE GAME ENGINE (3 jours)**

### **🎯 Objectifs**
- Implémenter moteur de jeu de base
- Créer système de scoring
- Ajouter gestion des assets
- Intégrer navigation jeux

### **🔍 Étape 1 : Audit Flutter (1 heure)**
```bash
# Vérifier intégration navigation existante
grep -r "go_router" lib/ --include="*.dart" | head -5
grep -r "Navigator" lib/ --include="*.dart" | head -5
# Vérifier providers existants
find lib/providers/ -name "*.dart"
# Vérifier widgets existants
find lib/widgets/ -name "*.dart"
```

### **🗄️ Étape 2 : Audit Supabase (1 heure)**
```bash
cd .windsurf
python -c "
from supabase_auto_manager import SupabaseAutoManager
manager = SupabaseAutoManager()
# Vérifier si tables student existent
result = manager.execute_sql_auto('SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = \'app\' AND table_name = \'students\' ORDER BY ordinal_position;')
print('Structure students:', result)
# Vérifier RPCs student existantes
result = manager.execute_sql_auto('SELECT routine_name FROM information_schema.routines WHERE routine_schema = \'app\' AND routine_name LIKE \'app_student_%\' ORDER BY routine_name LIMIT 10;')
print('RPCs student existantes:', result)
"
```

### **🛠️ Étape 3 : Implémentation (1 jour)**

#### **3.1 Game Engine Core**
```dart
// lib/games/economics/economics_game.dart
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame_audio/flame_audio.dart';

class EconomicsGame extends FlameGame {
  late final GameScoreManager _scoreManager;
  late final GameAssetManager _assetManager;
  
  @override
  Future<void> onLoad() async {
    _scoreManager = GameScoreManager();
    _assetManager = GameAssetManager();
    
    await _assetManager.loadAssets();
    await FlameAudio.audioCache.loadAll([
      'correct_answer.mp3',
      'wrong_answer.mp3',
      'game_over.mp3',
    ]);
  }
  
  void addScore(int points) {
    _scoreManager.addScore(points);
  }
  
  int get currentScore => _scoreManager.currentScore;
}

// lib/games/economics/managers/game_score_manager.dart
class GameScoreManager {
  int _score = 0;
  int _highScore = 0;
  
  void addScore(int points) {
    _score += points;
    if (_score > _highScore) {
      _highScore = _score;
    }
  }
  
  int get currentScore => _score;
  int get highScore => _highScore;
  
  void reset() {
    _score = 0;
  }
}

// lib/games/economics/managers/game_asset_manager.dart
class GameAssetManager {
  final Map<String, Sprite> _sprites = {};
  
  Future<void> loadAssets() async {
    // Loading sera implémenté plus tard
  }
  
  Sprite? getSprite(String name) => _sprites[name];
}
```

#### **3.2 Navigation Integration**
```dart
// lib/providers/game_provider.dart
import 'package:go_router/go_router.dart';
import '../games/economics/economics_game.dart';

class GameProvider extends ChangeNotifier {
  final Map<String, EconomicsGame> _activeGames = {};
  
  void launchGame(BuildContext context, String gameType) {
    final game = EconomicsGame();
    _activeGames[gameType] = game;
    
    // Navigation vers écran jeu
    context.go('/games/$gameType');
    notifyListeners();
  }
  
  EconomicsGame? getGame(String gameType) => _activeGames[gameType];
}

// lib/widgets/game_wrapper.dart
import 'package:flame/game.dart';
import '../games/economics/economics_game.dart';

class GameWrapper extends StatefulWidget {
  final String gameType;
  
  const GameWrapper({required this.gameType});
  
  @override
  _GameWrapperState createState() => _GameWrapperState();
}

class _GameWrapperState extends State<GameWrapper> {
  late EconomicsGame _game;
  
  @override
  void initState() {
    super.initState();
    _game = EconomicsGame();
  }
  
  @override
  Widget build(BuildContext context) {
    return GameWidget.controlled(
      gameFactory: () => _game,
      overlayBuilder: (context, game) => _buildGameOverlay(game),
    );
  }
  
  Widget _buildGameOverlay(EconomicsGame game) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Text('Score: ${game.currentScore}'),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Quitter'),
          ),
        ],
      ),
    );
  }
}
```

### **✅ Étape 4 : Vérification (1 heure)**
```bash
flutter analyze
flutter test
# Vérifier navigation
flutter run --debug
# Tester navigation vers page jeu (manuelle)
```

### **📊 Étape 5 : Bilan Phase 2**
- ✅ Moteur de jeu implémenté
- ✅ Système de scoring fonctionnel
- ✅ Navigation jeux intégrée
- ✅ Application stable

---

## 🎯 **PHASE 3 : SINGLE PLAYER GAMES (4 jours)**

### **🎯 Objectifs**
- Développer 4 jeux économiques solo
- Implémenter questions microéconomie
- Ajouter système de progression
- Intégrer feedback visuel et sonore

### **🔍 Étape 1 : Audit Flutter (1 heure)**
```bash
# Vérifier structures questions existantes
grep -r "question" lib/ --include="*.dart" | head -5
grep -r "quiz" lib/ --include="*.dart" | head -5
# Vérifier UI components existants
find lib/widgets/ -name "*.dart" | grep -E "(card|button|dialog)"
```

### **🗄️ Étape 2 : Audit Supabase (1 heure)**
```bash
cd .windsurf
python -c "
from supabase_auto_manager import SupabaseAutoManager
manager = SupabaseAutoManager()
# Vérifier si tables de contenu existent
result = manager.execute_sql_auto('SELECT table_name FROM information_schema.tables WHERE table_schema = \'app\' AND (table_name LIKE \'%course%\' OR table_name LIKE \'%exercise%\' OR table_name LIKE \'%question%\') ORDER BY table_name;')
print('Tables contenu existantes:', result)
# Vérifier structure pour potentielles questions économiques
result = manager.execute_sql_auto('SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = \'app\' AND table_name = \'courses\' ORDER BY ordinal_position LIMIT 10;')
print('Structure courses:', result)
"
```

### **🛠️ Étape 3 : Implémentation (2 jours)**

#### **3.1 Market Master Game**
```dart
// lib/games/economics/games/market_master_game.dart
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import '../economics_game.dart';
import '../components/supply_demand_curve.dart';
import '../components/market_chart.dart';

class MarketMasterGame extends EconomicsGame {
  late SupplyDemandCurve _supplyDemandCurve;
  late MarketChart _marketChart;
  int _currentLevel = 1;
  
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    _supplyDemandCurve = SupplyDemandCurve();
    _marketChart = MarketChart();
    
    add(_supplyDemandCurve);
    add(_marketChart);
    
    _loadLevel(_currentLevel);
  }
  
  void _loadLevel(int level) {
    // Charger scénario niveau
    final scenario = _getScenario(level);
    _supplyDemandCurve.setScenario(scenario);
  }
  
  MarketScenario _getScenario(int level) {
    switch(level) {
      case 1:
        return MarketScenario(
          title: "Marché du café - Éthiopie",
          initialSupply: 100,
          initialDemand: 80,
          price: 5.0,
          description: "Ajustez l'offre pour atteindre l'équilibre",
        );
      default:
        return MarketScenario.basic();
    }
  }
  
  void onPlayerAction(MarketAction action) {
    final success = _supplyDemandCurve.applyAction(action);
    if (success) {
      addScore(10);
      FlameAudio.play('correct_answer.mp3');
    } else {
      FlameAudio.play('wrong_answer.mp3');
    }
    
    if (_supplyDemandCurve.isEquilibriumReached()) {
      _levelComplete();
    }
  }
  
  void _levelComplete() {
    addScore(100);
    _currentLevel++;
    if (_currentLevel <= 20) {
      _loadLevel(_currentLevel);
    } else {
      _gameComplete();
    }
  }
}

// lib/games/economics/components/supply_demand_curve.dart
import 'package:flame/components.dart';
import 'package:flame/effects.dart';

class SupplyDemandCurve extends PositionComponent {
  late final TextComponent _titleText;
  late final TextComponent _scoreText;
  MarketScenario? _currentScenario;
  
  @override
  Future<void> onLoad() async {
    _titleText = TextComponent(
      text: 'Market Master',
      position: Vector2(0, 0),
    );
    add(_titleText);
    
    _scoreText = TextComponent(
      text: 'Score: 0',
      position: Vector2(0, 30),
    );
    add(_scoreText);
  }
  
  void setScenario(MarketScenario scenario) {
    _currentScenario = scenario;
    _titleText.text = scenario.title;
    // Implémenter logique courbes ici
  }
  
  bool applyAction(MarketAction action) {
    // Logique validation action
    return true; // Simplifié pour l'exemple
  }
  
  bool isEquilibriumReached() {
    // Logique vérification équilibre
    return true; // Simplifié
  }
}

// lib/games/economics/models/market_scenario.dart
class MarketScenario {
  final String title;
  final String description;
  final int initialSupply;
  final int initialDemand;
  final double price;
  
  MarketScenario({
    required this.title,
    required this.description,
    required this.initialSupply,
    required this.initialDemand,
    required this.price,
  });
  
  factory MarketScenario.basic() {
    return MarketScenario(
      title: "Marché de base",
      description: "Scénario d'apprentissage",
      initialSupply: 100,
      initialDemand: 100,
      price: 10.0,
    );
  }
}

enum MarketAction {
  increaseSupply,
  decreaseSupply,
  increaseDemand,
  decreaseDemand,
}
```

#### **3.2 Consumer Choice Game**
```dart
// lib/games/economics/games/consumer_choice_game.dart
class ConsumerChoiceGame extends EconomicsGame {
  late final BudgetConstraintComponent _budgetConstraint;
  late final IndifferenceCurveComponent _indifferenceCurve;
  int _currentScenario = 1;
  
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    _budgetConstraint = BudgetConstraintComponent();
    _indifferenceCurve = IndifferenceCurveComponent();
    
    add(_budgetConstraint);
    add(_indifferenceCurve);
    
    _loadScenario(_currentScenario);
  }
  
  void _loadScenario(int scenario) {
    final budget = _getBudget(scenario);
    _budgetConstraint.setBudget(budget);
    _indifferenceCurve.setPreferences(scenario);
  }
  
  BudgetScenario _getBudget(int scenario) {
    switch(scenario) {
      case 1:
        return BudgetScenario(
          title: "Budget étudiant - Dakar",
          totalBudget: 50000, // FCFA
          prices: {
            'nourriture': 20000,
            'logement': 15000,
            'transport': 5000,
            'loisirs': 10000,
          },
        );
      default:
        return BudgetScenario.basic();
    }
  }
  
  void onChoice(Map<String, double> choices) {
    final utility = _calculateUtility(choices);
    if (utility > _indifferenceCurve.currentUtility) {
      addScore(15);
      FlameAudio.play('correct_answer.mp3');
      _indifferenceCurve.updateUtility(utility);
    }
  }
  
  double _calculateUtility(Map<String, double> choices) {
    // Fonction utilité simplifiée
    return choices.values.fold(0.0, (sum, amount) => sum + amount * 0.1);
  }
}
```

#### **3.3 Firm Tycoon Game**
```dart
// lib/games/economics/games/firm_tycoon_game.dart
class FirmTycoonGame extends EconomicsGame {
  late final FirmDashboardComponent _dashboard;
  late final ProductionComponent _production;
  int _currentRound = 1;
  
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    _dashboard = FirmDashboardComponent();
    _production = ProductionComponent();
    
    add(_dashboard);
    add(_production);
    
    _loadRound(_currentRound);
  }
  
  void _loadRound(int round) {
    final scenario = _getScenario(round);
    _production.setScenario(scenario);
    _dashboard.updateMetrics(scenario);
  }
  
  FirmScenario _getScenario(int round) {
    switch(round) {
      case 1:
        return FirmScenario(
          title: "Startup Tech - Nairobi",
          initialCapital: 1000000,
          fixedCosts: 200000,
          variableCostPerUnit: 50,
          marketPrice: 100,
        );
      default:
        return FirmScenario.basic();
    }
  }
  
  void onProductionDecision(int quantity) {
    final profit = _calculateProfit(quantity);
    if (profit > 0) {
      addScore(20);
      FlameAudio.play('correct_answer.mp3');
    }
    
    _currentRound++;
    if (_currentRound <= 10) {
      _loadRound(_currentRound);
    } else {
      _gameComplete();
    }
  }
  
  double _calculateProfit(int quantity) {
    // Logique profit simplifiée
    final revenue = quantity * 100; // market price
    final costs = 200000 + (quantity * 50); // fixed + variable
    return revenue - costs;
  }
}
```

#### **3.4 Market Structures Game**
```dart
// lib/games/economics/games/market_structures_game.dart
class MarketStructuresGame extends EconomicsGame {
  late final MarketMapComponent _marketMap;
  late final CompetitionComponent _competition;
  int _currentStructure = 1;
  
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    _marketMap = MarketMapComponent();
    _competition = CompetitionComponent();
    
    add(_marketMap);
    add(_competition);
    
    _loadStructure(_currentStructure);
  }
  
  void _loadStructure(int structure) {
    final market = _getMarketStructure(structure);
    _marketMap.setMarket(market);
    _competition.setStructure(market);
  }
  
  MarketStructure _getMarketStructure(int structure) {
    switch(structure) {
      case 1:
        return MarketStructure.monopoly(
          title: "Télécoms - Afrique de l'Ouest",
          description: "Un seul opérateur dominant",
          marketShare: 0.8,
        );
      case 2:
        return MarketStructure.duopoly(
          title: "Banques - Sénégal",
          description: "Deux banques principales",
          marketShare: 0.6,
        );
      default:
        return MarketStructure.perfectCompetition();
    }
  }
  
  void onStrategyChoice(CompetitiveStrategy strategy) {
    final outcome = _competition.evaluateStrategy(strategy);
    if (outcome.success) {
      addScore(25);
      FlameAudio.play('correct_answer.mp3');
    }
    
    _currentStructure++;
    if (_currentStructure <= 8) {
      _loadStructure(_currentStructure);
    } else {
      _gameComplete();
    }
  }
}
```

### **✅ Étape 4 : Vérification (1 jour)**
```bash
flutter analyze
flutter test
# Tester chaque jeu individuellement
flutter run --debug
# Navigation manuelle vers chaque jeu
```

### **📊 Étape 5 : Bilan Phase 3**
- ✅ 4 jeux économiques implémentés
- ✅ Système de scoring intégré
- ✅ Feedback audio/visuel
- ✅ Progression par niveaux

---

## 🌐 **PHASE 4 : MULTIPLAYER FOUNDATION (3 jours)**

### **🎯 Objectifs**
- Implémenter infrastructure multiplayer
- Configurer Supabase Realtime
- Créer système de matchmaking
- Ajouter communication temps réel

### **🔍 Étape 1 : Audit Flutter (1 heure)**
```bash
# Vérifier si realtime déjà utilisé
grep -r "realtime" lib/ --include="*.dart" | head -5
grep -r "channel" lib/ --include="*.dart" | head -5
# Vérifier providers existants
find lib/providers/ -name "*realtime*" -o -name "*multiplayer*"
```

### **🗄️ Étape 2 : Audit Supabase (1 heure)**
```bash
cd .windsurf
python -c "
from supabase_auto_manager import SupabaseAutoManager
manager = SupabaseAutoManager()
# Vérifier si realtime déjà configuré
result = manager.execute_sql_auto('SELECT schemaname, tablename FROM pg_tables WHERE schemaname = \'realtime\' ORDER BY tablename;')
print('Tables realtime existantes:', result)
# Vérifier RLS policies
result = manager.execute_sql_execute('SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual FROM pg_policies WHERE schemaname = \'app\' ORDER BY tablename, policyname LIMIT 10;')
print('RLS policies existantes:', result)
"
```

### **🛠️ Étape 3 : Implémentation (1 jour)**

#### **3.1 Tables Multiplayer Supabase**
```sql
-- Création tables multiplayer
CREATE TABLE IF NOT EXISTS app.multiplayer_games (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    game_type TEXT NOT NULL,
    status TEXT DEFAULT 'waiting', -- waiting, active, completed
    player1_id UUID REFERENCES app.students(id),
    player2_id UUID REFERENCES app.students(id),
    current_round INTEGER DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS app.game_sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    game_id UUID REFERENCES app.multiplayer_games(id),
    player_id UUID REFERENCES app.students(id),
    score INTEGER DEFAULT 0,
    current_question INTEGER DEFAULT 1,
    answers JSONB DEFAULT '{}',
    time_used INTEGER DEFAULT 0,
    is_ready BOOLEAN DEFAULT FALSE,
    last_action TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS app.tournaments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    max_players INTEGER NOT NULL,
    format TEXT NOT NULL, -- single_elimination, double_elimination, round_robin
    status TEXT DEFAULT 'registration', -- registration, active, completed
    start_time TIMESTAMP WITH TIME ZONE,
    created_by UUID REFERENCES app.students(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS app.tournament_matches (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    tournament_id UUID REFERENCES app.tournaments(id),
    round INTEGER NOT NULL,
    match_number INTEGER NOT NULL,
    player1_id UUID REFERENCES app.students(id),
    player2_id UUID REFERENCES app.students(id) NULL,
    winner_id UUID REFERENCES app.students(id) NULL,
    status TEXT DEFAULT 'pending', -- pending, active, completed
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS Policies
ALTER TABLE app.multiplayer_games ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.game_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.tournaments ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.tournament_matches ENABLE ROW LEVEL SECURITY;

-- Policies pour multiplayer_games
CREATE POLICY "Users can view their own games" ON app.multiplayer_games
    FOR SELECT USING (
        player1_id = auth.uid() OR 
        player2_id = auth.uid()
    );

CREATE POLICY "Users can create games" ON app.multiplayer_games
    FOR INSERT WITH CHECK (player1_id = auth.uid());

-- Policies pour game_sessions
CREATE POLICY "Users can view their own sessions" ON app.game_sessions
    FOR SELECT USING (player_id = auth.uid());

CREATE POLICY "Users can update their own sessions" ON app.game_sessions
    FOR UPDATE USING (player_id = auth.uid());

-- Enable Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE app.multiplayer_games;
ALTER PUBLICATION supabase_realtime ADD TABLE app.game_sessions;
```

#### **3.2 RPCs Multiplayer**
```sql
-- RPC création partie multiplayer
CREATE OR REPLACE FUNCTION app_student_create_multiplayer_game(
    p_game_type TEXT,
    p_max_wait_time INTEGER DEFAULT 300 -- 5 minutes
)
RETURNS JSONB AS $$
DECLARE
    v_game_id UUID;
    v_existing_game UUID;
BEGIN
    -- Vérifier si une partie en attente existe déjà
    SELECT id INTO v_existing_game
    FROM app.multiplayer_games
    WHERE game_type = p_game_type
      AND status = 'waiting'
      AND player1_id != auth.uid()
      AND player2_id IS NULL
      AND created_at > NOW() - INTERVAL '1 minute'
    LIMIT 1;
    
    IF v_existing_game IS NOT NULL THEN
        -- Rejoindre partie existante
        UPDATE app.multiplayer_games
        SET player2_id = auth.uid(),
            status = 'active',
            started_at = NOW()
        WHERE id = v_existing_game;
        
        -- Créer session pour joueur 2
        INSERT INTO app.game_sessions (game_id, player_id)
        VALUES (v_existing_game, auth.uid());
        
        RETURN jsonb_build_object(
            'success', true,
            'game_id', v_existing_game,
            'action', 'joined'
        );
    ELSE
        -- Créer nouvelle partie
        INSERT INTO app.multiplayer_games (game_type, player1_id)
        VALUES (p_game_type, auth.uid())
        RETURNING id INTO v_game_id;
        
        -- Créer session pour joueur 1
        INSERT INTO app.game_sessions (game_id, player_id)
        VALUES (v_game_id, auth.uid());
        
        RETURN jsonb_build_object(
            'success', true,
            'game_id', v_game_id,
            'action', 'created'
        );
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC mise à jour session jeu
CREATE OR REPLACE FUNCTION app_student_update_game_session(
    p_game_id UUID,
    p_score INTEGER DEFAULT NULL,
    p_current_question INTEGER DEFAULT NULL,
    p_answer JSONB DEFAULT NULL,
    p_time_used INTEGER DEFAULT NULL,
    p_is_ready BOOLEAN DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_session_id UUID;
BEGIN
    -- Mettre à jour session
    UPDATE app.game_sessions
    SET 
        score = COALESCE(p_score, score),
        current_question = COALESCE(p_current_question, current_question),
        answers = CASE 
            WHEN p_answer IS NOT NULL THEN answers || p_answer::jsonb
            ELSE answers 
        END,
        time_used = COALESCE(p_time_used, time_used),
        is_ready = COALESCE(p_is_ready, is_ready),
        last_action = NOW()
    WHERE game_id = p_game_id AND player_id = auth.uid()
    RETURNING id INTO v_session_id;
    
    IF v_session_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Session not found'
        );
    END IF;
    
    RETURN jsonb_build_object(
        'success', true,
        'session_id', v_session_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC récupérer parties disponibles
CREATE OR REPLACE FUNCTION app_student_available_games(
    p_game_type TEXT DEFAULT NULL
)
RETURNS TABLE (
    game_id UUID,
    game_type TEXT,
    status TEXT,
    player1_name TEXT,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        g.id,
        g.game_type,
        g.status,
        s.full_name as player1_name,
        g.created_at
    FROM app.multiplayer_games g
    JOIN app.students s ON g.player1_id = s.id
    WHERE g.status = 'waiting'
      AND g.player1_id != auth.uid()
      AND (p_game_type IS NULL OR g.game_type = p_game_type)
      AND g.created_at > NOW() - INTERVAL '5 minutes'
    ORDER BY g.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### **3.3 Multiplayer Provider Flutter**
```dart
// lib/providers/multiplayer_provider.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class MultiplayerProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _gameChannel;
  MultiplayerGame? _currentGame;
  List<MultiplayerGame> _availableGames = [];
  bool _isConnected = false;
  
  MultiplayerGame? get currentGame => _currentGame;
  List<MultiplayerGame> get availableGames => _availableGames;
  bool get isConnected => _isConnected;
  
  Future<bool> createOrJoinGame(String gameType) async {
    try {
      final response = await _supabase.functions.invoke(
        'app_student_create_multiplayer_game',
        params: {'p_game_type': gameType},
      );
      
      if (response['success'] == true) {
        _currentGame = MultiplayerGame.fromJson(response);
        await _initializeRealtimeChannel();
        notifyListeners();
        return true;
      }
    } catch (e) {
      print('Error creating/joining game: $e');
    }
    return false;
  }
  
  Future<void> loadAvailableGames([String? gameType]) async {
    try {
      final response = await _supabase.functions.invoke(
        'app_student_available_games',
        params: gameType != null ? {'p_game_type': gameType} : {},
      );
      
      _availableGames = (response as List)
          .map((json) => MultiplayerGame.fromJson(json))
          .toList();
      notifyListeners();
    } catch (e) {
      print('Error loading available games: $e');
    }
  }
  
  Future<void> _initializeRealtimeChannel() async {
    if (_currentGame == null) return;
    
    _gameChannel = _supabase.channel('game_${_currentGame!.id}');
    
    _gameChannel!.onBroadcast(
      event: 'game_state_update',
      callback: (payload, [_]) {
        _handleGameStateUpdate(payload);
      },
    ).subscribe();
    
    _gameChannel!.onBroadcast(
      event: 'player_action',
      callback: (payload, [_]) {
        _handlePlayerAction(payload);
      },
    ).subscribe();
    
    _isConnected = true;
    notifyListeners();
  }
  
  void _handleGameStateUpdate(dynamic payload) {
    if (_currentGame != null) {
      _currentGame!.updateFromPayload(payload);
      notifyListeners();
    }
  }
  
  void _handlePlayerAction(dynamic payload) {
    final action = PlayerAction.fromPayload(payload);
    // Notifier le jeu de l'action adverse
    notifyListeners();
  }
  
  Future<void> sendPlayerAction(PlayerAction action) async {
    if (_gameChannel != null) {
      await _gameChannel!.sendBroadcastMessage(
        event: 'player_action',
        payload: action.toJson(),
      );
    }
  }
  
  Future<void> updateGameSession({
    int? score,
    int? currentQuestion,
    Map<String, dynamic>? answer,
    int? timeUsed,
    bool? isReady,
  }) async {
    if (_currentGame == null) return;
    
    try {
      await _supabase.functions.invoke(
        'app_student_update_game_session',
        params: {
          'p_game_id': _currentGame!.id,
          'p_score': score,
          'p_current_question': currentQuestion,
          'p_answer': answer,
          'p_time_used': timeUsed,
          'p_is_ready': isReady,
        },
      );
    } catch (e) {
      print('Error updating game session: $e');
    }
  }
  
  @override
  void dispose() {
    _gameChannel?.unsubscribe();
    super.dispose();
  }
}

// lib/models/multiplayer_game.dart
class MultiplayerGame {
  final String id;
  final String gameType;
  final String status;
  final String? player1Name;
  final DateTime createdAt;
  
  MultiplayerGame({
    required this.id,
    required this.gameType,
    required this.status,
    this.player1Name,
    required this.createdAt,
  });
  
  factory MultiplayerGame.fromJson(Map<String, dynamic> json) {
    return MultiplayerGame(
      id: json['game_id'],
      gameType: json['game_type'],
      status: json['status'],
      player1Name: json['player1_name'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
  
  void updateFromPayload(dynamic payload) {
    // Mettre à jour état du jeu depuis payload realtime
  }
}

class PlayerAction {
  final String playerId;
  final String action;
  final Map<String, dynamic> data;
  
  PlayerAction({
    required this.playerId,
    required this.action,
    required this.data,
  });
  
  factory PlayerAction.fromPayload(dynamic payload) {
    return PlayerAction(
      playerId: payload['player_id'],
      action: payload['action'],
      data: payload['data'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'player_id': playerId,
      'action': action,
      'data': data,
    };
  }
}
```

### **✅ Étape 4 : Vérification (1 jour)**
```bash
flutter analyze
flutter test
# Tester création partie
flutter run --debug
# Vérifier connexion realtime (logs console)
```

### **📊 Étape 5 : Bilan Phase 4**
- ✅ Infrastructure multiplayer créée
- ✅ Tables Supabase configurées
- ✅ RPCs multiplayer implémentées
- ✅ Communication temps réel fonctionnelle

---

## 🏆 **PHASE 5 : COMPETITIVE FEATURES (4 jours)**

### **🎯 Objectifs**
- Implémenter système de scoring compétitif
- Ajouter leaderboards temps réel
- Créer système de classement ELO
- Intégrer Game Services natifs

### **🔍 Étape 1 : Audit Flutter (1 heure)**
```bash
# Vérifier si games_services déjà utilisé
grep -r "games_services" pubspec.yaml
grep -r "leaderboard" lib/ --include="*.dart" | head -5
# Vérifier providers scoring existants
find lib/providers/ -name "*score*" -o -name "*rank*"
```

### **🗄️ Étape 2 : Audit Supabase (1 heure)**
```bash
cd .windsurf
python -c "
from supabase_auto_manager import SupabaseAutoManager
manager = SupabaseAutoManager()
# Vérifier si tables ranking existent
result = manager.execute_sql_auto('SELECT table_name FROM information_schema.tables WHERE table_schema = \'app\' AND (table_name LIKE \'%rank%\' OR table_name LIKE \'%score%\' OR table_name LIKE \'%leaderboard%\') ORDER BY table_name;')
print('Tables ranking existantes:', result)
# Vérifier structure students pour ELO
result = manager.execute_sql_auto('SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = \'app\' AND table_name = \'students\' AND column_name LIKE \'%elo%\' ORDER BY ordinal_position;')
print('Colonnes ELO existantes:', result)
"
```

### **🛠️ Étape 3 : Implémentation (2 jours)**

#### **3.1 Tables Compétition Supabase**
```sql
-- Table classements joueurs
CREATE TABLE IF NOT EXISTS app.player_rankings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    player_id UUID REFERENCES app.students(id) UNIQUE,
    elo_rating DECIMAL(10,2) DEFAULT 1200.00,
    total_games INTEGER DEFAULT 0,
    wins INTEGER DEFAULT 0,
    losses INTEGER DEFAULT 0,
    highest_score INTEGER DEFAULT 0,
    current_streak INTEGER DEFAULT 0,
    best_streak INTEGER DEFAULT 0,
    league TEXT DEFAULT 'challenger', -- bronze, silver, gold, diamond, master
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table historique compétitions
CREATE TABLE IF NOT EXISTS app.competition_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    player_id UUID REFERENCES app.students(id),
    game_id UUID REFERENCES app.multiplayer_games(id),
    opponent_id UUID REFERENCES app.students(id),
    player_score INTEGER,
    opponent_score INTEGER,
    result TEXT, -- win, loss, draw
    elo_change DECIMAL(10,2),
    elo_before DECIMAL(10,2),
    elo_after DECIMAL(10,2),
    game_type TEXT,
    played_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table achievements
CREATE TABLE IF NOT EXISTS app.achievements (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    icon TEXT,
    category TEXT, -- score, streak, games, special
    requirement_type TEXT, -- score_threshold, games_played, win_streak
    requirement_value INTEGER,
    points INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table player achievements
CREATE TABLE IF NOT EXISTS app.player_achievements (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    player_id UUID REFERENCES app.students(id),
    achievement_id UUID REFERENCES app.achievements(id),
    unlocked_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(player_id, achievement_id)
);

-- RLS Policies
ALTER TABLE app.player_rankings ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.competition_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.player_achievements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own rankings" ON app.player_rankings
    FOR SELECT USING (player_id = auth.uid());

CREATE POLICY "Users can view their own history" ON app.competition_history
    FOR SELECT USING (player_id = auth.uid());

CREATE POLICY "Users can view their achievements" ON app.player_achievements
    FOR SELECT USING (player_id = auth.uid());
```

#### **3.2 RPCs Compétition**
```sql
-- RPC calcul et mise à jour ELO
CREATE OR REPLACE FUNCTION app_update_player_elo(
    p_player_id UUID,
    p_opponent_id UUID,
    p_result TEXT, -- 'win', 'loss', 'draw'
    p_game_type TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_current_elo DECIMAL(10,2);
    v_opponent_elo DECIMAL(10,2);
    v_new_elo DECIMAL(10,2);
    v_opponent_new_elo DECIMAL(10,2);
    v_elo_change DECIMAL(10,2);
    v_k_factor DECIMAL := 32.0;
BEGIN
    -- Récupérer ELO actuels
    SELECT COALESCE(elo_rating, 1200.00) INTO v_current_elo
    FROM app.player_rankings
    WHERE player_id = p_player_id;
    
    SELECT COALESCE(elo_rating, 1200.00) INTO v_opponent_elo
    FROM app.player_rankings
    WHERE player_id = p_opponent_id;
    
    -- Calculer nouveaux ELO
    v_elo_change := v_k_factor * (
        CASE p_result
            WHEN 'win' THEN 1.0
            WHEN 'draw' THEN 0.5
            ELSE 0.0
        END - (1.0 / (1.0 + POWER(10.0, (v_opponent_elo - v_current_elo) / 400.0)))
    );
    
    v_new_elo := v_current_elo + v_elo_change;
    
    -- Calculer ELO adverse
    v_opponent_new_elo := v_opponent_elo - v_elo_change;
    
    -- Mettre à jour classements
    INSERT INTO app.player_rankings (player_id, elo_rating, total_games, wins, losses, updated_at)
    VALUES (p_player_id, v_new_elo, 1, 
            CASE WHEN p_result = 'win' THEN 1 ELSE 0 END,
            CASE WHEN p_result = 'loss' THEN 1 ELSE 0 END, NOW())
    ON CONFLICT (player_id) DO UPDATE SET
        elo_rating = v_new_elo,
        total_games = player_rankings.total_games + 1,
        wins = player_rankings.wins + CASE WHEN p_result = 'win' THEN 1 ELSE 0 END,
        losses = player_rankings.losses + CASE WHEN p_result = 'loss' THEN 1 ELSE 0 END,
        updated_at = NOW();
    
    INSERT INTO app.player_rankings (player_id, elo_rating, total_games, wins, losses, updated_at)
    VALUES (p_opponent_id, v_opponent_new_elo, 1,
            CASE WHEN p_result = 'loss' THEN 1 ELSE 0 END,
            CASE WHEN p_result = 'win' THEN 1 ELSE 0 END, NOW())
    ON CONFLICT (player_id) DO UPDATE SET
        elo_rating = v_opponent_new_elo,
        total_games = player_rankings.total_games + 1,
        wins = player_rankings.wins + CASE WHEN p_result = 'loss' THEN 1 ELSE 0 END,
        losses = player_rankings.losses + CASE WHEN p_result = 'win' THEN 1 ELSE 0 END,
        updated_at = NOW();
    
    -- Enregistrer historique
    INSERT INTO app.competition_history (
        player_id, opponent_id, result, elo_change, 
        elo_before, elo_after, game_type, played_at
    ) VALUES (
        p_player_id, p_opponent_id, p_result, v_elo_change,
        v_current_elo, v_new_elo, p_game_type, NOW()
    );
    
    -- Mettre à jour league
    UPDATE app.player_rankings
    SET league = CASE 
        WHEN elo_rating >= 2000 THEN 'master'
        WHEN elo_rating >= 1600 THEN 'diamond'
        WHEN elo_rating >= 1200 THEN 'gold'
        WHEN elo_rating >= 800 THEN 'silver'
        ELSE 'bronze'
    END
    WHERE player_id = p_player_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'elo_before', v_current_elo,
        'elo_after', v_new_elo,
        'elo_change', v_elo_change,
        'new_league', CASE 
            WHEN v_new_elo >= 2000 THEN 'master'
            WHEN v_new_elo >= 1600 THEN 'diamond'
            WHEN v_new_elo >= 1200 THEN 'gold'
            WHEN v_new_elo >= 800 THEN 'silver'
            ELSE 'bronze'
        END
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC leaderboard global
CREATE OR REPLACE FUNCTION app_get_global_leaderboard(
    p_limit INTEGER DEFAULT 50,
    p_league TEXT DEFAULT NULL
)
RETURNS TABLE (
    rank INTEGER,
    player_id UUID,
    player_name TEXT,
    elo_rating DECIMAL(10,2),
    total_games INTEGER,
    win_rate DECIMAL(5,2),
    league TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ROW_NUMBER() OVER (ORDER BY pr.elo_rating DESC) as rank,
        pr.player_id,
        s.full_name as player_name,
        pr.elo_rating,
        pr.total_games,
        CASE 
            WHEN pr.total_games > 0 THEN ROUND((pr.wins::DECIMAL / pr.total_games) * 100, 2)
            ELSE 0
        END as win_rate,
        pr.league
    FROM app.player_rankings pr
    JOIN app.students s ON pr.player_id = s.id
    WHERE (p_league IS NULL OR pr.league = p_league)
      AND pr.total_games >= 5 -- Minimum 5 parties pour être classé
    ORDER BY pr.elo_rating DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### **3.3 Competitive Provider Flutter**
```dart
// lib/providers/competitive_provider.dart
import 'package:games_services/games_services.dart';

class CompetitiveProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  PlayerRanking? _myRanking;
  List<LeaderboardEntry> _globalLeaderboard = [];
  List<Achievement> _achievements = [];
  bool _isGameCenterConnected = false;
  
  PlayerRanking? get myRanking => _myRanking;
  List<LeaderboardEntry> get globalLeaderboard => _globalLeaderboard;
  List<Achievement> get achievements => _achievements;
  bool get isGameCenterConnected => _isGameCenterConnected;
  
  Future<void> initialize() async {
    await _loadMyRanking();
    await _loadLeaderboard();
    await _connectGameServices();
    await _checkAchievements();
  }
  
  Future<void> _loadMyRanking() async {
    try {
      final response = await _supabase
          .from('player_rankings')
          .select()
          .eq('player_id', _supabase.auth.currentUser?.id)
          .single();
      
      _myRanking = PlayerRanking.fromJson(response);
      notifyListeners();
    } catch (e) {
      print('Error loading ranking: $e');
      _myRanking = PlayerRanking.default();
    }
  }
  
  Future<void> _loadLeaderboard() async {
    try {
      final response = await _supabase.functions.invoke(
        'app_get_global_leaderboard',
        params: {'p_limit': 50},
      );
      
      _globalLeaderboard = (response as List)
          .map((json) => LeaderboardEntry.fromJson(json))
          .toList();
      notifyListeners();
    } catch (e) {
      print('Error loading leaderboard: $e');
    }
  }
  
  Future<void> _connectGameServices() async {
    try {
      await GamesServices.signIn();
      _isGameCenterConnected = true;
      notifyListeners();
    } catch (e) {
      print('Game Services not available: $e');
      _isGameCenterConnected = false;
    }
  }
  
  Future<void> submitScore(int score, String gameType) async {
    // Soumettre à Game Services natifs
    if (_isGameCenterConnected) {
      try {
        await GamesServices.submitScore(
          score: Score(
            iOSLeaderboardID: '${gameType}_scores',
            androidLeaderboardID: '${gameType}_scores',
            value: score,
          ),
        );
      } catch (e) {
        print('Error submitting to Game Services: $e');
      }
    }
    
    // Soumettre à Supabase
    await _submitToSupabase(score, gameType);
  }
  
  Future<void> _submitToSupabase(int score, String gameType) async {
    try {
      // Mettre à jour highest score si nécessaire
      if (_myRanking == null || score > _myRanking!.highestScore) {
        await _supabase
            .from('player_rankings')
            .update({
              'highest_score': score,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('player_id', _supabase.auth.currentUser?.id);
        
        await _loadMyRanking();
      }
    } catch (e) {
      print('Error submitting score to Supabase: $e');
    }
  }
  
  Future<void> updateELO(String opponentId, String result, String gameType) async {
    try {
      final response = await _supabase.functions.invoke(
        'app_update_player_elo',
        params: {
          'p_player_id': _supabase.auth.currentUser?.id,
          'p_opponent_id': opponentId,
          'p_result': result,
          'p_game_type': gameType,
        },
      );
      
      if (response['success'] == true) {
        await _loadMyRanking();
        await _loadLeaderboard();
        await _checkAchievements();
      }
    } catch (e) {
      print('Error updating ELO: $e');
    }
  }
  
  Future<void> _checkAchievements() async {
    // Logique de vérification achievements
    // Basée sur le classement, streak, scores, etc.
  }
  
  Future<void> showLeaderboard() async {
    if (_isGameCenterConnected) {
      try {
        await GamesServices.showLeaderboards(
          iOSLeaderboardID: 'economia_challenge_scores',
          androidLeaderboardID: 'economia_challenge_scores',
        );
      } catch (e) {
        print('Error showing native leaderboard: $e');
      }
    }
  }
}

// lib/models/competitive_models.dart
class PlayerRanking {
  final String playerId;
  final double eloRating;
  final int totalGames;
  final int wins;
  final int losses;
  final int highestScore;
  final int currentStreak;
  final String league;
  
  PlayerRanking({
    required this.playerId,
    required this.eloRating,
    required this.totalGames,
    required this.wins,
    required this.losses,
    required this.highestScore,
    required this.currentStreak,
    required this.league,
  });
  
  factory PlayerRanking.fromJson(Map<String, dynamic> json) {
    return PlayerRanking(
      playerId: json['player_id'],
      eloRating: double.parse(json['elo_rating'].toString()),
      totalGames: json['total_games'],
      wins: json['wins'],
      losses: json['losses'],
      highestScore: json['highest_score'],
      currentStreak: json['current_streak'],
      league: json['league'],
    );
  }
  
  factory PlayerRanking.default() {
    return PlayerRanking(
      playerId: '',
      eloRating: 1200.0,
      totalGames: 0,
      wins: 0,
      losses: 0,
      highestScore: 0,
      currentStreak: 0,
      league: 'bronze',
    );
  }
  
  double get winRate {
    if (totalGames == 0) return 0.0;
    return (wins / totalGames) * 100;
  }
}

class LeaderboardEntry {
  final int rank;
  final String playerId;
  final String playerName;
  final double eloRating;
  final int totalGames;
  final double winRate;
  final String league;
  
  LeaderboardEntry({
    required this.rank,
    required this.playerId,
    required this.playerName,
    required this.eloRating,
    required this.totalGames,
    required this.winRate,
    required this.league,
  });
  
  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: json['rank'],
      playerId: json['player_id'],
      playerName: json['player_name'],
      eloRating: double.parse(json['elo_rating'].toString()),
      totalGames: json['total_games'],
      winRate: double.parse(json['win_rate'].toString()),
      league: json['league'],
    );
  }
}

class Achievement {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String category;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  
  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.isUnlocked,
    this.unlockedAt,
  });
}
```

### **✅ Étape 4 : Vérification (1 jour)**
```bash
flutter analyze
flutter test
# Tester soumission score
flutter run --debug
# Vérifier Game Services integration
```

### **📊 Étape 5 : Bilan Phase 5**
- ✅ Système ELO implémenté
- ✅ Leaderboards temps réel
- ✅ Game Services intégrés
- ✅ Achievements system

---

## 🏅 **PHASE 6 : TOURNAMENT SYSTEM (3 jours)**

### **🎯 Objectifs**
- Implémenter système de tournois
- Créer gestion brackets
- Ajouter mode async competitions
- Intégrer rewards et badges

### **🔍 Étape 1 : Audit Flutter (1 heure)**
```bash
# Vérifier si UI tournaments existent
grep -r "tournament" lib/ --include="*.dart" | head -5
grep -r "bracket" lib/ --include="*.dart" | head -5
# Vérifier components UI existants
find lib/widgets/ -name "*.dart" | grep -E "(card|list|dialog)"
```

### **🗄️ Étape 2 : Audit Supabase (1 heure)**
```bash
cd .windsurf
python -c "
from supabase_auto_manager import SupabaseAutoManager
manager = SupabaseAutoManager()
# Vérifier tables tournaments déjà créées
result = manager.execute_sql_auto('SELECT table_name FROM information_schema.tables WHERE table_schema = \'app\' AND table_name LIKE \'%tournament%\' ORDER BY table_name;')
print('Tables tournaments existantes:', result)
# Vérifier structure tournaments
result = manager.execute_sql_auto('SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = \'app\' AND table_name = \'tournaments\' ORDER BY ordinal_position;')
print('Structure tournaments:', result)
"
```

### **🛠️ Étape 3 : Implémentation (1 jour)**

#### **3.1 Tournament RPCs**
```sql
-- RPC création tournoi
CREATE OR REPLACE FUNCTION app_create_tournament(
    p_name TEXT,
    p_max_players INTEGER,
    p_format TEXT DEFAULT 'single_elimination',
    p_start_time TIMESTAMP WITH TIME ZONE DEFAULT NOW()
)
RETURNS JSONB AS $$
DECLARE
    v_tournament_id UUID;
BEGIN
    INSERT INTO app.tournaments (
        name, max_players, format, status, start_time, created_by
    ) VALUES (
        p_name, p_max_players, p_format, 'registration', 
        p_start_time, auth.uid()
    )
    RETURNING id INTO v_tournament_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'tournament_id', v_tournament_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC génération bracket
CREATE OR REPLACE FUNCTION app_generate_tournament_bracket(
    p_tournament_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_players JSONB;
    v_matches JSONB := '[]'::jsonb;
    v_player_count INTEGER;
    v_current_round INTEGER := 1;
    v_match_index INTEGER := 1;
BEGIN
    -- Récupérer joueurs inscrits
    SELECT jsonb_agg(
        jsonb_build_object(
            'player_id', player_id,
            'seed', ROW_NUMBER() OVER (ORDER BY created_at)
        )
    ) INTO v_players
    FROM app.tournament_registrations
    WHERE tournament_id = p_tournament_id
    ORDER BY created_at;
    
    v_player_count := jsonb_array_length(v_players);
    
    -- Générer premier round
    FOR i IN 0..v_player_count-1 BY 2 LOOP
        DECLARE
            v_player1 JSONB;
            v_player2 JSONB;
            v_match_id UUID := gen_random_uuid();
        BEGIN
            v_player1 := v_players -> i;
            v_player2 := CASE 
                WHEN i + 1 < v_player_count THEN v_players -> (i + 1)
                ELSE NULL
            END;
            
            -- Insérer match
            INSERT INTO app.tournament_matches (
                id, tournament_id, round, match_number, 
                player1_id, player2_id, status
            ) VALUES (
                v_match_id, p_tournament_id, v_current_round, v_match_index,
                (v_player1 ->> 'player_id')::uuid,
                CASE WHEN v_player2 IS NOT NULL THEN (v_player2 ->> 'player_id')::uuid ELSE NULL END,
                'pending'
            );
            
            -- Ajouter au résultat
            v_matches := v_matches || jsonb_build_object(
                'match_id', v_match_id,
                'round', v_current_round,
                'player1', v_player1,
                'player2', v_player2,
                'status', 'pending'
            );
            
            v_match_index := v_match_index + 1;
        END;
    END LOOP;
    
    -- Mettre à jour statut tournoi
    UPDATE app.tournaments
    SET status = 'active'
    WHERE id = p_tournament_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'matches', v_matches
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC inscription tournoi
CREATE OR REPLACE FUNCTION app_register_tournament(
    p_tournament_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_current_players INTEGER;
    v_max_players INTEGER;
    v_registration_id UUID;
BEGIN
    -- Vérifier disponibilité
    SELECT COUNT(*), max_players 
    INTO v_current_players, v_max_players
    FROM app.tournaments t
    LEFT JOIN app.tournament_registrations tr ON t.id = tr.tournament_id
    WHERE t.id = p_tournament_id AND t.status = 'registration'
    GROUP BY t.max_players;
    
    IF v_current_players >= v_max_players THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Tournament full'
        );
    END IF;
    
    -- Inscrire joueur
    INSERT INTO app.tournament_registrations (tournament_id, player_id)
    VALUES (p_tournament_id, auth.uid())
    RETURNING id INTO v_registration_id;
    
    -- Vérifier si tournoi plein pour démarrer
    IF v_current_players + 1 >= v_max_players THEN
        PERFORM app_generate_tournament_bracket(p_tournament_id);
    END IF;
    
    RETURN jsonb_build_object(
        'success', true,
        'registration_id', v_registration_id,
        'current_players', v_current_players + 1,
        'max_players', v_max_players
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### **3.2 Tournament Provider Flutter**
```dart
// lib/providers/tournament_provider.dart
class TournamentProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Tournament> _availableTournaments = [];
  List<Tournament> _myTournaments = [];
  List<TournamentMatch> _myMatches = [];
  
  List<Tournament> get availableTournaments => _availableTournaments;
  List<Tournament> get myTournaments => _myTournaments;
  List<TournamentMatch> get myMatches => _myMatches;
  
  Future<void> loadAvailableTournaments() async {
    try {
      final response = await _supabase
          .from('tournaments')
          .select()
          .eq('status', 'registration')
          .order('start_time', ascending: true);
      
      _availableTournaments = response
          .map((json) => Tournament.fromJson(json))
          .toList();
      notifyListeners();
    } catch (e) {
      print('Error loading tournaments: $e');
    }
  }
  
  Future<bool> registerTournament(String tournamentId) async {
    try {
      final response = await _supabase.functions.invoke(
        'app_register_tournament',
        params: {'p_tournament_id': tournamentId},
      );
      
      if (response['success'] == true) {
        await loadAvailableTournaments();
        await loadMyTournaments();
        return true;
      }
    } catch (e) {
      print('Error registering tournament: $e');
    }
    return false;
  }
  
  Future<void> loadMyTournaments() async {
    try {
      final response = await _supabase
          .from('tournaments')
          .select()
          .or('created_by.eq.${_supabase.auth.currentUser?.id},status.eq.active')
          .order('created_at', descending: true);
      
      _myTournaments = response
          .map((json) => Tournament.fromJson(json))
          .toList();
      
      await loadMyMatches();
      notifyListeners();
    } catch (e) {
      print('Error loading my tournaments: $e');
    }
  }
  
  Future<void> loadMyMatches() async {
    try {
      final response = await _supabase
          .from('tournament_matches')
          .select()
          .or('player1_id.eq.${_supabase.auth.currentUser?.id},player2_id.eq.${_supabase.auth.currentUser?.id}')
          .order('round', ascending: true);
      
      _myMatches = response
          .map((json) => TournamentMatch.fromJson(json))
          .toList();
      notifyListeners();
    } catch (e) {
      print('Error loading my matches: $e');
    }
  }
  
  Future<bool> createTournament({
    required String name,
    required int maxPlayers,
    String format = 'single_elimination',
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'app_create_tournament',
        params: {
          'p_name': name,
          'p_max_players': maxPlayers,
          'p_format': format,
        },
      );
      
      if (response['success'] == true) {
        await loadMyTournaments();
        return true;
      }
    } catch (e) {
      print('Error creating tournament: $e');
    }
    return false;
  }
}

// lib/models/tournament_models.dart
class Tournament {
  final String id;
  final String name;
  final int maxPlayers;
  final String format;
  final String status;
  final DateTime startTime;
  final String createdBy;
  
  Tournament({
    required this.id,
    required this.name,
    required this.maxPlayers,
    required this.format,
    required this.status,
    required this.startTime,
    required this.createdBy,
  });
  
  factory Tournament.fromJson(Map<String, dynamic> json) {
    return Tournament(
      id: json['id'],
      name: json['name'],
      maxPlayers: json['max_players'],
      format: json['format'],
      status: json['status'],
      startTime: DateTime.parse(json['start_time']),
      createdBy: json['created_by'],
    );
  }
}

class TournamentMatch {
  final String id;
  final String tournamentId;
  final int round;
  final int matchNumber;
  final String? player1Id;
  final String? player2Id;
  final String? winnerId;
  final String status;
  
  TournamentMatch({
    required this.id,
    required this.tournamentId,
    required this.round,
    required this.matchNumber,
    this.player1Id,
    this.player2Id,
    this.winnerId,
    required this.status,
  });
  
  factory TournamentMatch.fromJson(Map<String, dynamic> json) {
    return TournamentMatch(
      id: json['id'],
      tournamentId: json['tournament_id'],
      round: json['round'],
      matchNumber: json['match_number'],
      player1Id: json['player1_id'],
      player2Id: json['player2_id'],
      winnerId: json['winner_id'],
      status: json['status'],
    );
  }
}
```

#### **3.3 Tournament UI Components**
```dart
// lib/widgets/tournament_bracket_widget.dart
class TournamentBracketWidget extends StatelessWidget {
  final List<TournamentMatch> matches;
  
  const TournamentBracketWidget({required this.matches});
  
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _buildRounds(),
      ),
    );
  }
  
  List<Widget> _buildRounds() {
    final rounds = <int, List<TournamentMatch>>{};
    for (final match in matches) {
      rounds.putIfAbsent(match.round, () => []).add(match);
    }
    
    return rounds.entries.map((entry) {
      return _buildRoundColumn(entry.key, entry.value);
    }).toList();
  }
  
  Widget _buildRoundColumn(int round, List<TournamentMatch> matches) {
    return Container(
      width: 200,
      margin: EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          Text(
            'Round $round',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20),
          ...matches.map((match) => _matchCard(match)),
        ],
      ),
    );
  }
  
  Widget _matchCard(TournamentMatch match) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Column(
        children: [
          Text(
            'Match ${match.matchNumber}',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Player 1'),
              Text('Player 2'),
            ],
          ),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 60,
                height: 30,
                decoration: BoxDecoration(
                  color: match.winnerId == match.player1Id ? Colors.green : Colors.grey,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(child: Text('P1')),
              ),
              Container(
                width: 60,
                height: 30,
                decoration: BoxDecoration(
                  color: match.winnerId == match.player2Id ? Colors.green : Colors.grey,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(child: Text('P2')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

### **✅ Étape 4 : Vérification (1 jour)**
```bash
flutter analyze
flutter test
# Tester création tournoi
flutter run --debug
# Vérifier génération bracket
```

### **📊 Étape 5 : Bilan Phase 6**
- ✅ Système tournois implémenté
- ✅ Génération brackets automatique
- ✅ Mode async competitions
- ✅ UI tournaments responsive

---

## 🔗 **PHASE 7 : INTEGRATION & TESTING (2 jours)**

### **🎯 Objectifs**
- Intégrer tous les composants
- Tester navigation complète
- Valider performance
- Préparer production

### **🔍 Étape 1 : Audit Flutter (30 min)**
```bash
# Vérifier intégration complète
flutter analyze
flutter test
# Vérifier assets chargés
find assets/images/game/ -name "*.png" | wc -l
find assets/audio/game/ -name "*.mp3" | wc -l
```

### **🗄️ Étape 2 : Audit Supabase (30 min)**
```bash
cd .windsurf
python -c "
from supabase_auto_manager import SupabaseAutoManager
manager = SupabaseAutoManager()
# Vérifier toutes les tables créées
result = manager.execute_sql_auto('SELECT table_name FROM information_schema.tables WHERE table_schema = \'app\' ORDER BY table_name;')
print('Toutes les tables app.*:', len(result['data']))
# Vérifier tous les RPCs créés
result = manager.execute_sql_auto('SELECT routine_name FROM information_schema.routines WHERE routine_schema = \'app\' ORDER BY routine_name;')
print('Tous les RPCs app_*:', len(result['data']))
"
```

### **🛠️ Étape 3 : Intégration (1 jour)**

#### **3.1 Navigation Complète**
```dart
// lib/main.dart - Ajouter routes jeux
GoRouter router = GoRouter(
  routes: [
    // ... routes existantes
    GoRoute(
      path: '/games',
      builder: (context, state) => GamesMenuScreen(),
    ),
    GoRoute(
      path: '/games/:gameType',
      builder: (context, state) {
        final gameType = state.pathParameters['gameType']!;
        return GameWrapper(gameType: gameType);
      },
    ),
    GoRoute(
      path: '/multiplayer',
      builder: (context, state) => MultiplayerLobbyScreen(),
    ),
    GoRoute(
      path: '/tournaments',
      builder: (context, state) => TournamentListScreen(),
    ),
    GoRoute(
      path: '/leaderboard',
      builder: (context, state) => LeaderboardScreen(),
    ),
  ],
);

// lib/screens/games_menu_screen.dart
class GamesMenuScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Economia Challenge')),
      body: GridView.count(
        crossAxisCount: 2,
        padding: EdgeInsets.all(16),
        children: [
          _GameCard(
            title: 'Market Master',
            subtitle: 'Offre & Demande',
            icon: Icons.trending_up,
            onTap: () => context.go('/games/market_master'),
          ),
          _GameCard(
            title: 'Consumer Choice',
            subtitle: 'Théorie Consommateur',
            icon: Icons.person,
            onTap: () => context.go('/games/consumer_choice'),
          ),
          _GameCard(
            title: 'Firm Tycoon',
            subtitle: 'Gestion Entreprise',
            icon: Icons.business,
            onTap: () => context.go('/games/firm_tycoon'),
          ),
          _GameCard(
            title: 'Market Structures',
            subtitle: 'Structures Marché',
            icon: Icons.account_tree,
            onTap: () => context.go('/games/market_structures'),
          ),
          _GameCard(
            title: 'Multiplayer Battle',
            subtitle: '1v1 Temps Réel',
            icon: Icons.people,
            onTap: () => context.go('/multiplayer'),
          ),
          _GameCard(
            title: 'Tournaments',
            subtitle: 'Compétitions',
            icon: Icons.emoji_events,
            onTap: () => context.go('/tournaments'),
          ),
          _GameCard(
            title: 'Leaderboard',
            subtitle: 'Classements',
            icon: Icons.leaderboard,
            onTap: () => context.go('/leaderboard'),
          ),
          _GameCard(
            title: 'Practice',
            subtitle: 'Entraînement',
            icon: Icons.school,
            onTap: () => context.go('/games/practice'),
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  
  const _GameCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Theme.of(context).primaryColor),
              SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

#### **3.2 Provider Integration**
```dart
// lib/main.dart - Enregistrer tous les providers
MultiProvider(
  providers: [
    // ... providers existants
    ChangeNotifierProvider(create: (_) => GameProvider()),
    ChangeNotifierProvider(create: (_) => MultiplayerProvider()),
    ChangeNotifierProvider(create: (_) => CompetitiveProvider()),
    ChangeNotifierProvider(create: (_) => TournamentProvider()),
  ],
  child: Consumer<GameProvider>(
    builder: (context, gameProvider, child) {
      return MaterialApp.router(
        // ... configuration existante
        router: router,
      );
    },
  ),
)
```

### **✅ Étape 4 : Testing (1 jour)**
```bash
# Tests unitaires
flutter test test/games/
flutter test test/multiplayer/
flutter test test/competitive/

# Tests intégration
flutter test integration_test/

# Performance testing
flutter run --profile
# Mesurer FPS et mémoire pendant gameplay
```

### **📊 Étape 5 : Bilan Phase 7**
- ✅ Navigation complète intégrée
- ✅ Tous les providers connectés
- ✅ Tests passés
- ✅ Performance validée

---

## 🚀 **PHASE 8 : PRODUCTION DEPLOYMENT (2 jours)**

### **🎯 Objectifs**
- Préparer build production
- Déployer sur stores
- Monitorer performance
- Documenter lancement

### **🔍 Étape 1 : Audit Final (30 min)**
```bash
# Vérifier build production
flutter build apk --release
flutter build appbundle --release
# Vérifier taille APK
ls -la build/app/outputs/flutter-apk/release/
```

### **🗄️ Étape 2 : Audit Supabase (30 min)**
```bash
cd .windsurf
python -c "
from supabase_auto_manager import SupabaseAutoManager
manager = SupabaseAutoManager()
# Vérifier index performance
result = manager.execute_sql_auto('SELECT indexname, tablename FROM pg_indexes WHERE schemaname = \'app\' ORDER BY indexname;')
print('Indexes app.*:', result)
# Vérifier RLS policies actives
result = manager.execute_sql_execute('SELECT schemaname, tablename, policyname FROM pg_policies WHERE schemaname = \'app\' ORDER BY tablename, policyname;')
print('RLS policies actives:', result)
"
```

### **🛠️ Étape 3 : Production Prep (1 jour)**

#### **3.1 Performance Optimizations**
```dart
// lib/games/economics/performance_manager.dart
class PerformanceManager {
  static const int targetFPS = 60;
  static const int maxMemoryMB = 100;
  
  static void optimizeForDevice() {
    // Adapter qualité graphique selon device
    final deviceInfo = DeviceInfo();
    
    if (deviceInfo.isLowEnd) {
      // Réduire qualité pour vieux appareils
      Flame.images.prefix = 'low_res/';
      FlameAudio.audioCache.clearAll();
    }
  }
  
  static void monitorPerformance() {
    FlutterError.onError = (details, stack) {
      // Log erreurs performance
      print('Performance error: ${details.exception}');
    };
  }
}
```

#### **3.2 Analytics Integration**
```dart
// lib/services/analytics_service.dart
class AnalyticsService {
  static void trackGameStart(String gameType) {
    // Envoyer analytics
    // Firebase Analytics, Amplitude, etc.
  }
  
  static void trackGameComplete(String gameType, int score, double duration) {
    // Envoyer completion analytics
  }
  
  static void trackMultiplayerMatch(String result, int duration) {
    // Envoyer multiplayer analytics
  }
}
```

#### **3.3 Error Handling**
```dart
// lib/services/error_handler.dart
class GameErrorHandler {
  static void handleGameError(dynamic error, StackTrace stack) {
    // Log erreur détaillée
    print('Game Error: $error');
    print('Stack: $stack');
    
    // Envoyer à service monitoring
    // Sentry, Crashlytics, etc.
    
    // Afficher message utilisateur amical
    Get.snackbar(
      'Oups! Une erreur est survenue',
      'Nos équipes sont informées',
      backgroundColor: Colors.red,
    );
  }
}
```

### **✅ Étape 4 : Deployment (1 jour)**
```bash
# Build production
flutter build appbundle --release

# Upload to Google Play Console
# (Manuel via interface web)

# Build iOS
flutter build ios --release

# Upload to App Store Connect
# (Manuel via Xcode/App Store Connect)
```

### **📊 Étape 5 : Bilan Phase 8**
- ✅ Build production optimisé
- ✅ Analytics configurés
- ✅ Error handling robuste
- ✅ Prêt pour stores

---

## 🎯 **BILAN GÉNÉRAL DU PLAN**

### **📈 Timeline Totale**
- **Phase 1** : 2 jours (Infrastructure)
- **Phase 2** : 3 jours (Core Engine)
- **Phase 3** : 4 jours (Single Player)
- **Phase 4** : 3 jours (Multiplayer Foundation)
- **Phase 5** : 4 jours (Competitive Features)
- **Phase 6** : 3 jours (Tournament System)
- **Phase 7** : 2 jours (Integration & Testing)
- **Phase 8** : 2 jours (Production Deployment)

**Total : 23 jours (~4.5 semaines)**

### **✅ Garanties**
- **Non-blocking** : Chaque phase préserve application existante
- **Audit-driven** : Aucune supposition, tout vérifié
- **Progressif** : Validation à chaque étape
- **Production-ready** : Code optimisé et testé

### **🏆 Résultats Attendus**
- **4 jeux économiques** solo fonctionnels
- **Multiplayer temps réel** performant
- **Système tournois** complet
- **Leaderboards** intégrés
- **Application stable** en production

---

## 🚀 **PRÊT À COMMENCER ?**

Ce plan d'implémentation est **complet et détaillé**. Chaque phase peut être exécutée de manière autonome avec validation avant de passer à la suivante.

**Voulez-vous commencer la Phase 1 : Infrastructure de Base ?**

*Plan créé le 10 Mars 2026*
*Implementation Phases - Kellenge Project*
