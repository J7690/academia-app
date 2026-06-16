import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPricingScreen extends StatefulWidget {
  const AdminPricingScreen({super.key});

  @override
  State<AdminPricingScreen> createState() => _AdminPricingScreenState();
}

class _AdminPricingScreenState extends State<AdminPricingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: '💎 Crédits IA'),
            Tab(text: '🎫 Abonnements'),
            Tab(text: '📚 TD'),
            Tab(text: '🏫 Formations'),
            Tab(text: '🎓 Programmes'),
            Tab(text: '⚡ Actions IA'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              const _CreditPacksTab(),
              const _SubscriptionPlansTab(),
              const _TdProgramsTab(),
              const _ShortTrainingsTab(),
              const _UniversityProgramsTab(),
              const _AiActionPricesTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Helper: édition inline d'un montant
// ─────────────────────────────────────────────
Future<double?> _editAmountDialog(BuildContext context, String label, double current) async {
  final ctrl = TextEditingController(text: current > 0 ? current.toStringAsFixed(0) : '');
  return showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(label),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: false),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          suffixText: 'XOF',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () {
            final v = double.tryParse(ctrl.text);
            Navigator.pop(ctx, v);
          },
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );
}

Future<int?> _editIntDialog(BuildContext context, String label, int current) async {
  final ctrl = TextEditingController(text: current > 0 ? current.toString() : '');
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(label),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () {
            final v = int.tryParse(ctrl.text);
            Navigator.pop(ctx, v);
          },
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );
}

void _showSnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? Colors.red : Colors.green,
  ));
}

final _db = Supabase.instance.client;

// ─────────────────────────────────────────────
// TAB 1 : Crédits IA
// ─────────────────────────────────────────────
class _CreditPacksTab extends StatefulWidget {
  const _CreditPacksTab();
  @override
  State<_CreditPacksTab> createState() => _CreditPacksTabState();
}

