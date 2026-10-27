import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'alibaba_marketplace_tokens.dart';
import 'alibaba_press_scale.dart';

/// Bouton circulaire « verre dépoli » posé sur une image.
class MarketplaceGlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double size;
  final String? tooltip;

  const MarketplaceGlassButton({
    super.key,
    required this.child,
    this.onTap,
    this.size = 34,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = AlibabaPressScale(
      onTap: onTap,
      pressedScale: 0.88,
      borderRadius: BorderRadius.circular(size),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.78),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
            ),
            child: child,
          ),
        ),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}

/// Cœur qui « pop » quand on l'active.
class MarketplaceFavoriteButton extends StatefulWidget {
  final bool isFavorite;
  final VoidCallback? onTap;
  final double size;

  const MarketplaceFavoriteButton({
    super.key,
    required this.isFavorite,
    this.onTap,
    this.size = 34,
  });

  @override
  State<MarketplaceFavoriteButton> createState() => _MarketplaceFavoriteButtonState();
}

class _MarketplaceFavoriteButtonState extends State<MarketplaceFavoriteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late bool _fav = widget.isFavorite;

  @override
  void didUpdateWidget(covariant MarketplaceFavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFavorite != widget.isFavorite) {
      _fav = widget.isFavorite;
      if (_fav) _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _tap() {
    HapticFeedback.lightImpact();
    setState(() => _fav = !_fav);
    if (_fav) _c.forward(from: 0);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1, end: 1.35), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1), weight: 35),
    ]).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));

    return MarketplaceGlassButton(
      size: widget.size,
      tooltip: _fav ? 'Retirer des favoris' : 'Ajouter aux favoris',
      onTap: widget.onTap == null ? null : _tap,
      child: ScaleTransition(
        scale: scale,
        child: AnimatedSwitcher(
          duration: AlibabaMarketplaceTokens.fast,
          transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
          child: Icon(
            _fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            key: ValueKey(_fav),
            size: widget.size * 0.5,
            color: _fav ? AlibabaMarketplaceTokens.danger : AlibabaMarketplaceTokens.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Pastille de compteur qui rebondit à chaque changement de valeur.
class MarketplaceCountBadge extends StatefulWidget {
  final int count;
  final Widget child;
  final Color color;

  const MarketplaceCountBadge({
    super.key,
    required this.count,
    required this.child,
    this.color = AlibabaMarketplaceTokens.accent,
  });

  @override
  State<MarketplaceCountBadge> createState() => _MarketplaceCountBadgeState();
}

class _MarketplaceCountBadgeState extends State<MarketplaceCountBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
    value: 1,
  );

  @override
  void didUpdateWidget(covariant MarketplaceCountBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.count;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (c > 0)
          Positioned(
            right: -10,
            top: -7,
            child: ScaleTransition(
              scale: CurvedAnimation(parent: _c, curve: Curves.elasticOut),
              child: Container(
                constraints: const BoxConstraints(minWidth: 18),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: AlibabaMarketplaceTokens.shadowColored(widget.color),
                ),
                child: Text(
                  c > 99 ? '99+' : '$c',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Bouton « Ajouter au panier » : chargement puis coche de confirmation.
class MarketplaceAddToCartButton extends StatefulWidget {
  final Future<bool> Function() onAdd;
  final bool compact;
  final String label;

  const MarketplaceAddToCartButton({
    super.key,
    required this.onAdd,
    this.compact = false,
    this.label = 'Ajouter',
  });

  @override
  State<MarketplaceAddToCartButton> createState() => _MarketplaceAddToCartButtonState();
}

enum _AddState { idle, loading, done }

class _MarketplaceAddToCartButtonState extends State<MarketplaceAddToCartButton> {
  _AddState _state = _AddState.idle;

  Future<void> _tap() async {
    if (_state != _AddState.idle) return;
    HapticFeedback.mediumImpact();
    setState(() => _state = _AddState.loading);
    final ok = await widget.onAdd();
    if (!mounted) return;
    setState(() => _state = ok ? _AddState.done : _AddState.idle);
    if (ok) {
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (mounted) setState(() => _state = _AddState.idle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _state == _AddState.done;
    final h = widget.compact ? 34.0 : 40.0;

    if (widget.compact) {
      return AlibabaPressScale(
        onTap: _tap,
        pressedScale: 0.88,
        borderRadius: BorderRadius.circular(h),
        child: AnimatedContainer(
          duration: AlibabaMarketplaceTokens.medium,
          curve: AlibabaMarketplaceTokens.curve,
          width: h,
          height: h,
          decoration: BoxDecoration(
            gradient: done ? null : AlibabaMarketplaceTokens.accentGradient,
            color: done ? AlibabaMarketplaceTokens.success : null,
            shape: BoxShape.circle,
            boxShadow: AlibabaMarketplaceTokens.shadowColored(
              done ? AlibabaMarketplaceTokens.success : AlibabaMarketplaceTokens.accent,
            ),
          ),
          child: Center(child: _icon(18)),
        ),
      );
    }

    return AlibabaPressScale(
      onTap: _tap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: AlibabaMarketplaceTokens.medium,
        curve: AlibabaMarketplaceTokens.curve,
        height: h,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: done ? null : AlibabaMarketplaceTokens.accentGradient,
          color: done ? AlibabaMarketplaceTokens.success : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AlibabaMarketplaceTokens.shadowColored(
            done ? AlibabaMarketplaceTokens.success : AlibabaMarketplaceTokens.accent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _icon(18),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: AlibabaMarketplaceTokens.fast,
              child: Text(
                done ? 'Ajouté !' : widget.label,
                key: ValueKey(done),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _icon(double s) {
    return AnimatedSwitcher(
      duration: AlibabaMarketplaceTokens.medium,
      transitionBuilder: (child, a) => ScaleTransition(
        scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
        child: child,
      ),
      child: switch (_state) {
        _AddState.loading => SizedBox(
            key: const ValueKey('l'),
            width: s - 2,
            height: s - 2,
            child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
        _AddState.done => Icon(Icons.check_rounded, key: const ValueKey('d'), size: s, color: Colors.white),
        _AddState.idle => Icon(Icons.add_shopping_cart_rounded, key: const ValueKey('i'), size: s, color: Colors.white),
      },
    );
  }
}

/// Apparition en fondu + glissement, déclenchée une seule fois.
class MarketplaceReveal extends StatefulWidget {
  final Widget child;
  final int index;
  final Offset from;

  const MarketplaceReveal({
    super.key,
    required this.child,
    this.index = 0,
    this.from = const Offset(0, 0.08),
  });

  @override
  State<MarketplaceReveal> createState() => _MarketplaceRevealState();
}

class _MarketplaceRevealState extends State<MarketplaceReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AlibabaMarketplaceTokens.slow,
  );

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: 45 * (widget.index % 8));
    Future<void>.delayed(delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: _c, curve: AlibabaMarketplaceTokens.curve);
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(begin: widget.from, end: Offset.zero).animate(a),
        child: widget.child,
      ),
    );
  }
}

/// État vide / erreur illustré, avec icône qui flotte doucement.
class MarketplaceEmptyState extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color color;

  const MarketplaceEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.color = AlibabaMarketplaceTokens.brand,
  });

  @override
  State<MarketplaceEmptyState> createState() => _MarketplaceEmptyStateState();
}

class _MarketplaceEmptyStateState extends State<MarketplaceEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: MarketplaceReveal(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _c,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, -6 * Curves.easeInOut.transform(_c.value)),
                  child: child,
                ),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.color.withValues(alpha: 0.16),
                        widget.color.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, size: 44, color: widget.color),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AlibabaMarketplaceTokens.textPrimary,
                ),
              ),
              if (widget.message != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: AlibabaMarketplaceTokens.textSecondary,
                  ),
                ),
              ],
              if (widget.actionLabel != null && widget.onAction != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: widget.onAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.color,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(widget.actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
