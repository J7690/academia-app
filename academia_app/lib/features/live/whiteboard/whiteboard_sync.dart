import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import 'whiteboard_models.dart';

/// Service de synchronisation du tableau blanc via LiveKit Data Channel.
///
/// Envoie les strokes via `publishData` et les reçoit via `DataReceivedEvent`.
/// Format : topic='whiteboard', payload JSON.
class WhiteboardSync {
  final Room room;
  final void Function(WhiteboardStroke stroke) onRemoteStroke;
  final VoidCallback onRemoteClear;

  EventsListener<RoomEvent>? _listener;

  WhiteboardSync({
    required this.room,
    required this.onRemoteStroke,
    required this.onRemoteClear,
  });

  void start() {
    _listener = room.createListener();
    _listener!.on<DataReceivedEvent>(_handleData);
  }

  void dispose() {
    _listener?.dispose();
    _listener = null;
  }

  void _handleData(DataReceivedEvent event) {
    if (event.topic != 'whiteboard') return;
    try {
      final json = jsonDecode(utf8.decode(event.data)) as Map<String, dynamic>;
      final action = json['action']?.toString() ?? '';

      if (action == 'stroke') {
        final strokeData = json['stroke'];
        if (strokeData is Map<String, dynamic>) {
          onRemoteStroke(WhiteboardStroke.fromJson(strokeData));
        }
      } else if (action == 'clear') {
        onRemoteClear();
      }
    } catch (e) {
      debugPrint('[WhiteboardSync] Parse error: $e');
    }
  }

  /// Envoie un stroke terminé à tous les participants.
  Future<void> sendStroke(WhiteboardStroke stroke) async {
    try {
      final payload = jsonEncode({
        'action': 'stroke',
        'stroke': stroke.toJson(),
      });
      await room.localParticipant?.publishData(
        Uint8List.fromList(utf8.encode(payload)),
        reliable: true,
        topic: 'whiteboard',
      );
    } catch (e) {
      debugPrint('[WhiteboardSync] Send stroke error: $e');
    }
  }

  /// Notifie tous les participants d'un effacement total.
  Future<void> sendClear() async {
    try {
      final payload = jsonEncode({'action': 'clear'});
      await room.localParticipant?.publishData(
        Uint8List.fromList(utf8.encode(payload)),
        reliable: true,
        topic: 'whiteboard',
      );
    } catch (e) {
      debugPrint('[WhiteboardSync] Send clear error: $e');
    }
  }
}
