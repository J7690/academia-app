import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../providers/landing_content_provider.dart';
import '../../providers/student_offers_provider.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class AuthLandingScreen extends StatelessWidget {
  const AuthLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        title: const Text('Academia'),
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

  late final ScrollController _tickerController;
  Timer? _tickerTimer;

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
      final hasCustomVideo =
          (urlFromConfig != null && urlFromConfig.isNotEmpty);

      _startTicker();

      if (hasCustomVideo && urlFromConfig != null) {
        unawaited(_initVideo(urlFromConfig));
      }
    });
  }

  Future<void> _initVideo(String url) async {
    _videoController?.dispose();
    _videoReady = false;
    if (mounted) {
      setState(() {});
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    await controller.initialize();
    controller
      ..setLooping(true)
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
  }

  void _startTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_tickerController.hasClients) return;
      final position = _tickerController.position;
      if (!position.haveDimensions) return;
      final maxScroll = position.maxScrollExtent;
      if (maxScroll <= 0) return;
      double next = _tickerController.offset + 180;
      if (next >= maxScroll) {
        next = 0;
      }
      _tickerController.animateTo(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
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
                          child: _videoReady && _videoController != null
                              ? FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: _videoController!.value.size.width,
                                    height: _videoController!.value.size.height,
                                    child: VideoPlayer(_videoController!),
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [primaryColor, secondaryColor],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                ),
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  primaryColor.withOpacity(0.65),
                                  secondaryColor.withOpacity(0.5),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
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
                          return Column(
                            children: items
                                .map(
                                  (p) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _buildProgramCard(p),
                                  ),
                                )
                                .toList(),
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
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: whyCards
                            .map((card) => _buildWhyCard(card, accentColor))
                            .toList(),
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
                    colors: [Color(0xFFFF3B30), Color(0xFFE11D48)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: SizedBox(
                  height: 32,
                  child: ListView.builder(
                    controller: _tickerController,
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    itemCount: () {
                      final baseCount = announcements.isNotEmpty
                          ? announcements.length
                          : _fallbackAnnouncements.length;
                      if (baseCount <= 0) return 0;
                      return baseCount * 4;
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
                              color: Colors.white,
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
