import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/landing_content_provider.dart';
import '../../providers/student_offers_provider.dart';
import '../../utils/responsive.dart';
import '../debug/network_diagnostic_screen.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import '../../video/academia_playback_engine.dart';

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
  bool _videoReady = false;

  late final ScrollController _tickerController;
  Timer? _tickerTimer;

  static const Duration _imageSlideDuration = Duration(seconds: 8);
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

      _startTicker();

      final playlist = <_HeroMediaItem>[];
      try {
        final client = Supabase.instance.client;
        final dynamic response = await client
            .schema('app')
            .from('hero_playlist')
            .select('base_video_url, base_image_url, media_type, sort_order, is_active')
            .eq('slot', 'landing_hero_main')
            .eq('is_active', true)
            .order('sort_order', ascending: true)
            .limit(10);

        if (response is List && response.isNotEmpty) {
          for (final raw in response) {
            Map<String, dynamic>? row;
            if (raw is Map<String, dynamic>) {
              row = raw;
            } else if (raw is Map) {
              row = Map<String, dynamic>.from(raw);
            }
            if (row == null) {
              continue;
            }

            final rawType = (row['media_type'] ?? 'video').toString().toLowerCase();
            final isImage = rawType == 'image';
            final heroVideoUrl = (row['base_video_url'] ?? '').toString().trim();
            final heroImageUrl = (row['base_image_url'] ?? '').toString().trim();

            String? chosenUrl;
            String mediaType;
            if (isImage && heroImageUrl.isNotEmpty) {
              chosenUrl = heroImageUrl;
              mediaType = 'image';
            } else if (!isImage && heroVideoUrl.isNotEmpty) {
              chosenUrl = heroVideoUrl;
              mediaType = 'video';
            } else if (heroVideoUrl.isNotEmpty) {
              chosenUrl = heroVideoUrl;
              mediaType = 'video';
            } else if (heroImageUrl.isNotEmpty) {
              chosenUrl = heroImageUrl;
              mediaType = 'image';
            } else {
              chosenUrl = null;
              mediaType = 'video';
            }

            if (chosenUrl != null && chosenUrl.isNotEmpty) {
              debugPrint('Landing: hero item from app.hero_playlist url=' + chosenUrl);
              playlist.add(_HeroMediaItem(url: chosenUrl, mediaType: mediaType));
            }
          }
        }
      } catch (_) {}

      if (playlist.isNotEmpty) {
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
    _videoReady = false;
    if (mounted) {
      setState(() {});
    }

    if (!mounted) return;
    setState(() {
      _videoReady = true;
    });
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
    _tickerController.dispose();
    _mediaTimer?.cancel();
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
        final width = constraints.maxWidth;
        final bool isMobile = width < AppBreakpoints.mobile;
        final double heroBadgeSpacing = isMobile ? 12.0 : 16.0;
        final double heroTitleSpacing = isMobile ? 8.0 : 10.0;
        final double heroSubtitleSpacing = isMobile ? 14.0 : 18.0;
        final double sectionSpacing = isMobile ? 16.0 : 24.0;
        final double partnersSpacing = isMobile ? 20.0 : 24.0;
        final double bottomSpacing = isMobile ? 16.0 : 24.0;
        final hero = Padding(
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

                    if (_videoReady && currentVideoUrl != null) {
                      return AcademiaPlaybackEngine.view(
                        url: currentVideoUrl,
                        autoplay: true,
                        looping: false,
                        muted: kIsWeb,
                        showControls: false,
                        fit: BoxFit.cover,
                        onCompleted: _onVideoCompleted,
                        showErrorText: false,
                      );
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
                  padding: EdgeInsets.fromLTRB(
                    24,
                    isMobile ? 12 : 16,
                    24,
                    isMobile ? 20 : 32,
                  ),
                  child: Align(
                    alignment:
                        isMobile ? Alignment.bottomLeft : Alignment.centerLeft,
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
                          SizedBox(height: heroBadgeSpacing),
                          Text(
                            heroTitle,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 22 : 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: heroTitleSpacing),
                          Text(
                            heroSubtitle,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: heroSubtitleSpacing),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
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
        );
        return SingleChildScrollView(
          child: Column(
            children: [
              if (isMobile)
                hero
              else
                SizedBox(
                  height: firstHeight,
                  child: hero,
                ),
              SizedBox(height: sectionSpacing),
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
              SizedBox(height: sectionSpacing),
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
                SizedBox(height: partnersSpacing),
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
              SizedBox(height: sectionSpacing),
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
              SizedBox(height: bottomSpacing),
            ],
          ),
        );
      },
    );
  }
}
