class HeroTvTemplate {
  final String code;
  final String label;
  final String description;
  final List<Map<String, dynamic>> overlays;

  const HeroTvTemplate({
    required this.code,
    required this.label,
    required this.description,
    required this.overlays,
  });
}

const List<HeroTvTemplate> kHeroTvTemplates = <HeroTvTemplate>[
  HeroTvTemplate(
    code: 'academia_news_live',
    label: 'Academia News Live',
    description: 'Ticker d\'actu en bas + bandeau titre court au début.',
    overlays: <Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'ticker',
        'start_at_seconds': 0,
        'end_at_seconds': 60,
        'text': 'Dernières actualités du campus · Nouveaux challenges · Résultats des concours · Événements en direct',
        'align': 'bottom_center',
        'speed': 120,
        'sort_order': 0,
      },
      <String, dynamic>{
        'type': 'lower_third',
        'start_at_seconds': 1,
        'end_at_seconds': 8,
        'text': 'Academia News Live',
        'align': 'bottom_left',
        'animation': 'fade',
        'fade_in_duration': 0.4,
        'fade_out_duration': 0.6,
        'sort_order': 1,
      },
    ],
  ),
  HeroTvTemplate(
    code: 'challenge_spotlight',
    label: 'Challenge Spotlight',
    description: 'Titre principal centré + rappel du challenge en bas.',
    overlays: <Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'text',
        'start_at_seconds': 0,
        'end_at_seconds': 6,
        'text': 'Challenge du moment',
        'align': 'center',
        'animation': 'fade',
        'fade_in_duration': 0.6,
        'fade_out_duration': 0.8,
        'sort_order': 0,
      },
      <String, dynamic>{
        'type': 'lower_third',
        'start_at_seconds': 2,
        'end_at_seconds': 12,
        'text': 'Participez et gagnez des récompenses sur Academia',
        'align': 'bottom_left',
        'sort_order': 1,
      },
    ],
  ),
  HeroTvTemplate(
    code: 'simple_banner',
    label: 'Bandeau simple',
    description: 'Bandeau fixe en bas pour un message important.',
    overlays: <Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'lower_third',
        'start_at_seconds': 0,
        'end_at_seconds': 20,
        'text': 'Message important aux étudiants',
        'align': 'bottom_center',
        'sort_order': 0,
      },
    ],
  ),
];
