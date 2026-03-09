import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../video/audio_mix_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Result returned to the caller
// ─────────────────────────────────────────────────────────────────────────────

class DjMixResult {
  final double originalVolume;
  final double musicVolume;
  final List<VolumeSegment> originalSegments;
  final List<VolumeSegment> musicSegments;

  const DjMixResult({
    required this.originalVolume,
    required this.musicVolume,
    required this.originalSegments,
    required this.musicSegments,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal segment model for the UI
// ─────────────────────────────────────────────────────────────────────────────

class _UiSegment {
  double startSec;
  double endSec;
  double originalVol; // 0..1
  double musicVol; // 0..1
  String label;

  _UiSegment({
    required this.startSec,
    required this.endSec,
    required this.originalVol,
    required this.musicVol,
    required this.label,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Presets
// ─────────────────────────────────────────────────────────────────────────────

enum _DjPreset {
  voiceDominant('🎤 Ma voix domine', 'La musique reste en fond, ta voix est claire'),
  musicDominant('🎵 Musique domine', 'La musique est forte, ta voix passe au second plan'),
  balanced('⚖️ Équilibré', 'Les deux sont au même niveau'),
  custom('🎛️ Personnalisé', 'Tu contrôles tout, segment par segment');

  final String title;
  final String subtitle;
  const _DjPreset(this.title, this.subtitle);
}

// ─────────────────────────────────────────────────────────────────────────────
// DjMixSheet
// ─────────────────────────────────────────────────────────────────────────────

class DjMixSheet extends StatefulWidget {
  final String trackTitle;
  final double videoDurationSec;

  const DjMixSheet({
    super.key,
    required this.trackTitle,
    required this.videoDurationSec,
  });

  @override
  State<DjMixSheet> createState() => _DjMixSheetState();
}

class _DjMixSheetState extends State<DjMixSheet> {
  // ── Global volumes ──
  double _originalVol = 1.0;
  double _musicVol = 0.45;

  // ── Preset ──
  _DjPreset _preset = _DjPreset.voiceDominant;

  // ── Custom segments ──
  final List<_UiSegment> _segments = [];

  // ── Guided step (0 = preset choice, 1 = adjust, 2 = segments) ──
  int _step = 0;

  static const _accent = Color(0xFF00D2FF);
  static const _bg = Color(0xFF1A1A2E);
  static const _cardBg = Color(0xFF16213E);

  @override
  void initState() {
    super.initState();
    _applyPreset(_DjPreset.voiceDominant);
  }

  void _haptic() => HapticFeedback.lightImpact();

  void _applyPreset(_DjPreset preset) {
    _haptic();
    setState(() {
      _preset = preset;
      switch (preset) {
        case _DjPreset.voiceDominant:
          _originalVol = 1.0;
          _musicVol = 0.30;
          _segments.clear();
        case _DjPreset.musicDominant:
          _originalVol = 0.30;
          _musicVol = 0.85;
          _segments.clear();
        case _DjPreset.balanced:
          _originalVol = 0.70;
          _musicVol = 0.70;
          _segments.clear();
        case _DjPreset.custom:
          _originalVol = 1.0;
          _musicVol = 0.50;
          // Keep existing segments
      }
    });
  }

  void _addSegment() {
    _haptic();
    final dur = widget.videoDurationSec;
    // Default: middle third of the video
    final start = (dur * 0.3).clamp(0.0, dur - 2);
    final end = (dur * 0.6).clamp(start + 1, dur);
    setState(() {
      _segments.add(_UiSegment(
        startSec: start,
        endSec: end,
        originalVol: 0.20,
        musicVol: 0.80,
        label: 'Segment ${_segments.length + 1}',
      ));
      _preset = _DjPreset.custom;
    });
  }

  void _removeSegment(int index) {
    _haptic();
    setState(() => _segments.removeAt(index));
  }

  void _confirm() {
    _haptic();
    final origSegs = <VolumeSegment>[];
    final musicSegs = <VolumeSegment>[];

    for (final seg in _segments) {
      origSegs.add(VolumeSegment(
        startSec: seg.startSec,
        endSec: seg.endSec,
        volume: seg.originalVol,
      ));
      musicSegs.add(VolumeSegment(
        startSec: seg.startSec,
        endSec: seg.endSec,
        volume: seg.musicVol,
      ));
    }

    Navigator.of(context).pop(DjMixResult(
      originalVolume: _originalVol,
      musicVolume: _musicVol,
      originalSegments: origSegs,
      musicSegments: musicSegs,
    ));
  }

  String _fmtSec(double sec) {
    final m = sec ~/ 60;
    final s = (sec % 60).toInt();
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  int _pct(double v) => (v * 100).round();

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ── Handle ──
          const SizedBox(height: 8),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // ── Header ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  '🎛️ Mixage DJ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  widget.trackTitle,
                  style: TextStyle(
                    color: _accent.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // ── Step indicator ──
          _buildStepIndicator(),
          const SizedBox(height: 8),

          // ── Content ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_step == 0) _buildStep0Presets(),
                  if (_step >= 1) _buildStep1Volumes(),
                  if (_step >= 2) _buildStep2Segments(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // ── Bottom bar ──
          _buildBottomBar(bottomPad),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step indicator
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStepIndicator() {
    const labels = ['Style', 'Volumes', 'Segments'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(3, (i) {
          final active = i <= _step;
          final current = i == _step;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                _haptic();
                setState(() => _step = i);
              },
              child: Column(
                children: [
                  Row(
                    children: [
                      if (i > 0)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: active
                                ? _accent.withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: current
                              ? _accent
                              : active
                                  ? _accent.withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: active && !current
                              ? const Icon(Icons.check, color: Colors.white, size: 14)
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    color: current ? Colors.white : Colors.white38,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      if (i < 2)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: i < _step
                                ? _accent.withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[i],
                    style: TextStyle(
                      color: current ? _accent : Colors.white38,
                      fontSize: 10,
                      fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step 0 — Preset choice (guided)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStep0Presets() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildGuideCard(
          '👋 Comment veux-tu que le son sonne ?',
          'Choisis un style de mixage. Tu pourras affiner ensuite.',
        ),
        const SizedBox(height: 12),
        for (final preset in _DjPreset.values)
          _buildPresetTile(preset),
      ],
    );
  }

  Widget _buildPresetTile(_DjPreset preset) {
    final selected = _preset == preset;
    return GestureDetector(
      onTap: () {
        _applyPreset(preset);
        // Auto-advance to step 1 after a short delay
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _step = 1);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? _accent.withValues(alpha: 0.12)
              : _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _accent : Colors.white.withValues(alpha: 0.06),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset.title,
                    style: TextStyle(
                      color: selected ? _accent : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preset.subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: _accent, size: 22),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step 1 — Volume sliders
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStep1Volumes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildGuideCard(
          '🔊 Ajuste les volumes globaux',
          'Glisse pour régler le volume de ta voix et de la musique sur toute la vidéo.',
        ),
        const SizedBox(height: 12),

        // Original audio slider
        _buildVolumeRow(
          icon: Icons.mic,
          label: 'Ma voix / Son original',
          value: _originalVol,
          color: const Color(0xFF4CAF50),
          onChanged: (v) => setState(() => _originalVol = v),
        ),
        const SizedBox(height: 12),

        // Music slider
        _buildVolumeRow(
          icon: Icons.music_note,
          label: 'Musique ajoutée',
          value: _musicVol,
          color: const Color(0xFF9C27B0),
          onChanged: (v) => setState(() => _musicVol = v),
        ),
        const SizedBox(height: 12),

        // Visual balance indicator
        _buildBalanceIndicator(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildVolumeRow({
    required IconData icon,
    required String label,
    required double value,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_pct(value)}%',
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.15),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              trackHeight: 5,
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 1,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceIndicator() {
    final total = _originalVol + _musicVol;
    final origPct = total > 0 ? _originalVol / total : 0.5;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('🎤', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 8,
                    child: Row(
                      children: [
                        Flexible(
                          flex: (origPct * 100).round().clamp(1, 99),
                          child: Container(color: const Color(0xFF4CAF50)),
                        ),
                        Flexible(
                          flex: ((1 - origPct) * 100).round().clamp(1, 99),
                          child: Container(color: const Color(0xFF9C27B0)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Text('🎵', style: TextStyle(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            origPct > 0.6
                ? 'Ta voix est bien audible'
                : origPct < 0.4
                    ? 'La musique domine'
                    : 'Bon équilibre entre voix et musique',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step 2 — Segments
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStep2Segments() {
    final dur = widget.videoDurationSec;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildGuideCard(
          '🎚️ Ajuste le volume par moment (optionnel)',
          'Ajoute des segments pour changer le volume à des moments précis.\n'
              'Ex : entre 5s et 8s, baisse ta voix pour que la musique ressorte.',
        ),
        const SizedBox(height: 12),

        // Timeline visual bar
        _buildTimelineBar(dur),
        const SizedBox(height: 12),

        // Segments list
        if (_segments.isEmpty)
          _buildEmptySegmentsHint()
        else
          for (int i = 0; i < _segments.length; i++)
            _buildSegmentCard(i, dur),

        const SizedBox(height: 8),

        // Add segment button
        Center(
          child: GestureDetector(
            onTap: _addSegment,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _accent.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_circle_outline, color: _accent, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Ajouter un segment',
                    style: TextStyle(
                      color: _accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineBar(double dur) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '⏱ Timeline : ${_fmtSec(0)} → ${_fmtSec(dur)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${_segments.length} segment${_segments.length != 1 ? 's' : ''}',
                style: TextStyle(
                  color: _accent.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Visual bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 20,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  return Stack(
                    children: [
                      // Base bar (global volumes)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF4CAF50).withValues(alpha: 0.3),
                              const Color(0xFF9C27B0).withValues(alpha: 0.3),
                            ],
                          ),
                        ),
                      ),
                      // Segment overlays
                      for (final seg in _segments)
                        Positioned(
                          left: (seg.startSec / dur * w).clamp(0, w),
                          width: ((seg.endSec - seg.startSec) / dur * w).clamp(4, w),
                          top: 0,
                          bottom: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _accent.withValues(alpha: 0.4),
                              border: Border.all(
                                color: _accent.withValues(alpha: 0.6),
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmtSec(0), style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 9)),
              Text(_fmtSec(dur / 2), style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 9)),
              Text(_fmtSec(dur), style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySegmentsHint() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        children: [
          const Icon(Icons.info_outline, color: Colors.white24, size: 28),
          const SizedBox(height: 8),
          Text(
            'Pas de segment ajouté',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Les volumes globaux s\'appliqueront sur toute la vidéo.\n'
            'Ajoute un segment si tu veux changer le volume à un moment précis.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.25),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentCard(int index, double dur) {
    final seg = _segments[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.tune, color: _accent, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${_fmtSec(seg.startSec)} → ${_fmtSec(seg.endSec)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _removeSegment(index),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, color: Colors.red.withValues(alpha: 0.6), size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Time range slider
          Text(
            '⏱ Quand ?',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _accent,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.06),
              thumbColor: _accent,
              overlayColor: _accent.withValues(alpha: 0.12),
              rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 7),
              trackHeight: 4,
            ),
            child: RangeSlider(
              values: RangeValues(seg.startSec, seg.endSec),
              min: 0,
              max: dur,
              onChanged: (v) {
                if (v.end - v.start >= 1.0) {
                  setState(() {
                    seg.startSec = v.start;
                    seg.endSec = v.end;
                  });
                }
              },
            ),
          ),

          // Volume sliders
          _buildSegmentVolSlider(
            icon: Icons.mic,
            label: 'Voix',
            value: seg.originalVol,
            color: const Color(0xFF4CAF50),
            onChanged: (v) => setState(() => seg.originalVol = v),
          ),
          const SizedBox(height: 4),
          _buildSegmentVolSlider(
            icon: Icons.music_note,
            label: 'Musique',
            value: seg.musicVol,
            color: const Color(0xFF9C27B0),
            onChanged: (v) => setState(() => seg.musicVol = v),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentVolSlider({
    required IconData icon,
    required String label,
    required double value,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        SizedBox(
          width: 52,
          child: Text(
            '$label ${_pct(value)}%',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.06),
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.1),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              trackHeight: 3,
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 1,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Guide card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildGuideCard(String title, String body) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: _accent.withValues(alpha: 0.6), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
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

  // ─────────────────────────────────────────────────────────────────────────
  // Bottom bar
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBottomBar(double bottomPad) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPad + 10),
      decoration: BoxDecoration(
        color: _bg,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          // Back / Skip
          if (_step > 0)
            GestureDetector(
              onTap: () {
                _haptic();
                setState(() => _step--);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '← Retour',
                  style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          const Spacer(),

          // Next / Confirm
          GestureDetector(
            onTap: () {
              _haptic();
              if (_step < 2) {
                setState(() => _step++);
              } else {
                _confirm();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_accent, Color(0xFF7C4DFF)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _step < 2 ? 'Suivant' : '🎵 Mixer',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_step < 2) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
