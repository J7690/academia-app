import 'dart:math';

import 'package:flutter/material.dart';

/// Widget grille d'attention — l'utilisateur doit compter/repérer des cibles.
class AttentionGridWidget extends StatelessWidget {
  final List<List<String>> grid;
  final String target;
  final Set<String> selectedCells;
  final void Function(int row, int col)? onCellTap;
  final double cellSize;

  const AttentionGridWidget({
    super.key,
    required this.grid,
    required this.target,
    this.selectedCells = const {},
    this.onCellTap,
    this.cellSize = 36,
  });

  /// Génère une grille aléatoire avec un nombre défini de cibles.
  static ({List<List<String>> grid, int targetCount, String target}) generateGrid({
    int rows = 8,
    int cols = 8,
    int targetCount = 12,
    int difficulty = 1,
  }) {
    final rng = Random();
    final symbols = difficulty <= 2
        ? ['d', 'b', 'p', 'q', 'o', 'a']
        : ['d', 'b', 'p', 'q', 'o', 'a', 'e', 'c', 'g'];
    final target = symbols[0]; // 'd' is always the target

    final grid = List.generate(rows, (_) =>
        List.generate(cols, (_) => symbols[1 + rng.nextInt(symbols.length - 1)]));

    // Place targets randomly
    final positions = <String>{};
    while (positions.length < targetCount) {
      final r = rng.nextInt(rows);
      final c = rng.nextInt(cols);
      final key = '$r,$c';
      if (!positions.contains(key)) {
        positions.add(key);
        grid[r][c] = target;
      }
    }

    return (grid: grid, targetCount: targetCount, target: target);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search, size: 18, color: Color(0xFF1565C0)),
              const SizedBox(width: 6),
              Text(
                'Repérez toutes les lettres "$target"',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1565C0)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF9E9E9E)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: List.generate(grid.length, (row) => Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(grid[row].length, (col) {
                final cellKey = '$row,$col';
                final isSelected = selectedCells.contains(cellKey);
                final symbol = grid[row][col];

                return GestureDetector(
                  onTap: onCellTap != null ? () => onCellTap!(row, col) : null,
                  child: Container(
                    width: cellSize,
                    height: cellSize,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFC8E6C9) : Colors.white,
                      border: Border.all(color: const Color(0xFFE0E0E0), width: 0.5),
                    ),
                    child: Center(
                      child: Text(
                        symbol,
                        style: TextStyle(
                          fontSize: cellSize * 0.5,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? const Color(0xFF2E7D32) : const Color(0xFF424242),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                );
              }),
            )),
          ),
        ),
      ],
    );
  }
}
