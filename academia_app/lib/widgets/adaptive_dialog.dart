import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Boîtes de dialogue et feuilles adaptatives.
///
/// Objectif : plus aucune boîte de dialogue figée. Le contenu est toujours
/// scrollable, la hauteur maximale suit la hauteur réelle disponible (clavier
/// ouvert compris) et les boutons d'action restent visibles et atteignables
/// sur téléphone, tablette, ordinateur et application installée (PWA).
class AdaptiveDialog extends StatefulWidget {
  const AdaptiveDialog({
    super.key,
    this.title,
    required this.child,
    this.actions = const <Widget>[],
    this.maxWidth = 560,
    this.scrollController,
  });

  final Widget? title;
  final Widget child;
  final List<Widget> actions;

  /// Largeur maximale souhaitée sur grand écran. Sur petit écran la boîte
  /// occupe la largeur disponible moins les marges.
  final double maxWidth;

  final ScrollController? scrollController;

  @override
  State<AdaptiveDialog> createState() => _AdaptiveDialogState();
}

class _AdaptiveDialogState extends State<AdaptiveDialog> {
  ScrollController? _fallbackController;

  ScrollController get _controller =>
      widget.scrollController ??
      (_fallbackController ??= ScrollController());

  @override
  void dispose() {
    _fallbackController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final actions = widget.actions;
    final media = MediaQuery.of(context);
    final size = media.size;
    final keyboard = media.viewInsets.bottom;
    final isCompact = size.width < 600;

    // Marges extérieures relatives : jamais de valeur figée.
    final horizontalInset = isCompact ? 16.0 : math.max(24.0, size.width * 0.06);
    final verticalInset = math.max(16.0, size.height * 0.04);

    // Hauteur réellement disponible une fois le clavier déduit.
    final availableHeight =
        math.max(180.0, size.height - keyboard - verticalInset * 2);
    final availableWidth = math.max(280.0, size.width - horizontalInset * 2);

    final theme = Theme.of(context);

    return Dialog(
      insetPadding: EdgeInsets.fromLTRB(
        horizontalInset,
        verticalInset,
        horizontalInset,
        verticalInset + keyboard,
      ),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isCompact ? 16 : 20),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(widget.maxWidth, availableWidth),
          maxHeight: availableHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isCompact ? 16 : 24,
                  isCompact ? 16 : 24,
                  isCompact ? 16 : 24,
                  8,
                ),
                child: DefaultTextStyle.merge(
                  style: theme.textTheme.titleLarge,
                  child: title,
                ),
              ),
            // Le contenu prend la place restante et scrolle toujours.
            Flexible(
              child: Scrollbar(
                controller: _controller,
                child: SingleChildScrollView(
                  controller: _controller,
                  primary: false,
                  padding: EdgeInsets.fromLTRB(
                    isCompact ? 16 : 24,
                    title == null ? (isCompact ? 16 : 24) : 0,
                    isCompact ? 16 : 24,
                    8,
                  ),
                  child: widget.child,
                ),
              ),
            ),
            if (actions.isNotEmpty)
              _AdaptiveDialogActions(
                actions: actions,
                isCompact: isCompact,
              ),
          ],
        ),
      ),
    );
  }
}

class _AdaptiveDialogActions extends StatelessWidget {
  const _AdaptiveDialogActions({
    required this.actions,
    required this.isCompact,
  });

  final List<Widget> actions;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isCompact ? 12 : 20,
            8,
            isCompact ? 12 : 20,
            isCompact ? 12 : 16,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Sur écran étroit les boutons s'empilent en pleine largeur
              // au lieu d'être coupés sur la droite.
              if (constraints.maxWidth < 360) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = actions.length - 1; i >= 0; i--) ...[
                      actions[i],
                      if (i > 0) const SizedBox(height: 8),
                    ],
                  ],
                );
              }
              return Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: actions,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Affiche une [AdaptiveDialog]. Remplace `showDialog` + `AlertDialog`.
Future<T?> showAdaptiveAppDialog<T>({
  required BuildContext context,
  Widget? title,
  required WidgetBuilder builder,
  List<Widget> Function(BuildContext context)? actionsBuilder,
  double maxWidth = 560,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    // Indispensable pour que la boîte se redimensionne à l'ouverture du clavier.
    useSafeArea: true,
    builder: (dialogContext) {
      return AdaptiveDialog(
        title: title,
        maxWidth: maxWidth,
        actions: actionsBuilder?.call(dialogContext) ?? const <Widget>[],
        child: builder(dialogContext),
      );
    },
  );
}

/// Feuille modale adaptative (utile quand le contenu est long sur téléphone).
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxWidth = 720,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: BoxConstraints(maxWidth: maxWidth),
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      return Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: media.size.height * 0.9,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: builder(sheetContext),
          ),
        ),
      );
    },
  );
}
