import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/subscription_provider.dart';
import 'ligdicash_payment_sheet.dart';

/// Overlay paywall qui s'affiche quand l'utilisateur n'a pas d'abonnement premium.
/// Affiche les plans disponibles et permet de s'abonner via LigdiCash.
///
/// Usage :
/// ```dart
/// PaywallOverlay(
///   feature: 'prep_concours',
///   child: StudentPrepConcoursScreen(),
/// )
/// ```
class PaywallOverlay extends StatefulWidget {
  final String feature;
  final Widget child;
  final String? title;
  final String? subtitle;

  const PaywallOverlay({
    super.key,
    required this.feature,
    required this.child,
    this.title,
    this.subtitle,
  });

  @override
  State<PaywallOverlay> createState() => _PaywallOverlayState();
}

class _PaywallOverlayState extends State<PaywallOverlay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SubscriptionProvider>();
      if (!provider.initialized) {
        provider.loadActiveSubscription();
      }
      if (provider.plans.isEmpty) {
        provider.loadPlans();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, provider, _) {
        // Pas encore chargé — montrer le contenu avec un loader
        if (!provider.initialized || provider.isLoading) {
          return widget.child;
        }

        // A accès — montrer le contenu
        if (provider.hasFeatureAccess(widget.feature)) {
          return widget.child;
        }

        // Pas d'accès — montrer le paywall
        return _PaywallScreen(
          feature: widget.feature,
          title: widget.title,
          subtitle: widget.subtitle,
          provider: provider,
        );
      },
    );
  }
}

class _PaywallScreen extends StatelessWidget {
  final String feature;
  final String? title;
  final String? subtitle;
  final SubscriptionProvider provider;

  const _PaywallScreen({
    required this.feature,
    this.title,
    this.subtitle,
    required this.provider,
  });

  String _featureTitle(String feature) {
    switch (feature) {
      case 'prep_concours':
        return 'Préparation Concours';
      case 'ia_tuteur_illimite':
        return 'IA Tuteur Illimité';
      case 'jeux_complets':
        return 'Jeux Éducatifs Complets';
      case 'lives_prioritaires':
        return 'Lives Prioritaires';
      case 'td_illimite':
        return 'TD Illimité';
      default:
        return 'Fonctionnalité Premium';
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = provider.plans;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 32),

              // Lock icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFB020), Color(0xFFFF8C00)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF8C00).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.workspace_premium, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 20),

              Text(
                title ?? 'Contenu Premium',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle ?? 'Débloque ${_featureTitle(feature)} avec un abonnement Academia Premium.',
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // Features list
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Inclus dans Premium',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                    const SizedBox(height: 14),
                    _featureRow(Icons.school, 'Préparation Concours illimitée'),
                    _featureRow(Icons.smart_toy, 'IA Tuteur sans limite'),
                    _featureRow(Icons.sports_esports, 'Jeux éducatifs complets'),
                    _featureRow(Icons.cast_for_education, 'Accès prioritaire aux Lives'),
                    _featureRow(Icons.picture_as_pdf, 'Reçus de paiement PDF'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Plans
              if (plans.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                ...plans.map((plan) => _planCard(context, plan)),

              const SizedBox(height: 16),

              // Back button
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Retour', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF16A34A), size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14, color: Color(0xFF334155))),
          ),
        ],
      ),
    );
  }

  Widget _planCard(BuildContext context, Map<String, dynamic> plan) {
    final code = plan['code']?.toString() ?? '';
    final name = plan['name']?.toString() ?? '';
    final rawPrice = plan['price'];
    double basePrice = 0;
    if (rawPrice is num) basePrice = rawPrice.toDouble();
    final currency = plan['currency']?.toString() ?? 'XOF';
    final durationDays = plan['duration_days'] as int? ?? 30;
    final promoPercent = plan['promo_percent'] as int? ?? 0;
    final effectiveP = provider.effectivePrice(plan);
    final hasPromo = promoPercent > 0 && effectiveP < basePrice;

    final isAnnual = durationDays >= 365;
    final accentColor = isAnnual ? const Color(0xFFFF8C00) : const Color(0xFF1EA75C);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isAnnual ? const Color(0xFFFFB020) : const Color(0xFFE2E8F0), width: isAnnual ? 2 : 1),
        boxShadow: isAnnual
            ? [BoxShadow(color: const Color(0xFFFFB020).withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _subscribe(context, plan),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: accentColor)),
                          if (isAnnual) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB020).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Populaire', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFFF8C00))),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        durationDays >= 365 ? 'Accès pendant 1 an' : 'Accès pendant ${durationDays}j',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (hasPromo)
                      Text(
                        '${basePrice.toStringAsFixed(0)} $currency',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), decoration: TextDecoration.lineThrough),
                      ),
                    Text(
                      '${effectiveP.toStringAsFixed(0)} $currency',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: accentColor),
                    ),
                    if (hasPromo)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('-$promoPercent%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.red.shade700)),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios, size: 16, color: accentColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _subscribe(BuildContext context, Map<String, dynamic> plan) async {
    final code = plan['code']?.toString() ?? '';
    final result = await provider.createSubscriptionPayment(code);

    if (!context.mounted) return;

    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']?.toString() ?? 'Erreur')),
      );
      return;
    }

    final paymentId = result['payment_id']?.toString() ?? '';
    final amount = result['amount'] as double? ?? 0;
    final planName = result['plan_name']?.toString() ?? 'Abonnement';

    if (paymentId.isEmpty || amount <= 0) return;

    await LigdiCashPaymentSheet.show(
      context: context,
      paymentType: 'subscription',
      paymentId: paymentId,
      amount: amount,
      description: 'Abonnement $planName',
      onSuccess: () {
        // Recharger l'abonnement actif
        provider.loadActiveSubscription();
      },
    );
  }
}
