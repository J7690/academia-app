/// Smart Whiteboard IA V1 – Storyboard Models
/// 
/// Ce fichier contient tous les modèles de données pour le Smart Whiteboard IA V1,
/// conformément au Data Contract défini dans docs/SMART_WHITEBOARD_DATA_CONTRACT.md
/// 
/// Les modèles incluent :
/// - WhiteboardProject
/// - Storyboard
/// - Scene
/// - Block (et ses sous-types)
/// - Narration
/// - RenderJob
/// - ExportSettings

// ============================================================================
// ENUMS
// ============================================================================

enum ProjectStatus {
  draft,
  completed,
}

enum RendererId {
  scientific,
  notebook,
}

enum ThemeId {
  scientific,
  notebook,
}

enum NarrationMode {
  none,
  tts,
  userRecording,
}

enum RenderJobStatus {
  queued,
  processing,
  done,
  failed,
}

enum BlockType {
  title,
  paragraph,
  formula,
  definition,
  exercise,
  correction,
}

// ============================================================================
// EXPORT SETTINGS
// ============================================================================

class ExportSettings {
  final String format;
  final Resolution resolution;
  final int frameRate;
  final String videoCodec;
  final String audioCodec;

  const ExportSettings({
    required this.format,
    required this.resolution,
    required this.frameRate,
    required this.videoCodec,
    required this.audioCodec,
  });

  // Valeurs par défaut V1
  static const ExportSettings v1Default = ExportSettings(
    format: 'mp4',
    resolution: Resolution(width: 1080, height: 1920),
    frameRate: 30,
    videoCodec: 'h264',
    audioCodec: 'aac',
  );

  Map<String, dynamic> toJson() {
    return {
      'format': format,
      'resolution': resolution.toJson(),
      'frame_rate': frameRate,
      'video_codec': videoCodec,
      'audio_codec': audioCodec,
    };
  }

  factory ExportSettings.fromJson(Map<String, dynamic> json) {
    print("DEBUG 24: ExportSettings.fromJson json = $json");
    print("DEBUG 25: json['format'] = ${json['format']}");
    print("DEBUG 26: json['format'] type = ${json['format'].runtimeType}");
    print("DEBUG 27: json['video_codec'] = ${json['video_codec']}");
    print("DEBUG 28: json['video_codec'] type = ${json['video_codec'].runtimeType}");
    print("DEBUG 29: json['audio_codec'] = ${json['audio_codec']}");
    print("DEBUG 30: json['audio_codec'] type = ${json['audio_codec'].runtimeType}");
    print("DEBUG-D19-51: ExportSettings.fromJson START json=$json runtimeType=${json.runtimeType}");
    print("DEBUG-D19-52: ExportSettings.fromJson format=${json['format']} runtimeType=${json['format']?.runtimeType} isNull=${json['format'] == null}");
    print("DEBUG-D19-53: ExportSettings.fromJson resolution=${json['resolution']} runtimeType=${json['resolution']?.runtimeType} isNull=${json['resolution'] == null}");
    print("DEBUG-D19-54: ExportSettings.fromJson frame_rate=${json['frame_rate']} runtimeType=${json['frame_rate']?.runtimeType} isNull=${json['frame_rate'] == null}");

    return ExportSettings(
      format: json['format'] as String,
      resolution: Resolution.fromJson(json['resolution'] as Map<String, dynamic>),
      frameRate: json['frame_rate'] as int,
      videoCodec: json['video_codec'] as String,
      audioCodec: json['audio_codec'] as String,
    );
  }

  ExportSettings copyWith({
    String? format,
    Resolution? resolution,
    int? frameRate,
    String? videoCodec,
    String? audioCodec,
  }) {
    return ExportSettings(
      format: format ?? this.format,
      resolution: resolution ?? this.resolution,
      frameRate: frameRate ?? this.frameRate,
      videoCodec: videoCodec ?? this.videoCodec,
      audioCodec: audioCodec ?? this.audioCodec,
    );
  }
}

