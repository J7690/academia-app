import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/admin_applications_provider.dart';
import 'admin_applications_screen.dart';
import 'admin_programs_screen.dart';
import 'admin_course_library_screen.dart';
import 'admin_university_sites_screen.dart';
import 'admin_bobodo_screen.dart';
import 'admin_landing_screen.dart';
import 'admin_student_home_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Consumer<AdminApplicationsProvider>(
        builder: (context, applicationsProvider, child) {
          final unread = applicationsProvider.unreadCount;
          return Scaffold(
            backgroundColor: const Color(0xFFF3F4F6),
            appBar: AppBar(
              elevation: 0,
              centerTitle: false,
              title: const Text('Dashboard Admin'),
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
              actions: [
                IconButton(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout),
                  tooltip: 'Se déconnecter',
                ),
              ],
              bottom: TabBar(
                isScrollable: true,
                indicator: BoxDecoration(
                  color: const Color(0xFF1EA75C),
                  borderRadius: BorderRadius.circular(999),
                ),
                indicatorPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withOpacity(0.85),
                tabs: [
                  Tab(child: _AdminTabLabel(text: 'Candidatures', count: unread)),
                  const Tab(text: 'Programmes'),
                  const Tab(text: 'Cours'),
                  const Tab(text: 'Mini-sites'),
                  const Tab(text: 'Bobodo'),
                  const Tab(text: 'Accueil étudiant'),
                  const Tab(text: 'Landing'),
                ],
              ),
            ),
            body: const TabBarView(
              children: [
                AdminApplicationsScreen(),
                AdminProgramsScreen(),
                AdminCourseLibraryScreen(),
                AdminUniversitySitesScreen(),
                AdminBobodoScreen(),
                AdminStudentHomeScreen(),
                AdminLandingScreen(),
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
            color: const Color(0xFFFF3B30),
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
