import 'package:flutter/material.dart';

/// Barre de réactions pour une opportunité (like, love, commentaires, action)
class OpportunityReactionsBar extends StatelessWidget {
  final int reactionsCount;
  final int commentsCount;
  final String? myReaction;
  final String opportunityType;
  final VoidCallback? onLike;
  final VoidCallback? onLove;
  final VoidCallback? onComment;
  final VoidCallback? onAction;
  final Future<bool> Function()? onActionAsync;
  final GlobalKey? cartIconKey;
  final bool compact;

  const OpportunityReactionsBar({
    super.key,
    required this.reactionsCount,
    required this.commentsCount,
    this.myReaction,
    required this.opportunityType,
    this.onLike,
    this.onLove,
    this.onComment,
    this.onAction,
    this.onActionAsync,
    this.cartIconKey,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isLiked = myReaction == 'like';
    final isLoved = myReaction == 'love';

    if (compact) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _BounceReactionButton(
            icon: Icons.thumb_up,
            isActive: isLiked,
            activeColor: const Color(0xFF2196F3),
            onTap: onLike,
            compact: true,
          ),
          _BounceReactionButton(
            icon: Icons.favorite,
            isActive: isLoved,
            activeColor: const Color(0xFFE11D48),
            onTap: onLove,
            compact: true,
          ),
          if (reactionsCount > 0)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.5),
                  end: Offset.zero,
                ).animate(anim),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Text(
                '$reactionsCount',
                key: ValueKey(reactionsCount),
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9E9E9E),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          _CommentButton(
            count: commentsCount,
            onTap: onComment,
            compact: true,
          ),
          _ActionButton(
            type: opportunityType,
            onTap: onAction,
            onTapAsync: onActionAsync,
            cartIconKey: cartIconKey,
            compact: true,
          ),
        ],
      );
    }

    return Row(
      children: [
        // Bouton Like
        _BounceReactionButton(
          icon: Icons.thumb_up,
          isActive: isLiked,
          activeColor: const Color(0xFF2196F3),
          onTap: onLike,
          compact: compact,
        ),
        SizedBox(width: compact ? 4 : 8),

        // Bouton Love
        _BounceReactionButton(
          icon: Icons.favorite,
          isActive: isLoved,
          activeColor: const Color(0xFFE11D48),
          onTap: onLove,
          compact: compact,
        ),
        SizedBox(width: compact ? 8 : 12),

        // Compteur réactions
        if (reactionsCount > 0) ...[
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.5),
                end: Offset.zero,
              ).animate(anim),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Text(
              '$reactionsCount',
              key: ValueKey(reactionsCount),
              style: TextStyle(
                fontSize: compact ? 11 : 13,
                color: const Color(0xFF9E9E9E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: compact ? 12 : 16),
        ],

        // Bouton Commentaires
        _CommentButton(
          count: commentsCount,
          onTap: onComment,
          compact: compact,
        ),

        const Spacer(),

        // Bouton Action principal
        _ActionButton(
          type: opportunityType,
          onTap: onAction,
          onTapAsync: onActionAsync,
          cartIconKey: cartIconKey,
          compact: compact,
        ),
      ],
    );
  }
}

/// Reaction button with bounce animation (scale 1.0 → 1.4 → 1.0)
class _BounceReactionButton extends StatefulWidget {
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback? onTap;
  final bool compact;

  const _BounceReactionButton({
    required this.icon,
    required this.isActive,
    required this.activeColor,
    this.onTap,
    this.compact = false,
  });

  @override
  State<_BounceReactionButton> createState() => _BounceReactionButtonState();
}

