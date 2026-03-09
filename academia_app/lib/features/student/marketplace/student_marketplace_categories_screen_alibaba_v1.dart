import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/student_marketplace_categories_provider_v1.dart';
import '../../../widgets/marketplace/alibaba_marketplace_tokens.dart';
import '../../../widgets/marketplace/alibaba_press_scale.dart';
import '../../../widgets/marketplace/marketplace_shimmer.dart';

class StudentMarketplaceCategoriesScreenAlibabaV1 extends StatefulWidget {
  const StudentMarketplaceCategoriesScreenAlibabaV1({super.key});

  @override
  State<StudentMarketplaceCategoriesScreenAlibabaV1> createState() =>
      _StudentMarketplaceCategoriesScreenAlibabaV1State();
}

class _StudentMarketplaceCategoriesScreenAlibabaV1State
    extends State<StudentMarketplaceCategoriesScreenAlibabaV1> {
  String? _selectedRootId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<StudentMarketplaceCategoriesProviderV1>().loadRootCategories();
      if (!mounted) return;
      final roots = context.read<StudentMarketplaceCategoriesProviderV1>().rootCategories;
      final firstId = roots.isNotEmpty ? roots.first['id']?.toString() : null;
      if (firstId != null && firstId.trim().isNotEmpty) {
        setState(() => _selectedRootId = firstId);
        await context.read<StudentMarketplaceCategoriesProviderV1>().loadSubCategories(firstId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AlibabaMarketplaceTokens.bg,
      appBar: AppBar(
        title: const Text('Catégories'),
      ),
      body: Consumer<StudentMarketplaceCategoriesProviderV1>(
        builder: (context, provider, _) {
          final roots = provider.rootCategories;

          if (provider.isLoading && roots.isEmpty) {
            return const _CategoriesTwoPaneShimmer();
          }

          if (provider.error != null && roots.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Color(0xFF9CA3AF),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      provider.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () async {
                        await context
                            .read<StudentMarketplaceCategoriesProviderV1>()
                            .loadRootCategories();
                      },
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (roots.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.category_outlined,
                      size: 56,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Aucune catégorie',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final effectiveRootId = _selectedRootId ?? roots.first['id']?.toString();
          final subs = (effectiveRootId == null)
              ? const <Map<String, dynamic>>[]
              : provider.subCategories(effectiveRootId);

          return LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final leftW = (w * 0.32).clamp(110.0, 160.0);
              return Row(
                children: [
                  SizedBox(
                    width: leftW,
                    child: _LeftRootsList(
                      roots: roots,
                      selectedRootId: effectiveRootId,
                      onSelect: (id) async {
                        setState(() => _selectedRootId = id);
                        await context
                            .read<StudentMarketplaceCategoriesProviderV1>()
                            .loadSubCategories(id);
                      },
                    ),
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    child: _RightSubCategoriesGrid(
                      parentId: effectiveRootId,
                      subs: subs,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _CategoriesTwoPaneShimmer extends StatelessWidget {
  const _CategoriesTwoPaneShimmer();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final leftW = (w * 0.32).clamp(110.0, 160.0);

        return Row(
          children: [
            SizedBox(
              width: leftW,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: 8,
                itemBuilder: (context, index) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: MarketplaceShimmerBox(
                      width: double.infinity,
                      height: 46,
                      radius: 12,
                    ),
                  );
                },
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const gap = 10.0;
                    final maxW = constraints.maxWidth;
                    final tileW = ((maxW - gap * 2) / 3).clamp(86.0, 140.0);

                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (var i = 0; i < 12; i++)
                          SizedBox(
                            width: tileW,
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MarketplaceShimmerBox(
                                  width: double.infinity,
                                  height: 86,
                                  radius: 12,
                                ),
                                SizedBox(height: 10),
                                MarketplaceShimmerBox(
                                  width: double.infinity,
                                  height: 12,
                                  radius: 8,
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LeftRootsList extends StatelessWidget {
  final List<Map<String, dynamic>> roots;
  final String? selectedRootId;
  final ValueChanged<String> onSelect;

  const _LeftRootsList({
    required this.roots,
    required this.selectedRootId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: roots.length,
      itemBuilder: (context, index) {
        final r = roots[index];
        final id = r['id']?.toString() ?? '';
        final label = r['label']?.toString() ?? '';
        final selected = id.isNotEmpty && selectedRootId == id;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: AlibabaPressScale(
            onTap: id.isEmpty ? null : () => onSelect(id),
            borderRadius: BorderRadius.circular(12),
            child: Material(
              color: selected
                  ? AlibabaMarketplaceTokens.primaryOrange
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    color: selected ? Colors.white : const Color(0xFF111827),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RightSubCategoriesGrid extends StatelessWidget {
  final String? parentId;
  final List<Map<String, dynamic>> subs;

  const _RightSubCategoriesGrid({
    required this.parentId,
    required this.subs,
  });

  @override
  Widget build(BuildContext context) {
    if (parentId == null || parentId!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    if (subs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aucune sous-catégorie',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final w = constraints.maxWidth;
        final tileW = ((w - gap * 2) / 3).clamp(86.0, 140.0);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final sc in subs)
                SizedBox(
                  width: tileW,
                  child: _SubCategoryTile(
                    id: sc['id']?.toString() ?? '',
                    label: sc['label']?.toString() ?? '',
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SubCategoryTile extends StatelessWidget {
  final String id;
  final String label;

  const _SubCategoryTile({
    required this.id,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(AlibabaMarketplaceTokens.radiusCard);

    return AlibabaPressScale(
      onTap: id.trim().isEmpty
          ? null
          : () {
              Navigator.of(context).pop({
                'subCategoryId': id,
              });
            },
      borderRadius: br,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: br,
          border: Border.all(color: AlibabaMarketplaceTokens.divider),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AlibabaMarketplaceTokens.primaryOrange
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.grid_view_rounded,
                size: 16,
                color: AlibabaMarketplaceTokens.primaryOrange,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.15,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
