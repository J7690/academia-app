/// Description des champs du dossier de candidature.
///
/// Cette liste ne DÉCIDE rien. Le seul juge de la complétude est la fonction
/// `app_is_student_dossier_complete()` en base : c'est elle qui renvoie
/// `missing_fields`, et c'est elle que l'on rappelle après enregistrement.
/// Ce fichier sert uniquement à nommer, ordonner et regrouper ce que le
/// serveur signale — pour ne jamais afficher « bepc_mention » à un étudiant.
///
/// Corollaire : si le verrou change en base et exige un champ inconnu d'ici,
/// le formulaire ne peut pas le corriger. Il le dit (cf. `unsupportedFields`)
/// au lieu de l'ignorer en silence.
library;

enum DossierFieldKind {
  /// Texte court sur une ligne.
  text,

  /// Année sur 4 chiffres, enregistrée en entier.
  year,

  /// Date choisie au calendrier, enregistrée au format `YYYY-MM-DD`.
  date,

  /// Mention scolaire, choisie dans [kMentionOptions].
  mention,

  /// Texte libre sur plusieurs lignes.
  longText,
}

class DossierField {
  /// Nom de la colonne, tel que le serveur le renvoie dans `missing_fields`.
  final String key;
  final String label;
  final DossierFieldKind kind;
  final String? hint;

  const DossierField(this.key, this.label, this.kind, {this.hint});
}

class DossierStep {
  final String title;
  final List<DossierField> fields;

  const DossierStep({required this.title, required this.fields});
}

/// Les 12 champs exigés, en 3 étapes.
///
/// Une étape dont tous les champs sont déjà remplis n'est pas affichée : en
/// pratique `full_name` est renseigné à l'inscription, l'étape 1 se réduit
/// donc le plus souvent à la date de naissance.
const List<DossierStep> kDossierSteps = <DossierStep>[
  DossierStep(
    title: 'Identité',
    fields: <DossierField>[
      DossierField('full_name', 'Nom complet', DossierFieldKind.text),
      DossierField('date_of_birth', 'Date de naissance', DossierFieldKind.date),
    ],
  ),
  DossierStep(
    title: 'BEPC / Brevet',
    fields: <DossierField>[
      DossierField('bepc_year', 'Année du BEPC', DossierFieldKind.year,
          hint: 'ex : 2018'),
      DossierField(
          'bepc_institution', 'Établissement du BEPC', DossierFieldKind.text),
      DossierField('bepc_country', 'Pays du BEPC', DossierFieldKind.text,
          hint: 'ex : Burkina Faso'),
      DossierField('bepc_mention', 'Mention du BEPC', DossierFieldKind.mention),
    ],
  ),
  DossierStep(
    title: 'Baccalauréat et projet',
    fields: <DossierField>[
      DossierField('bac_year', 'Année du Baccalauréat', DossierFieldKind.year,
          hint: 'ex : 2021'),
      DossierField('bac_series', 'Série du Baccalauréat', DossierFieldKind.text,
          hint: 'ex : D'),
      DossierField(
          'bac_mention', 'Mention du Baccalauréat', DossierFieldKind.mention),
      DossierField(
          'bac_institution', 'Établissement du Bac', DossierFieldKind.text),
      DossierField('bac_country', 'Pays du Bac', DossierFieldKind.text,
          hint: 'ex : Burkina Faso'),
      DossierField(
        'study_project_text',
        "Projet d'études",
        DossierFieldKind.longText,
        hint: 'Ce que tu veux étudier, et pourquoi.',
      ),
    ],
  ),
];

/// « Sans mention » est une valeur à part entière : le serveur exige un texte
/// non vide, et un étudiant simplement admis doit pouvoir candidater.
const List<String> kMentionOptions = <String>[
  'Sans mention',
  'Passable',
  'Assez bien',
  'Bien',
  'Très bien',
];

final Map<String, DossierField> _byKey = <String, DossierField>{
  for (final step in kDossierSteps)
    for (final field in step.fields) field.key: field,
};

/// Libellé lisible d'un champ. Rend la clé brute si elle est inconnue : mieux
/// vaut un nom technique affiché qu'une exigence passée sous silence.
String dossierFieldLabel(String key) => _byKey[key]?.label ?? key;

/// Les champs signalés manquants que ce formulaire ne sait pas corriger.
List<String> unsupportedFields(List<String> missingFields) =>
    missingFields.where((key) => !_byKey.containsKey(key)).toList();

/// Les étapes à afficher, réduites aux seuls champs réellement manquants.
List<DossierStep> stepsForMissingFields(List<String> missingFields) {
  final missing = missingFields.toSet();
  final steps = <DossierStep>[];
  for (final step in kDossierSteps) {
    final fields =
        step.fields.where((field) => missing.contains(field.key)).toList();
    if (fields.isNotEmpty) {
      steps.add(DossierStep(title: step.title, fields: fields));
    }
  }
  return steps;
}
