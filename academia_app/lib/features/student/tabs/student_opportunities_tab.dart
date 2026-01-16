import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/student_opportunities_provider.dart';
import '../../../providers/opportunity_reactions_provider.dart';
import '../../../widgets/opportunities/opportunity_feed_card.dart';
import '../../../widgets/opportunities/opportunity_skeleton_loader.dart';
import '../../../widgets/opportunities/opportunity_comments_sheet.dart';
import '../../share/share_service.dart';
import '../../share/share_mode_provider.dart';
import '../../share/widgets/share_signature.dart';

/// Onglet Opportunités - Feed social style Facebook/LinkedIn
class StudentOpportunitiesTab extends StatefulWidget {
  const StudentOpportunitiesTab({super.key});

  @override
  State<StudentOpportunitiesTab> createState() => _StudentOpportunitiesTabState();
}

class _StudentOpportunitiesTabState extends State<StudentOpportunitiesTab> {
  String _searchQuery = '';
  String? _selectedType;
  bool _showBookmarksOnly = false;
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

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final provider = context.read<StudentOpportunitiesProvider>();
      if (provider.hasMore && !provider.isLoadingMore) {
        if (_showBookmarksOnly) {
          provider.loadBookmarkedOpportunities(
            type: _selectedType,
            search: _searchQuery.isEmpty ? null : _searchQuery,
            refresh: false,
          );
        } else {
          provider.loadMore();
        }
      }
    }
  }

  Future<void> _loadInitialData() async {
    final provider = context.read<StudentOpportunitiesProvider>();
    await provider.loadTypes();
    if (_showBookmarksOnly) {
      await provider.loadBookmarkedOpportunities(
        type: _selectedType,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        refresh: true,
      );
    } else {
      await provider.loadOpportunities(
        type: _selectedType,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        refresh: true,
      );
    }
    // Marquer les opportunités comme vues (reset badge)
    provider.markAsViewed();
  }

  Future<void> _onRefresh() async {
    final provider = context.read<StudentOpportunitiesProvider>();
    if (_showBookmarksOnly) {
      await provider.loadBookmarkedOpportunities(
        type: _selectedType,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        refresh: true,
      );
    } else {
      await provider.loadOpportunities(
        type: _selectedType,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        refresh: true,
      );
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _onRefresh();
  }

  void _onTypeSelected(String? type) {
    setState(() => _selectedType = type);
    _onRefresh();
  }

  Future<void> _onToggleBookmark(Map<String, dynamic> opportunity) async {
    final id = opportunity['id']?.toString();
    if (id == null) return;

    final provider = context.read<StudentOpportunitiesProvider>();
    final success = await provider.toggleBookmark(id);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de la mise à jour du favori.'),
        ),
      );
    }
  }

  Future<void> _applyToOpportunity(Map<String, dynamic> opportunity) async {
    final provider = context.read<StudentOpportunitiesProvider>();
    final id = opportunity['id']?.toString();
    if (id == null) return;

    final messageController = TextEditingController();
    String? cvStoragePath;
    String? cvFileName;
    bool isSubmitting = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Postuler à cette opportunité'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: messageController,
                      decoration: const InputDecoration(
                        labelText: 'Message de motivation (optionnel)',
                        hintText: 'Présentez-vous brièvement...',
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cvFileName != null
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: cvFileName != null
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFE0E0E0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            cvFileName != null
                                ? Icons.check_circle
                                : Icons.attach_file,
                            color: cvFileName != null
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFF757575),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cvFileName ?? 'Joindre un CV',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: cvFileName != null
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFF424242),
                                  ),
                                ),
                                if (cvFileName == null)
                                  const Text(
                                    'PDF, image ou Word',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF9E9E9E),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final result = await FilePicker.platform.pickFiles(
                                allowMultiple: false,
                                withData: true,
                                type: FileType.custom,
                                allowedExtensions: const [
                                  'pdf',
                                  'jpg',
                                  'jpeg',
                                  'png',
                                  'doc',
                                  'docx',
                                ],
                              );

                              if (result == null || result.files.isEmpty) {
                                return;
                              }

                              final file = result.files.first;
                              final bytes = file.bytes;
                              final fileName = file.name;

                              if (bytes == null) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Impossible de lire le contenu du fichier.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              setDialogState(() {
                                cvFileName = 'Envoi en cours...';
                              });

                              final path = await provider.uploadCvFile(
                                opportunityId: id,
                                bytes: bytes,
                                fileName: fileName,
                                mimeType: file.extension,
                              );

                              if (!context.mounted) return;

                              if (path != null) {
                                setDialogState(() {
                                  cvStoragePath = path;
                                  cvFileName = fileName;
                                });
                              } else {
                                setDialogState(() {
                                  cvFileName = null;
                                });
                                if (provider.error != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(provider.error!)),
                                  );
                                }
                              }
                            },
                            child: Text(
                              cvFileName != null ? 'Changer' : 'Parcourir',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () {
                          Navigator.of(context).pop(false);
                        },
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setDialogState(() {
                            isSubmitting = true;
                          });

                          final success = await provider.applyForOpportunity(
                            opportunityId: id,
                            message: messageController.text.trim().isEmpty
                                ? null
                                : messageController.text.trim(),
                            cvUrl: cvStoragePath,
                          );

                          if (!context.mounted) return;

                          if (success) {
                            Navigator.of(context).pop(true);
                          } else {
                            setDialogState(() {
                              isSubmitting = false;
                            });
                            if (provider.error != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(provider.error!)),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Envoyer'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Candidature envoyée avec succès.')),
      );
    } else if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!)),
      );
    }
  }

  void _onReaction(Map<String, dynamic> opportunity, String reactionType) async {
    final opportunityId = opportunity['id']?.toString();
    if (opportunityId == null) return;

    final reactionsProvider = context.read<OpportunityReactionsProvider>();
    final success = await reactionsProvider.toggleReaction(opportunityId, reactionType);

    if (success && mounted) {
      final counts = reactionsProvider.getReactionCounts(opportunityId);
      final myReaction = reactionsProvider.getMyReaction(opportunityId);
      context.read<StudentOpportunitiesProvider>().updateOpportunityCounters(
            opportunityId,
            reactionsCount: counts['total'],
            myReaction: myReaction,
          );
    }
  }

  void _onComment(Map<String, dynamic> opportunity) {
    final opportunityId = opportunity['id']?.toString();
    final title = opportunity['title']?.toString() ?? '';
    if (opportunityId == null) return;

    OpportunityCommentsSheet.show(
      context,
      opportunityId: opportunityId,
      opportunityTitle: title,
    );
  }

  Widget _buildCareerTipCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFA7F3D0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFF6EE7B7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lightbulb,
              size: 18,
              color: Color(0xFF047857),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Astuce carrière',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF065F46),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Un message de motivation court et personnalisé augmente fortement tes chances de réponse.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF047857),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return Consumer<StudentOpportunitiesProvider>(
      builder: (context, provider, _) {
        final opportunities = provider.opportunities;
        int bookmarkedCount = 0;
        for (final opp in opportunities) {
          if (opp['is_bookmarked'] == true) {
            bookmarkedCount++;
          }
        }

        return Container(
          margin: const EdgeInsets.only(top: 8, bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFF4F46E5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.trending_up,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mon avancée carrière',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _ProgressPill(
                          icon: Icons.work_outline,
                          label:
                              '${provider.total} opportunité${provider.total > 1 ? 's' : ''}',
                        ),
                        _ProgressPill(
                          icon: Icons.bookmark_outline,
                          label:
                              '$bookmarkedCount favori${bookmarkedCount > 1 ? 's' : ''}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: RepaintBoundary(
        key: _shareBoundaryKey,
        child: Stack(
          children: [
            NestedScrollView(
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
                child: Consumer<StudentOpportunitiesProvider>(
                  builder: (context, provider, child) {
              if (provider.isLoading && provider.opportunities.isEmpty) {
                return const SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  child: OpportunitySkeletonLoader(count: 3),
                );
              }

              if (provider.error != null && provider.opportunities.isEmpty) {
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
                            color: Color(0xFF9CA3AF),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            provider.error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF6B7280)),
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

                    final opportunities = provider.opportunities;
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
                            Icons.work_off_outlined,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Aucune opportunité disponible',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Reviens voir régulièrement pour découvrir de nouvelles opportunités !',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

                    const bool hasTipCard = true;
                    final int baseItemCount =
                        opportunities.length + (provider.hasMore ? 1 : 0);
                    final int itemCount = baseItemCount + (hasTipCard ? 1 : 0);

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: itemCount,
                      itemBuilder: (context, index) {
                        if (hasTipCard && index == 0) {
                          return _buildCareerTipCard();
                        }

                        final int effectiveIndex =
                            hasTipCard ? index - 1 : index;

                        if (effectiveIndex >= opportunities.length) {
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

                        final opp = opportunities[effectiveIndex];
                        return OpportunityFeedCard(
                          opportunity: opp,
                          onTap: () {
                            // TODO: Navigate to detail screen
                          },
                          onLike: () => _onReaction(opp, 'like'),
                          onLove: () => _onReaction(opp, 'love'),
                          onComment: () => _onComment(opp),
                          onAction: () => _applyToOpportunity(opp),
                          onBookmark: () => _onToggleBookmark(opp),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: IgnorePointer(
                child: Consumer<ShareModeProvider>(
                  builder: (context, shareMode, _) {
                    if (!shareMode.isShareModeEnabled) {
                      return const SizedBox.shrink();
                    }
                    return const ShareSignature();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFFF3F4F6),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Opportunités',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A2540),
                  ),
                ),
              ),
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
            ],
          ),
          const SizedBox(height: 4),
          Consumer<StudentOpportunitiesProvider>(
            builder: (context, provider, _) {
              return Text(
                '${provider.total} opportunité${provider.total > 1 ? 's' : ''} disponible${provider.total > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Consumer<StudentOpportunitiesProvider>(
            builder: (context, provider, _) {
              final opportunities = provider.opportunities;
              if (opportunities.isEmpty) {
                return const SizedBox.shrink();
              }

              final now = DateTime.now();
              int recentCount = 0;
              for (final opp in opportunities) {
                final createdAtStr = opp['created_at']?.toString();
                if (createdAtStr == null || createdAtStr.isEmpty) {
                  continue;
                }
                try {
                  final createdAt = DateTime.parse(createdAtStr);
                  if (now.difference(createdAt).inDays < 7) {
                    recentCount++;
                  }
                } catch (_) {}
              }

              if (recentCount <= 0) {
                return const SizedBox.shrink();
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bolt,
                      size: 14,
                      color: Color(0xFF0EA5E9),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$recentCount nouvelle${recentCount > 1 ? 's' : ''} opportunité${recentCount > 1 ? 's' : ''} cette semaine',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF0369A1),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          _buildProgressCard(),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF)),
              hintText: 'Rechercher une opportunité...',
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 12),
          Consumer<StudentOpportunitiesProvider>(
            builder: (context, provider, child) {
              final types = provider.types;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Tous',
                      isSelected: _selectedType == null,
                      onTap: () => _onTypeSelected(null),
                    ),
                    const SizedBox(width: 8),
                    for (final t in types) ...[
                      _FilterChip(
                        label: t['label']?.toString() ?? t['code']?.toString() ?? '',
                        isSelected: _selectedType == t['code']?.toString(),
                        onTap: () => _onTypeSelected(t['code']?.toString()),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(
              label: const Text('Mes favoris'),
              selected: _showBookmarksOnly,
              onSelected: (selected) {
                setState(() {
                  _showBookmarksOnly = selected;
                });
                _onRefresh();
              },
              selectedColor: const Color(0xFFEEF2FF),
              checkmarkColor: const Color(0xFF4F46E5),
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _showBookmarksOnly
                    ? const Color(0xFF4F46E5)
                    : const Color(0xFF374151),
              ),
              side: BorderSide(
                color: _showBookmarksOnly
                    ? const Color(0xFF4F46E5)
                    : const Color(0xFFE5E7EB),
              ),
              backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ProgressPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: const Color(0xFF4F46E5),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3275D0) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF3275D0) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}
