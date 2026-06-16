import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/credit_provider.dart';
import '../../widgets/ligdicash_payment_sheet.dart';

/// Écran boutique de crédits Academia.
/// Affiche le solde, le bonus hebdo, les packs d'achat et l'historique.
class CreditStoreScreen extends StatefulWidget {
  const CreditStoreScreen({super.key});

  @override
  State<CreditStoreScreen> createState() => _CreditStoreScreenState();
}

class _CreditStoreScreenState extends State<CreditStoreScreen> {
  @override
  void initState() {
    super.initState();
    final prov = context.read<CreditProvider>();
    prov.loadAll();
    prov.loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crédits Academia'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Consumer<CreditProvider>(
        builder: (context, prov, _) {
          if (!prov.initialized) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: () async {
              await prov.loadAll();
              await prov.loadTransactions();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildBalanceCard(prov),
                const SizedBox(height: 16),
                _buildWeeklyBonusCard(prov),
                const SizedBox(height: 20),
                _buildSectionTitle('Acheter des crédits'),
                const SizedBox(height: 8),
                _buildPacksGrid(prov),
                const SizedBox(height: 20),
                _buildSectionTitle('Tarifs IA'),
                const SizedBox(height: 8),
                _buildPricingList(prov),
                const SizedBox(height: 20),
                _buildSectionTitle('Historique'),
                const SizedBox(height: 8),
                _buildTransactionsList(prov),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard(CreditProvider prov) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8F00), Color(0xFFFFA726)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.diamond_rounded, size: 40, color: Colors.white),
          const SizedBox(height: 8),
          Text(
            '${prov.balance}',
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const Text('crédits disponibles', style: TextStyle(fontSize: 14, color: Colors.white70)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem('Achetés', prov.totalPurchased, Icons.shopping_cart_outlined),
              _buildStatItem('Offerts', prov.totalGifted, Icons.card_giftcard),
              _buildStatItem('Utilisés', prov.totalConsumed, Icons.bolt),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.white70),
        const SizedBox(height: 2),
        Text('$value', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white60)),
      ],
    );
  }

  Widget _buildWeeklyBonusCard(CreditProvider prov) {
    final canClaim = prov.canClaimWeeklyBonus;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: canClaim ? const Color(0xFF2E7D32) : Colors.grey.shade300, width: 1.5),
      ),
      child: ListTile(
        leading: Icon(
          Icons.card_giftcard,
          color: canClaim ? const Color(0xFF2E7D32) : Colors.grey,
          size: 28,
        ),
        title: Text(
          canClaim ? 'Bonus hebdomadaire disponible !' : 'Bonus déjà réclamé',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: canClaim ? const Color(0xFF2E7D32) : Colors.grey,
          ),
        ),
        subtitle: Text(canClaim ? '+15 crédits gratuits' : 'Revenez la semaine prochaine'),
        trailing: canClaim
            ? ElevatedButton(
                onPressed: prov.isLoading ? null : () => _claimBonus(prov),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('Réclamer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              )
            : const Icon(Icons.check_circle, color: Colors.grey),
      ),
    );
  }

  Future<void> _claimBonus(CreditProvider prov) async {
    final result = await prov.claimWeeklyBonus();
    if (!mounted) return;
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('+${result['credits_added']} crédits offerts !'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error']?.toString() ?? 'Erreur'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF212121)));
  }

  Widget _buildPacksGrid(CreditProvider prov) {
    if (prov.packs.isEmpty) {
      return const Center(child: Text('Aucun pack disponible', style: TextStyle(color: Colors.grey)));
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: prov.packs.length,
      itemBuilder: (context, index) {
        final pack = prov.packs[index];
        return _buildPackCard(pack, prov);
      },
    );
  }

  Widget _buildPackCard(Map<String, dynamic> pack, CreditProvider prov) {
    final credits = (pack['credits'] as num?)?.toInt() ?? 0;
    final priceXof = (pack['price_xof'] as num?)?.toInt() ?? 0;
    final bonusPct = (pack['bonus_percent'] as num?)?.toInt() ?? 0;
    final name = pack['name']?.toString() ?? '';
    final code = pack['code']?.toString() ?? '';
    final totalCredits = credits + (bonusPct > 0 ? (credits * bonusPct / 100).round() : 0);

    return GestureDetector(
      onTap: () => _buyPack(code, priceXof, name, prov),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFB300), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.orange.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.diamond_rounded, size: 30, color: Color(0xFFFF8F00)),
            const SizedBox(height: 8),
            Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF212121))),
            const SizedBox(height: 4),
            Text(
              '$totalCredits crédits',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFFE65100)),
            ),
            if (bonusPct > 0) ...[
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '+$bonusPct% bonus',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32)),
                ),
              ),
            ],
            const Spacer(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF8F00),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$priceXof XOF',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _buyPack(String packCode, int priceXof, String packName, CreditProvider prov) async {
    // Créer un paiement via RPC puis ouvrir LigdiCash
    try {
      final resp = await Supabase.instance.client.rpc('app_student_create_profile_payment', params: {
        'p_payment_reason': 'credit_purchase',
        'p_amount_due': priceXof,
      });
      final data = resp as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${data?['error'] ?? 'Échec création paiement'}'), backgroundColor: Colors.red),
        );
        return;
      }
      final paymentId = data['payment_id']?.toString() ?? '';
      if (paymentId.isEmpty) return;

      if (!mounted) return;

      LigdiCashPaymentSheet.show(
        context: context,
        paymentType: 'application',
        paymentId: paymentId,
        amount: priceXof.toDouble(),
        description: 'Achat $packName — crédits Academia',
        onSuccess: () async {
          // Créditer les crédits
          final result = await prov.purchaseCredits(packCode, paymentId: paymentId);
          if (!mounted) return;
          if (result['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('+${result['credits_added']} crédits ajoutés !'),
                backgroundColor: const Color(0xFF2E7D32),
              ),
            );
            prov.loadTransactions();
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildPricingList(CreditProvider prov) {
    if (prov.actionPrices.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: prov.actionPrices.map((a) {
        final cost = (a['cost_credits'] as num?)?.toInt() ?? 0;
        final label = a['label']?.toString() ?? '';
        final desc = a['description']?.toString() ?? '';
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$cost',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFE65100)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    if (desc.isNotEmpty)
                      Text(desc, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTransactionsList(CreditProvider prov) {
    if (prov.transactions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('Aucune transaction', style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    return Column(
      children: prov.transactions.take(10).map((t) {
        final amount = (t['amount'] as num?)?.toInt() ?? 0;
        final type = t['transaction_type']?.toString() ?? '';
        final desc = t['description']?.toString() ?? '';
        final date = t['created_at']?.toString() ?? '';
        final isPositive = amount > 0;

        IconData icon;
        Color color;
        switch (type) {
          case 'purchase':
            icon = Icons.shopping_cart;
            color = const Color(0xFF2E7D32);
            break;
          case 'welcome_bonus':
          case 'weekly_bonus':
          case 'referral_bonus':
            icon = Icons.card_giftcard;
            color = const Color(0xFF1565C0);
            break;
          case 'refund':
            icon = Icons.undo;
            color = const Color(0xFF00838F);
            break;
          case 'consumption':
          default:
            icon = Icons.bolt;
            color = const Color(0xFFE65100);
            break;
        }

        String dateStr = '';
        final dt = DateTime.tryParse(date);
        if (dt != null) {
          dateStr = '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      desc.isNotEmpty ? desc : type,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (dateStr.isNotEmpty)
                      Text(dateStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              Text(
                '${isPositive ? '+' : ''}$amount',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isPositive ? const Color(0xFF2E7D32) : const Color(0xFFE53935),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
