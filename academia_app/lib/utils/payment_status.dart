import 'package:flutter/material.dart';

String paymentStatusLabel(String? status) {
  switch (status) {
    case 'pending':
      return 'Paiement en attente';
    case 'declared_by_student':
      return 'Paiement déclaré — en vérification';
    case 'under_verification':
      return 'Paiement en cours de vérification';
    case 'confirmed':
      return 'Paiement confirmé';
    case 'rejected':
      return 'Paiement refusé';
    default:
      return 'Statut inconnu';
  }
}

Color paymentStatusColor(String? status) {
  switch (status) {
    case 'pending':
      return const Color(0xFFB45309);
    case 'declared_by_student':
    case 'under_verification':
      return const Color(0xFF2563EB);
    case 'confirmed':
      return const Color(0xFF1EA75C);
    case 'rejected':
      return const Color(0xFFDC2626);
    default:
      return const Color(0xFF6B7280);
  }
}
