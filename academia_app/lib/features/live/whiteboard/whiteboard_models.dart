import 'dart:ui';

/// Un trait de dessin sur le tableau blanc.
class WhiteboardStroke {
  final String id;
  final String userId;
  final List<Point> points;
  final Color color;
  final double strokeWidth;
  final bool isEraser;
  final DateTime createdAt;

  WhiteboardStroke({
    required this.id,
    required this.userId,
    required this.points,
    this.color = const Color(0xFFFFFFFF),
    this.strokeWidth = 3.0,
    this.isEraser = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  WhiteboardStroke copyWith({
    List<Point>? points,
    Color? color,
    double? strokeWidth,
    bool? isEraser,
  }) {
    return WhiteboardStroke(
      id: id,
      userId: userId,
      points: points ?? this.points,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isEraser: isEraser ?? this.isEraser,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'points': points.map((p) => [p.x, p.y, p.pressure]).toList(),
        'color': color.toARGB32(),
        'stroke_width': strokeWidth,
        'is_eraser': isEraser,
      };

  factory WhiteboardStroke.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List? ?? [];
    return WhiteboardStroke(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      points: rawPoints.map<Point>((p) {
        if (p is List && p.length >= 2) {
          return Point(
            (p[0] as num).toDouble(),
            (p[1] as num).toDouble(),
            p.length >= 3 ? (p[2] as num).toDouble() : 0.5,
          );
        }
        return const Point(0, 0, 0.5);
      }).toList(),
      color: Color(json['color'] as int? ?? 0xFFFFFFFF),
      strokeWidth: (json['stroke_width'] as num?)?.toDouble() ?? 3.0,
      isEraser: json['is_eraser'] == true,
    );
  }
}

/// Point avec pression (pour perfect_freehand).
class Point {
  final double x;
  final double y;
  final double pressure;

  const Point(this.x, this.y, [this.pressure = 0.5]);
}

/// Outil de dessin actif.
enum WhiteboardTool {
  pen,
  highlighter,
  eraser,
  text,
  pointer,
}

/// Couleur prédéfinie pour la palette.
class WhiteboardColor {
  final String label;
  final Color color;
  const WhiteboardColor(this.label, this.color);
}

const kWhiteboardColors = [
  WhiteboardColor('Blanc', Color(0xFFFFFFFF)),
  WhiteboardColor('Rouge', Color(0xFFEF4444)),
  WhiteboardColor('Bleu', Color(0xFF3B82F6)),
  WhiteboardColor('Vert', Color(0xFF22C55E)),
  WhiteboardColor('Jaune', Color(0xFFFBBF24)),
  WhiteboardColor('Orange', Color(0xFFF97316)),
  WhiteboardColor('Violet', Color(0xFF8B5CF6)),
  WhiteboardColor('Rose', Color(0xFFEC4899)),
];

const kStrokeWidths = [1.5, 3.0, 5.0, 8.0];
