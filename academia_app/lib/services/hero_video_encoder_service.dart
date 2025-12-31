import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class HeroVideoEncoderJob {
  final String jobId;
  final String? heroVideoId;
  final String status;

  const HeroVideoEncoderJob({
    required this.jobId,
    required this.status,
    this.heroVideoId,
  });

  factory HeroVideoEncoderJob.fromJson(Map<String, dynamic> json) {
    return HeroVideoEncoderJob(
      jobId: json['job_id']?.toString() ?? '',
      heroVideoId: json['hero_video_id']?.toString(),
      status: json['status']?.toString() ?? 'pending',
    );
  }
}

class HeroVideoRecord {
  final String id;
  final String context;
  final double? duration;
  final String? resolution;
  final int? fps;
  final String? codec;
  final String? audioCodec;
  final int partsCount;
  final List<String> partsUrls;
  final int? totalSizeBytes;
  final DateTime? createdAt;

  const HeroVideoRecord({
    required this.id,
    required this.context,
    required this.partsCount,
    required this.partsUrls,
    this.duration,
    this.resolution,
    this.fps,
    this.codec,
    this.audioCodec,
    this.totalSizeBytes,
    this.createdAt,
  });

  factory HeroVideoRecord.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      return int.tryParse(value.toString());
    }

    DateTime? parseTs(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    final rawParts = json['parts_urls'];
    final List<String> parts = <String>[];
    if (rawParts is List) {
      for (final e in rawParts) {
        if (e != null) {
          parts.add(e.toString());
        }
      }
    }

    return HeroVideoRecord(
      id: json['id']?.toString() ?? '',
      context: json['context']?.toString() ?? '',
      duration: parseDouble(json['duration']),
      resolution: json['resolution']?.toString(),
      fps: parseInt(json['fps']),
      codec: json['codec']?.toString(),
      audioCodec: json['audio_codec']?.toString(),
      partsCount: parseInt(json['parts_count']) ?? 0,
      partsUrls: parts,
      totalSizeBytes: parseInt(json['total_size_bytes']),
      createdAt: parseTs(json['created_at']),
    );
  }
}

class HeroVideoEncoderJobStatus {
  final String id;
  final String context;
  final String status;
  final String? sourceFilename;
  final int? sourceSizeBytes;
  final String? heroVideoId;
  final String? log;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const HeroVideoEncoderJobStatus({
    required this.id,
    required this.context,
    required this.status,
    this.sourceFilename,
    this.sourceSizeBytes,
    this.heroVideoId,
    this.log,
    this.createdAt,
    this.updatedAt,
  });

  factory HeroVideoEncoderJobStatus.fromJson(Map<String, dynamic> json) {
    DateTime? parseTs(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      return int.tryParse(value.toString());
    }

    return HeroVideoEncoderJobStatus(
      id: json['id']?.toString() ?? '',
      context: json['context']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      sourceFilename: json['source_filename']?.toString(),
      sourceSizeBytes: parseInt(json['source_size_bytes']),
      heroVideoId: json['hero_video_id']?.toString(),
      log: json['log']?.toString(),
      createdAt: parseTs(json['created_at']),
      updatedAt: parseTs(json['updated_at']),
    );
  }
}

class HeroVideoLinkResult {
  final String heroVideoId;
  final String playlistItemId;
  final String baseVideoUrl;

  const HeroVideoLinkResult({
    required this.heroVideoId,
    required this.playlistItemId,
    required this.baseVideoUrl,
  });

  factory HeroVideoLinkResult.fromJson(Map<String, dynamic> json) {
    return HeroVideoLinkResult(
      heroVideoId: json['hero_video_id']?.toString() ?? '',
      playlistItemId: json['playlist_item_id']?.toString() ?? '',
      baseVideoUrl: json['base_video_url']?.toString() ?? '',
    );
  }
}

class HeroVideoEncoderService {
  HeroVideoEncoderService._();

  /// Base URL du serveur local Hero Video Encoder, injectée via --dart-define.
  /// Exemple : --dart-define=HERO_ENCODER_BASE_URL=http://localhost:8010
  static const String _encoderBaseUrl =
      String.fromEnvironment('HERO_ENCODER_BASE_URL', defaultValue: '');

  static bool get isConfigured => _encoderBaseUrl.trim().isNotEmpty;

  static String get baseUrl => _encoderBaseUrl;