class Resolution {
  final int width;
  final int height;

  const Resolution({
    required this.width,
    required this.height,
  });

  Map<String, dynamic> toJson() {
    return {
      'width': width,
      'height': height,
    };
  }

  factory Resolution.fromJson(Map<String, dynamic> json) {
    print("DEBUG-D19-55: Resolution.fromJson START json=$json runtimeType=${json.runtimeType}");
    print("DEBUG-D19-56: Resolution.fromJson width=${json['width']} runtimeType=${json['width']?.runtimeType} isNull=${json['width'] == null}");
    print("DEBUG-D19-57: Resolution.fromJson height=${json['height']} runtimeType=${json['height']?.runtimeType} isNull=${json['height'] == null}");
    return Resolution(
      width: json['width'] as int,
      height: json['height'] as int,
    );
  }

  Resolution copyWith({
    int? width,
    int? height,
  }) {
    return Resolution(
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

// ============================================================================
// NARRATION
// ============================================================================

class Narration {
  final NarrationMode mode;
  final String? audioUrl;
  final int? durationMs;
  final String? language;
  final String? voice;

  const Narration({
    required this.mode,
    this.audioUrl,
    this.durationMs,
    this.language,
    this.voice,
  });

  Map<String, dynamic> toJson() {
    return {
      'mode': mode.name,
      'audio_url': audioUrl,
      'duration_ms': durationMs,
      'language': language,
      'voice': voice,
    };
  }

  factory Narration.fromJson(Map<String, dynamic> json) {
    return Narration(
      mode: NarrationMode.values.firstWhere(
        (e) => e.name == json['mode'],
        orElse: () => NarrationMode.none,
      ),
      audioUrl: json['audio_url'] as String?,
      durationMs: json['duration_ms'] as int?,
      language: json['language'] as String?,
      voice: json['voice'] as String?,
    );
  }

  Narration copyWith({
    NarrationMode? mode,
    String? audioUrl,
    int? durationMs,
    String? language,
    String? voice,
  }) {
    return Narration(
      mode: mode ?? this.mode,
      audioUrl: audioUrl ?? this.audioUrl,
      durationMs: durationMs ?? this.durationMs,
      language: language ?? this.language,
      voice: voice ?? this.voice,
    );
  }
}

// ============================================================================
// BLOCK STYLE
// ============================================================================

class BlockStyle {
  final int? fontSize;
  final String? fontWeight;
  final String? color;
  final String? termColor;
  final String? definitionColor;
  final String? exampleColor;
  final String? questionColor;
  final String? hintColor;
  final String? solutionColor;
  final String? stepNumberColor;
  final String? explanationColor;

  const BlockStyle({
    this.fontSize,
    this.fontWeight,
    this.color,
    this.termColor,
    this.definitionColor,
    this.exampleColor,
    this.questionColor,
    this.hintColor,
    this.solutionColor,
    this.stepNumberColor,
    this.explanationColor,
  });

  Map<String, dynamic> toJson() {
    return {
      'font_size': fontSize,
      'font_weight': fontWeight,
      'color': color,
      'term_color': termColor,
      'definition_color': definitionColor,
      'example_color': exampleColor,
      'question_color': questionColor,
      'hint_color': hintColor,
      'solution_color': solutionColor,
      'step_number_color': stepNumberColor,
      'explanation_color': explanationColor,
    };
  }

  factory BlockStyle.fromJson(Map<String, dynamic> json) {
    return BlockStyle(
      fontSize: json['font_size'] as int?,
      fontWeight: json['font_weight'] as String?,
      color: json['color'] as String?,
      termColor: json['term_color'] as String?,
      definitionColor: json['definition_color'] as String?,
      exampleColor: json['example_color'] as String?,
      questionColor: json['question_color'] as String?,
      hintColor: json['hint_color'] as String?,
      solutionColor: json['solution_color'] as String?,
      stepNumberColor: json['step_number_color'] as String?,
      explanationColor: json['explanation_color'] as String?,
    );
  }

  BlockStyle copyWith({
    int? fontSize,
    String? fontWeight,
    String? color,
    String? termColor,
    String? definitionColor,
    String? exampleColor,
    String? questionColor,
    String? hintColor,
    String? solutionColor,
    String? stepNumberColor,
    String? explanationColor,
  }) {
    return BlockStyle(
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      color: color ?? this.color,
      termColor: termColor ?? this.termColor,
      definitionColor: definitionColor ?? this.definitionColor,
      exampleColor: exampleColor ?? this.exampleColor,
      questionColor: questionColor ?? this.questionColor,
      hintColor: hintColor ?? this.hintColor,
      solutionColor: solutionColor ?? this.solutionColor,
      stepNumberColor: stepNumberColor ?? this.stepNumberColor,
      explanationColor: explanationColor ?? this.explanationColor,
    );
  }
}

// ============================================================================
// BLOCK
// ============================================================================

abstract class Block {
  final String id;
  final BlockType type;
  final String content;
  final int order;
  final bool visible;
  final Map<String, dynamic>? animation;
  final Map<String, dynamic>? position;
  final BlockStyle style;

  const Block({
    required this.id,
    required this.type,
    required this.content,
    required this.order,
    required this.visible,
    this.animation,
    this.position,
    required this.style,
  });

  Map<String, dynamic> toJson();

  static Block fromJson(Map<String, dynamic> json) {
    print("DEBUG 31: Block.fromJson json = $json");
    print("DEBUG 32: json['id'] = ${json['id']}");
    print("DEBUG 33: json['id'] type = ${json['id'].runtimeType}");
    print("DEBUG 34: json['type'] = ${json['type']}");
    print("DEBUG 35: json['type'] type = ${json['type'].runtimeType}");
    print("DEBUG 36: json['content'] = ${json['content']}");
    print("DEBUG 37: json['content'] type = ${json['content'].runtimeType}");
    print("DEBUG-D19-64: Block.fromJson START json=$json runtimeType=${json.runtimeType}");
    print("DEBUG-D19-65: Block.fromJson id=${json['id']} runtimeType=${json['id']?.runtimeType} isNull=${json['id'] == null}");
    print("DEBUG-D19-66: Block.fromJson type=${json['type']} runtimeType=${json['type']?.runtimeType} isNull=${json['type'] == null}");
    print("DEBUG-D19-67: Block.fromJson content=${json['content']} runtimeType=${json['content']?.runtimeType} isNull=${json['content'] == null}");

    final type = BlockType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => BlockType.paragraph,
    );

    final commonData = {
      'id': json['id'] as String,
      'type': json['type'] as String,
      'content': json['content'] as String,
      'order': json['order'] as int,
      'visible': json['visible'] as bool,
      'animation': json['animation'] as Map<String, dynamic>?,
      'position': json['position'] as Map<String, dynamic>?,
      'style': BlockStyle.fromJson(json['style'] as Map<String, dynamic>? ?? {}),
    };

    switch (type) {
      case BlockType.title:
        return TitleBlock.fromJson({...commonData, ...json});
      case BlockType.paragraph:
        return ParagraphBlock.fromJson({...commonData, ...json});
      case BlockType.formula:
        return FormulaBlock.fromJson({...commonData, ...json});
      case BlockType.definition:
        return DefinitionBlock.fromJson({...commonData, ...json});
      case BlockType.exercise:
        return ExerciseBlock.fromJson({...commonData, ...json});
      case BlockType.correction:
        return CorrectionBlock.fromJson({...commonData, ...json});
    }
  }
}

// Title Block
class TitleBlock extends Block {
  const TitleBlock({
    required super.id,
    required super.content,
    required super.order,
    super.visible = true,
    super.animation,
    super.position,
    super.style = const BlockStyle(fontSize: 24, fontWeight: 'bold'),
  }) : super(type: BlockType.title);

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'content': content,
      'order': order,
      'visible': visible,
      'animation': animation,
      'position': position,
      'style': style.toJson(),
    };
  }

