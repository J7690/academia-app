import 'package:http/http.dart' as http;
import 'dart:convert';

import '../config/supabase_config.dart';

/// Service RPC Supabase utilisant les méthodes validées du système automatisé
/// FORCE l'utilisation des méthodes RPC validées - PLUS DE CONTOURNEMENT POSSIBLE
class SupabaseRPCService {
  static const String _baseUrl = SupabaseConfig.url;
  static const String _serviceKey = SupabaseConfig.serviceKey;
  
  // Headers validés pour les appels RPC
  static final Map<String, String> _headers = {
    'apikey': _serviceKey,
    'Authorization': 'Bearer $_serviceKey',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  /// Audit de la base de données via méthode RPC validée
  /// OBLIGATOIRE: Utiliser list_tables_detailed
  Future<Map<String, dynamic>> auditDatabase() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/rest/v1/rpc/list_tables_detailed'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
          'method': 'rpc_list_tables_detailed',
        };
      } else {
        return {
          'success': false,
          'error': 'Erreur HTTP ${response.statusCode}',
          'method': 'rpc_list_tables_detailed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Exception: ${e.toString()}',
        'method': 'rpc_list_tables_detailed',
      };
    }
  }
  
  /// Créer une table via méthode RPC validée
  /// OBLIGATOIRE: Utiliser create_table_safe
  Future<Map<String, dynamic>> createTable(String tableName, List<Map<String, String>> columns) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/rest/v1/rpc/create_table_safe'),
        headers: _headers,
        body: jsonEncode({
          'p_table_name': tableName,
          'p_table_definition': columns.map((col) => {
            'name': col['name'],
            'type': col['type'],
          }).toList(),
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
          'method': 'rpc_create_table_safe',
        };
      } else {
        return {
          'success': false,
          'error': 'Erreur HTTP ${response.statusCode}',
          'method': 'rpc_create_table_safe',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Exception: ${e.toString()}',
        'method': 'rpc_create_table_safe',
      };
    }
  }
  
  /// Décrire une table via méthode RPC validée
  /// OBLIGATOIRE: Utiliser describe_table_detailed
  Future<Map<String, dynamic>> describeTable(String tableName) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/rest/v1/rpc/describe_table_detailed'),
        headers: _headers,
        body: jsonEncode({
          'p_table_name': tableName,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
          'method': 'rpc_describe_table_detailed',
        };
      } else {
        return {
          'success': false,
          'error': 'Erreur HTTP ${response.statusCode}',
          'method': 'rpc_describe_table_detailed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Exception: ${e.toString()}',
        'method': 'rpc_describe_table_detailed',
      };
    }
  }
  
  /// Vérifier si une table existe via méthode RPC validée
  /// OBLIGATOIRE: Utiliser table_exists
  Future<Map<String, dynamic>> tableExists(String tableName) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/rest/v1/rpc/table_exists'),
        headers: _headers,
        body: jsonEncode({
          'p_table_name': tableName,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
          'method': 'rpc_table_exists',
        };
      } else {
        return {
          'success': false,
          'error': 'Erreur HTTP ${response.statusCode}',
          'method': 'rpc_table_exists',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Exception: ${e.toString()}',
        'method': 'rpc_table_exists',
      };
    }
  }
  
  /// Lire des données via méthode API REST validée
  /// OBLIGATOIRE: Utiliser API REST pour les opérations CRUD
  Future<Map<String, dynamic>> readData(String tableName, {int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/rest/v1/$tableName?limit=$limit'),
        headers: {
          'apikey': _serviceKey,
          'Authorization': 'Bearer $_serviceKey',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
          'method': 'api_select',
        };
      } else {
        return {
          'success': false,
          'error': 'Erreur HTTP ${response.statusCode}',
          'method': 'api_select',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Exception: ${e.toString()}',
        'method': 'api_select',
      };
    }
  }
  
  /// Insérer des données via méthode API REST validée
  /// OBLIGATOIRE: Utiliser API REST pour les opérations CRUD
  Future<Map<String, dynamic>> insertData(String tableName, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/rest/v1/$tableName'),
        headers: {
          'apikey': _serviceKey,
          'Authorization': 'Bearer $_serviceKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );
      
      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'data': responseData,
          'method': 'api_insert',
        };
      } else {
        return {
          'success': false,
          'error': 'Erreur HTTP ${response.statusCode}',
          'method': 'api_insert',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Exception: ${e.toString()}',
        'method': 'api_insert',
      };
    }
  }
  
  /// Mettre à jour des données via méthode API REST validée
  /// OBLIGATOIRE: Utiliser API REST pour les opérations CRUD
  Future<Map<String, dynamic>> updateData(String tableName, Map<String, dynamic> data, String condition) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/rest/v1/$tableName?$condition'),
        headers: {
          'apikey': _serviceKey,
          'Authorization': 'Bearer $_serviceKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'data': responseData,
          'method': 'api_update',
        };
      } else {
        return {
          'success': false,
          'error': 'Erreur HTTP ${response.statusCode}',
          'method': 'api_update',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Exception: ${e.toString()}',
        'method': 'api_update',
      };
    }
  }
  
  /// Supprimer des données via méthode API REST validée
  /// OBLIGATOIRE: Utiliser API REST pour les opérations CRUD
  Future<Map<String, dynamic>> deleteData(String tableName, String condition) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/rest/v1/$tableName?$condition'),
        headers: {
          'apikey': _serviceKey,
          'Authorization': 'Bearer $_serviceKey',
        },
      );
      
      if (response.statusCode == 204) {
        return {
          'success': true,
          'data': {'deleted': true},
          'method': 'api_delete',
        };
      } else {
        return {
          'success': false,
          'error': 'Erreur HTTP ${response.statusCode}',
          'method': 'api_delete',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Exception: ${e.toString()}',
        'method': 'api_delete',
      };
    }
  }
}
