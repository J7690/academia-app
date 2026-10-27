import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AlibabaPressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final double pressedScale;
  final bool haptic;

  const AlibabaPressScale({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.pressedScale = 0.96,
    this.haptic = true,
  });

  @override
  State<AlibabaPressScale> createState() => _AlibabaPressScaleState();
}

class _AlibabaPressScaleState extends State<AlibabaPressScale> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Listener(
      onPointerDown: enabled ? (_) => _setPressed(true) : null,
      onPointerUp: enabled ? (_) => _setPressed(false) : null,
      onPointerCancel: enabled ? (_) => _setPressed(false) : null,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: Duration(milliseconds: _pressed ? 90 : 220),
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: Material(
          color: Colors.transparent,
          borderRadius: widget.borderRadius,
          child: InkWell(
            onTap: enabled
                ? () {
                    if (widget.haptic) HapticFeedback.selectionClick();
                    widget.onTap!();
                  }
                : null,
            borderRadius: widget.borderRadius,
            splashColor: const Color(0x144F46E5),
            highlightColor: Colors.transparent,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