class _CreditPacksTabState extends State<_CreditPacksTab> {
  List<Map<String, dynamic>> _packs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _db.rpc('app_admin_list_credit_packs');
      final data = res as Map<String, dynamic>;
      if (data['success'] == true) {
        final raw = data['packs'];
        setState(() => _packs = raw != null ? List<Map<String, dynamic>>.from(raw) : []);
      }
    } catch (e) {
      debugPrint('CreditPacksTab load error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _editPack(Map<String, dynamic> pack) async {
    final newPrice = await _editAmountDialog(
      context, 'Prix — ${pack['name']}', (pack['price_xof'] as num?)?.toDouble() ?? 0,
    );
    if (newPrice == null || !mounted) return;
    try {
      await _db.rpc('app_admin_manage_credit_pack', params: {
        'p_action': 'update',
        'p_pack_id': pack['id'],
        'p_price_xof': newPrice.toInt(),
      });
      _showSnack(context, 'Prix mis à jour : ${newPrice.toInt()} XOF');
      _load();
    } catch (e) {
      _showSnack(context, 'Erreur: $e', error: true);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> pack) async {
    final newActive = !(pack['is_active'] as bool? ?? true);
    try {
      await _db.rpc('app_admin_manage_credit_pack', params: {
        'p_action': 'update',
        'p_pack_id': pack['id'],
        'p_is_active': newActive,
      });
      _load();
    } catch (e) {
      _showSnack(context, 'Erreur: $e', error: true);
    }
  }

  Future<void> _editCredits(Map<String, dynamic> pack) async {
    final newCredits = await _editIntDialog(
      context, 'Crédits — ${pack['name']}', (pack['credits'] as num?)?.toInt() ?? 0,
    );
    if (newCredits == null || !mounted) return;
    try {
      await _db.rpc('app_admin_manage_credit_pack', params: {
        'p_action': 'update',
        'p_pack_id': pack['id'],
        'p_credits': newCredits,
      });
      _showSnack(context, '$newCredits crédits enregistrés');
      _load();
    } catch (e) {
      _showSnack(context, 'Erreur: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Packs crédits IA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Appuyez sur un montant pour le modifier.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
          ..._packs.map((p) => Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: (p['is_active'] == true) ? Colors.green : Colors.grey,
                child: Text('${p['sort_order'] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
              title: Text(p['name']?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _editCredits(p),
                    child: Text('${p['credits']} crédits  (bonus: ${p['bonus_percent']}%)',
                        style: const TextStyle(decoration: TextDecoration.underline)),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _editPack(p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue),
                      ),
                      child: Text('${p['price_xof'] ?? 0} XOF',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: p['is_active'] == true,
                    onChanged: (_) => _toggleActive(p),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TAB 2 : Abonnements
// ─────────────────────────────────────────────
class _SubscriptionPlansTab extends StatefulWidget {
  const _SubscriptionPlansTab();
  @override
  State<_SubscriptionPlansTab> createState() => _SubscriptionPlansTabState();
}

class _SubscriptionPlansTabState extends State<_SubscriptionPlansTab> {
  List<Map<String, dynamic>> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _db.rpc('app_admin_list_subscription_plans');
      final data = res as Map<String, dynamic>;
      if (data['success'] == true) {
        final raw = data['plans'];
        setState(() => _plans = raw != null ? List<Map<String, dynamic>>.from(raw) : []);
      }
    } catch (e) {
      debugPrint('SubscriptionPlansTab load error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _editPrice(Map<String, dynamic> plan) async {
    final newPrice = await _editAmountDialog(
      context, 'Prix — ${plan['name']}', (plan['price'] as num?)?.toDouble() ?? 0,
    );
    if (newPrice == null || !mounted) return;
    try {
      await _db.rpc('app_admin_manage_subscription_plan', params: {
        'p_action': 'update',
        'p_plan_id': plan['id'],
        'p_price': newPrice,
      });
      _showSnack(context, 'Prix mis à jour : ${newPrice.toInt()} XOF');
      _load();
    } catch (e) {
      _showSnack(context, 'Erreur: $e', error: true);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> plan) async {
    final newActive = !(plan['is_active'] as bool? ?? true);
    try {
      await _db.rpc('app_admin_manage_subscription_plan', params: {
        'p_action': 'update',
        'p_plan_id': plan['id'],
        'p_is_active': newActive,
      });
      _load();
    } catch (e) {
      _showSnack(context, 'Erreur: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Plans d\'abonnement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ..._plans.map((p) => Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: (p['is_active'] == true) ? Colors.indigo : Colors.grey,
                child: const Icon(Icons.card_membership, color: Colors.white, size: 18),
              ),
              title: Text(p['name']?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${p['duration_days']} jours — code: ${p['code']}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _editPrice(p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.indigo),
                      ),
                      child: Text('${(p['price'] as num?)?.toInt() ?? 0} XOF',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(value: p['is_active'] == true, onChanged: (_) => _toggleActive(p)),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TAB 3 : TD
// ─────────────────────────────────────────────
class _TdProgramsTab extends StatefulWidget {
  const _TdProgramsTab();
  @override
  State<_TdProgramsTab> createState() => _TdProgramsTabState();
}

class _TdProgramsTabState extends State<_TdProgramsTab> {
  List<Map<String, dynamic>> _programs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _db.rpc('app_admin_list_td_programs_pricing');
      final data = res as Map<String, dynamic>;
      if (data['success'] == true) {
        final raw = data['programs'];
        setState(() => _programs = raw != null ? List<Map<String, dynamic>>.from(raw) : []);
      }
    } catch (e) {
      debugPrint('TdProgramsTab load error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _editPrice(Map<String, dynamic> program) async {
    final newPrice = await _editAmountDialog(
      context, 'Prix TD — ${program['title']}', (program['price'] as num?)?.toDouble() ?? 0,
    );
    if (newPrice == null || !mounted) return;
    try {
      await _db.rpc('app_admin_update_td_program_price', params: {
        'p_program_id': program['id'],
        'p_price': newPrice,
      });
      _showSnack(context, 'Prix mis à jour : ${newPrice.toInt()} XOF');
      _load();
    } catch (e) {
      _showSnack(context, 'Erreur: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Prix des programmes TD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Appuyez sur le prix pour modifier.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
          ..._programs.map((p) => Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: (p['status'] == 'published') ? Colors.teal : Colors.grey,
                child: const Icon(Icons.school, color: Colors.white, size: 18),
              ),
              title: Text(p['title']?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${p['level'] ?? ''} • ${p['modality'] ?? ''}'),
              trailing: GestureDetector(
                onTap: () => _editPrice(p),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal),
                  ),
                  child: Text('${(p['price'] as num?)?.toInt() ?? 0} XOF',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TAB 4 : Formations courtes
// ─────────────────────────────────────────────
class _ShortTrainingsTab extends StatefulWidget {
  const _ShortTrainingsTab();
  @override
  State<_ShortTrainingsTab> createState() => _ShortTrainingsTabState();
}

class _ShortTrainingsTabState extends State<_ShortTrainingsTab> {
  List<Map<String, dynamic>> _trainings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _db.rpc('app_admin_list_short_trainings_pricing');
      final data = res as Map<String, dynamic>;
      if (data['success'] == true) {
        final raw = data['trainings'];
        setState(() => _trainings = raw != null ? List<Map<String, dynamic>>.from(raw) : []);
      }
    } catch (e) {
      debugPrint('ShortTrainingsTab load error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _editPrice(Map<String, dynamic> t) async {
    final newPrice = await _editAmountDialog(
      context, 'Prix — ${t['title']}', (t['price'] as num?)?.toDouble() ?? 0,
    );
    if (newPrice == null || !mounted) return;
    try {
      await _db.rpc('app_admin_upsert_short_training', params: {
        'p_training_id': t['id'],
        'p_price': newPrice,
      });
      _showSnack(context, 'Prix mis à jour : ${newPrice.toInt()} XOF');
      _load();
    } catch (e) {
      _showSnack(context, 'Erreur: $e', error: true);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> t) async {
    final newActive = !(t['is_active'] as bool? ?? true);
    try {
      await _db.rpc('app_admin_upsert_short_training', params: {
        'p_training_id': t['id'],
        'p_is_active': newActive,
      });
      _load();
    } catch (e) {
      _showSnack(context, 'Erreur: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Formations courtes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ..._trainings.map((t) => Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: (t['is_active'] == true) ? Colors.orange : Colors.grey,
                child: const Icon(Icons.play_lesson, color: Colors.white, size: 18),
              ),
              title: Text(t['title']?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${t['category'] ?? ''} • ${t['modality'] ?? ''} • ${t['duration_days'] ?? '?'} jours'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _editPrice(t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Text('${(t['price'] == null) ? "—" : "${(t['price'] as num).toInt()} XOF"}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(value: t['is_active'] == true, onChanged: (_) => _toggleActive(t)),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TAB 5 : Programmes Université
// ─────────────────────────────────────────────
class _UniversityProgramsTab extends StatefulWidget {
  const _UniversityProgramsTab();
  @override
  State<_UniversityProgramsTab> createState() => _UniversityProgramsTabState();
}

class _UniversityProgramsTabState extends State<_UniversityProgramsTab> {
  List<Map<String, dynamic>> _programs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _db.rpc('app_admin_list_programs_pricing');
      final data = res as Map<String, dynamic>;
      if (data['success'] == true) {
        final raw = data['programs'];
        setState(() => _programs = raw != null ? List<Map<String, dynamic>>.from(raw) : []);
      }
    } catch (e) {
      debugPrint('UniversityProgramsTab load error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _editBrokerageFee(Map<String, dynamic> p) async {
    final newFee = await _editAmountDialog(
      context, 'Frais de courtage — ${p['title']}', (p['brokerage_fee'] as num?)?.toDouble() ?? 0,
    );
    if (newFee == null || !mounted) return;
    try {
      await _db.rpc('app_admin_update_program_fees', params: {
        'p_program_id': p['id'],
        'p_brokerage_fee': newFee,
      });
      _showSnack(context, 'Frais de courtage mis à jour : ${newFee.toInt()} XOF');
      _load();
    } catch (e) {
      _showSnack(context, 'Erreur: $e', error: true);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> p) async {
    final newActive = !(p['is_active'] as bool? ?? true);
    try {
      await _db.rpc('app_admin_update_program_fees', params: {
        'p_program_id': p['id'],
        'p_is_active': newActive,
      });
      _load();
    } catch (e) {
      _showSnack(context, 'Erreur: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Frais de courtage — Programmes universitaires',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Montant factur\u00e9 par la plateforme pour chaque candidature. Ce n\'est pas les frais de scolarit\u00e9.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
          ..._programs.map((p) {
            final fee = (p['brokerage_fee'] as num?)?.toInt() ?? 0;
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: (p['is_active'] == true) ? Colors.deepPurple : Colors.grey,
                  child: const Icon(Icons.account_balance, color: Colors.white, size: 16),
                ),
                title: Text(p['title']?.toString() ?? '\u2014', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${p['university_name'] ?? ''} \u2022 ${p['degree_level'] ?? ''}'.trim()),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _editBrokerageFee(p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: fee > 0 ? Colors.deepPurple.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: fee > 0 ? Colors.deepPurple : Colors.red),
                        ),
                        child: Text(
                          fee > 0 ? '$fee XOF' : 'Non d\u00e9fini',
                          style: TextStyle(fontWeight: FontWeight.bold, color: fee > 0 ? Colors.deepPurple : Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(value: p['is_active'] == true, onChanged: (_) => _toggleActive(p)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TAB 6 : Actions IA (coûts en crédits)
// ─────────────────────────────────────────────
class _AiActionPricesTab extends StatefulWidget {
  const _AiActionPricesTab();
  @override
  State<_AiActionPricesTab> createState() => _AiActionPricesTabState();
}

class _AiActionPricesTabState extends State<_AiActionPricesTab> {
  List<Map<String, dynamic>> _prices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _db.rpc('app_admin_list_ai_action_prices');
      final data = res as Map<String, dynamic>;
      if (data['success'] == true) {
        final raw = data['prices'];
        setState(() => _prices = raw != null ? List<Map<String, dynamic>>.from(raw) : []);
      }
    } catch (e) {
      debugPrint('AiActionPricesTab load error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _editCredits(Map<String, dynamic> item) async {
    final newCredits = await _editIntDialog(
      context,
      'Coût — ${item['label'] ?? item['action_code']}',
      (item['cost_credits'] as num?)?.toInt() ?? 0,
    );
    if (newCredits == null || !mounted) return;
    try {
      await _db.rpc('app_admin_manage_ai_action_price', params: {
        'p_action': 'update',
        'p_price_id': item['id'],
        'p_cost_credits': newCredits,
      });
      _showSnack(context, 'Coût mis à jour : $newCredits crédits');
      _load();
    } catch (e) {
      _showSnack(context, 'Erreur: $e', error: true);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> item) async {
    final newActive = !(item['is_active'] as bool? ?? true);
    try {
      await _db.rpc('app_admin_manage_ai_action_price', params: {
        'p_action': 'update',
        'p_price_id': item['id'],
        'p_is_active': newActive,
      });
      _load();
    } catch (e) {
      _showSnack(context, 'Erreur: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Coût des actions IA (en crédits)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Appuyez sur le nombre de crédits pour modifier.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
          ..._prices.map((item) => Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: (item['is_active'] == true) ? Colors.deepOrange : Colors.grey,
                child: const Icon(Icons.bolt, color: Colors.white, size: 18),
              ),
              title: Text(
                item['label']?.toString() ?? item['action_code']?.toString() ?? '—',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(item['action_code']?.toString() ?? ''),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _editCredits(item),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.deepOrange),
                      ),
                      child: Text(
                        '${(item['cost_credits'] as num?)?.toInt() ?? 0} crédits',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.deepOrange),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: item['is_active'] == true,
                    onChanged: (_) => _toggleActive(item),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}
