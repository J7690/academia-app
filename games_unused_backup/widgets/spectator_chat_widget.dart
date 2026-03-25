import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/live_arena_service.dart';
import '../../themes/bloomberg_theme.dart';

/// Widget pour le chat des spectateurs en temps réel
class SpectatorChatWidget extends StatefulWidget {
  final String sessionId;
  
  const SpectatorChatWidget({
    Key? key,
    required this.sessionId,
  }) : super(key: key);
  
  @override
  State<SpectatorChatWidget> createState() => _SpectatorChatWidgetState();
}

class _SpectatorChatWidgetState extends State<SpectatorChatWidget> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  String? _currentUserId;
  
  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _loadMessages();
    _subscribeToChat();
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    
    try {
      final result = await Supabase.instance.client
          .from('live_chat_messages')
          .select()
          .eq('session_id', widget.sessionId)
          .eq('is_deleted', false)
          .order('created_at', ascending: true)
          .limit(50);
      
      setState(() {
        _messages = List<Map<String, dynamic>>.from(result);
        _isLoading = false;
      });
      
      // Auto-scroll vers le bas
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('Erreur lors du chargement des messages: $e');
      setState(() => _isLoading = false);
    }
  }
  
  void _subscribeToChat() {
    Supabase.instance.client
        .channel('live_chat_${widget.sessionId}')
        .onPostgresChanges(
          event: PostgresChangeType.insert,
          schema: 'app',
          table: 'live_chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: widget.sessionId,
          ),
        )
        .listen((event) {
          if (event.newRecord != null) {
            _addMessage(event.newRecord);
          }
        });
  }
  
  void _addMessage(Map<String, dynamic> message) {
    setState(() {
      _messages.add(message);
    });
    
    // Auto-scroll vers le bas
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildMessageList(),
          _buildInputArea(),
        ],
      ),
    );
  }
  
  Widget _buildMessageList() {
    if (_isLoading) {
      return Expanded(
        child: Center(
          child: CircularProgressIndicator(
            color: BloombergTheme.accent,
          ),
        ),
      );
    }
    
    if (_messages.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                color: BloombergTheme.textSecondary,
                size: 48,
              ),
              SizedBox(height: 16),
              Text(
                'Soyez le premier à commenter !',
                style: BloombergTheme.captionStyle,
              ),
              SizedBox(height: 8),
              Text(
                'Les spectateurs peuvent encourager les joueurs',
                style: BloombergTheme.captionStyle.copyWith(
                  color: BloombergTheme.textTertiary,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Expanded(
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.all(8),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          return _buildMessageItem(message, index);
        },
      ),
    );
  }
  
  Widget _buildMessageItem(Map<String, dynamic> message, int index) {
    final isCurrentUser = message['user_id'] == _currentUserId;
    final messageType = message['message_type'] ?? 'text';
    
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentUser 
            ? BloombergTheme.accentBox.color.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isCurrentUser
            ? Border.all(color: BloombergTheme.accent.withOpacity(0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header du message
          Row(
            children: [
              Text(
                message['user_profile']?['full_name'] ?? 'Anonyme',
                style: BloombergTheme.bodyStyle.copyWith(
                  color: isCurrentUser ? BloombergTheme.accent : BloombergTheme.text,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              Text(
                _formatTime(message['created_at']),
                style: BloombergTheme.captionStyle.copyWith(
                  color: BloombergTheme.textTertiary,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          
          // Contenu du message
          if (messageType == 'text')
            Text(
            message['message'],
            style: BloombergTheme.bodyStyle.copyWith(
              color: BloombergTheme.text,
            ),
          )
          else if (messageType == 'reaction')
            _buildReactionMessage(message),
          else if (messageType == 'support')
            _buildSupportMessage(message),
          else if (messageType == 'battle_chat')
            _buildBattleMessage(message),
        ],
      ),
    );
  }
  
  Widget _buildReactionMessage(Map<String, dynamic> message) {
    final reaction = message['message'];
    final emojis = {
      '👍': 'Thumbs up',
      '❤️': 'Heart',
      '🔥': 'Fire',
      '👏': 'Clap',
      '😂': 'Laugh',
      '😮': 'Wow',
      '🎉': 'Party',
    };
    
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            emojis[reaction] ?? reaction,
            style: TextStyle(fontSize: 24),
          ),
          SizedBox(width: 8),
          Text(
            message['user_profile']?['full_name'] ?? 'Anonyme',
            style: BloombergTheme.captionStyle,
          ),
        ],
      ),
    );
  }
  
  Widget _buildSupportMessage(Map<String, dynamic> message) {
    final supportedFighter = message['supported_fighter'];
    final fighterName = supportedFighter == message['fighter1_id'] ? 'Fighter 1' : 'Fighter 2';
    
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.favorite,
            color: Colors.green,
            size: 20,
          ),
          SizedBox(width: 8),
          Text(
            '${message['user_profile']?['full_name'] ?? 'Anonyme'} supporte $fighterName !',
            style: BloombergTheme.captionStyle.copyWith(
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBattleMessage(Map<String, dynamic> message) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.emoji_events,
                color: Colors.orange,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'BATTLE CHAT',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            message['message'],
            style: BloombergTheme.bodyStyle.copyWith(
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          // Bouton de réaction
          PopupMenuButton<String>(
            icon: Icon(Icons.add_reaction),
            color: BloombergTheme.text,
            onSelected: (reaction) {
              _sendReaction(reaction);
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: '👍',
                child: Text('👍 Like'),
              ),
              PopupMenuItem<String>(
                value: '❤️',
                child: Text('❤️ Heart'),
              ),
              PopupMenuItem<String>(
                value: '🔥',
                child: Text('🔥 Fire'),
              ),
              PopupMenuItem<String>(
                value: '👏',
                child: Text('👏 Clap'),
              ),
              PopupMenuItem<String>(
                value: '😂',
                child: Text('😂️ Laugh'),
              ),
              PopupMenuItem<String>(
                value: '😮',
                child: Text('😮 Wow'),
              ),
              PopupMenuItem<String>(
                value: '🎉',
                child: Text('🎉 Party'),
              ),
            ],
          ),
          
          SizedBox(width: 12),
          
          // Champ de texte
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Écrivez un message...',
                hintStyle: TextStyle(
                  color: BloombergTheme.textTertiary,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              style: TextStyle(
                color: BloombergTheme.text,
              ),
              onSubmitted: (text) {
                if (text.isNotEmpty) {
                  _sendMessage(text);
                }
              },
            ),
          ),
          
          SizedBox(width: 12),
          
          // Bouton d'envoi
          IconButton(
            icon: Icon(Icons.send, color: BloombergTheme.text),
            onPressed: () {
              final text = _messageController.text.trim();
              if (text.isNotEmpty) {
                _sendMessage(text);
                _messageController.clear();
              }
            },
          ),
        ],
      ),
    );
  }
  
  Future<void> _sendMessage(String message) async {
    if (_currentUserId == null) return;
    
    try {
      await LiveArenaService.sendChatMessage(
        sessionId: widget.sessionId,
        userId: _currentUserId!,
        message: message,
        messageType: 'text',
      );
    } catch (e) {
      print('Erreur lors de l\'envoi du message: $e');
    }
  }
  
  Future<void> _sendReaction(String reaction) async {
    if (_currentUserId == null) return;
    
    try {
      await LiveArenaService.sendChatMessage(
        sessionId: widget.sessionId,
        userId: _currentUserId!,
        message: reaction,
        messageType: 'reaction',
      );
    } catch (e) {
      print('Erreur lors de l\'envoi de la réaction: $e');
    }
  }
  
  String _formatTime(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inMinutes < 1) {
        return 'à l\'instant';
      } else if (difference.inHours < 1) {
        return 'il y a ${difference.inMinutes} min';
      } else if (difference.inDays < 1) {
        return 'il y a ${difference.inHours}h';
      } else {
        return 'il y a ${difference.inDays}j';
      }
    } catch (e) {
      return 'récemment';
    }
  }
}

/// Widget pour les barres de support
class SupportBarWidget extends StatelessWidget {
  final String fighterId;
  final List<Spectator> spectators;
  final String side;
  
  const SupportBarWidget({
    Key? key,
    required this.fighterId,
    required this.spectators,
    required this.side,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // Compter les supporters pour ce fighter
    final supporters = spectators
        .where((s) => s.supportedFighter == fighterId)
        .length;
    
    // Calculer le pourcentage de support
    final totalSpectators = spectators.length;
    final supportPercentage = totalSpectators > 0 
        ? (supporters / totalSpectators * 100).round()
        : 0;
    
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: side == 'left' 
            ? Colors.blue.withOpacity(0.2)
            : Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // Barre de support
          FractionallySizedBox(
            widthFactor: supportPercentage / 100,
            child: Container(
              decoration: BoxDecoration(
                color: side == 'left' 
                    ? Colors.blue 
                    : Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          
          // Informations
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  side == 'left' 
                      ? Icons.favorite_border 
                      : Icons.favorite,
                  color: side == 'left' 
                      ? Colors.blue 
                      : Colors.red,
                  size: 16,
                ),
                SizedBox(width: 8),
                Text(
                  '$supporters%',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
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
}
