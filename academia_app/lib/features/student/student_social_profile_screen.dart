import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/student_challenges_provider.dart';
import '../../video/academia_playback_engine.dart';
import '../../widgets/video_overlays_layer.dart';
import '../../widgets/report_content_sheet.dart';
import 'student_profile_screen.dart';

/// TikTok-style social profile screen.
/// Shows avatar, username, bio, website, stats (videos, likes, followers),
/// and a tabbed grid of the user's published videos (Challenges / Créations).
class StudentSocialProfileScreen extends StatefulWidget {
  final String userId;
  final String? displayName;
  final String? avatarUrl;

  const StudentSocialProfileScreen({
    super.key,
    required this.userId,
    this.displayName,
    this.avatarUrl,
  });

  @override
  State<StudentSocialProfileScreen> createState() =>
      _StudentSocialProfileScreenState();
}

class _StudentSocialProfileScreenState
    extends State<StudentSocialProfileScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _userVideos = [];
  Map<String, dynamic>? _publicProfile;
  bool _isLoading = true;
  late final TabController _tabController;

  bool get _isOwnProfile =>
      Supabase.instance.client.auth.currentUser?.id == widget.userId;

  List<Map<String, dynamic>> get _challengeVideos =>
      _userVideos.where((v) => v['video_type'] == 'challenge').toList();

  List<Map<String, dynamic>> get _freeVideos =>
      _userVideos.where((v) => v['video_type'] == 'free').toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final client = Supabase.instance.client;
    final provider = context.read<StudentChallengesProvider>();

    // Load public profile via RPC
    try {
      final resp = await client.rpc(
        'app_get_public_user_profile',
        params: {'p_user_id': widget.userId},
      );
      if (resp is Map<String, dynamic> && resp['success'] == true) {
        _publicProfile = Map<String, dynamic>.from(resp['profile'] as Map);
      }
    } catch (e) {
      debugPrint('[SocialProfile] Error loading public profile: $e');
    }

    // Load videos
    final videos = await provider.loadUserVideos(widget.userId);
    if (!mounted) return;
    setState(() {
      _userVideos = videos;
      _isLoading = false;
    });
  }

  String get _displayName =>
      _publicProfile?['full_name']?.toString() ??
      widget.displayName ??
      'Utilisateur';

  String? get _avatarUrl =>
      _publicProfile?['avatar_url']?.toString() ?? widget.avatarUrl;

  String get _bio => _publicProfile?['bio']?.toString() ?? '';
  String get _websiteUrl => _publicProfile?['website_url']?.toString() ?? '';
  String get _location {
    final city = _publicProfile?['city']?.toString() ?? '';
    final country = _publicProfile?['country']?.toString() ?? '';
    if (city.isNotEmpty && country.isNotEmpty) return '$city, $country';
    if (city.isNotEmpty) return city;
    return country;
  }

  int get _totalLikes => (_publicProfile?['total_likes'] as int?) ?? 0;
  int get _followersCount =>
      (_publicProfile?['followers_count'] as int?) ?? 0;
  int get _followingCount =>
      (_publicProfile?['following_count'] as int?) ?? 0;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final name = _displayName;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final avatar = _avatarUrl;

    return Scaffold(
      backgroundColor: Colors.black,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // ── Header ──
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.only(top: topPad + 8, bottom: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1A1A2E), Colors.black],
                ),
              ),
              child: Column(
                children: [
                  // Back button + report/block
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      if (!_isOwnProfile)
                        IconButton(
                          onPressed: () => UserModerationSheet.show(
                            context,
                            userId: widget.userId,
                            userName: _displayName,
                          ),
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          tooltip: 'Signaler / Bloquer',
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Avatar
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: const Color(0xFF1EA75C),
                    backgroundImage:
                        avatar != null && avatar.isNotEmpty
                            ? NetworkImage(avatar)
                            : null,
                    child: avatar == null || avatar.isEmpty
                        ? Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 10),
                  // Name
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${widget.userId.substring(0, 8)}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                  // Bio
                  if (_bio.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
                      child: Text(
                        _bio,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  // Website
                  if (_websiteUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: GestureDetector(
                        onTap: () {
                          final uri = Uri.tryParse(_websiteUrl);
                          if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                        child: Text(
                          _websiteUrl,
                          style: const TextStyle(
                            color: Color(0xFF4FC3F7),
                            fontSize: 12,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  // Location
                  if (_location.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on, color: Colors.white38, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            _location,
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _StatColumn(count: _followingCount, label: 'Abonnements'),
                      const SizedBox(width: 24),
                      _StatColumn(count: _followersCount, label: 'Abonnés'),
                      const SizedBox(width: 24),
                      _StatColumn(count: _totalLikes, label: 'Likes'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Action buttons
                  if (_isOwnProfile)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const StudentProfileScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit, size: 16, color: Colors.white70),
                      label: const Text('Modifier le profil',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      ),
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Fonctionnalité suivre bientôt disponible'),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1EA75C),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                          ),
                          child: const Text('Suivre'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Messagerie bientôt disponible'),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          child: const Icon(Icons.mail_outline, color: Colors.white70, size: 18),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // ── Tab Bar ──
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF1EA75C),
                indicatorWeight: 2.5,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white38,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.emoji_events_outlined, size: 20),
                    text: 'Challenges (${_challengeVideos.length})',
                  ),
                  Tab(
                    icon: const Icon(Icons.videocam_outlined, size: 20),
                    text: 'Créations (${_freeVideos.length})',
                  ),
                ],
              ),
            ),
          ),
        ],
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF1EA75C)),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildVideoGrid(_challengeVideos),
                  _buildVideoGrid(_freeVideos),
                ],
              ),
      ),
    );
  }

  Widget _buildVideoGrid(List<Map<String, dynamic>> videos) {
    if (videos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off, color: Colors.white38, size: 48),
            SizedBox(height: 12),
            Text(
              'Aucune vidéo publiée',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        childAspectRatio: 9 / 16,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) => _VideoGridTile(video: videos[index]),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverTabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.black, child: _tabBar);
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) => false;
}

