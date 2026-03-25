import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Service pour le partage TikTok des battles Live Arena
class TikTokSharingService {
  static const String _tiktokApiBaseUrl = 'https://open-api.tiktok.com';
  static const String _redirectUri = 'academia://tiktok-callback';
  static const String _scope = 'user.info.basic,video.list';
  
  static final Map<String, TikTokShareSession> _activeSessions = {};
  static final Uuid _uuid = Uuid();
  
  /// Initialiser le SDK TikTok
  static Future<bool> initializeTikTokSDK() async {
    try {
      // Configuration du SDK TikTok
      // Note: Les clés API doivent être configurées dans les variables d'environnement
      return true;
    } catch (e) {
      print('Erreur initialisation TikTok SDK: $e');
      return false;
    }
  }
  
  /// Authentifier l'utilisateur sur TikTok
  static Future<String?> authenticateTikTok() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return null;
      
      // Générer l'URL d'authentification TikTok
      final authUrl = '$_tiktokApiBaseUrl/oauth/authorize?' +
          'client_key=TIKTOK_CLIENT_KEY&' +
          'response_type=code&' +
          'scope=$_scope&' +
          'redirect_uri=$_redirectUri&' +
          'state=${_uuid.v4()}';
      
      // Ouvrir l'URL dans le navigateur
      // Note: Utiliser url_launcher pour ouvrir le navigateur
      
