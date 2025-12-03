class ChallengeVideoOverlays {
  final String backgroundTheme;
  final String filter;
  final List<Map<String, dynamic>> texts;
  final List<Map<String, dynamic>> equations;
  final List<Map<String, dynamic>> subtitles;
  final List<Map<String, dynamic>> stickers;
  final List<Map<String, dynamic>> arObjects;

  ChallengeVideoOverlays({
    required this.backgroundTheme,
    required this.filter,
    required this.texts,
    required this.equations,
    required this.subtitles,
    required this.stickers,
    required this.arObjects,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'background': <String, dynamic>{
        'theme': backgroundTheme,
      },
      'filter': filter,
      'texts': texts,
      'equations': equations,
      'subtitles': subtitles,
      'stickers': stickers,
      'ar_objects': arObjects,
    };
  }

  factory ChallengeVideoOverlays.fromJson(Map<String, dynamic> json) {
    final backgroundRaw = json['background'];
    final background = backgroundRaw is Map<String, dynamic>
        ? backgroundRaw
        : <String, dynamic>{};

    List<Map<String, dynamic>> normalizeList(dynamic value) {
      if (value is List) {
        return value
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      }
      return const <Map<String, dynamic>>[];
    }

    return ChallengeVideoOverlays(
      backgroundTheme: background['theme']?.toString() ?? 'universite-vert',
      filter: json['filter']?.toString() ?? 'none',
      texts: normalizeList(json['texts']),
      equations: normalizeList(json['equations']),
      subtitles: normalizeList(json['subtitles']),
      stickers: normalizeList(json['stickers']),
      arObjects: normalizeList(json['ar_objects']),
    );
  }

  ChallengeVideoOverlays copyWith({
    String? backgroundTheme,
    String? filter,
    List<Map<String, dynamic>>? texts,
    List<Map<String, dynamic>>? equations,
    List<Map<String, dynamic>>? subtitles,
    List<Map<String, dynamic>>? stickers,
    List<Map<String, dynamic>>? arObjects,
  }) {
    return ChallengeVideoOverlays(
      backgroundTheme: backgroundTheme ?? this.backgroundTheme,
      filter: filter ?? this.filter,
      texts: texts ?? this.texts,
      equations: equations ?? this.equations,
      subtitles: subtitles ?? this.subtitles,
      stickers: stickers ?? this.stickers,
      arObjects: arObjects ?? this.arObjects,
    );
  }
}
