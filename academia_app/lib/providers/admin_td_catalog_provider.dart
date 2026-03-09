import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour la gestion des filières, programmes,
/// collections et séances TD côté admin.
class AdminTdCatalogProvider extends ChangeNotifier {
  AdminTdCatalogProvider() : _client = Supabase.instance.client;

  final SupabaseClient _client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _fields = [];
  List<Map<String, dynamic>> _programs = [];
  List<Map<String, dynamic>> _collections = [];
  List<Map<String, dynamic>> _sessions = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get fields => List.unmodifiable(_fields);
  List<Map<String, dynamic>> get programs => List.unmodifiable(_programs);
  List<Map<String, dynamic>> get collections => List.unmodifiable(_collections);
  List<Map<String, dynamic>> get sessions => List.unmodifiable(_sessions);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadFields() async {
    _setLoading(true);
    _setError(null);
    try {
      final raw = await _client
          .schema('app')
          .from('td_fields')
          .select()
          .order('name');
      final list = raw as List<dynamic>? ?? [];
      _fields = list.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e, st) {
      debugPrint('[AdminTdCatalogProvider] loadFields error=$e stack=$st');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> createField({
    required String name,
    String? colorHex,
    String? iconName,
    String? description,
  }) async {
    if (name.trim().isEmpty) {
      _setError('Nom de filière invalide.');
      return false;
    }
    _setLoading(true);
    _setError(null);
    try {
      await _client.schema('app').from('td_fields').insert({
            'name': name.trim(),
            if (colorHex != null && colorHex.isNotEmpty) 'color_hex': colorHex,
            if (iconName != null && iconName.isNotEmpty) 'icon_name': iconName,
            if (description != null && description.isNotEmpty) 'description': description,
          });
      await loadFields();
      return true;
    } catch (e, st) {
      debugPrint('[AdminTdCatalogProvider] createField error=$e stack=$st');
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateField({
    required String fieldId,
    String? name,
    String? colorHex,
    String? iconName,
    String? description,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final updates = <String, dynamic>{};
      if (name != null && name.isNotEmpty) updates['name'] = name;
      if (colorHex != null) updates['color_hex'] = colorHex;
      if (iconName != null) updates['icon_name'] = iconName;
      if (description != null) updates['description'] = description;
      if (updates.isEmpty) return true;
      await _client.schema('app').from('td_fields').update(updates).eq('id', fieldId);
      await loadFields();
      return true;
    } catch (e, st) {
      debugPrint('[AdminTdCatalogProvider] updateField error=$e stack=$st');
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadPrograms({required String fieldId}) async {
    _setLoading(true);
    _setError(null);
    try {
      final raw = await _client
          .schema('app')
          .from('td_programs')
          .select()
          .eq('field_id', fieldId)
          .order('title');
      final list = raw as List<dynamic>? ?? [];
      _programs = list.cast<Map<String, dynamic>>();
      _collections = [];
      _sessions = [];
      notifyListeners();
    } catch (e, st) {
      debugPrint('[AdminTdCatalogProvider] loadPrograms error=$e stack=$st');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> createProgram({
    required String fieldId,
    required String level,
    required String title,
    required double price,
    String? modality,
    String? description,
    String? coverImageUrl,
    bool isFeatured = false,
    String? tags,
  }) async {
    if (fieldId.isEmpty || title.trim().isEmpty) {
      _setError('Filière ou titre de programme invalide.');
      return false;
    }
    _setLoading(true);
    _setError(null);
    try {
      await _client.schema('app').from('td_programs').insert({
            'field_id': fieldId,
            'level': level.trim().isEmpty ? 'N/A' : level.trim(),
            'title': title.trim(),
            'price': price,
            'modality': modality ?? 'online',
            'status': 'published',
            if (description != null && description.isNotEmpty) 'description': description,
            if (coverImageUrl != null && coverImageUrl.isNotEmpty) 'cover_image_url': coverImageUrl,
            'is_featured': isFeatured,
            if (tags != null && tags.isNotEmpty) 'tags': tags.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
          });
      await loadPrograms(fieldId: fieldId);
      return true;
    } catch (e, st) {
      debugPrint('[AdminTdCatalogProvider] createProgram error=$e stack=$st');
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateProgram({
    required String programId,
    required String fieldId,
    String? title,
    String? description,
    String? level,
    double? price,
    String? coverImageUrl,
    bool? isFeatured,
    String? tags,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final updates = <String, dynamic>{};
      if (title != null && title.isNotEmpty) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (level != null && level.isNotEmpty) updates['level'] = level;
      if (price != null) updates['price'] = price;
      if (coverImageUrl != null) updates['cover_image_url'] = coverImageUrl;
      if (isFeatured != null) updates['is_featured'] = isFeatured;
      if (tags != null) updates['tags'] = tags.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
      if (updates.isEmpty) return true;
      await _client.schema('app').from('td_programs').update(updates).eq('id', programId);
      await loadPrograms(fieldId: fieldId);
      return true;
    } catch (e, st) {
      debugPrint('[AdminTdCatalogProvider] updateProgram error=$e stack=$st');
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadCollections({required String programId}) async {
    _setLoading(true);
    _setError(null);
    try {
      final raw = await _client
          .schema('app')
          .from('td_collections')
          .select()
          .eq('program_id', programId)
          .order('position');
      final list = raw as List<dynamic>? ?? [];
      _collections = list.cast<Map<String, dynamic>>();
      _sessions = [];
      notifyListeners();
    } catch (e, st) {
      debugPrint('[AdminTdCatalogProvider] loadCollections error=$e stack=$st');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> createCollection({
    required String programId,
    required String title,
  }) async {
    if (programId.isEmpty || title.trim().isEmpty) {
      _setError('Programme ou titre de collection invalide.');
      return false;
    }
    _setLoading(true);
    _setError(null);
    try {
      await _client.schema('app').from('td_collections').insert({
            'program_id': programId,
            'title': title.trim(),
          });
      await loadCollections(programId: programId);
      return true;
    } catch (e, st) {
      debugPrint('[AdminTdCatalogProvider] createCollection error=$e stack=$st');
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadSessions({required String collectionId}) async {
    _setLoading(true);
    _setError(null);
    try {
      final raw = await _client
          .schema('app')
          .from('td_sessions')
          .select()
          .eq('collection_id', collectionId)
          .order('position');
      final list = raw as List<dynamic>? ?? [];
      _sessions = list.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e, st) {
      debugPrint('[AdminTdCatalogProvider] loadSessions error=$e stack=$st');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> createSession({
    required String collectionId,
    required String title,
    bool isPreview = false,
    DateTime? scheduledAt,
    int? durationMinutes,
  }) async {
    if (collectionId.isEmpty || title.trim().isEmpty) {
      _setError('Collection ou titre de séance invalide.');
      return false;
    }
    _setLoading(true);
    _setError(null);
    try {
      await _client.schema('app').from('td_sessions').insert({
            'collection_id': collectionId,
            'title': title.trim(),
            'is_preview': isPreview,
            if (scheduledAt != null) 'scheduled_at': scheduledAt.toIso8601String(),
            if (durationMinutes != null) 'duration_minutes': durationMinutes,
          });
      await loadSessions(collectionId: collectionId);
      return true;
    } catch (e, st) {
      debugPrint('[AdminTdCatalogProvider] createSession error=$e stack=$st');
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
