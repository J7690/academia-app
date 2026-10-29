import 'dart:html' as html;

/// Affiche une notification système du navigateur.
///
/// Sur le web, Firebase ne montre rien quand l'onglet est au premier plan :
/// le message arrive dans `onMessage` et c'est à l'application de l'afficher.
/// Le service worker ne prend la main que lorsque l'onglet est en arrière-plan.
/// Sans ce geste, un administrateur qui garde la console ouverte ne voyait
/// aucune alerte — support, candidatures, comptes créés.
void afficherNotificationNavigateur(
  String titre,
  String corps, {
  void Function()? auClic,
}) {
  try {
    if (!html.Notification.supported) return;
    if (html.Notification.permission != 'granted') return;
    final notification = html.Notification(
      titre,
      body: corps,
      icon: 'icons/Icon-192.png',
    );
    notification.onClick.listen((_) {
      notification.close();
      auClic?.call();
    });
  } catch (_) {
    // Une alerte qui ne s'affiche pas ne doit jamais casser l'application.
  }
}
