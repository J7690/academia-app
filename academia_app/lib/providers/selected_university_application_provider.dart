import 'package:flutter/foundation.dart';

/// Provider dédié pour la sélection d'une candidature côté université.
/// Sépare l'état de sélection de la logique de chargement de la liste.
class SelectedUniversityApplicationProvider extends ChangeNotifier {
  Map<String, dynamic>? _selectedApplication;

  /// Candidature actuellement sélectionnée dans le poste de travail université.
  /// Une copie défensive est retournée pour éviter les modifications involontaires.
  Map<String, dynamic>? get selectedApplication =>
      _selectedApplication == null ? null : Map<String, dynamic>.from(_selectedApplication!);

  /// Met à jour la candidature sélectionnée (ou la réinitialise si null) et notifie les listeners.
  void selectApplication(Map<String, dynamic>? application) {
    if (application == null) {
      _selectedApplication = null;
    } else {
      _selectedApplication = Map<String, dynamic>.from(application);
    }
    notifyListeners();
  }
}
