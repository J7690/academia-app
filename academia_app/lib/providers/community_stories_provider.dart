import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityStoriesProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _stories = [];
  List<Map<String, dynamic>> _viewers = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get stories => _stories;
  List<Map<String, dynamic>> get viewers => _viewers;

  String? get currentUserId => _client.auth.currentUser?.id;

  /// Group stories by author for the stories bar display
  List<Map<String, dynamic>> get storiesByAuthor {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final s in _stories) {
      final authorId = s['author_id']?.toString() ?? '';
      if (authorId.isEmpty) continue;
      map.putIfAbsent(authorId, () => []);
      map[authorId]!.add(s);
    }
    // Convert to list of {author_id, author_name, author_avatar_url, stories, has_unviewed}
    final result = <Map<String, dynamic>>[];
    final uid = currentUserId;

    // Put current user first if they have stories
    final myStories = map.remove(uid);
    if (myStories != null && myStories.isNotEmpty) {
      result.add({
        'author_id': uid,
        'author_name': myStories.first['author_name'] ?? '',
        'author_avatar_url': myStories.first['author_avatar_url'],
        'stories': myStories,
        'has_unviewed': myStories.any((s) => s['viewed_by_me'] != true),
        'is_me': true,
      });
    }

    // Then others sorted by most recent story
    final others = map.entries.toList()
      ..sort((a, b) {
        final aTime = DateTime.tryParse(
                a.value.first['created_at']?.toString() ?? '') ??
            DateTime(2000);
        final bTime = DateTime.tryParse(
                b.value.first['created_at']?.toString() ?? '') ??
            DateTime(2000);
        return bTime.compareTo(aTime);
      });

    for (final entry in others) {
      final authorStories = entry.value;
      result.add({
        'author_id': entry.key,
        'author_name': authorStories.first['author_name'] ?? '',
        'author_avatar_url': authorStories.first['author_avatar_url'],
        'stories': authorStories,
        'has_unviewed': authorStories.any((s) => s['viewed_by_me'] != true),
        'is_me': false,
      });
    }

    return result;
  }

  Future<void> loadStories(String communityId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _client.rpc(
        'app_student_list_community_stories',
        params: {'p_community_id': communityId},
      );
      if (result is List) {
        _stories = result
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else {
        _stories = [];
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('[StoriesProvider] loadStories error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createStory({
    required String communityId,
    required String type,
    String? mediaUrl,
    String? caption,
    String? bgColor,
    String? textContent,
    String? category,
  }) async {
    _error = null;
    try {
      final params = <String, dynamic>{
        'p_community_id': communityId,
        'p_type': type,
      };
      if (mediaUrl != null) params['p_media_url'] = mediaUrl;
      if (caption != null) params['p_caption'] = caption;
      if (bgColor != null) params['p_bg_color'] = bgColor;
      if (textContent != null) params['p_text_content'] = textContent;
      if (category != null) params['p_category'] = category;

      final result = await _client.rpc(
        'app_student_create_community_story',
        params: params,
      );
      if (result is Map && result['success'] == true) {
        await loadStories(communityId);
        return true;
      } else {
        _error = result?['error']?.toString() ?? 'Erreur création story';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<String?> uploadStoryMedia({
    required String communityId,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      final userId = currentUserId ?? 'unknown';
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = 'stories/$communityId/${userId}_$ts.$mimeType';
      await _client.storage.from('community-media').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: 'image/$mimeType',
            ),
          );
      return _client.storage.from('community-media').getPublicUrl(path);
    } catch (e) {
      _error = 'Erreur upload: $e';
      notifyListeners();
      return null;
    }
  }

  Future<void> markViewed(String storyId) async {
    try {
      await _client.rpc(
        'app_student_mark_story_viewed',
        params: {'p_story_id': storyId},
      );
      // Update local state
      for (int i = 0; i < _stories.length; i++) {
        if (_stories[i]['id']?.toString() == storyId) {
          _stories[i] = Map<String, dynamic>.from(_stories[i])
            ..['viewed_by_me'] = true;
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[StoriesProvider] markViewed error: $e');
    }
  }

  Future<void> loadViewers(String storyId) async {
    _viewers = [];
    try {
      final result = await _client.rpc(
        'app_student_list_story_viewers',
        params: {'p_story_id': storyId},
      );
      if (result is List) {
        _viewers = result
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[StoriesProvider] loadViewers error: $e');
    }
  }

  Future<bool> deleteStory({
    required String storyId,
    required String communityId,
  }) async {
    try {
      await _client.rpc(
        'app_student_delete_own_story',
        params: {'p_story_id': storyId},
      );
      _stories.removeWhere((s) => s['id']?.toString() == storyId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
