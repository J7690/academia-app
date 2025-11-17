import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_applications_provider.dart';
import 'admin_application_detail_screen.dart';

class AdminApplicationsScreen extends StatefulWidget {
  const AdminApplicationsScreen({super.key});

  @override
  State<AdminApplicationsScreen> createState() => _AdminApplicationsScreenState();
}

class _AdminApplicationsScreenState extends State<AdminApplicationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminApplicationsProvider>().loadApplications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminApplicationsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.applications.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(provider.error!),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: provider.loadApplications,
                  child: const Text('Recharger'),
                ),
              ],
            ),
          );
        }

        final applications = provider.applications;
        if (applications.isEmpty) {
          return const Center(
            child: Text('Aucune candidature pour le moment.'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: applications.length,
          itemBuilder: (context, index) {
            final app = applications[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AdminApplicationDetailScreen(application: app),
                    ),
                  );
                },
                leading: _AdminApplicationLeading(application: app),
                title: Text(
                  app['program_title']?.toString() ?? 'Programme inconnu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app['university_name']?.toString() ?? ''),
                    Text('Étudiant : ${app['student_full_name'] ?? ''}'),
                    if (app['last_message_at'] != null)
                      Text('Dernier message : ${app['last_message_at']}'),
                  ],
                ),
                trailing: _AdminStatusAndUnread(application: app),
              ),
            );
          },
        );
      },
    );
  }
}

class _AdminApplicationLeading extends StatelessWidget {
  final Map<String, dynamic> application;

  const _AdminApplicationLeading({required this.application});

  @override
  Widget build(BuildContext context) {
    final hasUnread = application['has_unread_for_admin'] == true;
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

class _AdminStatusAndUnread extends StatelessWidget {
  final Map<String, dynamic> application;

  const _AdminStatusAndUnread({required this.application});

  @override
  Widget build(BuildContext context) {
    final status = application['status']?.toString() ?? '';
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(status),
      ],
    );
  }
}
