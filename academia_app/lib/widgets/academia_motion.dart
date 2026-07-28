import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/academia_palette.dart';

/// Boîte à outils d'animation partagée par les onglets étudiants.
///
/// Trois principes :
///   1. **Rien de gratuit.** Chaque animation sert à comprendre — d'où vient
///      un élément, qu'un appui a été pris en compte, qu'un chargement est en
///      cours. Une animation qui n'explique rien fatigue dès la dixième
///      ouverture.
///   2. **Court.** 220 à 380 ms. Au-delà, l'utilisateur attend l'interface.
///   3. **Désactivable.** Tout respecte `MediaQuery.disableAnimations`
///      (« Réduire les animations » du système). Le rendu final est identique,
///      seule la transition disparaît.
class AcademiaMotion {
  const AcademiaMotion._();

  static const Duration fast = Duration(milliseconds: 220);
  static const Duration base = Duration(milliseconds: 360);
  static const Duration slow = Duration(milliseconds: 620);

  /// Décalage entre deux éléments d'une même cascade.
  static const Duration stagger = Duration(milliseconds: 55);

  /// Au-delà, on cesse de décaler : sinon le dernier élément d'une longue
  /// liste apparaîtrait plusieurs secondes après le premier.
  static const int staggerCap = 7;

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  static Duration delayFor(int index) =>
      stagger * (index > staggerCap ? staggerCap : index);
}

enum AcademiaEntranceFrom { bottom, left, right, none }

/// Entrée en cascade d'un élément de liste ou de grille.
///
/// Passer l'index de l'élément : le décalage est calculé automatiquement.
class AcademiaEntrance extends StatelessWidget {
  const AcademiaEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.from = AcademiaEntranceFrom.bottom,
    this.duration,
    this.distance = 16,
  });

  final Widget child;
  final int index;
  final AcademiaEntranceFrom from;
  final Duration? duration;
  final double distance;

  @override
  Widget build(BuildContext context) {
    if (AcademiaMotion.reduced(context)) return child;

    final delay = AcademiaMotion.delayFor(index);
    final d = duration ?? AcademiaMotion.base;

    switch (from) {
      case AcademiaEntranceFrom.bottom:
        return FadeInUp(
          from: distance,
          delay: delay,
          duration: d,
          child: child,
        );
      case AcademiaEntranceFrom.left:
        return FadeInLeft(
          from: distance,
          delay: delay,
          duration: d,
          child: child,
        );
      case AcademiaEntranceFrom.right:
        return FadeInRight(
          from: distance,
          delay: delay,
          duration: d,
          child: child,
        );
      case AcademiaEntranceFrom.none:
        return FadeIn(delay: delay, duration: d, child: child);
    }
  }
}

/// Retour tactile : la carte s'enfonce légèrement sous le doigt.
///
/// C'est la micro-animation qui change le plus la perception de réactivité,
/// parce qu'elle répond avant même que la navigation ne démarre.
class AcademiaTapScale extends StatefulWidget {
  const AcademiaTapScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<AcademiaTapScale> createState() => _AcademiaTapScaleState();
}

class _AcademiaTapScaleState extends State<AcademiaTapScale> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value && mounted) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;

    final reduced = AcademiaMotion.reduced(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: reduced ? null : (_) => _set(true),
      onTapUp: reduced ? null : (_) => _set(false),
      onTapCancel: reduced ? null : () => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Compteur qui monte de 0 à [value].
///
/// Utilisé dans les en-têtes : le chiffre qui s'anime attire l'œil sur la
/// progression de l'étudiant, ce qu'un nombre statique ne fait pas.
class AcademiaCountUp extends StatelessWidget {
  const AcademiaCountUp({
    super.key,
    required this.value,
    required this.style,
    this.suffix = '',
  });

  final int value;
  final TextStyle style;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    if (AcademiaMotion.reduced(context) || value == 0) {
      return Text('$value$suffix', style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: AcademiaMotion.slow,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}$suffix', style: style),
    );
  }
}

