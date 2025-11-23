import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/student_applications_provider.dart';
import 'tabs/student_home_tab.dart';
import 'tabs/student_applications_tab.dart';
import 'tabs/student_partners_tab.dart';
import 'tabs/student_courses_tab.dart';
import 'tabs/student_bobodo_tab.dart';

/// Dashboard étudiant avec onglets principaux
class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _ensureStudentProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        // Précharger les candidatures pour que le badge soit à jour
        context.read<StudentApplicationsProvider>().loadApplications();
      } catch (_) {}
    });
  }

  void _ensureStudentProfile() async {
    final client = Supabase.instance.client;
    try {
      await client.rpc('app_ensure_student_profile');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      const StudentHomeTab(),
      const StudentApplicationsTab(),
      const StudentPartnersTab(),
      const StudentCoursesTab(),
      const StudentBobodoTab(),
    ];

    return Consumer<StudentApplicationsProvider>(
      builder: (context, applicationsProvider, child) {
        final unread = applicationsProvider.unreadCount;
        return Scaffold(
          backgroundColor: const Color(0xFFF3F4F6),
          body: tabs[_currentIndex],
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFA3D65C), Color(0xFF1EA75C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: NavigationBar(
              backgroundColor: Colors.transparent,
              indicatorColor: Colors.white.withOpacity(0.2),
              height: 52,
              labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Accueil',
              ),
              NavigationDestination(
                icon: _NavBadgeIcon(
                  icon: Icons.assignment_outlined,
                  count: unread,
                ),
                selectedIcon: _NavBadgeIcon(
                  icon: Icons.assignment,
                  count: unread,
                ),
                label: 'Candidatures',
              ),
              const NavigationDestination(
                icon: Icon(Icons.apartment_outlined),
                selectedIcon: Icon(Icons.apartment),
                label: 'Universités',
              ),
              const NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book),
                label: 'Cours',
              ),
              const NavigationDestination(
                icon: Icon(Icons.smart_toy_outlined),
                selectedIcon: Icon(Icons.smart_toy),
                label: 'Bobodo',
              ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NavBadgeIcon extends StatelessWidget {
  final IconData icon;
  final int count;

  const _NavBadgeIcon({required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return Icon(icon);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Color(0xFFFF3B30),
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
            child: Center(
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
