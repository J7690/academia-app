import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

import '../../providers/admin_marketplace_control_tower_provider.dart';
import 'admin_marketplace_payments_reviews_tabs.dart';
import '../../widgets/marketplace/marketplace_shimmer.dart';

class AdminMarketplaceControlTowerScreen extends StatefulWidget {
  const AdminMarketplaceControlTowerScreen({super.key});

  @override
  State<AdminMarketplaceControlTowerScreen> createState() =>
      _AdminMarketplaceControlTowerScreenState();
}

class _AdminMarketplaceControlTowerScreenState
    extends State<AdminMarketplaceControlTowerScreen> {
  late final AdminMarketplaceControlTowerProvider _provider;

  String _formatMoney(dynamic v, String? currency) {
    if (v is num) {
      final cur = (currency ?? '').trim();
      if (cur.isEmpty) return '${v.toStringAsFixed(0)} FCFA';
      return '${v.toStringAsFixed(0)} $cur';
    }
    return v?.toString() ?? '';
  }

  Future<void> _openPhotosSheet({
    required AdminMarketplaceControlTowerProvider provider,
    required String listingId,
    required String title,
  }) async {
    if (listingId.trim().isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        bool loading = true;
        String? error;
        List<Map<String, dynamic>> media = [];

        Future<void> load() async {
          loading = true;
          error = null;
          try {
            media = await provider.adminListListingMedia(listingId: listingId);
            if (provider.error != null) {
              error = provider.error;
            }
          } catch (e) {
            error = e.toString();
          } finally {
            loading = false;
          }
        }

        Future<void> pickAndUpload() async {
          final picker = ImagePicker();
          final picked = await picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1600,
            imageQuality: 82,
          );
          if (picked == null) return;

          final Uint8List bytes = await picked.readAsBytes();
          final url = await provider.adminUploadListingImageAndRegister(
            listingId: listingId,
            bytes: bytes,
            fileName: picked.name,
            mimeType: picked.mimeType,
            sortOrder: 0,
          );

          if (!sheetContext.mounted) return;
          if (url == null) {
            ScaffoldMessenger.of(sheetContext).showSnackBar(
              SnackBar(content: Text(provider.error ?? 'Erreur upload.')),
            );
          } else {
            ScaffoldMessenger.of(sheetContext).showSnackBar(
              const SnackBar(content: Text('Photo ajoutée.')),
            );
          }
        }

        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> reload() async {
              setState(() {
                loading = true;
                error = null;
              });
              await load();
              if (!sheetContext.mounted) return;
              setState(() {});
            }

            Future<void> addPhoto() async {
              await pickAndUpload();
              if (!sheetContext.mounted) return;
              await reload();
            }

            Future<void> disableMedia(String mediaId) async {
              setState(() {
                loading = true;
                error = null;
              });
              final ok = await provider.adminDisableListingMedia(mediaId: mediaId);
              if (!sheetContext.mounted) return;
              if (!ok) {
                setState(() {
                  loading = false;
                  error = provider.error ?? 'Erreur suppression.';
                });
                return;
              }
              await reload();
            }

            if (loading && media.isEmpty && error == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                reload();
              });
            }

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(sheetContext).size.height * 0.72,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Photos — $title',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Ajouter',
                            onPressed: provider.isLoading ? null : addPhoto,
                            icon: const Icon(Icons.add_a_photo_outlined),
                          ),
                          IconButton(
                            tooltip: 'Rafraîchir',
                            onPressed: provider.isLoading ? null : reload,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                    ),
                    if (error != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    Expanded(
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : media.isEmpty
                              ? const Center(child: Text('Aucune photo.'))
                              : GridView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                  ),
                                  itemCount: media.length,
                                  itemBuilder: (context, index) {
                                    final m = media[index];
                                    final url = (m['url'] ?? '').toString().trim();
                                    final mediaId = (m['id'] ?? '').toString().trim();
                                    final isActive = m['is_active'] == true;

                                    return Stack(
                                      children: [
                                        Positioned.fill(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(14),
                                            child: url.isEmpty
                                                ? Container(
                                                    color: const Color(0xFFF1F0EB),
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons.image_not_supported_outlined,
                                                      ),
                                                    ),
                                                  )
                                                : Image.network(
                                                    url,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, e, s) {
                                                      return Container(
                                                        color: const Color(0xFFF1F0EB),
                                                        child: const Center(
                                                          child: Icon(
                                                            Icons.image_not_supported_outlined,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                          ),
                                        ),
                                        Positioned(
                                          right: 6,
                                          top: 6,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.5),
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: IconButton(
                                              visualDensity: VisualDensity.compact,
                                              tooltip: 'Supprimer',
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                              onPressed: (!isActive || mediaId.isEmpty)
                                                  ? null
                                                  : () => disableMedia(mediaId),
                                            ),
                                          ),
                                        ),
                                        if (!isActive)
                                          Positioned.fill(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.35),
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              child: const Center(
                                                child: Text(
                                                  'Désactivée',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _provider = AdminMarketplaceControlTowerProvider();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider.refreshAll();
    });
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  Future<void> _confirmReject(
    BuildContext context,
    AdminMarketplaceControlTowerProvider provider,
    String opportunityId,
  ) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rejeter l\'annonce'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Indique une raison (visible pour le marchand).',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Raison',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'Rejeter',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final ok = await provider.reviewOpportunity(
      opportunityId: opportunityId,
      approve: false,
      reason: controller.text.trim().isEmpty ? null : controller.text.trim(),
    );
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Annonce rejetée.' : (provider.error ?? 'Erreur.'),
        ),
      ),
    );
  }

  Widget _buildPendingTab(AdminMarketplaceControlTowerProvider provider) {
    final items = provider.pendingOpportunities;

    if (provider.isLoading && items.isEmpty) {
      return const MarketplaceShimmerList();
    }

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: provider.loadPendingOpportunities,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            Center(child: Text('Aucune annonce en attente.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.loadPendingOpportunities,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final o = items[index];
          final id = o['id']?.toString() ?? '';
          final title = o['title']?.toString() ?? 'Sans titre';
          final org = o['organization_name']?.toString() ?? '';
          final priceFrom = o['price_from']?.toString();
          final priceTo = o['price_to']?.toString();
          final currency = o['currency']?.toString();

          String priceText = '';
          if ((priceFrom != null && priceFrom.isNotEmpty) ||
              (priceTo != null && priceTo.isNotEmpty)) {
            priceText = 'Prix: ';
            if (priceFrom != null && priceFrom.isNotEmpty) {
              priceText += priceFrom;
            }
            if (priceTo != null && priceTo.isNotEmpty) {
              priceText += ' - $priceTo';
            }
            if (currency != null && currency.isNotEmpty) {
              priceText += ' $currency';
            }
          }

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (org.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(org),
                  ],
                  if (priceText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(priceText),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: provider.isLoading
                              ? null
                              : () => _confirmReject(context, provider, id),
                          child: const Text('Rejeter'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: provider.isLoading || id.isEmpty
                              ? null
                              : () => _openPhotosSheet(
                                    provider: provider,
                                    listingId: id,
                                    title: title,
                                  ),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Photos'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: provider.isLoading
                              ? null
                              : () async {
                                  final ok = await provider.reviewOpportunity(
                                    opportunityId: id,
                                    approve: true,
                                  );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? 'Annonce approuvée et publiée.'
                                            : (provider.error ?? 'Erreur.'),
                                      ),
                                    ),
                                  );
                                },
                          child: const Text('Approuver'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPublishedTab(AdminMarketplaceControlTowerProvider provider) {
    final items = provider.publishedListings;

    if (provider.isLoading && items.isEmpty) {
      return const MarketplaceShimmerList();
    }

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => provider.loadPublishedListings(),
        child: ListView(
          children: const [
            SizedBox(height: 80),
            Center(child: Text('Aucune annonce publiée.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadPublishedListings(),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final o = items[index];
          final id = o['id']?.toString() ?? '';
          final title = o['title']?.toString() ?? 'Sans titre';
          final org = o['organization_name']?.toString() ?? '';

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (org.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(org),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: provider.isLoading || id.isEmpty
                              ? null
                              : () => _openPhotosSheet(
                                    provider: provider,
                                    listingId: id,
                                    title: title,
                                  ),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Photos'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMerchantsTab(AdminMarketplaceControlTowerProvider provider) {
    final items = provider.merchants;

    if (provider.isLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: provider.loadMerchants,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            Center(child: Text('Aucun marchand.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.loadMerchants,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final m = items[index];
          final id = m['user_id']?.toString() ?? '';
          final name = m['display_name']?.toString() ?? 'Marchand';
          final isVerified = m['is_verified'] == true;
          final isActive = m['is_active'] != false;
          final verificationLevel =
              (m['verification_level']?.toString().trim().isNotEmpty ?? false)
                  ? m['verification_level']?.toString()
                  : 'none';

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(child: Text('Actif')),
                      Switch(
                        value: isActive,
                        onChanged: provider.isLoading
                            ? null
                            : (v) async {
                                final ok =
                                    await provider.updateMerchantStatus(
                                  merchantId: id,
                                  isActive: v,
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ok
                                          ? 'Statut marchand mis à jour.'
                                          : (provider.error ?? 'Erreur.'),
                                    ),
                                  ),
                                );
                              },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Expanded(child: Text('Vérifié')),
                      Switch(
                        value: isVerified,
                        onChanged: provider.isLoading
                            ? null
                            : (v) async {
                                final ok =
                                    await provider.setMerchantVerification(
                                  merchantId: id,
                                  isVerified: v,
                                  verificationLevel: verificationLevel ?? 'none',
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ok
                                          ? 'Vérification mise à jour.'
                                          : (provider.error ?? 'Erreur.'),
                                    ),
                                  ),
                                );
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Niveau: '),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: verificationLevel ?? 'none',
                        items: const [
                          DropdownMenuItem(value: 'none', child: Text('Aucun')),
                          DropdownMenuItem(
                            value: 'basic',
                            child: Text('Basique'),
                          ),
                          DropdownMenuItem(
                            value: 'verified',
                            child: Text('Vérifié'),
                          ),
                          DropdownMenuItem(
                            value: 'gold',
                            child: Text('Gold'),
                          ),
                        ],
                        onChanged: provider.isLoading
                            ? null
                            : (value) async {
                                final level = value ?? 'none';
                                final ok =
                                    await provider.setMerchantVerification(
                                  merchantId: id,
                                  isVerified: isVerified,
                                  verificationLevel: level,
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ok
                                          ? 'Niveau mis à jour.'
                                          : (provider.error ?? 'Erreur.'),
                                    ),
                                  ),
                                );
                              },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static const Map<String, String> _adminOrderStatusLabels = {
    'pending': 'En attente de paiement',
    'paid': 'Payée',
    'confirmed': 'Confirmée',
    'accepted': 'Acceptée',
    'shipped': 'Expédiée',
    'delivered': 'Livrée',
    'completed': 'Terminée',
    'cancelled': 'Annulée',
    'disputed': 'Litige',
    'refunded': 'Remboursée',
  };

  Future<String?> _askAdminNote(String title, String hint) async {
    final controller = TextEditingController();
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 300,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Retour'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    controller.dispose();
    return (r == null || r.isEmpty) ? null : r;
  }

  Future<void> _openAdminOrderSheet(
    AdminMarketplaceControlTowerProvider provider,
    String orderId,
  ) async {
    final detail = await provider.getOrderDetail(orderId);
    if (!mounted) return;
    if (detail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Commande introuvable.')),
      );
      return;
    }
    final order = Map<String, dynamic>.from(detail['order'] as Map);
    final actions = detail['actions'] is Map
        ? Map<String, dynamic>.from(detail['actions'])
        : <String, dynamic>{};
    final payments = (detail['payments'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final events = (detail['events'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final items = (detail['items'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final status = order['status']?.toString() ?? '';
    final currency = order['currency']?.toString();

    Future<void> run(Future<bool> Function() action, String okMessage) async {
      final ok = await action();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? okMessage : (provider.error ?? 'Erreur.'))),
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.8,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Commande #${orderId.substring(0, 8).toUpperCase()} — ${_adminOrderStatusLabels[status] ?? status}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text('Total : ${_formatMoney(order['total_amount'], currency)}'),
              Text('Acheteur : ${detail['student_name'] ?? '-'}'),
              Text('Marchand : ${detail['merchant_name'] ?? '-'}'),
              if ((order['dispute_reason']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Réclamation : ${order['dispute_reason']}',
                  style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w700),
                ),
              ],
              if ((order['cancel_reason']?.toString() ?? '').isNotEmpty)
                Text('Motif d\'annulation : ${order['cancel_reason']}'),
              if (actions['can_resolve'] == true) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB91C1C)),
                        onPressed: () async {
                          final note = await _askAdminNote(
                            'Rembourser l\'acheteur',
                            'Motif de la décision (communiqué aux deux parties)',
                          );
                          if (note == null) return;
                          await run(
                            () => provider.resolveDispute(orderId: orderId, refundBuyer: true, note: note),
                            'Acheteur remboursé.',
                          );
                        },
                        icon: const Icon(Icons.undo, size: 18),
                        label: const Text('Rembourser'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF047857)),
                        onPressed: () async {
                          final note = await _askAdminNote(
                            'Payer le vendeur',
                            'Motif de la décision (communiqué aux deux parties)',
                          );
                          if (note == null) return;
                          await run(
                            () => provider.resolveDispute(orderId: orderId, refundBuyer: false, note: note),
                            'Fonds versés au vendeur.',
                          );
                        },
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Payer le vendeur'),
                      ),
                    ),
                  ],
                ),
              ],
              if (actions['can_cancel'] == true) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final reason = await _askAdminNote(
                      'Annuler la commande',
                      'Motif (l\'acheteur est remboursé intégralement s\'il a payé)',
                    );
                    if (reason == null) return;
                    await run(
                      () => provider.cancelOrder(orderId: orderId, reason: reason),
                      'Commande annulée.',
                    );
                  },
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Annuler la commande'),
                ),
              ],
              const SizedBox(height: 16),
              const Text('Articles', style: TextStyle(fontWeight: FontWeight.w900)),
              ...items.map((i) => Text(
                    '• ${i['title'] ?? ''} x${i['quantity'] ?? ''} — ${_formatMoney(i['unit_price'], i['currency']?.toString())}',
                  )),
              const SizedBox(height: 16),
              const Text('Paiements', style: TextStyle(fontWeight: FontWeight.w900)),
              if (payments.isEmpty) const Text('Aucun.'),
              ...payments.map((p) => Text(
                    '• ${_formatMoney(p['gross_amount'], currency)} — ${p['status']} — ${p['phone_number'] ?? 'numéro inconnu'}',
                  )),
              const SizedBox(height: 16),
              const Text('Historique', style: TextStyle(fontWeight: FontWeight.w900)),
              ...events.map((e) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '• ${e['created_at']?.toString().substring(0, 16).replaceFirst('T', ' ') ?? ''} — '
                      '${_adminOrderStatusLabels[e['to_status']] ?? e['to_status']} (${e['actor_role']})'
                      '${(e['note']?.toString() ?? '').isEmpty ? '' : '\n   ${e['note']}'}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersTab(AdminMarketplaceControlTowerProvider provider) {
    final items = provider.orders;

    if (provider.isLoading && items.isEmpty) {
      return const MarketplaceShimmerList();
    }

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => provider.loadOrders(),
        child: ListView(
          children: const [
            SizedBox(height: 80),
            Center(child: Text('Aucune commande.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadOrders(),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final o = items[index];
          final status = o['status']?.toString() ?? '';
          final currency = o['currency']?.toString();
          final total = o['total_amount'];
          final merchantName = o['merchant_name']?.toString() ?? '';
          final createdAt = o['created_at']?.toString() ?? '';

          final orderId = (o['id'] ?? o['order_id'])?.toString() ?? '';
          final isDispute = status == 'disputed';

          return Card(
            color: isDispute ? const Color(0xFFFEF2F2) : null,
            child: ListTile(
              leading: isDispute
                  ? const Icon(Icons.gavel, color: Color(0xFFB91C1C))
                  : null,
              title: Text(
                _formatMoney(total, currency),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                'Statut : ${_adminOrderStatusLabels[status] ?? status}${merchantName.isEmpty ? '' : '\nMarchand : $merchantName'}${createdAt.isEmpty ? '' : '\nCréée : $createdAt'}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: orderId.isEmpty
                  ? null
                  : () => _openAdminOrderSheet(provider, orderId),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<AdminMarketplaceControlTowerProvider>(
        builder: (context, provider, child) {
          return DefaultTabController(
            length: 6,
            child: Scaffold(
              backgroundColor: const Color(0xFFF3F4F6),
              appBar: AppBar(
                title: const Text('Marketplace (Admin)'),
                bottom: const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(text: 'En attente'),
                    Tab(text: 'Publiées'),
                    Tab(text: 'Marchands'),
                    Tab(text: 'Commandes'),
                    Tab(text: 'Paiements'),
                    Tab(text: 'Avis'),
                  ],
                ),
                actions: [
                  IconButton(
                    onPressed: provider.isLoading ? null : provider.refreshAll,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Rafraîchir',
                  ),
                ],
              ),
              body: Column(
                children: [
                  if (provider.error != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: Colors.red.withOpacity(0.08),
                      child: Text(
                        provider.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildPendingTab(provider),
                        _buildPublishedTab(provider),
                        _buildMerchantsTab(provider),
                        _buildOrdersTab(provider),
                        const AdminMarketplacePaymentsTab(),
                        const AdminMarketplaceReviewsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
