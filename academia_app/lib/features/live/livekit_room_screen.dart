import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../services/livekit_token_service.dart';

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
      final data = await LivekitTokenService.getTokenForSession(widget.sessionId);
      final host = (data['host'] ?? '').toString();
      final token = (data['token'] ?? '').toString();
      if (host.isEmpty || token.isEmpty) {
        throw Exception('Données LiveKit invalides.');
      }

      final uri = Uri.parse(host);
      final wsUri = uri.scheme == 'wss' || uri.scheme == 'ws'
          ? uri
          : uri.replace(scheme: uri.scheme == 'https' ? 'wss' : 'ws');

      final room = Room();
      await room.connect(
        wsUri.toString(),
        token,
        roomOptions: const RoomOptions(),
        connectOptions: const ConnectOptions(),
      );

      await room.localParticipant?.setCameraEnabled(true);
      await room.localParticipant?.setMicrophoneEnabled(true);

      room.addListener(_onRoomChanged);

      setState(() {
        _room = room;
        _connecting = false;
        _micEnabled = true;
        _cameraEnabled = true;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _connecting = false;
      });
    }
  }

  @override
  void dispose() {
    final room = _room;
    room?.removeListener(_onRoomChanged);
    room?.dispose();
    super.dispose();
  }

  void _onRoomChanged() {
    if (!mounted) return;
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

  void _raiseHand() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Main levée envoyée au professeur.'),
      ),
    );
  }

  void _openChatSheet(Room room) {
    final participants = <Participant>[
      if (room.localParticipant != null) room.localParticipant!,
      ...room.remoteParticipants.values,
    ];

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: 360,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildSidePanel(participants),
            ),
          ),
        );
      },
    );
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
          child: Row(
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
                        color: Colors.grey.withOpacity(0.2),
                      ),
                    ),
                  ),
                  child: _buildSidePanel(participants),
                ),
            ],
          ),
        ),
        _buildControlsBar(room),
      ],
    );
  }

  Widget _buildVideoGrid(List<Participant> participants, double width) {
    final crossAxisCount = width < 600
        ? 1
        : width < 1000
            ? 2
            : 3;

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
          final t = pub.track;
          if (t is VideoTrack) {
            videoTrack = t;
            break;
          }
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
          ),
          child: videoTrack != null
              ? VideoTrackRenderer(videoTrack)
              : Center(
                  child: Text(
                    p.identity,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildSidePanel(List<Participant> participants) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Text(
            'Participants & chat',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: participants.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text(
                      'Aucun participant connecté pour le moment.',
                      style: TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: participants.length,
                  itemBuilder: (context, index) {
                    final p = participants[index];
                    final isLocal = p is LocalParticipant;
                    final name = p.identity;
                    return ListTile(
                      dense: true,
                      title: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: isLocal
                          ? const Text(
                              'Vous',
                              style: TextStyle(fontSize: 11),
                            )
                          : null,
                    );
                  },
                ),
        ),
        const Padding(
          padding: EdgeInsets.all(12.0),
          child: Text(
            'Le chat texte sera bientôt disponible.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ),
      ],
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
              ],
            ),
            const Spacer(),
            IconButton(
              onPressed: _raiseHand,
              icon: const Icon(
                Icons.pan_tool_outlined,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () => _openChatSheet(room),
              icon: const Icon(
                Icons.chat_bubble_outline,
                color: Colors.white,
              ),
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
