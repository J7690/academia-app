import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

class AudioTrack {
  final String id;
  final String title;
  final String artist;
  final AudioCategory category;
  final String url; // direct streamable MP3 URL
  final Duration duration;
  final String mood;

  const AudioTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.category,
    required this.url,
    required this.duration,
    this.mood = 'neutral',
  });
}

/// Result returned when the user selects a track + trim range.
class AudioPickResult {
  final AudioTrack track;
  final Duration trimStart;
  final Duration trimEnd;

  const AudioPickResult({
    required this.track,
    required this.trimStart,
    required this.trimEnd,
  });

  Duration get trimDuration => trimEnd - trimStart;
}

enum AudioCategory {
  education('🎓', 'Éducation', Color(0xFF4CAF50)),
  chill('🎵', 'Chill / Lo-fi', Color(0xFF9C27B0)),
  motivating('🔥', 'Motivant', Color(0xFFFF5722)),
  none('🔇', 'Aucun', Color(0xFF757575));

  final String emoji;
  final String label;
  final Color color;
  const AudioCategory(this.emoji, this.label, this.color);
}

// ─────────────────────────────────────────────────────────────────────────────
// Audio library — Pixabay CDN direct MP3 links (royalty-free, no attribution)
// These URLs stream directly via audioplayers UrlSource.
// ─────────────────────────────────────────────────────────────────────────────

