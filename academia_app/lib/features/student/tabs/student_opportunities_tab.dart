import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/student_marketplace_listings_provider_v1.dart';
import '../../../providers/student_marketplace_categories_provider_v1.dart';
import '../../../providers/student_marketplace_cart_provider_v1.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../widgets/marketplace/alibaba_marketplace_tokens.dart';
import '../../../widgets/marketplace/alibaba_search_bar.dart';
import '../../../widgets/marketplace/alibaba_section_header.dart';
import '../../../widgets/marketplace/alibaba_marketplace_shimmers.dart';
import '../../../widgets/marketplace/marketplace_product_card.dart';
import '../marketplace/student_my_inquiries_screen_v1.dart';
import '../marketplace/student_marketplace_favorites_screen_v1.dart';
import '../marketplace/student_marketplace_cart_screen_v1.dart';
import '../marketplace/student_marketplace_categories_screen_alibaba_v1.dart';
import '../marketplace/student_marketplace_product_detail_screen_v1.dart';
import '../marketplace/student_marketplace_my_orders_screen_v1.dart';
import '../../share/share_service.dart';
import '../../share/share_mode_provider.dart';

/// Onglet Opportunités - Feed social style Facebook/LinkedIn
class StudentOpportunitiesTab extends StatefulWidget {
  const StudentOpportunitiesTab({super.key});

  @override
  State<StudentOpportunitiesTab> createState() => _StudentOpportunitiesTabState();
}

class _StudentOpportunitiesTabState extends State<StudentOpportunitiesTab> {
  String _searchQuery = '';
  String? _selectedType;
  int _tabIndex = 0;
  String? _selectedMarketplaceCategoryId;
  String? _selectedMarketplaceSubCategoryId;
  bool _marketplaceGridMode = true;
  int _marketplaceHomeTabIndex = 1;
  String _sort = 'newest';
  bool _verifiedOnly = false;
  bool _readyToShipOnly = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _shareBoundaryKey = GlobalKey();
  final ShareService _shareService = ShareService();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
      context.read<StudentMarketplaceCartProviderV1>().loadCart();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _shareCurrentView() async {
    await _shareService.shareCurrentView(
      context: context,
      boundaryKey: _shareBoundaryKey,
      shareText: 'Découvert via Academia – Faciliter l’accès aux formations.',
    );
  }

