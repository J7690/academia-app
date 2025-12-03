import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../providers/landing_content_provider.dart';
import '../../providers/student_offers_provider.dart';
import '../debug/network_diagnostic_screen.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import '../../widgets/hls_web_stub.dart'
    if (dart.library.html) '../../widgets/hls_web.dart';
import '../../widgets/academia_video_widget.dart';

class _HeroMediaItem {
  final String url;
  final String mediaType; // 'video' ou 'image'

  const _HeroMediaItem({required this.url, required this.mediaType});
}

class AuthLandingScreen extends StatelessWidget {
  const AuthLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        title: GestureDetector(
          onLongPress: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NetworkDiagnosticScreen(),
              ),
            );
          },
          child: const Text('Academia'),
        ),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFA3D65C), Color(0xFF1EA75C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text(
              'Connexion',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B30),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SignupScreen()),
                );
              },
              child: const Text('Créer un compte'),
            ),
          ),
        ],
      ),
      body: const _MarketingLandingView(),
    );
  }
}

class _MarketingLandingView extends StatefulWidget {
  const _MarketingLandingView();

  @override
  State<_MarketingLandingView> createState() => _MarketingLandingViewState();
}

class _MarketingLandingViewState extends State<_MarketingLandingView> {
  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _isHlsWeb = false;
  String? _currentHlsUrl;

  late final ScrollController _tickerController;
  Timer? _tickerTimer;

  static const Duration _imageSlideDuration = Duration(seconds: 5);
  Timer? _mediaTimer;
  List<_HeroMediaItem> _mediaPlaylist = [];
  int _currentMediaIndex = 0;

  static const List<String> _fallbackAnnouncements = [
    'Ouverture des candidatures 2025',
    'Bourses pour étudiants internationaux',
    'Nouveaux programmes disponibles',
    'Accompagnement personnalisé',
  ];

