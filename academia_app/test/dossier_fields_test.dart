import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/features/student/dossier_fields.dart';

/// Ce que le formulaire montre quand le serveur réclame un champ.
///
/// Le serveur ne renvoie QUE ce qu'il exige : depuis le 08/09 il ne réclame
/// plus que `last_diploma`. Ces essais fixent les trois cas qui comptent, et
/// dont deux ont failli casser en silence.
void main() {
  group('stepsForMissingFields', () {
    test('un seul champ exigé ouvre son étape, avec sa précision facultative', () {
      final steps = stepsForMissingFields(<String>['last_diploma']);

      expect(steps, hasLength(1), reason: 'une seule étape doit s ouvrir');
      expect(steps.single.title, 'Ton parcours');

      final cles = steps.single.fields.map((f) => f.key).toList();
      // La précision n'est JAMAIS dans missing_fields : sans la règle des
      // champs compagnons, elle serait invisible à jamais.
      expect(cles, <String>['last_diploma', 'last_diploma_detail']);
    });

    test('la précision est facultative, elle ne doit pas bloquer', () {
      final steps = stepsForMissingFields(<String>['last_diploma']);
      final detail = steps.single.fields
          .firstWhere((f) => f.key == 'last_diploma_detail');
      final diplome =
          steps.single.fields.firstWhere((f) => f.key == 'last_diploma');

      expect(detail.optional, isTrue);
      expect(diplome.optional, isFalse);
    });

    test('un facultatif seul n interrompt pas l étudiant', () {
      // Le serveur n'exige rien de cette étape : elle ne doit pas s'ouvrir
      // juste pour proposer un champ facultatif.
      expect(stepsForMissingFields(<String>['full_name'])
          .map((s) => s.title), isNot(contains('Ton parcours')));
      expect(stepsForMissingFields(<String>[]), isEmpty);
    });

    test('le dernier diplôme porte une liste de choix, pas une saisie libre', () {
      final steps = stepsForMissingFields(<String>['last_diploma']);
      final diplome =
          steps.single.fields.firstWhere((f) => f.key == 'last_diploma');
      expect(diplome.kind, DossierFieldKind.choice);
      expect(kDiplomaOptions, contains('Licence'));
      // Un élève de terminale doit pouvoir candidater.
      expect(kDiplomaOptions, contains("Aucun pour l'instant"));
    });

    test('un champ inconnu du formulaire est signalé, jamais ignoré', () {
      expect(unsupportedFields(<String>['last_diploma']), isEmpty);
      expect(unsupportedFields(<String>['champ_invente']),
          <String>['champ_invente']);
    });
  });
}