  factory TitleBlock.fromJson(Map<String, dynamic> json) {
    return TitleBlock(
      id: json['id'] as String,
      content: json['content'] as String,
      order: json['order'] as int,
      visible: json['visible'] as bool,
      animation: json['animation'] as Map<String, dynamic>?,
      position: json['position'] as Map<String, dynamic>?,
      style: BlockStyle.fromJson(json['style'] as Map<String, dynamic>? ?? {}),
    );
  }

  TitleBlock copyWith({
    String? id,
    String? content,
    int? order,
    bool? visible,
    Map<String, dynamic>? animation,
    Map<String, dynamic>? position,
    BlockStyle? style,
  }) {
    return TitleBlock(
      id: id ?? this.id,
      content: content ?? this.content,
      order: order ?? this.order,
      visible: visible ?? this.visible,
      animation: animation ?? this.animation,
      position: position ?? this.position,
      style: style ?? this.style,
    );
  }
}

// Paragraph Block
class ParagraphBlock extends Block {
  const ParagraphBlock({
    required super.id,
    required super.content,
    required super.order,
    super.visible = true,
    super.animation,
    super.position,
    super.style = const BlockStyle(fontSize: 16),
  }) : super(type: BlockType.paragraph);

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'content': content,
      'order': order,
      'visible': visible,
      'animation': animation,
      'position': position,
      'style': style.toJson(),
    };
  }

  factory ParagraphBlock.fromJson(Map<String, dynamic> json) {
    return ParagraphBlock(
      id: json['id'] as String,
      content: json['content'] as String,
      order: json['order'] as int,
      visible: json['visible'] as bool,
      animation: json['animation'] as Map<String, dynamic>?,
      position: json['position'] as Map<String, dynamic>?,
      style: BlockStyle.fromJson(json['style'] as Map<String, dynamic>? ?? {}),
    );
  }

  ParagraphBlock copyWith({
    String? id,
    String? content,
    int? order,
    bool? visible,
    Map<String, dynamic>? animation,
    Map<String, dynamic>? position,
    BlockStyle? style,
  }) {
    return ParagraphBlock(
      id: id ?? this.id,
      content: content ?? this.content,
      order: order ?? this.order,
      visible: visible ?? this.visible,
      animation: animation ?? this.animation,
      position: position ?? this.position,
      style: style ?? this.style,
    );
  }
}