  static Future<bool> isEncoderReachable() async {
    final base = _encoderBaseUrl.trim();
    if (base.isEmpty) {
      return false;
    }

    Uri baseUri;
    try {
      baseUri = Uri.parse(base);
    } catch (_) {
      return false;
    }

    final uri = baseUri.replace(path: '/');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 2));
      return response.statusCode > 0;
    } on SocketException {
      return false;
    } on HttpException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<String> _getAdminJwt() async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) {
      throw Exception('Administrateur non authentifié.');
    }

    final jwt = session.accessToken;
    if (jwt.isEmpty) {
      throw Exception('Jeton administrateur invalide.');
    }

    return jwt;
  }

  static Uri _buildBackendUri(String path) {
    final base = _encoderBaseUrl.trim();
    if (base.isEmpty) {
      throw Exception(
        'Encoder local non configuré. '
        'Définis HERO_ENCODER_BASE_URL (ex. http://localhost:8010) au lancement de l\'app. '
        'Le endpoint /services/hero_video_encoder/... ne doit JAMAIS être appelé sur '
        'le domaine Supabase : c\'est un service LOCAL sur localhost.',
      );
    }

    Uri baseUri;
    try {
      baseUri = Uri.parse(base);
    } catch (_) {
      throw Exception('HERO_ENCODER_BASE_URL invalide : "$base".');
    }

    return baseUri.replace(path: path);
  }

  static Exception _wrapNetworkError(Object error, String defaultMessage) {
    if (error is SocketException || error is HttpException) {
      final base = _encoderBaseUrl.trim();
      return Exception(
        '$defaultMessage (encoder local injoignable sur ${base.isEmpty ? 'HERO_ENCODER_BASE_URL non défini' : base}). '
        'Vérifie que le serveur FastAPI Hero Video Encoder tourne bien sur ta machine.',
      );
    }

    return Exception('$defaultMessage (${error.toString()}).');
  }

  static Exception _buildBackendException(
    http.Response response, {
    required String defaultMessage,
  }) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is Map<String, dynamic>) {
          final rawMessage = (detail['message'] ?? '').toString();
          if (rawMessage.isNotEmpty) {
            return Exception(rawMessage);
          }
        } else if (detail is String && detail.isNotEmpty) {
          return Exception(detail);
        }
      }
    } catch (_) {}

    return Exception('$defaultMessage (${response.statusCode}).');
  }

  static Future<List<HeroVideoRecord>> listHeroVideos({String? context}) async {
    final client = Supabase.instance.client;
    final dynamic response = await client
        .schema('app')
        .from('hero_videos')
        .select()
        .order('created_at', ascending: false)
        .limit(50);

    if (response is! List) {
      return const <HeroVideoRecord>[];
    }

    return response
        .whereType<Map>()
        .map((e) => HeroVideoRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  static Future<HeroVideoEncoderJob> startJob({
    required Uint8List bytes,
    required String fileName,
    String? context,
  }) async {
    final jwt = await _getAdminJwt();

    final uri = _buildBackendUri('/services/hero_video_encoder/jobs');

    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll({
      'Authorization': 'Bearer $jwt',
      'Accept': 'application/json',
    });

    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );

    if (context != null && context.trim().isNotEmpty) {
      request.fields['context'] = context.trim();
    }

    http.StreamedResponse streamed;
    try {
      streamed = await request.send();
    } catch (error) {
      throw _wrapNetworkError(
        error,
        'Erreur réseau vers l\'encoder Hero Video Studio.',
      );
    }

    final response = await http.Response.fromStream(streamed);

    if (response.statusCode >= 400) {
      throw _buildBackendException(
        response,
        defaultMessage: 'Erreur lors du transcodage Hero Video Studio.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Réponse Hero Video Encoder invalide.');
    }

    return HeroVideoEncoderJob.fromJson(decoded);
  }

  static Future<HeroVideoEncoderJobStatus> getJobStatus(String jobId) async {
    final jwt = await _getAdminJwt();

    final uri = _buildBackendUri('/services/hero_video_encoder/jobs/$jobId');

    http.Response response;
    try {
      response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $jwt',
          'Accept': 'application/json',
        },
      );
    } catch (error) {
      throw _wrapNetworkError(
        error,
        'Erreur réseau lors de la lecture du job Hero Video Studio.',
      );
    }

    if (response.statusCode >= 400) {
      throw _buildBackendException(
        response,
        defaultMessage: 'Erreur lors de la lecture du job Hero Video Studio.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Réponse de statut Hero Video Encoder invalide.');
    }

    return HeroVideoEncoderJobStatus.fromJson(decoded);
  }

  static Future<HeroVideoLinkResult> linkToPlaylist({
    required String heroVideoId,
    required String playlistItemId,
  }) async {
    final jwt = await _getAdminJwt();

    final uri = _buildBackendUri('/services/hero_video_encoder/link');

    http.Response response;
    try {
      response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $jwt',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'hero_video_id': heroVideoId,
          'playlist_item_id': playlistItemId,
        }),
      );
    } catch (error) {
      throw _wrapNetworkError(
        error,
        'Erreur réseau lors du lien Hero Video & Hero playlist.',
      );
    }

    if (response.statusCode >= 400) {
      throw _buildBackendException(
        response,
        defaultMessage: 'Erreur lors du lien Hero Video & Hero playlist.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Réponse de lien Hero Video Encoder invalide.');
    }

    return HeroVideoLinkResult.fromJson(decoded);
  }
}
