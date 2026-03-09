import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/student_marketplace_cart_provider_v1.dart';
import '../../../widgets/marketplace/alibaba_marketplace_tokens.dart';
import '../../../widgets/marketplace/alibaba_marketplace_shimmers.dart';
import 'student_marketplace_order_confirmation_screen_v1.dart';

class StudentMarketplaceCartScreenV1 extends StatefulWidget {
  final bool showAppBar;

  const StudentMarketplaceCartScreenV1({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<StudentMarketplaceCartScreenV1> createState() =>
      _StudentMarketplaceCartScreenV1State();
}

class _StudentMarketplaceCartScreenV1State
    extends State<StudentMarketplaceCartScreenV1> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentMarketplaceCartProviderV1>().loadCart();
    });
  }

  String _formatMoney(num v, String? currency) {
    final cur = (currency ?? '').trim();
    if (cur.isEmpty) return '${v.toStringAsFixed(0)} FCFA';
    return '${v.toStringAsFixed(0)} $cur';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentMarketplaceCartProviderV1>(
      builder: (context, provider, child) {
        final items = provider.items;
        final hasError = provider.error != null;
        final errorText = provider.errorMessage ?? provider.error;

        return Scaffold(
          backgroundColor: AlibabaMarketplaceTokens.bg,
          appBar: widget.showAppBar
              ? AppBar(
                  title: const Text('Panier'),
                  actions: [
                    TextButton(
                      onPressed: provider.isMutating || provider.isLoading
                          ? null
                          : () async {
                              HapticFeedback.lightImpact();
                              final ok = await provider.clear();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? 'Panier vidé.'
                                        : (provider.errorMessage ??
                                            'Erreur panier.'),
                                  ),
                                  duration:
                                      const Duration(milliseconds: 900),
                                ),
                              );
                            },
                      child: const Text('Vider'),
                    ),
                  ],
                )
              : null,
          body: Column(
            children: [
              if (hasError && errorText != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(
                      AlibabaMarketplaceTokens.radiusCard,
                    ),
                    border: Border.all(
                      color: const Color(0xFFFF3B30).withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFFF3B30),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          errorText,
                          style: const TextStyle(
                            color: Color(0xFFFF3B30),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: provider.isLoading
                    ? const SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(12, 12, 12, 120),
                        child: AlibabaGridShimmer(itemCount: 8),
                      )
                    : items.isEmpty
                        ? const Center(
                            child: Text(
                              'Ton panier est vide.',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AlibabaMarketplaceTokens.textSecondary,
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                const gap = 12.0;
                                final maxW = constraints.maxWidth;
                                final columns = maxW < 360 ? 1 : 2;
                                final cardW = columns == 1
                                    ? maxW
                                    : (maxW - gap) / 2.0;

                                return Wrap(
                                  spacing: gap,
                                  runSpacing: gap,
                                  children: [
                                    for (final item in items)
                                      SizedBox(
                                        width: cardW,
                                        child: _AlibabaCartItemCard(
                                          item: item,
                                          isBusy: provider.isMutating ||
                                              provider.isLoading,
                                          formatMoney: _formatMoney,
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AlibabaMarketplaceTokens.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatMoney(provider.total, provider.currency),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AlibabaMarketplaceTokens.textPrimary,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                AlibabaMarketplaceTokens.primaryOrange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          onPressed: provider.isMutating ||
                                  provider.isLoading ||
                                  items.isEmpty
                              ? null
                              : () async {
                                  HapticFeedback.lightImpact();
                                  final res = await provider.checkout();
                                  if (!context.mounted) return;
                                  if (res == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          provider.errorMessage ??
                                              'Erreur commande.',
                                        ),
                                        duration:
                                            const Duration(milliseconds: 1100),
                                      ),
                                    );
                                    return;
                                  }

                                  final orders = res['orders'];
                                  if (orders is! List || orders.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Commande créée.'),
                                      ),
                                    );
                                    return;
                                  }

                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          StudentMarketplaceOrderConfirmationScreenV1(
                                        orders: orders
                                            .whereType<Map>()
                                            .map((e) =>
                                                Map<String, dynamic>.from(e))
                                            .toList(growable: false),
                                      ),
                                    ),
                                  );
                                },
                          child: provider.isMutating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Commander'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AlibabaCartItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isBusy;
  final String Function(num, String?) formatMoney;

  const _AlibabaCartItemCard({
    required this.item,
    required this.isBusy,
    required this.formatMoney,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<StudentMarketplaceCartProviderV1>();

    final itemId = item['id']?.toString() ?? '';
    final title = item['title']?.toString() ?? '';
    final q = (item['quantity'] is num)
        ? (item['quantity'] as num).toInt()
        : (item['quantity'] as int? ?? 1);
    final unitPrice = (item['unit_price'] is num)
        ? item['unit_price'] as num
        : ((item['price_from'] is num) ? item['price_from'] as num : 0);
    final currency = item['currency']?.toString();
    final subtotal = unitPrice * q;

    final borderRadius =
        BorderRadius.circular(AlibabaMarketplaceTokens.radiusCard);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius,
        border: Border.all(color: AlibabaMarketplaceTokens.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 92,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(
                  Icons.image_outlined,
                  size: 34,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AlibabaMarketplaceTokens.textPrimary,
                fontSize: 13,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatMoney(unitPrice, currency),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AlibabaMarketplaceTokens.price,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 34,
                    height: 34,
                  ),
                  onPressed: isBusy || q <= 1
                      ? null
                      : () async {
                          HapticFeedback.lightImpact();
                          final ok = await provider.updateQuantity(
                            itemId: itemId,
                            quantity: q - 1,
                          );
                          if (!context.mounted) return;
                          if (!ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  provider.errorMessage ?? 'Erreur panier.',
                                ),
                                duration: const Duration(milliseconds: 900),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  q.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AlibabaMarketplaceTokens.textPrimary,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 34,
                    height: 34,
                  ),
                  onPressed: isBusy
                      ? null
                      : () async {
                          HapticFeedback.lightImpact();
                          final ok = await provider.updateQuantity(
                            itemId: itemId,
                            quantity: q + 1,
                          );
                          if (!context.mounted) return;
                          if (!ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  provider.errorMessage ?? 'Erreur panier.',
                                ),
                                duration: const Duration(milliseconds: 900),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sous-total',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AlibabaMarketplaceTokens.textSecondary,
                    ),
                  ),
                ),
                Text(
                  formatMoney(subtotal, currency),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AlibabaMarketplaceTokens.textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 34,
                    height: 34,
                  ),
                  onPressed: isBusy
                      ? null
                      : () async {
                          HapticFeedback.lightImpact();
                          final ok = await provider.removeItem(itemId: itemId);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? 'Article supprimé.'
                                    : (provider.errorMessage ?? 'Erreur panier.'),
                              ),
                              duration: const Duration(milliseconds: 900),
                            ),
                          );
                        },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
