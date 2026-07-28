import 'package:flutter/material.dart';

import '../theme/academia_palette.dart';
import 'academia_motion.dart';

/// Briques visuelles partagées entre les onglets Cours et Lives.
///
/// Elles reprennent strictement la palette « Ciel Academia » définie dans
/// [AcademiaPalette], elle-même alignée sur l'onglet Accueil.

// ─────────────────────────────────────────────────────────────────────────
// En-tête immersif
// ─────────────────────────────────────────────────────────────────────────

class AcademiaHeaderStat {
  const AcademiaHeaderStat(this.value, this.label, {this.animate = true});

  /// Valeur affichée. Si elle est purement numérique et [animate] est vrai,
  /// le chiffre monte de 0 à sa valeur à l'apparition de l'en-tête.
  final String value;
  final String label;
  final bool animate;

  int? get numericValue => int.tryParse(value);
}

class AcademiaHeader extends StatelessWidget {
  const AcademiaHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.gradient,
    this.stats = const [],
    this.trailing,
  });

  final String title;
  final String subtitle;
  final LinearGradient gradient;
  final List<AcademiaHeaderStat> stats;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(26),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: -80,
            child: _Bubble(size: 190, opacity: 0.10),
          ),
          Positioned(
            right: -100,
            bottom: -120,
            child: _Bubble(size: 210, opacity: 0.07),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    trailing!,
                  ],
                ],
              ),
              if (stats.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    for (var i = 0; i < stats.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: AcademiaEntrance(
                          index: i,
                          distance: 10,
                          child: _StatBox(stat: stats[i]),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      );
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.stat});
  final AcademiaHeaderStat stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Builder(
            builder: (context) {
              const style = TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              );
              final numeric = stat.numericValue;
              if (!stat.animate || numeric == null) {
                return Text(stat.value, style: style);
              }
              return AcademiaCountUp(value: numeric, style: style);
            },
          ),
          const SizedBox(height: 3),
          Text(
            stat.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pastille d'avatar utilisée dans les en-têtes.
class AcademiaAvatarBadge extends StatelessWidget {
  const AcademiaAvatarBadge({super.key, required this.initials});
  final String initials;

  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────
// Titre de section
// ─────────────────────────────────────────────────────────────────────────

class AcademiaSectionHeader extends StatelessWidget {
  const AcademiaSectionHeader({
    super.key,
    required this.title,
    this.kicker,
    this.count,
    this.actionLabel,
    this.onAction,
    this.leading,
    this.accent = AcademiaPalette.green600,
  });

  final String title;
  final String? kicker;
  final String? count;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? leading;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          if (kicker != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                kicker!.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: AcademiaPalette.ink,
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Text(
              count!,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AcademiaPalette.faint,
              ),
            ),
          ],
          const Spacer(),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                '$actionLabel ›',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Chip de filtre
// ─────────────────────────────────────────────────────────────────────────

class AcademiaFilterChip extends StatelessWidget {
  const AcademiaFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.accent = AcademiaPalette.green600,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AcademiaTapScale(
      onTap: onTap,
      scale: 0.94,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent : AcademiaPalette.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? accent : AcademiaPalette.borderStrong,
          ),
          boxShadow:
              selected ? AcademiaPalette.shadowAccent(accent) : AcademiaPalette.shadowSoft,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AcademiaPalette.muted,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.25)
                      : AcademiaPalette.surfaceAlt,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AcademiaPalette.faint,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Badge
// ─────────────────────────────────────────────────────────────────────────

class AcademiaBadge extends StatelessWidget {
  const AcademiaBadge({
    super.key,
    required this.label,
    required this.color,
    this.background,
    this.pulsing = false,
    this.icon,
  });

  final String label;
  final Color color;
  final Color? background;
  final bool pulsing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pulsing) ...[
            AcademiaPulseDot(color: color),
            const SizedBox(width: 5),
          ] else if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Point pulsant — réservé au signal « en direct ».
class AcademiaPulseDot extends StatefulWidget {
  const AcademiaPulseDot({super.key, this.color = AcademiaPalette.live, this.size = 7});
  final Color color;
  final double size;

  @override
  State<AcademiaPulseDot> createState() => _AcademiaPulseDotState();
}

class _AcademiaPulseDotState extends State<AcademiaPulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void initState() {
    super.initState();
    _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );
    if (reduceMotion) return dot;
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.3).animate(_c),
      child: dot,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Couverture (image réseau avec repli dégradé + glyphe)
// ─────────────────────────────────────────────────────────────────────────

class AcademiaCover extends StatelessWidget {
  const AcademiaCover({
    super.key,
    required this.height,
    this.imageUrl,
    this.seed = '',
    this.gradient,
    this.icon,
    this.overlays = const [],
    this.borderRadius,
  });

  final double height;
  final String? imageUrl;
  final String seed;
  final LinearGradient? gradient;
  final IconData? icon;
  final List<Widget> overlays;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final g = gradient ?? AcademiaPalette.coverFor(seed);
    final url = (imageUrl ?? '').trim();

    Widget content = Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(decoration: BoxDecoration(gradient: g)),
        if (url.isNotEmpty)
          Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            // Le dégradé sert de fond permanent : l'image se fond dessus une
            // fois téléchargée, sans à-coup ni case blanche.
            frameBuilder: (context, child, frame, wasSyncLoaded) {
              if (wasSyncLoaded || AcademiaMotion.reduced(context)) {
                return child;
              }
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: AcademiaMotion.base,
                curve: Curves.easeOut,
                child: child,
              );
            },
          ),
        if (url.isEmpty && icon != null)
          Positioned(
            right: 8,
            bottom: 2,
            child: Icon(
              icon,
              size: height * 0.42,
              color: Colors.white.withValues(alpha: 0.26),
            ),
          ),
        ...overlays,
      ],
    );

    if (borderRadius != null) {
      content = ClipRRect(borderRadius: borderRadius!, child: content);
    }

    return SizedBox(height: height, width: double.infinity, child: content);
  }
}

