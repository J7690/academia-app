import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:share_plus/share_plus.dart';

import '../../../services/academia_livekit_service.dart';
import '../../../services/academia_presence_service.dart';

/// Panneau "Participants" pour l'hôte d'une salle AcademiaClassroom.
///
/// Ajoute deux contrôles demandés par l'audit Live/Classroom :
/// - couper à distance le micro d'un participant précis (host uniquement),
/// - exporter le registre de présence de la session en CSV.
class AcademiaParticipantsPanel extends StatefulWidget {
  final String sessionId;
  final bool isHost;
  final LocalParticipant? localParticipant;
  final List<RemoteParticipant> remoteParticipants;
  final VoidCallback onClose;

  const AcademiaParticipantsPanel({
    super.key,
    required this.sessionId,
    required this.isHost,
    required this.localParticipant,
    required this.remoteParticipants,
    required this.onClose,
  });

  @override
  State<AcademiaParticipantsPanel> createState() =>
      _AcademiaParticipantsPanelState();
}

class _AcademiaParticipantsPanelState
    extends State<AcademiaParticipantsPanel> {
  final _livekit = AcademiaLivekitService.instance;
  final _presence = AcademiaPresenceService.instance;
  final Set<String> _mutingInProgress = {};
  bool _exportingAttendance = false;

  Future<void> _toggleMute(RemoteParticipant p) async {
    final identity = p.identity;
    if (_mutingInProgress.contains(identity)) return;
    setState(() => _mutingInProgress.add(identity));

    final currentlyEnabled = p.isMicrophoneEnabled();
    final ok = await _livekit.muteParticipantAudio(
      sessionId: widget.sessionId,
      participantIdentity: identity,
      muted: currentlyEnabled, // si activé -> on coupe (muted=true)
    );

    if (mounted) {
      setState(() => _mutingInProgress.remove(identity));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? (currentlyEnabled
                    ? 'Micro coupé pour ${p.name.isNotEmpty ? p.name : identity}.'
                    : 'Micro réactivable par le participant.')
                : "Impossible de couper ce micro pour l'instant.",
          ),
        ),
      );
    }
  }

  Future<void> _exportAttendance() async {
    setState(() => _exportingAttendance = true);
    try {
      final rows = await _presence.listPresence(widget.sessionId);
      final buffer = StringBuffer();
      buffer.writeln('nom,identifiant,statut,rejoint_le,derniere_activite');
      for (final r in rows) {
        final name = (r['display_name'] ?? r['name'] ?? '').toString();
        final id = (r['user_id'] ?? r['participant_id'] ?? '').toString();
        final status = (r['status'] ?? (r['is_online'] == true ? 'en ligne' : 'hors ligne')).toString();
        final joined = (r['joined_at'] ?? r['created_at'] ?? '').toString();
        final lastSeen = (r['last_seen'] ?? r['last_heartbeat_at'] ?? r['updated_at'] ?? '').toString();
        String esc(String v) => '"${v.replaceAll('"', '""')}"';
        buffer.writeln('${esc(name)},${esc(id)},${esc(status)},${esc(joined)},${esc(lastSeen)}');
      }

      final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
      final file = XFile.fromData(
        bytes,
        mimeType: 'text/csv',
        name: 'presence_${widget.sessionId}.csv',
      );
      await Share.shareXFiles([file], text: 'Registre de présence Academia');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Export impossible : $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingAttendance = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.remoteParticipants.length + (widget.localParticipant != null ? 1 : 0);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Sur écran étroit, le libellé "Présence (CSV)" ferait
                  // déborder la ligne à côté du titre + bouton fermer : on
                  // le réduit à une icône seule en dessous de 380px.
                  final compact = constraints.maxWidth < 380;
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Participants ($total)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.isHost)
                        compact
                            ? IconButton(
                                tooltip: 'Présence (CSV)',
                                onPressed:
                                    _exportingAttendance ? null : _exportAttendance,
                                icon: _exportingAttendance
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child:
                                            CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.file_download_outlined,
                                        color: Color(0xFF60A5FA), size: 18),
                              )
                            : TextButton.icon(
                                onPressed:
                                    _exportingAttendance ? null : _exportAttendance,
                                icon: _exportingAttendance
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child:
                                            CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.file_download_outlined, size: 18),
                                label: const Text('Présence (CSV)'),
                                style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF60A5FA)),
                              ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: widget.onClose,
                      ),
                    ],
                  );
                },
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (widget.localParticipant != null)
                    _ParticipantRow(
                      name: '${widget.localParticipant!.name.isNotEmpty ? widget.localParticipant!.name : 'Moi'} (vous)',
                      micEnabled: widget.localParticipant!.isMicrophoneEnabled(),
                      canModerate: false,
                      onToggleMute: null,
                    ),
                  ...widget.remoteParticipants.map(
                    (p) => _ParticipantRow(
                      name: p.name.isNotEmpty ? p.name : p.identity,
                      micEnabled: p.isMicrophoneEnabled(),
                      canModerate: widget.isHost,
                      isBusy: _mutingInProgress.contains(p.identity),
                      onToggleMute: widget.isHost ? () => _toggleMute(p) : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  final String name;
  final bool micEnabled;
  final bool canModerate;
  final bool isBusy;
  final VoidCallback? onToggleMute;

  const _ParticipantRow({
    required this.name,
    required this.micEnabled,
    required this.canModerate,
    this.isBusy = false,
    this.onToggleMute,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.3),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 13),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: canModerate
          ? (isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: Icon(
                    micEnabled ? Icons.mic : Icons.mic_off,
                    color: micEnabled ? Colors.white70 : const Color(0xFFEF4444),
                    size: 20,
                  ),
                  tooltip: micEnabled ? 'Couper le micro' : 'Micro déjà coupé',
                  onPressed: onToggleMute,
                ))
          : Icon(
              micEnabled ? Icons.mic : Icons.mic_off,
              color: micEnabled ? Colors.white24 : const Color(0xFFEF4444),
              size: 18,
            ),
    );
  }
}
