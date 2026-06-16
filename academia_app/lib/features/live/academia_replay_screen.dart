import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../services/academia_replay_service.dart';

/// Écran de lecture replay d'une session AcademiaClassroom.
///
/// Affiche la vidéo enregistrée avec une timeline enrichie
/// montrant les quiz, arrivées de participants, et chapitres.
class AcademiaReplayScreen extends StatefulWidget {
  final String sessionId;

  const AcademiaReplayScreen({super.key, required this.sessionId});

  @override
  State<AcademiaReplayScreen> createState() => _AcademiaReplayScreenState();
}

class _AcademiaReplayScreenState extends State<AcademiaReplayScreen> {
  final _replayService = AcademiaReplayService.instance;
  AcademiaReplay? _replay;
  List<ReplayTimelineEvent> _timeline = [];
  VideoPlayerController? _videoCtrl;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final replay = await _replayService.getReplay(widget.sessionId);
    if (!mounted) return;

    if (replay == null || replay.replayUrl.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Replay non disponible pour cette session.';
      });
      return;
    }

    final timeline = await _replayService.getTimeline(widget.sessionId);

    final ctrl = VideoPlayerController.networkUrl(
      Uri.parse(replay.replayUrl),
    );
    await ctrl.initialize();

    if (!mounted) {
      ctrl.dispose();
      return;
    }

    setState(() {
      _replay = replay;
      _timeline = timeline;
      _videoCtrl = ctrl;
      _loading = false;
    });
  }

  void _seekTo(int offsetSeconds) {
    _videoCtrl?.seekTo(Duration(seconds: offsetSeconds));
    if (_videoCtrl?.value.isPlaying == false) {
      _videoCtrl?.play();
    }
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Text(
          _replay?.title ?? 'Replay',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF60A5FA)))
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.white54)))
              : Column(
                  children: [
                    // ── Vidéo ──────────────────────────────────────────
                    Expanded(
                      flex: 3,
                      child: _videoCtrl != null &&
                              _videoCtrl!.value.isInitialized
                          ? Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                AspectRatio(
                                  aspectRatio:
                                      _videoCtrl!.value.aspectRatio,
                                  child: VideoPlayer(_videoCtrl!),
                                ),
                                _buildVideoControls(),
                              ],
                            )
                          : const Center(
                              child: Text(
                                'Chargement vidéo…',
                                style: TextStyle(color: Colors.white38),
                              ),
                            ),
                    ),
                    // ── Info session ───────────────────────────────────
                    if (_replay != null) _buildSessionInfo(),
                    // ── Timeline événements ────────────────────────────
                    Expanded(
                      flex: 1,
                      child: _buildTimeline(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildVideoControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.black45,
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (_videoCtrl!.value.isPlaying) {
                _videoCtrl!.pause();
              } else {
                _videoCtrl!.play();
              }
              setState(() {});
            },
            child: Icon(
              _videoCtrl!.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: VideoProgressIndicator(
              _videoCtrl!,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Color(0xFF3B82F6),
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white10,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatDuration(
                _videoCtrl!.value.duration.inSeconds),
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionInfo() {
    final r = _replay!;
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF1E293B),
      child: Row(
        children: [
          _InfoChip(Icons.person, r.hostName),
          _InfoChip(Icons.people, '${r.participantCount} participants'),
          _InfoChip(Icons.quiz, '${r.quizCount} quiz'),
          _InfoChip(Icons.chat_bubble, '${r.messageCount} messages'),
          _InfoChip(Icons.timer, _formatDuration(r.durationSeconds)),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    if (_timeline.isEmpty) {
      return const Center(
        child: Text(
          'Aucun événement enregistré',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      scrollDirection: Axis.horizontal,
      itemCount: _timeline.length,
      itemBuilder: (_, i) {
        final event = _timeline[i];
        return GestureDetector(
          onTap: () => _seekTo(event.offsetSeconds),
          child: Container(
            width: 120,
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF334155),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: event.type == 'quiz'
                    ? const Color(0xFF3B82F6)
                    : const Color(0xFF22C55E),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  event.type == 'quiz' ? Icons.quiz : Icons.login,
                  color: event.type == 'quiz'
                      ? const Color(0xFF60A5FA)
                      : const Color(0xFF34D399),
                  size: 16,
                ),
                const SizedBox(height: 4),
                Text(
                  event.type == 'quiz' ? 'Quiz' : 'Arrivée',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _formatDuration(event.offsetSeconds),
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white38, size: 12),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
