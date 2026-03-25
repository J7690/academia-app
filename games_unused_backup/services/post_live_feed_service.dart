import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import 'live_arena_service.dart';
import 'quiz_battle_service.dart';

/// Service pour le Post-Live Feed des battles
class PostLiveFeedService {
  static final Map<String, PostLiveFeed> _activeFeeds = {};
  static final Uuid _uuid = Uuid();
  
  /// Créer un Post-Live Feed après un battle
  static Future<String> createPostLiveFeed({
    required String battleId,
    required String videoUrl,
    String? thumbnailUrl,
    String? title,
    String? description,
    List<String>? tags,
    List<BattleHighlight>? highlights,
  }) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecté');
      
      // Vérifier si le battle existe
      final battle = await QuizBattleService.getBattleSession(battleId);
      if (battle == null) throw Exception('Battle non trouvé');
      
      // Créer le feed
      final feedId = _uuid.v4();
      final feed = PostLiveFeed(
        id: feedId,
        battleId: battleId,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl ?? '',
        title: title ?? 'Battle Live Arena - ${battle.gameType}',
        description: description ?? 'Découvrez ce battle économique incroyable !',
        tags: tags ?? ['livearena', 'economics', 'battle', battle.gameType],
        highlights: highlights ?? [],
        viewerCount: 0,
        likeCount: 0,
        commentCount: 0,
        shareCount: 0,
        duration: 0, // À calculer
        fileSize: 0, // À calculer
        status: FeedStatus.processing,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      _activeFeeds[feedId] = feed;
      
      // Enregistrer dans la base
      await Supabase.instance.client
          .from('post_live_feed')
          .insert({
            'id': feedId,
            'battle_id': battleId,
            'video_url': videoUrl,
            'thumbnail_url': thumbnailUrl,
            'title': feed.title,
            'description': feed.description,
            'tags': jsonEncode(feed.tags),
            'highlights': jsonEncode(feed.highlights.map((h) => h.toJson()).toList()),
            'status': 'processing',
          });
      
      // Traiter la vidéo en arrière-plan
      await _processVideo(feedId);
      
      return feedId;
    } catch (e) {
      print('Erreur création Post-Live Feed: $e');
      rethrow;
    }
  }
  
  /// Traiter la vidéo (générer thumbnail, calculer durée, etc.)
  static Future<void> _processVideo(String feedId) async {
    try {
      final feed = _activeFeeds[feedId];
      if (feed == null) return;
      
      // Mettre à jour le statut
      feed.status = FeedStatus.processing;
      await _updateFeedStatus(feedId, 'processing');
      
      // Calculer la durée de la vidéo
      final videoController = VideoPlayerController.networkUrl(Uri.parse(feed.videoUrl));
      await videoController.initialize();
      
      final duration = videoController.value.duration.inSeconds;
      feed.duration = duration;
      
      // Générer une thumbnail si nécessaire
      if (feed.thumbnailUrl.isEmpty) {
        final thumbnailUrl = await _generateThumbnail(feed.videoUrl, duration ~/ 2);
        feed.thumbnailUrl = thumbnailUrl;
        await _updateFeedThumbnail(feedId, thumbnailUrl);
      }
      
      // Calculer la taille du fichier
      final fileSize = await _getVideoFileSize(feed.videoUrl);
      feed.fileSize = fileSize;
      
      // Mettre à jour le statut
      feed.status = FeedStatus.ready;
      await _updateFeedStatus(feedId, 'ready');
      await _updateFeedMetadata(feedId, duration, fileSize);
      
      videoController.dispose();
    } catch (e) {
      print('Erreur traitement vidéo: $e');
      await _updateFeedStatus(feedId, 'failed');
    }
  }
  
  /// Générer une thumbnail
  static Future<String> _generateThumbnail(String videoUrl, int position) async {
    try {
      // Note: Nécessiterait ffmpeg ou une librairie de thumbnail
      // Pour l'instant, retourner une URL par défaut
      return 'https://picsum.photos/seed/${_uuid.v4()}/640/360.jpg';
    } catch (e) {
      print('Erreur génération thumbnail: $e');
      return 'https://picsum.photos/seed/default/640/360.jpg';
    }
  }
  
  /// Obtenir la taille du fichier vidéo
  static Future<int> _getVideoFileSize(String videoUrl) async {
    try {
      final response = await http.head(Uri.parse(videoUrl));
      final contentLength = response.headers['content-length'];
      return contentLength != null ? int.parse(contentLength) : 0;
    } catch (e) {
      print('Erreur taille fichier: $e');
      return 0;
    }
  }
  
  /// Mettre à jour le statut du feed
  static Future<void> _updateFeedStatus(String feedId, String status) async {
    try {
      await Supabase.instance.client
          .from('post_live_feed')
          .update({'status': status})
          .eq('id', feedId);
    } catch (e) {
      print('Erreur mise à jour statut feed: $e');
    }
  }
  
  /// Mettre à jour la thumbnail du feed
  static Future<void> _updateFeedThumbnail(String feedId, String thumbnailUrl) async {
    try {
      await Supabase.instance.client
          .from('post_live_feed')
          .update({'thumbnail_url': thumbnailUrl})
          .eq('id', feedId);
    } catch (e) {
      print('Erreur mise à jour thumbnail: $e');
    }
  }
  
  /// Mettre à jour les métadonnées du feed
  static Future<void> _updateFeedMetadata(String feedId, int duration, int fileSize) async {
    try {
      await Supabase.instance.client
          .from('post_live_feed')
          .update({
            'duration': duration,
            'file_size': fileSize,
          })
          .eq('id', feedId);
    } catch (e) {
      print('Erreur mise à jour métadonnées: $e');
    }
  }
  
  /// Obtenir le Post-Live Feed d'un battle
  static Future<PostLiveFeed?> getPostLiveFeed(String battleId) async {
    try {
      final result = await Supabase.instance.client
          .from('post_live_feed')
          .select()
          .eq('battle_id', battleId)
          .maybeSingle();
      
      if (result != null) {
        return PostLiveFeed.fromJson(result);
      }
      return null;
    } catch (e) {
      print('Erreur récupération Post-Live Feed: $e');
      return null;
    }
  }
  
  /// Obtenir tous les Post-Live Feeds
  static Future<List<PostLiveFeed>> getAllPostLiveFeeds({
    int limit = 20,
    int offset = 0,
    String? sortBy = 'created_at',
    bool descending = true,
  }) async {
    try {
      final query = Supabase.instance.client
          .from('post_live_feed')
          .select()
          .eq('status', 'ready');
      
      // Ajouter le tri
      if (sortBy != null) {
        query.order(sortBy, ascending: !descending);
      }
      
      // Ajouter la pagination
      query.range(offset, offset + limit - 1);
      
      final result = await query;
      return result.map((json) => PostLiveFeed.fromJson(json)).toList();
    } catch (e) {
      print('Erreur récupération tous les feeds: $e');
      return [];
    }
  }
  
  /// Aimer un Post-Live Feed
  static Future<void> likePostLiveFeed(String feedId) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecté');
      
      // Vérifier si l'utilisateur a déjà aimé
      final existingLike = await Supabase.instance.client
          .from('share_analytics')
          .select()
          .eq('share_id', feedId)
          .eq('user_id', userId)
          .eq('share_type', 'like')
          .maybeSingle();
      
      if (existingLike == null) {
        // Ajouter le like
        await Supabase.instance.client
            .from('share_analytics')
            .insert({
              'share_id': feedId,
              'share_type': 'like',
              'user_id': userId,
              'platform': 'post_live',
            });
        
        // Mettre à jour le compteur
        await Supabase.instance.client
            .rpc('increment_post_live_feed_like_count', params: {'feed_id': feedId});
      }
    } catch (e) {
      print('Erreur like Post-Live Feed: $e');
      rethrow;
    }
  }
  
  /// Commenter un Post-Live Feed
  static Future<void> commentPostLiveFeed(String feedId, String comment) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecté');
      
      // Ajouter le commentaire
      await Supabase.instance.client
          .from('share_analytics')
          .insert({
            'share_id': feedId,
            'share_type': 'comment',
            'user_id': userId,
            'platform': 'post_live',
            'content': comment,
          });
      
      // Mettre à jour le compteur
      await Supabase.instance.client
          .rpc('increment_post_live_feed_comment_count', params: {'feed_id': feedId});
    } catch (e) {
      print('Erreur commentaire Post-Live Feed: $e');
      rethrow;
    }
  }
  
  /// Partager un Post-Live Feed
  static Future<void> sharePostLiveFeed(String feedId, String platform) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecté');
      
      // Ajouter le partage
      await Supabase.instance.client
          .from('share_analytics')
          .insert({
            'share_id': feedId,
            'share_type': 'share',
            'user_id': userId,
            'platform': platform,
          });
      
      // Mettre à jour le compteur
      await Supabase.instance.client
          .rpc('increment_post_live_feed_share_count', params: {'feed_id': feedId});
    } catch (e) {
      print('Erreur partage Post-Live Feed: $e');
      rethrow;
    }
  }
  
  /// Obtenir les analytics d'un Post-Live Feed
  static Future<PostLiveFeedAnalytics> getPostLiveFeedAnalytics(String feedId) async {
    try {
      // Obtenir les compteurs
      final feed = await getPostLiveFeed(feedId);
      if (feed == null) throw Exception('Feed non trouvé');
      
      // Obtenir les analytics détaillés
      final result = await Supabase.instance.client
          .from('share_analytics')
          .select()
          .eq('share_id', feedId);
      
      final analytics = result.map((json) => ShareAnalytics.fromJson(json)).toList();
      
      return PostLiveFeedAnalytics(
        feedId: feedId,
        viewerCount: feed.viewerCount,
        likeCount: feed.likeCount,
        commentCount: feed.commentCount,
        shareCount: feed.shareCount,
        engagementRate: _calculateEngagementRate(feed.viewerCount, feed.likeCount, feed.commentCount, feed.shareCount),
        analytics: analytics,
      );
    } catch (e) {
      print('Erreur analytics Post-Live Feed: $e');
      rethrow;
    }
  }
  
  /// Calculer le taux d'engagement
  static double _calculateEngagementRate(int viewers, int likes, int comments, int shares) {
    if (viewers == 0) return 0.0;
    
    final totalEngagement = likes + comments + shares;
    return (totalEngagement / viewers) * 100;
  }
  
  /// Obtenir les Post-Live Feeds tendance
  static Future<List<PostLiveFeed>> getTrendingPostLiveFeeds({int limit = 10}) async {
    try {
      final result = await Supabase.instance.client
          .from('post_live_feed')
          .select()
          .eq('status', 'ready')
          .order('viewer_count', ascending: false)
          .order('like_count', ascending: false)
          .limit(limit);
      
      return result.map((json) => PostLiveFeed.fromJson(json)).toList();
    } catch (e) {
      print('Erreur feeds tendance: $e');
      return [];
    }
  }
  
  /// Rechercher des Post-Live Feeds
  static Future<List<PostLiveFeed>> searchPostLiveFeeds(String query, {int limit = 20}) async {
    try {
      final result = await Supabase.instance.client
          .from('post_live_feed')
          .select()
          .eq('status', 'ready')
          .or('title.ilike.%$query%,description.ilike.%$query%')
          .order('created_at', ascending: false)
          .limit(limit);
      
      return result.map((json) => PostLiveFeed.fromJson(json)).toList();
    } catch (e) {
      print('Erreur recherche feeds: $e');
      return [];
    }
  }
  
  /// Supprimer un Post-Live Feed
  static Future<void> deletePostLiveFeed(String feedId) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecté');
      
      // Vérifier que l'utilisateur est le propriétaire
      final feed = await getPostLiveFeed(feedId);
      if (feed == null) throw Exception('Feed non trouvé');
      
      // Supprimer le feed
      await Supabase.instance.client
          .from('post_live_feed')
          .delete()
          .eq('id', feedId);
      
      // Supprimer les analytics associés
      await Supabase.instance.client
          .from('share_analytics')
          .delete()
          .eq('share_id', feedId);
      
      // Retirer de la mémoire cache
      _activeFeeds.remove(feedId);
    } catch (e) {
      print('Erreur suppression feed: $e');
      rethrow;
    }
  }
}

