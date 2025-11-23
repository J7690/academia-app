import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentHomeContentProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _videos = [];

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  List<Map<String, dynamic>> get announcements => List.unmodifiable(_announcements);
  List<Map<String, dynamic>> get videos => List.unmodifiable(_videos);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setSaving(bool value) {
    _isSaving = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  void _applyResponse(dynamic response) {
    if (response is! Map<String, dynamic>) {
      _setError('Réponse invalide du serveur pour l\'accueil étudiant.');
      return;
    }
    if (response['success'] != true) {
      _setError(
        response['error']?.toString() ?? 'Erreur lors du chargement de l\'accueil étudiant.',
      );
      return;
    }

    final announcements = response['announcements'];
    final videos = response['videos'];

    if (announcements is List) {
      _announcements = announcements
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    } else {
      _announcements = [];
    }

    if (videos is List) {
      _videos = videos
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    } else {
      _videos = [];
    }

    notifyListeners();
  }

  Future<void> loadPublicStudentHomeContent() async {
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc('app_public_student_home_content');
      _applyResponse(response);
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadAdminStudentHomeContent() async {
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc('app_admin_get_student_home_content');
      _applyResponse(response);
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> upsertAnnouncement({
    String? announcementId,
    required String text,
    int? sortOrder,
    bool? isActive,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_admin_upsert_student_home_announcement',
        params: {
          'p_announcement_id': announcementId,
          'p_text': text,
          'p_sort_order': sortOrder,
          'p_is_active': isActive,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la sauvegarde de l\'annonce.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ?? 'Erreur lors de la sauvegarde de l\'annonce.',
        );
        return false;
      }
      await loadAdminStudentHomeContent();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> deleteAnnouncement(String announcementId) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_admin_delete_student_home_announcement',
        params: {
          'p_announcement_id': announcementId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la suppression de l\'annonce.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ?? 'Erreur lors de la suppression de l\'annonce.',
        );
        return false;
      }
      await loadAdminStudentHomeContent();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> upsertVideo({
    String? videoId,
    required String videoUrl,
    String? title,
    int? sortOrder,
    bool? isActive,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_admin_upsert_student_home_video',
        params: {
          'p_video_id': videoId,
          'p_video_url': videoUrl,
          'p_title': title,
          'p_sort_order': sortOrder,
          'p_is_active': isActive,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la sauvegarde de la vidéo.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ?? 'Erreur lors de la sauvegarde de la vidéo.',
        );
        return false;
      }
      await loadAdminStudentHomeContent();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> deleteVideo(String videoId) async {
    _setSaving(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_admin_delete_student_home_video',
        params: {
          'p_video_id': videoId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la suppression de la vidéo.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ?? 'Erreur lors de la suppression de la vidéo.',
        );
        return false;
      }
      await loadAdminStudentHomeContent();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<String?> uploadStudentHomeFile({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
    String folder = 'student-home',
  }) async {
    _setError(null);
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        _setError('Utilisateur non authentifié.');
        return null;
      }

      final sanitizedFileName =
          fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final storagePath = '${user.id}/student-home/$folder/$sanitizedFileName';

      await _client.storage.from('landing-media').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: true,
            ),
          );

      final publicUrl =
          _client.storage.from('landing-media').getPublicUrl(storagePath);
      return publicUrl;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }
}
