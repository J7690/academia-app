import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/university_applications_provider.dart';
import '../../providers/selected_university_application_provider.dart';

class UniversityApplicationsScreen extends StatefulWidget {
  const UniversityApplicationsScreen({super.key});

  @override
  State<UniversityApplicationsScreen> createState() => _UniversityApplicationsScreenState();
}

class _UniversityApplicationsScreenState extends State<UniversityApplicationsScreen> {
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UniversityApplicationsProvider>().loadApplications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<UniversityApplicationsProvider, SelectedUniversityApplicationProvider>(
      builder: (context, applicationsProvider, selectionProvider, child) {
        if (applicationsProvider.isLoading && applicationsProvider.applications.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (applicationsProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(applicationsProvider.error!),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: applicationsProvider.loadApplications,
                  child: const Text('Recharger'),
                ),
              ],
            ),
          );
        }

        final allApplications = applicationsProvider.applications;

        if (allApplications.isEmpty) {
          return const Center(
            child: Text('Aucune candidature reçue pour le moment.'),
          );
        }

        final applications = _statusFilter == null
            ? allApplications
            : allApplications
                .where((app) =>
                    (app['status']?.toString().toLowerCase() ?? '') == _statusFilter)
                .toList();

        if (applications.isNotEmpty && selectionProvider.selectedApplication == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            selectionProvider.selectApplication(applications.first);
          });
        }

        return Column(
          children: [
            _UniversityStatusFilterBar(
              currentFilter: _statusFilter,
              onFilterChanged: (value) {
                setState(() {
                  _statusFilter = value;
                });
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: applications.length,
                itemBuilder: (context, index) {
                  final app = applications[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      onTap: () {
                        selectionProvider.selectApplication(app);
                      },
                      leading: _UniversityApplicationLeading(application: app),
                      title: Text(
                        app['program_title']?.toString() ?? 'Programme inconnu',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Étudiant : ${app['student_full_name'] ?? ''}'),
                          if (app['last_message_at'] != null)
                            Text('Dernier message : ${app['last_message_at']}'),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _UniversityApplicationLeading extends StatelessWidget {
  final Map<String, dynamic> application;

  const _UniversityApplicationLeading({required this.application});

  @override
  Widget build(BuildContext context) {
    final hasUnread = application['has_unread_for_university'] == true;
    return Stack(
      children: [
        const Icon(Icons.assignment),
        if (hasUnread)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class _UniversityStatusFilterBar extends StatelessWidget {
  final String? currentFilter;
  final ValueChanged<String?> onFilterChanged;

  const _UniversityStatusFilterBar({
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    const statuses = <String?>[
      null,
      'submitted',
      'under_review',
      'accepted',
      'rejected',
      'canceled',
    ];

    String _labelFor(String? status) {
      switch (status) {
        case 'submitted':
          return 'Soumises';
        case 'under_review':
          return 'En étude';
        case 'accepted':
          return 'Acceptées';
        case 'rejected':
          return 'Refusées';
        case 'canceled':
          return 'Annulées';
        default:
          return 'Toutes';
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: statuses.map((status) {
          final selected = currentFilter == status;
          final label = _labelFor(status);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) => onFilterChanged(status),
            ),
          );
        }).toList(),
      ),
    );
  }
}
