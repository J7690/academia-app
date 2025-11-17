import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/admin_applications_provider.dart';
import 'admin_applications_screen.dart';
import 'admin_programs_screen.dart';
import 'admin_university_sites_screen.dart';
import 'admin_bobodo_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Consumer<AdminApplicationsProvider>(
        builder: (context, applicationsProvider, child) {
          final unread = applicationsProvider.unreadCount;
          return Scaffold(
            appBar: AppBar(
              title: const Text('Dashboard Admin'),
              actions: [
                IconButton(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout),
                  tooltip: 'Se déconnecter',
                ),
              ],
              bottom: TabBar(
                tabs: [
                  Tab(child: _AdminTabLabel(text: 'Candidatures', count: unread)),
                  const Tab(text: 'Programmes'),
                  const Tab(text: 'Mini-sites'),
                  const Tab(text: 'Bobodo'),
                ],
              ),
            ),
            body: const TabBarView(
              children: [
                AdminApplicationsScreen(),
                AdminProgramsScreen(),
                AdminUniversitySitesScreen(),
                AdminBobodoScreen(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AdminTabLabel extends StatelessWidget {
  final String text;
  final int count;

  const _AdminTabLabel({required this.text, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return Text(text);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            count > 9 ? '9+' : '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
