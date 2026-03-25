import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/live_arena_service.dart';
import '../services/quiz_battle_service.dart';
import '../widgets/spectator_chat_widget.dart';
import '../widgets/support_bar_widget.dart';
import '../../themes/bloomberg_theme.dart';
import '../../config/feature_flags.dart';

/// Écran principal de la Live Arena
class LiveArenaScreen extends StatefulWidget {
  final String sessionId;
  final String? battleId;
  
  const LiveArenaScreen({
    Key? key,
    required this.sessionId,
    this.battleId,
  }) : super(key: key);
  
  @override
  State<LiveArenaScreen> createState() => _LiveArenaScreenState();
}

class _LiveArenaScreenState extends State<LiveArenaScreen> {
  LiveSession? _session;
  BattleSession? _battle;
  List<Spectator> _spectators = [];
  bool _isLoading = true;
  String? _currentUserId;
  
  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _loadArenaData();
  }
  
  Future<void> _loadArenaData() async {
    try {
      // Charger la session
      _session = await LiveArenaService.getSession(widget.sessionId);
      
      // Si battleId est fourni, charger le battle
      if (widget.battleId != null) {
        _battle = QuizBattleService.getBattleState(widget.battleId!);
      }
      
      // Charger les spectateurs
      _spectators = await LiveArenaService.getSpectators(widget.sessionId);
      
      // Rejoindre en tant que spectateur si pas déjà participant
      if (_currentUserId != null && !_isParticipant()) {
        await LiveArenaService.addSpectator(widget.sessionId, _currentUserId!);
        _spectators = await LiveArenaService.getSpectators(widget.sessionId);
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des données: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  bool _isParticipant() {
    if (_currentUserId == null || _session == null) return false;
    return _currentUserId == _session!.fighter1Id || _currentUserId == _session!.fighter2Id;
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: BloombergTheme.background,
        body: Center(
          child: CircularProgressIndicator(
            color: BloombergTheme.accent,
          ),
        ),
      );
    }
    
    if (_session == null) {
      return Scaffold(
        backgroundColor: BloombergTheme.background,
        body: Center(
          child: Text(
            'Session non trouvée',
            style: BloombergTheme.bodyStyle.copyWith(color: Colors.red),
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: BloombergTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildMainContent(),
            ),
            _buildSpectatorSection(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BloombergTheme.surface,
        border: Border(
          bottom: BorderSide(color: BloombergTheme.gridLines),
        ),
      ),
      child: Row(
        children: [
          // Badge LIVE
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '🔴 LIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 12),
          
          // Titre
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getArenaTitle(),
                  style: BloombergTheme.headerStyle.copyWith(
                    fontSize: 18,
                  ),
                ),
                Text(
                  _getSubtitle(),
                  style: BloombergTheme.captionStyle,
                ),
              ],
            ),
          ),
          
          // Spectateurs
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: BloombergTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BloombergTheme.gridLines),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.visibility,
                  color: BloombergTheme.textSecondary,
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  '${_spectators.length}',
                  style: BloombergTheme.bodyStyle.copyWith(
                    color: BloombergTheme.text,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMainContent() {
    if (_battle != null && _battle!.status == BattleStatus.active) {
      return _buildBattleContent();
    } else {
      return _buildWaitingContent();
    }
  }
  
  Widget _buildBattleContent() {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BloombergTheme.primaryBox,
      child: Column(
        children: [
          // Zone de combat
          Expanded(
            flex: 2,
            child: _buildBattleArena(),
          ),
          
          // Question actuelle
          Container(
            height: 200,
            margin: EdgeInsets.symmetric(vertical: 16),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: BloombergTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BloombergTheme.gridLines),
            ),
            child: _buildCurrentQuestion(),
          ),
          
          // Scores
          Container(
            height: 80,
            padding: EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: BloombergTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BloombergTheme.gridLines),
            ),
            child: _buildScoreBoard(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildWaitingContent() {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BloombergTheme.primaryBox,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hourglass_empty,
            color: BloombergTheme.textSecondary,
            size: 64,
          ),
          SizedBox(height: 16),
          Text(
            'En attente des joueurs...',
            style: BloombergTheme.subheaderStyle,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'La session commencera dès que les deux joueurs seront prêts',
            style: BloombergTheme.captionStyle,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32),
          
          if (_isParticipant())
            _buildStartButton()
          else
            _buildSpectatorMessage(),
        ],
      ),
    );
  }
  
  Widget _buildBattleArena() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1EA75C), Color(0xFF0D4F2C)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Stack(
        children: [
          // Cercles de combat
          _buildFighterCircles(),
          
          // Effets visuels
          _buildBattleEffects(),
          
          // Support bars
          _buildSupportBars(),
        ],
      ),
    );
  }
  
  Widget _buildFighterCircles() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Fighter 1
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.withOpacity(0.3),
            border: Border.all(color: Colors.blue, width: 3),
          ),
          child: Center(
            child: Text(
              'F1',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        
        // VS
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'VS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Round ${_battle?.currentRound ?? 1}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        
        // Fighter 2
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withOpacity(0.3),
            border: Border.all(color: Colors.red, width: 3),
          ),
          child: Center(
            child: Text(
              'F2',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildBattleEffects() {
    return Positioned.fill(
      child: Container(),
    );
  }
  
  Widget _buildSupportBars() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Row(
        children: [
          // Barre de support Fighter 1
          Expanded(
            child: SupportBarWidget(
              fighterId: _session!.fighter1Id,
              spectators: _spectators,
              side: 'left',
            ),
          ),
          
          SizedBox(width: 20),
          
          // Barre de support Fighter 2
          Expanded(
            child: SupportBarWidget(
              fighterId: _session!.fighter2Id,
              spectators: _spectators,
              side: 'right',
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCurrentQuestion() {
    final question = QuizBattleService.getCurrentQuestion(widget.battleId!);
    
    if (question == null) {
      return Center(
        child: Text(
          'Chargement de la question...',
          style: BloombergTheme.bodyStyle,
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Question ${_battle!.currentRound}',
          style: BloombergTheme.captionStyle.copyWith(
            color: BloombergTheme.textSecondary,
          ),
        ),
        SizedBox(height: 8),
        Text(
          question.question,
          style: BloombergTheme.subheaderStyle,
        ),
        SizedBox(height: 16),
        ...question.options.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          final isCorrect = option == question.correctAnswer;
          
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCorrect ? BloombergTheme.successBox.color.withOpacity(0.1) : BloombergTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCorrect ? BloombergTheme.successBox.color.withOpacity(0.3) : BloombergTheme.gridLines,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '${String.fromCharCode(65 + index)}.',
                    style: BloombergTheme.bodyStyle.copyWith(
                      color: isCorrect ? BloombergTheme.marketUp : BloombergTheme.text,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      option,
                      style: BloombergTheme.bodyStyle.copyWith(
                        color: isCorrect ? BloombergTheme.marketUp : BloombergTheme.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
  
  Widget _buildScoreBoard() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        // Fighter 1 Score
        Column(
          children: [
            Text(
              'Fighter 1',
              style: BloombergTheme.captionStyle,
            ),
            Text(
              '${_battle!.fighter1Score}',
              style: BloombergTheme.subheaderStyle.copyWith(
                color: Colors.blue,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        
        // VS
        Text(
          'VS',
          style: TextStyle(
            color: BloombergTheme.text,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        // Fighter 2 Score
        Column(
          children: [
            Text(
              'Fighter 2',
              style: BloombergTheme.captionStyle,
            ),
            Text(
              '${_battle!.fighter2Score}',
              style: BloombergTheme.subheaderStyle.copyWith(
                color: Colors.red,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildSpectatorSection() {
    return Container(
      height: 200,
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          _buildSpectatorHeader(),
          Expanded(
            child: SpectatorChatWidget(
              sessionId: widget.sessionId,
            ),
          ),
          _buildSpectatorControls(),
        ],
      ),
    );
  }
  
  Widget _buildSpectatorHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.people,
            color: Colors.white,
            size: 20,
          ),
          SizedBox(width: 8),
          Text(
            'Spectateurs (${_spectators.length})',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Spacer(),
          if (_battle != null && _battle!.status == BattleStatus.active)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'BATTLE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildSpectatorControls() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          // Support buttons
          if (_battle != null) ...[
            Expanded(
              child: ElevatedButton(
                onPressed: () => _supportFighter(_session!.fighter1Id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.withOpacity(0.3),
                  foregroundColor: Colors.blue,
                  side: BorderSide(color: Colors.blue),
                ),
                child: Text('Support F1'),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _supportFighter(_session!.fighter2Id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.3),
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red),
                ),
                child: Text('Support F2'),
              ),
            ),
            SizedBox(width: 8),
          ],
          
          // Chat input
          Expanded(
            flex: 2,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Envoyer un message...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              style: TextStyle(color: Colors.white),
              onSubmitted: (message) {
                if (message.isNotEmpty) {
                  _sendMessage(message);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStartButton() {
    return ElevatedButton.icon(
      onPressed: _startBattle,
      icon: Icon(Icons.play_arrow),
      label: 'Commencer le Battle',
      style: ElevatedButton.styleFrom(
        backgroundColor: BloombergTheme.accent,
        foregroundColor: BloombergTheme.background,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }
  
  Widget _buildSpectatorMessage() {
    return Column(
      children: [
        Icon(
          Icons.visibility,
          color: BloombergTheme.textSecondary,
          size: 48,
        ),
        SizedBox(height: 16),
        Text(
          'Vous êtes spectateur',
          style: BloombergTheme.subheaderStyle,
        ),
        SizedBox(height: 8),
        Text(
          'Encouragez les joueurs et participez au chat !',
          style: BloombergTheme.captionStyle,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  String _getArenaTitle() {
    if (_battle != null) {
      return 'Quiz Battle - ${_battle!.gameType.toUpperCase()}';
    }
    return 'Live Arena';
  }
  
  String _getSubtitle() {
    if (_session != null) {
      if (_session!.isPrivate) {
        return 'Session privée - Code: ${_session!.roomCode ?? 'N/A'}';
      } else {
        return 'Session publique - ${_session!.spectatorCount} spectateurs';
      }
    }
    return 'Session en attente';
  }
  
  Future<void> _startBattle() async {
    if (widget.battleId == null) return;
    
    try {
      await QuizBattleService.startBattle(widget.battleId!);
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du démarrage: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _supportFighter(String fighterId) async {
    if (widget.battleId == null) return;
    
    try {
      await LiveArenaService.supportFighter(
        sessionId: widget.sessionId,
        spectatorId: _currentUserId!,
        fighterId: fighterId,
      );
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du support: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _sendMessage(String message) async {
    if (widget.battleId == null) return;
    
    try {
      await QuizBattleService.sendBattleMessage(
        battleId: widget.battleId!,
        userId: _currentUserId!,
        message: message,
      );
    } catch (e) {
      print('Erreur lors de l\'envoi du message: $e');
    }
  }
}
