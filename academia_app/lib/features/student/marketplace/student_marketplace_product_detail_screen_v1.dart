import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../providers/student_marketplace_cart_provider_v1.dart';
import '../../../providers/student_marketplace_listings_provider_v1.dart';
import 'student_marketplace_cart_screen_v1.dart';
import 'student_merchant_profile_screen_v1.dart';

class StudentMarketplaceProductDetailScreenV1 extends StatefulWidget {
  final String listingId;

  const StudentMarketplaceProductDetailScreenV1({
    super.key,
    required this.listingId,
  });

  @override
  State<StudentMarketplaceProductDetailScreenV1> createState() =>
      _StudentMarketplaceProductDetailScreenV1State();
}

class _StudentMarketplaceProductDetailScreenV1State
    extends State<StudentMarketplaceProductDetailScreenV1> {
  bool _loading = false;
  String? _error;

  final PageController _pageController = PageController();
  int _activeMediaIndex = 0;

  Map<String, dynamic>? _listing;
  List<Map<String, dynamic>> _media = const [];
  bool _isBookmarked = false;

  bool _isAddingToCart = false;
  bool _addToCartSuccess = false;

  void _prefetchAroundIndex(List<String> urls, int index) {
    if (!mounted) return;
    if (urls.isEmpty) return;

    final current = index.clamp(0, urls.length - 1);
    final next = (current + 1) % urls.length;
    for (final i in <int>{current, next}) {
      final u = urls[i];
      if (u.trim().isEmpty) continue;
      precacheImage(NetworkImage(u), context);
    }

  }

  List<String> _buildOrderedUrls({
    required String listingId,
    required String? coverUrl,
    required List<Map<String, dynamic>> media,
  }) {
    final out = <String>[];
    final seen = <String>{};

    final c = (coverUrl ?? '').trim();
    if (c.isNotEmpty && seen.add(c)) {
      out.add(c);
    }

    for (final m in media) {
      final u = (m['url'] ?? '').toString().trim();
      if (u.isEmpty) continue;
      if (seen.add(u)) out.add(u);
    }

    return out;
  }


  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    final id = widget.listingId.trim();
    if (id.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;
      final response = await client.rpc(
        'app_student_get_marketplace_listing_detail',
        params: {
          'p_listing_id': id,
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

      final listingRaw = response['listing'];
      final mediaRaw = response['media'];

      setState(() {
        _listing = listingRaw is Map ? Map<String, dynamic>.from(listingRaw) : null;
        _media = (mediaRaw is List)
            ? mediaRaw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList(growable: false)
            : <Map<String, dynamic>>[];
        _isBookmarked = response['is_bookmarked'] == true;
      });

      final listing = listingRaw is Map ? Map<String, dynamic>.from(listingRaw) : null;
      final coverUrl = listing?['cover_url']?.toString().trim();
      final urls = _buildOrderedUrls(
        listingId: id,
        coverUrl: coverUrl,
        media: (mediaRaw is List)
            ? mediaRaw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList(growable: false)
            : <Map<String, dynamic>>[],
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _prefetchAroundIndex(urls, 0);
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

  Future<void> _addToCart() async {
    final listingId = widget.listingId.trim();
    if (listingId.isEmpty) return;

    if (_isAddingToCart) return;

    setState(() {
      _isAddingToCart = true;
      _addToCartSuccess = false;
    });

    HapticFeedback.lightImpact();
    final cart = context.read<StudentMarketplaceCartProviderV1>();
    final ok = await cart.addItem(listingId: listingId, quantity: 1);
    if (!mounted) return;

    if (ok) {
      setState(() {
        _addToCartSuccess = true;
      });
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        setState(() {
          _addToCartSuccess = false;
        });
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Ajouté au panier.'
              : (cart.errorMessage ?? cart.error ?? 'Erreur panier.'),
        ),
        action: ok
            ? SnackBarAction(
                label: 'Voir panier',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const StudentMarketplaceCartScreenV1(),
                    ),
                  );
                },
              )
            : null,
      ),
    );

    setState(() {
      _isAddingToCart = false;
    });
  }

  Future<void> _toggleBookmark() async {
    final listingId = widget.listingId.trim();
    if (listingId.isEmpty) return;

    final listingsProvider = context.read<StudentMarketplaceListingsProviderV1>();
    final ok = await listingsProvider.toggleBookmark(listingId);
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(listingsProvider.error ?? 'Erreur favoris.')),
      );
      return;
    }

    setState(() {
      _isBookmarked = !_isBookmarked;
    });
  }

  Future<void> _contactMerchant() async {
    final listingId = widget.listingId.trim();
    if (listingId.isEmpty) return;

    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Contacter le vendeur'),
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

    try {
      final msg = controller.text.trim();
      final client = Supabase.instance.client;
      final response = await client.rpc(
        'app_student_create_marketplace_listing_inquiry',
        params: {
          'p_listing_id': listingId,
          'p_message': msg.isEmpty ? 'Bonjour, je suis intéressé.' : msg,
        },
      );

      if (!mounted) return;

      if (response is Map && response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message envoyé.')),
        );
      } else {
        final err = (response is Map) ? response['error']?.toString() : null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err ?? 'Erreur envoi.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  String _formatMoney(dynamic v, String? currency) {
    if (v is num) {
      final cur = (currency ?? '').trim();
      if (cur.isEmpty) return '${v.toStringAsFixed(0)} FCFA';
      return '${v.toStringAsFixed(0)} $cur';
    }
    return v?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final listing = _listing;

    final title = listing?['title']?.toString() ?? '';
    final desc = listing?['description']?.toString() ?? '';
    final shortDesc = listing?['short_description']?.toString() ?? '';
    final merchantId = listing?['merchant_id']?.toString();
    final coverUrl = listing?['cover_url']?.toString().trim();

    final priceFrom = listing?['price_from'];
    final currency = listing?['currency']?.toString();
    final minQty = listing?['min_order_qty'];
    final leadTime = listing?['lead_time_days'];
    final readyToShip = listing?['is_ready_to_ship'] == true;

    final urls = _buildOrderedUrls(
      listingId: widget.listingId,
      coverUrl: coverUrl,
      media: _media,
    );
    final mediaCount = urls.length;
    if (_activeMediaIndex >= mediaCount) {
      _activeMediaIndex = 0;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Détails'),
        actions: [
          IconButton(
            tooltip: 'Partager',
            onPressed: listing == null
                ? null
                : () {
                    final text = title.trim().isEmpty
                        ? 'Annonce Marketplace'
                        : title.trim();
                    Share.share(text);
                  },
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: 'Favori',
            onPressed: _loading ? null : _toggleBookmark,
            icon: Icon(_isBookmarked ? Icons.bookmark : Icons.bookmark_border),
          ),
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _loading
            ? const Center(
                key: ValueKey('loading'),
                child: CircularProgressIndicator(),
              )
            : _error != null
                ? Center(
                    key: const ValueKey('error'),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  )
                : listing == null
                    ? const Center(
                        key: ValueKey('not_found'),
                        child: Text('Annonce introuvable.'),
                      )
                    : Stack(
                        key: const ValueKey('content'),
                        children: [
                          ListView(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 110),
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: urls.isEmpty
                                      ? Container(
                                          height: 220,
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Color(0xFF111827),
                                                Color(0xFF374151),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.image_outlined,
                                              color: Colors.white,
                                              size: 48,
                                            ),
                                          ),
                                        )
                                      : Stack(
                                          children: [
                                            SizedBox(
                                              height: 260,
                                              child: PageView.builder(
                                                controller: _pageController,
                                                onPageChanged: (i) {
                                                  setState(() {
                                                    _activeMediaIndex = i;
                                                  });

                                                  _prefetchAroundIndex(urls, i);
                                                },
                                                itemCount: urls.length,
                                                itemBuilder: (context, index) {
                                                  final u = urls[index];
                                                  final isHero =
                                                      index == 0 &&
                                                      coverUrl != null &&
                                                      coverUrl.isNotEmpty &&
                                                      u == coverUrl;

                                                  final img = Image.network(
                                                    u,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (context, error, stack) {
                                                      return Container(
                                                        color: const Color(0xFFF1F0EB),
                                                        child: const Center(
                                                          child: Icon(
                                                            Icons.image_not_supported_outlined,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  );

                                                  if (!isHero) return img;
                                                  return Hero(
                                                    tag:
                                                        'marketplace_listing_cover_${widget.listingId.trim()}',
                                                    child: img,
                                                  );
                                                },
                                              ),
                                            ),
                                          Positioned(
                                            right: 10,
                                            top: 10,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.45),
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                '${_activeMediaIndex + 1}/${urls.length}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (urls.length > 1)
                                            Positioned(
                                              left: 0,
                                              right: 0,
                                              bottom: 10,
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: List.generate(urls.length,
                                                    (i) {
                                                  final active =
                                                      i == _activeMediaIndex;
                                                  return AnimatedContainer(
                                                    duration: const Duration(
                                                      milliseconds: 160,
                                                    ),
                                                    margin:
                                                        const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                    ),
                                                    height: 8,
                                                    width: active ? 18 : 8,
                                                    decoration: BoxDecoration(
                                                      color: active
                                                          ? Colors.white
                                                          : Colors.white
                                                              .withOpacity(0.55),
                                                      borderRadius:
                                                          BorderRadius.circular(999),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(0.25),
                                                          blurRadius: 8,
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }),
                                              ),
                                            ),
                                        ],
                                      ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                  if (shortDesc.trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      shortDesc,
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      if (priceFrom != null)
                                        _InfoChip(
                                          icon: Icons.payments_outlined,
                                          label: 'À partir de ${_formatMoney(priceFrom, currency)}',
                                          color: const Color(0xFFF97316),
                                        ),
                                      if (minQty != null)
                                        _InfoChip(
                                          icon: Icons.inventory_2_outlined,
                                          label: 'MOQ ${minQty.toString()}',
                                        ),
                                      if (leadTime != null)
                                        _InfoChip(
                                          icon: Icons.timelapse,
                                          label: 'Délai ${leadTime.toString()}j',
                                        ),
                                      if (readyToShip)
                                        const _InfoChip(
                                          icon: Icons.local_shipping_outlined,
                                          label: 'Prêt à expédier',
                                          color: Color(0xFF059669),
                                        ),
                                    ],
                                  ),
                                  if (desc.trim().isNotEmpty) ...[
                                    const SizedBox(height: 14),
                                    const Text(
                                      'Description',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      desc,
                                      style: const TextStyle(
                                        color: Color(0xFF1F2937),
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                  if (merchantId != null && merchantId.trim().isNotEmpty) ...[
                                    const SizedBox(height: 14),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => StudentMerchantProfileScreenV1(
                                              merchantId: merchantId,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.storefront_outlined),
                                      label: const Text('Voir le vendeur'),
                                    ),
                                  ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: SafeArea(
                              top: false,
                              child: Container(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border(
                                    top: BorderSide(
                                      color: Colors.black.withOpacity(0.06),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 48,
                                        child: AnimatedScale(
                                          scale: _isAddingToCart ? 0.98 : 1.0,
                                          duration:
                                              const Duration(milliseconds: 120),
                                          curve: Curves.easeOut,
                                          child: ElevatedButton.icon(
                                            onPressed:
                                                _isAddingToCart ? null : _addToCart,
                                            icon: AnimatedSwitcher(
                                              duration: const Duration(
                                                milliseconds: 180,
                                              ),
                                              child: Icon(
                                                _addToCartSuccess
                                                    ? Icons.check_circle_outline
                                                    : Icons.add_shopping_cart,
                                                key: ValueKey(
                                                  _addToCartSuccess,
                                                ),
                                              ),
                                            ),
                                            label: AnimatedSwitcher(
                                              duration: const Duration(
                                                milliseconds: 180,
                                              ),
                                              child: Text(
                                                _addToCartSuccess
                                                    ? 'Ajouté'
                                                    : 'Ajouter au panier',
                                                key: ValueKey(
                                                  _addToCartSuccess,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    SizedBox(
                                      height: 48,
                                      child: OutlinedButton.icon(
                                        onPressed: _contactMerchant,
                                        icon: const Icon(
                                            Icons.chat_bubble_outline),
                                        label: const Text('Contacter'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color = const Color(0xFF64748B),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
