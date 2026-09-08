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

  /// Dernier diplôme, choisi dans [kDiplomaOptions].
  choice,

  /// Texte libre sur plusieurs lignes.
  longText,
}

class DossierField {
  /// Nom de la colonne, tel que le serveur le renvoie dans `missing_fields`.
  final String key;
  final String label;
  final DossierFieldKind kind;
  final String? hint;

  /// Champ COMPAGNON : affiché avec son étape, jamais exigé.
  ///
  /// Sans cette notion, un champ que le serveur ne réclame pas ne peut pas
  /// exister dans ce formulaire : `stepsForMissingFields` ne conserve que les
  /// clés présentes dans `missing_fields`. `last_diploma_detail` — la précision
  /// « Licence en quoi » — n'aurait donc JAMAIS pu s'afficher, alors que c'est
  /// précisément ce qui rend le dernier diplôme exploitable pour le courtage.
  ///
  /// Un champ facultatif n'apparaît que si un AUTRE champ de son étape est
  /// réclamé, et `_validateCurrentStep` ne le bloque jamais.
  final bool optional;

  const DossierField(this.key, this.label, this.kind,
      {this.hint, this.optional = false});
}

class DossierStep {
  final String title;
  final List<DossierField> fields;

  const DossierStep({required this.title, required this.fields});
}

/// CANDIDATER NE DEMANDE PLUS QU'UN CHAMP (décision du 08/09/2026).
///
/// Le serveur exigeait DOUZE champs — identité, BEPC, BAC, projet d'études —
/// avant d'accepter une candidature. Mesure du jour : 290 étudiants inscrits,
/// **10 dossiers complets**, et 278 à qui il manquait onze champs ou plus.
/// Aucune candidature déposée entre le 05/08 et le 08/09.
///
/// Le courtage n'a pas besoin de ces douze champs pour RECEVOIR une
/// candidature ; il en a besoin pour monter le dossier envoyé à l'école — et
/// c'est le travail de l'administrateur, qui parle de toute façon au candidat
/// pendant la négociation.
///
/// Ne restent donc exigés que `full_name` (recueilli à la création du compte,
/// `NOT NULL` en base) et `last_diploma`. **Les étapes suivantes ne sont plus
/// jamais déclenchées par le dépôt d'une candidature** : elles sont conservées
/// parce que ce formulaire sert aussi à compléter un profil, et parce que les
/// dix dossiers déjà remplis doivent rester affichables.
///
/// Une étape dont tous les champs sont déjà remplis n'est pas affichée.
const List<DossierStep> kDossierSteps = <DossierStep>[
  DossierStep(
    title: 'Ton parcours',
    fields: <DossierField>[
      // POURQUOI LE DERNIER DIPLÔME, ET NON LA SÉRIE DU BAC. Un candidat au
      // master a une licence : lui demander sa série de bac ne dit rien de son
      // parcours réel. Un seul champ couvre les deux cas.
      DossierField('last_diploma', 'Dernier diplôme obtenu',
          DossierFieldKind.choice),
      // Facultatif : jamais réclamé par le serveur, donc jamais affiché seul.
      // Il n'apparaît qu'à côté du diplôme, pour préciser « Licence en quoi ».
      DossierField('last_diploma_detail', 'Précision (facultatif)',
          DossierFieldKind.text,
          hint: 'ex : série D, ou Informatique de gestion',
          optional: true),
    ],
  ),
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

/// Les diplômes proposés, du plus courant au plus rare dans le public visé.
///
/// « Aucun pour l'instant » n'est pas un aveu d'échec : un élève de terminale
/// qui prépare son orientation doit pouvoir candidater. Le champ sert à
/// orienter le courtage, pas à filtrer les candidats — c'est l'administrateur
/// qui juge, pendant la négociation.
const List<String> kDiplomaOptions = <String>[
  'Baccalauréat',
  'BEPC',
  'Licence',
  'Master',
  'BTS / DUT',
  'Doctorat',
  'Autre',
  "Aucun pour l'instant",
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

/// Les étapes à afficher, réduites aux champs réellement manquants — PLUS les
/// champs facultatifs de ces mêmes étapes.
///
/// Le serveur ne réclame QUE ce qu'il exige. Un champ facultatif n'apparaît
/// donc jamais dans `missing_fields`, et sans la seconde passe ci-dessous il
/// serait invisible à jamais : c'était le cas de `last_diploma_detail`, la
/// précision qui dit « Licence en quoi » et sans laquelle le dernier diplôme
/// ne sert pas à grand-chose au courtage.
///
/// Une étape n'est retenue que si elle contient au moins un champ EXIGÉ : un
/// facultatif seul n'a aucune raison d'interrompre l'étudiant.
List<DossierStep> stepsForMissingFields(List<String> missingFields) {
  final missing = missingFields.toSet();
  final steps = <DossierStep>[];
  for (final step in kDossierSteps) {
    final exiges =
        step.fields.where((field) => missing.contains(field.key)).toList();
    if (exiges.isEmpty) continue;
    // On reprend l'ordre déclaré, en ajoutant les facultatifs de l'étape.
    final fields = step.fields
        .where((field) => missing.contains(field.key) || field.optional)
        .toList();
    steps.add(DossierStep(title: step.title, fields: fields));
  }
  return steps;
}
