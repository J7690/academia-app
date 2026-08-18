import 'package:phone_numbers_parser/phone_numbers_parser.dart';

/// Règles de numérotation utilisées par l'inscription et la connexion par
/// téléphone.
///
/// Un seul pays est ouvert aujourd'hui (Burkina Faso). Ouvrir un pays de plus
/// consiste à ajouter une entrée dans [kSupportedPhoneCountries] : la
/// validation, elle, ne bouge pas. Elle délègue à `phone_numbers_parser`, qui
/// embarque les plans de numérotation officiels (libphonenumber) — on ne
/// réécrit donc jamais à la main les préfixes d'un opérateur.
class PhoneCountry {
  const PhoneCountry({
    required this.isoCode,
    required this.dialCode,
    required this.flag,
    required this.label,
    required this.nsnLength,
    required this.hint,
  });

  /// Code ISO passé au parseur pour qu'il applique le bon plan de numérotation.
  final IsoCode isoCode;

  /// Indicatif international, sans le « + ». Exemple : « 226 ».
  final String dialCode;

  /// Drapeau affiché à gauche du champ.
  final String flag;

  /// Nom du pays, utilisé dans les messages d'erreur.
  final String label;

  /// Nombre de chiffres du numéro national, hors indicatif.
  final int nsnLength;

  /// Exemple de saisie affiché dans le champ vide.
  final String hint;

  /// Indicatif prêt à afficher. Exemple : « +226 ».
  String get dialPrefix => '+$dialCode';
}

const PhoneCountry kBurkinaFaso = PhoneCountry(
  isoCode: IsoCode.BF,
  dialCode: '226',
  flag: '\u{1F1E7}\u{1F1EB}',
  label: 'Burkina Faso',
  nsnLength: 8,
  hint: '7X XX XX XX',
);

/// Pays proposés dans le sélecteur d'indicatif, dans l'ordre d'affichage.
const List<PhoneCountry> kSupportedPhoneCountries = <PhoneCountry>[
  kBurkinaFaso,
];

/// Résultat d'une vérification de numéro : soit un E.164 exploitable, soit un
/// message d'erreur prêt à afficher. Jamais les deux.
class PhoneCheck {
  const PhoneCheck.valid(String this.e164) : error = null;
  const PhoneCheck.invalid(String this.error) : e164 = null;

  /// Numéro au format E.164 (« +22670000000 »). Non nul si le numéro est bon.
  final String? e164;

  /// Message destiné à l'utilisateur. Non nul si le numéro est mauvais.
  final String? error;

  bool get isValid => e164 != null;
}

/// Ne conserve que les chiffres et retire l'indicatif si l'utilisateur l'a
/// saisi lui-même (cas fréquent : on colle un numéro copié depuis WhatsApp).
String normalizePhoneInput(String input, PhoneCountry country) {
  var digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.length > country.nsnLength &&
      digits.startsWith(country.dialCode)) {
    digits = digits.substring(country.dialCode.length);
  }
  return digits;
}

/// Vérifie un numéro saisi pour [country] et renvoie son E.164.
///
/// La longueur est vérifiée avant le parseur : c'est elle qui produit le
/// message le plus utile pour l'utilisateur (« il manque un chiffre »). Si le
/// parseur lève une exception, on ne bloque pas l'inscription pour autant :
/// la vérification de longueur fait alors foi. Refuser un étudiant réel à
/// cause d'une bibliothèque coûte plus cher qu'accepter un numéro douteux,
/// puisque aucun SMS n'est envoyé de toute façon.
PhoneCheck checkPhoneNumber(String input, PhoneCountry country) {
  final nsn = normalizePhoneInput(input, country);

  if (nsn.isEmpty) {
    return const PhoneCheck.invalid(
      'Veuillez saisir votre numéro de téléphone.',
    );
  }
  if (nsn.length != country.nsnLength) {
    return PhoneCheck.invalid(
      'Un numéro ${country.label} compte ${country.nsnLength} chiffres — '
      'vous en avez saisi ${nsn.length}.',
    );
  }

  try {
    final parsed = PhoneNumber.parse(nsn, callerCountry: country.isoCode);
    if (!parsed.isValid()) {
      return PhoneCheck.invalid(
        'Ce numéro ne correspond à aucun numéro ${country.label} existant.',
      );
    }
    final international = parsed.international;
    return PhoneCheck.valid(
      international.startsWith('+')
          ? international
          : '${country.dialPrefix}$nsn',
    );
  } catch (_) {
    return PhoneCheck.valid('${country.dialPrefix}$nsn');
  }
}
