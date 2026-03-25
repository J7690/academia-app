import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../services/livekit_token_service.dart';
import '../../services/livekit_recording_service.dart';
import '../../widgets/live_quiz_overlay.dart';

class _ChatMessage {
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isLocal;

  _ChatMessage({
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.isLocal = false,
  });
}

class _FloatingReaction {
  final String emoji;
  final String sender;
  final double startX;
  final DateTime createdAt;

  _FloatingReaction({
    required this.emoji,
    required this.sender,
    required this.startX,
    required this.createdAt,
  });
}

class LivekitRoomScreen extends StatefulWidget {
  final String sessionId;

  const LivekitRoomScreen({super.key, required this.sessionId});

  @override
  State<LivekitRoomScreen> createState() => _LivekitRoomScreenState();
}

class _LivekitRoomScreenState extends State<LivekitRoomScreen> {
  Room? _room;
  bool _connecting = true;
  String? _error;
  bool _micEnabled = true;
  bool _cameraEnabled = true;
  bool _screenShareEnabled = false;
  String _displayName = '';
  bool _isHost = false;
  String? _pinnedParticipantId;
  bool _isRecording = false;
  String? _egressId;
  bool _showQuiz = false;
  ConnectionQuality _connectionQuality = ConnectionQuality.good;
  bool _autoAudioOnly = false;

  final List<_ChatMessage> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  int _unreadChat = 0;
  bool _chatVisible = false;
  EventsListener<RoomEvent>? _roomListener;

