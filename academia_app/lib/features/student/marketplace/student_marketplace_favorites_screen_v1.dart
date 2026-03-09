import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/student_marketplace_bookmarked_listings_provider_v1.dart';
import '../../../widgets/opportunities/opportunity_feed_card.dart';
import 'student_merchant_profile_screen_v1.dart';

class StudentMarketplaceFavoritesScreenV1 extends StatefulWidget {
  const StudentMarketplaceFavoritesScreenV1({super.key});

  @override
  State<StudentMarketplaceFavoritesScreenV1> createState() =>
      _StudentMarketplaceFavoritesScreenV1State();
}

class _StudentMarketplaceFavoritesScreenV1State
    extends State<StudentMarketplaceFavoritesScreenV1> {
  late final StudentMarketplaceBookmarkedListingsProviderV1 _provider;

  @override
  void initState() {
    super.initState();
    _provider = StudentMarketplaceBookmarkedListingsProviderV1();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider.load();
    });
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<StudentMarketplaceBookmarkedListingsProviderV1>(
        builder: (context, provider, child) {
          final items = provider.items;
          return Scaffold(
            backgroundColor: const Color(0xFFF3F4F6),
            appBar: AppBar(
              title: const Text('Favoris Marketplace'),
              actions: [
                IconButton(
                  onPressed: provider.isLoading ? null : () => provider.load(),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            body: Column(
              children: [
                if (provider.error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.red.withOpacity(0.08),
                    child: Text(
                      provider.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                Expanded(
                  child: provider.isLoading && items.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : items.isEmpty
                          ? RefreshIndicator(
                              onRefresh: () => provider.load(),
                              child: ListView(
                                children: const [
                                  SizedBox(height: 80),
                                  Center(child: Text('Aucun favori.')),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () => provider.load(),
                              child: ListView.builder(
                                padding: const EdgeInsets.only(bottom: 16),
                                itemCount:
                                    items.length + (provider.hasMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= items.length) {
                                    provider.loadMore();
                                    return const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  final item = items[index];
                                  final merchantId =
                                      item['merchant_id']?.toString();
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: OpportunityFeedCard(
                                      opportunity: item,
                                      onTap: () {
                                        if (merchantId != null &&
                                            merchantId.isNotEmpty) {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  StudentMerchantProfileScreenV1(
                                                merchantId: merchantId,
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      onLike: null,
                                      onLove: null,
                                      onComment: null,
                                      onAction: null,
                                      onBookmark: null,
                                    ),
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