// Formula Block
class FormulaBlock extends Block {
  final String format;

  const FormulaBlock({
    required super.id,
    required super.content,
    required super.order,
    this.format = 'latex',
    super.visible = true,
    super.animation,
    super.position,
    super.style = const BlockStyle(fontSize: 18),
  }) : super(type: BlockType.formula);

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'content': content,
      'format': format,
      'order': order,
      'visible': visible,
      'animation': animation,
      'position': position,
      'style': style.toJson(),
    };
  }

  factory FormulaBlock.fromJson(Map<String, dynamic> json) {
    return FormulaBlock(
      id: json['id'] as String,
      content: json['content'] as String,
      format: json['format'] as String? ?? 'latex',
      order: json['order'] as int,
      visible: json['visible'] as bool,
      animation: json['animation'] as Map<String, dynamic>?,
      position: json['position'] as Map<String, dynamic>?,
      style: BlockStyle.fromJson(json['style'] as Map<String, dynamic>? ?? {}),
    );
  }

  FormulaBlock copyWith({
    String? id,
    String? content,
    String? format,
    int? order,
    bool? visible,
    Map<String, dynamic>? animation,
    Map<String, dynamic>? position,
    BlockStyle? style,
  }) {
    return FormulaBlock(
      id: id ?? this.id,
      content: content ?? this.content,
      format: format ?? this.format,
      order: order ?? this.order,
      visible: visible ?? this.visible,
      animation: animation ?? this.animation,
      position: position ?? this.position,
      style: style ?? this.style,
    );
  }
}

