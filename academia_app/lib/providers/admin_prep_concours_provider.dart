import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPrepSourceDocument {
  final String id;
  final String? subjectId;
  final int? year;
  final String? docType;
  final String sourceType;
  final String? storageBucket;
  final String? storagePath;
  final String status;
  final String? extractedText;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AdminPrepSourceDocument({
    required this.id,
    required this.subjectId,
    required this.year,
    required this.docType,
    required this.sourceType,
    required this.storageBucket,
    required this.storagePath,
    required this.status,
    required this.extractedText,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdminPrepSourceDocument.fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return AdminPrepSourceDocument(
      id: (json['id'] ?? '').toString(),
      subjectId: (json['subject_id'] ?? '').toString().trim().isEmpty
          ? null
          : (json['subject_id'] ?? '').toString(),
      year: json['year'] is int ? json['year'] as int : int.tryParse('${json['year'] ?? ''}'),
      docType: (json['doc_type'] ?? '').toString().trim().isEmpty
          ? null
          : (json['doc_type'] ?? '').toString(),
      sourceType: (json['source_type'] ?? 'text').toString(),
      storageBucket: (json['storage_bucket'] ?? '').toString().trim().isEmpty
          ? null
          : (json['storage_bucket'] ?? '').toString(),
      storagePath: (json['storage_path'] ?? '').toString().trim().isEmpty
          ? null
          : (json['storage_path'] ?? '').toString(),
      status: (json['status'] ?? 'received').toString(),
      extractedText: (json['extracted_text'] ?? '').toString().trim().isEmpty
          ? null
          : (json['extracted_text'] ?? '').toString(),
      createdAt: parseDt(json['created_at']),
      updatedAt: parseDt(json['updated_at']),
    );
  }
}

class AdminPrepAiGeneration {
  final String id;
  final String? subjectId;
  final String generationType;
  final Map<String, dynamic>? inputParams;
  final Map<String, dynamic>? outputJson;
  final String status;
  final String? errorMessage;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AdminPrepAiGeneration({
    required this.id,
    required this.subjectId,
    required this.generationType,
    required this.inputParams,
    required this.outputJson,
    required this.status,
    required this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdminPrepAiGeneration.fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    Map<String, dynamic>? parseMap(dynamic v) {
      if (v is Map) {
        return Map<String, dynamic>.from(v);
      }
      return null;
    }

    return AdminPrepAiGeneration(
      id: (json['id'] ?? '').toString(),
      subjectId: (json['subject_id'] ?? '').toString().trim().isEmpty
          ? null
          : (json['subject_id'] ?? '').toString(),
      generationType: (json['generation_type'] ?? 'mcq').toString(),
      inputParams: parseMap(json['input_params']),
      outputJson: parseMap(json['output_json']),
      status: (json['status'] ?? 'proposed').toString(),
      errorMessage: (json['error_message'] ?? '').toString().trim().isEmpty
          ? null
          : (json['error_message'] ?? '').toString(),
      createdAt: parseDt(json['created_at']),
      updatedAt: parseDt(json['updated_at']),
    );
  }
}

class AdminPrepConcoursProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  List<AdminPrepSourceDocument> _documents = const [];
  List<AdminPrepAiGeneration> _generations = const [];

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  List<AdminPrepSourceDocument> get documents => _documents;
  List<AdminPrepAiGeneration> get generations => _generations;

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

  Future<void> loadSourceDocuments({String? subjectId, String? status}) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_prep_list_source_documents',
        params: {
          'p_subject_id': subjectId,
          'p_status': status,
        },
      );

      if (response is! Map) {
        _setError('Réponse invalide du serveur.');
        return;
      }
      final map = Map<String, dynamic>.from(response);
      if (map['success'] != true) {
        _setError(map['error']?.toString() ?? 'Erreur lors du chargement.');
        return;
      }
      final docs = map['documents'];
      if (docs is List) {
        _documents = docs
            .whereType<Map>()
            .map((e) => AdminPrepSourceDocument.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false);
      } else {
        _documents = const [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> publishAiGeneration({required String generationId}) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_prep_publish_ai_generation',
        params: {
          'p_generation_id': generationId,
        },
      );

      if (response is! Map) {
        _setError('Réponse invalide du serveur.');
        return false;
      }
      final map = Map<String, dynamic>.from(response);
      if (map['success'] != true) {
        _setError(map['error']?.toString() ?? 'Erreur lors de la publication.');
        return false;
      }

      await loadAiGenerations();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<void> loadAiGenerations({String? subjectId, String? status}) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_prep_list_ai_generations',
        params: {
          'p_subject_id': subjectId,
          'p_status': status,
        },
      );

      if (response is! Map) {
        _setError('Réponse invalide du serveur.');
        return;
      }
      final map = Map<String, dynamic>.from(response);
      if (map['success'] != true) {
        _setError(map['error']?.toString() ?? 'Erreur lors du chargement.');
        return;
      }

      final data = map['generations'];
      if (data is List) {
        _generations = data
            .whereType<Map>()
            .map((e) => AdminPrepAiGeneration.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false);
      } else {
        _generations = const [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> upsertSourceDocument({
    String? documentId,
    String? subjectId,
    int? year,
    String? docType,
    String sourceType = 'text',
    String? storageBucket,
    String? storagePath,
    String? extractedText,
    String status = 'received',
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_prep_upsert_source_document',
        params: {
          'p_document_id': documentId,
          'p_subject_id': subjectId,
          'p_year': year,
          'p_doc_type': docType,
          'p_source_type': sourceType,
          'p_storage_bucket': storageBucket,
          'p_storage_path': storagePath,
          'p_extracted_text': extractedText,
          'p_status': status,
        },
      );

      if (response is! Map) {
        _setError('Réponse invalide du serveur.');
        return false;
      }
      final map = Map<String, dynamic>.from(response);
      if (map['success'] != true) {
        _setError(map['error']?.toString() ?? 'Erreur lors de la sauvegarde.');
        return false;
      }

      await loadSourceDocuments();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> updateSourceDocumentText({
    required String documentId,
    required String extractedText,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_prep_update_source_document_text',
        params: {
          'p_document_id': documentId,
          'p_extracted_text': extractedText,
        },
      );

      if (response is! Map) {
        _setError('Réponse invalide du serveur.');
        return false;
      }
      final map = Map<String, dynamic>.from(response);
      if (map['success'] != true) {
        _setError(map['error']?.toString() ?? 'Erreur lors de la mise à jour.');
        return false;
      }

      await loadSourceDocuments();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> setSourceDocumentStatus({
    required String documentId,
    required String status,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_prep_set_source_document_status',
        params: {
          'p_document_id': documentId,
          'p_status': status,
        },
      );

      if (response is! Map) {
        _setError('Réponse invalide du serveur.');
        return false;
      }
      final map = Map<String, dynamic>.from(response);
      if (map['success'] != true) {
        _setError(map['error']?.toString() ?? 'Erreur lors de la mise à jour.');
        return false;
      }

      await loadSourceDocuments();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }
}
