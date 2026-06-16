import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/admin_live_sessions_provider.dart';
import '../../models/academia_session.dart';
import '../live/academia_classroom_screen.dart';

class AdminLiveSessionsScreen extends StatefulWidget {
  const AdminLiveSessionsScreen({super.key});

  @override
  State<AdminLiveSessionsScreen> createState() => _AdminLiveSessionsScreenState();
}

class _AdminLiveSessionsScreenState extends State<AdminLiveSessionsScreen> {
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminLiveSessionsProvider>().loadSessions();
    });
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'draft':
        return 'Brouillon';
      case 'pending_approval':
        return 'En attente validation';
      case 'approved':
        return 'Approuvée';
      case 'running':
        return 'En cours';
      case 'ended':
        return 'Terminée';
      case 'cancelled':
        return 'Annulée';
      case 'rejected':
        return 'Refusée';
      default:
        return 'Inconnu';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'draft':
        return const Color(0xFF6B7280);
      case 'pending_approval':
        return const Color(0xFFF59E0B);
      case 'approved':
        return const Color(0xFF1EA75C);
      case 'running':
        return const Color(0xFF2563EB);
      case 'ended':
        return const Color(0xFF6B7280);
      case 'cancelled':
      case 'rejected':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        title: const Text('Lives - Admin'),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFA3D65C), Color(0xFF1EA75C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Consumer<AdminLiveSessionsProvider>(
        builder: (context, provider, child) {
          final sessions = provider.sessions;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Text(
                      'Filtre statut :',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          hintText: 'Tous',
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Tous')),
                          DropdownMenuItem(value: 'draft', child: Text('Brouillon')),
                          DropdownMenuItem(
                            value: 'pending_approval',
                            child: Text('En attente validation'),
                          ),
                          DropdownMenuItem(value: 'approved', child: Text('Approuvée')),
                          DropdownMenuItem(value: 'running', child: Text('En cours')),
                          DropdownMenuItem(value: 'ended', child: Text('Terminée')),
                          DropdownMenuItem(value: 'cancelled', child: Text('Annulée')),
                          DropdownMenuItem(value: 'rejected', child: Text('Refusée')),
                        ],
                        onChanged: (value) async {
                          setState(() {
                            _selectedStatus = value;
                          });
                          await provider.loadSessions(status: value);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => provider.loadSessions(status: _selectedStatus),
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Recharger',
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Ce tableau regroupe les sessions live des cours en ligne (brouillons, en attente, approuvées, en cours, etc.). '
                  'Utilisez le filtre de statut pour traiter les demandes des enseignants et suivre les lives en cours.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: provider.isLoading && sessions.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : provider.error != null && sessions.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    provider.error!,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: () => provider.loadSessions(
                                      status: _selectedStatus,
                                    ),
                                    child: const Text('Recharger'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : sessions.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text(
                                    'Aucune session live trouvée.',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                itemCount: sessions.length,
                                itemBuilder: (context, index) {
                                  final s = sessions[index];
                                  final sessionId = s['id']?.toString();
                                  final title = (s['title'] ?? '').toString();
                                  final courseTitle =
                                      (s['course_title'] ?? '').toString();
                                  final providerName =
                                      (s['provider'] ?? '').toString();
                                  final startAt =
                                      (s['start_at'] ?? '').toString();
                                  final status =
                                      (s['status'] ?? '').toString();

                                  final statusLabel = _statusLabel(status);
                                  final statusColor = _statusColor(status);

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    color: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      title: Text(title),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (courseTitle.isNotEmpty)
                                            Text(
                                              courseTitle,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          if (providerName.isNotEmpty)
                                            Text(
                                              providerName,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          if (startAt.isNotEmpty)
                                            Text(
                                              startAt,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          Text(
                                            statusLabel,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: statusColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: sessionId == null
                                          ? null
                                          : _buildActions(
                                              context,
                                              provider,
                                              sessionId,
                                              status,
                                              providerName,
                                              title,
                                            ),
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActions(
    BuildContext context,
    AdminLiveSessionsProvider provider,
    String sessionId,
    String status,
    String providerName,
    String title,
  ) {
    final actions = <Widget>[];

    if (status == 'pending_approval') {
      actions.addAll([
        TextButton(
          onPressed: provider.isSaving
              ? null
              : () async {
                  final ok = await provider.updateStatus(
                    sessionId: sessionId,
                    status: 'approved',
                  );
                  if (!context.mounted) return;
                  if (!ok && provider.error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(provider.error!)),
                    );
                  }
                },
          child: const Text('Approuver'),
        ),
        TextButton(
          onPressed: provider.isSaving
              ? null
              : () async {
                  final ok = await provider.updateStatus(
                    sessionId: sessionId,
                    status: 'rejected',
                  );
                  if (!context.mounted) return;
                  if (!ok && provider.error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(provider.error!)),
                    );
                  }
                },
          child: const Text('Refuser'),
        ),
      ]);
    } else if (status == 'approved') {
      actions.add(
        TextButton(
          onPressed: provider.isSaving
              ? null
              : () async {
                  final ok = await provider.updateStatus(
                    sessionId: sessionId,
                    status: 'cancelled',
                  );
                  if (!context.mounted) return;
                  if (!ok && provider.error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(provider.error!)),
                    );
                  }
                },
          child: const Text('Annuler'),
        ),
      );
    } else if (status == 'running') {
      actions.addAll([
        TextButton(
          onPressed: () {
            final desc = '';
            final academiaSession = AcademiaSession(
              id: sessionId,
              type: SessionType.course,
              status: SessionStatus.running,
              provider: SessionProvider.livekit,
              title: title,
              description: desc.isNotEmpty ? desc : null,
              hostId: Supabase.instance.client.auth.currentUser?.id ?? '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AcademiaClassroomScreen(
                  session: academiaSession,
                  isHost: true,
                ),
              ),
            );
          },
          child: const Text('Rejoindre'),
        ),
        TextButton(
          onPressed: provider.isSaving
              ? null
              : () async {
                  final ok = await provider.updateStatus(
                    sessionId: sessionId,
                    status: 'ended',
                  );
                  if (!context.mounted) return;
                  if (!ok && provider.error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(provider.error!)),
                    );
                  }
                },
          child: const Text('Clôturer'),
        ),
        TextButton(
          onPressed: () async {
            await provider.loadParticipants(sessionId);
            if (!context.mounted) return;
            _showParticipantsDialog(context, provider, sessionId);
          },
          child: const Text('Participants'),
        ),
      ]);
    }

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: actions,
    );
  }

  Future<void> _showParticipantsDialog(
    BuildContext context,
    AdminLiveSessionsProvider provider,
    String sessionId,
  ) async {
    await provider.loadParticipants(sessionId);
    if (!context.mounted) return;

    final participants = provider.participants;

    // ignore: use_build_context_synchronously
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Participants de la session'),
          content: SizedBox(
            width: 420,
            child: participants.isEmpty
                ? const Text('Aucun participant enregistré pour cette session.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: participants.length,
                    itemBuilder: (context, index) {
                      final p = participants[index];
                      final userId = p['user_id']?.toString() ?? '';
                      final role = p['role']?.toString() ?? '';
                      final isBanned = p['is_banned'] == true;
                      final joinedAt = p['joined_at']?.toString() ?? '';

                      return ListTile(
                        title: Text('Utilisateur: $userId'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Rôle: $role'),
                            if (joinedAt.isNotEmpty)
                              Text(
                                'Rejoint: $joinedAt',
                                style: const TextStyle(fontSize: 12),
                              ),
                            Text(
                              isBanned ? 'Banni' : 'Autorisé',
                              style: TextStyle(
                                fontSize: 12,
                                color: isBanned
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF1EA75C),
                              ),
                            ),
                          ],
                        ),
                        trailing: isBanned
                            ? null
                            : TextButton(
                                onPressed: provider.isSaving
                                    ? null
                                    : () async {
                                        final ok = await provider.banUser(
                                          sessionId: sessionId,
                                          userId: userId,
                                        );
                                        if (!dialogContext.mounted) return;
                                        if (!ok && provider.error != null) {
                                          ScaffoldMessenger.of(dialogContext)
                                              .showSnackBar(
                                            SnackBar(
                                              content:
                                                  Text(provider.error!),
                                            ),
                                          );
                                        }
                                      },
                                child: const Text('Bannir'),
                              ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }
}