// Definition Block
class DefinitionBlock extends Block {
  final String term;
  final String definition;
  final String? example;

  const DefinitionBlock({
    required super.id,
    required this.term,
    required this.definition,
    this.example,
    required super.order,
    super.visible = true,
    super.animation,
    super.position,
    super.style = const BlockStyle(),
  }) : super(type: BlockType.definition, content: definition);

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'content': content,
      'term': term,
      'definition': definition,
      'example': example,
      'order': order,
      'visible': visible,
      'animation': animation,
      'position': position,
      'style': style.toJson(),
    };
  }

  factory DefinitionBlock.fromJson(Map<String, dynamic> json) {
    final fallback = json['content'] as String? ?? '';
    return DefinitionBlock(
      id: json['id'] as String,
      term: json['term'] as String? ?? fallback,
      definition: json['definition'] as String? ?? fallback,
      example: json['example'] as String?,
      order: json['order'] as int,
      visible: json['visible'] as bool,
      animation: json['animation'] as Map<String, dynamic>?,
      position: json['position'] as Map<String, dynamic>?,
      style: BlockStyle.fromJson(json['style'] as Map<String, dynamic>? ?? {}),
    );
  }

  DefinitionBlock copyWith({
    String? id,
    String? term,
    String? definition,
    String? example,
    int? order,
    bool? visible,
    Map<String, dynamic>? animation,
    Map<String, dynamic>? position,
    BlockStyle? style,
  }) {
    return DefinitionBlock(
      id: id ?? this.id,
      term: term ?? this.term,
      definition: definition ?? this.definition,
      example: example ?? this.example,
      order: order ?? this.order,
      visible: visible ?? this.visible,
      animation: animation ?? this.animation,
      position: position ?? this.position,
      style: style ?? this.style,
    );
  }
}

// Exercise Block
class ExerciseBlock extends Block {
  final String question;
  final String? hint;
  final String? solution;

  const ExerciseBlock({
    required super.id,
    required this.question,
    this.hint,
    this.solution,
    required super.order,
    super.visible = true,
    super.animation,
    super.position,
    super.style = const BlockStyle(),
  }) : super(type: BlockType.exercise, content: question);

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'content': content,
      'question': question,
      'hint': hint,
      'solution': solution,
      'order': order,
      'visible': visible,
      'animation': animation,
      'position': position,
      'style': style.toJson(),
    };
  }

  factory ExerciseBlock.fromJson(Map<String, dynamic> json) {
    return ExerciseBlock(
      id: json['id'] as String,
      question: json['question'] as String? ?? json['content'] as String? ?? '',
      hint: json['hint'] as String?,
      solution: json['solution'] as String?,
      order: json['order'] as int,
      visible: json['visible'] as bool,
      animation: json['animation'] as Map<String, dynamic>?,
      position: json['position'] as Map<String, dynamic>?,
      style: BlockStyle.fromJson(json['style'] as Map<String, dynamic>? ?? {}),
    );
  }

  ExerciseBlock copyWith({
    String? id,
    String? question,
    String? hint,
    String? solution,
    int? order,
    bool? visible,
    Map<String, dynamic>? animation,
    Map<String, dynamic>? position,
    BlockStyle? style,
  }) {
    return ExerciseBlock(
      id: id ?? this.id,
      question: question ?? this.question,
      hint: hint ?? this.hint,
      solution: solution ?? this.solution,
      order: order ?? this.order,
      visible: visible ?? this.visible,
      animation: animation ?? this.animation,
      position: position ?? this.position,
      style: style ?? this.style,
    );
  }
}

// Correction Block
class CorrectionBlock extends Block {
  final String exerciseId;
  final List<String> steps;
  final String explanation;

