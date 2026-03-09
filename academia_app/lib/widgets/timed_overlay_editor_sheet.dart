import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/timed_overlay.dart';

/// Bottom sheet for creating or editing a single [TimedOverlay].
///
/// Returns the edited overlay on pop, or null if cancelled.
class TimedOverlayEditorSheet extends StatefulWidget {
  final TimedOverlay? overlay;
  final double totalDurationMs;
  final double currentPositionMs;

  const TimedOverlayEditorSheet({
    super.key,
    this.overlay,
    required this.totalDurationMs,
    required this.currentPositionMs,
  });

  @override
  State<TimedOverlayEditorSheet> createState() =>
      _TimedOverlayEditorSheetState();
}

class _TimedOverlayEditorSheetState extends State<TimedOverlayEditorSheet> {
  late OverlayType _type;
  late double _startMs;
  late double _endMs;
  late double _x;
  late double _y;
  late double _opacity;
  late OverlayAnimation _enterAnim;
  late OverlayAnimation _exitAnim;
  late TextEditingController _textCtrl;
  late TextEditingController _latexCtrl;

  bool get _isNew => widget.overlay == null;

  @override
  void initState() {
    super.initState();
    final o = widget.overlay;
    _type = o?.type ?? OverlayType.text;
    _startMs = o?.startMs ?? widget.currentPositionMs;
    _endMs = o?.endMs ?? (widget.currentPositionMs + 5000).clamp(0, widget.totalDurationMs);
    _x = o?.x ?? 0.5;
    _y = o?.y ?? 0.5;
    _opacity = o?.opacity ?? 1.0;
    _enterAnim = o?.enterAnim ?? OverlayAnimation.fadeIn;
    _exitAnim = o?.exitAnim ?? OverlayAnimation.fadeOut;
    _textCtrl = TextEditingController(
      text: o?.content['text']?.toString() ?? '',
    );
    _latexCtrl = TextEditingController(
      text: o?.content['latex']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _latexCtrl.dispose();
    super.dispose();
  }

  void _haptic() => HapticFeedback.lightImpact();

  void _save() {
    _haptic();
    final content = <String, dynamic>{};
    switch (_type) {
      case OverlayType.text:
      case OverlayType.subtitle:
        content['text'] = _textCtrl.text.trim();
        break;
      case OverlayType.equation:
        content['latex'] = _latexCtrl.text.trim();
        break;
      case OverlayType.drawing:
        content.addAll(widget.overlay?.content ?? {});
        break;
      case OverlayType.image:
        content.addAll(widget.overlay?.content ?? {});
        break;
      case OverlayType.sticker:
        content['type'] = widget.overlay?.content['type'] ?? 'star';
        break;
    }

    final result = TimedOverlay(
      id: widget.overlay?.id ?? UniqueKey().toString(),
      type: _type,
      startMs: _startMs,
      endMs: _endMs,
      x: _x,
      y: _y,
      opacity: _opacity,
      content: content,
      enterAnim: _enterAnim,
      exitAnim: _exitAnim,
    );

    Navigator.of(context).pop(result);
  }

  String _formatMs(double ms) {
    final sec = (ms / 1000);
    return '${sec.toStringAsFixed(1)}s';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    final total = widget.totalDurationMs.clamp(1.0, double.infinity);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad + 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle ──
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Title ──
            Text(
              _isNew ? '➕ Nouvel overlay' : '✏️ Modifier overlay',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),

            // ── Type selector ──
            const Text(
              'Type',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in OverlayType.values)
                  GestureDetector(
                    onTap: () {
                      _haptic();
                      setState(() => _type = t);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _type == t
                            ? t.color.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _type == t
                              ? t.color
                              : Colors.white.withValues(alpha: 0.1),
                          width: _type == t ? 1.5 : 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(t.emoji, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text(
                            t.label,
                            style: TextStyle(
                              color: _type == t ? t.color : Colors.white54,
                              fontSize: 12,
                              fontWeight: _type == t
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Timing ──
            const Text(
              'Timing',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  _formatMs(_startMs),
                  style: const TextStyle(
                    color: Color(0xFF00D2FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
                Expanded(
                  child: RangeSlider(
                    values: RangeValues(_startMs, _endMs),
                    min: 0,
                    max: total,
                    activeColor: _type.color,
                    inactiveColor: Colors.white.withValues(alpha: 0.1),
                    onChanged: (v) {
                      setState(() {
                        _startMs = v.start;
                        _endMs = v.end.clamp(v.start + 100, total);
                      });
                    },
                  ),
                ),
                Text(
                  _formatMs(_endMs),
                  style: const TextStyle(
                    color: Color(0xFF00D2FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Content ──
            if (_type == OverlayType.text || _type == OverlayType.subtitle) ...[
              const Text(
                'Texte',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _textCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Entrez votre texte...',
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (_type == OverlayType.equation) ...[
              const Text(
                'Formule LaTeX',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _latexCtrl,
                maxLines: 2,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: r'E = mc^2',
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Astuce : utilisez le bouton Écrire dans la toolbar pour l\'éditeur visuel',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Position ──
            const Text(
              'Position',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('X', style: TextStyle(color: Colors.white38, fontSize: 11)),
                Expanded(
                  child: Slider(
                    value: _x,
                    min: 0,
                    max: 1,
                    activeColor: _type.color,
                    inactiveColor: Colors.white.withValues(alpha: 0.1),
                    onChanged: (v) => setState(() => _x = v),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Y', style: TextStyle(color: Colors.white38, fontSize: 11)),
                Expanded(
                  child: Slider(
                    value: _y,
                    min: 0,
                    max: 1,
                    activeColor: _type.color,
                    inactiveColor: Colors.white.withValues(alpha: 0.1),
                    onChanged: (v) => setState(() => _y = v),
                  ),
                ),
              ],
            ),

            // ── Opacity ──
            Row(
              children: [
                const Text('Opacité',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
                Expanded(
                  child: Slider(
                    value: _opacity,
                    min: 0.1,
                    max: 1.0,
                    activeColor: _type.color,
                    inactiveColor: Colors.white.withValues(alpha: 0.1),
                    onChanged: (v) => setState(() => _opacity = v),
                  ),
                ),
                Text(
                  '${(_opacity * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Animations ──
            const Text(
              'Animations',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _AnimDropdown(
                    label: 'Entrée',
                    value: _enterAnim,
                    onChanged: (v) => setState(() => _enterAnim = v),
                    color: _type.color,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AnimDropdown(
                    label: 'Sortie',
                    value: _exitAnim,
                    onChanged: (v) => setState(() => _exitAnim = v),
                    color: _type.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Actions ──
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _haptic();
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Annuler',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _save,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_type.color, _type.color.withValues(alpha: 0.7)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _type.color.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _isNew ? '➕ Ajouter' : '✅ Enregistrer',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimDropdown extends StatelessWidget {
  final String label;
  final OverlayAnimation value;
  final ValueChanged<OverlayAnimation> onChanged;
  final Color color;

  const _AnimDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.color,
  });

  static const _labels = {
    OverlayAnimation.none: 'Aucune',
    OverlayAnimation.fadeIn: 'Fondu',
    OverlayAnimation.fadeOut: 'Fondu',
    OverlayAnimation.slideUp: 'Glisser ↑',
    OverlayAnimation.slideDown: 'Glisser ↓',
    OverlayAnimation.slideLeft: 'Glisser ←',
    OverlayAnimation.slideRight: 'Glisser →',
    OverlayAnimation.pop: 'Pop',
    OverlayAnimation.bounce: 'Rebond',
    OverlayAnimation.shrink: 'Rétrécir',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<OverlayAnimation>(
            value: value,
            isExpanded: true,
            dropdownColor: const Color(0xFF1A1A2E),
            underline: const SizedBox.shrink(),
            iconEnabledColor: color,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            items: OverlayAnimation.values
                .map((a) => DropdownMenuItem(
                      value: a,
                      child: Text(_labels[a] ?? a.name),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}