/// Post-Live Feed
class PostLiveFeed {
  final String id;
  final String battleId;
  final String videoUrl;
  final String thumbnailUrl;
  final String title;
  final String description;
  final List<String> tags;
  final List<BattleHighlight> highlights;
  final int viewerCount;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int duration;
  final int fileSize;
  final FeedStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  PostLiveFeed({
    required this.id,
    required this.battleId,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.title,
    required this.description,
    required this.tags,
    required this.highlights,
    required this.viewerCount,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.duration,
    required this.fileSize,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory PostLiveFeed.fromJson(Map<String, dynamic> json) {
    return PostLiveFeed(
      id: json['id'],
      battleId: json['battle_id'],
      videoUrl: json['video_url'],
      thumbnailUrl: json['thumbnail_url'] ?? '',
      title: json['title'],
      description: json['description'],
      tags: List<String>.from(jsonDecode(json['tags'] ?? '[]')),
      highlights: (jsonDecode(json['highlights'] ?? '[]') as List)
          .map((h) => BattleHighlight.fromJson(h))
          .toList(),
      viewerCount: json['viewer_count'] ?? 0,
      likeCount: json['like_count'] ?? 0,
      commentCount: json['comment_count'] ?? 0,
      shareCount: json['share_count'] ?? 0,
      duration: json['duration'] ?? 0,
      fileSize: json['file_size'] ?? 0,
      status: FeedStatus.values.firstWhere(
        (s) => s.toString() == 'FeedStatus.${json['status']}',
        orElse: () => FeedStatus.processing,
      ),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

/// Moment fort du battle
class BattleHighlight {
  final String type;
  final double timestamp;
  final String description;
  final String? thumbnailUrl;
  
  BattleHighlight({
    required this.type,
    required this.timestamp,
    required this.description,
    this.thumbnailUrl,
  });
  
  factory BattleHighlight.fromJson(Map<String, dynamic> json) {
    return BattleHighlight(
      type: json['type'],
      timestamp: json['timestamp']?.toDouble() ?? 0.0,
      description: json['description'],
      thumbnailUrl: json['thumbnail_url'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'timestamp': timestamp,
      'description': description,
      'thumbnail_url': thumbnailUrl,
    };
  }
}

/// Statut du feed
enum FeedStatus {
  processing,
  ready,
  failed,
}

/// Analytics du Post-Live Feed
class PostLiveFeedAnalytics {
  final String feedId;
  final int viewerCount;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final double engagementRate;
  final List<ShareAnalytics> analytics;
  
  PostLiveFeedAnalytics({
    required this.feedId,
    required this.viewerCount,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.engagementRate,
    required this.analytics,
  });
}

/// Analytics de partage
class ShareAnalytics {
  final String id;
  final String shareId;
  final String shareType;
  final String userId;
  final String platform;
  final String? content;
  final DateTime createdAt;
  
  ShareAnalytics({
    required this.id,
    required this.shareId,
    required this.shareType,
    required this.userId,
    required this.platform,
    this.content,
    required this.createdAt,
  });
  
  factory ShareAnalytics.fromJson(Map<String, dynamic> json) {
    return ShareAnalytics(
      id: json['id'],
      shareId: json['share_id'],
      shareType: json['share_type'],
      userId: json['user_id'],
      platform: json['platform'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
