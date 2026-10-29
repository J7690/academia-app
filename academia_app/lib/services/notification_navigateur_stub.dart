// Stub pour les plateformes non-web : Android affiche déjà les notifications
// au premier plan par flutter_local_notifications.
void afficherNotificationNavigateur(
  String titre,
  String corps, {
  void Function()? auClic,
}) {}
