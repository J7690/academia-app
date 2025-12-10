import 'package:flutter/material.dart';

import 'hero_studio_screen.dart';

class AdminHeroAccueilScreen extends StatelessWidget {
  const AdminHeroAccueilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hero / Accueil (TV)'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Landing publique'),
              Tab(text: 'Accueil étudiant'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            HeroStudioScreen(slot: 'landing_hero_main'),
            HeroStudioScreen(slot: 'student_home_hero_main'),
          ],
        ),
      ),
    );
  }
}
