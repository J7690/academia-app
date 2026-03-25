import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSubscriptionsScreen extends StatefulWidget {
  const AdminSubscriptionsScreen({super.key});

  @override
  State<AdminSubscriptionsScreen> createState() => _AdminSubscriptionsScreenState();
}

class _AdminSubscriptionsScreenState extends State<AdminSubscriptionsScreen> {
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _subscriptions = [];
  List<Map<String, dynamic>> _plans = [];
  String _statusFilter = 'active';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    final client = Supabase.instance.client;
    try {
      // Load subscriptions
      final subResp = await client.rpc('app_admin_list_subscriptions', params: {
        'p_status': _statusFilter.isEmpty ? null : _statusFilter,
      });
      final subData = subResp as Map<String, dynamic>?;
      if (subData != null && subData['success'] == true) {
        final list = subData['subscriptions'] as List<dynamic>? ?? [];
        _subscriptions = list.cast<Map<String, dynamic>>();
      }

      // Load plans
      final plansRaw = await client.schema('app').from('subscription_plans').select().order('price', ascending: true);
      final plansList = plansRaw as List<dynamic>? ?? [];
      _plans = plansList.cast<Map<String, dynamic>>();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Plans summary
        if (_plans.isNotEmpty)
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              itemCount: _plans.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final plan = _plans[index];
                final code = plan['code']?.toString() ?? '';
                final name = plan['name']?.toString() ?? '';
                final price = plan['price'];
                final isActive = plan['is_active'] == true;
                return Container(
                  width: 160,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFF0FDF4) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isActive ? const Color(0xFFBBF7D0) : const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text('$price XOF', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF16A34A))),
                      Text(isActive ? 'Actif' : 'Inactif', style: TextStyle(fontSize: 10, color: isActive ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF))),
                    ],
                  ),
                );
              },
            ),
          ),

        // Filter
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              DropdownButton<String>(
                value: _statusFilter,
                underline: const SizedBox.shrink(),
                isDense: true,
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Actifs')),
                  DropdownMenuItem(value: 'expired', child: Text('Expirés')),
                  DropdownMenuItem(value: 'pending_payment', child: Text('En attente paiement')),
                  DropdownMenuItem(value: 'cancelled', child: Text('Annulés')),
                  DropdownMenuItem(value: '', child: Text('Tous')),
                ],
                onChanged: (v) {
                  _statusFilter = v ?? 'active';
                  _loadData();
                },
              ),
              const SizedBox(width: 8),
              Text('${_subscriptions.length} abonnement(s)', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              const Spacer(),
              IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _loadData, tooltip: 'Recharger'),
            ],
          ),
        ),

        // List
        if (_isLoading && _subscriptions.isEmpty)
          const Expanded(child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
        else if (_error != null && _subscriptions.isEmpty)
          Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))))
        else if (_subscriptions.isEmpty)
          const Expanded(child: Center(child: Text('Aucun abonnement trouvé.')))
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: _subscriptions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final sub = _subscriptions[index];
                final studentName = sub['student_name']?.toString() ?? 'Étudiant';
                final planName = sub['plan_name']?.toString() ?? '';
                final planPrice = sub['plan_price'];
                final status = sub['status']?.toString() ?? '';
                final expiresAt = sub['expires_at']?.toString() ?? '';
                final startedAt = sub['started_at']?.toString() ?? '';
                final autoRenew = sub['auto_renew'] == true;

                Color statusColor;
                String statusLabel;
                switch (status) {
                  case 'active':
                    statusColor = const Color(0xFF16A34A);
                    statusLabel = 'Actif';
                    break;
                  case 'expired':
                    statusColor = const Color(0xFF6B7280);
                    statusLabel = 'Expiré';
                    break;
                  case 'pending_payment':
                    statusColor = const Color(0xFFCA8A04);
                    statusLabel = 'Paiement en attente';
                    break;
                  case 'cancelled':
                    statusColor = const Color(0xFFDC2626);
                    statusLabel = 'Annulé';
                    break;
                  default:
                    statusColor = const Color(0xFF6B7280);
                    statusLabel = status;
                }

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(studentName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.workspace_premium, size: 16, color: Color(0xFFFF8C00)),
                            const SizedBox(width: 4),
                            Text(planName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            const SizedBox(width: 8),
                            if (planPrice != null)
                              Text('$planPrice XOF', style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (startedAt.isNotEmpty)
                          Text('Début : ${_fmtDate(startedAt)}', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                        if (expiresAt.isNotEmpty)
                          Text('Expire : ${_fmtDate(expiresAt)}', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                        if (autoRenew)
                          const Text('Renouvellement auto', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB))),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