  final List<_FloatingReaction> _floatingReactions = [];
  final Set<String> _raisedHands = {};

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _error = null;
    });

    try {
      final tokenData = await LivekitTokenService.getTokenForSession(
        widget.sessionId,
      );

      if (!mounted) return;

      final token = tokenData['token'] as String?;
      final url = tokenData['url'] as String?;

      if (token == null || token.isEmpty || url == null || url.isEmpty) {
        setState(() {
          _connecting = false;
          _error = 'Token ou URL LiveKit manquant. Le serveur live n\'est peut-être pas encore configuré.';
        });
        return;
      }

      _displayName = (tokenData['display_name'] ?? '').toString();
      _isHost = tokenData['is_host'] == true;

      final room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultVideoPublishOptions: VideoPublishOptions(
            simulcast: true,
          ),
        ),
      );
      room.addListener(_onRoomChanged);

      _roomListener = room.createListener();
      _roomListener!.on<DataReceivedEvent>(_onDataReceived);

      await room.connect(url, token);

      if (!mounted) {
        _roomListener?.dispose();
        room.removeListener(_onRoomChanged);
        room.dispose();
        return;
      }

      if (_isHost) {
        await room.localParticipant?.setMicrophoneEnabled(true);
        await room.localParticipant?.setCameraEnabled(true);
      }

      setState(() {
        _room = room;
        _connecting = false;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('[LivekitRoom] Erreur connexion: $e');
      setState(() {
        _connecting = false;
        _error = 'Impossible de rejoindre la session live.\n$e';
      });
    }
  }

  void _onDataReceived(DataReceivedEvent event) {
    if (!mounted) return;
    try {
      final json = utf8.decode(event.data);
      final map = jsonDecode(json) as Map<String, dynamic>;

      if (event.topic == 'chat') {
        final msg = _ChatMessage(
          senderName: (map['sender'] ?? '').toString(),
          text: (map['text'] ?? '').toString(),
          timestamp: DateTime.now(),
          isLocal: false,
        );
        setState(() {
          _chatMessages.add(msg);
          if (!_chatVisible) _unreadChat++;
        });
        _scrollChatToBottom();
      } else if (event.topic == 'reaction') {
        final type = (map['type'] ?? '').toString();
        final sender = (map['sender'] ?? '').toString();
        if (type == 'hand_raise') {
          setState(() => _raisedHands.add(sender));
        } else if (type == 'hand_lower') {
          setState(() => _raisedHands.remove(sender));
        } else if (type == 'emoji') {
          final emoji = (map['emoji'] ?? '❤️').toString();
          _addFloatingReaction(emoji, sender);
        }
      }
    } catch (e) {
      debugPrint('[LivekitRoom] Data parse error: $e');
    }
  }

  void _addFloatingReaction(String emoji, String sender) {
    final rng = Random();
    final reaction = _FloatingReaction(
      emoji: emoji,
      sender: sender,
      startX: 0.6 + rng.nextDouble() * 0.3,
      createdAt: DateTime.now(),
    );
    setState(() => _floatingReactions.add(reaction));
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _floatingReactions.remove(reaction));
      }
    });
  }

  void _sendReaction(String emoji) {
    final room = _room;
    if (room == null) return;
    final senderName = _displayName.isNotEmpty
        ? _displayName
        : (room.localParticipant?.identity ?? 'Moi');
    final payload = jsonEncode({
      'sender': senderName,
      'type': 'emoji',
      'emoji': emoji,
    });
    try {
      room.localParticipant?.publishData(
        utf8.encode(payload),
        reliable: true,
        topic: 'reaction',
      );
    } catch (_) {}
    _addFloatingReaction(emoji, senderName);
  }

  Future<void> _sendChatMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    final room = _room;
    if (room == null) return;

    final payload = jsonEncode({
      'sender': _displayName.isNotEmpty
          ? _displayName
          : (room.localParticipant?.identity ?? 'Moi'),
      'text': text,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });

    try {
      await room.localParticipant?.publishData(
        utf8.encode(payload),
        reliable: true,
        topic: 'chat',
      );

      setState(() {
        _chatMessages.add(_ChatMessage(
          senderName: _displayName.isNotEmpty ? _displayName : 'Moi',
          text: text,
          timestamp: DateTime.now(),
          isLocal: true,
        ));
      });
      _chatController.clear();
      _scrollChatToBottom();
    } catch (e) {
      debugPrint('[LivekitRoom] Chat send error: $e');
    }
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _roomListener?.dispose();
    final room = _room;
    room?.removeListener(_onRoomChanged);
    room?.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _onRoomChanged() {
    if (!mounted) return;
    final room = _room;
    if (room != null && room.localParticipant != null) {
      final quality = room.localParticipant!.connectionQuality;
      if (quality != _connectionQuality) {
        _connectionQuality = quality;
        if (quality == ConnectionQuality.poor && !_autoAudioOnly) {
          _autoAudioOnly = true;
          room.localParticipant?.setCameraEnabled(false);
          debugPrint('[LivekitRoom] Auto audio-only: connexion faible');
        } else if (quality != ConnectionQuality.poor && _autoAudioOnly) {
          _autoAudioOnly = false;
          if (_cameraEnabled) {
            room.localParticipant?.setCameraEnabled(true);
          }
          debugPrint('[LivekitRoom] Connexion r\u00e9tablie, vid\u00e9o r\u00e9activ\u00e9e');
        }
      }
    }
    setState(() {});
  }

  Future<void> _toggleMicrophone() async {
    final room = _room;
    if (room == null) return;
    final enabled = !_micEnabled;
    try {
      await room.localParticipant?.setMicrophoneEnabled(enabled);
      if (!mounted) return;
      setState(() {
        _micEnabled = enabled;
      });
    } catch (_) {}
  }

  Future<void> _toggleCamera() async {
    final room = _room;
    if (room == null) return;
    final enabled = !_cameraEnabled;
    try {
      await room.localParticipant?.setCameraEnabled(enabled);
      if (!mounted) return;
      setState(() {
        _cameraEnabled = enabled;
      });
    } catch (_) {}
  }

  Future<void> _toggleRecording() async {
    final room = _room;
    if (room == null || !_isHost) return;
    try {
      if (!_isRecording) {
        final result = await LivekitRecordingService.startRecording(
          sessionId: widget.sessionId,
        );
        if (!mounted) return;
        setState(() {
          _isRecording = true;
          _egressId = (result['egress_id'] ?? '').toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enregistrement démarré.')),
        );
      } else {
        if (_egressId == null || _egressId!.isEmpty) return;
        await LivekitRecordingService.stopRecording(
          sessionId: widget.sessionId,
          egressId: _egressId!,
        );
        if (!mounted) return;
        setState(() {
          _isRecording = false;
          _egressId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enregistrement arrêté. Le replay sera disponible.')),
        );
      }
    } catch (e) {
      debugPrint('[LivekitRoom] Recording error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur enregistrement: $e')),
        );
      }
    }
  }

  Future<void> _toggleScreenShare() async {
    final room = _room;
    if (room == null) return;
    final enabled = !_screenShareEnabled;
    try {
      await room.localParticipant?.setScreenShareEnabled(enabled);
      if (!mounted) return;
      setState(() {
        _screenShareEnabled = enabled;
      });
    } catch (e) {
      debugPrint('[LivekitRoom] Screen share error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de partager l\'écran: $e')),
        );
      }
    }
  }

  void _raiseHand() {
    if (!mounted) return;
    final room = _room;
    if (room == null) return;
    final senderName = _displayName.isNotEmpty
        ? _displayName
        : (room.localParticipant?.identity ?? 'Moi');
    final isRaised = _raisedHands.contains(senderName);
    final payload = jsonEncode({
      'sender': senderName,
      'type': isRaised ? 'hand_lower' : 'hand_raise',
    });
    try {
      room.localParticipant?.publishData(
        utf8.encode(payload),
        reliable: true,
        topic: 'reaction',
      );
    } catch (_) {}
    setState(() {
      if (isRaised) {
        _raisedHands.remove(senderName);
      } else {
        _raisedHands.add(senderName);
      }
    });
  }

  void _showReactionPicker(Room room) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        const emojis = ['👏', '❤️', '😂', '🔥', '👍', '🎉', '😮', '💯'];
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Réactions',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: emojis.map((e) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _sendReaction(e);
                      },
                      child: Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(e, style: const TextStyle(fontSize: 28)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openChatSheet(Room room) {
    setState(() {
      _chatVisible = true;
      _unreadChat = 0;
    });
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              top: false,
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.chat_bubble, size: 18, color: Color(0xFF1EA75C)),
                          const SizedBox(width: 8),
                          Text(
                            'Chat (${_chatMessages.length})',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Text(
                            '${room.remoteParticipants.length + 1} participants',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _buildChatList()),
                    _buildChatInput(),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      if (mounted) setState(() => _chatVisible = false);
    });
  }

  void _leaveRoom() {
    final room = _room;
    room?.removeListener(_onRoomChanged);
    room?.dispose();
    _room = null;
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session live'),
      ),
      body: _connecting
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _connect,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                )
              : room == null
                  ? const Center(child: Text('Room LiveKit non disponible.'))
                  : _buildRoomView(room),
    );
  }

  Widget _buildRoomView(Room room) {
    final participants = <Participant>[
      if (room.localParticipant != null) room.localParticipant!,
      ...room.remoteParticipants.values,
    ];
    final width = MediaQuery.of(context).size.width;
    final showSidePanel = width >= 900;

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildVideoGrid(participants, width),
                  ),
                  if (showSidePanel)
                    Container(
                      width: 260,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        border: Border(
                          left: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                      child: _buildSidePanel(participants),
                    ),
                ],
              ),
              ..._floatingReactions.map((r) {
                final age = DateTime.now().difference(r.createdAt).inMilliseconds;
                final progress = (age / 3000).clamp(0.0, 1.0);
                final yOffset = progress * MediaQuery.of(context).size.height * 0.6;
                final opacity = (1.0 - progress).clamp(0.0, 1.0);
                return Positioned(
                  right: r.startX * 80,
                  bottom: 20 + yOffset,
                  child: Opacity(
                    opacity: opacity,
                    child: Text(
                      r.emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                );
              }),
              if (_showQuiz)
                Positioned.fill(
                  child: LiveQuizOverlay(
                    room: room,
                    isHost: _isHost,
                    displayName: _displayName,
                    onClose: () => setState(() => _showQuiz = false),
                  ),
                ),
            ],
          ),
        ),
        _buildControlsBar(room),
      ],
    );
  }

  VideoTrack? _findScreenShareTrack(List<Participant> participants) {
    for (final p in participants) {
      for (final pub in p.videoTrackPublications) {
        if (pub.source == TrackSource.screenShareVideo && pub.track is VideoTrack) {
          return pub.track as VideoTrack;
        }
      }
    }
    return null;
  }

  Participant? _findScreenShareParticipant(List<Participant> participants) {
    for (final p in participants) {
      for (final pub in p.videoTrackPublications) {
        if (pub.source == TrackSource.screenShareVideo && pub.track != null) {
          return p;
        }
      }
    }
    return null;
  }

  Participant? _getActiveSpeaker(List<Participant> participants) {
    final room = _room;
    if (room == null) return null;
    if (_pinnedParticipantId != null) {
      for (final p in participants) {
        if (p.identity == _pinnedParticipantId) return p;
      }
    }
    final speakers = room.activeSpeakers;
    if (speakers.isNotEmpty) {
      return speakers.first;
    }
    return null;
  }

  bool _isSpeaking(Participant p) {
    final room = _room;
    if (room == null) return false;
    return room.activeSpeakers.any((s) => s.identity == p.identity);
  }

  Widget _buildVideoGrid(List<Participant> participants, double width) {
    if (participants.isEmpty) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            'En attente du démarrage du live...',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final screenShareTrack = _findScreenShareTrack(participants);
    final screenShareParticipant = _findScreenShareParticipant(participants);

    if (screenShareTrack != null) {
      return _buildSpeakerView(participants, screenShareTrack, screenShareParticipant, width);
    }

    if (participants.length > 2) {
      final speaker = _getActiveSpeaker(participants);
      if (speaker != null) {
        VideoTrack? speakerTrack;
        for (final pub in speaker.videoTrackPublications) {
          if (pub.source != TrackSource.screenShareVideo && pub.track is VideoTrack) {
            speakerTrack = pub.track as VideoTrack;
            break;
          }
        }
        if (speakerTrack != null) {
          return _buildSpeakerView(participants, speakerTrack, speaker, width);
        }
      }
    }

    return _buildGalleryView(participants, width);
  }

  Widget _buildSpeakerView(
    List<Participant> participants,
    VideoTrack screenTrack,
    Participant? screenParticipant,
    double width,
  ) {
    final isPortrait = MediaQuery.of(context).size.height > width;
    final thumbnailSize = isPortrait ? 80.0 : 100.0;

    return Column(
      children: [
        if (screenParticipant != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            color: const Color(0xFF1EA75C).withValues(alpha: 0.9),
            child: Row(
              children: [
                const Icon(Icons.screen_share, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  '${screenParticipant is LocalParticipant ? "Vous partagez" : "${screenParticipant.identity} partage"} son écran',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        Expanded(
          child: Container(
            color: Colors.black,
            child: VideoTrackRenderer(screenTrack),
          ),
        ),
        SizedBox(
          height: thumbnailSize + 8,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            itemCount: participants.length,
            itemBuilder: (context, index) {
              final p = participants[index];
              VideoTrack? camTrack;
              for (final pub in p.videoTrackPublications) {
                if (pub.source != TrackSource.screenShareVideo && pub.track is VideoTrack) {
                  camTrack = pub.track as VideoTrack;
                  break;
                }
              }
              return Container(
                width: thumbnailSize * 1.3,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: (screenParticipant != null && p.identity == screenParticipant.identity)
                      ? Border.all(color: const Color(0xFF1EA75C), width: 2)
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      camTrack != null
                          ? VideoTrackRenderer(camTrack)
                          : Center(
                              child: Text(
                                p.identity.isNotEmpty ? p.identity[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                      Positioned(
                        bottom: 2, left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            p is LocalParticipant ? 'Vous' : p.identity,
                            style: const TextStyle(color: Colors.white, fontSize: 9),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGalleryView(List<Participant> participants, double width) {
    final crossAxisCount = width < 600
        ? 1
        : width < 1000
            ? 2
            : 3;

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final p = participants[index];
        VideoTrack? videoTrack;
        for (final pub in p.videoTrackPublications) {
          if (pub.source != TrackSource.screenShareVideo) {
            final t = pub.track;
            if (t is VideoTrack) {
              videoTrack = t;
              break;
            }
          }
        }

        final speaking = _isSpeaking(p);
        final isPinned = _pinnedParticipantId == p.identity;

        return GestureDetector(
          onLongPress: _isHost
              ? () {
                  setState(() {
                    _pinnedParticipantId =
                        _pinnedParticipantId == p.identity ? null : p.identity;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_pinnedParticipantId == p.identity
                          ? '${p.identity} épinglé en présentateur'
                          : 'Épingle retirée'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              : null,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: speaking || isPinned
                  ? Border.all(
                      color: isPinned ? const Color(0xFFF59E0B) : const Color(0xFF1EA75C),
                      width: 2.5,
                    )
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(speaking || isPinned ? 9.5 : 12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  videoTrack != null
                      ? VideoTrackRenderer(videoTrack)
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFF374151),
                                child: Text(
                                  p.identity.isNotEmpty ? p.identity[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                p.identity,
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                  Positioned(
                    bottom: 6, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (speaking)
                            Container(
                              width: 8, height: 8,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: const BoxDecoration(
                                color: Color(0xFF1EA75C),
                                shape: BoxShape.circle,
                              ),
                            ),
                          Icon(
                            p.audioTrackPublications.any((pub) => pub.track != null && !pub.muted)
                                ? Icons.mic
                                : Icons.mic_off,
                            size: 12,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            p is LocalParticipant ? 'Vous' : p.identity,
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          if (isPinned) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.push_pin, size: 10, color: Color(0xFFF59E0B)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSidePanel(List<Participant> participants) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: Color(0xFF1EA75C),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF1EA75C),
            labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: 'Chat'),
              Tab(text: 'Participants'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                Column(
                  children: [
                    Expanded(child: _buildChatList()),
                    _buildChatInput(),
                  ],
                ),
                _buildParticipantsList(participants),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsList(List<Participant> participants) {
    if (participants.isEmpty) {
      return const Center(
        child: Text('Aucun participant connecté.', style: TextStyle(fontSize: 12, color: Colors.grey)),
      );
    }
    return ListView.builder(
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final p = participants[index];
        final isLocal = p is LocalParticipant;
        final name = p.identity;
        final hasVideo = p.videoTrackPublications.any((pub) => pub.track != null);
        final hasAudio = p.audioTrackPublications.any((pub) => pub.track != null && !pub.muted);
        return ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: isLocal ? const Color(0xFF1EA75C) : const Color(0xFF6B7280),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          title: Text(
            isLocal ? '$name (Vous)' : name,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(hasAudio ? Icons.mic : Icons.mic_off, size: 14,
                  color: hasAudio ? const Color(0xFF1EA75C) : Colors.grey),
              const SizedBox(width: 4),
              Icon(hasVideo ? Icons.videocam : Icons.videocam_off, size: 14,
                  color: hasVideo ? const Color(0xFF1EA75C) : Colors.grey),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatList() {
    if (_chatMessages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline, size: 32, color: Colors.grey),
              SizedBox(height: 8),
              Text('Aucun message', style: TextStyle(color: Colors.grey, fontSize: 13)),
              SizedBox(height: 4),
              Text('Envoyez un message pour démarrer la conversation.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _chatScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      itemCount: _chatMessages.length,
      itemBuilder: (context, index) {
        final msg = _chatMessages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: msg.isLocal ? const Color(0xFF1EA75C) : const Color(0xFF6366F1),
                child: Text(
                  msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          msg.isLocal ? 'Vous' : msg.senderName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: msg.isLocal ? const Color(0xFF1EA75C) : const Color(0xFF6366F1),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 9, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(msg.text, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              style: const TextStyle(fontSize: 13),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendChatMessage(),
              decoration: InputDecoration(
                hintText: 'Envoyer un message...',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: _sendChatMessage,
            icon: const Icon(Icons.send, size: 20, color: Color(0xFF1EA75C)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionQualityIndicator() {
    IconData icon;
    Color color;
    String label;
    switch (_connectionQuality) {
      case ConnectionQuality.excellent:
        icon = Icons.signal_cellular_alt;
        color = const Color(0xFF1EA75C);
        label = 'Excellente';
        break;
      case ConnectionQuality.good:
        icon = Icons.signal_cellular_alt_2_bar;
        color = const Color(0xFF1EA75C);
        label = 'Bonne';
        break;
      case ConnectionQuality.poor:
        icon = Icons.signal_cellular_alt_1_bar;
        color = const Color(0xFFF59E0B);
        label = 'Faible';
        break;
      default:
        icon = Icons.signal_cellular_connected_no_internet_0_bar;
        color = Colors.redAccent;
        label = 'Perdue';
    }
    return Tooltip(
      message: 'Connexion: $label${_autoAudioOnly ? ' (audio seul)' : ''}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          if (_autoAudioOnly) ...[
            const SizedBox(width: 2),
            const Text('Audio', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 9, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }

  Widget _buildControlsBar(Room room) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: const BoxDecoration(
          color: Colors.black,
        ),
        child: Row(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: _toggleMicrophone,
                  icon: Icon(
                    _micEnabled ? Icons.mic : Icons.mic_off,
                    color: _micEnabled ? Colors.white : Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: _toggleCamera,
                  icon: Icon(
                    _cameraEnabled ? Icons.videocam : Icons.videocam_off,
                    color: _cameraEnabled ? Colors.white : Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: _toggleScreenShare,
                  icon: Icon(
                    _screenShareEnabled ? Icons.stop_screen_share : Icons.screen_share,
                    color: _screenShareEnabled ? const Color(0xFF1EA75C) : Colors.white,
                  ),
                  tooltip: _screenShareEnabled ? 'Arrêter le partage' : 'Partager l\'écran',
                ),
                if (_isHost) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: _toggleRecording,
                    icon: Icon(
                      _isRecording ? Icons.stop_circle : Icons.fiber_manual_record,
                      color: _isRecording ? Colors.redAccent : Colors.white,
                    ),
                    tooltip: _isRecording ? 'Arrêter l\'enregistrement' : 'Enregistrer',
                  ),
                ],
              ],
            ),
            if (_isHost) ...[
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => setState(() => _showQuiz = !_showQuiz),
                icon: Icon(
                  Icons.quiz,
                  color: _showQuiz ? const Color(0xFFF59E0B) : Colors.white,
                ),
                tooltip: 'Quiz en direct',
              ),
            ],
            if (_isRecording)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: Colors.white, size: 8),
                    SizedBox(width: 4),
                    Text('REC', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            const Spacer(),
            _buildConnectionQualityIndicator(),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () => _showReactionPicker(room),
              icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.white),
              tooltip: 'Réactions',
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: _raiseHand,
              icon: Icon(
                _raisedHands.contains(_displayName.isNotEmpty
                    ? _displayName
                    : (_room?.localParticipant?.identity ?? ''))
                    ? Icons.pan_tool
                    : Icons.pan_tool_outlined,
                color: _raisedHands.contains(_displayName.isNotEmpty
                    ? _displayName
                    : (_room?.localParticipant?.identity ?? ''))
                    ? const Color(0xFFF59E0B)
                    : Colors.white,
              ),
              tooltip: 'Main levée',
            ),
            const SizedBox(width: 4),
            Stack(
              children: [
                IconButton(
                  onPressed: () => _openChatSheet(room),
                  icon: const Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.white,
                  ),
                ),
                if (_unreadChat > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1EA75C),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _unreadChat > 9 ? '9+' : '$_unreadChat',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _leaveRoom,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(Icons.call_end, size: 18),
              label: const Text(
                'Quitter',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
