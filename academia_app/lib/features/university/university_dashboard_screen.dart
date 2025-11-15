import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UniversityDashboardScreen extends StatelessWidget {
  const UniversityDashboardScreen({super.key});

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Université'),
        actions: [
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Espace université partenaire (à compléter).',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
