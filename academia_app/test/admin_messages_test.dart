import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/providers/admin_user_invitations_provider.dart';

/// Ce que l'administrateur LIT quand une création de compte échoue.
///
/// Mesure du 09/09 : trois tentatives ont échoué pour trois raisons
/// distinctes — adresse déjà prise, adresse mal formée — et l'écran affichait
/// le même code technique pour toutes. Une erreur qu'on ne peut pas nommer est
/// une erreur qu'on ne peut pas corriger.
void main() {
  String msg(String? code) =>
      AdminUserInvitationsProvider.messageLisible(code, quoi: 'du compte test');

  group('messages d erreur de creation de compte', () {
    test('une adresse deja prise le dit, et dit quoi faire', () {
      final m = msg('email_deja_utilise');
      expect(m, contains('déjà utilisée'));
      // Le contournement que Jocelyn a du trouver seul : promouvoir le compte.
      expect(m.toLowerCase(), contains('change de rôle'));
    });

    test('une adresse mal formee nomme la cause probable', () {
      final m = msg('email_invalide');
      expect(m, contains("n'est pas valide"));
      expect(m, contains('espace'));
    });

    test('un mot de passe trop court donne la longueur exigee', () {
      expect(msg('mot_de_passe_trop_court'), contains('6 caractères'));
    });

    test('une session expiree dit de se reconnecter', () {
      expect(msg('not_authenticated'), contains('Reconnecte-toi'));
    });

    test('un code inconnu reste affiche, jamais avale', () {
      // On preferera toujours un code technique visible a un silence : c'est
      // ce qui permet de diagnostiquer un cas qu'on n'avait pas prevu.
      expect(msg('code_jamais_vu'), contains('code_jamais_vu'));
    });

    test('sans code, le message reste comprehensible', () {
      expect(msg(null), contains('du compte test'));
      expect(msg(null), isNot(contains('null')));
    });
  });
}