/// Étiquette posée sur une couverture (niveau, durée, chapitre…).
class AcademiaCoverTag extends StatelessWidget {
  const AcademiaCoverTag({super.key, required this.label, this.background});
  final String label;
  final Color? background;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: background ?? Colors.black.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: Colors.white,
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────
// États vides / erreurs
// ─────────────────────────────────────────────────────────────────────────

class AcademiaEmptyState extends StatelessWidget {
  const AcademiaEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.accent = AcademiaPalette.green600,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color accent;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      decoration: BoxDecoration(
        color: AcademiaPalette.surface,
        borderRadius: BorderRadius.circular(AcademiaPalette.rLg),
        border: Border.all(color: AcademiaPalette.border),
        boxShadow: AcademiaPalette.shadowSoft,
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 27, color: accent),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AcademiaPalette.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.8,
              height: 1.5,
              color: AcademiaPalette.muted,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: accent),
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class AcademiaErrorBanner extends StatelessWidget {
  const AcademiaErrorBanner({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AcademiaPalette.live50,
        borderRadius: BorderRadius.circular(AcademiaPalette.rMd),
        border: Border.all(color: AcademiaPalette.live.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              size: 18, color: AcademiaPalette.live),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                color: AcademiaPalette.live,
                height: 1.4,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AcademiaPalette.live,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 32),
            ),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Bandeau Bobodo
// ─────────────────────────────────────────────────────────────────────────

class AcademiaBobodoBanner extends StatelessWidget {
  const AcademiaBobodoBanner({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.accent = AcademiaPalette.green600,
    this.avatar,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color accent;
  final Widget? avatar;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.10),
            AcademiaPalette.blue50,
          ],
        ),
        borderRadius: BorderRadius.circular(AcademiaPalette.rLg),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          avatar ??
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: AcademiaPalette.coursHeader,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.smart_toy,
                    color: Colors.white, size: 21),
              ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12.3,
                    height: 1.5,
                    color: AcademiaPalette.text,
                  ),
                ),
                if (actionLabel != null) ...[
                  const SizedBox(height: 9),
                  GestureDetector(
                    onTap: onAction,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AcademiaPalette.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: accent.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        actionLabel!,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
