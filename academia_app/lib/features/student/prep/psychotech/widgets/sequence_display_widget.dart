import 'package:flutter/material.dart';

/// Widget d'affichage d'une suite (numérique ou alphabétique) avec le terme manquant.
class SequenceDisplayWidget extends StatelessWidget {
  final List<String> terms;
  final int hiddenIndex;
  final double fontSize;

  const SequenceDisplayWidget({
    super.key,
    required this.terms,
    this.hiddenIndex = -1,
    this.fontSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 8,
      children: List.generate(terms.length, (i) {
        final isHidden = i == hiddenIndex;
        return Container(
          constraints: BoxConstraints(minWidth: fontSize * 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isHidden ? const Color(0xFF1565C0) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isHidden ? const Color(0xFF1565C0) : const Color(0xFFBDBDBD),
            ),
          ),
          child: Text(
            isHidden ? '?' : terms[i],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: isHidden ? Colors.white : const Color(0xFF212121),
              fontFamily: 'monospace',
            ),
          ),
        );
      }),
    );
  }
}

/// Widget pour afficher les options de réponse en grille 2x2.
class OptionsGridWidget extends StatelessWidget {
  final List<String> options;
  final int? selectedIndex;
  final int? correctIndex;
  final bool showResult;
  final ValueChanged<int>? onSelect;

  const OptionsGridWidget({
    super.key,
    required this.options,
    this.selectedIndex,
    this.correctIndex,
    this.showResult = false,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.8,
      ),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final isSelected = selectedIndex == index;
        final isCorrect = correctIndex == index;
        final isWrong = showResult && isSelected && !isCorrect;

        Color bgColor;
        Color borderColor;
        Color textColor;

        if (showResult && isCorrect) {
          bgColor = const Color(0xFFC8E6C9);
          borderColor = const Color(0xFF2E7D32);
          textColor = const Color(0xFF1B5E20);
        } else if (isWrong) {
          bgColor = const Color(0xFFFFCDD2);
          borderColor = const Color(0xFFD32F2F);
          textColor = const Color(0xFFB71C1C);
        } else if (isSelected) {
          bgColor = const Color(0xFFE3F2FD);
          borderColor = const Color(0xFF1565C0);
          textColor = const Color(0xFF0D47A1);
        } else {
          bgColor = Colors.white;
          borderColor = const Color(0xFFBDBDBD);
          textColor = const Color(0xFF424242);
        }

        return GestureDetector(
          onTap: showResult ? null : () => onSelect?.call(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: isSelected || (showResult && isCorrect) ? 2 : 1),
              boxShadow: [
                if (isSelected || (showResult && isCorrect))
                  BoxShadow(color: borderColor.withAlpha(40), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (showResult && isCorrect)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.check_circle, color: textColor, size: 18),
                    ),
                  if (isWrong)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.cancel, color: textColor, size: 18),
                    ),
                  Flexible(
                    child: Text(
                      options[index],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