class _BounceReactionButtonState extends State<_BounceReactionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 35),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant _BounceReactionButton old) {
    super.didUpdateWidget(old);
    if (old.isActive != widget.isActive && widget.isActive) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  IconData _getOutlinedIcon(IconData icon) {
    if (icon == Icons.thumb_up) return Icons.thumb_up_outlined;
    if (icon == Icons.favorite) return Icons.favorite_border;
    return icon;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? 6 : 8),
        child: ScaleTransition(
          scale: _scale,
          child: Icon(
            widget.isActive ? widget.icon : _getOutlinedIcon(widget.icon),
            size: widget.compact ? 18 : 22,
            color: widget.isActive
                ? widget.activeColor
                : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}

class _CommentButton extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;
  final bool compact;

  const _CommentButton({
    required this.count,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8,
          vertical: compact ? 6 : 8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: compact ? 16 : 20,
              color: const Color(0xFF9E9E9E),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: compact ? 11 : 13,
                  color: const Color(0xFF9E9E9E),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final String type;
  final VoidCallback? onTap;
  final Future<bool> Function()? onTapAsync;
  final GlobalKey? cartIconKey;
  final bool compact;

  const _ActionButton({
    required this.type,
    this.onTap,
    this.onTapAsync,
    this.cartIconKey,
    this.compact = false,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  bool _busy = false;
  bool _success = false;
  Offset? _lastTapGlobal;

  void _flyToCart() {
    final start = _lastTapGlobal;
    final cartContext = widget.cartIconKey?.currentContext;
    if (start == null || cartContext == null) return;

    final overlay = Overlay.of(context);

    final cartBox = cartContext.findRenderObject();
    if (cartBox is! RenderBox) return;
    final end = cartBox.localToGlobal(
      cartBox.size.center(Offset.zero),
    );

    late final OverlayEntry entry;
    late final AnimationController ctrl;

    ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    final anim = CurvedAnimation(parent: ctrl, curve: Curves.easeInOutCubic);

    entry = OverlayEntry(
      builder: (ctx) {
        return AnimatedBuilder(
          animation: anim,
          builder: (context, child) {
            final t = anim.value;
            final dx = start.dx + (end.dx - start.dx) * t;
            final dy = start.dy + (end.dy - start.dy) * t;
            final scale = 1.0 - (t * 0.35);
            final opacity = (1.0 - (t * 0.6)).clamp(0.0, 1.0);
            return Positioned(
              left: dx - 8,
              top: dy - 8,
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: child,
                ),
              ),
            );
          },
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFFFFB74D),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
          ),
        );
      },
    );

    overlay.insert(entry);
    ctrl.forward();
    ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        entry.remove();
        ctrl.dispose();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = _getActionConfig(widget.type);
    final isCartLike = widget.type.toLowerCase() == 'product';

    Future<void> run() async {
      if (_busy) return;
      if (widget.onTapAsync == null) {
        widget.onTap?.call();
        return;
      }

      setState(() {
        _busy = true;
        _success = false;
      });

      final ok = await widget.onTapAsync!();
      if (!mounted) return;

      if (ok && isCartLike) {
        setState(() {
          _success = true;
        });

        _flyToCart();

        Future.delayed(const Duration(milliseconds: 700), () {
          if (!mounted) return;
          setState(() {
            _success = false;
          });
        });
      }

      if (!mounted) return;
      setState(() {
        _busy = false;
      });
    }

    return GestureDetector(
      onTapDown: (d) {
        _lastTapGlobal = d.globalPosition;
      },
      child: ElevatedButton.icon(
        onPressed: _busy ? null : run,
        style: ElevatedButton.styleFrom(
          backgroundColor: config.color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 12 : 16,
            vertical: widget.compact ? 8 : 10,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.compact ? 8 : 12),
          ),
          elevation: 0,
        ),
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Icon(
            (_success && isCartLike)
                ? Icons.check_circle_outline
                : (_busy ? Icons.hourglass_top : config.icon),
            key: ValueKey('${_success}_${_busy}_${config.icon.codePoint}'),
            size: widget.compact ? 14 : 16,
          ),
        ),
        label: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(
            (_success && isCartLike)
                ? 'Ajouté'
                : (_busy ? '...' : config.label),
            key: ValueKey('${_success}_${_busy}_${config.label}'),
            style: TextStyle(
              fontSize: widget.compact ? 11 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  _ActionConfig _getActionConfig(String type) {
    switch (type.toLowerCase()) {
      case 'job':
        return _ActionConfig(
          label: 'Postuler',
          color: const Color(0xFF2196F3),
          icon: Icons.send,
        );
      case 'service':
        return _ActionConfig(
          label: 'Contacter',
          color: const Color(0xFF66BB6A),
          icon: Icons.chat,
        );
      case 'product':
        return _ActionConfig(
          label: 'Acheter',
          color: const Color(0xFFFFB74D),
          icon: Icons.shopping_cart,
        );
      default:
        return _ActionConfig(
          label: 'Voir',
          color: const Color(0xFF9E9E9E),
          icon: Icons.arrow_forward,
        );
    }
  }
}

class _ActionConfig {
  final String label;
  final Color color;
  final IconData icon;

  _ActionConfig({
    required this.label,
    required this.color,
    required this.icon,
  });
}