/// Bascule animée entre deux contenus (bouton qui apparaît, état qui change).
///
/// Fondu + léger zoom, jamais d'animation de taille : une transition de
/// hauteur sur un contenu volumineux provoque un recalcul de mise en page à
/// chaque image, et c'est la première source de saccades.
///
/// Les enfants doivent porter une `Key` distincte pour que la bascule soit
/// détectée.
class AcademiaSwitcher extends StatelessWidget {
  const AcademiaSwitcher({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (AcademiaMotion.reduced(context)) return child;
    return AnimatedSwitcher(
      duration: AcademiaMotion.fast,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Transition d'écran commune aux onglets étudiants.
///
/// Fondu + montée de 4 % : plus doux que le glissement latéral par défaut,
/// et cohérent avec les entrées en cascade des listes.
class AcademiaPageRoute<T> extends PageRouteBuilder<T> {
  AcademiaPageRoute({required this.builder, super.settings})
      : super(
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 240),
          pageBuilder: (context, _, __) => builder(context),
          transitionsBuilder: (context, animation, _, child) {
            if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
              return child;
            }
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );

  final WidgetBuilder builder;
}

// ─────────────────────────────────────────────────────────────────────────
// Squelettes de chargement
//
// Un squelette qui épouse la mise en page finale est perçu comme nettement
// plus rapide qu'un indicateur circulaire, et il supprime le saut de contenu
// au moment où les données arrivent.
// ─────────────────────────────────────────────────────────────────────────

/// Enveloppe shimmer. Un seul par écran : le dégradé reste ainsi synchronisé
/// sur toutes les formes, ce qui évite l'effet « guirlande ».
class AcademiaShimmer extends StatelessWidget {
  const AcademiaShimmer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (AcademiaMotion.reduced(context)) {
      return Opacity(opacity: 0.55, child: child);
    }
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8EAF0),
      highlightColor: const Color(0xFFF7F8FA),
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }
}

/// Forme grise élémentaire.
class AcademiaSkeletonBox extends StatelessWidget {
  const AcademiaSkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

/// Squelette d'une carte à couverture (catalogue de cours, replay).
class AcademiaSkeletonCard extends StatelessWidget {
  const AcademiaSkeletonCard({
    super.key,
    this.coverHeight = 92,
    this.lines = 2,
  });

  final double coverHeight;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AcademiaPalette.surface,
        borderRadius: BorderRadius.circular(AcademiaPalette.rLg),
        border: Border.all(color: AcademiaPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AcademiaSkeletonBox(
            height: coverHeight,
            width: double.infinity,
            radius: AcademiaPalette.rLg,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < lines; i++) ...[
                  AcademiaSkeletonBox(
                    height: 10,
                    width: i == lines - 1 ? 90 : double.infinity,
                  ),
                  const SizedBox(height: 7),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    const AcademiaSkeletonBox(height: 12, width: 58),
                    const Spacer(),
                    const AcademiaSkeletonBox(height: 24, width: 52, radius: 9),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Squelette de grille — catalogue de cours, replays.
class AcademiaSkeletonGrid extends StatelessWidget {
  const AcademiaSkeletonGrid({
    super.key,
    this.count = 4,
    this.columns = 2,
    this.extent = 218,
    this.coverHeight = 92,
  });

  final int count;
  final int columns;
  final double extent;
  final double coverHeight;

  @override
  Widget build(BuildContext context) {
    return AcademiaShimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: extent,
          ),
          itemCount: count,
          itemBuilder: (_, __) =>
              AcademiaSkeletonCard(coverHeight: coverHeight),
        ),
      ),
    );
  }
}

/// Squelette de rail horizontal — bloc « Reprendre ».
class AcademiaSkeletonRail extends StatelessWidget {
  const AcademiaSkeletonRail({super.key, this.height = 214, this.width = 262});

  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return AcademiaShimmer(
      child: SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 2,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) => SizedBox(
            width: width,
            child: const AcademiaSkeletonCard(coverHeight: 104, lines: 2),
          ),
        ),
      ),
    );
  }
}

/// Squelette de cartes empilées — séances, ressources, conseillers.
class AcademiaSkeletonList extends StatelessWidget {
  const AcademiaSkeletonList({
    super.key,
    this.count = 3,
    this.height = 108,
  });

  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    return AcademiaShimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            for (var i = 0; i < count; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: AcademiaPalette.surface,
                    borderRadius:
                        BorderRadius.circular(AcademiaPalette.rMd),
                    border: Border.all(color: AcademiaPalette.border),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AcademiaSkeletonBox(
                          height: 14, width: 62, radius: 999),
                      const SizedBox(height: 10),
                      const AcademiaSkeletonBox(height: 11),
                      const SizedBox(height: 7),
                      const AcademiaSkeletonBox(height: 9, width: 140),
                      const Spacer(),
                      Row(
                        children: const [
                          AcademiaSkeletonBox(
                              height: 24, width: 84, radius: 9),
                          SizedBox(width: 7),
                          AcademiaSkeletonBox(
                              height: 24, width: 62, radius: 9),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
