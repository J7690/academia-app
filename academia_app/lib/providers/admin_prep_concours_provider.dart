import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

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

  /// Triggers the prep-analyze-trends Edge Function to detect recurring topics and generate predictions.
  Future<Map<String, dynamic>?> triggerAnalyzeTrends({
    String? concoursType,
    String targetYear = '2026',
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final session = _client.auth.currentSession;
      if (session == null) {
        _setError('Non authentifié.');
        return null;
      }

      final uri = Uri.parse('${SupabaseConfig.url}/functions/v1/prep-analyze-trends');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'apikey': SupabaseConfig.anonKey,
        },
        body: jsonEncode({
          if (concoursType != null) 'concours_type': concoursType,
          'target_year': targetYear,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['success'] == true) {
          return data;
        }
        _setError(data['error']?.toString() ?? 'Erreur analyse des tendances.');
        return null;
      }

      _setError('Erreur Edge Function (${response.statusCode}).');
      return null;
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setSaving(false);
    }
  }

  /// Triggers the prep-generate-questions Edge Function to generate QCM from indexed content.
  Future<Map<String, dynamic>?> triggerGenerateQuestions({
    String? concoursType,
    String? subjectName,
    String? subjectId,
    String? bankId,
    int count = 10,
    String mode = 'similar', // similar, exam_blanc, revision
    int? difficulty,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final session = _client.auth.currentSession;
      if (session == null) {
        _setError('Non authentifié.');
        return null;
      }

      final uri = Uri.parse('${SupabaseConfig.url}/functions/v1/prep-generate-questions');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'apikey': SupabaseConfig.anonKey,
        },
        body: jsonEncode({
          if (concoursType != null) 'concours_type': concoursType,
          if (subjectName != null) 'subject_name': subjectName,
          if (subjectId != null) 'subject_id': subjectId,
          if (bankId != null) 'bank_id': bankId,
          'count': count,
          'mode': mode,
          if (difficulty != null) 'difficulty': difficulty,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['success'] == true) {
          await loadAiGenerations();
          return data;
        }
        _setError(data['error']?.toString() ?? 'Erreur inconnue lors de la génération.');
        return null;
      }

      _setError('Erreur Edge Function (${response.statusCode}).');
      return null;
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setSaving(false);
    }
  }

  /// Triggers the prep-ingest-document Edge Function to extract PDF → chunks → embeddings.
  Future<bool> triggerIngestion({required String documentId}) async {
    _setSaving(true);
    _setError(null);
    try {
      final session = _client.auth.currentSession;
      if (session == null) {
        _setError('Non authentifié.');
        return false;
      }

      final uri = Uri.parse('${SupabaseConfig.url}/functions/v1/prep-ingest-document');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'apikey': SupabaseConfig.anonKey,
        },
        body: jsonEncode({'document_id': documentId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['success'] == true) {
          await loadSourceDocuments();
          return true;
        }
        _setError(data['error']?.toString() ?? 'Erreur inconnue lors de l\'ingestion.');
        return false;
      }

      _setError('Erreur Edge Function (${response.statusCode}).');
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }

  /// Crée un enregistrement prep_ai_generation avec output_json
  Future<String?> createAiGenerationWithJson({
    required String subjectId,
    required String generationType,
    required Map<String, dynamic> outputJson,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final res1 = await _client.rpc(
        'app_admin_prep_create_ai_generation',
        params: {
          'p_subject_id': subjectId,
          'p_generation_type': generationType,
          'p_input_params': {'source': 'manual_import'},
        },
      );
      if (res1 is! Map) { _setError('Réponse invalide (create).'); return null; }
      final map1 = Map<String, dynamic>.from(res1);
      if (map1['success'] != true) { _setError(map1['error']?.toString()); return null; }
      final genId = map1['generation']?['id']?.toString();
      if (genId == null || genId.isEmpty) { _setError('ID génération manquant.'); return null; }

      final res2 = await _client.rpc(
        'app_admin_prep_set_ai_generation_status',
        params: {
          'p_generation_id': genId,
          'p_status': 'validated',
          'p_output_json': outputJson,
          'p_error_message': null,
        },
      );
      if (res2 is! Map) { _setError('Réponse invalide (validate).'); return null; }
      final map2 = Map<String, dynamic>.from(res2);
      if (map2['success'] != true) { _setError(map2['error']?.toString()); return null; }

      return genId;
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setSaving(false);
    }
  }

  /// Importe les questions depuis l'asset JSON et les publie par matière.
  /// Retourne une map sujet → nombre de questions injectées.
  Future<Map<String, int>> importQuestionsFromAsset({
    required Map<String, String> subjectSlugToId,
  }) async {
    final results = <String, int>{};
    _setError(null);

    try {
      final jsonStr = await rootBundle.loadString(
          'assets/data/prep_concours_questions_burkina.json');
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      final questions = (data['questions'] as List).cast<Map<String, dynamic>>();

      // Grouper par matière
      final bySubject = <String, List<Map<String, dynamic>>>{};
      for (final q in questions) {
        final subject = (q['subject'] as String?)?.toLowerCase().trim() ?? '';
        bySubject.putIfAbsent(subject, () => []).add(q);
      }

      for (final entry in bySubject.entries) {
        final slug = entry.key;
        final subjectId = subjectSlugToId[slug];
        if (subjectId == null) {
          debugPrint('[Import] Sujet "$slug" non trouvé, ignoré.');
          continue;
        }

        // Convertir au format attendu par publish_ai_generation
        final formattedQuestions = entry.value.map((q) {
          return {
            'question': q['question'] ?? '',
            'explanation': q['explanation'] ?? '',
            'choices': List<String>.from(q['options'] ?? []),
            'correct_index': q['correct_answer'] ?? 0,
          };
        }).toList();

        final outputJson = {'questions': formattedQuestions};

        final genId = await createAiGenerationWithJson(
          subjectId: subjectId,
          generationType: 'mcq',
          outputJson: outputJson,
        );

        if (genId == null) {
          debugPrint('[Import] Erreur création génération pour "$slug": $_error');
          continue;
        }

        final published = await publishAiGeneration(generationId: genId);
        if (published) {
          results[slug] = entry.value.length;
        } else {
          debugPrint('[Import] Erreur publication pour "$slug": $_error');
        }
      }
    } catch (e) {
      _setError(e.toString());
    }

    return results;
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
