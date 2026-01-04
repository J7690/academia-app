import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/student_opportunities_provider.dart';
import '../../../providers/opportunity_reactions_provider.dart';
import '../../../widgets/opportunities/opportunity_feed_card.dart';
import '../../../widgets/opportunities/opportunity_skeleton_loader.dart';
import '../../../widgets/opportunities/opportunity_comments_sheet.dart';

/// Onglet Opportunités - Feed social style Facebook/LinkedIn
class StudentOpportunitiesTab extends StatefulWidget {
  const StudentOpportunitiesTab({super.key});

  @override
  State<StudentOpportunitiesTab> createState() => _StudentOpportunitiesTabState();
}

class _StudentOpportunitiesTabState extends State<StudentOpportunitiesTab> {
  String _searchQuery = '';
  String? _selectedType;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

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

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final provider = context.read<StudentOpportunitiesProvider>();
      if (provider.hasMore && !provider.isLoadingMore) {
        provider.loadMore();
      }
    }
  }

  Future<void> _loadInitialData() async {
    final provider = context.read<StudentOpportunitiesProvider>();
    await provider.loadTypes();
    await provider.loadOpportunities(
      type: _selectedType,
      search: _searchQuery.isEmpty ? null : _searchQuery,
      refresh: true,
    );
    // Marquer les opportunités comme vues (reset badge)
    provider.markAsViewed();
  }

  Future<void> _onRefresh() async {
    final provider = context.read<StudentOpportunitiesProvider>();
    await provider.loadOpportunities(
      type: _selectedType,
      search: _searchQuery.isEmpty ? null : _searchQuery,
      refresh: true,
    );
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _onRefresh();
  }

  void _onTypeSelected(String? type) {
    setState(() => _selectedType = type);
    _onRefresh();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: NestedScrollView(
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

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: opportunities.length + (provider.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= opportunities.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }

                  final opp = opportunities[index];
                  return OpportunityFeedCard(
                    opportunity: opp,
                    onTap: () {
                      // TODO: Navigate to detail screen
                    },
                    onLike: () => _onReaction(opp, 'like'),
                    onLove: () => _onReaction(opp, 'love'),
                    onComment: () => _onComment(opp),
                    onAction: () => _applyToOpportunity(opp),
                  );
                },
              );
            },
          ),
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
          const Text(
            'Opportunités',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0A2540),
            ),
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
