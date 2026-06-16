import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../providers/student_live_sessions_provider.dart';
import '../../live/academia_classroom_screen.dart';
import '../../../models/academia_session.dart';

class StudentLiveSessionsTab extends StatefulWidget {
  const StudentLiveSessionsTab({super.key});

  @override
  State<StudentLiveSessionsTab> createState() => _StudentLiveSessionsTabState();
}

class _StudentLiveSessionsTabState extends State<StudentLiveSessionsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentLiveSessionsProvider>().loadMySessions();
    });
  }

  Future<void> _openExternalUrl(String url) async {
    if (url.trim().isEmpty) return;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Consumer<StudentLiveSessionsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.sessions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.sessions.isEmpty) {
            return Center(
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
                      onPressed: provider.loadMySessions,
                      child: const Text('Recharger'),
                    ),
                  ],
                ),
              ),
            );
          }

          final sessions = provider.sessions;
          final width = MediaQuery.of(context).size.width;
          final crossAxisCount = width >= 1100
              ? 3
              : width >= 700
                  ? 2
                  : 1;

          return RefreshIndicator(
            onRefresh: provider.loadMySessions,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Mes lives & sessions en direct',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Retrouvez ici toutes les sessions live prévues pour vos cours en ligne.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                if (sessions.isEmpty)
                  const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
                        child: Text(
                          'Aucune session live n\'est planifiée pour le moment.',
                          style: TextStyle(fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: crossAxisCount == 1 ? 3.0 : 2.2,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final session = sessions[index];
                          final String? sessionId = session['id']?.toString();
                          final title = (session['title'] ?? '').toString();
                          final courseTitle = (session['course_title'] ?? '').toString();
                          final description = (session['description'] ?? '').toString();
                          final providerName = (session['provider'] ?? '').toString();
                          final joinUrl = (session['join_url'] ?? '').toString();
                          final replayUrl = (session['replay_video_url'] ?? '').toString();
                          final startAt = (session['start_at'] ?? '').toString();
                          final status = (session['status'] ?? '').toString();

                          final metaParts = <String>[];
                          if (courseTitle.isNotEmpty) metaParts.add(courseTitle);
                          if (providerName.isNotEmpty) metaParts.add(providerName);
                          if (startAt.isNotEmpty) metaParts.add(startAt);

                          final isLivekit =
                              providerName.toLowerCase().trim() == 'livekit' &&
                                  (sessionId != null && sessionId.isNotEmpty);
                          final urlToOpen = !isLivekit && joinUrl.isNotEmpty
                              ? joinUrl
                              : replayUrl;

                          final hasStatus = status.isNotEmpty;

                          return Card(
                            color: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title.isNotEmpty ? title : 'Session en direct',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (courseTitle.isNotEmpty)
                                    Text(
                                      courseTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  if (description.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                  if (metaParts.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      metaParts.join(' • '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  Row(
                                    children: [
                                      if (hasStatus)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blueGrey.withOpacity(0.06),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Text(
                                            status,
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      const Spacer(),
                                      if (status == 'ended' && replayUrl.isNotEmpty && !replayUrl.startsWith('recording:'))
                                        ElevatedButton.icon(
                                          onPressed: () => _openExternalUrl(replayUrl),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF6366F1),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          ),
                                          icon: const Icon(Icons.replay, size: 16),
                                          label: const Text('Voir le replay', style: TextStyle(fontSize: 12)),
                                        )
                                      else if (isLivekit && status != 'ended')
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            if (sessionId == null || sessionId.isEmpty) return;
                                            final academiaSession = AcademiaSession(
                                              id: sessionId,
                                              type: SessionType.course,
                                              status: SessionStatus.running,
                                              provider: SessionProvider.livekit,
                                              title: title,
                                              description: description.isNotEmpty ? description : null,
                                              hostId: '',
                                              createdAt: DateTime.now(),
                                              updatedAt: DateTime.now(),
                                            );
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => AcademiaClassroomScreen(
                                                  session: academiaSession,
                                                  isHost: false,
                                                ),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: status == 'running'
                                                ? const Color(0xFFEF4444)
                                                : const Color(0xFF1EA75C),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          ),
                                          icon: Icon(status == 'running' ? Icons.videocam : Icons.login, size: 16),
                                          label: Text(
                                            status == 'running' ? 'LIVE' : 'Rejoindre',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        )
                                      else if (urlToOpen.isNotEmpty)
                                        ElevatedButton(
                                          onPressed: () => _openExternalUrl(urlToOpen),
                                          child: Text(joinUrl.isNotEmpty ? 'Rejoindre' : 'Voir le replay'),
                                        )
                                      else if (status == 'ended')
                                        const Text('Replay en préparation...', style: TextStyle(fontSize: 11, color: Colors.grey))
                                      else
                                        const Text('Lien non disponible', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: sessions.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
