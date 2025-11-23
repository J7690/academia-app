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
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
                color: const Color(0xFFFF3B30),
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
        _AdminStatusBadge(status: status),
      ],
    );
  }
}

class _AdminStatusBadge extends StatelessWidget {
  final String status;

  const _AdminStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = _adminStatusLabel(status);
    final color = _adminStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

String _adminStatusLabel(String? status) {
  switch (status) {
    case 'draft':
      return 'Brouillon';
    case 'submitted':
      return 'Soumise';
    case 'under_review':
      return 'En étude';
    case 'accepted':
      return 'Acceptée';
    case 'rejected':
      return 'Refusée';
    case 'canceled':
      return 'Annulée';
    default:
      return status ?? 'Inconnu';
  }
}

Color _adminStatusColor(String? status) {
  switch (status) {
    case 'draft':
      return const Color(0xFF9CA3AF);
    case 'submitted':
      return const Color(0xFF1EA75C);
    case 'under_review':
      return const Color(0xFFF59E0B);
    case 'accepted':
      return const Color(0xFFA3D65C);
    case 'rejected':
      return const Color(0xFFFF3B30);
    case 'canceled':
      return const Color(0xFF6B7280);
    default:
      return const Color(0xFF9CA3AF);
  }
}
