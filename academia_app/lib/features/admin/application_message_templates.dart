/// Modèles locaux : leur sélection prépare un brouillon, jamais un envoi.
class ApplicationMessageTemplate {
  const ApplicationMessageTemplate({
    required this.label,
    required this.target,
    required this.body,
  });

  final String label;
  final String target;
  final String body;

  String render(Map<String, dynamic> application) {
    String value(String key, String fallback) {
      final text = application[key]?.toString().trim() ?? '';
      return text.isEmpty ? fallback : text;
    }

    final program = value('program_title', 'la formation demandée');
    final degree = value('requested_degree_level', '');
    final replacements = <String, String>{
      'nom': value('student_full_name', 'le candidat'),
      'filiere': degree.isEmpty ? program : '$program ($degree)',
      'universite': value('university_name', "l’université concernée"),
    };
    // Une seule passe : les accolades présentes dans un nom restent du texte.
    return body.replaceAllMapped(
      RegExp(r'\{(nom|filiere|universite)\}'),
      (match) => replacements[match.group(1)]!,
    );
  }
}

const applicationMessageTemplates = <ApplicationMessageTemplate>[
  ApplicationMessageTemplate(
    label: 'Candidature reçue',
    target: 'student',
    body: 'Bonjour {nom},\n\n'
        'Nous avons bien reçu votre candidature pour {filiere} auprès de '
        '{universite}. Nous allons examiner votre dossier et vous contacter '
        'ici si des précisions sont nécessaires.\n\nL’équipe Academia',
  ),
  ApplicationMessageTemplate(
    label: 'Dossier transmis',
    target: 'student',
    body: 'Bonjour {nom},\n\n'
        'Votre dossier de candidature pour {filiere} a été transmis à '
        '{universite}. Nous vous informerons ici dès réception de leur '
        'réponse.\n\nL’équipe Academia',
  ),
  ApplicationMessageTemplate(
    label: 'Réponse défavorable',
    target: 'student',
    body: 'Bonjour {nom},\n\n'
        'Nous sommes désolés de vous informer que {universite} n’a pas '
        'retenu votre candidature pour {filiere}. Vous pouvez nous répondre '
        'ici pour échanger sur les autres possibilités de formation.\n\n'
        'L’équipe Academia',
  ),
  ApplicationMessageTemplate(
    label: 'Acceptation et paiement',
    target: 'student',
    body: 'Bonjour {nom},\n\n'
        'Félicitations, votre candidature pour {filiere} auprès de '
        '{universite} a été acceptée.\n\n'
        'Prochaines étapes :\n'
        '1. Ouvrez l’application et allez dans « Mes paiements ».\n'
        '2. Réglez les frais de courtage indiqués par mobile money.\n'
        '3. Après confirmation, retrouvez le reçu et le bon de courtage '
        'dans « Mes documents ».\n'
        '4. Présentez le reçu ET le bon de courtage à la scolarité de '
        'l’université pour officialiser votre inscription.\n\n'
        'Important : les conditions négociées sont temporaires et les '
        'places ne sont pas garanties indéfiniment. Vous disposez de '
        '7 jours à compter de ce message pour payer et finaliser votre '
        'inscription. Passé ce délai, l’offre pourra être réévaluée.\n\n'
        'L’équipe Academia',
  ),
  ApplicationMessageTemplate(
    label: 'Transmettre le dossier',
    target: 'university',
    body: 'Bonjour,\n\n'
        'Nous vous transmettons la candidature de {nom} pour {filiere} '
        'auprès de {universite}. Merci de consulter le dossier dans votre '
        'espace et de nous communiquer votre réponse ainsi que les '
        'conditions proposées.\n\nL’équipe Academia',
  ),
  ApplicationMessageTemplate(
    label: 'Réponse reçue',
    target: 'university',
    body: 'Bonjour,\n\n'
        'Nous accusons réception de votre réponse concernant la candidature '
        'de {nom} pour {filiere} auprès de {universite}. Nous allons '
        'informer le candidat et assurer le suivi avec lui.\n\n'
        'L’équipe Academia',
  ),
  ApplicationMessageTemplate(
    label: 'Suivi et relance',
    target: 'student',
    body: 'Bonjour {nom},\n\n'
        'Nous revenons vers vous au sujet de votre candidature pour '
        '{filiere} auprès de {universite}. Êtes-vous toujours intéressé(e) '
        'par cette formation ? Merci de nous répondre ici et de nous '
        'signaler toute difficulté pour poursuivre vos démarches.\n\n'
        'L’équipe Academia',
  ),
];
