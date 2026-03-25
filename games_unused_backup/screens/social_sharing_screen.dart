import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../services/tiktok_sharing_service.dart';
import '../services/post_live_feed_service.dart';
import '../services/live_arena_service.dart';
import '../widgets/battle_video_player.dart';
import '../widgets/social_share_button.dart';

/// Écran de partage social des battles Live Arena
class SocialSharingScreen extends StatefulWidget {
  final String battleId;
  final String? videoPath;
  
  const SocialSharingScreen({
    Key? key,
    required this.battleId,
    this.videoPath,
  }) : super(key: key);
  
  @override
  _SocialSharingScreenState createState() => _SocialSharingScreenState();
}

class _SocialSharingScreenState extends State<SocialSharingScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late VideoPlayerController _videoController;
  
  bool _isLoading = true;
  bool _isTikTokConnected = false;
  String? _currentShareSession;
  PostLiveFeed? _postLiveFeed;
  List<TikTokShare> _tikTokShares = [];
  List<BattleClip> _battleClips = [];
  
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<String> _selectedHashtags = [];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _videoController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  Future<void> _initializeData() async {
    try {
      // Vérifier la connexion TikTok
      _isTikTokConnected = await TikTokSharingService.isTikTokConnected();
      
      // Charger les informations du battle
      if (widget.videoPath != null) {
        _videoController = VideoPlayerController.file(File(widget.videoPath!));
        await _videoController.initialize();
      }
      
      // Charger le Post-Live Feed
      _postLiveFeed = await PostLiveFeedService.getPostLiveFeed(widget.battleId);
      
      // Charger les partages TikTok
      _tikTokShares = await TikTokSharingService.getUserTikTokShares();
      
      // Charger les clips du battle
      _battleClips = await TikTokSharingService.getBattleClips(widget.battleId);
      
      // Initialiser les champs
      _titleController.text = _postLiveFeed?.title ?? 'Battle Live Arena';
      _descriptionController.text = _postLiveFeed?.description ?? 'Découvrez ce battle économique !';
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur initialisation: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Partage Social',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00D4FF),
          labelColor: const Color(0xFF00D4FF),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'TikTok'),
            Tab(text: 'Post-Live'),
            Tab(text: 'Clips'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D4FF)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTikTokTab(),
                _buildPostLiveTab(),
                _buildClipsTab(),
              ],
            ),
    );
  }
  
  Widget _buildTikTokTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statut de connexion TikTok
          _buildTikTokConnectionStatus(),
          const SizedBox(height: 20),
          
          // Aperçu vidéo
          if (widget.videoPath != null) _buildVideoPreview(),
          const SizedBox(height: 20),
          
          // Formulaire de partage
          _buildShareForm(),
          const SizedBox(height: 20),
          
          // Boutons de partage
          _buildShareButtons(),
          const SizedBox(height: 20),
          
          // Historique des partages
          _buildTikTokShareHistory(),
        ],
      ),
    );
  }
  
  Widget _buildTikTokConnectionStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            _isTikTokConnected ? Icons.check_circle : Icons.warning,
            color: _isTikTokConnected ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isTikTokConnected ? 'Connecté à TikTok' : 'Non connecté à TikTok',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (!_isTikTokConnected)
            ElevatedButton(
              onPressed: _connectTikTok,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D4FF),
                foregroundColor: Colors.black,
              ),
              child: const Text('Se connecter'),
            ),
        ],
      ),
    );
  }
  
  Widget _buildVideoPreview() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BattleVideoPlayer(
          controller: _videoController,
          autoPlay: false,
          showControls: true,
        ),
      ),
    );
  }
  
  Widget _buildShareForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre
        TextField(
          controller: _titleController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Titre',
            labelStyle: const TextStyle(color: Colors.white54),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF00D4FF)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Description
        TextField(
          controller: _descriptionController,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Description',
            labelStyle: const TextStyle(color: Colors.white54),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF00D4FF)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Hashtags
        _buildHashtagSelector(),
      ],
    );
  }
  
  Widget _buildHashtagSelector() {
    final availableHashtags = [
      '#academia',
      '#livearena',
      '#economics',
      '#battle',
      '#education',
      '#quiz',
      '#game',
      '#learn',
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hashtags',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableHashtags.map((hashtag) {
            final isSelected = _selectedHashtags.contains(hashtag);
            return FilterChip(
              label: Text(hashtag),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedHashtags.add(hashtag);
                  } else {
                    _selectedHashtags.remove(hashtag);
                  }
                });
              },
              backgroundColor: Colors.white.withOpacity(0.1),
              selectedColor: const Color(0xFF00D4FF).withOpacity(0.3),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFF00D4FF) : Colors.white,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
  
  Widget _buildShareButtons() {
    return Column(
      children: [
        // Bouton principal TikTok
        SocialShareButton(
          icon: '🎵',
          label: 'Partager sur TikTok',
          color: const Color(0xFF000000),
          onPressed: _isTikTokConnected ? _shareToTikTok : null,
        ),
        const SizedBox(height: 12),
        
        // Autres plateformes
        Row(
          children: [
            Expanded(
              child: SocialShareButton(
                icon: '📷',
                label: 'Instagram',
                color: const Color(0xFFE4405F),
                onPressed: _shareToInstagram,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SocialShareButton(
                icon: '📘',
                label: 'Facebook',
                color: const Color(0xFF1877F2),
                onPressed: _shareToFacebook,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildTikTokShareHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Partages récents',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ..._tikTokShares.take(3).map((share) => _buildTikTokShareItem(share)),
      ],
    );
  }
  
  Widget _buildTikTokShareItem(TikTokShare share) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Thumbnail
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.black,
            ),
            child: share.thumbnailUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: share.thumbnailUrl,
                    fit: BoxFit.cover,
                  )
                : const Icon(Icons.play_circle, color: Colors.white54),
          ),
          const SizedBox(width: 12),
          
          // Informations
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  share.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  share.description,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: Colors.white54,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(share.createdAt),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Statut
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(share.status),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getStatusText(share.status),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPostLiveTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statut Post-Live Feed
          _buildPostLiveStatus(),
          const SizedBox(height: 20),
          
          // Aperçu du feed
          if (_postLiveFeed != null) _buildPostLiveFeedPreview(),
          const SizedBox(height: 20),
          
          // Actions
          if (_postLiveFeed != null) _buildPostLiveActions(),
          const SizedBox(height: 20),
          
          // Analytics
          if (_postLiveFeed != null) _buildPostLiveAnalytics(),
        ],
      ),
    );
  }
  
  Widget _buildPostLiveStatus() {
    if (_postLiveFeed == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.video_library,
              color: Color(0xFF00D4FF),
              size: 48,
            ),
            SizedBox(height: 12),
            Text(
              'Aucun Post-Live Feed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Créez un Post-Live Feed pour partager votre battle',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Post-Live Feed actif',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(_postLiveFeed!.createdAt),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPostLiveFeedPreview() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black,
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              color: Colors.black,
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: _postLiveFeed!.thumbnailUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: _postLiveFeed!.thumbnailUrl,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.black,
                      child: const Center(
                        child: Icon(
                          Icons.play_circle,
                          color: Colors.white54,
                          size: 48,
                        ),
                      ),
                    ),
            ),
          ),
          
          // Informations
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _postLiveFeed!.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _postLiveFeed!.description,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Tags
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _postLiveFeed!.tags.map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D4FF).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        color: Color(0xFF00D4FF),
                        fontSize: 12,
                      ),
                    ),
                  )).toList(),
                ),
                
                const SizedBox(height: 12),
                
                // Statistiques
                Row(
                  children: [
                    _buildStatItem('👁️', '${_postLiveFeed!.viewerCount}'),
                    const SizedBox(width: 16),
                    _buildStatItem('❤️', '${_postLiveFeed!.likeCount}'),
                    const SizedBox(width: 16),
                    _buildStatItem('💬', '${_postLiveFeed!.commentCount}'),
                    const SizedBox(width: 16),
                    _buildStatItem('🔗', '${_postLiveFeed!.shareCount}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(String icon, String count) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 4),
        Text(
          count,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  
  Widget _buildPostLiveActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => PostLiveFeedService.likePostLiveFeed(_postLiveFeed!.id),
                icon: const Icon(Icons.favorite, color: Colors.red),
                label: const Text('Like'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showCommentDialog,
                icon: const Icon(Icons.comment, color: Color(0xFF00D4FF)),
                label: const Text('Commenter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SocialShareButton(
          icon: '🔗',
          label: 'Partager',
          color: const Color(0xFF00D4FF),
          onPressed: _sharePostLiveFeed,
        ),
      ],
    );
  }
  
  Widget _buildPostLiveAnalytics() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analytics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildAnalyticsRow('Vues', '${_postLiveFeed!.viewerCount}', Icons.visibility),
          _buildAnalyticsRow('Likes', '${_postLiveFeed!.likeCount}', Icons.favorite),
          _buildAnalyticsRow('Commentaires', '${_postLiveFeed!.commentCount}', Icons.comment),
          _buildAnalyticsRow('Partages', '${_postLiveFeed!.shareCount}', Icons.share),
          _buildAnalyticsRow('Engagement', '${_calculateEngagementRate().toStringAsFixed(1)}%', Icons.trending_up),
        ],
      ),
    );
  }
  
  Widget _buildAnalyticsRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00D4FF), size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildClipsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bouton créer un clip
          ElevatedButton.icon(
            onPressed: _createBattleClip,
            icon: const Icon(Icons.cut, color: Colors.black),
            label: const Text('Créer un clip'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D4FF),
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 20),
          
          // Liste des clips
          if (_battleClips.isEmpty)
            const Center(
              child: Text(
                'Aucun clip disponible',
                style: TextStyle(color: Colors.white54),
              ),
            )
          else
            ..._battleClips.map((clip) => _buildBattleClipItem(clip)),
        ],
      ),
    );
  }
  
  Widget _buildBattleClipItem(BattleClip clip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          Container(
            height: 120,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              color: Colors.black,
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: clip.thumbnailUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: clip.thumbnailUrl,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.black,
                      child: const Center(
                        child: Icon(
                          Icons.play_circle,
                          color: Colors.white54,
                          size: 32,
                        ),
                      ),
                    ),
            ),
          ),
          
          // Informations
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clip.description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.white54,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${clip.startTime}s - ${clip.endTime}s',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    if (clip.isHighlight)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Highlight',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      clip.category,
                      style: const TextStyle(
                        color: Color(0xFF00D4FF),
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.white54),
                      onPressed: () => _shareClip(clip),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Méthodes utilitaires
  
  Future<void> _connectTikTok() async {
    try {
      final authUrl = await TikTokSharingService.authenticateTikTok();
      if (authUrl != null) {
        // Ouvrir l'URL dans le navigateur
        // Note: Utiliser url_launcher
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Redirection vers TikTok...'),
            backgroundColor: Color(0xFF00D4FF),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur connexion TikTok: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _shareToTikTok() async {
    if (widget.videoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune vidéo disponible'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      setState(() {
        _isLoading = true;
      });
      
      final sessionId = await TikTokSharingService.prepareTikTokShare(
        battleId: widget.battleId,
        videoPath: widget.videoPath!,
        title: _titleController.text,
        description: _descriptionController.text,
        hashtags: _selectedHashtags,
      );
      
      await TikTokSharingService.uploadTikTokVideo(sessionId);
      await TikTokSharingService.publishTikTokVideo(sessionId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vidéo partagée sur TikTok !'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Recharger les partages
      _tikTokShares = await TikTokSharingService.getUserTikTokShares();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur partage TikTok: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _shareToInstagram() async {
    // Implémentation Instagram
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Partage Instagram bientôt disponible !'),
        backgroundColor: Color(0xFF00D4FF),
      ),
    );
  }
  
  Future<void> _shareToFacebook() async {
    // Implémentation Facebook
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Partage Facebook bientôt disponible !'),
        backgroundColor: Color(0xFF00D4FF),
      ),
    );
  }
  
  Future<void> _sharePostLiveFeed() async {
    try {
      await Share.share(
        '${_postLiveFeed!.title}\n${_postLiveFeed!.description}\n\nDécouvrez sur Academia !',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur partage: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _showCommentDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text(
          'Ajouter un commentaire',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Votre commentaire...',
            hintStyle: const TextStyle(color: Colors.white54),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Annuler',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await PostLiveFeedService.commentPostLiveFeed(
                _postLiveFeed!.id,
                controller.text,
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Commentaire ajouté !'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D4FF),
              foregroundColor: Colors.black,
            ),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _createBattleClip() async {
    // Implémentation création de clip
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Création de clips bientôt disponible !'),
        backgroundColor: Color(0xFF00D4FF),
      ),
    );
  }
  
  Future<void> _shareClip(BattleClip clip) async {
    try {
      await Share.share(
        'Découvrez ce clip de battle Live Arena !\n${clip.description}',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur partage clip: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  double _calculateEngagementRate() {
    if (_postLiveFeed!.viewerCount == 0) return 0.0;
    final totalEngagement = _postLiveFeed!.likeCount + _postLiveFeed!.commentCount + _postLiveFeed!.shareCount;
    return (totalEngagement / _postLiveFeed!.viewerCount) * 100;
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}j';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}min';
    } else {
      return 'maintenant';
    }
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'published':
        return Colors.green;
      case 'processing':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  String _getStatusText(String status) {
    switch (status) {
      case 'published':
        return 'Publié';
      case 'processing':
        return 'En cours';
      case 'failed':
        return 'Échec';
      default:
        return status;
    }
  }
}
