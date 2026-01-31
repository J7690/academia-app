import 'dart:async';

import 'package:flutter/material.dart';

import '../video/academia_playback_engine.dart';

/// Modèle minimal pour un média de héros (image ou vidéo).
class HeroMediaItem {
  final String id;
  final String mediaType; // 'image' ou 'video'
  final String url; // URL effective à lire (image ou vidéo)
  final String? posterUrl; // Optionnel : image d'aperçu pour les vidéos
  final int? durationMs; // Durée d'affichage pour les images (et éventuellement override vidéo)
  final int sortOrder;

  const HeroMediaItem({
    required this.id,
    required this.mediaType,
    required this.url,
    this.posterUrl,
    this.durationMs,
    required this.sortOrder,
  });

  bool get isVideo => mediaType.toLowerCase() == 'video';

  bool get isImage => mediaType.toLowerCase() == 'image';
}

/// Carrousel réutilisable pour les héros (landing, home étudiant, mini-site).
///
/// - Affiche les images avec un timer.
/// - Affiche les vidéos avec AcademiaPlaybackEngine.view.
/// - Gère un timeout de démarrage vidéo pour éviter les blocages sur réseaux lents.
class HeroMediaCarousel extends StatefulWidget {
  const HeroMediaCarousel({
    super.key,
    required this.items,
    this.aspectRatio = 16 / 9,
    this.defaultImageDuration = const Duration(seconds: 5),
    this.videoStartTimeout = const Duration(seconds: 5),
    this.loopVideos = false,
    this.autoplay = true,
    this.mutedByDefault = true,
    this.showControls = false,
    this.overlayBuilder,
    this.useAspectRatio = true,
  });

  /// Liste des médias à afficher.
  final List<HeroMediaItem> items;

  /// Ratio d'aspect du conteneur hero.
  final double aspectRatio;

  /// Durée par défaut pour les images si aucune durée spécifique n'est fournie.
  final Duration defaultImageDuration;

  /// Timeout maximum pour le démarrage d'une vidéo avant de passer à la suivante.
  final Duration videoStartTimeout;

  /// Faut-il boucler les vidéos ? Pour les héros, false par défaut.
  final bool loopVideos;

  /// Démarrage automatique des vidéos.
  final bool autoplay;

  /// Muet par défaut pour les vidéos.
  final bool mutedByDefault;

  /// Afficher les contrôles vidéo natifs.
  final bool showControls;

   /// Builder optionnel pour superposer un overlay par-dessus le média courant.
   /// Utile pour les titres, badges, dégradés, boutons de partage, etc.
   final Widget Function(BuildContext context, HeroMediaItem? currentItem)?
       overlayBuilder;

   /// Si true, le widget applique un AspectRatio autour du contenu.
   /// Si false, il occupe tout l'espace disponible du parent.
   final bool useAspectRatio;

  @override
  State<HeroMediaCarousel> createState() => _HeroMediaCarouselState();
}

class _HeroMediaCarouselState extends State<HeroMediaCarousel>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  Timer? _imageTimer;
  Timer? _videoStartTimer;
  bool _videoCompleted = false;
  bool _appInForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCurrentItem();
  }

  @override
  void didUpdateWidget(HeroMediaCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _currentIndex = 0;
      _restartTimers();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelTimers();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isForeground =
        state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;
    if (isForeground != _appInForeground) {
      _appInForeground = isForeground;
      if (_appInForeground) {
        _restartTimers();
      } else {
        _cancelTimers();
      }
    }
  }

  void _cancelTimers() {
    _imageTimer?.cancel();
    _imageTimer = null;
    _videoStartTimer?.cancel();
    _videoStartTimer = null;
  }

  void _restartTimers() {
    _cancelTimers();
    _startCurrentItem();
  }

  void _startCurrentItem() {
    if (!_appInForeground) {
      return;
    }
    if (widget.items.isEmpty) {
      return;
    }

    final item = widget.items[_currentIndex % widget.items.length];
    _videoCompleted = false;

    if (item.isImage) {
      final imageDuration =
          item.durationMs != null && item.durationMs! > 0
              ? Duration(milliseconds: item.durationMs!)
              : widget.defaultImageDuration;

      _imageTimer = Timer(imageDuration, _goToNext);
    } else if (item.isVideo) {
      // Timeout pour éviter de rester bloqué sur une vidéo qui ne démarre pas.
      _videoStartTimer = Timer(widget.videoStartTimeout, () {
        if (!_videoCompleted) {
          _goToNext();
        }
      });
    }
  }

  void _goToNext() {
    if (!mounted || widget.items.isEmpty) {
      return;
    }
    _cancelTimers();
    setState(() {
      _currentIndex = (_currentIndex + 1) % widget.items.length;
    });
    _startCurrentItem();
  }

  void _handleVideoCompleted() {
    _videoCompleted = true;
    _goToNext();
  }

  @override
  Widget build(BuildContext context) {
    // Cas sans médias : placeholder simple, avec overlay éventuel.
    if (widget.items.isEmpty) {
      Widget content = const ColoredBox(
        color: Colors.black12,
        child: Center(
          child: Icon(Icons.image_outlined, color: Colors.black45),
        ),
      );

      if (widget.overlayBuilder != null) {
        content = Stack(
          fit: StackFit.expand,
          children: [
            content,
            widget.overlayBuilder!(context, null),
          ],
        );
      }

      if (widget.useAspectRatio) {
        content = AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: content,
        );
      }

      return content;
    }

    final item = widget.items[_currentIndex % widget.items.length];

    Widget content = _buildMediaItem(context, item);

    if (widget.overlayBuilder != null) {
      content = Stack(
        fit: StackFit.expand,
        children: [
          content,
          widget.overlayBuilder!(context, item),
        ],
      );
    }

    content = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: content,
    );

    if (widget.useAspectRatio) {
      content = AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: content,
      );
    }

    return content;
  }

  Widget _buildMediaItem(BuildContext context, HeroMediaItem item) {
    if (item.isVideo) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (item.posterUrl != null && item.posterUrl!.trim().isNotEmpty)
            Image.network(
              item.posterUrl!,
              fit: BoxFit.cover,
            ),
          AcademiaPlaybackEngine.view(
            url: item.url,
            autoplay: widget.autoplay,
            looping: widget.loopVideos,
            muted: widget.mutedByDefault,
            showControls: widget.showControls,
            fit: BoxFit.cover,
            onCompleted: _handleVideoCompleted,
          ),
        ],
      );
    }

    // Image simple avec timer.
    return Image.network(
      item.url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const ColoredBox(
          color: Colors.black12,
          child: Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.black45),
          ),
        );
      },
    );
  }
}
