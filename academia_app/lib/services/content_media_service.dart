// Sélection automatique de l'implémentation selon la plateforme :
// - mobile/desktop : content_media_service_io.dart (dart:io, galerie, partage fichier)
// - web            : content_media_service_web.dart (sans dart:io)
export 'content_media_service_io.dart'
    if (dart.library.html) 'content_media_service_web.dart';
