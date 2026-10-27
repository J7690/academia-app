import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../providers/student_marketplace_listings_provider_v1.dart';
import '../../../providers/student_marketplace_categories_provider_v1.dart';
import '../../../providers/student_marketplace_cart_provider_v1.dart';
import '../../../widgets/app_snack.dart';
import '../../../widgets/marketplace/alibaba_marketplace_tokens.dart';
import '../../../widgets/marketplace/alibaba_press_scale.dart';
import '../../../widgets/marketplace/alibaba_search_bar.dart';
import '../../../widgets/marketplace/alibaba_section_header.dart';
import '../../../widgets/marketplace/alibaba_marketplace_shimmers.dart';
import '../../../widgets/marketplace/marketplace_motion.dart';
import '../../../widgets/marketplace/marketplace_product_card.dart';
import '../marketplace/student_my_inquiries_screen_v1.dart';
import '../marketplace/student_marketplace_favorites_screen_v1.dart';
import '../marketplace/student_marketplace_cart_screen_v1.dart';
import '../marketplace/student_marketplace_categories_screen_alibaba_v1.dart';
import '../marketplace/student_marketplace_product_detail_screen_v1.dart';
import '../marketplace/student_marketplace_my_orders_screen_v1.dart';
import '../../share/share_service.dart';
import '../../share/share_mode_provider.dart';

typedef _T = AlibabaMarketplaceTokens;