const List<AudioTrack> kAudioLibrary = [
  // ── Éducation ──
  AudioTrack(
    id: 'edu_01',
    title: 'Documentary',
    artist: 'Pixabay',
    category: AudioCategory.education,
    url: 'https://cdn.pixabay.com/audio/2022/02/22/audio_d1718ab41b.mp3',
    duration: Duration(minutes: 2, seconds: 12),
    mood: 'calm',
  ),
  AudioTrack(
    id: 'edu_02',
    title: 'Science Documentary',
    artist: 'Pixabay',
    category: AudioCategory.education,
    url: 'https://cdn.pixabay.com/audio/2022/10/25/audio_33845bc1c1.mp3',
    duration: Duration(minutes: 1, seconds: 57),
    mood: 'motivating',
  ),
  AudioTrack(
    id: 'edu_03',
    title: 'Inspiring Cinematic',
    artist: 'Pixabay',
    category: AudioCategory.education,
    url: 'https://cdn.pixabay.com/audio/2022/01/18/audio_d0a13f69d2.mp3',
    duration: Duration(minutes: 2, seconds: 28),
    mood: 'motivating',
  ),
  AudioTrack(
    id: 'edu_04',
    title: 'Ambient Piano',
    artist: 'Pixabay',
    category: AudioCategory.education,
    url: 'https://cdn.pixabay.com/audio/2022/08/02/audio_884fe92c21.mp3',
    duration: Duration(minutes: 2, seconds: 6),
    mood: 'calm',
  ),

  // ── Chill / Lo-fi ──
  AudioTrack(
    id: 'chill_01',
    title: 'Lofi Study',
    artist: 'Pixabay',
    category: AudioCategory.chill,
    url: 'https://cdn.pixabay.com/audio/2022/05/27/audio_1808fbf07a.mp3',
    duration: Duration(minutes: 2, seconds: 34),
    mood: 'calm',
  ),
  AudioTrack(
    id: 'chill_02',
    title: 'Chill Abstract',
    artist: 'Pixabay',
    category: AudioCategory.chill,
    url: 'https://cdn.pixabay.com/audio/2022/11/22/audio_febc508520.mp3',
    duration: Duration(minutes: 2, seconds: 21),
    mood: 'calm',
  ),
  AudioTrack(
    id: 'chill_03',
    title: 'Good Night',
    artist: 'Pixabay',
    category: AudioCategory.chill,
    url: 'https://cdn.pixabay.com/audio/2022/05/16/audio_35e67a8e8f.mp3',
    duration: Duration(minutes: 2, seconds: 49),
    mood: 'calm',
  ),
  AudioTrack(
    id: 'chill_04',
    title: 'Relaxing',
    artist: 'Pixabay',
    category: AudioCategory.chill,
    url: 'https://cdn.pixabay.com/audio/2022/03/10/audio_b09a9e6cbc.mp3',
    duration: Duration(minutes: 3, seconds: 5),
    mood: 'calm',
  ),

  // ── Motivant ──
  AudioTrack(
    id: 'motiv_01',
    title: 'Energetic Hip Hop',
    artist: 'Pixabay',
    category: AudioCategory.motivating,
    url: 'https://cdn.pixabay.com/audio/2022/08/25/audio_4f3b0a816e.mp3',
    duration: Duration(minutes: 2, seconds: 15),
    mood: 'energetic',
  ),
  AudioTrack(
    id: 'motiv_02',
    title: 'Upbeat Fun',
    artist: 'Pixabay',
    category: AudioCategory.motivating,
    url: 'https://cdn.pixabay.com/audio/2023/07/19/audio_e552178e49.mp3',
    duration: Duration(minutes: 1, seconds: 48),
    mood: 'energetic',
  ),
  AudioTrack(
    id: 'motiv_03',
    title: 'Powerful Beat',
    artist: 'Pixabay',
    category: AudioCategory.motivating,
    url: 'https://cdn.pixabay.com/audio/2022/04/27/audio_67bcce58af.mp3',
    duration: Duration(minutes: 2, seconds: 32),
    mood: 'motivating',
  ),
  AudioTrack(
    id: 'motiv_04',
    title: 'Electronic Future',
    artist: 'Pixabay',
    category: AudioCategory.motivating,
    url: 'https://cdn.pixabay.com/audio/2022/03/15/audio_115b9b3c26.mp3',
    duration: Duration(minutes: 2, seconds: 41),
    mood: 'energetic',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// AudioPickerSheet — TikTok-style music picker with preview + trim
// ─────────────────────────────────────────────────────────────────────────────

class AudioPickerSheet extends StatefulWidget {
  final String? currentTrackId;

  const AudioPickerSheet({super.key, this.currentTrackId});

  @override
  State<AudioPickerSheet> createState() => _AudioPickerSheetState();
}

class _AudioPickerSheetState extends State<AudioPickerSheet> {
  AudioCategory _selectedCategory = AudioCategory.education;
  final AudioPlayer _player = AudioPlayer();

  // Playback state
  String? _playingId;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<PlayerState>? _stateSub;

  // Trim state — only shown when a track is expanded
  String? _expandedId;
  RangeValues _trimRange = const RangeValues(0, 1); // normalized 0..1

  @override
  void initState() {
    super.initState();
    _posSub = _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _durSub = _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _totalDuration = d);
    });
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (s == PlayerState.completed && mounted) {
        setState(() => _playingId = null);
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _haptic() => HapticFeedback.lightImpact();

  List<AudioTrack> get _filteredTracks {
    if (_selectedCategory == AudioCategory.none) return [];
    return kAudioLibrary
        .where((t) => t.category == _selectedCategory)
        .toList(growable: false);
  }

  Future<void> _togglePlay(AudioTrack track) async {
    _haptic();
    if (_playingId == track.id) {
      await _player.stop();
      setState(() => _playingId = null);
      return;
    }

    setState(() {
      _playingId = track.id;
      _isLoading = true;
      _position = Duration.zero;
      _totalDuration = track.duration;
    });

    try {
      await _player.play(UrlSource(track.url));
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('[AudioPickerSheet] play error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _playingId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de lire : $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  void _expandTrack(AudioTrack track) {
    _haptic();
    setState(() {
      if (_expandedId == track.id) {
        _expandedId = null;
      } else {
        _expandedId = track.id;
        _trimRange = const RangeValues(0, 1);
      }
    });
  }

  void _selectTrack(AudioTrack track) {
    _haptic();
    _player.stop();

    final totalMs = track.duration.inMilliseconds.toDouble();
    final trimStart = Duration(
      milliseconds: (_trimRange.start * totalMs).round(),
    );
    final trimEnd = Duration(
      milliseconds: (_trimRange.end * totalMs).round(),
    );

    Navigator.of(context).pop(
      AudioPickResult(
        track: track,
        trimStart: trimStart,
        trimEnd: trimEnd,
      ),
    );
  }

  void _selectNone() {
    _haptic();
    _player.stop();
    Navigator.of(context).pop(
      AudioPickResult(
        track: const AudioTrack(
          id: 'none',
          title: 'Aucun',
          artist: '',
          category: AudioCategory.none,
          url: '',
          duration: Duration.zero,
        ),
        trimStart: Duration.zero,
        trimEnd: Duration.zero,
      ),
    );
  }

  String _fmtDur(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _fmtSec(double sec) {
    final m = sec ~/ 60;
    final s = (sec % 60).toInt();
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    final tracks = _filteredTracks;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
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

          // ── Title ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  '🎵 Musique de fond',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _selectNone,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '🔇 Sans musique',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Category chips ──
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final cat in AudioCategory.values.where((c) => c != AudioCategory.none))
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () {
                        _haptic();
                        setState(() => _selectedCategory = cat);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _selectedCategory == cat
                              ? cat.color.withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _selectedCategory == cat ? cat.color : Colors.transparent,
                            width: _selectedCategory == cat ? 2 : 0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(cat.emoji, style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 4),
                            Text(
                              cat.label,
                              style: TextStyle(
                                color: _selectedCategory == cat ? cat.color : Colors.white54,
                                fontSize: 12,
                                fontWeight: _selectedCategory == cat ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Track list ──
          Expanded(
            child: tracks.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun morceau dans cette catégorie.',
                      style: TextStyle(color: Colors.white24, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    itemCount: tracks.length,
                    itemBuilder: (_, i) => _buildTrackTile(tracks[i]),
                  ),
          ),

          SizedBox(height: bottomPad + 6),
        ],
      ),
    );
  }

  Widget _buildTrackTile(AudioTrack track) {
    final isPlaying = _playingId == track.id;
    final isExpanded = _expandedId == track.id;
    final isSelected = widget.currentTrackId == track.id;
    final color = track.category.color;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isExpanded
            ? color.withValues(alpha: 0.08)
            : isSelected
                ? color.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: isExpanded || isSelected
            ? Border.all(color: color.withValues(alpha: 0.4), width: 1)
            : null,
      ),
      child: Column(
        children: [
          // ── Main row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: Row(
              children: [
                // Play/Pause button
                GestureDetector(
                  onTap: () => _togglePlay(track),
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: isPlaying
                          ? color.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: _isLoading && isPlaying
                        ? Padding(
                            padding: const EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: color,
                            ),
                          )
                        : Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: isPlaying ? color : Colors.white54,
                            size: 24,
                          ),
                  ),
                ),
                const SizedBox(width: 10),

                // Track info — tap to expand/trim
                Expanded(
                  child: GestureDetector(
                    onTap: () => _expandTrack(track),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          style: TextStyle(
                            color: isSelected ? color : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '${track.artist} · ${_fmtDur(track.duration)}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _moodLabel(track.mood),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Progress bar when playing
                        if (isPlaying) ...[
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: _totalDuration.inMilliseconds > 0
                                  ? (_position.inMilliseconds / _totalDuration.inMilliseconds).clamp(0.0, 1.0)
                                  : 0,
                              backgroundColor: Colors.white.withValues(alpha: 0.06),
                              color: color,
                              minHeight: 3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // USE button — always visible
                GestureDetector(
                  onTap: () => _selectTrack(track),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.7)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.25),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Text(
                      'Utiliser',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                if (isSelected) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.check_circle, color: color, size: 18),
                ],
              ],
            ),
          ),

          // ── Trim panel (expanded) ──
          if (isExpanded)
            _buildTrimPanel(track),
        ],
      ),
    );
  }

  Widget _buildTrimPanel(AudioTrack track) {
    final color = track.category.color;
    final totalSec = track.duration.inSeconds.toDouble();
    final startSec = _trimRange.start * totalSec;
    final endSec = _trimRange.end * totalSec;
    final segmentSec = endSec - startSec;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.content_cut, color: Colors.white38, size: 14),
              const SizedBox(width: 4),
              Text(
                'Couper un extrait',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${_fmtSec(startSec)} → ${_fmtSec(endSec)}  (${segmentSec.toStringAsFixed(0)}s)',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.15),
              rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 7),
              trackHeight: 4,
            ),
            child: RangeSlider(
              values: _trimRange,
              min: 0,
              max: 1,
              onChanged: (v) {
                // Minimum segment: 2 seconds
                final minSegment = 2.0 / totalSec;
                if (v.end - v.start >= minSegment) {
                  setState(() => _trimRange = v);
                }
              },
            ),
          ),
          Text(
            'Ce morceau sera lu en boucle pendant ta vidéo',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.2),
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  String _moodLabel(String mood) {
    switch (mood) {
      case 'calm':
        return '😌 Calme';
      case 'energetic':
        return '⚡ Énergique';
      case 'motivating':
        return '💪 Motivant';
      default:
        return '🎵 Neutre';
    }
  }
}
