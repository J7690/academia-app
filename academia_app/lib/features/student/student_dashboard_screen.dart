import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

    return Scaffold(
      body: tabs[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Candidatures',
          ),
          NavigationDestination(
            icon: Icon(Icons.apartment_outlined),
            selectedIcon: Icon(Icons.apartment),
            label: 'Universités',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Cours',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy),
            label: 'Bobodo',
          ),
        ],
      ),
    );
  }
}
