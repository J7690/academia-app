import 'package:flutter/material.dart';

/// Palette et mises en forme du module d'orientation.
///
/// Regrouper ces constantes évite que chaque écran redéclare ses couleurs et
/// ses bordures — c'est ce qui produit, à la longue, des interfaces qui se
/// ressemblent sans jamais être identiques.
class OrientationTheme {
  const OrientationTheme._();

  static const accent = Color(0xFF6C5CE7);
  static const teal = Color(0xFF12B886);
  static const red = Color(0xFFE14D4D);
  static const amber = Color(0xFFF0A020);
  static const amberDark = Color(0xFFB07510);

  static const background = Color(0xFFF5F6F8);
  static const surface = Colors.white;
  static const surfaceMuted = Color(0xFFF7F8FA);
  static const border = Color(0xFFE2E5EA);

  static const text = Color(0xFF14161A);
  static const textSecondary = Color(0xFF5C6270);
  static const textMuted = Color(0xFF8A90A0);

  static BoxDecoration get cardDecoration => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      );

  static BoxDecoration get sheetDecoration => const BoxDecoration(
        color: background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      );

  static const warningTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Color(0xFF7A5510),
  );

  static const warningBody = TextStyle(
    fontSize: 13,
    height: 1.5,
    color: Color(0xFF7A5510),
  );

  static const label = TextStyle(
    fontSize: 10.5,
    letterSpacing: 0.5,
    fontWeight: FontWeight.w500,
    color: textMuted,
  );
}

/// Libellés du domaine, au même endroit pour rester cohérents d'un écran à
/// l'autre — et traduisibles d'un seul geste le jour venu.
class OrientationLabels {
  const OrientationLabels._();

  static const kinds = <String, String>{
    'orientation': 'Orientation scolaire',
    'career': 'Orientation professionnelle',
    'etudes_etranger': 'Études à l\'étranger',
    'reconversion': 'Reconversion',
    'psychologue': 'Psychologue scolaire',
  };

  static const specialites = <String, String>{
    'filieres_scientifiques': 'Filières scientifiques',
    'filieres_litteraires': 'Filières littéraires',
    'concours_fonction_publique': 'Concours fonction publique',
    'etudes_superieures': 'Études supérieures',
    'ecoles_professionnelles': 'Écoles professionnelles',
    'bourses': 'Bourses',
  };

  static const langues = <String, String>{
    'fr': 'Français',
    'moore': 'Mooré',
    'dioula': 'Dioula',
    'fulfulde': 'Fulfuldé',
    'en': 'Anglais',
  };

  static const niveaux = <String, String>{
    'college': 'Collège',
    'seconde': 'Seconde',
    'premiere': 'Première',
    'terminale': 'Terminale',
    'licence': 'Licence',
    'master': 'Master',
  };

  static const jours = [
    'Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'
  ];

  static const joursCourts = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];

  static const mois = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
  ];

  static String kind(String? k) => kinds[k] ?? 'Conseiller';
  static String speciality(String s) => specialites[s] ?? _humanise(s);
  static String langue(String l) => langues[l] ?? l;
  static String niveau(String n) => niveaux[n] ?? _humanise(n);

  static String _humanise(String s) {
    final t = s.replaceAll('_', ' ');
    return t.isEmpty ? t : '${t[0].toUpperCase()}${t.substring(1)}';
  }

  static String _deuxChiffres(int v) => v.toString().padLeft(2, '0');

  /// « aujourd'hui à 14h30 », « demain à 09h00 », « 30 juillet à 16h00 ».
  static String dateComplete(DateTime d) {
    final maintenant = DateTime.now();
    final heure = '${_deuxChiffres(d.hour)}h${_deuxChiffres(d.minute)}';
    bool memeJour(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    if (memeJour(d, maintenant)) return "aujourd'hui à $heure";
    if (memeJour(d, maintenant.add(const Duration(days: 1)))) {
      return 'demain à $heure';
    }
    if (memeJour(d, maintenant.subtract(const Duration(days: 1)))) {
      return 'hier à $heure';
    }
    return '${d.day} ${mois[d.month - 1]} à $heure';
  }

  /// Séparateur de milliers par espace insécable étroit, usage francophone.
  static String montant(int valeur) {
    final s = valeur.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(s[i]);
    }
    return '${valeur < 0 ? '-' : ''}$buffer';
  }
}
