import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/student_announcements_provider.dart';

class StudentAnnouncementsScreen extends StatefulWidget {
  const StudentAnnouncementsScreen({super.key});

  @override
  State<StudentAnnouncementsScreen> createState() => _StudentAnnouncementsScreenState();
}

class _StudentAnnouncementsScreenState extends State<StudentAnnouncementsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentAnnouncementsProvider>().loadAnnouncements(limit: 50);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Annonces officielles'),
      ),
      body: Consumer<StudentAnnouncementsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.announcements.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.announcements.isEmpty) {
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
                      onPressed: () => provider.loadAnnouncements(limit: 50),
                      child: const Text('Recharger'),
                    ),
                  ],
                ),
              ),
            );
          }

          final announcements = provider.announcements;
          if (announcements.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Aucune annonce officielle pour le moment.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: announcements.length,
            itemBuilder: (context, index) {
              final a = announcements[index];
              final id = a['id']?.toString();
              final title = a['title']?.toString() ?? '';
              final summary = (a['summary']?.toString() ?? '').trim();
              final body = (a['body']?.toString() ?? '').trim();
              final urgency = (a['urgency_level']?.toString() ?? 'info').toLowerCase();
              final createdAt = a['created_at']?.toString() ?? '';
              final isRead = a['is_read'] == true;

              Color chipColor;
              String chipText;
              if (urgency == 'critical') {
                chipColor = const Color(0xFFDC2626);
                chipText = 'Critique';
              } else if (urgency == 'important') {
                chipColor = const Color(0xFFF97316);
                chipText = 'Important';
              } else {
                chipColor = const Color(0xFF3B82F6);
                chipText = 'Info';
              }

              final preview = summary.isNotEmpty
                  ? summary
                  : (body.length > 160 ? '${body.substring(0, 160)}…' : body);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () async {
                    if (id != null && id.isNotEmpty) {
                      await provider.markAnnouncementRead(id);
                    }
                    if (!context.mounted) return;
                    await showDialog<void>(
                      context: context,
                      builder: (ctx) {
                        return AlertDialog(
                          title: Text(title.isEmpty ? 'Annonce officielle' : title),
                          content: SingleChildScrollView(
                            child: Text(body.isEmpty ? preview : body),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Fermer'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                title.isEmpty ? 'Annonce officielle' : title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Chip(
                              label: Text(
                                chipText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                              backgroundColor: chipColor,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (preview.isNotEmpty)
                          Text(
                            preview,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        if (createdAt.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            createdAt,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                        if (!isRead) ...[
                          const SizedBox(height: 4),
                          const Text(
                            'Non lue',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
