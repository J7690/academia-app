import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/student_academic_calendar_provider.dart';

class StudentAcademicCalendarScreen extends StatefulWidget {
  const StudentAcademicCalendarScreen({super.key});

  @override
  State<StudentAcademicCalendarScreen> createState() => _StudentAcademicCalendarScreenState();
}

class _StudentAcademicCalendarScreenState extends State<StudentAcademicCalendarScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<StudentAcademicCalendarProvider>();
      provider.loadEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendrier académique'),
      ),
      body: Consumer<StudentAcademicCalendarProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingEvents && provider.events.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.events.isEmpty) {
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
                      onPressed: () => provider.loadEvents(),
                      child: const Text('Recharger'),
                    ),
                  ],
                ),
              ),
            );
          }

          final events = provider.events;
          if (events.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Aucun événement académique enregistré pour le moment.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final e = events[index];
              final title = e['title']?.toString() ?? '';
              final description = (e['description']?.toString() ?? '').trim();
              final type = (e['event_type']?.toString() ?? '').trim();
              final location = (e['location']?.toString() ?? '').trim();
              final city = (e['city']?.toString() ?? '').trim();
              final startAt = e['start_at']?.toString() ?? '';
              final endAt = e['end_at']?.toString() ?? '';

              final isAllDay = e['is_all_day'] == true;

              String dateLine = '';
              if (startAt.isNotEmpty && endAt.isNotEmpty) {
                dateLine = isAllDay
                    ? 'Du $startAt au $endAt (toute la journée)'
                    : '$startAt — $endAt';
              } else if (startAt.isNotEmpty) {
                dateLine = isAllDay ? '$startAt (toute la journée)' : startAt;
              }

              final placeLine = [
                if (city.isNotEmpty) city,
                if (location.isNotEmpty) location,
              ].join(' · ');

              Color chipColor;
              String chipText;
              switch (type.toLowerCase()) {
                case 'exam':
                  chipColor = const Color(0xFFDC2626);
                  chipText = 'Examen';
                  break;
                case 'registration':
                  chipColor = const Color(0xFF2563EB);
                  chipText = 'Inscriptions';
                  break;
                case 'holiday':
                  chipColor = const Color(0xFF16A34A);
                  chipText = 'Vacances';
                  break;
                case 'scholarship':
                  chipColor = const Color(0xFFF97316);
                  chipText = 'Bourse';
                  break;
                default:
                  chipColor = const Color(0xFF6B7280);
                  chipText = type.isEmpty ? 'Événement' : type;
              }

              final preview = description.isNotEmpty
                  ? (description.length > 160
                      ? '${description.substring(0, 160)}…'
                      : description)
                  : '';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
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
                              title.isEmpty ? 'Événement académique' : title,
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
                      if (dateLine.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          dateLine,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                      if (placeLine.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          placeLine,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                      if (preview.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          preview,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ],
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
