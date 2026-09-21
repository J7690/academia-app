import 'package:flutter/material.dart';

import '../student_documents_screen.dart';

/// Onglet « Mes documents » dans la barre de navigation étudiante.
///
/// Réutilise l'écran existant en mode onglet (sans bouton « Retour »).
class StudentDocumentsTab extends StatelessWidget {
  const StudentDocumentsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const StudentDocumentsScreen();
  }
}
