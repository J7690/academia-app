import 'package:flutter/material.dart';

/// Libellés et couleurs de statut de candidature, partagés entre la liste
/// et l'écran de détail.
String adminStatusLabel(String? status) {
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
      return (status == null || status.isEmpty) ? 'Inconnu' : status;
  }
}

Color adminStatusColor(String? status) {
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
