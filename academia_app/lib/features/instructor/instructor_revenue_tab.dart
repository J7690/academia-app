import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InstructorRevenueTab extends StatefulWidget {
  const InstructorRevenueTab({super.key});

  @override
  State<InstructorRevenueTab> createState() => _InstructorRevenueTabState();
}

class _InstructorRevenueTabState extends State<InstructorRevenueTab> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _balance = {};
  String _payoutPhone = '';
  String _payoutOperator = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    final client = Supabase.instance.client;
    try {
      final resp = await client.rpc('app_instructor_get_my_balance');
      final data = resp as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        _balance = data;
      }
      // Charger infos paiement de l'enseignant
      final userId = client.auth.currentUser?.id;
      if (userId != null) {
        final instr = await client.schema('app').from('instructors')
            .select('payout_phone, payout_operator').eq('id', userId).maybeSingle();
        if (instr != null) {
          _payoutPhone = instr['payout_phone']?.toString() ?? '';
          _payoutOperator = instr['payout_operator']?.toString() ?? '';
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  String _fmt(dynamic v) {
    if (v == null) return '0';
    if (v is num) return v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));

    final available = _balance['available_balance'] ?? 0;
    final pending = _balance['pending_balance'] ?? 0;
    final totalEarned = _balance['total_earned'] ?? 0;
    final totalWithdrawn = _balance['total_withdrawn'] ?? 0;
    final currency = _balance['currency']?.toString() ?? 'XOF';
    final needsPayoutInfo = _payoutPhone.isEmpty;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Alerte si infos paiement manquantes
          if (needsPayoutInfo)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Color(0xFFD97706), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Informations de paiement requises',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF92400E))),
                        const SizedBox(height: 2),
                        const Text('Configurez votre numéro mobile money pour recevoir vos revenus.',
                            style: TextStyle(fontSize: 12, color: Color(0xFFB45309))),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 32,
                          child: ElevatedButton(
                            onPressed: () => _showPayoutInfoDialog(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD97706),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            child: const Text('Configurer maintenant'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Balance card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0D9488), Color(0xFF0891B2)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text('Solde disponible', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 6),
                Text('${_fmt(available)} $currency',
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _MiniStat(label: 'En attente', value: _fmt(pending), color: const Color(0xFFFCD34D)),
                    Container(width: 1, height: 30, color: Colors.white24),
                    _MiniStat(label: 'Total gagné', value: _fmt(totalEarned), color: const Color(0xFF4ADE80)),
                    Container(width: 1, height: 30, color: Colors.white24),
                    _MiniStat(label: 'Retiré', value: _fmt(totalWithdrawn), color: Colors.white70),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Payout button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: available is num && available > 0 && !needsPayoutInfo
                  ? () => _requestPayout(context)
                  : null,
              icon: const Icon(Icons.account_balance_wallet, size: 18),
              label: Text(
                available is num && available > 0
                    ? 'Retirer ${_fmt(available)} $currency'
                    : 'Aucun solde à retirer',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          if (_payoutPhone.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.phone_android, size: 16, color: Color(0xFF6B7280)),
                const SizedBox(width: 6),
                Text('Numéro payout : $_payoutPhone', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                if (_payoutOperator.isNotEmpty)
                  Text(' ($_payoutOperator)', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                const Spacer(),
                TextButton(
                  onPressed: () => _showPayoutInfoDialog(context),
                  child: const Text('Modifier', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),
          const Text('Comment ça fonctionne', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _infoRow(Icons.school, 'Un étudiant paie pour un TD ou un cours en ligne'),
          _infoRow(Icons.pie_chart, 'La plateforme calcule automatiquement votre part selon les règles de répartition'),
          _infoRow(Icons.account_balance_wallet, 'Votre part est créditée dans votre solde disponible'),
          _infoRow(Icons.send, 'Vous demandez un retrait → l\'argent est envoyé sur votre mobile money'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6B7280)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF374151)))),
        ],
      ),
    );
  }

  Future<void> _showPayoutInfoDialog(BuildContext context) async {
    final phoneCtrl = TextEditingController(text: _payoutPhone);
    String operator = _payoutOperator.isNotEmpty ? _payoutOperator : 'orange_money';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Informations de paiement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Numéro mobile money',
                  hintText: '226 7X XX XX XX',
                  prefixIcon: Icon(Icons.phone_android),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: operator,
                decoration: const InputDecoration(labelText: 'Opérateur', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'orange_money', child: Text('Orange Money')),
                  DropdownMenuItem(value: 'moov_money', child: Text('Moov Money')),
                  DropdownMenuItem(value: 'telecel_money', child: Text('Telecel Money')),
                ],
                onChanged: (v) => setState(() => operator = v ?? operator),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    final phone = phoneCtrl.text.trim();
    if (phone.length < 8) return;

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;
      await client.schema('app').from('instructors')
          .update({'payout_phone': phone, 'payout_operator': operator}).eq('id', userId);
      // Aussi td_teachers
      await client.schema('app').from('td_teachers')
          .update({'payout_phone': phone, 'payout_operator': operator}).eq('user_id', userId);
      if (mounted) {
        setState(() { _payoutPhone = phone; _payoutOperator = operator; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Infos paiement enregistrées.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  Future<void> _requestPayout(BuildContext context) async {
    try {
      final client = Supabase.instance.client;
      final resp = await client.rpc('app_instructor_request_payout', params: {'p_phone': _payoutPhone});
      final data = resp as Map<String, dynamic>?;
      if (!mounted) return;
      if (data != null && data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Retrait demandé : ${data['amount']} XOF vers $_payoutPhone')),
        );
        _loadData();
      } else {
        final err = data?['error']?.toString() ?? 'Erreur';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          err == 'no_funds_available' ? 'Aucun solde à retirer.' : 'Erreur : $err')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }
}
