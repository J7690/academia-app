import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../games/services/game_live_service.dart';
import '../../services/academia_room_options.dart';
import '../../services/livekit_token_service.dart';
import 'challenge_live_duo_screen.dart';

/// TikTok-style live broadcast screen for challenges.
/// - Host: publishes video + audio, sees chat + reactions + viewer count
/// - Viewer: subscribes only, can chat + send reactions
class ChallengeLiveScreen extends StatefulWidget {
  final String? sessionId;
  final bool isHost;

  const ChallengeLiveScreen({
    super.key,
    this.sessionId,
    this.isHost = false,
  });

  @override
  State<ChallengeLiveScreen> createState() => _ChallengeLiveScreenState();
}

class _ChatMsg {
  final String sender;
  final String text;
  final DateTime ts;
  _ChatMsg({required this.sender, required this.text, required this.ts});
}

class _FloatingEmoji {
  final String emoji;
  final double startX;
  final DateTime createdAt;
  _FloatingEmoji({required this.emoji, required this.startX, required this.createdAt});
}

class _ChallengeLiveScreenState extends State<ChallengeLiveScreen> {
  Room? _room;
  bool _connecting = true;
  String? _error;
  String _displayName = '';
  bool _isHost = false;
  bool _micEnabled = true;
  bool _cameraEnabled = true;
  String? _sessionId;

  EventsListener<RoomEvent>? _roomListener;
  final List<_ChatMsg> _chatMessages = [];
  final List<_FloatingEmoji> _floatingEmojis = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  int get _viewerCount {
    final room = _room;
    if (room == null) return 0;
    return room.remoteParticipants.length + 1;
  }

  @override
  void initState() {
    super.initState();
    _isHost = widget.isHost;
    _connect();
  }

  Future<void> _connect() async {
    setState(() { _connecting = true; _error = null; });

    try {
      String? sessionId = _sessionId ?? widget.sessionId;

      // If no sessionId provided, we are the HOST → create a live session
      if (sessionId == null || sessionId.isEmpty) {
        if (!widget.isHost) {
          setState(() { _connecting = false; _error = 'ID de session manquant.'; });
          return;
        }
        // Create a new game live session via RPC
        sessionId = await GameLiveService.startLive(
          gameType: 'challenge_live',
          mode: 'solo',
        );
        if (sessionId == null || sessionId.isEmpty) {
          setState(() {
            _connecting = false;
            _error = 'Impossible de créer la session live. Réessayez.';
          });
          return;
        }
        _sessionId = sessionId;
      }

      final tokenData = await LivekitTokenService.getTokenForSession(sessionId);
      if (!mounted) return;

      final token = tokenData['token'] as String?;
      final url = tokenData['url'] as String?;
      if (token == null || token.isEmpty || url == null || url.isEmpty) {
        setState(() { _connecting = false; _error = 'Token LiveKit manquant.'; });
        return;
      }

      _displayName = (tokenData['display_name'] ?? '').toString();
      _isHost = tokenData['is_host'] == true || widget.isHost;

      final room = Room(roomOptions: AcademiaRoomOptions.broadcast);
      room.addListener(_onRoomChanged);

      _roomListener = room.createListener();
      _roomListener!.on<DataReceivedEvent>(_onDataReceived);

      await room.connect(url, token);
      if (!mounted) { room.dispose(); return; }

      if (_isHost) {
        await room.localParticipant?.setCameraEnabled(true);
        await room.localParticipant?.setMicrophoneEnabled(true);
      }

      setState(() { _room = room; _connecting = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _connecting = false; _error = 'Connexion impossible.\n$e'; });
    }
  }

  void _onRoomChanged() {
    if (mounted) setState(() {});
  }

  void _onDataReceived(DataReceivedEvent event) {
    if (!mounted) return;
    try {
      final map = jsonDecode(utf8.decode(event.data)) as Map<String, dynamic>;
      if (event.topic == 'chat') {
        setState(() {
          _chatMessages.add(_ChatMsg(
            sender: (map['sender'] ?? '').toString(),
            text: (map['text'] ?? '').toString(),
            ts: DateTime.now(),
          ));
        });
        _scrollChat();
      } else if (event.topic == 'reaction') {
        final type = (map['type'] ?? '').toString();
        if (type == 'emoji') {
          _addFloatingEmoji((map['emoji'] ?? '❤️').toString());
        }
      } else if (event.topic == 'duo_invite') {
        final from = (map['from'] ?? '').toString();
        _showDuoInviteDialog(from);
      }
    } catch (_) {}
  }