class _StatColumn extends StatelessWidget {
  final int count;
  final String label;

  const _StatColumn({required this.count, required this.label});

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatCount(count),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _VideoGridTile extends StatelessWidget {
  final Map<String, dynamic> video;

  const _VideoGridTile({required this.video});

  @override
  Widget build(BuildContext context) {
    final videoUrl = video['video_url']?.toString() ?? '';
    final likesCount =
        video['likes_count'] is int ? video['likes_count'] as int : 0;
    final posterUrl = video['poster_url']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        if (videoUrl.isEmpty) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _FullScreenVideoPreview(
              videoUrl: videoUrl,
              video: video,
            ),
          ),
        );
      },
      child: Container(
        color: const Color(0xFF111111),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (posterUrl.isNotEmpty)
              Image.network(
                posterUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.play_circle_outline,
                      color: Colors.white38, size: 32),
                ),
              )
            else
              const Center(
                child: Icon(Icons.play_circle_outline,
                    color: Colors.white38, size: 32),
              ),
            // Likes overlay
            Positioned(
              bottom: 4,
              left: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite, color: Colors.white, size: 12),
                  const SizedBox(width: 2),
                  Text(
                    '$likesCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullScreenVideoPreview extends StatelessWidget {
  final String videoUrl;
  final Map<String, dynamic> video;

  const _FullScreenVideoPreview({
    required this.videoUrl,
    required this.video,
  });

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? overlays;
    final rawOverlays = video['overlays'] ?? video['layers'];
    if (rawOverlays is Map<String, dynamic>) {
      overlays = Map<String, dynamic>.from(rawOverlays);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AcademiaPlaybackEngine.view(
            url: videoUrl,
            autoplay: true,
          ),
          if (overlays != null && overlays.isNotEmpty)
            VideoOverlaysLayer(overlays: overlays),
        ],
      ),
    );
  }
}
