import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'psychotech_generator.dart';

/// Widget profil de compétences psychotechniques — barres par type, prédiction, recommandations.
class PsychotechProfileWidget extends StatefulWidget {
  final bool compact;
  const PsychotechProfileWidget({super.key, this.compact = false});

  @override
  State<PsychotechProfileWidget> createState() => _PsychotechProfileWidgetState();
}

class _PsychotechProfileWidgetState extends State<PsychotechProfileWidget> {
  bool _loading = true;
  Map<String, dynamic> _profile = {};
  List<Map<String, dynamic>> _stats = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final client = Supabase.instance.client;

      // Load profile
      final profileRes = await client.rpc('app_prep_get_psychotech_profile');
      if (profileRes is Map) {
        _profile = Map<String, dynamic>.from(profileRes);
      }

      // Load detailed stats
      final statsRes = await client.rpc('app_prep_get_psychotech_stats');
      if (statsRes is Map && statsRes['success'] == true && statsRes['stats'] is List) {
        _stats = (statsRes['stats'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (e) {
      debugPrint('[PsychotechProfile] load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(20),
        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED)),
      ));
    }

    final totalTests = (_profile['total_tests'] as int?) ?? 0;
    final totalCorrect = (_profile['total_correct'] as int?) ?? 0;
    final predicted = (_profile['predicted_score'] as int?) ?? 0;
    final weakAreas = (_profile['weak_areas'] is List)
        ? (_profile['weak_areas'] as List).cast<String>()
        : <String>[];
    final strongAreas = (_profile['strong_areas'] is List)
        ? (_profile['strong_areas'] as List).cast<String>()
        : <String>[];
    final globalAccuracy = totalTests > 0 ? (totalCorrect / totalTests * 100).round() : 0;

    if (totalTests == 0 && !widget.compact) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF3E5F5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(children: [
          Icon(Icons.psychology, size: 40, color: Color(0xFF7C3AED)),
          SizedBox(height: 10),
          Text('Aucun test effectué', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text('Faites des tests psychotechniques pour voir votre profil de compétences.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF757575))),
        ]),
      );
    }

    if (totalTests == 0 && widget.compact) {
      return const SizedBox.shrink();
    }

    if (widget.compact) {
      return _buildCompact(globalAccuracy, totalTests, predicted);
    }

    return _buildFull(globalAccuracy, totalTests, totalCorrect, predicted, weakAreas, strongAreas);
  }

  Widget _buildCompact(int accuracy, int totalTests, int predicted) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text('$accuracy%',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF7C3AED)))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Psychotechnique', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('$totalTests tests · Score prédit: $predicted%',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF757575))),
            ],
          )),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF9E9E9E)),
        ],
      ),
    );
  }

  Widget _buildFull(int accuracy, int totalTests, int totalCorrect, int predicted,
      List<String> weakAreas, List<String> strongAreas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF9333EA)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            // Score circle
            SizedBox(
              width: 70, height: 70,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(width: 70, height: 70,
                  child: CircularProgressIndicator(
                    value: accuracy / 100, strokeWidth: 6, strokeCap: StrokeCap.round,
                    backgroundColor: Colors.white.withAlpha(50),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                Text('$accuracy%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
              ]),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Profil Psychotechnique', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('$totalTests tests · $totalCorrect corrects',
                    style: TextStyle(color: Colors.white.withAlpha(190), fontSize: 12)),
                if (predicted > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withAlpha(40), borderRadius: BorderRadius.circular(8)),
                    child: Text('Score prédit au concours: $predicted%',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            )),
          ]),
        ),
        const SizedBox(height: 16),

        // Bars by type
        const Text('Par type de test', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ..._stats.map((s) {
          final type = (s['test_type'] ?? '').toString();
          final total = (s['total'] as int?) ?? 0;
          final correct = (s['correct'] as int?) ?? 0;
          final acc = (s['accuracy'] as num?)?.toDouble() ?? 0;
          final avgTime = (s['avg_time'] as num?)?.toDouble() ?? 0;
          final label = PsychotechGenerator.typeLabel(type);
          final emoji = PsychotechGenerator.typeIcon(type);

          final barColor = acc >= 70 ? const Color(0xFF2E7D32) : acc >= 50 ? const Color(0xFFF57C00) : const Color(0xFFD32F2F);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  Text('${acc.round()}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: barColor)),
                  const SizedBox(width: 8),
                  Text('$correct/$total', style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E))),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: acc / 100),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (_, value, __) => LinearProgressIndicator(
                      value: value, minHeight: 6,
                      backgroundColor: barColor.withAlpha(25),
                      valueColor: AlwaysStoppedAnimation(barColor),
                    ),
                  ),
                ),
                if (avgTime > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('Temps moyen: ${(avgTime / 1000).toStringAsFixed(1)}s',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E))),
                  ),
              ],
            ),
          );
        }),

        // Strengths & Weaknesses
        if (strongAreas.isNotEmpty || weakAreas.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (strongAreas.isNotEmpty)
                Expanded(child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC8E6C9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.thumb_up, size: 14, color: Color(0xFF2E7D32)),
                        SizedBox(width: 4),
                        Text('Points forts', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2E7D32))),
                      ]),
                      const SizedBox(height: 4),
                      ...strongAreas.map((a) => Text('• ${PsychotechGenerator.typeLabel(a)}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF1B5E20)))),
                    ],
                  ),
                )),
              if (strongAreas.isNotEmpty && weakAreas.isNotEmpty) const SizedBox(width: 8),
              if (weakAreas.isNotEmpty)
                Expanded(child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFCDD2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.trending_down, size: 14, color: Color(0xFFD32F2F)),
                        SizedBox(width: 4),
                        Text('À travailler', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFD32F2F))),
                      ]),
                      const SizedBox(height: 4),
                      ...weakAreas.map((a) => Text('• ${PsychotechGenerator.typeLabel(a)}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFFB71C1C)))),
                    ],
                  ),
                )),
            ],
          ),
        ],
      ],
    );
  }
}
