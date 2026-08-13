/// Fusionne un storyboard édité avec le JSON d'origine, sans rien perdre.
///
/// LE DÉFAUT QUE CE FICHIER CORRIGE, ET IL EXPLIQUAIT TOUT.
/// Avant d'envoyer un rendu, l'application réécrivait `storyboard_json` avec
/// `Storyboard.toJson()`. Or le modèle Dart ne connaît qu'une partie des champs
/// que l'IA produit. Mesuré le 07/08 sur le storyboard réel d'un cours :
///
///   présents dans le JSON de l'IA   engine, narration, emphasis,
///                                   emphasis_target, key_words, recall, beat
///   présents dans le modèle Dart    aucun des sept
///
/// Chaque envoi de rendu effaçait donc `"engine": "vision2"`. Le serveur lisait
/// un moteur vide et retombait sur la chaîne *legacy* — diaporama d'images,
/// **sans aperçu, sans sound design, sans écriture manuscrite**. C'est ce qui
/// explique les 71 rendus sans un seul aperçu publié, longtemps attribués à un
/// défaut de threads côté serveur qui n'existait pas.
///
/// POURQUOI UNE FUSION PROFONDE ET NON UN SIMPLE `{...brut, ...edite}`.
/// Une fusion de surface sauverait `engine`, mais `toJson()` reconstruit le
/// tableau `scenes` en entier : les champs par bloc — `narration`, `emphasis`,
/// `key_words` — disparaîtraient quand même. Or c'est `bloc.narration` qui
/// porte le cours réel (206 mots sur ce même storyboard, contre 99 pour les
/// résumés de scène).
///
/// La règle est donc : **ce que l'éditeur a modifié gagne, tout le reste
/// survit.** On apparie les scènes et les blocs par identifiant quand il
/// existe, par rang sinon.
library;

/// Rend le JSON à enregistrer : les champs édités par-dessus le JSON d'origine.
Map<String, dynamic> fusionnerStoryboard(
  Map<String, dynamic>? brut,
  Map<String, dynamic> edite,
) {
  if (brut == null || brut.isEmpty) return edite;
  return _fusionnerObjet(brut, edite);
}

Map<String, dynamic> _fusionnerObjet(
  Map<String, dynamic> brut,
  Map<String, dynamic> edite,
) {
  final resultat = Map<String, dynamic>.from(brut);

  edite.forEach((cle, valeurEditee) {
    final valeurBrute = brut[cle];

    if (valeurEditee is Map<String, dynamic> &&
        valeurBrute is Map<String, dynamic>) {
      resultat[cle] = _fusionnerObjet(valeurBrute, valeurEditee);
    } else if (valeurEditee is List && valeurBrute is List) {
      resultat[cle] = _fusionnerListe(valeurBrute, valeurEditee);
    } else if (valeurEditee == null) {
      // Une valeur nulle côté éditeur veut dire « je n'en sais rien »,
      // jamais « efface ». C'est précisément la confusion qui a coûté le
      // moteur vision2.
      // On garde donc l'original.
    } else {
      resultat[cle] = valeurEditee;
    }
  });

  return resultat;
}

List<dynamic> _fusionnerListe(List<dynamic> brut, List<dynamic> edite) {
  // Apparier par identifiant si les deux côtés en portent un : l'éditeur peut
  // réordonner ou supprimer une scène, et un appariement par rang associerait
  // alors les mauvais blocs.
  final parId = <String, Map<String, dynamic>>{};
  for (final element in brut) {
    if (element is Map<String, dynamic>) {
      final id = element['id']?.toString();
      if (id != null && id.isNotEmpty) parId[id] = element;
    }
  }

  final resultat = <dynamic>[];
  for (var i = 0; i < edite.length; i++) {
    final elementEdite = edite[i];
    if (elementEdite is! Map<String, dynamic>) {
      resultat.add(elementEdite);
      continue;
    }

    Map<String, dynamic>? correspondant;
    final id = elementEdite['id']?.toString();
    if (id != null && id.isNotEmpty) correspondant = parId[id];
    correspondant ??= (i < brut.length && brut[i] is Map<String, dynamic>)
        ? brut[i] as Map<String, dynamic>
        : null;

    resultat.add(correspondant == null
        ? elementEdite
        : _fusionnerObjet(correspondant, elementEdite));
  }
  return resultat;
}