  const CorrectionBlock({
    required super.id,
    required this.exerciseId,
    required this.steps,
    required this.explanation,
    required super.order,
    super.visible = true,
    super.animation,
    super.position,
    super.style = const BlockStyle(),
  }) : super(type: BlockType.correction, content: explanation);

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'content': content,
      'exercise_id': exerciseId,
      'steps': steps,
      'explanation': explanation,
      'order': order,
      'visible': visible,
      'animation': animation,
      'position': position,
      'style': style.toJson(),
    };
  }

  factory CorrectionBlock.fromJson(Map<String, dynamic> json) {
    return CorrectionBlock(
      id: json['id'] as String,
      exerciseId: json['exercise_id'] as String? ?? '',
      steps: (json['steps'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      explanation: json['explanation'] as String? ?? json['content'] as String? ?? '',
      order: json['order'] as int,
      visible: json['visible'] as bool,
      animation: json['animation'] as Map<String, dynamic>?,
      position: json['position'] as Map<String, dynamic>?,
      style: BlockStyle.fromJson(json['style'] as Map<String, dynamic>? ?? {}),
    );
  }

  CorrectionBlock copyWith({
    String? id,
    String? exerciseId,
    List<String>? steps,
    String? explanation,
    int? order,
    bool? visible,
    Map<String, dynamic>? animation,
    Map<String, dynamic>? position,
    BlockStyle? style,
  }) {
    return CorrectionBlock(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      steps: steps ?? this.steps,
      explanation: explanation ?? this.explanation,
      order: order ?? this.order,
      visible: visible ?? this.visible,
      animation: animation ?? this.animation,
      position: position ?? this.position,
      style: style ?? this.style,
    );
  }
}

// ============================================================================
// SCENE
// ============================================================================

class Scene {
  final String id;
  final int order;
  final String title;
  final int durationMs;
  final Map<String, dynamic>? transition;
  final List<Block> blocks;

  const Scene({
    required this.id,
    required this.order,
    required this.title,
    required this.durationMs,
    this.transition,
    required this.blocks,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order': order,
      'title': title,
      'duration_ms': durationMs,
      'transition': transition,
      'blocks': blocks.map((b) => b.toJson()).toList(),
    };
  }

  factory Scene.fromJson(Map<String, dynamic> json) {
    print("DEBUG-D19-58: Scene.fromJson START json=$json runtimeType=${json.runtimeType}");
    print("DEBUG-D19-59: Scene.fromJson id=${json['id']} runtimeType=${json['id']?.runtimeType} isNull=${json['id'] == null}");
    print("DEBUG-D19-60: Scene.fromJson order=${json['order']} runtimeType=${json['order']?.runtimeType} isNull=${json['order'] == null}");
    print("DEBUG-D19-61: Scene.fromJson title=${json['title']} runtimeType=${json['title']?.runtimeType} isNull=${json['title'] == null}");
    print("DEBUG-D19-62: Scene.fromJson duration_ms=${json['duration_ms']} runtimeType=${json['duration_ms']?.runtimeType} isNull=${json['duration_ms'] == null}");
    print("DEBUG-D19-63: Scene.fromJson blocks=${json['blocks']} runtimeType=${json['blocks']?.runtimeType} isNull=${json['blocks'] == null}");
    return Scene(
      id: json['id'] as String,
      order: json['order'] as int,
      title: json['title'] as String,
      durationMs: json['duration_ms'] as int,
      transition: json['transition'] as Map<String, dynamic>?,
      blocks: (json['blocks'] as List<dynamic>?)
              ?.map((b) => Block.fromJson(b as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Scene copyWith({
    String? id,
    int? order,
    String? title,
    int? durationMs,
    Map<String, dynamic>? transition,
    List<Block>? blocks,
  }) {
    return Scene(
      id: id ?? this.id,
      order: order ?? this.order,
      title: title ?? this.title,
      durationMs: durationMs ?? this.durationMs,
      transition: transition ?? this.transition,
      blocks: blocks ?? this.blocks,
    );
  }
}

// ============================================================================
// STORYBOARD
// ============================================================================

class Storyboard {
  final String version;
  final DateTime createdAt;
  final String createdBy;
  final String subject;
  final RendererId renderer;
  final ThemeId theme;
  final NarrationMode narrationMode;
  final ExportSettings exportSettings;
  final List<Scene> scenes;

  const Storyboard({
    required this.version,
    required this.createdAt,
    required this.createdBy,
    required this.subject,
    required this.renderer,
    required this.theme,
    required this.narrationMode,
    required this.exportSettings,
    required this.scenes,
  });

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
      'subject': subject,
      'renderer': renderer.name,
      'theme': theme.name,
      'narration_mode': narrationMode.name,
      'export_settings': exportSettings.toJson(),
      'scenes': scenes.map((s) => s.toJson()).toList(),
    };
  }

  factory Storyboard.fromJson(Map<String, dynamic> json) {
    print("DEBUG 15: Storyboard.fromJson json = $json");
    print("DEBUG 16: json['version'] = ${json['version']}");
    print("DEBUG 17: json['version'] type = ${json['version'].runtimeType}");
    print("DEBUG 18: json['created_at'] = ${json['created_at']}");
    print("DEBUG 19: json['created_at'] type = ${json['created_at'].runtimeType}");
    print("DEBUG 20: json['created_by'] = ${json['created_by']}");
    print("DEBUG 21: json['created_by'] type = ${json['created_by'].runtimeType}");
    print("DEBUG 22: json['subject'] = ${json['subject']}");
    print("DEBUG 23: json['subject'] type = ${json['subject'].runtimeType}");
    print("DEBUG-D19-68: Storyboard.fromJson START json=$json runtimeType=${json.runtimeType}");
    print("DEBUG-D19-69: Storyboard.fromJson version=${json['version']} runtimeType=${json['version']?.runtimeType} isNull=${json['version'] == null}");
    print("DEBUG-D19-70: Storyboard.fromJson created_at=${json['created_at']} runtimeType=${json['created_at']?.runtimeType} isNull=${json['created_at'] == null}");
    print("DEBUG-D19-71: Storyboard.fromJson created_by=${json['created_by']} runtimeType=${json['created_by']?.runtimeType} isNull=${json['created_by'] == null}");
    print("DEBUG-D19-72: Storyboard.fromJson subject=${json['subject']} runtimeType=${json['subject']?.runtimeType} isNull=${json['subject'] == null}");
    print("DEBUG-D19-73: Storyboard.fromJson renderer=${json['renderer']} runtimeType=${json['renderer']?.runtimeType} isNull=${json['renderer'] == null}");
    print("DEBUG-D19-74: Storyboard.fromJson theme=${json['theme']} runtimeType=${json['theme']?.runtimeType} isNull=${json['theme'] == null}");
    print("DEBUG-D19-75: Storyboard.fromJson narration_mode=${json['narration_mode']} runtimeType=${json['narration_mode']?.runtimeType} isNull=${json['narration_mode'] == null}");
    print("DEBUG-D19-76: Storyboard.fromJson export_settings=${json['export_settings']} runtimeType=${json['export_settings']?.runtimeType} isNull=${json['export_settings'] == null}");
    print("DEBUG-D19-77: Storyboard.fromJson scenes=${json['scenes']} runtimeType=${json['scenes']?.runtimeType} isNull=${json['scenes'] == null}");

    return Storyboard(
      version: json['version'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String,
      subject: json['subject'] as String,
      renderer: RendererId.values.firstWhere(
        (e) => e.name == json['renderer'],
        orElse: () => RendererId.scientific,
      ),
      theme: ThemeId.values.firstWhere(
        (e) => e.name == json['theme'],
        orElse: () => ThemeId.scientific,
      ),
      narrationMode: NarrationMode.values.firstWhere(
        (e) => e.name == json['narration_mode'],
        orElse: () => NarrationMode.none,
      ),
      exportSettings: ExportSettings.fromJson(
          json['export_settings'] as Map<String, dynamic>),
      scenes: (json['scenes'] as List<dynamic>?)
              ?.map((s) => Scene.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Storyboard copyWith({
    String? version,
    DateTime? createdAt,
    String? createdBy,
    String? subject,
    RendererId? renderer,
    ThemeId? theme,
    NarrationMode? narrationMode,
    ExportSettings? exportSettings,
    List<Scene>? scenes,
  }) {
    return Storyboard(
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      subject: subject ?? this.subject,
      renderer: renderer ?? this.renderer,
      theme: theme ?? this.theme,
      narrationMode: narrationMode ?? this.narrationMode,
      exportSettings: exportSettings ?? this.exportSettings,
      scenes: scenes ?? this.scenes,
    );
  }
}

// ============================================================================
// WHITEBOARD PROJECT
// ============================================================================

class WhiteboardProject {
  final String id;
  final String studentId;
  final String subject;
  final ProjectStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final RendererId rendererId;
  final ThemeId themeId;
  final NarrationMode narrationMode;
  final Storyboard storyboard;

  const WhiteboardProject({
    required this.id,
    required this.studentId,
    required this.subject,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.rendererId,
    required this.themeId,
    required this.narrationMode,
    required this.storyboard,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'subject': subject,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'renderer_id': rendererId.name,
      'theme_id': themeId.name,
      'narration_mode': narrationMode.name,
      'storyboard': storyboard.toJson(),
    };
  }

  factory WhiteboardProject.fromJson(Map<String, dynamic> json) {
    return WhiteboardProject(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      subject: json['subject'] as String,
      status: ProjectStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ProjectStatus.draft,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      rendererId: RendererId.values.firstWhere(
        (e) => e.name == json['renderer_id'],
        orElse: () => RendererId.scientific,
      ),
      themeId: ThemeId.values.firstWhere(
        (e) => e.name == json['theme_id'],
        orElse: () => ThemeId.scientific,
      ),
      narrationMode: NarrationMode.values.firstWhere(
        (e) => e.name == json['narration_mode'],
        orElse: () => NarrationMode.none,
      ),
      storyboard: Storyboard.fromJson(json['storyboard'] as Map<String, dynamic>),
    );
  }

  WhiteboardProject copyWith({
    String? id,
    String? studentId,
    String? subject,
    ProjectStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    RendererId? rendererId,
    ThemeId? themeId,
    NarrationMode? narrationMode,
    Storyboard? storyboard,
  }) {
    return WhiteboardProject(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      subject: subject ?? this.subject,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rendererId: rendererId ?? this.rendererId,
      themeId: themeId ?? this.themeId,
      narrationMode: narrationMode ?? this.narrationMode,
      storyboard: storyboard ?? this.storyboard,
    );
  }
}

// ============================================================================
// RENDER JOB
// ============================================================================

class RenderJob {
  final String id;
  final String projectId;
  final RenderJobStatus status;
  final String? videoUrl;
  final int? durationMs;
  final String? errorMessage;
  final int? progress;
  final DateTime createdAt;
  final DateTime? completedAt;

  const RenderJob({
    required this.id,
    required this.projectId,
    required this.status,
    this.videoUrl,
    this.durationMs,
    this.errorMessage,
    this.progress,
    required this.createdAt,
    this.completedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'status': status.name,
      'video_url': videoUrl,
      'duration_ms': durationMs,
      'error_message': errorMessage,
      'progress': progress,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  factory RenderJob.fromJson(Map<String, dynamic> json) {
    return RenderJob(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      status: RenderJobStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => RenderJobStatus.queued,
      ),
      videoUrl: json['video_url'] as String?,
      durationMs: json['duration_ms'] as int?,
      errorMessage: json['error_message'] as String?,
      progress: json['progress'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }

  RenderJob copyWith({
    String? id,
    String? projectId,
    RenderJobStatus? status,
    String? videoUrl,
    int? durationMs,
    String? errorMessage,
    int? progress,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return RenderJob(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      status: status ?? this.status,
      videoUrl: videoUrl ?? this.videoUrl,
      durationMs: durationMs ?? this.durationMs,
      errorMessage: errorMessage ?? this.errorMessage,
      progress: progress ?? this.progress,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