      return authUrl;
    } catch (e) {
      print('Erreur authentification TikTok: $e');
      return null;
    }
  }
  
  /// Traiter le callback TikTok
  static Future<bool> handleTikTokCallback(String code, String state) async {
    try {
      // Échanger le code contre un access token
      final response = await http.post(
        Uri.parse('$_tiktokApiBaseUrl/oauth/access_token/'),
        body: {
          'client_key': 'TIKTOK_CLIENT_KEY',
          'client_secret': 'TIKTOK_CLIENT_SECRET',
          'code': code,
          'grant_type': 'authorization_code',
          'redirect_uri': _redirectUri,
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final accessToken = data['access_token'];
        final refreshToken = data['refresh_token'];
        final expiresIn = data['expires_in'];
        
        // Sauvegarder les tokens
        await _saveTikTokTokens(accessToken, refreshToken, expiresIn);
        return true;
      } else {
        print('Erreur token TikTok: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Erreur callback TikTok: $e');
      return false;
    }
  }
  
  /// Sauvegarder les tokens TikTok
  static Future<void> _saveTikTokTokens(String accessToken, String refreshToken, int expiresIn) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      
      final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
      
      await Supabase.instance.client
          .from('social_media_links')
          .upsert({
            'user_id': userId,
            'platform': 'tiktok',
            'access_token': accessToken,
            'refresh_token': refreshToken,
            'expires_at': expiresAt.toIso8601String(),
            'is_active': true,
          }, onConflict: 'user_id,platform');
    } catch (e) {
      print('Erreur sauvegarde tokens TikTok: $e');
    }
  }
  
  /// Vérifier si l'utilisateur est connecté à TikTok
  static Future<bool> isTikTokConnected() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return false;
      
      final result = await Supabase.instance.client
          .from('social_media_links')
          .select()
          .eq('user_id', userId)
          .eq('platform', 'tiktok')
          .eq('is_active', true)
          .maybeSingle();
      
      if (result != null) {
        final expiresAt = DateTime.parse(result['expires_at']);
        return DateTime.now().isBefore(expiresAt);
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  /// Préparer le partage TikTok d'un battle
  static Future<String> prepareTikTokShare({
    required String battleId,
    required String videoPath,
    String? title,
    String? description,
    List<String>? hashtags,
  }) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecté');
      
      // Vérifier la connexion TikTok
      if (!await isTikTokConnected()) {
        throw Exception('Non connecté à TikTok');
      }
      
      // Créer une session de partage
      final sessionId = _uuid.v4();
      final session = TikTokShareSession(
        id: sessionId,
        userId: userId,
        battleId: battleId,
        videoPath: videoPath,
        title: title ?? 'Battle Live Arena - Academia',
        description: description ?? 'Découvrez ce battle économique incroyable !',
        hashtags: hashtags ?? ['academia', 'livearena', 'economics', 'battle'],
        status: ShareStatus.preparing,
        createdAt: DateTime.now(),
      );
      
      _activeSessions[sessionId] = session;
      
      // Enregistrer dans la base
      await Supabase.instance.client
          .from('tiktok_shares')
          .insert({
            'id': sessionId,
            'user_id': userId,
            'battle_id': battleId,
            'video_url': videoPath,
            'title': session.title,
            'description': session.description,
            'hashtags': jsonEncode(session.hashtags),
            'share_token': _uuid.v4(),
            'status': 'preparing',
          });
      
      return sessionId;
    } catch (e) {
      print('Erreur préparation partage TikTok: $e');
      rethrow;
    }
  }
  
  /// Uploader la vidéo vers TikTok
  static Future<void> uploadTikTokVideo(String sessionId) async {
    try {
      final session = _activeSessions[sessionId];
      if (session == null) throw Exception('Session non trouvée');
      
      // Mettre à jour le statut
      session.status = ShareStatus.uploading;
      await _updateSessionStatus(sessionId, 'uploading');
      
      // Préparer le fichier vidéo
      final videoFile = File(session.videoPath);
      if (!await videoFile.exists()) {
        throw Exception('Fichier vidéo non trouvé');
      }
      
      // Obtenir les tokens TikTok
      final tokens = await _getTikTokTokens();
      if (tokens == null) throw Exception('Tokens TikTok non disponibles');
      
      // Uploader la vidéo
      final uploadUrl = await _getTikTokUploadUrl(tokens['accessToken']!);
      final videoBytes = await videoFile.readAsBytes();
      
      final uploadResponse = await http.put(
        Uri.parse(uploadUrl),
        headers: {
          'Authorization': 'Bearer ${tokens['accessToken']!}',
          'Content-Type': 'video/mp4',
        },
        body: videoBytes,
      );
      
      if (uploadResponse.statusCode == 200) {
        final uploadData = jsonDecode(uploadResponse.body);
        final videoId = uploadData['video_id'];
        
        // Mettre à jour la session
        session.tiktokVideoId = videoId;
        session.status = ShareStatus.uploaded;
        await _updateSessionStatus(sessionId, 'uploaded');
        await _updateSessionVideoId(sessionId, videoId);
      } else {
        throw Exception('Erreur upload TikTok: ${uploadResponse.body}');
      }
    } catch (e) {
      print('Erreur upload TikTok: $e');
      await _updateSessionStatus(sessionId, 'failed');
      rethrow;
    }
  }
  
  /// Publier la vidéo sur TikTok
  static Future<void> publishTikTokVideo(String sessionId) async {
    try {
      final session = _activeSessions[sessionId];
      if (session == null) throw Exception('Session non trouvée');
      
      if (session.tiktokVideoId == null) {
        throw Exception('Vidéo non uploadée');
      }
      
      // Mettre à jour le statut
      session.status = ShareStatus.publishing;
      await _updateSessionStatus(sessionId, 'publishing');
      
      // Obtenir les tokens TikTok
      final tokens = await _getTikTokTokens();
      if (tokens == null) throw Exception('Tokens TikTok non disponibles');
      
      // Préparer les métadonnées
      final metadata = {
        'video_id': session.tiktokVideoId,
        'title': session.title,
        'description': session.description,
        'hashtags': session.hashtags.join(','),
        'privacy_level': 'public',
      };
      
      // Publier la vidéo
      final publishResponse = await http.post(
        Uri.parse('$_tiktokApiBaseUrl/video/publish/'),
        headers: {
          'Authorization': 'Bearer ${tokens['accessToken']}',
          'Content-Type': 'application/json',
        },
        body: json.encode(metadata),
      );
      
      if (publishResponse.statusCode == 200) {
        final publishData = json.decode(publishResponse.body);
        final videoUrl = publishData['video_url'];
        
        // Mettre à jour la session
        session.status = ShareStatus.published;
        session.tiktokVideoUrl = videoUrl;
        await _updateSessionStatus(sessionId, 'published');
        await _updateSessionVideoUrl(sessionId, videoUrl);
        
        // Enregistrer les analytics
        await _recordShareAnalytics(sessionId, 'tiktok', session.userId);
      } else {
        throw Exception('Erreur publication TikTok: ${publishResponse.body}');
      }
    } catch (e) {
      print('Erreur publication TikTok: $e');
      await _updateSessionStatus(sessionId, 'failed');
      rethrow;
    }
  }
  
  /// Obtenir l'URL d'upload TikTok
  static Future<String> _getTikTokUploadUrl(String accessToken) async {
    try {
      final response = await http.post(
        Uri.parse('$_tiktokApiBaseUrl/video/upload/'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'file_size': 100 * 1024 * 1024, // 100MB max
          'file_type': 'video/mp4',
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['upload_url'];
      } else {
        throw Exception('Erreur URL upload: ${response.body}');
      }
    } catch (e) {
      print('Erreur URL upload TikTok: $e');
      rethrow;
    }
  }
  
  /// Obtenir les tokens TikTok
  static Future<Map<String, String>?> _getTikTokTokens() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return null;
      
      final result = await Supabase.instance.client
          .from('social_media_links')
          .select()
          .eq('user_id', userId)
          .eq('platform', 'tiktok')
          .eq('is_active', true)
          .maybeSingle();
      
      if (result != null) {
        return {
          'accessToken': result['access_token'],
          'refreshToken': result['refresh_token'],
        };
      }
      return null;
    } catch (e) {
      print('Erreur récupération tokens TikTok: $e');
      return null;
    }
  }
  
  /// Mettre à jour le statut de la session
  static Future<void> _updateSessionStatus(String sessionId, String status) async {
    try {
      await Supabase.instance.client
          .from('tiktok_shares')
          .update({'status': status})
          .eq('id', sessionId);
    } catch (e) {
      print('Erreur mise à jour statut: $e');
    }
  }
  
  /// Mettre à jour l'ID vidéo TikTok
  static Future<void> _updateSessionVideoId(String sessionId, String videoId) async {
    try {
      await Supabase.instance.client
          .from('tiktok_shares')
          .update({'tiktok_video_id': videoId})
          .eq('id', sessionId);
    } catch (e) {
      print('Erreur mise à jour video ID: $e');
    }
  }
  
  /// Mettre à jour l'URL vidéo TikTok
  static Future<void> _updateSessionVideoUrl(String sessionId, String videoUrl) async {
    try {
      await Supabase.instance.client
          .from('tiktok_shares')
          .update({'video_url': videoUrl})
          .eq('id', sessionId);
    } catch (e) {
      print('Erreur mise à jour video URL: $e');
    }
  }
  
  /// Enregistrer les analytics de partage
  static Future<void> _recordShareAnalytics(String shareId, String platform, String userId) async {
    try {
      await Supabase.instance.client
          .from('share_analytics')
          .insert({
            'share_id': shareId,
            'share_type': platform,
            'user_id': userId,
            'platform': platform,
            'created_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      print('Erreur enregistrement analytics: $e');
    }
  }
  
  /// Obtenir les partages TikTok d'un utilisateur
  static Future<List<TikTokShare>> getUserTikTokShares() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return [];
      
      final result = await Supabase.instance.client
          .from('tiktok_shares')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      return result.map((json) => TikTokShare.fromJson(json)).toList();
    } catch (e) {
      print('Erreur récupération partages TikTok: $e');
      return [];
    }
  }
  
  /// Créer un clip court d'un battle
  static Future<String> createBattleClip({
    required String battleId,
    required String videoPath,
    required double startTime,
    required double endTime,
    String? description,
    bool isHighlight = false,
    String category = 'general',
  }) async {
    try {
      final clipId = _uuid.v4();
      
      // Créer le clip (simplifié - nécessiterait ffmpeg pour le découpage réel)
      await Supabase.instance.client
          .from('battle_clips')
          .insert({
            'id': clipId,
            'battle_id': battleId,
            'video_url': videoPath,
            'start_time': startTime,
            'end_time': endTime,
            'duration': (endTime - startTime).toInt(),
            'description': description ?? 'Clip de battle',
            'is_highlight': isHighlight,
            'category': category,
          });
      
      return clipId;
    } catch (e) {
      print('Erreur création clip: $e');
      rethrow;
    }
  }
  
  /// Obtenir les clips d'un battle
  static Future<List<BattleClip>> getBattleClips(String battleId) async {
    try {
      final result = await Supabase.instance.client
          .from('battle_clips')
          .select()
          .eq('battle_id', battleId)
          .order('start_time', ascending: true);
      
      return result.map((json) => BattleClip.fromJson(json)).toList();
    } catch (e) {
      print('Erreur récupération clips: $e');
      return [];
    }
  }
}

