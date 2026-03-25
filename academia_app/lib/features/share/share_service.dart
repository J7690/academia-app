import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'screenshot_service.dart';
import 'share_mode_provider.dart';
import 'widgets/zone_selector.dart';

/// High-level orchestrator for screenshot-based sharing.
///
/// The concrete implementation (capture + native share sheet) will be
/// provided in a later phase of the feature.
class ShareService {
  ShareService({ScreenshotService? screenshotService})
      : _screenshotService = screenshotService ?? const ScreenshotService();

  final ScreenshotService _screenshotService;

  Future<void> shareCurrentView({
    required BuildContext context,
    required GlobalKey boundaryKey,
    String? shareText,
  }) async {
    final shareMode = context.read<ShareModeProvider>();

    await shareMode.runWithShareMode(() async {
      Uint8List bytes;

      try {
        bytes = await _screenshotService.captureRepaintBoundary(boundaryKey);
      } catch (e, st) {
        debugPrint('ShareService.capture error: $e\n$st');
        return;
      }

      final text = shareText ??
          'Découvert via Academia – Faciliter l’accès aux formations.';

      try {
        if (kIsWeb) {
          // Sur le Web, shareXFiles n'est pas supporté. On tente un partage
          // texte standard. Si le navigateur ne supporte pas l'API de partage,
          // l'appel échouera et on affichera un message utilisateur.
          await Share.share(text);
          return;
        }

        final xFile = XFile.fromData(
          bytes,
          mimeType: 'image/png',
          name: 'academia-share.png',
        );

        await Share.shareXFiles(
          [xFile],
          text: text,
        );
      } catch (e, st) {
        debugPrint('ShareService.share error: $e\n$st');

        if (kIsWeb) {
          // Donne un feedback explicite quand le partage système n'est pas
          // disponible dans le navigateur (cas typique de Chrome desktop).
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Le partage avancé est surtout disponible sur mobile (Android/iOS).',
                ),
              ),
            );
          } catch (_) {}
        }
      }
    });
  }

  /// Ouvre l'interface de sélection de zone et partage la zone sélectionnée.
  Future<void> shareSelectedZone({
    required BuildContext context,
    required GlobalKey boundaryKey,
    String? shareText,
  }) async {
    Rect? selectedRect;
    
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          // Créer une nouvelle clé pour le ZoneSelector
          final zoneBoundaryKey = GlobalKey();
          
          return Material(
            color: Colors.transparent,
            child: ZoneSelector(
              child: RepaintBoundary(
                key: zoneBoundaryKey,
                child: Builder(
                  builder: (builderContext) {
                    // Capturer le widget actuel dans le contexte
                    final RenderObject? renderObject = boundaryKey.currentContext?.findRenderObject();
                    if (renderObject is RenderRepaintBoundary) {
                      return SizedBox(
                        width: renderObject.size.width,
                        height: renderObject.size.height,
                        child: IgnorePointer(
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: RepaintBoundary(
                                  child: Builder(
                                    builder: (_) {
                                      // Utilise le contexte parent pour récupérer le contenu
                                      final scaffold = context.findAncestorWidgetOfExactType<Scaffold>();
                                      return scaffold ?? Container();
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return Container();
                  },
                ),
              ),
              onSelectionChanged: (rect) {
                selectedRect = rect;
              },
              onConfirm: () async {
                Navigator.of(dialogContext).pop();
                // Partager la zone sélectionnée après la fermeture du sélecteur
                if (selectedRect != null) {
                  await shareZoneCrop(
                    context: context,
                    boundaryKey: boundaryKey,
                    selectionRect: selectedRect!,
                    shareText: shareText,
                  );
                }
              },
              onCancel: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  /// Partage une zone spécifique capturée depuis un RepaintBoundary.
  Future<void> shareZoneCrop({
    required BuildContext context,
    required GlobalKey boundaryKey,
    required Rect selectionRect,
    String? shareText,
  }) async {
    final shareMode = context.read<ShareModeProvider>();

    await shareMode.runWithShareMode(() async {
      Uint8List bytes;

      try {
        bytes = await _screenshotService.captureRepaintBoundaryWithCrop(
          boundaryKey,
          selectionRect,
        );
      } catch (e, st) {
        debugPrint('ShareService.shareZoneCrop error: $e\n$st');
        return;
      }

      final text = shareText ??
          'Zone sélectionnée via Academia – Faciliter l\'accès aux formations.';

      try {
        if (kIsWeb) {
          // Sur le Web, on tente un partage texte standard
          await Share.share(text);
          return;
        }

        final xFile = XFile.fromData(
          bytes,
          mimeType: 'image/png',
          name: 'academia-zone-share.png',
        );

        await Share.shareXFiles(
          [xFile],
          text: text,
        );
      } catch (e, st) {
        debugPrint('ShareService.shareZoneCrop error: $e\n$st');

        if (kIsWeb) {
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Le partage avancé est surtout disponible sur mobile (Android/iOS).',
                ),
              ),
            );
          } catch (_) {}
        }
      }
    });
  }

  /// Affiche un dialogue éphémère contenant [card] dans un RepaintBoundary,
  /// déclenche le partage, puis ferme le dialogue.
  Future<void> shareCustomCard({
    required BuildContext context,
    required Widget card,
    String? shareText,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: _ShareCardDialog(
            card: card,
            shareService: this,
            shareText: shareText,
          ),
        );
      },
    );
  }

}

class _ShareCardDialog extends StatefulWidget {
  final Widget card;
  final ShareService shareService;
  final String? shareText;

  const _ShareCardDialog({
    required this.card,
    required this.shareService,
    this.shareText,
  });

  @override
  State<_ShareCardDialog> createState() => _ShareCardDialogState();
}

class _ShareCardDialogState extends State<_ShareCardDialog> {
  final GlobalKey _boundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.shareService.shareCurrentView(
        context: context,
        boundaryKey: _boundaryKey,
        shareText: widget.shareText,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RepaintBoundary(
        key: _boundaryKey,
        child: widget.card,
      ),
    );
  }
}
