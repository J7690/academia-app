import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/credit_provider.dart';
import '../features/student/credit_store_screen.dart';

/// Petit chip affichant le solde de crédits Academia.
/// Tap → ouvre la boutique de crédits.
class CreditBalanceChip extends StatelessWidget {
  final VoidCallback? onTap;

  const CreditBalanceChip({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<CreditProvider>(
      builder: (context, prov, _) {
        if (!prov.initialized) {
          prov.loadBalance();
          return const SizedBox.shrink();
        }
        return GestureDetector(
          onTap: onTap ?? () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreditStoreScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: prov.balance > 0
                  ? const Color(0xFFFFF8E1)
                  : const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: prov.balance > 0
                    ? const Color(0xFFFFB300)
                    : const Color(0xFFE53935),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.diamond_rounded,
                  size: 16,
                  color: prov.balance > 0
                      ? const Color(0xFFFF8F00)
                      : const Color(0xFFE53935),
                ),
                const SizedBox(width: 4),
                Text(
                  '${prov.balance}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: prov.balance > 0
                        ? const Color(0xFFE65100)
                        : const Color(0xFFE53935),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
