import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/credit_provider.dart';
import '../features/student/credit_store_screen.dart';

/// Dialogue affiché quand l'étudiant n'a pas assez de crédits pour une action IA.
/// Montre le solde actuel, le coût requis, et un bouton pour aller à la boutique.
class InsufficientCreditsDialog {
  /// Affiche le dialogue. Retourne true si l'utilisateur va à la boutique.
  static Future<bool> show({
    required BuildContext context,
    required int balance,
    required int cost,
    String? actionLabel,
  }) async {
    final deficit = cost - balance;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(Icons.diamond_rounded, size: 30, color: Color(0xFFE65100)),
              ),
              const SizedBox(height: 14),
              const Text(
                'Crédits insuffisants',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF212121)),
              ),
              const SizedBox(height: 8),
              if (actionLabel != null && actionLabel.isNotEmpty)
                Text(
                  actionLabel,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildCreditBadge('Solde', balance, const Color(0xFFE53935)),
                  const SizedBox(width: 12),
                  const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                  const SizedBox(width: 12),
                  _buildCreditBadge('Requis', cost, const Color(0xFFE65100)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Il vous manque $deficit crédits',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFE53935)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Achetez des crédits à partir de 100 XOF\nou réclamez votre bonus hebdomadaire gratuit.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Fermer', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(ctx).pop(true),
              icon: const Icon(Icons.shopping_cart, size: 16),
              label: const Text('Acheter des crédits'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8F00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        );
      },
    );

    if (result == true && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CreditStoreScreen()),
      );
      return true;
    }
    return false;
  }

  static Widget _buildCreditBadge(String label, int value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.diamond_rounded, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                '$value',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Méthode utilitaire : vérifie les crédits et affiche le dialogue si insuffisant.
  /// Retourne true si l'action peut être exécutée (assez de crédits).
  static Future<bool> checkAndShowIfNeeded({
    required BuildContext context,
    required String actionCode,
  }) async {
    final prov = context.read<CreditProvider>();
    final result = await prov.checkAccess(actionCode);

    if (result['success'] != true) return false;

    if (result['allowed'] == true) {
      return true;
    }

    // Pas assez de crédits → afficher le dialogue
    if (!context.mounted) return false;
    await show(
      context: context,
      balance: (result['balance'] as num?)?.toInt() ?? 0,
      cost: (result['cost'] as num?)?.toInt() ?? 0,
      actionLabel: prov.labelForAction(actionCode),
    );
    // Recharger le solde après retour de la boutique
    await prov.loadBalance();
    return false;
  }
}
