import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

/// Barre de contrôles host pour AcademiaClassroom.
class AcademiaHostControls extends StatelessWidget {
  final bool micEnabled;
  final bool cameraEnabled;
  final bool screenShareEnabled;
  final bool isRecording;
  final bool showQuiz;
  final bool showWhiteboard;
  final ConnectionQuality connectionQuality;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleScreenShare;
  final VoidCallback onToggleRecording;
  final VoidCallback onToggleQuiz;
  final VoidCallback onToggleWhiteboard;
  final VoidCallback onEndSession;
  final AcademiaSessionFeatures features;

  /// Bascule caméra avant / arrière. Masquée si la plateforme ne la gère pas.
  final VoidCallback? onSwitchCamera;

  /// Mode caméra-document : caméra arrière pour filmer une feuille ou un
  /// tableau, mise en avant pour tous les participants.
  final VoidCallback? onToggleDocumentMode;
  final bool isDocumentMode;

  const AcademiaHostControls({
    super.key,
    required this.micEnabled,
    required this.cameraEnabled,
    required this.screenShareEnabled,
    required this.isRecording,
    required this.showQuiz,
    required this.showWhiteboard,
    required this.connectionQuality,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onToggleScreenShare,
    required this.onToggleRecording,
    required this.onToggleQuiz,
    required this.onToggleWhiteboard,
    required this.onEndSession,
    required this.features,
    this.onSwitchCamera,
    this.onToggleDocumentMode,
    this.isDocumentMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: const Color(0xFF111827).withValues(alpha: 0.92),
      child: SafeArea(
        top: false,
        // La barre hôte peut porter jusqu'à neuf boutons. Sur un écran étroit
        // elle déborderait ; on la rend défilante horizontalement tout en
        // gardant la répartition régulière quand la place suffit.
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.of(context).size.width - 24,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
            _Btn(
              icon: micEnabled ? Icons.mic : Icons.mic_off,
              label: micEnabled ? 'Micro' : 'Muet',
              color: micEnabled ? Colors.white : const Color(0xFFEF4444),
              onTap: onToggleMic,
            ),
            _Btn(
              icon: cameraEnabled ? Icons.videocam : Icons.videocam_off,
              label: cameraEnabled ? 'Caméra' : 'Off',
              color: cameraEnabled ? Colors.white : const Color(0xFFEF4444),
              onTap: onToggleCamera,
            ),
            if (onSwitchCamera != null)
              _Btn(
                icon: Icons.flip_camera_ios_outlined,
                label: 'Retourner',
                color: cameraEnabled ? Colors.white : Colors.white24,
                onTap: onSwitchCamera!,
              ),
            if (onToggleDocumentMode != null)
              _Btn(
                icon: isDocumentMode
                    ? Icons.description
                    : Icons.description_outlined,
                label: 'Document',
                color: isDocumentMode
                    ? const Color(0xFF34D399)
                    : (cameraEnabled ? Colors.white54 : Colors.white24),
                onTap: onToggleDocumentMode!,
              ),
            if (features.isScreenShareEnabled)
              _Btn(
                icon: Icons.screen_share,
                label: 'Écran',
                color: screenShareEnabled
                    ? const Color(0xFF34D399)
                    : Colors.white54,
                onTap: onToggleScreenShare,
              ),
            if (features.isRecordingEnabled)
              _Btn(
                icon: isRecording ? Icons.stop_circle : Icons.fiber_manual_record,
                label: isRecording ? 'Stop' : 'REC',
                color: isRecording ? const Color(0xFFEF4444) : Colors.white54,
                onTap: onToggleRecording,
              ),
            if (features.isQuizEnabled)
              _Btn(
                icon: Icons.quiz_outlined,
                label: 'Quiz',
                color: showQuiz ? const Color(0xFF60A5FA) : Colors.white54,
                onTap: onToggleQuiz,
              ),
            if (features.isWhiteboardEnabled)
              _Btn(
                icon: Icons.draw_outlined,
                label: 'Tableau',
                color: showWhiteboard ? const Color(0xFFFBBF24) : Colors.white54,
                onTap: onToggleWhiteboard,
              ),
            _QualityIndicator(quality: connectionQuality),
            _Btn(
              icon: Icons.call_end,
              label: 'Terminer',
              color: const Color(0xFFEF4444),
              onTap: onEndSession,
              filled: true,
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barre de contrôles étudiant pour AcademiaClassroom.
class AcademiaStudentControls extends StatelessWidget {
  final bool micEnabled;
  final bool cameraEnabled;
  final bool isHandRaised;
  final int unreadChat;
  final ConnectionQuality connectionQuality;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleHandRaise;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenReactions;
  final VoidCallback onLeave;
  final AcademiaSessionFeatures features;

  const AcademiaStudentControls({
    super.key,
    required this.micEnabled,
    required this.cameraEnabled,
    required this.isHandRaised,
    required this.unreadChat,
    required this.connectionQuality,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onToggleHandRaise,
    required this.onOpenChat,
    required this.onOpenReactions,
    required this.onLeave,
    required this.features,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: const Color(0xFF111827).withValues(alpha: 0.92),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _Btn(
              icon: micEnabled ? Icons.mic : Icons.mic_off,
              label: micEnabled ? 'Micro' : 'Muet',
              color: micEnabled ? Colors.white : const Color(0xFFEF4444),
              onTap: onToggleMic,
            ),
            _Btn(
              icon: cameraEnabled ? Icons.videocam : Icons.videocam_off,
              label: cameraEnabled ? 'Caméra' : 'Off',
              color: cameraEnabled ? Colors.white : const Color(0xFFEF4444),
              onTap: onToggleCamera,
            ),
            if (features.isHandRaiseEnabled)
              _Btn(
                icon: isHandRaised ? Icons.back_hand : Icons.back_hand_outlined,
                label: isHandRaised ? 'Main ✋' : 'Lever',
                color: isHandRaised
                    ? const Color(0xFFFBBF24)
                    : Colors.white54,
                onTap: onToggleHandRaise,
              ),
            if (features.isChatEnabled)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _Btn(
                    icon: Icons.chat_bubble_outline,
                    label: 'Chat',
                    color: Colors.white54,
                    onTap: onOpenChat,
                  ),
                  if (unreadChat > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$unreadChat',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            _Btn(
              icon: Icons.emoji_emotions_outlined,
              label: 'Réaction',
              color: Colors.white54,
              onTap: onOpenReactions,
            ),
            _QualityIndicator(quality: connectionQuality),
            _Btn(
              icon: Icons.call_end,
              label: 'Quitter',
              color: const Color(0xFFEF4444),
              onTap: onLeave,
              filled: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets internes ─────────────────────────────────────────────────

class _Btn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  const _Btn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: filled ? color : Colors.white12,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: filled ? Colors.white : color,
              size: 20,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _QualityIndicator extends StatelessWidget {
  final ConnectionQuality quality;
  const _QualityIndicator({required this.quality});

  @override
  Widget build(BuildContext context) {
    final color = quality == ConnectionQuality.excellent
        ? const Color(0xFF34D399)
        : quality == ConnectionQuality.good
            ? const Color(0xFFFBBF24)
            : const Color(0xFFEF4444);
    final label = quality == ConnectionQuality.excellent
        ? 'Excellent'
        : quality == ConnectionQuality.good
            ? 'Bon'
            : 'Faible';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.signal_cellular_alt, color: color, size: 20),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(color: color, fontSize: 10)),
      ],
    );
  }
}

/// Configuration des features passée aux contrôles.
class AcademiaSessionFeatures {
  final bool isRecordingEnabled;
  final bool isWhiteboardEnabled;
  final bool isQuizEnabled;
  final bool isChatEnabled;
  final bool isScreenShareEnabled;
  final bool isHandRaiseEnabled;

  const AcademiaSessionFeatures({
    this.isRecordingEnabled = true,
    this.isWhiteboardEnabled = false,
    this.isQuizEnabled = true,
    this.isChatEnabled = true,
    this.isScreenShareEnabled = true,
    this.isHandRaiseEnabled = true,
  });

  factory AcademiaSessionFeatures.fromJson(Map<String, dynamic> json) =>
      AcademiaSessionFeatures(
        isRecordingEnabled: json['is_recording_enabled'] == true,
        isWhiteboardEnabled: json['is_whiteboard_enabled'] == true,
        isQuizEnabled: json['is_quiz_enabled'] != false,
        isChatEnabled: json['is_chat_enabled'] != false,
        isScreenShareEnabled: json['is_screen_share_enabled'] != false,
        isHandRaiseEnabled: json['is_hand_raise_enabled'] != false,
      );
}
