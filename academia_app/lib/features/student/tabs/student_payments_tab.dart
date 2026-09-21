import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../providers/student_application_payments_provider.dart';
import '../../../providers/student_applications_provider.dart';
import '../../../utils/payment_status.dart';
import '../../../widgets/app_snack.dart';
import '../../../widgets/ligdicash_payment_sheet.dart';
import '../../share/share_mode_provider.dart';
import '../student_application_detail_screen.dart';

/// Onglet « Mes paiements » — uniquement les candidatures acceptées avec un
/// taux de réduction fixé, donc éligibles au paiement des frais de courtage.
class StudentPaymentsTab extends StatefulWidget {
  const StudentPaymentsTab({super.key});

  @override
  State<StudentPaymentsTab> createState() => _StudentPaymentsTabState();
}

class _StudentPaymentsTabState extends State<StudentPaymentsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
    });
  }

  Future<void> _load() async {
    final applicationsProvider = context.read<StudentApplicationsProvider>();
    final paymentsProvider = context.read<StudentApplicationPaymentsProvider>();
    try {
      await applicationsProvider.loadApplications();
    } catch (_) {}
    try {
      await paymentsProvider.loadMyPayments();
    } catch (_) {}
  }

  List<Map<String, dynamic>> _eligibleApplications(
    List<Map<String, dynamic>> applications,
  ) {
    return applications.where((app) {
      final status = app['status']?.toString();
      if (status != 'accepted') return false;
      final discountRate = app['discount_rate'];
      if (discountRate == null) return false;
      final numeric = discountRate is num
          ? discountRate.toDouble()
          : double.tryParse(discountRate.toString());
      return numeric != null && numeric >= 0;
    }).toList();
  }

  Map<String, dynamic>? _paymentForApplication(
    List<Map<String, dynamic>> payments,
    String applicationId,
  ) {
    for (final payment in payments) {
      if (payment['application_id']?.toString() == applicationId &&
          payment['payment_reason']?.toString() == 'application_fee') {
        return payment;
      }
    }
    return null;
  }

  Future<void> _openPaymentFlow(
    BuildContext context,
    Map<String, dynamic> application,
  ) async {
    final appId = application['id']?.toString() ?? '';
    final paymentsProvider = context.read<StudentApplicationPaymentsProvider>();

    if (!context.mounted) return;

    double amountDue = 0;
    try {
      final feeResp = await _AppServices.feeForApplication(appId);
      final feeData = feeResp as Map<String, dynamic>?;
      if (feeData == null || feeData['success'] != true) {
        if (!context.mounted) return;
        AppSnack.error(
          context,
          feeData?['error']?.toString() ?? 'Erreur récupération tarif',
        );
        return;
      }
      final brokerageFee = (feeData['brokerage_fee'] as num?)?.toDouble() ?? 0;
      if (brokerageFee <= 0) {
        if (!context.mounted) return;
        AppSnack.error(context, 'Les frais de courtage ne sont pas encore définis.');
        return;
      }
      amountDue = brokerageFee;
    } catch (e) {
      if (!context.mounted) return;
      AppSnack.error(context, e);
      return;
    }

    String paymentId = '';
    final payments = paymentsProvider.payments;
    Map<String, dynamic>? existingPending;
    try {
      existingPending = payments.firstWhere(
        (p) =>
            p['application_id']?.toString() == appId &&
            p['payment_reason']?.toString() == 'application_fee',
      );
    } catch (_) {}

    if (existingPending != null) {
      final status = existingPending['status']?.toString();
      if (status == 'pending') {
        paymentId = existingPending['id']?.toString() ?? '';
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ce paiement est déjà en statut « ${paymentStatusLabel(status)} ».',
            ),
          ),
        );
        return;
      }
    } else {
      try {
        final resp = await _AppServices.createApplicationPayment(
          appId,
          amountDue,
        );
        final data = resp as Map<String, dynamic>?;
        if (data == null || data['success'] != true) {
          if (!context.mounted) return;
          final phrase = (data?['message']?.toString() ?? '').trim();
          final code = (data?['error']?.toString() ?? '').trim();
          AppSnack.error(
            context,
            phrase.isNotEmpty
                ? phrase
                : (code.isEmpty
                    ? 'Le paiement n\'a pas pu être ouvert.'
                    : 'Le paiement n\'a pas pu être ouvert ($code).'),
          );
          return;
        }
        paymentId = data['payment_id']?.toString() ?? '';
      } catch (e) {
        if (!context.mounted) return;
        AppSnack.error(context, e);
        return;
      }
    }

    if (paymentId.isEmpty || !context.mounted) return;

    await LigdiCashPaymentSheet.show(
      context: context,
      paymentType: 'application',
      paymentId: paymentId,
      amount: amountDue,
      description: 'Frais de courtage — candidature',
      onSuccess: () {
        paymentsProvider.loadMyPayments();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isShareMode = context.select<ShareModeProvider, bool>((p) => p.isShareModeEnabled);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes paiements'),
        bottom: isShareMode
            ? null
            : const PreferredSize(
                preferredSize: Size.fromHeight(1),
                child: Divider(height: 1),
              ),
      ),
      body: Consumer2<StudentApplicationsProvider, StudentApplicationPaymentsProvider>(
        builder: (context, applicationsProvider, paymentsProvider, child) {
          final isLoading = applicationsProvider.isLoading || paymentsProvider.isLoading;
          final error = applicationsProvider.error ?? paymentsProvider.error;
          final eligible = _eligibleApplications(applicationsProvider.applications);

          if (isLoading && eligible.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (error != null && eligible.isEmpty) {
            return _ErrorView(
              error: error,
              onRetry: _load,
            );
          }

          if (eligible.isEmpty) {
            return _EmptyView(onRefresh: _load);
          }

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const _InfoCard(),
                const SizedBox(height: 16),
                ...eligible.map((app) {
                  final payment = _paymentForApplication(
                    paymentsProvider.payments,
                    app['id']?.toString() ?? '',
                  );
                  return _ApplicationPaymentCard(
                    application: app,
                    payment: payment,
                    onPay: () => _openPaymentFlow(context, app),
                    onDetail: () => _openDetail(context, app, payment),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openDetail(
    BuildContext context,
    Map<String, dynamic> application,
    Map<String, dynamic>? payment,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => StudentApplicationPaymentsProvider(),
          child: StudentApplicationDetailScreen(
            application: application,
            initialTabIndex: 1,
          ),
        ),
      ),
    );
  }
}

class _AppServices {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<dynamic> feeForApplication(String applicationId) async {
    return _client.rpc(
      'app_get_program_brokerage_fee',
      params: {'p_application_id': applicationId},
    );
  }

  static Future<dynamic> createApplicationPayment(
    String applicationId,
    double amount,
  ) async {
    return _client.rpc(
      'app_create_application_payment',
      params: {
        'p_application_id': applicationId,
        'p_payment_reason': 'application_fee',
        'p_amount_due': amount,
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comment payer les frais de courtage ?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          SizedBox(height: 10),
          _Step(number: 1, text: 'Choisis une candidature acceptée ci-dessous.'),
          _Step(number: 2, text: 'Appuie sur « Payer ». Le montant est fixé par Academia.'),
          _Step(number: 3, text: 'Saisis ton numéro de téléphone et valide avec l\'OTP.'),
          _Step(number: 4, text: 'Après confirmation, ton reçu et ton bon de courtage sont dans « Mes documents ».'),
          _Step(number: 5, text: 'Présente le reçu et le bon à la scolarité pour finaliser ton inscription.'),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFF1EA75C),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicationPaymentCard extends StatelessWidget {
  const _ApplicationPaymentCard({
    required this.application,
    this.payment,
    required this.onPay,
    required this.onDetail,
  });

  final Map<String, dynamic> application;
  final Map<String, dynamic>? payment;
  final VoidCallback onPay;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    final programTitle = application['program_title']?.toString() ??
        application['program']?['title']?.toString() ??
        'Formation';
    final universityName = application['university_name']?.toString() ??
        application['university']?['name']?.toString() ??
        'Université';
    final discountRate = application['discount_rate'];
    final discountText = discountRate == null
        ? ''
        : 'Réduction : ${(discountRate is num ? discountRate.toDouble() : double.tryParse(discountRate.toString()) ?? 0).toStringAsFixed(0)} %';
    final brokerageFee = application['brokerage_fee'];
    final amountText = brokerageFee == null
        ? 'Montant à définir'
        : '${NumberFormat.decimalPattern('fr').format(brokerageFee is num ? brokerageFee.toDouble() : double.tryParse(brokerageFee.toString()) ?? 0)} FCFA';

    final status = payment?['status']?.toString();
    final statusLabel = paymentStatusLabel(status);
    final statusColor = paymentStatusColor(status);
    final hasPayment = payment != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onDetail,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      programTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                universityName,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
              if (discountText.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  discountText,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF1EA75C)),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Frais de courtage',
                          style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          amountText,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1EA75C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: onPay,
                    icon: const Icon(Icons.payment, size: 18),
                    label: Text(hasPayment ? 'Continuer' : 'Payer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1EA75C),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.payments_outlined, size: 56, color: Color(0xFF9CA3AF)),
          const SizedBox(height: 16),
          const Text(
            'Aucun paiement de courtage en cours',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Les paiements apparaissent ici quand une candidature est acceptée et que le taux de réduction a été fixé par Academia.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualiser'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRetry,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
          const SizedBox(height: 16),
          const Text(
            'Impossible de charger les paiements',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 24),
          Center(
            child: FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ),
        ],
      ),
    );
  }
}
