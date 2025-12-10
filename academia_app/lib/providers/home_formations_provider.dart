import 'package:flutter/foundation.dart';

/// Modèle léger pour une formation/filière affichée sur la home mobile.
class HomeFormation {
  final String id;
  final String title;
  final String? description;
  final String universityName;
  final String? universitySlug;
  final String? degreeLevel;
  final String? mode;
  final String? city;
  final String? country;
  final bool highlighted;
  final Map<String, dynamic> raw;

  HomeFormation({
    required this.id,
    required this.title,
    required this.universityName,
    required this.raw,
    this.description,
    this.universitySlug,
    this.degreeLevel,
    this.mode,
    this.city,
    this.country,
    this.highlighted = false,
  });

  factory HomeFormation.fromOffer(Map<String, dynamic> offer) {
    final id = (offer['program_id'] ?? offer['id'] ?? '').toString();
    final title =
        (offer['program_title'] ?? offer['title'] ?? '').toString().trim();
    final universityName =
        (offer['university_name'] ?? '').toString().trim();
    final description =
        (offer['program_description'] ?? '').toString().trim();
    final degreeLevel = (offer['degree_level'] ?? '').toString().trim();
    final mode = (offer['mode'] ?? '').toString().trim();
    final city = (offer['city'] ?? '').toString().trim();
    final country = (offer['country'] ?? '').toString().trim();
    final universitySlug = (offer['university_slug'] ?? '').toString().trim();
    final highlighted = offer['highlighted'] == true;

    if (title.isEmpty || universityName.isEmpty) {
      throw ArgumentError('Programme invalide: titre ou université manquant.');
    }

    return HomeFormation(
      id: id.isEmpty ? '${title}_$universityName' : id,
      title: title,
      universityName: universityName,
      description: description.isEmpty ? null : description,
      degreeLevel: degreeLevel.isEmpty ? null : degreeLevel,
      mode: mode.isEmpty ? null : mode,
      city: city.isEmpty ? null : city,
      country: country.isEmpty ? null : country,
      universitySlug: universitySlug.isEmpty ? null : universitySlug,
      highlighted: highlighted,
      raw: Map<String, dynamic>.from(offer),
    );
  }
}

/// Provider agrégateur pour les formations de la home mobile.
///
/// Il ne fait AUCUN appel RPC direct : il consomme uniquement
/// les données déjà chargées via StudentOffersProvider.homeOffers.
class HomeFormationsProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  bool _initialized = false;
  List<HomeFormation> _formations = [];
  String? _lastSourceSignature;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get initialized => _initialized;
  List<HomeFormation> get formations => List.unmodifiable(_formations);

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  /// Met à jour la liste des formations à partir des homeOffers existants.
  ///
  /// Cette méthode peut être appelée à chaque fois que StudentOffersProvider
  /// recharge les données. Elle ne déclenche aucun appel réseau.
  void syncFromHomeOffers(List<Map<String, dynamic>> offers) {
    final signature = offers
        .map((offer) => (offer['program_id'] ?? offer['id'] ?? '').toString())
        .join('|');

    if (_initialized && _lastSourceSignature == signature) {
      return;
    }

    _initialized = true;
    _lastSourceSignature = signature;
    _setError(null);

    final list = <HomeFormation>[];

    for (final raw in offers) {
      try {
        final formation = HomeFormation.fromOffer(raw);
        list.add(formation);
      } catch (_) {
        continue;
      }
    }

    list.sort((a, b) {
      if (a.highlighted == b.highlighted) {
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
      return a.highlighted ? -1 : 1;
    });

    _formations = list;
    notifyListeners();
  }
}