/// Session de partage TikTok
class TikTokShareSession {
  final String id;
  final String userId;
  final String battleId;
  final String videoPath;
  final String title;
  final String description;
  final List<String> hashtags;
  ShareStatus status;
  String? tiktokVideoId;
  String? tiktokVideoUrl;
  final DateTime createdAt;
  
  TikTokShareSession({
    required this.id,
    required this.userId,
    required this.battleId,
    required this.videoPath,
    required this.title,
    required this.description,
    required this.hashtags,
    required this.status,
    this.tiktokVideoId,
    this.tiktokVideoUrl,
    required this.createdAt,
  });
}

/// Statut de partage
enum ShareStatus {
  preparing,
  uploading,
  uploaded,
  publishing,
  published,
  failed,
}

/// Partage TikTok
class TikTokShare {
  final String id;
  final String userId;
  final String battleId;
  final String videoUrl;
  final String thumbnailUrl;
  final String title;
  final String description;
  final List<String> hashtags;
  final int duration;
  final int fileSize;
  final String shareToken;
  final String status;
  final String? tiktokVideoId;
  final String platform;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  TikTokShare({
    required this.id,
    required this.userId,
    required this.battleId,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.title,
    required this.description,
    required this.hashtags,
    required this.duration,
    required this.fileSize,
    required this.shareToken,
    required this.status,
    this.tiktokVideoId,
    required this.platform,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory TikTokShare.fromJson(Map<String, dynamic> json) {
    return TikTokShare(
      id: json['id'],
      userId: json['user_id'],
      battleId: json['battle_id'],
      videoUrl: json['video_url'],
      thumbnailUrl: json['thumbnail_url'] ?? '',
      title: json['title'],
      description: json['description'],
      hashtags: jsonDecode(json['hashtags'] ?? '[]'),
      duration: json['duration'] ?? 0,
      fileSize: json['file_size'] ?? 0,
      shareToken: json['share_token'],
      status: json['status'],
      tiktokVideoId: json['tiktok_video_id'],
      platform: json['platform'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

/// Clip de battle
class BattleClip {
  final String id;
  final String battleId;
  final String videoUrl;
  final String thumbnailUrl;
  final double startTime;
  final double endTime;
  final int duration;
  final String description;
  final bool isHighlight;
  final String category;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  BattleClip({
    required this.id,
    required this.battleId,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.description,
    required this.isHighlight,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory BattleClip.fromJson(Map<String, dynamic> json) {
    return BattleClip(
      id: json['id'],
      battleId: json['battle_id'],
      videoUrl: json['video_url'],
      thumbnailUrl: json['thumbnail_url'] ?? '',
      startTime: json['start_time']?.toDouble() ?? 0.0,
      endTime: json['end_time']?.toDouble() ?? 0.0,
      duration: json['duration'] ?? 0,
      description: json['description'],
      isHighlight: json['is_highlight'] ?? false,
      category: json['category'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
