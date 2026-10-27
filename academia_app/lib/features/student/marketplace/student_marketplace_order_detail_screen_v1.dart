import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../widgets/ligdicash_payment_sheet.dart';
import 'student_marketplace_add_review_screen.dart';

const Map<String, String> _orderStatusLabels = {
  'pending': 'En attente de paiement',
  'paid': 'Payée',
  'confirmed': 'Confirmée',
  'accepted': 'Acceptée par le vendeur',
  'shipped': 'Expédiée',
  'delivered': 'Livrée',
  'completed': 'Terminée',
  'cancelled': 'Annulée',
  'canceled': 'Annulée',
  'disputed': 'Réclamation en cours',
  'refunded': 'Remboursée',
};

const Map<String, String> _actorLabels = {
  'student': 'Vous',
  'merchant': 'Vendeur',
  'admin': 'Academia',
  'system': 'Automatique',
};

class StudentMarketplaceOrderDetailScreenV1 extends StatefulWidget {
  final String orderId;

  const StudentMarketplaceOrderDetailScreenV1({
    super.key,
    required this.orderId,
  });

  @override
  State<StudentMarketplaceOrderDetailScreenV1> createState() =>
      _StudentMarketplaceOrderDetailScreenV1State();
}

class _StudentMarketplaceOrderDetailScreenV1State
    extends State<StudentMarketplaceOrderDetailScreenV1> {
  bool _loading = false;
  bool _paying = false;
  bool _acting = false;
  String? _error;

  Map<String, dynamic>? _order;
  List<Map<String, dynamic>> _items = const [];
  Map<String, dynamic> _actions = const {};
  Map<String, dynamic> _deadlines = const {};
  Map<String, dynamic>? _payment;
  List<Map<String, dynamic>> _events = const [];

  String _formatDate(dynamic v) {
    final d = DateTime.tryParse(v?.toString() ?? '')?.toLocal();
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} à ${two(d.hour)}:${two(d.minute)}';
  }

  String? _deadlineText() {
    final d = _deadlines;
    if (d['pay_before'] != null) {
      return 'À payer avant le ${_formatDate(d['pay_before'])}, sinon la commande sera annulée.';
    }
    if (d['accept_before'] != null) {
      return 'Le vendeur doit accepter avant le ${_formatDate(d['accept_before'])}. Sinon, annulation et remboursement intégral automatiques.';
    }
    if (d['ship_before'] != null) {
      return 'Expédition attendue avant le ${_formatDate(d['ship_before'])}. Sinon, annulation et remboursement intégral automatiques.';
    }
    if (d['auto_complete_at'] != null) {
      return 'Un problème ? Vous avez jusqu\'au ${_formatDate(d['auto_complete_at'])} pour ouvrir une réclamation. Ensuite, la commande sera validée et le vendeur payé.';
    }
    if (d['dispute_from'] != null) {
      return 'Rien reçu ? Vous pourrez ouvrir une réclamation à partir du ${_formatDate(d['dispute_from'])}.';
    }
    return null;
  }

  Future<void> _runAction(
    String rpc,
    Map<String, dynamic> params,
    String successMessage,
  ) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      final res = await Supabase.instance.client.rpc(rpc, params: params);
      if (!mounted) return;
      final map = res is Map ? Map<String, dynamic>.from(res) : null;
      final ok = map?['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? successMessage
                : (map?['message']?.toString() ??
                    'Action impossible (${map?['error'] ?? 'erreur'}).'),
          ),
        ),
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur réseau. Réessayez.')),
      );
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<bool> _confirmDialog(String title, String message, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Retour'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _cancel() async {
    final paid = _order?['status']?.toString() == 'paid';
    final ok = await _confirmDialog(
      'Annuler la commande ?',
      paid
          ? 'Le montant payé vous sera intégralement remboursé sur le numéro utilisé pour le paiement.'
          : 'La commande sera annulée.',
      'Annuler la commande',
    );
    if (!ok) return;
    await _runAction(
      'app_student_cancel_marketplace_order',
      {'p_order_id': widget.orderId.trim(), 'p_reason': null},
      paid ? 'Commande annulée. Remboursement en cours.' : 'Commande annulée.',
    );
  }

  Future<void> _confirmReceived() async {
    final ok = await _confirmDialog(
      'Confirmer la réception ?',
      'Confirmez uniquement si vous avez reçu la commande conforme. Le vendeur sera payé et vous ne pourrez plus ouvrir de réclamation.',
      'J\'ai bien reçu',
    );
    if (!ok) return;
    await _runAction(
      'app_student_confirm_marketplace_order_received',
      {'p_order_id': widget.orderId.trim()},
      'Merci ! Commande terminée.',
    );
  }

  Future<void> _openDispute() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Signaler un problème'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Le paiement au vendeur sera bloqué le temps qu\'Academia examine votre réclamation.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Décrivez le problème (non reçu, abîmé, non conforme…)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Retour'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty) return;
    if (reason.length < 10) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Décrivez le problème en 10 caractères minimum.')),
      );
      return;
    }
    await _runAction(
      'app_student_open_marketplace_dispute',
      {'p_order_id': widget.orderId.trim(), 'p_reason': reason},
      'Réclamation envoyée. Academia revient vers vous.',
    );
  }

  Map<String, dynamic> _asMap(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  List<Map<String, dynamic>> _asList(dynamic v) => v is List
      ? v
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false)
      : <Map<String, dynamic>>[];

  String _formatMoney(dynamic v, String? currency) {
    if (v is num) {
      final cur = (currency ?? '').trim();
      if (cur.isEmpty) return '${v.toStringAsFixed(0)} FCFA';
      return '${v.toStringAsFixed(0)} $cur';
    }
    return v?.toString() ?? '';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    final id = widget.orderId.trim();
    if (id.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;
      final response = await client.rpc(
        'app_student_get_marketplace_order_detail',
        params: {
          'p_order_id': id,
        },
      );

      if (response is! Map<String, dynamic>) {
        setState(() {
          _error = 'Réponse invalide du serveur.';
        });
        return;
      }

      if (response['success'] != true) {
        setState(() {
          _error = response['error']?.toString() ?? 'Erreur serveur.';
        });
        return;
      }

      final o = response['order'];
      final it = response['items'];

      setState(() {
        _order = o is Map ? Map<String, dynamic>.from(o) : null;
        _items = _asList(it);
        _actions = _asMap(response['actions']);
        _deadlines = _asMap(response['deadlines']);
        _payment = response['payment'] is Map
            ? Map<String, dynamic>.from(response['payment'])
            : null;
        _events = _asList(response['events']);
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _pay() async {
    if (_paying) return;
    setState(() => _paying = true);
    try {
      final res = await Supabase.instance.client.rpc(
        'app_student_ensure_marketplace_payment',
        params: {'p_order_id': widget.orderId.trim()},
      );
      if (!mounted) return;
      final map = res is Map ? Map<String, dynamic>.from(res) : null;
      final paymentId = map?['marketplace_payment_id']?.toString();
      final amount = map?['amount'];
      if (map?['success'] != true || paymentId == null || paymentId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paiement indisponible pour cette commande.'),
          ),
        );
        await _load();
        return;
      }
      await LigdiCashPaymentSheet.show(
        context: context,
        paymentType: 'marketplace',
        paymentId: paymentId,
        amount: amount is num
            ? amount.toDouble()
            : double.tryParse(amount?.toString() ?? '') ?? 0,
        description: 'Commande Marketplace',
        onSuccess: () {},
      );
      if (mounted) await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors du paiement. Réessayez.')),
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final status = order?['status']?.toString() ?? '';
    final currency = order?['currency']?.toString();
    final total = order?['total_amount'];
    final deadline = _deadlineText();
    final cancelReason = order?['cancel_reason']?.toString();
    final disputeReason = order?['dispute_reason']?.toString();
    final refunded = _payment?['status']?.toString() == 'refunded';
    final canCancel = _actions['can_cancel'] == true;
    final canConfirm = _actions['can_confirm'] == true;
    final canDispute = _actions['can_dispute'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Détail commande'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              : order == null
                  ? const Center(child: Text('Commande introuvable.'))
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Statut : ${_orderStatusLabels[status] ?? status}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Total: ${_formatMoney(total, currency)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              if (deadline != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  deadline,
                                  style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                              if (status == 'cancelled' &&
                                  cancelReason != null &&
                                  cancelReason.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text('Motif : $cancelReason'),
                              ],
                              if (status == 'disputed' &&
                                  disputeReason != null &&
                                  disputeReason.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Votre réclamation : $disputeReason\nAcademia examine le dossier ; le vendeur n\'est pas payé en attendant.',
                                ),
                              ],
                              if (refunded) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Remboursement de ${_formatMoney(_payment?['gross_amount'], currency)} envoyé sur le numéro ayant servi au paiement.',
                                  style: const TextStyle(
                                    color: Color(0xFF047857),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                              if (canConfirm) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _acting ? null : _confirmReceived,
                                    icon: const Icon(Icons.check_circle_outline, size: 18),
                                    label: const Text('J\'ai reçu ma commande'),
                                  ),
                                ),
                              ],
                              if (canDispute) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _acting ? null : _openDispute,
                                    icon: const Icon(Icons.report_problem_outlined, size: 18),
                                    label: const Text('Signaler un problème'),
                                  ),
                                ),
                              ],
                              if (canCancel) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: TextButton.icon(
                                    onPressed: _acting ? null : _cancel,
                                    icon: const Icon(Icons.cancel_outlined, size: 18),
                                    label: const Text('Annuler la commande'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ],
                              if (status == 'pending') ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _paying ? null : _pay,
                                    icon: _paying
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.payment, size: 18),
                                    label: const Text('Payer maintenant'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Articles',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        if (_items.isEmpty)
                          const Text('Aucun article.')
                        else
                          ..._items.map((it) {
                            final title = it['title']?.toString() ?? '';
                            final qty = it['quantity']?.toString() ?? '';
                            final unit = it['unit_price'];
                            final cur = it['currency']?.toString();
                            final productId = it['product_id']?.toString();
                            final canReview = status == 'delivered' || status == 'completed';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text('x$qty'),
                                      const SizedBox(width: 12),
                                      Text(
                                        _formatMoney(unit, cur),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (canReview && productId != null && productId.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => StudentMarketplaceAddReviewScreen(
                                                listingId: productId,
                                                orderId: widget.orderId,
                                                listingTitle: title,
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.rate_review_outlined, size: 18),
                                        label: const Text('Laisser un avis'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                        if (_events.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Historique',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _events.map((e) {
                                final to = e['to_status']?.toString() ?? '';
                                final who = _actorLabels[e['actor_role']?.toString()] ?? '';
                                final note = e['note']?.toString() ?? '';
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 3),
                                        child: Icon(Icons.circle, size: 8, color: Color(0xFF9CA3AF)),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${_formatDate(e['created_at'])} — ${_orderStatusLabels[to] ?? to}'
                                          '${who.isEmpty ? '' : ' ($who)'}'
                                          '${note.isEmpty ? '' : '\n$note'}',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
    );
  }
}