  void _showDuoInviteDialog(String fromName) {
    if (!mounted) return;
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.people, color: Color(0xFF6366F1), size: 24),
            SizedBox(width: 8),
            Text('Invitation Duo', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Text(
          '$fromName vous invite à rejoindre un Live Duo !',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Refuser', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            child: const Text('Accepter'),
          ),
        ],
      ),
    ).then((accepted) {
      if (accepted == true && mounted && widget.sessionId != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ChallengeLiveDuoScreen(
              sessionId: widget.sessionId!,
              isPublisher: true,
            ),
          ),
        );
      }
    });
  }

  void _inviteToDuo() {
    if (_room == null || !_isHost) return;
    final senderName = _displayName.isNotEmpty ? _displayName : (_room!.localParticipant?.identity ?? 'Hôte');
    final payload = jsonEncode({'from': senderName, 'type': 'duo_invite'});
    try {
      _room!.localParticipant?.publishData(utf8.encode(payload), reliable: true, topic: 'duo_invite');
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation Duo envoyée à tous les viewers.')),
      );
    }
    // Host also navigates to duo screen
    if (widget.sessionId != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChallengeLiveDuoScreen(
            sessionId: widget.sessionId!,
            isPublisher: true,
          ),
        ),
      );
    }
  }

  void _addFloatingEmoji(String emoji) {
    final rng = Random();
    final fe = _FloatingEmoji(emoji: emoji, startX: 0.5 + rng.nextDouble() * 0.4, createdAt: DateTime.now());
    setState(() => _floatingEmojis.add(fe));
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _floatingEmojis.remove(fe));
    });
  }

  void _sendChat() {
    final text = _chatController.text.trim();
    if (text.isEmpty || _room == null) return;
    final senderName = _displayName.isNotEmpty ? _displayName : (_room!.localParticipant?.identity ?? 'Moi');
    final payload = jsonEncode({'sender': senderName, 'text': text});
    try {
      _room!.localParticipant?.publishData(utf8.encode(payload), reliable: true, topic: 'chat');
    } catch (_) {}
    setState(() {
      _chatMessages.add(_ChatMsg(sender: senderName, text: text, ts: DateTime.now()));
    });
    _chatController.clear();
    _scrollChat();
  }

  void _sendReaction(String emoji) {
    if (_room == null) return;
    final senderName = _displayName.isNotEmpty ? _displayName : (_room!.localParticipant?.identity ?? 'Moi');
    final payload = jsonEncode({'sender': senderName, 'type': 'emoji', 'emoji': emoji});
    try {
      _room!.localParticipant?.publishData(utf8.encode(payload), reliable: true, topic: 'reaction');
    } catch (_) {}
    _addFloatingEmoji(emoji);
  }

  void _scrollChat() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _leave() async {
    // End the live session if we are the host
    if (_isHost && _sessionId != null) {
      await GameLiveService.endLive();
    }
    _roomListener?.dispose();
    _room?.removeListener(_onRoomChanged);
    _room?.dispose();
    _room = null;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    // Cancel live if host and still live on dispose
    if (_isHost && _sessionId != null && GameLiveService.isLive) {
      GameLiveService.cancelLive();
    }
    _roomListener?.dispose();
    _room?.removeListener(_onRoomChanged);
    _room?.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_connecting) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _connect, child: const Text('Réessayer')),
                const SizedBox(height: 8),
                TextButton(onPressed: _leave, child: const Text('Retour', style: TextStyle(color: Colors.white70))),
              ],
            ),
          ),
        ),
      );
    }

    final room = _room;
    if (room == null) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: Text('Room non disponible.', style: TextStyle(color: Colors.white))));
    }

    // Find the host's tracks: screen share (gameplay) + camera (face, optional)
    VideoTrack? gameplayTrack; // Screen share = jeu en plein écran
    VideoTrack? faceCamTrack;  // Caméra frontale = PiP optionnel
    String? hostIdentity;
    final allParticipants = <Participant>[
      if (room.localParticipant != null) room.localParticipant!,
      ...room.remoteParticipants.values,
    ];
    for (final p in allParticipants) {
      for (final pub in p.videoTrackPublications) {
        if (pub.source == TrackSource.screenShareVideo && pub.track is VideoTrack) {
          gameplayTrack = pub.track as VideoTrack;
          hostIdentity = p.identity;
        } else if (pub.source == TrackSource.camera && pub.track is VideoTrack) {
          faceCamTrack = pub.track as VideoTrack;
          hostIdentity ??= p.identity;
        }
      }
    }
    // Fallback: si pas de screen share, utiliser la caméra comme vidéo principale
    final mainVideo = gameplayTrack ?? faceCamTrack;
    final pipVideo = gameplayTrack != null ? faceCamTrack : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen: gameplay (screen share) ou caméra en fallback
          Positioned.fill(
            child: mainVideo != null
                ? VideoTrackRenderer(mainVideo)
                : const Center(child: Text('En attente du gameplay...', style: TextStyle(color: Colors.white70, fontSize: 16))),
          ),

          // PiP: caméra frontale du joueur (petit cercle) ou avatar profil
          Positioned(
            right: 12,
            top: MediaQuery.of(context).padding.top + 56,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                color: Colors.black54,
              ),
              clipBehavior: Clip.antiAlias,
              child: pipVideo != null
                  ? VideoTrackRenderer(pipVideo)
                  : const Center(
                      child: Icon(Icons.person, color: Colors.white54, size: 32),
                    ),
            ),
          ),

          // Top bar: LIVE badge + viewer count + close
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: Colors.white, size: 8),
                      SizedBox(width: 4),
                      Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.remove_red_eye, color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text('$_viewerCount', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
                const Spacer(),
                if (_isHost)
                  IconButton(
                    onPressed: _inviteToDuo,
                    icon: const Icon(Icons.people, color: Color(0xFF6366F1), size: 22),
                    tooltip: 'Inviter en Duo',
                  ),
                if (_isHost) ...[
                  IconButton(
                    onPressed: () async {
                      _micEnabled = !_micEnabled;
                      await _room?.localParticipant?.setMicrophoneEnabled(_micEnabled);
                      if (mounted) setState(() {});
                    },
                    icon: Icon(_micEnabled ? Icons.mic : Icons.mic_off, color: _micEnabled ? Colors.white : Colors.redAccent, size: 22),
                  ),
                  IconButton(
                    onPressed: () async {
                      _cameraEnabled = !_cameraEnabled;
                      await _room?.localParticipant?.setCameraEnabled(_cameraEnabled);
                      if (mounted) setState(() {});
                    },
                    icon: Icon(_cameraEnabled ? Icons.videocam : Icons.videocam_off, color: _cameraEnabled ? Colors.white : Colors.redAccent, size: 22),
                  ),
                ],
                IconButton(
                  onPressed: _leave,
                  icon: const Icon(Icons.close, color: Colors.white, size: 26),
                ),
              ],
            ),
          ),

          // Floating emoji reactions (right side, rising)
          ..._floatingEmojis.map((fe) {
            final age = DateTime.now().difference(fe.createdAt).inMilliseconds;
            final progress = (age / 3000).clamp(0.0, 1.0);
            final yOffset = progress * MediaQuery.of(context).size.height * 0.5;
            final opacity = (1.0 - progress).clamp(0.0, 1.0);
            return Positioned(
              right: fe.startX * 60,
              bottom: 160 + yOffset,
              child: Opacity(opacity: opacity, child: Text(fe.emoji, style: const TextStyle(fontSize: 32))),
            );
          }),

          // Bottom: chat overlay + input + reactions
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Chat messages (scrollable, transparent bg)
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      controller: _chatScrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _chatMessages.length,
                      itemBuilder: (ctx, i) {
                        final msg = _chatMessages[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Flexible(
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${msg.sender}  ',
                                        style: const TextStyle(color: Color(0xFF1EA75C), fontWeight: FontWeight.w700, fontSize: 13),
                                      ),
                                      TextSpan(
                                        text: msg.text,
                                        style: const TextStyle(color: Colors.white, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Input row + quick reactions
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendChat(),
                            decoration: InputDecoration(
                              hintText: 'Envoyer un message...',
                              hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                              filled: true,
                              fillColor: Colors.white12,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Quick reaction buttons
                        ...<String>['❤️', '🔥', '👏', '😂'].map((e) => GestureDetector(
                              onTap: () => _sendReaction(e),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: Text(e, style: const TextStyle(fontSize: 24)),
                              ),
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
