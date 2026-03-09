import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';

import '../../../providers/td_gamification_provider.dart';
import '../../../theme/td_theme.dart';

/// Onglet Catalogue — Explorer les TD avec filtres, catégories, visuels
class TdCatalogTab extends StatefulWidget {
  const TdCatalogTab({super.key});

  @override
  State<TdCatalogTab> createState() => _TdCatalogTabState();
}

class _TdCatalogTabState extends State<TdCatalogTab> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TdGamificationProvider>();

    return Column(
      children: [
        // ─── Search bar ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => p.setCatalogSearch(v.trim().isEmpty ? null : v.trim()),
            decoration: InputDecoration(
              hintText: 'Rechercher un TD...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        p.setCatalogSearch(null);
                      },
                    )
                  : null,
              filled: true,
              fillColor: TdTheme.cardBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(TdTheme.radiusMd),
                borderSide: BorderSide(color: TdTheme.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(TdTheme.radiusMd),
                borderSide: BorderSide(color: TdTheme.divider),
              ),
            ),
          ),
        ),

        // ─── Discipline filter chips ─────────────────────────────
        if (p.fields.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _FilterChip(
                  label: 'Tout',
                  isSelected: p.catalogFieldId == null,
                  color: TdTheme.studentTdPrimary,
                  onTap: () => p.setCatalogFilters(),
                ),
                ...p.fields.map((f) {
                  final color = TdTheme.colorFromHex(f['color_hex']?.toString());
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _FilterChip(
                      label: f['name']?.toString() ?? '',
                      isSelected: p.catalogFieldId == f['id']?.toString(),
                      color: color,
                      count: f['program_count'] as int?,
                      onTap: () => p.setCatalogFilters(fieldId: f['id']?.toString()),
                    ),
                  );
                }),
              ],
            ),
          ),

        // ─── Sort row ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                '${p.catalogPrograms.length} programme${p.catalogPrograms.length > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 12, color: TdTheme.textSecondary),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                initialValue: p.catalogSort,
                onSelected: (v) => p.setCatalogFilters(sort: v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'popular', child: Text('Populaires')),
                  PopupMenuItem(value: 'newest', child: Text('Récents')),
                  PopupMenuItem(value: 'price_asc', child: Text('Prix ↑')),
                  PopupMenuItem(value: 'price_desc', child: Text('Prix ↓')),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sort, size: 16, color: TdTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      _sortLabel(p.catalogSort),
                      style: const TextStyle(fontSize: 12, color: TdTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ─── Programs list ───────────────────────────────────────
        Expanded(
          child: p.catalogLoading
              ? const Center(child: CircularProgressIndicator())
              : p.catalogPrograms.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off, size: 48, color: TdTheme.textTertiary.withOpacity(0.5)),
                          const SizedBox(height: 8),
                          const Text('Aucun TD trouvé', style: TextStyle(color: TdTheme.textTertiary)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: p.loadCatalog,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: p.catalogPrograms.length,
                        itemBuilder: (context, index) {
                          final prog = p.catalogPrograms[index];
                          return FadeInUp(
                            delay: Duration(milliseconds: 30 * index),
                            duration: const Duration(milliseconds: 300),
                            child: _ProgramCard(program: prog),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  String _sortLabel(String sort) {
    switch (sort) {
      case 'popular':
        return 'Populaires';
      case 'newest':
        return 'Récents';
      case 'price_asc':
        return 'Prix ↑';
      case 'price_desc':
        return 'Prix ↓';
      default:
        return sort;
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final int? count;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.color,
    this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : color,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? Colors.white.withOpacity(0.8) : color.withOpacity(0.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  final Map<String, dynamic> program;

  const _ProgramCard({required this.program});

  @override
  Widget build(BuildContext context) {
    final title = program['title']?.toString() ?? '';
    final description = program['description']?.toString() ?? '';
    final level = program['level']?.toString() ?? '';
    final modality = program['modality']?.toString() ?? '';
    final price = program['price'];
    final currency = program['currency']?.toString() ?? 'XOF';
    final fieldName = program['field_name']?.toString() ?? '';
    final fieldColor = TdTheme.colorFromHex(program['field_color']?.toString());
    final enrollmentCount = program['enrollment_count'] as int? ?? 0;
    final resourceCount = program['resource_count'] as int? ?? 0;
    final isFeatured = program['is_featured'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: TdTheme.cardDecoration(),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(TdTheme.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(TdTheme.radiusLg),
          onTap: () {
            // TODO: Navigate to program detail
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [fieldColor, fieldColor.withOpacity(0.7)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.menu_book, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(title,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              if (isFeatured)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('⭐ Populaire',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFFD97706))),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (fieldName.isNotEmpty) TdTheme.disciplineChip(fieldName, color: fieldColor),
                              if (level.isNotEmpty) TdTheme.statusBadge(level, TdTheme.info),
                              if (modality.isNotEmpty) TdTheme.statusBadge(modality, TdTheme.neutral),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: TdTheme.textSecondary, height: 1.4)),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.people_outline, size: 14, color: TdTheme.textTertiary),
                    const SizedBox(width: 4),
                    Text('$enrollmentCount', style: const TextStyle(fontSize: 11, color: TdTheme.textTertiary)),
                    const SizedBox(width: 12),
                    Icon(Icons.folder_outlined, size: 14, color: TdTheme.textTertiary),
                    const SizedBox(width: 4),
                    Text('$resourceCount', style: const TextStyle(fontSize: 11, color: TdTheme.textTertiary)),
                    const Spacer(),
                    if (price != null)
                      Text(
                        '$price $currency',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: fieldColor),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
