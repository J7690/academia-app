import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../services/livekit_token_service.dart';

/// TikTok-style Duo Live: 2 streamers in split-screen + N viewers with chat & reactions.
class ChallengeLiveDuoScreen extends StatefulWidget {
  final String sessionId;
  final bool isPublisher;

  const ChallengeLiveDuoScreen({
    super.key,
    required this.sessionId,
    this.isPublisher = false,
  });

  @override
  State<ChallengeLiveDuoScreen> createState() => _ChallengeLiveDuoScreenState();
}

class _DuoChatMsg {
  final String sender;
  final String text;
  _DuoChatMsg({required this.sender, required this.text});
}

class _DuoFloatingEmoji {
  final String emoji;
  final double startX;
  final DateTime createdAt;
  _DuoFloatingEmoji({required this.emoji, required this.startX, required this.createdAt});
}

class _ChallengeLiveDuoScreenState extends State<ChallengeLiveDuoScreen> {
  Room? _room;
  bool _connecting = true;
  String? _error;
  String _displayName = '';
  bool _isPublisher = false;
  bool _micEnabled = true;
  bool _cameraEnabled = true;

  EventsListener<RoomEvent>? _roomListener;
  final List<_DuoChatMsg> _chatMessages = [];
  final List<_DuoFloatingEmoji> _floatingEmojis = [];
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
    _isPublisher = widget.isPublisher;
    _connect();
  }

  Future<void> _connect() async {
    setState(() { _connecting = true; _error = null; });
    try {
      final tokenData = await LivekitTokenService.getTokenForSession(widget.sessionId);
      if (!mounted) return;

      final token = tokenData['token'] as String?;
      final url = tokenData['url'] as String?;
      if (token == null || token.isEmpty || url == null || url.isEmpty) {
        setState(() { _connecting = false; _error = 'Token LiveKit manquant.'; });
        return;
      }

      _displayName = (tokenData['display_name'] ?? '').toString();
      if (tokenData['is_host'] == true) _isPublisher = true;

      final room = Room();
      room.addListener(_onRoomChanged);
      _roomListener = room.createListener();
      _roomListener!.on<DataReceivedEvent>(_onDataReceived);

      await room.connect(url, token);
      if (!mounted) { room.dispose(); return; }

      if (_isPublisher) {
        await room.localParticipant?.setCameraEnabled(true);
        await room.localParticipant?.setMicrophoneEnabled(true);
      }

      setState(() { _room = room; _connecting = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _connecting = false; _error = 'Connexion impossible.\n$e'; });
    }
  }

  void _onRoomChanged() { if (mounted) setState(() {}); }

  void _onDataReceived(DataReceivedEvent event) {
    if (!mounted) return;
    try {
      final map = jsonDecode(utf8.decode(event.data)) as Map<String, dynamic>;
      if (event.topic == 'chat') {
        setState(() {
          _chatMessages.add(_DuoChatMsg(
            sender: (map['sender'] ?? '').toString(),
            text: (map['text'] ?? '').toString(),
          ));
        });
        _scrollChat();
      } else if (event.topic == 'reaction') {
        if ((map['type'] ?? '') == 'emoji') {
          _addFloatingEmoji((map['emoji'] ?? '❤️').toString());
        }
      }
    } catch (_) {}
  }

  void _addFloatingEmoji(String emoji) {
    final rng = Random();
    final fe = _DuoFloatingEmoji(emoji: emoji, startX: 0.5 + rng.nextDouble() * 0.4, createdAt: DateTime.now());
    setState(() => _floatingEmojis.add(fe));
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _floatingEmojis.remove(fe));
    });
  }

  void _sendChat() {
    final text = _chatController.text.trim();
    if (text.isEmpty || _room == null) return;
    final sender = _displayName.isNotEmpty ? _displayName : (_room!.localParticipant?.identity ?? 'Moi');
    try {
      _room!.localParticipant?.publishData(
        utf8.encode(jsonEncode({'sender': sender, 'text': text})),
        reliable: true, topic: 'chat',
      );
    } catch (_) {}
    setState(() => _chatMessages.add(_DuoChatMsg(sender: sender, text: text)));
    _chatController.clear();
    _scrollChat();
  }

  void _sendReaction(String emoji) {
    if (_room == null) return;
    final sender = _displayName.isNotEmpty ? _displayName : (_room!.localParticipant?.identity ?? 'Moi');
    try {
      _room!.localParticipant?.publishData(
        utf8.encode(jsonEncode({'sender': sender, 'type': 'emoji', 'emoji': emoji})),
        reliable: true, topic: 'reaction',
      );
    } catch (_) {}
    _addFloatingEmoji(emoji);
  }

  void _scrollChat() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150), curve: Curves.easeOut,
        );
      }
    });
  }

  void _leave() {
    _roomListener?.dispose();
    _room?.removeListener(_onRoomChanged);
    _room?.dispose();
    _room = null;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _roomListener?.dispose();
    _room?.removeListener(_onRoomChanged);
    _room?.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  /// Collect the 2 publishers' video tracks (camera only, skip screenshare).
  List<_DuoVideoSlot> _collectPublisherTracks() {
    final room = _room;
    if (room == null) return [];
    final slots = <_DuoVideoSlot>[];

    final allParticipants = <Participant>[
      if (room.localParticipant != null) room.localParticipant!,
      ...room.remoteParticipants.values,
    ];

    for (final p in allParticipants) {
      VideoTrack? cam;
      for (final pub in p.videoTrackPublications) {
        if (pub.source != TrackSource.screenShareVideo && pub.track is VideoTrack) {
          cam = pub.track as VideoTrack;
          break;
        }
      }
      // Only include participants who are publishing video (= publishers)
      if (cam != null) {
        slots.add(_DuoVideoSlot(
          identity: p.identity,
          isLocal: p is LocalParticipant,
          track: cam,
        ));
      }
      if (slots.length >= 2) break;
    }
    return slots;
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
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _connect, child: const Text('Réessayer')),
              const SizedBox(height: 8),
              TextButton(onPressed: _leave, child: const Text('Retour', style: TextStyle(color: Colors.white70))),
            ]),
          ),
        ),
      );
    }

    final room = _room;
    if (room == null) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: Text('Room non disponible.', style: TextStyle(color: Colors.white))));
    }

    final slots = _collectPublisherTracks();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Split-screen: 2 videos stacked vertically
          Column(
            children: [
              // Top half: publisher 1
              Expanded(
                child: slots.isNotEmpty
                    ? _buildVideoSlot(slots[0])
                    : const Center(child: Text('En attente du streamer 1...', style: TextStyle(color: Colors.white54, fontSize: 14))),
              ),
              // Thin divider
              Container(height: 2, color: Colors.white24),
              // Bottom half: publisher 2
              Expanded(
                child: slots.length >= 2
                    ? _buildVideoSlot(slots[1])
                    : Container(
                        color: const Color(0xFF111111),
                        child: const Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.person_add, color: Colors.white38, size: 36),
                            SizedBox(height: 8),
                            Text('En attente du 2ème streamer...', style: TextStyle(color: Colors.white54, fontSize: 13)),
                          ]),
                        ),
                      ),
              ),
            ],
          ),

          // Top bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12, right: 12,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF6366F1), borderRadius: BorderRadius.circular(6)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.people, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('DUO', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                  ]),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.remove_red_eye, color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Text('$_viewerCount', style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ]),
                ),
                const Spacer(),
                if (_isPublisher) ...[
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
                IconButton(onPressed: _leave, icon: const Icon(Icons.close, color: Colors.white, size: 26)),
              ],
            ),
          ),

          // Floating emoji reactions
          ..._floatingEmojis.map((fe) {
            final age = DateTime.now().difference(fe.createdAt).inMilliseconds;
            final progress = (age / 3000).clamp(0.0, 1.0);
            final yOffset = progress * MediaQuery.of(context).size.height * 0.4;
            final opacity = (1.0 - progress).clamp(0.0, 1.0);
            return Positioned(
              right: fe.startX * 60,
              bottom: 160 + yOffset,
              child: Opacity(opacity: opacity, child: Text(fe.emoji, style: const TextStyle(fontSize: 32))),
            );
          }),

          // Bottom: chat + input + reactions
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: SafeArea(
              top: false,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  height: 160,
                  child: ListView.builder(
                    controller: _chatScrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _chatMessages.length,
                    itemBuilder: (ctx, i) {
                      final msg = _chatMessages[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: RichText(text: TextSpan(children: [
                          TextSpan(text: '${msg.sender}  ', style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w700, fontSize: 13)),
                          TextSpan(text: msg.text, style: const TextStyle(color: Colors.white, fontSize: 13)),
                        ])),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _chatController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendChat(),
                        decoration: InputDecoration(
                          hintText: 'Envoyer un message...',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                          filled: true, fillColor: Colors.white12, isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ...<String>['❤️', '🔥', '👏', '😂'].map((e) => GestureDetector(
                          onTap: () => _sendReaction(e),
                          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: Text(e, style: const TextStyle(fontSize: 24))),
                        )),
                  ]),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSlot(_DuoVideoSlot slot) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: Colors.black,
          child: VideoTrackRenderer(slot.track),
        ),
        Positioned(
          bottom: 6, left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
            child: Text(
              slot.isLocal ? 'Vous' : slot.identity,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _DuoVideoSlot {
  final String identity;
  final bool isLocal;
  final VideoTrack track;
  _DuoVideoSlot({required this.identity, required this.isLocal, required this.track});
}