  Widget _buildMarketplaceHomeSection({required int total}) {
    return Consumer2<StudentMarketplaceCategoriesProviderV1,
        StudentMarketplaceListingsProviderV1>(
      builder: (context, categoriesProvider, listingsProvider, child) {
        final categories = categoriesProvider.rootCategories;
        final items = listingsProvider.items;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AlibabaMarketplaceTokens.surface,
                  borderRadius: BorderRadius.circular(AlibabaMarketplaceTokens.radiusCard),
                  border: Border.all(color: AlibabaMarketplaceTokens.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.shopping_bag_outlined,
                          color: AlibabaMarketplaceTokens.primaryOrange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Produits',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: AlibabaMarketplaceTokens.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '$total',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AlibabaMarketplaceTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    AlibabaSearchBar(
                      controller: _searchController,
                      onChanged: (v) => _onSearchChanged(v),
                      onSearch: _onRefresh,
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _AlibabaHomeTabChip(
                            label: 'Mode IA',
                            selected: _marketplaceHomeTabIndex == 0,
                            onTap: () => setState(() => _marketplaceHomeTabIndex = 0),
                          ),
                          const SizedBox(width: 8),
                          _AlibabaHomeTabChip(
                            label: 'Produits',
                            selected: _marketplaceHomeTabIndex == 1,
                            onTap: () => setState(() => _marketplaceHomeTabIndex = 1),
                          ),
                          const SizedBox(width: 8),
                          _AlibabaHomeTabChip(
                            label: 'Fabricants',
                            selected: _marketplaceHomeTabIndex == 2,
                            onTap: () => setState(() => _marketplaceHomeTabIndex = 2),
                          ),
                          const SizedBox(width: 8),
                          _AlibabaHomeTabChip(
                            label: 'Mondial',
                            selected: _marketplaceHomeTabIndex == 3,
                            onTap: () => setState(() => _marketplaceHomeTabIndex = 3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionPill(
                            icon: Icons.verified_outlined,
                            label: 'Vérifiés',
                            selected: _verifiedOnly,
                            onTap: () {
                              setState(() {
                                _verifiedOnly = !_verifiedOnly;
                              });
                              _onRefresh();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickActionPill(
                            icon: Icons.local_shipping_outlined,
                            label: 'Prêt',
                            selected: _readyToShipOnly,
                            onTap: () {
                              setState(() {
                                _readyToShipOnly = !_readyToShipOnly;
                              });
                              _onRefresh();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickActionPill(
                            icon: Icons.favorite_border,
                            label: 'Favoris',
                            selected: false,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const StudentMarketplaceFavoritesScreenV1(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AlibabaSectionHeader(
                title: 'Catégories',
                onTap: () {
                  Navigator.of(context)
                      .push<Map<String, dynamic>>(
                    MaterialPageRoute(
                      builder: (_) =>
                          const StudentMarketplaceCategoriesScreenAlibabaV1(),
                    ),
                  )
                      .then((result) {
                    if (!mounted) return;
                    if (result == null) return;
                    final subId = result['subCategoryId']?.toString();
                    if (subId == null || subId.trim().isEmpty) return;
                    setState(() {
                      _selectedMarketplaceSubCategoryId = subId;
                    });
                    _onRefresh();
                  });
                },
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final c = categories[index];
                    final id = c['id']?.toString();
                    final label = c['label']?.toString() ?? '';
                    final selected = id != null && _selectedMarketplaceCategoryId == id;

                    return GestureDetector(
                      onTap: () async {
                        if (id == null || id.isEmpty) return;
                        setState(() {
                          _selectedMarketplaceCategoryId = id;
                          _selectedMarketplaceSubCategoryId = null;
                        });
                        await context
                            .read<StudentMarketplaceCategoriesProviderV1>()
                            .loadSubCategories(id);
                        if (!mounted) return;
                        await _onRefresh();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 120,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF2196F3)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFE0E0E0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2196F3).withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.category_outlined,
                              size: 20,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF424242),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF424242),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              if (items.isNotEmpty) ...[
                AlibabaSectionHeader(
                  title: 'Meilleures offres',
                  onTap: null,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 240,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length > 10 ? 10 : items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final it = items[index];
                      final id = it['id']?.toString();

                      return SizedBox(
                        width: 170,
                        child: MarketplaceProductCard(
                          listing: it,
                          compact: true,
                          onTap: () {
                            if (id == null || id.isEmpty) return;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    StudentMarketplaceProductDetailScreenV1(
                                  listingId: id,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Text(
                'Pour toi',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_tabIndex == 0) {
        final provider = context.read<StudentMarketplaceListingsProviderV1>();
        if (provider.hasMore && !provider.isLoadingMore) {
          provider.loadMore();
        }
        return;
      }
    }
  }

  Future<void> _loadInitialData() async {
    final categoriesProvider =
        context.read<StudentMarketplaceCategoriesProviderV1>();
    final marketplaceListingsProvider =
        context.read<StudentMarketplaceListingsProviderV1>();

    await categoriesProvider.loadRootCategories();
    if (!mounted) return;
    await marketplaceListingsProvider.loadListings(
          type: _selectedType,
          search: _searchQuery.isEmpty ? null : _searchQuery,
          sort: _sort,
          verifiedOnly: _verifiedOnly,
          readyToShipOnly: _readyToShipOnly,
          categoryId: _selectedMarketplaceCategoryId,
          subCategoryId: _selectedMarketplaceSubCategoryId,
          refresh: true,
        );
  }

  Future<void> _onRefresh() async {
    if (_tabIndex == 0) {
      await context.read<StudentMarketplaceListingsProviderV1>().loadListings(
            type: _selectedType,
            search: _searchQuery.isEmpty ? null : _searchQuery,
            sort: _sort,
            verifiedOnly: _verifiedOnly,
            readyToShipOnly: _readyToShipOnly,
            categoryId: _selectedMarketplaceCategoryId,
            subCategoryId: _selectedMarketplaceSubCategoryId,
            refresh: true,
          );
      return;
    }
  }

  Future<void> _openFiltersSheet() async {
    final currentSort = _sort;
    bool verifiedOnly = _verifiedOnly;
    bool readyToShipOnly = _readyToShipOnly;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        String sort = currentSort;
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 14,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Filtres & tri',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tri',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: sort,
                    items: const [
                      DropdownMenuItem(value: 'newest', child: Text('Plus récent')),
                      DropdownMenuItem(value: 'price_asc', child: Text('Prix croissant')),
                      DropdownMenuItem(value: 'price_desc', child: Text('Prix décroissant')),
                    ],
                    onChanged: (v) => setState(() => sort = v ?? 'newest'),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    value: verifiedOnly,
                    onChanged: (v) => setState(() => verifiedOnly = v),
                    title: const Text('Vendeurs vérifiés uniquement'),
                  ),
                  SwitchListTile(
                    value: readyToShipOnly,
                    onChanged: (v) => setState(() => readyToShipOnly = v),
                    title: const Text('Prêt à expédier uniquement'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop({
                              'sort': 'newest',
                              'verifiedOnly': false,
                              'readyToShipOnly': false,
                              'reset': true,
                            });
                          },
                          child: const Text('Réinitialiser'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop({
                              'sort': sort,
                              'verifiedOnly': verifiedOnly,
                              'readyToShipOnly': readyToShipOnly,
                            });
                          },
                          child: const Text('Appliquer'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted || result == null) return;
    setState(() {
      _sort = result['sort']?.toString() ?? _sort;
      _verifiedOnly = result['verifiedOnly'] == true;
      _readyToShipOnly = result['readyToShipOnly'] == true;
    });
    await _onRefresh();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _shareBoundaryKey,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tabIndex,
          onDestinationSelected: (i) {
            setState(() => _tabIndex = i);
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: 'Accueil',
            ),
            Consumer<StudentMarketplaceCartProviderV1>(
              builder: (context, cart, _) {
                final c = cart.itemsCount;
                return NavigationDestination(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.shopping_cart_outlined),
                      if (c > 0)
                        Positioned(
                          right: -10,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AlibabaMarketplaceTokens.primaryOrange,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              c > 99 ? '99+' : c.toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  selectedIcon: const Icon(Icons.shopping_cart),
                  label: 'Panier',
                );
              },
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Compte',
            ),
          ],
        ),
        body: _tabIndex == 0
            ? _buildMarketplaceTabBody()
            : _tabIndex == 1
                ? const StudentMarketplaceCartScreenV1(showAppBar: false)
                : const _OpportunitiesAccountTab(),
      ),
    );
  }

  Widget _buildMarketplaceTabBody() {
    return NestedScrollView(
      controller: _scrollController,
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(
            child: _buildHeader(),
          ),
        ];
      },
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: Consumer<StudentMarketplaceListingsProviderV1>(
          builder: (context, provider, child) {
            if (provider.isLoading && provider.items.isEmpty) {
              return const SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AlibabaRailShimmer(itemCount: 6),
                    SizedBox(height: 16),
                    AlibabaGridShimmer(itemCount: 8),
                  ],
                ),
              );
            }

            if (provider.error != null && provider.items.isEmpty) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Color(0xFF9E9E9E),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          provider.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _onRefresh,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final opportunities = provider.items;
            if (opportunities.isEmpty) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Aucune annonce disponible',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Reviens voir régulièrement pour découvrir de nouvelles annonces !',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final int itemCount = opportunities.length + (provider.hasMore ? 1 : 0);

            Widget buildCard(Map<String, dynamic> opp, int index) {
              return FadeInUp(
                duration: const Duration(milliseconds: 350),
                delay: Duration(milliseconds: 50 * (index < 10 ? index : 0)),
                child: MarketplaceProductCard(
                  listing: opp,
                  compact: _marketplaceGridMode,
                  onTap: () {
                    final id = opp['id']?.toString();
                    if (id == null || id.isEmpty) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            StudentMarketplaceProductDetailScreenV1(
                          listingId: id,
                        ),
                      ),
                    );
                  },
                  onAddToCart: () async {
                    final id = opp['id']?.toString();
                    if (id == null || id.isEmpty) return;
                    final cart = context.read<StudentMarketplaceCartProviderV1>();
                    final ok = await cart.addItem(listingId: id, quantity: 1);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Ajouté au panier.'
                              : (cart.errorMessage ?? cart.error ?? 'Erreur panier.'),
                        ),
                      ),
                    );
                  },
                  onBookmark: () async {
                    final id = opp['id']?.toString();
                    if (id == null) return;
                    final ok = await context
                        .read<StudentMarketplaceListingsProviderV1>()
                        .toggleBookmark(id);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.read<StudentMarketplaceListingsProviderV1>().error ??
                                'Erreur favori.',
                          ),
                        ),
                      );
                    }
                  },
                ),
              );
            }

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _buildMarketplaceHomeSection(
                    total: provider.total,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  sliver: SliverMasonryGrid.count(
                    crossAxisCount: _marketplaceGridMode ? 2 : 1,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childCount: itemCount,
                    itemBuilder: (context, index) {
                      if (index >= opportunities.length) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: provider.isLoadingMore
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : OutlinedButton(
                                    onPressed: provider.loadMore,
                                    child: const Text('Charger plus'),
                                  ),
                          ),
                        );
                      }
                      return buildCard(opportunities[index], index);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFFFAFAFA),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Marketplace',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF424242),
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Consumer<ShareModeProvider>(
                        builder: (context, shareMode, _) {
                          if (shareMode.isShareModeEnabled) {
                            return const SizedBox.shrink();
                          }
                          final isBusy = shareMode.isBusy;
                          return IconButton(
                            icon: const Icon(Icons.share),
                            tooltip: 'Partager',
                            onPressed: isBusy ? null : _shareCurrentView,
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline),
                        tooltip: 'Mes demandes',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const StudentMyInquiriesScreenV1(),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.favorite_border),
                        tooltip: 'Favoris Marketplace',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const StudentMarketplaceFavoritesScreenV1(),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: 'Mes commandes',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const StudentMarketplaceMyOrdersScreenV1(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.receipt_long_outlined),
                      ),
                      IconButton(
                        icon: Icon(
                          _marketplaceGridMode
                              ? Icons.view_list
                              : Icons.grid_view,
                        ),
                        tooltip: _marketplaceGridMode
                            ? 'Afficher en liste'
                            : 'Afficher en grille',
                        onPressed: () {
                          setState(() {
                            _marketplaceGridMode = !_marketplaceGridMode;
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.tune),
                        tooltip: 'Filtres & tri',
                        onPressed: _openFiltersSheet,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Consumer<StudentMarketplaceListingsProviderV1>(
                  builder: (context, provider, _) {
                    return Text(
                      '${provider.total} annonce${provider.total > 1 ? 's' : ''} disponible${provider.total > 1 ? 's' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9E9E9E),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OpportunitiesAccountTab extends StatelessWidget {
  const _OpportunitiesAccountTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF2196F3),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Mon compte',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF424242),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Mes commandes'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const StudentMarketplaceMyOrdersScreenV1(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('Mes demandes'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const StudentMyInquiriesScreenV1(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.favorite_border),
                title: const Text('Mes favoris'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const StudentMarketplaceFavoritesScreenV1(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AlibabaHomeTabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AlibabaHomeTabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? const Color(0xFF2196F3)
          : const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : const Color(0xFF424242),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _QuickActionPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2196F3) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.transparent : const Color(0xFFE0E0E0),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2196F3).withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : const Color(0xFF424242),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : const Color(0xFF424242),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

