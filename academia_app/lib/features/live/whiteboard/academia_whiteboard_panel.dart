import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import 'whiteboard_canvas.dart';
import 'whiteboard_models.dart';
import 'whiteboard_sync.dart';

/// Panneau tableau blanc intégrable dans AcademiaClassroom.
///
/// Gère la synchronisation via Data Channel LiveKit et l'affichage
/// des strokes locaux + distants.
class AcademiaWhiteboardPanel extends StatefulWidget {
  final Room? room;
  final bool isHost;

  const AcademiaWhiteboardPanel({
    super.key,
    this.room,
    required this.isHost,
  });

  @override
  State<AcademiaWhiteboardPanel> createState() =>
      _AcademiaWhiteboardPanelState();
}

class _AcademiaWhiteboardPanelState extends State<AcademiaWhiteboardPanel> {
  final List<WhiteboardStroke> _remoteStrokes = [];
  WhiteboardSync? _sync;
  final _canvasKey = GlobalKey<WhiteboardCanvasState>();

  @override
  void initState() {
    super.initState();
    _initSync();
  }

  @override
  void didUpdateWidget(AcademiaWhiteboardPanel old) {
    super.didUpdateWidget(old);
    if (widget.room != old.room) {
      _sync?.dispose();
      _initSync();
    }
  }

  @override
  void dispose() {
    _sync?.dispose();
    super.dispose();
  }

  void _initSync() {
    if (widget.room == null) return;
    _sync = WhiteboardSync(
      room: widget.room!,
      onRemoteStroke: (stroke) {
        if (!mounted) return;
        setState(() => _remoteStrokes.add(stroke));
      },
      onRemoteClear: () {
        if (!mounted) return;
        setState(() => _remoteStrokes.clear());
        _canvasKey.currentState?.clearLocal();
      },
    );
    _sync!.start();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border.all(color: const Color(0xFF334155)),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: const Color(0xFF0F172A),
            child: Row(
              children: [
                const Icon(Icons.draw, color: Color(0xFFFBBF24), size: 16),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Tableau blanc',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  widget.isHost ? 'Hôte' : 'Lecture seule',
                  style: TextStyle(
                    color: widget.isHost
                        ? const Color(0xFF34D399)
                        : Colors.white38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          // ── Canvas ──────────────────────────────────────────────
          Expanded(
            child: WhiteboardCanvas(
              key: _canvasKey,
              isReadOnly: !widget.isHost,
              remoteStrokes: _remoteStrokes,
              onStrokeCompleted: (stroke) {
                _sync?.sendStroke(stroke);
              },
              onClearAll: () {
                _sync?.sendClear();
              },
            ),
          ),
        ],
      ),
    );
  }
}
