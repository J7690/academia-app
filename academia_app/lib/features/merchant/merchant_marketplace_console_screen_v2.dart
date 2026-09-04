import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

import '../../widgets/bouton_deconnexion.dart';

import '../../providers/merchant_marketplace_console_provider_v2.dart';
import '../../widgets/support_fab.dart';
import '../student/student_settings_screen.dart';
import '../../services/push_trigger_service.dart';
import 'merchant_inquiry_chat_screen_v1.dart';
import '../../widgets/marketplace/marketplace_shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MerchantMarketplaceConsoleScreenV2 extends StatefulWidget {
  const MerchantMarketplaceConsoleScreenV2({super.key});

  @override
  State<MerchantMarketplaceConsoleScreenV2> createState() =>
      _MerchantMarketplaceConsoleScreenV2State();
}

class _MerchantMarketplaceConsoleScreenV2State
    extends State<MerchantMarketplaceConsoleScreenV2> {
  late final MerchantMarketplaceConsoleProviderV2 _provider;


  String _formatMoney(dynamic v, String? currency) {
    if (v is num) {
      final cur = (currency ?? '').trim();
      if (cur.isEmpty) return '${v.toStringAsFixed(0)} FCFA';
      return '${v.toStringAsFixed(0)} $cur';
    }
    return v?.toString() ?? '';
  }

  Future<void> _pickAndUploadListingImage({
    required MerchantMarketplaceConsoleProviderV2 provider,
    required String listingId,
  }) async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 82);
    if (picked == null) return;

    final Uint8List bytes = await picked.readAsBytes();
    final mimeType = picked.mimeType;
    final url = await provider.uploadListingImageAndRegister(
      listingId: listingId,
      bytes: bytes,
      fileName: picked.name,
      mimeType: mimeType,
      sortOrder: 0,
    );

    if (!mounted) return;
    if (url != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo ajoutée.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Erreur upload.')),
      );
    }

  }

  Future<void> _openOrderDetailSheet({
    required MerchantMarketplaceConsoleProviderV2 provider,
    required String orderId,
  }) async {
    final id = orderId.trim();
    if (id.isEmpty) return;

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
        Map<String, dynamic>? order;
        List<Map<String, dynamic>> items = const [];
        String? status;

        Future<void> load() async {
          loading = true;
          error = null;
          try {
            final res = await provider.getOrderDetail(orderId: id);
            if (res == null) {
              error = provider.error ?? 'Erreur.';
              return;
            }
            final o = res['order'];
            final it = res['items'];
            order = o is Map ? Map<String, dynamic>.from(o) : null;
            items = (it is List)
                ? it
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList(growable: false)
                : <Map<String, dynamic>>[];
            status = order?['status']?.toString();
          } catch (e) {
            error = e.toString();
          } finally {
            loading = false;
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

            if (loading && order == null && error == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                reload();
              });
            }

            final currency = order?['currency']?.toString();
            final total = order?['total_amount'];

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(sheetContext).size.height * 0.78,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Commande',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
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
                    if (loading)
                      const Expanded(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total: ${_formatMoney(total, currency)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      const Text(
                                        'Statut',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const Spacer(),
                                      DropdownButton<String>(
                                        value: (status ?? 'pending'),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'pending',
                                            child: Text('pending'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'accepted',
                                            child: Text('accepted'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'shipped',
                                            child: Text('shipped'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'completed',
                                            child: Text('completed'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'canceled',
                                            child: Text('canceled'),
                                          ),
                                        ],
                                        onChanged: provider.isLoading
                                            ? null
                                            : (v) async {
                                                final newStatus = v ?? 'pending';
                                                setState(() {
                                                  status = newStatus;
                                                });
                                                final ok =
                                                    await provider.updateOrderStatus(
                                                  orderId: id,
                                                  status: newStatus,
                                                );
                                                if (!sheetContext.mounted) return;
                                                ScaffoldMessenger.of(sheetContext)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      ok
                                                          ? 'Statut mis à jour.'
                                                          : (provider.error ??
                                                              'Erreur.'),
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
                            const SizedBox(height: 12),
                            const Text(
                              'Articles',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 8),
                            if (items.isEmpty)
                              const Text('Aucun article.')
                            else
                              ...items.map((it) {
                                final title = it['title']?.toString() ?? '';
                                final qty = it['quantity']?.toString() ?? '';
                                final unit = it['unit_price'];
                                final cur = it['currency']?.toString();
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
                                  child: Row(
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
                                );
                              }),
                          ],
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


  Future<void> _openPhotosSheet({
    required MerchantMarketplaceConsoleProviderV2 provider,
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
            media = await provider.listListingMedia(listingId: listingId);
            if (provider.error != null) {
              error = provider.error;
            }
          } catch (e) {
            error = e.toString();
          } finally {
            loading = false;
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
              await _pickAndUploadListingImage(
                provider: provider,
                listingId: listingId,
              );
              if (!sheetContext.mounted) return;
              await reload();
            }

            Future<void> disableMedia(String mediaId) async {
              setState(() {
                loading = true;
                error = null;
              });
              final ok = await provider.disableListingMedia(mediaId: mediaId);
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
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
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
                                      final url =
                                          (m['url'] ?? '').toString().trim();
                                      final mediaId =
                                          (m['id'] ?? '').toString().trim();
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
    _provider = MerchantMarketplaceConsoleProviderV2();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider.refreshAll();
      PushTriggerService.instance.triggerPendingPush();
    });
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  Future<void> _openUpsertDialog({
    required BuildContext context,
    required MerchantMarketplaceConsoleProviderV2 provider,
    Map<String, dynamic>? existing,
  }) async {
    final titleCtrl = TextEditingController(text: existing?['title']?.toString());
    final shortCtrl = TextEditingController(
      text: existing?['short_description']?.toString(),
    );
    final descCtrl = TextEditingController(
      text: existing?['description']?.toString(),
    );
    final typeCtrl = TextEditingController(text: existing?['type']?.toString());
    final catCtrl = TextEditingController(text: existing?['category']?.toString());
    final orgCtrl = TextEditingController(
      text: existing?['organization_name']?.toString(),
    );
    final countryCtrl =
        TextEditingController(text: existing?['country']?.toString());
    final cityCtrl = TextEditingController(text: existing?['city']?.toString());

    final priceFromCtrl =
        TextEditingController(text: existing?['price_from']?.toString());
    final priceToCtrl =
        TextEditingController(text: existing?['price_to']?.toString());
    final currencyCtrl =
        TextEditingController(text: existing?['currency']?.toString() ?? 'XOF');

    final minQtyCtrl =
        TextEditingController(text: existing?['min_order_qty']?.toString());
    final leadTimeCtrl =
        TextEditingController(text: existing?['lead_time_days']?.toString());

    bool isReadyToShip = existing?['is_ready_to_ship'] == true;
    bool isRemotePossible = existing?['is_remote_possible'] == true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(existing == null ? 'Nouvelle annonce' : 'Modifier'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Titre',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: shortCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description courte',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: typeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: catCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Catégorie',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: orgCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Organisation',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: countryCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Pays',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: cityCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Ville',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: priceFromCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Prix min',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: priceToCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Prix max',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: TextField(
                            controller: currencyCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Devise',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minQtyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Qté min',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: leadTimeCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Délai (jours)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      value: isReadyToShip,
                      onChanged: (v) => setState(() => isReadyToShip = v),
                      title: const Text('Prêt à expédier'),
                    ),
                    SwitchListTile(
                      value: isRemotePossible,
                      onChanged: (v) => setState(() => isRemotePossible = v),
                      title: const Text('Remote possible'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: provider.isLoading
                      ? null
                      : () async {
                          final ok = await provider.upsertOpportunity(
                            opportunityId: existing?['id']?.toString(),
                            title: titleCtrl.text.trim(),
                            shortDescription: shortCtrl.text.trim(),
                            description:
                                descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                            type: typeCtrl.text.trim(),
                            category: catCtrl.text.trim().isEmpty ? null : catCtrl.text.trim(),
                            organizationName: orgCtrl.text.trim(),
                            country: countryCtrl.text.trim(),
                            city: cityCtrl.text.trim(),
                            priceFrom: double.tryParse(priceFromCtrl.text.trim()),
                            priceTo: double.tryParse(priceToCtrl.text.trim()),
                            currency: currencyCtrl.text.trim().isEmpty
                                ? null
                                : currencyCtrl.text.trim(),
                            minOrderQty: int.tryParse(minQtyCtrl.text.trim()),
                            leadTimeDays: int.tryParse(leadTimeCtrl.text.trim()),
                            isReadyToShip: isReadyToShip,
                            isRemotePossible: isRemotePossible,
                          );
                          if (!dialogContext.mounted) return;
                          if (ok) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!context.mounted) return;
    if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!)),
      );
    }
  }

  Widget _buildMyOpportunities(MerchantMarketplaceConsoleProviderV2 provider) {
    final items = provider.myOpportunities;

    if (provider.isLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: provider.loadMyOpportunities,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            Center(child: Text('Aucune annonce.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.loadMyOpportunities,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final o = items[index];
          final id = o['id']?.toString() ?? '';
          final title = o['title']?.toString() ?? 'Sans titre';
          final status = o['review_status']?.toString() ?? '';
          final reason = o['review_reason']?.toString();

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
                  const SizedBox(height: 6),
                  Text('Statut: $status'),
                  if (reason != null && reason.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Motif: $reason'),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: provider.isLoading
                              ? null
                              : () => _openUpsertDialog(
                                    context: context,
                                    provider: provider,
                                    existing: o,
                                  ),
                          child: const Text('Modifier'),
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
                          onPressed: provider.isLoading || status != 'draft'
                              ? null
                              : () async {
                                  final ok = await provider.submitForReview(
                                    opportunityId: id,
                                  );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? 'Soumis pour validation.'
                                            : (provider.error ?? 'Erreur.'),
                                      ),
                                    ),
                                  );
                                },
                          child: const Text('Soumettre'),
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

  Widget _buildInquiries(MerchantMarketplaceConsoleProviderV2 provider) {
    final items = provider.inquiries;

    if (provider.isLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: provider.loadInquiries,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            Center(child: Text('Aucune demande.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.loadInquiries,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final i = items[index];
          final id = i['id']?.toString() ?? '';
          final msg = i['message']?.toString() ?? '';
          final status = i['status']?.toString() ?? '';
          final buyerId = i['buyer_id']?.toString() ?? '';

          return Card(
            child: InkWell(
              onTap: id.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MerchantInquiryChatScreenV1(
                            inquiryId: id,
                          ),
                        ),
                      );
                    },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Demande $status',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text('Acheteur: $buyerId'),
                    const SizedBox(height: 6),
                    Text(msg),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: provider.isLoading
                          ? null
                          : () async {
                              final controller = TextEditingController();
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) {
                                  return AlertDialog(
                                    title: const Text('Répondre'),
                                    content: TextField(
                                      controller: controller,
                                      maxLines: 4,
                                      decoration: const InputDecoration(
                                        labelText: 'Message',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dialogContext).pop(false),
                                        child: const Text('Annuler'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.of(dialogContext).pop(true),
                                        child: const Text('Envoyer'),
                                      ),
                                    ],
                                  );
                                },
                              );

                              if (confirmed != true) return;

                              final ok = await provider.replyToInquiry(
                                inquiryId: id,
                                message: controller.text.trim(),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? 'Réponse envoyée.'
                                        : (provider.error ?? 'Erreur.'),
                                  ),
                                ),
                              );
                            },
                      icon: const Icon(Icons.reply),
                      label: const Text('Répondre'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrders(MerchantMarketplaceConsoleProviderV2 provider) {
    final items = provider.orders;

    if (provider.isLoading && items.isEmpty) {
      return const MarketplaceShimmerList();
    }

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: provider.loadMyOrders,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            Center(child: Text('Aucune commande.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.loadMyOrders,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final o = items[index];
          final id = o['id']?.toString() ?? '';
          final status = o['status']?.toString() ?? '';
          final currency = o['currency']?.toString();
          final total = o['total_amount'];

          return Card(
            child: ListTile(
              title: Text(
                'Total: ${_formatMoney(total, currency)}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text('Statut: $status'),
              trailing: const Icon(Icons.chevron_right),
              onTap: provider.isLoading || id.isEmpty
                  ? null
                  : () => _openOrderDetailSheet(
                        provider: provider,
                        orderId: id,
                      ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReviews(MerchantMarketplaceConsoleProviderV2 provider) {
    final items = provider.myReviews;

    if (provider.isLoading && items.isEmpty) {
      return const MarketplaceShimmerList();
    }

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: provider.loadMyReviews,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            Center(child: Text('Aucun avis reçu.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.loadMyReviews,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final r = items[index];
          final reviewId = r['id']?.toString() ?? '';
          final rating = r['rating'] as int? ?? 5;
          final reviewTitle = r['review_title']?.toString() ?? '';
          final content = r['content']?.toString() ?? '';
          final buyerName = r['buyer_name']?.toString() ?? 'Acheteur';
          final listingTitle = r['listing_title']?.toString() ?? '';
          final verified = r['is_verified_purchase'] == true;
          final sellerReply = r['seller_reply']?.toString();
          final hasReply = sellerReply != null && sellerReply.isNotEmpty;

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ...List.generate(5, (i) => Icon(
                        i < rating ? Icons.star : Icons.star_border,
                        size: 16,
                        color: const Color(0xFFF59E0B),
                      )),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          buyerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                      if (verified)
                        const Icon(Icons.verified, size: 16, color: Color(0xFF10B981)),
                    ],
                  ),
                  if (listingTitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      listingTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                  if (reviewTitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(reviewTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                  if (content.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(content, style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.4)),
                  ],
                  if (hasReply) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.reply, size: 14, color: Color(0xFF6B7280)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(sellerReply, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: provider.isLoading || reviewId.isEmpty
                        ? null
                        : () => _showReplyDialog(provider, reviewId, hasReply ? sellerReply : null),
                    icon: Icon(hasReply ? Icons.edit : Icons.reply, size: 16),
                    label: Text(hasReply ? 'Modifier la réponse' : 'Répondre'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showReplyDialog(
    MerchantMarketplaceConsoleProviderV2 provider,
    String reviewId,
    String? currentReply,
  ) async {
    final controller = TextEditingController(text: currentReply ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Répondre à l\'avis'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Votre réponse',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Envoyer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    final reply = controller.text.trim();
    if (reply.isEmpty) return;

    final ok = await provider.replyToReview(reviewId: reviewId, reply: reply);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Réponse envoyée.' : (provider.error ?? 'Erreur.'))),
    );
  }

  Widget _buildRevenueTab(MerchantMarketplaceConsoleProviderV2 provider) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadMerchantBalance(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final balance = snapshot.data ?? {};
        final available = balance['available_balance'] ?? 0;
        final totalEarned = balance['total_earned'] ?? 0;
        final totalCommission = balance['total_commission'] ?? 0;
        final currency = balance['currency']?.toString() ?? 'XOF';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Balance card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1E3A5F), Color(0xFF2563EB)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text('Solde disponible', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 6),
                    Text('${_formatMoney(available, currency)}',
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(children: [
                          Text(_formatMoney(totalEarned, currency),
                              style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 14, fontWeight: FontWeight.bold)),
                          const Text('Total gagné', style: TextStyle(color: Colors.white60, fontSize: 10)),
                        ]),
                        Container(width: 1, height: 30, color: Colors.white24),
                        Column(children: [
                          Text(_formatMoney(totalCommission, currency),
                              style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 14, fontWeight: FontWeight.bold)),
                          const Text('Commission plateforme', style: TextStyle(color: Colors.white60, fontSize: 10)),
                        ]),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Auto-payout info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6EE7B7)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.autorenew, color: Color(0xFF059669), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Les versements sont automatiques vers votre compte LigdiCash.',
                        style: TextStyle(fontSize: 12, color: const Color(0xFF065F46)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('Comment ça marche', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _revenueInfoRow(Icons.shopping_cart, 'Un client passe commande et paie via LigdiCash'),
              _revenueInfoRow(Icons.lock, 'Le montant est bloqué en escrow jusqu\'à la livraison'),
              _revenueInfoRow(Icons.check_circle, 'Après livraison, l\'escrow est libéré'),
              _revenueInfoRow(Icons.account_balance_wallet, 'Votre part est automatiquement transférée vers votre compte LigdiCash'),
            ],
          ),
        );
      },
    );
  }

  Widget _revenueInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6B7280)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF374151)))),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _loadMerchantBalance() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return {};
      final merchant = await client.schema('app').from('marketplace_merchants')
          .select('id').eq('owner_user_id', userId).limit(1).maybeSingle();
      if (merchant == null) return {};
      final balance = await client.schema('app').from('marketplace_merchant_balances')
          .select().eq('merchant_id', merchant['id']).maybeSingle();
      return balance ?? {};
    } catch (_) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<MerchantMarketplaceConsoleProviderV2>(
        builder: (context, provider, child) {
          return DefaultTabController(
            length: 5,
            child: Scaffold(
              backgroundColor: const Color(0xFFF3F4F6),
              appBar: AppBar(
                title: const Text('Console Marchand'),
                bottom: const TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(text: 'Mes annonces'),
                    Tab(text: 'Demandes'),
                    Tab(text: 'Commandes'),
                    Tab(text: 'Avis'),
                    Tab(text: 'Mes revenus'),
                  ],
                ),
                actions: [
                  IconButton(
                    onPressed: provider.isLoading ? null : provider.refreshAll,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Rafraîchir',
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const StudentSettingsScreen(
                            showProfile: false,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings),
                    tooltip: 'Paramètres',
                  ),
                  const BoutonDeconnexion(),
                ],
              ),
              floatingActionButton: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SupportFab(),
                  const SizedBox(height: 12),
                  FloatingActionButton(
                    heroTag: 'merchant_add_fab',
                    onPressed: provider.isLoading
                        ? null
                        : () => _openUpsertDialog(
                              context: context,
                              provider: provider,
                            ),
                    child: const Icon(Icons.add),
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
                        _buildMyOpportunities(provider),
                        _buildInquiries(provider),
                        _buildOrders(provider),
                        _buildReviews(provider),
                        _buildRevenueTab(provider),
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
