import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/kellenge_game_engine.dart';
import '../models/game_session.dart';
import '../services/matchmaking_service.dart';
import '../services/realtime_service.dart';
import '../utils/game_constants.dart';
import '../providers/game_provider.dart';

/// Écran principal du multiplayer Kellenge
class MultiplayerHubScreen extends StatefulWidget {
  const MultiplayerHubScreen({super.key});

  @override
  State<MultiplayerHubScreen> createState() => _MultiplayerHubScreenState();
}

class _MultiplayerHubScreenState extends State<MultiplayerHubScreen> {
  final MatchmakingService _matchmakingService = MatchmakingService.instance;
  final RealtimeService _realtimeService = RealtimeService.instance;
  
  bool _isMatchmaking = false;
  String? _selectedGameType;
  List<PublicSession> _publicSessions = [];
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadPublicSessions();
  }
  
  @override
  void dispose() {
    _realtimeService.dispose();
    super.dispose();
  }
  
  Future<void> _loadPublicSessions() async {
    setState(() => _isLoading = true);
    
    final sessions = await _matchmakingService.listPublicSessions(
      gameType: _selectedGameType,
      limit: 20,
    );
    
    setState(() {
      _publicSessions = sessions;
      _isLoading = false;
    });
  }
  
  Future<void> _startMatchmaking(String gameType) async {
    setState(() => _isMatchmaking = true);
    
    final result = await _matchmakingService.startMatchmaking(
      gameType: gameType,
      eloRange: 200,
      timeout: const Duration(minutes: 3),
    );
    
    setState(() => _isMatchmaking = false);
    
    if (result.success && result.sessionId != null) {
      _navigateToGame(result.sessionId!, gameType);
    } else {
      _showError(result.message);
    }
  }
  
  Future<void> _createPrivateSession(String gameType) async {
    final result = await _matchmakingService.createPrivateSession(
      gameType: gameType,
      maxPlayers: 2,
    );
    
    if (result.success && result.sessionId != null) {
      _navigateToGame(result.sessionId!, gameType);
    } else {
      _showError(result.message);
    }
  }
  
  Future<void> _joinSessionByCode(String roomCode) async {
    final result = await _matchmakingService.joinSessionByCode(roomCode);
    
    if (result.success && result.sessionId != null) {
      _navigateToGame(result.sessionId!, '');
    } else {
      _showError(result.message);
    }
  }
  
  void _navigateToGame(String sessionId, String gameType) {
    // Créer une session de jeu pour le multiplayer
    final gameSession = GameSession(
      id: sessionId,
      playerId: 'current_user',
      gameType: gameType.isNotEmpty ? gameType : GameConstants.marketMaster,
      duration: GameConstants.defaultGameDuration,
      createdAt: DateTime.now(),
    );
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiplayerGameScreen(
          session: gameSession,
          multiplayerSessionId: sessionId,
        ),
      ),
    );
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  void _showRoomCodeDialog() {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Game'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Room Code',
            hintText: 'Enter 6-character code',
          ),
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
                Navigator.pop(context);
                _joinSessionByCode(controller.text.toUpperCase());
              },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multiplayer Games'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.code),
            onPressed: _showRoomCodeDialog,
            tooltip: 'Join by Code',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header avec sélection de jeu
          _buildGameTypeSelector(),
          
          // Options de matchmaking
          _buildMatchmakingOptions(),
          
          // Sessions publiques
          Expanded(
            child: _buildPublicSessionsList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGameTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Game Type',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: GameConstants.gameTypes.map((gameType) {
                final isSelected = _selectedGameType == gameType;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(gameType),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedGameType = selected ? gameType : null;
                        _loadPublicSessions();
                      });
                    },
                    backgroundColor: isSelected ? Colors.blue : Colors.grey[300],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMatchmakingOptions() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_isMatchmaking) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 16),
                  Text(
                    'Searching for opponent...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: () {
                      // TODO: Cancel matchmaking
                      setState(() => _isMatchmaking = false);
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectedGameType != null
                        ? () => _startMatchmaking(_selectedGameType!)
                        : null,
                    icon: const Icon(Icons.search),
                    label: 'Quick Match',
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectedGameType != null
                        ? () => _createPrivateSession(_selectedGameType!)
                        : null,
                    icon: const Icon(Icons.lock),
                    label: 'Private Room',
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildPublicSessionsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_publicSessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No public sessions available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a private room or start quick match',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: _publicSessions.length,
      itemBuilder: (context, index) {
        final session = _publicSessions[index];
        return _PublicSessionCard(session: session);
      },
    );
  }
  
  Widget _PublicSessionCard({required PublicSession session}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  session.gameType,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: session.canJoin ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    session.roomCode,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                Text(
                  '${session.currentPlayers}/${session.maxPlayers} players',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                Text(
                  session.hostName,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (session.eloMin > 0 || session.eloMax < 3000) ...[
              Row(
                children: [
                  Icon(Icons.trending_up, size: 16, color: Colors.grey[600]),
                  Text(
                    'ELO: ${session.eloMin}-${session.eloMax}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Text(
                  'Created ${_formatTime(session.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: session.canJoin
                      ? () => _joinSessionByCode(session.roomCode)
                      : null,
                  child: Text(session.canJoin ? 'Join' : 'Full'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: session.canJoin ? Colors.blue : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

/// Écran de jeu multiplayer
class MultiplayerGameScreen extends StatefulWidget {
  final GameSession session;
  final String multiplayerSessionId;
  
  const MultiplayerGameScreen({
    super.key,
    required this.session,
    required this.multiplayerSessionId,
  });

  @override
  State<MultiplayerGameScreen> createState() => _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState extends State<MultiplayerGameScreen> {
  final RealtimeService _realtimeService = RealtimeService.instance;
  final MatchmakingService _matchmakingService = MatchmakingService.instance;
  
  late GameSession? _multiplayerSession;
  List<SessionParticipant> _participants = [];
  List<ChatMessage> _chatMessages = [];
  
  bool _isGameActive = false;
  bool _showChat = false;
  final TextEditingController _chatController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _initializeGame();
    _subscribeToRealtimeUpdates();
  }
  
  @override
  void dispose() {
    _realtimeService.dispose();
    super.dispose();
  }
  
  Future<void> _initializeGame() async {
    // Obtenir les détails de la session multiplayer
    _multiplayerSession = await _matchmakingService.getSessionDetails(widget.multiplayerSessionId);
    
    setState(() {});
  }
  
  void _subscribeToRealtimeUpdates() {
    // S'abonner aux messages de chat
    _realtimeService.subscribeToChat(widget.multiplayerSessionId, (messages) {
      setState(() {
        _chatMessages = messages;
      });
    });
    
    // S'abonner aux participants
    _realtimeService.subscribeToParticipants(widget.multiplayerSessionId, (participants) {
      setState(() {
        _participants = participants;
      });
    });
    
    // S'abonner au statut de la session
    _realtimeService.subscribeToSessionStatus(widget.multiplayerSessionId, (session) {
      setState(() {
        _multiplayerSession = session;
        if (session.isActive && !_isGameActive) {
          _startGame();
        }
      });
    });
  }
  
  Future<void> _startGame() async {
    final success = await _matchmakingService.startSession(widget.multiplayerSessionId);
    
    if (success) {
      setState(() => _isGameActive = true);
      
      _sendGameEvent('Game started!');
    }
  }
  
  void _sendGameEvent(String event) {
    _realtimeService.sendGameEvent(
      sessionId: widget.multiplayerSessionId,
      eventDescription: event,
    );
  }
  
  void _sendMessage() {
    if (_chatController.text.trim().isEmpty) return;
    
    _realtimeService.sendChatMessage(
      sessionId: widget.multiplayerSessionId,
      message: _chatController.text.trim(),
    );
    
    _chatController.clear();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_multiplayerSession?.gameType ?? 'Multiplayer Game'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_showChat ? Icons.chat : Icons.chat_outlined),
            onPressed: () => setState(() => _showChat = !_showChat),
          ),
        ],
      ),
      body: Row(
        children: [
            // Zone de jeu
            Expanded(
              flex: _showChat ? 2 : 3,
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'Game Area\n(Multiplayer Game Engine)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
            
            // Panneau latéral (chat, participants)
            if (_showChat) ...[
              Expanded(
                flex: 1,
                child: Container(
                  margin: const EdgeInsets.only(right: 16, top: 16, bottom: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      // Participants
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Players',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._participants.map((participant) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    participant.isReady ? Icons.check_circle : Icons.circle_outlined,
                                    size: 16,
                                    color: participant.isReady ? Colors.green : Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      participant.isCurrentUser 
                                          ? 'You (${participant.statusDisplay})'
                                          : 'Player (${participant.statusDisplay})',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            )).toList(),
                          ],
                        ),
                      ),
                      
                      // Chat
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              Expanded(
                                child: ListView.builder(
                                  itemCount: _chatMessages.length,
                                  itemBuilder: (context, index) {
                                    final message = _chatMessages[index];
                                    return _buildChatMessage(message);
                                  },
                                ),
                              ),
                              
                              // Input de chat
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  border: Border(top: BorderSide(color: Colors.grey[300]),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _chatController,
                                        decoration: const InputDecoration(
                                          hintText: 'Type a message...',
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.send),
                                      onPressed: _sendMessage,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildChatMessage(ChatMessage message) {
    final isMe = message.isFromCurrentUser;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              child: Text(
                message.displayName.isNotEmpty ? message.displayName[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe ? Colors.blue[500] : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.isSystem) ...[
                    Text(
                      message.message,
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ] else if (message.isEmoji) ...[
                    Text(
                      message.message,
                      style: const TextStyle(
                        fontSize: 24,
                      ),
                    ),
                  ] else ...[
                    Text(
                      message.message,
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  Text(
                    message.formattedTime,
                    style: TextStyle(
                      color: isMe ? Colors.white70 : Colors.black54,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              child: Text(
                message.displayName.isNotEmpty ? message.displayName[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
