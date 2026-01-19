import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/commercial_dashboard_provider.dart';

/// Tableau de bord minimal pour les comptes commerciaux.
/// Logique métier limitée : l'essentiel viendra des RPC côté Supabase.
class CommercialDashboardScreen extends StatefulWidget {
  const CommercialDashboardScreen({super.key});

  @override
  State<CommercialDashboardScreen> createState() => _CommercialDashboardScreenState();
}

class _CommercialDashboardScreenState extends State<CommercialDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CommercialDashboardProvider>().loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommercialDashboardProvider>();
    final profile = provider.profile;
    final summary = provider.summary;

    Widget body;

    if (provider.isLoading && profile == null && summary == null) {
      body = const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (provider.error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                provider.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: provider.isLoading
                    ? null
                    : () => provider.loadDashboard(),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    } else if (profile == null || summary == null) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Aucune donnée commerciale disponible pour le moment.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      final refCode = (profile['ref_code'] ?? '').toString();
      final refLink = (profile['ref_link'] ?? '').toString();
      final studentsCount = summary['students_count'] ?? 0;
      final paymentsConfirmedCount = summary['payments_confirmed_count'] ?? 0;
      final totalPending = summary['total_commission_pending'] ?? 0;
      final totalPaid = summary['total_commission_paid'] ?? 0;
      final referrals = provider.referrals;
      final commissions = provider.commissions;

      body = SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Votre lien de parrainage',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (refCode.isNotEmpty)
                      Text(
                        'Code : $refCode',
                        style: const TextStyle(fontSize: 14),
                      ),
                    if (refLink.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        refLink,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Résumé des performances',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Étudiants référés'),
                              const SizedBox(height: 4),
                              Text(
                                studentsCount.toString(),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Paiements confirmés'),
                              const SizedBox(height: 4),
                              Text(
                                paymentsConfirmedCount.toString(),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Commissions en attente'),
                              const SizedBox(height: 4),
                              Text(
                                totalPending.toString(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Commissions payées'),
                              const SizedBox(height: 4),
                              Text(
                                totalPaid.toString(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Étudiants référés',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (referrals.isEmpty)
                      const Text(
                        'Aucun étudiant rattaché pour le moment.',
                        style: TextStyle(fontSize: 13),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: referrals.length,
                        itemBuilder: (context, index) {
                          final ref = referrals[index];
                          final studentId =
                              (ref['student_id'] ?? '').toString();
                          final attributedAt =
                              (ref['attributed_at'] ?? '').toString();
                          final expiresAt =
                              (ref['expires_at'] ?? '').toString();

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Étudiant : $studentId',
                              style: const TextStyle(fontSize: 13),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (attributedAt.isNotEmpty)
                                  Text(
                                    'Attribué le : $attributedAt',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                if (expiresAt.isNotEmpty)
                                  Text(
                                    'Expire le : $expiresAt',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Commissions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (commissions.isEmpty)
                      const Text(
                        'Aucune commission générée pour le moment.',
                        style: TextStyle(fontSize: 13),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: commissions.length,
                        itemBuilder: (context, index) {
                          final c = commissions[index];
                          final studentId =
                              (c['student_id'] ?? '').toString();
                          final amount = c['commission_amount'] ?? 0;
                          final currency =
                              (c['currency'] ?? '').toString();
                          final status =
                              (c['status'] ?? '').toString();
                          final createdAt =
                              (c['created_at'] ?? '').toString();

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Étudiant : $studentId',
                              style: const TextStyle(fontSize: 13),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Montant : $amount $currency',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  'Statut : $status',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                if (createdAt.isNotEmpty)
                                  Text(
                                    'Créée le : $createdAt',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Espace commercial'),
      ),
      body: body,
    );
  }
}
