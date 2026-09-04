import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/push_notification_service.dart';

/// Le bouton « Se déconnecter », à poser dans la barre du haut de chaque
/// tableau de bord — à côté de l'engrenage, pas à l'intérieur.
///
/// **Pourquoi ce composant existe.** La déconnexion existait déjà pour tous les
/// rôles : les neuf tableaux de bord (étudiant, admin, commercial, enseignant,
/// gestionnaire, marchand, conseiller, université) ouvrent le même
/// `StudentSettingsScreen`, qui la porte. Mais elle y était **enfouie** : il
/// fallait ouvrir les paramètres, faire défiler, puis la trouver. Un utilisateur
/// qui veut quitter son compte doit pouvoir le faire depuis l'écran où il est.
///
/// **Elle reste dans les paramètres.** Ce bouton s'ajoute, il ne remplace rien :
/// l'habitude de ceux qui la cherchent là-bas n'est pas cassée.
///
/// **Pourquoi un composant partagé plutôt que neuf copies.** La déconnexion
/// n'est pas qu'un `signOut` : il faut d'abord retirer l'appareil du compte,
/// sinon il continue de recevoir les notifications de l'utilisateur parti.
/// Recopier cette séquence neuf fois, c'est se garantir qu'une copie l'oubliera.
class BoutonDeconnexion extends StatelessWidget {
  const BoutonDeconnexion({super.key, this.couleur, this.compact = false});

  /// Couleur de l'icône. À laisser nulle dans une `AppBar` colorée : elle
  /// hérite alors du thème, comme les autres actions de la barre.
  final Color? couleur;

  /// Réduit la zone tactile — pour les barres déjà chargées, comme l'en-tête
  /// mobile de l'étudiant qui porte déjà l'avatar, le partage et le menu.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Se déconnecter',
      icon: Icon(Icons.logout, color: couleur),
      visualDensity: compact ? VisualDensity.compact : null,
      constraints: compact
          ? const BoxConstraints(minWidth: 36, minHeight: 36)
          : null,
      padding: compact ? EdgeInsets.zero : null,
      onPressed: () => confirmerEtSeDeconnecter(context),
    );
  }
}

/// Demande confirmation, puis déconnecte et renvoie à l'écran d'accueil.
///
/// Exposée séparément pour les endroits qui ne veulent pas d'un `IconButton` —
/// une entrée de menu, par exemple. Ne lance pas : une erreur de déconnexion
/// est signalée à l'utilisateur plutôt qu'avalée.
Future<void> confirmerEtSeDeconnecter(BuildContext context) async {
  final navigateur = Navigator.of(context);
  final messager = ScaffoldMessenger.of(context);

  final confirme = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Déconnexion'),
      content: const Text('Voulez-vous vraiment vous déconnecter ?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text(
            'Se déconnecter',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );

  if (confirme != true) return;

  try {
    // AVANT la déconnexion : retirer l'appareil du compte, sinon il continue
    // d'en recevoir les notifications indéfiniment.
    await PushNotificationService.instance.unregisterTokenBeforeLogout();
    await Supabase.instance.client.auth.signOut();
    navigateur.pushNamedAndRemoveUntil('/', (route) => false);
  } catch (e) {
    // Un échec muet laisserait l'utilisateur croire qu'il est parti alors que
    // sa session est toujours ouverte — sur un téléphone partagé, c'est grave.
    messager.showSnackBar(
      SnackBar(content: Text('La déconnexion a échoué : $e')),
    );
  }
}
