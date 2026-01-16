import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'screenshot_service.dart';
import 'share_mode_provider.dart';

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
