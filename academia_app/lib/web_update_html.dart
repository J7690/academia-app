import 'dart:html' as html;

/// Affiche un message de mise à jour puis recharge la page.
Future<void> showUpdateAndReload() async {
  try {
    html.window.alert(
      'Une nouvelle version est disponible. Mise à jour en cours…',
    );
  } catch (_) {
    // Si l'alert échoue, on force tout de même le rechargement.
  }
  html.window.location.reload();
}
