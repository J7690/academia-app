import 'package:flutter/foundation.dart';

import '../services/supabase_rpc_service.dart';

/// Provider Supabase utilisant les méthodes validées du système automatisé
/// Force l'utilisation des méthodes RPC validées
class SupabaseProvider extends ChangeNotifier {
  final SupabaseRPCService _rpcService = SupabaseRPCService();
  
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _data = [];
  
  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get data => _data;
  
  /// Audit de la base de données via méthode validée
  Future<void> auditDatabase() async {
    setLoading(true);
    clearError();
    
    try {
      // Utilisation OBLIGATOIRE de la méthode validée
      final result = await _rpcService.auditDatabase();
      
      if (result['success']) {
        _data = List<Map<String, dynamic>>.from(result['data']);
        notifyListeners();
      } else {
        setError(result['error'] ?? 'Erreur lors de l\'audit');
      }
    } catch (e) {
      setError('Exception: ${e.toString()}');
    } finally {
      setLoading(false);
    }
  }
  
  /// Créer une table via méthode validée
  Future<bool> createTable(String tableName, List<Map<String, String>> columns) async {
    setLoading(true);
    clearError();
    
    try {
      // Utilisation OBLIGATOIRE de la méthode validée
      final result = await _rpcService.createTable(tableName, columns);
      
      if (result['success']) {
        notifyListeners();
        return true;
      } else {
        setError(result['error'] ?? 'Erreur lors de la création');
        return false;
      }
    } catch (e) {
      setError('Exception: ${e.toString()}');
      return false;
    } finally {
      setLoading(false);
    }
  }
  
  /// Lire des données via méthode validée
  Future<void> readData(String tableName, {int limit = 10}) async {
    setLoading(true);
    clearError();
    
    try {
      // Utilisation OBLIGATOIRE de la méthode validée
      final result = await _rpcService.readData(tableName, limit: limit);
      
      if (result['success']) {
        _data = List<Map<String, dynamic>>.from(result['data']);
        notifyListeners();
      } else {
        setError(result['error'] ?? 'Erreur lors de la lecture');
      }
    } catch (e) {
      setError('Exception: ${e.toString()}');
    } finally {
      setLoading(false);
    }
  }
  
  /// Insérer des données via méthode validée
  Future<bool> insertData(String tableName, Map<String, dynamic> data) async {
    setLoading(true);
    clearError();
    
    try {
      // Utilisation OBLIGATOIRE de la méthode validée
      final result = await _rpcService.insertData(tableName, data);
      
      if (result['success']) {
        notifyListeners();
        return true;
      } else {
        setError(result['error'] ?? 'Erreur lors de l\'insertion');
        return false;
      }
    } catch (e) {
      setError('Exception: ${e.toString()}');
      return false;
    } finally {
      setLoading(false);
    }
  }
  
  /// Vérifier si une table existe via méthode validée
  Future<bool> tableExists(String tableName) async {
    try {
      // Utilisation OBLIGATOIRE de la méthode validée
      final result = await _rpcService.tableExists(tableName);
      return result['success'] && result['data'] == true;
    } catch (e) {
      setError('Exception: ${e.toString()}');
      return false;
    }
  }
  
  /// Méthodes utilitaires
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void setError(String error) {
    _error = error;
    notifyListeners();
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  void clearData() {
    _data = [];
    notifyListeners();
  }
}