  @override
  void initState() {
    super.initState();
    _tickerController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final landing = context.read<LandingContentProvider>();
      final offers = context.read<StudentOffersProvider>();

      try {
        await Future.wait([
          landing.loadPublicLandingContent(),
          offers.loadHomeOffers(),
        ]);
      } catch (_) {}

      if (!mounted) return;

      final cfg = landing.config;
      final urlFromConfig = (cfg?['video_url'] as String?)?.trim();
      final hasConfigVideo =
          (urlFromConfig != null && urlFromConfig.isNotEmpty);

      final videos = landing.videos;
      final playlist = <_HeroMediaItem>[];

      if (videos.isNotEmpty) {
        debugPrint('Landing: videos from provider (count=${videos.length})');
        for (final v in videos) {
          if (v['is_active'] == false) continue;
          final url = (v['video_url'] ?? '').toString().trim();
          if (url.isEmpty) continue;
          debugPrint('Landing: candidate video from Supabase=' + url);
          final rawType = (v['media_type'] ?? 'video').toString().toLowerCase();
          final mediaType = (rawType == 'image') ? 'image' : 'video';
          playlist.add(_HeroMediaItem(url: url, mediaType: mediaType));
        }
      }

      _startTicker();

      if (playlist.isEmpty && hasConfigVideo && urlFromConfig != null) {
        playlist.add(_HeroMediaItem(url: urlFromConfig, mediaType: 'video'));
      }

      if (playlist.isNotEmpty) {
        debugPrint('Landing: final playlist=' +
            playlist.map((e) => '${e.mediaType}:${e.url}').join(', '));
        _mediaPlaylist = playlist;
        _goToMediaIndex(0);
      }
    });
  }

  void _goToMediaIndex(int index) {
    if (_mediaPlaylist.isEmpty) return;
    _mediaTimer?.cancel();

    _currentMediaIndex = index % _mediaPlaylist.length;
    final item = _mediaPlaylist[_currentMediaIndex];

    if (item.mediaType == 'image') {
      debugPrint('Landing: displaying image media url=' + item.url);
      _videoController?.dispose();
      _videoController = null;
      _isHlsWeb = false;
      _currentHlsUrl = null;
      _videoReady = true;
      if (mounted) {
        setState(() {});
      }
      _mediaTimer = Timer(_imageSlideDuration, _onMediaCompleted);
    } else {
      _initVideo(item.url);
    }
  }

  Future<void> _initVideo(String url) async {
    debugPrint('Landing: _initVideo(url=' + url + ')');
    _videoController?.dispose();
    _videoReady = false;
    _isHlsWeb = false;
    _currentHlsUrl = null;
    if (mounted) {
      setState(() {});
    }

    final lowerUrl = url.toLowerCase();
    final isHls = lowerUrl.contains('.m3u8');

    debugPrint('Landing: _initVideo kIsWeb=' + kIsWeb.toString() +
        ' isHls=' + isHls.toString());

    if (kIsWeb && isHls) {
      debugPrint('Landing: using HLS web player for URL=' + url);
      setState(() {
        _videoController = null;
        _isHlsWeb = true;
        _currentHlsUrl = url;
        _videoReady = true;
      });
      return;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      debugPrint('Landing: using Android custom video widget for URL=' + url);
      setState(() {
        _videoController = null;
        _videoReady = true;
        _isHlsWeb = false;
        _currentHlsUrl = null;
      });
      return;
    }

    try {
      debugPrint('Landing: using VideoPlayer for URL=' + url);
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();

      var hasCompleted = false;
      controller.addListener(() {
        final value = controller.value;
        if (!mounted) return;
        if (!value.isInitialized) return;
        final duration = value.duration;
        if (duration == Duration.zero) return;
        if (!value.isPlaying && value.position >= duration && !hasCompleted) {
          hasCompleted = true;
          _onVideoCompleted();
        }
      });

      controller
        ..setLooping(false)
        ..setVolume(0)
        ..play();

      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() {
        _videoController = controller;
        _videoReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _videoController = null;
        _videoReady = false;
      });
      debugPrint('Landing: _initVideo error for URL=' + url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible de lire cette vidéo. Utilise un lien direct vers un fichier vidéo (mp4, webm, …) accessible publiquement.',
          ),
        ),
      );
    }
  }

  void _onVideoCompleted() {
    _onMediaCompleted();
  }

  void _onMediaCompleted() {
    if (!mounted) return;
    if (_mediaPlaylist.isEmpty) return;
    final nextIndex = (_currentMediaIndex + 1) % _mediaPlaylist.length;
    final nextItem = _mediaPlaylist[nextIndex];
    debugPrint('Landing: _onMediaCompleted -> next=${nextItem.mediaType}');
    _goToMediaIndex(nextIndex);
  }

  void _startTicker() {
    _tickerTimer?.cancel();
    const step = 4.0;
    const tick = Duration(milliseconds: 40);
    const animDuration = Duration(milliseconds: 40);

    _tickerTimer = Timer.periodic(tick, (_) {
      if (!_tickerController.hasClients) return;
      final position = _tickerController.position;
      if (!position.haveDimensions) return;
      final maxScroll = position.maxScrollExtent;
      if (maxScroll <= 0) return;

      final current = _tickerController.offset;
      double next = current + step;

      if (next >= maxScroll) {
        _tickerController.jumpTo(0);
        return;
      }

      _tickerController.animateTo(
        next,
        duration: animDuration,
        curve: Curves.linear,
      );
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _mediaTimer?.cancel();
    _tickerController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _pickRandomPrograms(
    List<Map<String, dynamic>> all,
  ) {
    if (all.isEmpty) return const [];
    final copy = List<Map<String, dynamic>>.from(all);
    copy.shuffle(Random());
    final take = copy.length > 6 ? 6 : copy.length;
    return copy.take(take).toList();
  }

  Widget _buildProgramCard(Map<String, dynamic> program) {
    final title =
        (program['program_title'] ?? program['title'] ?? '').toString();
    final universityName = (program['university_name'] ?? '').toString();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE5F9E7),
            Color(0xFFD1FAE5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      universityName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                  );
                },
                child: const Text('Voir plus'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color? _parseColor(String? hex) {
    if (hex == null) return null;
    var value = hex.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('#')) {
      value = value.substring(1);
    }
    if (value.startsWith('0x')) {
      value = value.substring(2);
    }
    if (value.length == 6) {
      value = 'FF$value';
    }
    if (value.length != 8) return null;
    final intVal = int.tryParse(value, radix: 16);
    if (intVal == null) return null;
    return Color(intVal);
  }

  IconData _iconForKey(String? key) {
    switch (key) {
      case 'files':
        return Icons.folder_copy_rounded;
      case 'bell':
        return Icons.notifications_active_rounded;
      case 'university':
        return Icons.school_rounded;
      case 'check':
        return Icons.verified_rounded;
      default:
        return Icons.star_rounded;
    }
  }

  Widget _buildWhyCard(Map<String, dynamic> card, Color accentColor) {
    final title = (card['title'] ?? '').toString();
    final subtitle = (card['subtitle'] ?? '').toString();
    final iconKey = (card['icon_key'] ?? '').toString();
    final icon = _iconForKey(iconKey);

    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openPartnerUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final landing = context.watch<LandingContentProvider>();
    final cfg = landing.config;

    final primaryColor =
        _parseColor(cfg?['primary_color'] as String?) ?? const Color(0xFFA3D65C);
    final secondaryColor =
        _parseColor(cfg?['secondary_color'] as String?) ?? const Color(0xFF1EA75C);
    final accentColor =
        _parseColor(cfg?['accent_color'] as String?) ?? const Color(0xFFFF3B30);

    final heroBadge =
        (cfg?['hero_badge_text'] as String?)?.trim().isNotEmpty == true
            ? (cfg?['hero_badge_text'] as String?)!.trim()
            : 'Prépare ton parcours universitaire';
    final heroTitle =
        (cfg?['hero_title'] as String?)?.trim().isNotEmpty == true
            ? (cfg?['hero_title'] as String?)!.trim()
            : 'Découvre les meilleurs programmes\net pilote tes démarches en un seul endroit.';
    final heroSubtitle =
        (cfg?['hero_subtitle'] as String?)?.trim().isNotEmpty == true
            ? (cfg?['hero_subtitle'] as String?)!.trim()
            : 'Accède aux offres complètes en créant ton compte gratuitement.';

    final announcements = landing.announcements;
    final partners = landing.partners;
    final whyCards = landing.whyCards;

    _HeroMediaItem? currentItem;
    if (_mediaPlaylist.isNotEmpty &&
        _currentMediaIndex >= 0 &&
        _currentMediaIndex < _mediaPlaylist.length) {
      currentItem = _mediaPlaylist[_currentMediaIndex];
    }

    String? currentVideoUrl;
    String? currentImageUrl;
    final item = currentItem;
    if (item != null) {
      if (item.mediaType == 'video') {
        currentVideoUrl = item.url;
      } else if (item.mediaType == 'image') {
        currentImageUrl = item.url;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final firstHeight = constraints.maxHeight;
        return SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                height: firstHeight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: () {
                            if (currentImageUrl != null) {
                              return Image.network(
                                currentImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, _, __) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [primaryColor, secondaryColor],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                  );
                                },
                              );
                            }

                            if (_videoReady &&
                                !kIsWeb &&
                                defaultTargetPlatform == TargetPlatform.android &&
                                currentVideoUrl != null) {
                              return AcademiaVideoWidget(
                                url: currentVideoUrl,
                                autoplay: true,
                                loop: true,
                                muted: true,
                                showControls: false,
                                resizeMode: 'cover',
                              );
                            }

                            if (_videoReady && _videoController != null) {
                              return FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: _videoController!.value.size.width,
                                  height: _videoController!.value.size.height,
                                  child: VideoPlayer(_videoController!),
                                ),
                              );
                            }

                            if (_videoReady &&
                                _isHlsWeb &&
                                kIsWeb &&
                                _currentHlsUrl != null) {
                              return const SizedBox.shrink();
                            }

                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [primaryColor, secondaryColor],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            );
                          }(),
                        ),
                        if (_videoReady && _isHlsWeb && kIsWeb && _currentHlsUrl != null)
                          Positioned.fill(
                            child: HlsWebVideoPlayer(
                              url: _currentHlsUrl!,
                              autoplay: true,
                              loop: false,
                              muted: true,
                              onEnded: _onVideoCompleted,
                            ),
                          ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  primaryColor.withOpacity(0.75),
                                  primaryColor.withOpacity(0.4),
                                  secondaryColor.withOpacity(0.05),
                                ],
                                stops: const [0.0, 0.45, 1.0],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      heroBadge,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    heroTitle,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    heroSubtitle,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: accentColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 22,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => const SignupScreen(),
                                            ),
                                          );
                                        },
                                        child: const Text('Créer un compte'),
                                      ),
                                      const SizedBox(width: 12),
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Colors.white),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => const LoginScreen(),
                                            ),
                                          );
                                        },
                                        child: const Text('Se connecter'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quelques programmes à découvrir',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Crée un compte pour voir tous les détails et filtrer les offres.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 16),
                    Consumer<StudentOffersProvider>(
                      builder: (context, provider, _) {
                        if (provider.isLoading && provider.homeOffers.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        if (provider.error != null &&
                            provider.homeOffers.isEmpty) {
                          return Text(
                            provider.error!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.red,
                            ),
                          );
                        }

                        final items = _pickRandomPrograms(provider.homeOffers);
                        if (items.isEmpty) {
                          return const Text(
                            'Les programmes apparaîtront ici dès qu’ils seront disponibles.',
                            style: TextStyle(fontSize: 13),
                          );
                        }
                        final isWide = MediaQuery.of(context).size.width >= 900;
                        if (!isWide) {
                          return SizedBox(
                            height: 170,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final p = items[index];
                                return SizedBox(
                                  width: 280,
                                  child: _buildProgramCard(p),
                                );
                              },
                            ),
                          );
                        }

                        final screenWidth = MediaQuery.of(context).size.width;
                        final horizontalPadding = 40.0; // 20 de chaque côté
                        final availableWidth = screenWidth - horizontalPadding;
                        final cardWidth = (availableWidth - 12) / 2;

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: items
                              .map(
                                (p) => SizedBox(
                                  width: cardWidth,
                                  child: _buildProgramCard(p),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (whyCards.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pourquoi créer un compte ?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 900;
                          if (isNarrow) {
                            return SizedBox(
                              height: 210,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: whyCards.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final card = whyCards[index];
                                  return _buildWhyCard(card, accentColor);
                                },
                              ),
                            );
                          }

                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: whyCards
                                .map((card) => _buildWhyCard(card, accentColor))
                                .toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SignupScreen(),
                            ),
                          );
                        },
                        child: const Text('Créer mon compte gratuitement'),
                      ),
                    ],
                  ),
                ),
              if (partners.isNotEmpty) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Universités partenaires',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 64,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: partners.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final p = partners[index];
                            final logoUrl = p['logo_url']?.toString();
                            final name = p['name']?.toString() ?? '';
                            final website = p['website_url']?.toString();

                            return GestureDetector(
                              onTap: (website != null && website.isNotEmpty)
                                  ? () => _openPartnerUrl(website)
                                  : null,
                              child: Container(
                                width: 120,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: logoUrl != null && logoUrl.isNotEmpty
                                    ? Image.network(
                                        logoUrl,
                                        fit: BoxFit.contain,
                                      )
                                    : Center(
                                        child: Text(
                                          name,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 0),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF15803D), Color(0xFF0F766E)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: SizedBox(
                  height: 32,
                  child: ListView.builder(
                    controller: _tickerController,
                    scrollDirection: Axis.horizontal,
                    itemCount: () {
                      final baseCount = announcements.isNotEmpty
                          ? announcements.length
                          : _fallbackAnnouncements.length;
                      if (baseCount <= 0) return 0;
                      return baseCount * 20;
                    }(),
                    itemBuilder: (context, index) {
                      final hasAnnouncements = announcements.isNotEmpty;
                      final baseCount = hasAnnouncements
                          ? announcements.length
                          : _fallbackAnnouncements.length;
                      if (baseCount == 0) {
                        return const SizedBox.shrink();
                      }
                      final effectiveIndex = index % baseCount;
                      String text;
                      if (hasAnnouncements) {
                        final a = announcements[effectiveIndex];
                        text = (a['text'] ?? '').toString();
                        if (text.isEmpty) {
                          text = _fallbackAnnouncements[
                              effectiveIndex % _fallbackAnnouncements.length];
                        }
                      } else {
                        text = _fallbackAnnouncements[effectiveIndex];
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Center(
                          child: Text(
                            text,
                            style: const TextStyle(
                              color: Color(0xFFF9FAFB),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
