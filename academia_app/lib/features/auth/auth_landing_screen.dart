import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';

import '../../providers/landing_content_provider.dart';
import '../../providers/student_offers_provider.dart';
import '../../utils/responsive.dart';
import '../../widgets/hero_media_carousel.dart';
import '../debug/network_diagnostic_screen.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'phone_signup_screen.dart';
import '../share/share_service.dart';
import '../share/share_mode_provider.dart';
import '../share/widgets/share_signature.dart';
import '../../services/analytics_tracking_service.dart';

void _showSignupChoice(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Comment souhaitez-vous vous inscrire ?",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _SignupOptionTile(
                icon: Icons.email_outlined,
                color: const Color(0xFF3275D0),
                title: 'Par adresse e-mail',
                subtitle: 'Nom, prénom, e-mail et mot de passe',
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const SignupScreen(),
                  ));
                },
              ),
              const SizedBox(height: 12),
              _SignupOptionTile(
                icon: Icons.phone_android,
                color: const Color(0xFF1EA75C),
                title: 'Par numéro de téléphone',
                subtitle: 'Nom, prénom, numéro et mot de passe',
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const PhoneSignupScreen(),
                  ));
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SignupOptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SignupOptionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(12),
          color: color.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}

class AuthLandingScreen extends StatelessWidget {
  const AuthLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shareService = ShareService();
    final shareBoundaryKey = GlobalKey();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 72,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF7BC96F), Color(0xFFE8F5E9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leadingWidth: context.isMobile ? 110 : 150,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              height: 36,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white, width: 1.5),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: context.isMobile ? 10 : 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: Text(
                  'Connexion',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: context.isMobile ? 12 : 14,
                  ),
                ),
              ),
            ),
          ),
        ),
        title: GestureDetector(
          onLongPress: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NetworkDiagnosticScreen(),
              ),
            );
          },
          child: SizedBox(
            height: 72,
            child: FittedBox(
              fit: BoxFit.fitHeight,
              child: Image.asset(
                'assets/images/nexiom.png',
              ),
            ),
          ),
        ),
        actions: [
          Consumer<ShareModeProvider>(
            builder: (context, shareMode, _) {
              if (shareMode.isShareModeEnabled) {
                return const SizedBox.shrink();
              }
              final isBusy = shareMode.isBusy;
              return IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Partager',
                onPressed: isBusy
                    ? null
                    : () async {
                        await shareService.shareCurrentView(
                          context: context,
                          boundaryKey: shareBoundaryKey,
                          shareText:
                              'Découvert via Academia – Faciliter l’accès aux formations.',
                        );
                      },
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(
              height: 36,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B30),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: context.isMobile ? 10 : 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  elevation: 0,
                ),
                onPressed: () => _showSignupChoice(context),
                child: Text(
                  'Créer un compte',
                  style: TextStyle(
                    fontSize: context.isMobile ? 12 : 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RepaintBoundary(
        key: shareBoundaryKey,
        child: Stack(
          children: [
            const _MarketingLandingView(),
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
}

class _MarketingLandingView extends StatefulWidget {
  const _MarketingLandingView();

  @override
  State<_MarketingLandingView> createState() => _MarketingLandingViewState();
}

class _MarketingLandingViewState extends State<_MarketingLandingView> {
  late final ScrollController _tickerController;
  Timer? _tickerTimer;

  /// Playlist du hero landing, alimentée par app_public_hero_playlist.
  List<HeroMediaItem> _heroMediaItems = [];

  static const String _landingHeroCacheKey = 'landing_hero_playlist_v1';

  Future<void> _loadHeroPlaylistFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_landingHeroCacheKey);
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final cached = <HeroMediaItem>[];
      var sort = 0;
      for (final item in decoded) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final url = (map['url'] ?? '').toString().trim();
        if (url.isEmpty) continue;
        final mediaType = (map['mediaType'] ?? 'video').toString();
        cached.add(
          HeroMediaItem(
            id: 'cache_$sort',
            mediaType: mediaType,
            url: url,
            sortOrder: sort,
          ),
        );
        sort++;
      }

      if (cached.isEmpty || !mounted) return;

      setState(() {
        _heroMediaItems = cached;
      });
    } catch (_) {}
  }

  Future<void> _refreshHeroPlaylistFromRemote() async {
    final client = Supabase.instance.client;
    final playlist = <HeroMediaItem>[];

    try {
      debugPrint(
        'Landing: calling app_public_hero_playlist(slot=landing_hero_main)',
      );
      final dynamic response = await client.rpc(
        'app_public_hero_playlist',
        params: {'p_slot': 'landing_hero_main'},
      );

      if (response is! Map<String, dynamic>) {
        debugPrint(
          'Landing: invalid hero playlist response type='
          '${response.runtimeType}',
        );
        return;
      }
      if (response['success'] != true) {
        debugPrint(
          'Landing: app_public_hero_playlist returned non-success: '
          'success=${response['success']} error=${response['error']}',
        );
        return;
      }

      final items = response['items'];
      if (items is! List) {
        debugPrint('Landing: hero playlist items is not a List');
        return;
      }

      for (final raw in items) {
        if (raw is! Map) continue;
        final row = Map<String, dynamic>.from(raw);

        final rawType = (row['media_type'] ?? 'video').toString().toLowerCase();
        final isImage = rawType == 'image';

        final playbackRaw = row['playback'];
        Map<String, dynamic>? playback;
        if (playbackRaw is Map) {
          playback = Map<String, dynamic>.from(playbackRaw);
        }

        final bestUrl = (playback?['best_url'] ?? '').toString().trim();
        final posterUrl = (playback?['poster_url'] ?? '').toString().trim();
        final baseVideoUrl = (row['base_video_url'] ?? '').toString().trim();
        final baseImageUrl = (row['base_image_url'] ?? '').toString().trim();

        String? resolvedUrl;
        String mediaType;

        if (isImage) {
          if (baseImageUrl.isEmpty) continue;
          resolvedUrl = baseImageUrl;
          mediaType = 'image';
        } else {
          resolvedUrl = bestUrl.isNotEmpty ? bestUrl : baseVideoUrl;
          if (resolvedUrl.isEmpty) {
            continue;
          }
          mediaType = 'video';
        }

        final id = (row['id'] ?? '').toString();
        final sortOrder = (row['sort_order'] as int?) ?? playlist.length;

        debugPrint(
          'Landing: hero item from app_public_hero_playlist slot=landing_hero_main '
          'id=' + id + ' type=' + mediaType + ' url=' + resolvedUrl,
        );

        playlist.add(
          HeroMediaItem(
            id: id.isNotEmpty ? id : 'auto_${playlist.length}',
            mediaType: mediaType,
            url: resolvedUrl,
            posterUrl: posterUrl.isNotEmpty ? posterUrl : null,
            sortOrder: sortOrder,
          ),
        );
      }
      debugPrint(
        'Landing: hero playlist built with \\${playlist.length} items from app_public_hero_playlist',
      );
    } catch (e) {
      debugPrint(
        'Landing: error while loading hero playlist from app_public_hero_playlist: '
        '\\$e',
      );
    }

    if (!mounted) {
      debugPrint(
        'Landing: hero playlist refresh aborted after app_public_hero_playlist, '
        'mounted=$mounted playlist_len=${playlist.length}',
      );
      return;
    }

    if (playlist.isEmpty) {
      try {
        Map<String, dynamic>? cfg;

        final landing = context.read<LandingContentProvider>();
        final cachedCfg = landing.config;
        if (cachedCfg != null) {
          cfg = cachedCfg;
        } else {
          final dynamic resp = await client.rpc('app_public_landing_content');
          if (resp is Map<String, dynamic> && resp['success'] == true) {
            final c = resp['config'];
            if (c is Map) {
              cfg = Map<String, dynamic>.from(c);
            }
          }
        }

        final playback = (cfg?['playback'] is Map)
            ? Map<String, dynamic>.from(cfg?['playback'] as Map)
            : null;
        final bestUrl = (playback?['best_url'] ?? '').toString().trim();
        final heroVideoUrl = (cfg?['hero_video_url'] ?? '').toString().trim();
        final fallbackUrl = bestUrl.isNotEmpty ? bestUrl : heroVideoUrl;
        if (fallbackUrl.isNotEmpty) {
          playlist.add(
            HeroMediaItem(
              id: 'fallback_config',
              mediaType: 'video',
              url: fallbackUrl,
              posterUrl: (playback?['poster_url'] ?? '').toString().trim().isNotEmpty
                  ? (playback?['poster_url'] ?? '').toString().trim()
                  : null,
              sortOrder: 0,
            ),
          );
          debugPrint(
            'Landing: hero playlist empty from app_public_hero_playlist, using config fallback url=$fallbackUrl',
          );
        }
      } catch (e) {
        debugPrint('Landing: error while building hero fallback from config: $e');
      }
    }

    // Always update the in-memory hero playlist, even when it becomes empty,
    // so that deletions in the admin actually clear the hero media on landing.
    setState(() {
      _heroMediaItems = playlist;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      if (playlist.isEmpty) {
        await prefs.remove(_landingHeroCacheKey);
      } else {
        final data = playlist
            .map((e) => {
                  'url': e.url,
                  'mediaType': e.mediaType,
                })
            .toList();
        await prefs.setString(_landingHeroCacheKey, jsonEncode(data));
      }
    } catch (_) {}
  }

  static const List<String> _fallbackAnnouncements = [
    'Ouverture des candidatures 2025',
    'Bourses pour étudiants internationaux',
    'Nouveaux programmes disponibles',
    'Accompagnement personnalisé',
  ];

  @override
  void initState() {
    super.initState();
    AnalyticsTrackingService.instance.init();
    AnalyticsTrackingService.instance.trackScreen('auth_landing');
    _tickerController = ScrollController();
    _loadHeroPlaylistFromCache();
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

      await _refreshHeroPlaylistFromRemote();
    });
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

  Future<void> _showAuthRequiredDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Connexion requise'),
          content: const Text(
            'Pour voir tous les détails et postuler, connecte-toi ou crée un compte.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LoginScreen(),
                  ),
                );
              },
              child: const Text('Se connecter'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showSignupChoice(context);
              },
              child: const Text('Créer un compte'),
            ),
          ],
        );
      },
    );
  }

  static const _kLandingCardGradients = <List<Color>>[
    [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
    [Color(0xFF1A2980), Color(0xFF26D0CE)],
    [Color(0xFF0B486B), Color(0xFFF56217)],
    [Color(0xFF2E7D32), Color(0xFF66BB6A)],
    [Color(0xFF4A148C), Color(0xFFAB47BC)],
    [Color(0xFFBF360C), Color(0xFFFF8A65)],
    [Color(0xFF00695C), Color(0xFF4DB6AC)],
    [Color(0xFF283593), Color(0xFF5C6BC0)],
  ];

  Widget _buildProgramCard(Map<String, dynamic> program, {int gradientIndex = 0}) {
    final title =
        (program['program_title'] ?? program['title'] ?? '').toString();
    final universityName = (program['university_name'] ?? '').toString();
    final degree = (program['degree_level'] ?? '').toString();
    final city = (program['city'] ?? '').toString();
    final country = (program['country'] ?? '').toString();

    final locationParts = <String>[];
    if (city.isNotEmpty) locationParts.add(city);
    if (country.isNotEmpty) locationParts.add(country);
    final location = locationParts.join(', ');

    final colors =
        _kLandingCardGradients[gradientIndex % _kLandingCardGradients.length];

    return _ScaleTapWrapper(
      onTap: () {
        _showAuthRequiredDialog();
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x28000000),
              offset: Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Decorative circle pattern
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              left: -10,
              bottom: -15,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // University icon
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Title
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // University name
                  Text(
                    universityName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.75),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Badges
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      if (degree.isNotEmpty)
                        _buildBadge(degree),
                      if (location.isNotEmpty)
                        _buildBadge(location),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildShortTrainingCard(Map<String, dynamic> item) {
    final title = (item['title'] ?? '').toString();
    final category = (item['category'] ?? '').toString();
    final modality = (item['modality'] ?? '').toString();
    final location = (item['location'] ?? '').toString();
    final rawPrice = item['price'];
    final priceText = rawPrice == null || rawPrice.toString().trim().isEmpty
        ? 'Tarif : à préciser'
        : 'Tarif : ${rawPrice.toString()}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0x80F6A623),
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _showAuthRequiredDialog();
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
                        color: Color(0xFF0A2540),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (category.isNotEmpty || modality.isNotEmpty) ...[
                      Text(
                        [category, modality]
                            .where((e) => e.trim().isNotEmpty)
                            .join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    if (location.isNotEmpty) ...[
                      Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      priceText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF3275D0),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3275D0),
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
                child: const Text('S’inscrire'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOpportunityHighlightCard(Map<String, dynamic> item) {
    final title = (item['title'] ?? '').toString();
    final org = (item['organization_name'] ?? '').toString();
    final city = (item['city'] ?? '').toString();
    final country = (item['country'] ?? '').toString();
    final shortDescription = (item['short_description'] ?? '').toString();
    final type = (item['type'] ?? '').toString();

    String locationLabel;
    if (city.isNotEmpty && country.isNotEmpty) {
      locationLabel = '$city, $country';
    } else if (city.isNotEmpty) {
      locationLabel = city;
    } else {
      locationLabel = country;
    }

    final typeLabel = type.isNotEmpty ? 'Type : $type' : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0x80F6A623),
          width: 2,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0A2540),
                ),
              ),
              const SizedBox(height: 4),
              if (org.isNotEmpty) ...[
                Text(
                  org,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 2),
              ],
              if (locationLabel.isNotEmpty) ...[
                Text(
                  locationLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              if (shortDescription.isNotEmpty) ...[
                Text(
                  shortDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              if (typeLabel != null) ...[
                Text(
                  typeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3275D0),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: () {
                    _showAuthRequiredDialog();
                  },
                  child: const Text('Voir l’offre'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineCourseCard(Map<String, dynamic> item) {
    final title = (item['title'] ?? '').toString();
    final category = (item['category'] ?? '').toString();
    final level = (item['level'] ?? '').toString();
    final shortDescription = (item['short_description'] ?? '').toString();
    final rawPrice = item['price'];
    final priceText = rawPrice == null || rawPrice.toString().trim().isEmpty
        ? 'Tarif : à préciser'
        : 'Tarif : ${rawPrice.toString()}';

    String? meta;
    if (category.isNotEmpty && level.isNotEmpty) {
      meta = '$category • $level';
    } else if (category.isNotEmpty) {
      meta = category;
    } else if (level.isNotEmpty) {
      meta = level;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0x80F6A623),
          width: 2,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0A2540),
                ),
              ),
              const SizedBox(height: 4),
              if (meta != null && meta.isNotEmpty) ...[
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              if (shortDescription.isNotEmpty) ...[
                Text(
                  shortDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                priceText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF3275D0),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3275D0),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 32),
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
                  child: const Text('Voir le cours'),
                ),
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0x80F6A623),
          width: 2,
        ),
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
              color: Color(0xFF0A2540),
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
        _parseColor(cfg?['primary_color'] as String?) ?? const Color(0xFF7BC96F);
    final secondaryColor =
        _parseColor(cfg?['secondary_color'] as String?) ?? const Color(0xFFE8F5E9);
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
    final shortTrainingHighlights = landing.shortTrainingHighlights;
    final opportunityHighlights = landing.opportunityHighlights;
    final onlineCourseHighlights = landing.onlineCourseHighlights;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final bool isMobile = width < AppBreakpoints.mobile;

        double heroAspectRatio;
        if (width < 600) {
          heroAspectRatio = 16 / 9;
        } else if (width < 1000) {
          heroAspectRatio = 16 / 7;
        } else {
          heroAspectRatio = 16 / 5;
        }

        final double heroBadgeSpacing = isMobile ? 12.0 : 16.0;
        final double heroTitleSpacing = isMobile ? 8.0 : 10.0;
        final double heroSubtitleSpacing = isMobile ? 14.0 : 18.0;
        final double sectionSpacing = isMobile ? 16.0 : 24.0;
        final double partnersSpacing = isMobile ? 20.0 : 24.0;
        final double bottomSpacing = isMobile ? 16.0 : 24.0;

        final hero = Padding(
          padding: EdgeInsets.fromLTRB(isMobile ? 0 : 16, 4, isMobile ? 0 : 16, 4),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF2E7D32),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10.5),
              child: HeroMediaCarousel(
              items: _heroMediaItems,
              aspectRatio: heroAspectRatio,
              useAspectRatio: true,
              autoplay: true,
              loopVideos: true,
              mutedByDefault: true,
              showControls: true,
              defaultImageDuration: const Duration(seconds: 5),
              overlayBuilder: (context, currentItem) {
                final hasMedia = currentItem != null;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (!hasMedia)
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF7BC96F), Color(0xFFE8F5E9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.45),
                            Colors.black.withOpacity(0.1),
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          isMobile ? 12 : 16,
                          24,
                          isMobile ? 12 : 24,
                        ),
                        child: Align(
                          alignment: isMobile
                              ? Alignment.bottomLeft
                              : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: SingleChildScrollView(
                              reverse: true,
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
                                    onPressed: () => _showSignupChoice(context),
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
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          ),
        );

        return SingleChildScrollView(
          child: Column(
            children: [
              hero,
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
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            const spacing = 10.0;
                            final cardWidth =
                                (constraints.maxWidth - spacing) / 2;
                            return Wrap(
                              spacing: spacing,
                              runSpacing: 10,
                              children: items.asMap().entries.map((entry) {
                                return FadeInUp(
                                  duration: const Duration(milliseconds: 500),
                                  delay: Duration(milliseconds: 150 * entry.key),
                                  child: SizedBox(
                                    width: cardWidth,
                                    child: _buildProgramCard(
                                      entry.value,
                                      gradientIndex: entry.key,
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (shortTrainingHighlights.isNotEmpty) ...[
                SizedBox(height: sectionSpacing),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Formations courtes à venir',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Découvre quelques sessions publiques avant de créer ton compte.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 900;
                          if (isNarrow) {
                            return SizedBox(
                              height: 180,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: shortTrainingHighlights.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final item = shortTrainingHighlights[index];
                                  return SizedBox(
                                    width: 280,
                                    child: _buildShortTrainingCard(item),
                                  );
                                },
                              ),
                            );
                          }

                          final cardWidth = (constraints.maxWidth - 12) / 2;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: shortTrainingHighlights
                                .asMap()
                                .entries
                                .map(
                                  (entry) => FadeInUp(
                                    duration: const Duration(milliseconds: 500),
                                    delay: Duration(milliseconds: 150 * entry.key),
                                    child: SizedBox(
                                      width: cardWidth,
                                      child: _buildShortTrainingCard(entry.value),
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
              if (opportunityHighlights.isNotEmpty) ...[
                SizedBox(height: sectionSpacing),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          _showAuthRequiredDialog();
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7E6),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                '🔥 Top opportunités du moment',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Opportunités à saisir',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Les meilleures occasions pour booster ton parcours : stages, emplois et missions sélectionnés pour toi.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 900;
                          if (isNarrow) {
                            return SizedBox(
                              height: 190,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: opportunityHighlights.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final item = opportunityHighlights[index];
                                  return SizedBox(
                                    width: 280,
                                    child: _buildOpportunityHighlightCard(item),
                                  );
                                },
                              ),
                            );
                          }

                          final cardWidth = (constraints.maxWidth - 12) / 2;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: opportunityHighlights
                                .asMap()
                                .entries
                                .map(
                                  (entry) => FadeInUp(
                                    duration: const Duration(milliseconds: 500),
                                    delay: Duration(milliseconds: 150 * entry.key),
                                    child: SizedBox(
                                      width: cardWidth,
                                      child: _buildOpportunityHighlightCard(entry.value),
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
              if (onlineCourseHighlights.isNotEmpty) ...[
                SizedBox(height: sectionSpacing),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cours en ligne',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Quelques cours à découvrir en libre accès ou sur inscription.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 900;
                          if (isNarrow) {
                            return SizedBox(
                              height: 190,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: onlineCourseHighlights.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final item = onlineCourseHighlights[index];
                                  return SizedBox(
                                    width: 280,
                                    child: _buildOnlineCourseCard(item),
                                  );
                                },
                              ),
                            );
                          }

                          final cardWidth = (constraints.maxWidth - 12) / 2;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: onlineCourseHighlights
                                .asMap()
                                .entries
                                .map(
                                  (entry) => FadeInUp(
                                    duration: const Duration(milliseconds: 500),
                                    delay: Duration(milliseconds: 150 * entry.key),
                                    child: SizedBox(
                                      width: cardWidth,
                                      child: _buildOnlineCourseCard(entry.value),
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
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
                                .asMap()
                                .entries
                                .map((entry) => FadeInUp(
                                      duration: const Duration(milliseconds: 500),
                                      delay: Duration(milliseconds: 150 * entry.key),
                                      child: _buildWhyCard(entry.value, accentColor),
                                    ))
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
                        onPressed: () => _showSignupChoice(context),
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
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, secondaryColor],
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
                              color: Color(0xFF000000),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
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

class _ScaleTapWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _ScaleTapWrapper({required this.child, this.onTap});

  @override
  State<_ScaleTapWrapper> createState() => _ScaleTapWrapperState();
}

class _ScaleTapWrapperState extends State<_ScaleTapWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale = 1.0 - 0.04 * _controller.value;
          return Transform.scale(scale: scale, child: child);
        },
        child: widget.child,
      ),
    );
  }
}