/// Onglet Marketplace étudiant — Academia Market.
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
  String _sort = 'newest';
  bool _verifiedOnly = false;
  bool _readyToShipOnly = false;
  Timer? _searchDebounce;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _shareBoundaryKey = GlobalKey();
  final ShareService _shareService = ShareService();

  int get _activeFilters =>
      (_verifiedOnly ? 1 : 0) + (_readyToShipOnly ? 1 : 0) + (_sort != 'newest' ? 1 : 0);

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
    _searchDebounce?.cancel();
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

  void _onScroll() {
    if (_tabIndex != 0 || !_scrollController.hasClients) return;
    final p = _scrollController.position;
    if (p.pixels >= p.maxScrollExtent - 400) {
      final provider = context.read<StudentMarketplaceListingsProviderV1>();
      if (provider.hasMore && !provider.isLoadingMore && !provider.isLoading) {
        provider.loadMore();
      }
    }
  }

  Future<void> _loadInitialData() async {
    await context.read<StudentMarketplaceCategoriesProviderV1>().loadRootCategories();
    if (!mounted) return;
    await _onRefresh();
  }

  Future<void> _onRefresh() async {
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
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _searchQuery = value.trim());
      _onRefresh();
    });
  }

  void _setSort(String sort) {
    if (_sort == sort) return;
    setState(() => _sort = sort);
    _onRefresh();
  }

  Future<void> _selectCategory(String? id) async {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMarketplaceCategoryId = id;
      _selectedMarketplaceSubCategoryId = null;
    });
    if (id != null) {
      await context.read<StudentMarketplaceCategoriesProviderV1>().loadSubCategories(id);
    }
    if (!mounted) return;
    await _onRefresh();
  }

  Future<void> _openAllCategories() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const StudentMarketplaceCategoriesScreenAlibabaV1()),
    );
    if (!mounted || result == null) return;
    final subId = result['subCategoryId']?.toString();
    if (subId == null || subId.trim().isEmpty) return;
    setState(() => _selectedMarketplaceSubCategoryId = subId);
    _onRefresh();
  }

  void _openProduct(Map<String, dynamic> listing) {
    final id = listing['id']?.toString();
    if (id == null || id.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: _T.medium,
        reverseTransitionDuration: _T.medium,
        pageBuilder: (_, __, ___) => StudentMarketplaceProductDetailScreenV1(listingId: id),
        transitionsBuilder: (_, a, __, child) {
          final c = CurvedAnimation(parent: a, curve: _T.curve);
          return FadeTransition(
            opacity: c,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(c),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<bool> _addToCart(Map<String, dynamic> listing) async {
    final id = listing['id']?.toString();
    if (id == null || id.isEmpty) return false;
    final cart = context.read<StudentMarketplaceCartProviderV1>();
    final ok = await cart.addItem(listingId: id, quantity: 1);
    if (!mounted) return ok;
    if (!ok) {
      AppSnack.error(context, cart.errorMessage ?? cart.error ?? 'Erreur panier.');
    }
    return ok;
  }

  Future<void> _toggleBookmark(Map<String, dynamic> listing) async {
    final id = listing['id']?.toString();
    if (id == null) return;
    final provider = context.read<StudentMarketplaceListingsProviderV1>();
    final ok = await provider.toggleBookmark(id);
    if (!ok && mounted) {
      AppSnack.error(context, provider.error ?? 'Erreur favori.');
    }
  }

  Future<void> _openFiltersSheet() async {
    String sort = _sort;
    bool verifiedOnly = _verifiedOnly;
    bool readyToShipOnly = _readyToShipOnly;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(_T.radiusSheet)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            Widget sortChip(String value, String label, IconData icon) {
              final selected = sort == value;
              return Expanded(
                child: _SelectableTile(
                  selected: selected,
                  icon: icon,
                  label: label,
                  onTap: () => setSheet(() => sort = value),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _T.divider,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Filtres & tri',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _T.textPrimary),
                  ),
                  const SizedBox(height: 18),
                  const Text('Trier par', style: TextStyle(fontWeight: FontWeight.w700, color: _T.textSecondary)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      sortChip('newest', 'Récents', Icons.schedule_rounded),
                      const SizedBox(width: 8),
                      sortChip('price_asc', 'Prix ↑', Icons.trending_up_rounded),
                      const SizedBox(width: 8),
                      sortChip('price_desc', 'Prix ↓', Icons.trending_down_rounded),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SwitchRow(
                    icon: Icons.verified_rounded,
                    title: 'Vendeurs vérifiés uniquement',
                    value: verifiedOnly,
                    onChanged: (v) => setSheet(() => verifiedOnly = v),
                  ),
                  _SwitchRow(
                    icon: Icons.bolt_rounded,
                    title: 'Prêt à expédier uniquement',
                    value: readyToShipOnly,
                    onChanged: (v) => setSheet(() => readyToShipOnly = v),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop({
                            'sort': 'newest',
                            'verifiedOnly': false,
                            'readyToShipOnly': false,
                          }),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _T.textSecondary,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            side: const BorderSide(color: _T.divider),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Réinitialiser'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop({
                            'sort': sort,
                            'verifiedOnly': verifiedOnly,
                            'readyToShipOnly': readyToShipOnly,
                          }),
                          style: FilledButton.styleFrom(
                            backgroundColor: _T.brand,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Afficher les résultats',
                              style: TextStyle(fontWeight: FontWeight.w700)),
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

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _shareBoundaryKey,
      child: Scaffold(
        backgroundColor: _T.bg,
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            indicatorColor: _T.brandSoft,
            elevation: 0,
            height: 68,
            labelTextStyle: WidgetStateProperty.resolveWith(
              (s) => TextStyle(
                fontSize: 12,
                fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
                color: s.contains(WidgetState.selected) ? _T.brand : _T.textMeta,
              ),
            ),
            iconTheme: WidgetStateProperty.resolveWith(
              (s) => IconThemeData(color: s.contains(WidgetState.selected) ? _T.brand : _T.textMeta),
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(color: _T.brandInk.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, -4)),
              ],
            ),
            child: NavigationBar(
              selectedIndex: _tabIndex,
              onDestinationSelected: (i) {
                HapticFeedback.selectionClick();
                setState(() => _tabIndex = i);
              },
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.storefront_outlined),
                  selectedIcon: Icon(Icons.storefront_rounded),
                  label: 'Boutique',
                ),
                NavigationDestination(
                  icon: Consumer<StudentMarketplaceCartProviderV1>(
                    builder: (context, cart, _) => MarketplaceCountBadge(
                      count: cart.itemsCount,
                      child: const Icon(Icons.shopping_bag_outlined),
                    ),
                  ),
                  selectedIcon: Consumer<StudentMarketplaceCartProviderV1>(
                    builder: (context, cart, _) => MarketplaceCountBadge(
                      count: cart.itemsCount,
                      child: const Icon(Icons.shopping_bag_rounded),
                    ),
                  ),
                  label: 'Panier',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Compte',
                ),
              ],
            ),
          ),
        ),
        body: AnimatedSwitcher(
          duration: _T.medium,
          switchInCurve: _T.curve,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: ScaleTransition(
              scale: Tween(begin: 0.98, end: 1.0).animate(a),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey(_tabIndex),
            child: _tabIndex == 0
                ? _buildMarketplaceTabBody()
                : _tabIndex == 1
                    ? const StudentMarketplaceCartScreenV1(showAppBar: false)
                    : const _OpportunitiesAccountTab(),
          ),
        ),
      ),
    );
  }

  Widget _buildMarketplaceTabBody() {
    return Consumer2<StudentMarketplaceListingsProviderV1, StudentMarketplaceCategoriesProviderV1>(
      builder: (context, provider, categoriesProvider, _) {
        final items = provider.items;
        final loadingFirst = provider.isLoading && items.isEmpty;

        final slivers = <Widget>[
          _buildHeader(provider.total),
          SliverToBoxAdapter(child: _buildQuickFilters()),
          SliverToBoxAdapter(child: _buildCategories(categoriesProvider.rootCategories)),
        ];

        if (loadingFirst) {
          slivers.add(const SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AlibabaRailShimmer(itemCount: 4),
                  SizedBox(height: 20),
                  AlibabaGridShimmer(itemCount: 6),
                ],
              ),
            ),
          ));
        } else if (provider.error != null && items.isEmpty) {
          slivers.add(SliverFillRemaining(
            hasScrollBody: false,
            child: MarketplaceEmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'Impossible de charger la boutique',
              message: provider.error,
              actionLabel: 'Réessayer',
              onAction: _onRefresh,
              color: _T.danger,
            ),
          ));
        } else if (items.isEmpty) {
          final filtered = _searchQuery.isNotEmpty ||
              _activeFilters > 0 ||
              _selectedMarketplaceCategoryId != null ||
              _selectedMarketplaceSubCategoryId != null;
          slivers.add(SliverFillRemaining(
            hasScrollBody: false,
            child: MarketplaceEmptyState(
              icon: filtered ? Icons.search_off_rounded : Icons.shopping_bag_outlined,
              title: filtered ? 'Aucun résultat' : 'La boutique se remplit bientôt',
              message: filtered
                  ? 'Essayez un autre mot-clé ou retirez quelques filtres.'
                  : 'Reviens voir régulièrement pour découvrir de nouvelles annonces !',
              actionLabel: filtered ? 'Tout afficher' : null,
              onAction: filtered
                  ? () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _sort = 'newest';
                        _verifiedOnly = false;
                        _readyToShipOnly = false;
                        _selectedMarketplaceCategoryId = null;
                        _selectedMarketplaceSubCategoryId = null;
                      });
                      _onRefresh();
                    }
                  : null,
            ),
          ));
        } else {
          slivers.add(const SliverToBoxAdapter(child: _TrustBanner()));
          if (_searchQuery.isEmpty && items.length > 3) {
            slivers.add(SliverToBoxAdapter(child: _buildRail(items)));
          }
          slivers.add(SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            sliver: SliverToBoxAdapter(
              child: AlibabaSectionHeader(
                title: _searchQuery.isEmpty ? 'Pour toi' : 'Résultats',
                subtitle: '${provider.total} article${provider.total > 1 ? 's' : ''}',
                icon: _searchQuery.isEmpty ? Icons.auto_awesome_rounded : Icons.search_rounded,
              ),
            ),
          ));
          slivers.add(SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: _marketplaceGridMode ? 2 : 1,
              mainAxisSpacing: _T.gridGap,
              crossAxisSpacing: _T.gridGap,
              childCount: items.length,
              itemBuilder: (context, index) {
                final it = items[index];
                return MarketplaceReveal(
                  key: ValueKey('mp-${it['id']}'),
                  index: index,
                  child: MarketplaceProductCard(
                    listing: it,
                    compact: _marketplaceGridMode,
                    heroTag: 'mp-${it['id']}',
                    onTap: () => _openProduct(it),
                    onAddToCartAsync: () => _addToCart(it),
                    onBookmark: () => _toggleBookmark(it),
                  ),
                );
              },
            ),
          ));
          slivers.add(SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Center(
                child: provider.isLoadingMore
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: _T.brand),
                      )
                    : provider.hasMore
                        ? TextButton.icon(
                            onPressed: provider.loadMore,
                            style: TextButton.styleFrom(foregroundColor: _T.brand),
                            icon: const Icon(Icons.expand_more_rounded),
                            label: const Text('Charger plus'),
                          )
                        : const Text(
                            'Vous avez tout vu ✨',
                            style: TextStyle(color: _T.textMeta, fontWeight: FontWeight.w600),
                          ),
              ),
            ),
          ));
        }

        return RefreshIndicator(
          color: _T.brand,
          edgeOffset: 120,
          onRefresh: _onRefresh,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: slivers,
          ),
        );
      },
    );
  }

  Widget _buildHeader(int total) {
    Widget action(IconData icon, String tooltip, VoidCallback? onTap) => IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          icon: Icon(icon, color: Colors.white),
        );

    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: 178,
      toolbarHeight: 60,
      backgroundColor: _T.brandDark,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleSpacing: 16,
      title: const Row(
        children: [
          _LogoMark(),
          SizedBox(width: 10),
          Text(
            'Academia Market',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 19,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
      actions: [
        action(Icons.chat_bubble_outline_rounded, 'Mes demandes',
            () => _push(const StudentMyInquiriesScreenV1())),
        action(Icons.receipt_long_rounded, 'Mes commandes',
            () => _push(const StudentMarketplaceMyOrdersScreenV1())),
        Consumer<ShareModeProvider>(
          builder: (context, shareMode, _) {
            if (shareMode.isShareModeEnabled) return const SizedBox.shrink();
            return action(Icons.ios_share_rounded, 'Partager',
                shareMode.isBusy ? null : _shareCurrentView);
          },
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: _T.heroGradient),
        child: FlexibleSpaceBar(
          collapseMode: CollapseMode.parallax,
          stretchModes: const [StretchMode.zoomBackground],
          background: Stack(
            children: [
              Positioned(
                right: -40,
                top: -30,
                child: _Orb(size: 170, opacity: 0.10),
              ),
              Positioned(
                left: -30,
                bottom: 40,
                child: _Orb(size: 110, opacity: 0.07),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 84,
                child: Row(
                  children: [
                    const Icon(Icons.shield_rounded, size: 15, color: Color(0xFFC7D2FE)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$total article${total > 1 ? 's' : ''} · Paiement sécurisé par Academia',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFE0E7FF),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: AlibabaSearchBar(
            controller: _searchController,
            onChanged: _onSearchChanged,
            onSearch: () {
              _searchDebounce?.cancel();
              setState(() => _searchQuery = _searchController.text.trim());
              _onRefresh();
            },
            onFilters: _openFiltersSheet,
            activeFilters: _activeFilters,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickFilters() {
    final chips = <Widget>[
      _FilterChipPill(
        icon: Icons.verified_rounded,
        label: 'Vérifiés',
        selected: _verifiedOnly,
        onTap: () {
          setState(() => _verifiedOnly = !_verifiedOnly);
          _onRefresh();
        },
      ),
      _FilterChipPill(
        icon: Icons.bolt_rounded,
        label: 'Prêt à expédier',
        selected: _readyToShipOnly,
        onTap: () {
          setState(() => _readyToShipOnly = !_readyToShipOnly);
          _onRefresh();
        },
      ),
      _FilterChipPill(
        icon: Icons.schedule_rounded,
        label: 'Récents',
        selected: _sort == 'newest',
        onTap: () => _setSort('newest'),
      ),
      _FilterChipPill(
        icon: Icons.south_rounded,
        label: 'Prix bas',
        selected: _sort == 'price_asc',
        onTap: () => _setSort('price_asc'),
      ),
      _FilterChipPill(
        icon: Icons.north_rounded,
        label: 'Prix haut',
        selected: _sort == 'price_desc',
        onTap: () => _setSort('price_desc'),
      ),
      _FilterChipPill(
        icon: Icons.favorite_rounded,
        label: 'Favoris',
        selected: false,
        onTap: () => _push(const StudentMarketplaceFavoritesScreenV1()),
      ),
      _FilterChipPill(
        icon: _marketplaceGridMode ? Icons.view_agenda_rounded : Icons.grid_view_rounded,
        label: _marketplaceGridMode ? 'Liste' : 'Grille',
        selected: false,
        onTap: () => setState(() => _marketplaceGridMode = !_marketplaceGridMode),
      ),
    ];

    return SizedBox(
      height: 60,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  Widget _buildCategories(List<Map<String, dynamic>> categories) {
    if (categories.isEmpty) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AlibabaSectionHeader(
              title: 'Catégories',
              onTap: _openAllCategories,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 102,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: categories.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _CategoryBubble(
                    label: 'Tout',
                    icon: Icons.apps_rounded,
                    color: _T.brand,
                    selected: _selectedMarketplaceCategoryId == null &&
                        _selectedMarketplaceSubCategoryId == null,
                    onTap: () => _selectCategory(null),
                  );
                }
                final c = categories[index - 1];
                final id = c['id']?.toString();
                final label = c['label']?.toString() ?? '';
                return _CategoryBubble(
                  label: label,
                  icon: _T.categoryIcon(label, index - 1),
                  color: _T.categoryColor(index),
                  selected: id != null && _selectedMarketplaceCategoryId == id,
                  onTap: (id == null || id.isEmpty) ? null : () => _selectCategory(id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRail(List<Map<String, dynamic>> items) {
    final rail = items.take(10).toList(growable: false);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: AlibabaSectionHeader(
              title: 'Meilleures offres',
              subtitle: 'Les nouveautés du moment',
              icon: Icons.local_fire_department_rounded,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 306,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: rail.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final it = rail[index];
                return MarketplaceReveal(
                  index: index,
                  from: const Offset(0.15, 0),
                  child: SizedBox(
                    width: 176,
                    child: MarketplaceProductCard(
                      listing: it,
                      compact: true,
                      onTap: () => _openProduct(it),
                      onAddToCartAsync: () => _addToCart(it),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Composants de l'onglet ────────────────────────────────────────────────
// Écrits le 27/10 : la refonte du 07/10 s'était arrêtée sur le marqueur
// « PART3 », avant ces huit composants, et le fichier ne compilait plus.

/// Pastille de logo dans la barre du haut.
class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 19),
    );
  }
}

/// Disque lumineux décoratif du bandeau dégradé.
class _Orb extends StatelessWidget {
  final double size;
  final double opacity;

  const _Orb({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.white.withValues(alpha: opacity),
              Colors.white.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// Filtre rapide de la rangée horizontale.
class _FilterChipPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : _T.textSecondary;
    return AlibabaPressScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_T.radiusChip),
      child: AnimatedContainer(
        duration: _T.fast,
        curve: _T.curve,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _T.brand : _T.surface,
          borderRadius: BorderRadius.circular(_T.radiusChip),
          border: Border.all(color: selected ? _T.brand : _T.divider),
          boxShadow: selected ? _T.shadowColored(_T.brand) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : _T.brand),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bulle de catégorie (icône ronde + libellé).
class _CategoryBubble extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  const _CategoryBubble({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AlibabaPressScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: _T.fast,
              curve: _T.curve,
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: selected ? color : color.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? color : color.withValues(alpha: 0.22),
                  width: selected ? 2 : 1,
                ),
                boxShadow: selected ? _T.shadowColored(color) : null,
              ),
              child: Icon(icon, size: 26, color: selected ? Colors.white : color),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? _T.textPrimary : _T.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Choix d'un tri dans la feuille des filtres.
class _SelectableTile extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SelectableTile({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AlibabaPressScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: _T.fast,
        curve: _T.curve,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? _T.brandSoft : _T.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? _T.brand : _T.divider, width: selected ? 1.6 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: selected ? _T.brand : _T.textMeta),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? _T.brand : _T.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Interrupteur d'un filtre dans la feuille des filtres.
class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _T.brandSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: _T.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _T.textPrimary),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: _T.brand,
          ),
        ],
      ),
    );
  }
}

/// Bandeau « paiement protégé » au-dessus des annonces.
///
/// Il ne promet que ce que le serveur applique (règles du 06/10,
/// `marketplace_regles_metier.md`) : fonds en séquestre jusqu'à la réception,
/// remboursement intégral si la commande est annulée.
class _TrustBanner extends StatelessWidget {
  const _TrustBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _T.surface,
          borderRadius: BorderRadius.circular(_T.radiusCard),
          border: Border.all(color: _T.divider),
          boxShadow: _T.shadowSoft,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _T.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.verified_user_rounded, color: _T.success),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paiement protégé',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _T.textPrimary),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Academia garde ton argent jusqu\'à la réception. '
                    'Commande annulée : remboursement intégral.',
                    style: TextStyle(fontSize: 12, height: 1.3, color: _T.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Onglet « Compte » de la boutique : les raccourcis de l'acheteur, et ce que
/// la protection acheteur garantit réellement (mêmes règles que le serveur).
class _OpportunitiesAccountTab extends StatelessWidget {
  const _OpportunitiesAccountTab();

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    Widget entry({
      required IconData icon,
      required Color color,
      required String title,
      required String subtitle,
      required Widget screen,
    }) {
      return AlibabaPressScale(
        onTap: () => _push(context, screen),
        borderRadius: BorderRadius.circular(_T.radiusCard),
        pressedScale: 0.98,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _T.surface,
            borderRadius: BorderRadius.circular(_T.radiusCard),
            border: Border.all(color: _T.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _T.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: _T.textMeta)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _T.textMeta),
            ],
          ),
        ),
      );
    }

    Widget garantie(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: _T.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text, style: const TextStyle(fontSize: 13, height: 1.35, color: _T.textSecondary)),
              ),
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      physics: const BouncingScrollPhysics(),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: _T.heroGradient,
            borderRadius: BorderRadius.circular(_T.radiusCard),
            boxShadow: _T.shadowLifted,
          ),
          child: const Row(
            children: [
              _LogoMark(),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mon espace acheteur',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text('Commandes, échanges avec les vendeurs et favoris',
                        style: TextStyle(color: Color(0xFFE0E7FF), fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        entry(
          icon: Icons.receipt_long_rounded,
          color: _T.brand,
          title: 'Mes commandes',
          subtitle: 'Suivi, réception, réclamation',
          screen: const StudentMarketplaceMyOrdersScreenV1(),
        ),
        const SizedBox(height: 10),
        entry(
          icon: Icons.chat_bubble_outline_rounded,
          color: const Color(0xFF0EA5E9),
          title: 'Mes demandes',
          subtitle: 'Questions posées aux vendeurs',
          screen: const StudentMyInquiriesScreenV1(),
        ),
        const SizedBox(height: 10),
        entry(
          icon: Icons.favorite_rounded,
          color: const Color(0xFFEC4899),
          title: 'Mes favoris',
          subtitle: 'Les articles que tu as gardés',
          screen: const StudentMarketplaceFavoritesScreenV1(),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          decoration: BoxDecoration(
            color: _T.surface,
            borderRadius: BorderRadius.circular(_T.radiusCard),
            border: Border.all(color: _T.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ta protection acheteur',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _T.textPrimary)),
              const SizedBox(height: 12),
              garantie(Icons.lock_rounded,
                  'Ton paiement est conservé par Academia : le vendeur n\'est payé qu\'après la réception.'),
              garantie(Icons.undo_rounded,
                  'Commande annulée avant l\'expédition : tu es remboursé intégralement.'),
              garantie(Icons.report_gmailerrorred_rounded,
                  'Un problème ? Tu peux ouvrir une réclamation dans les 72 h qui suivent la livraison.'),
            ],
          ),
        ),
      ],
    );
  }
}
