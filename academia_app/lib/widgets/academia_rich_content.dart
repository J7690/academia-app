import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

/// Widget réutilisable pour afficher du contenu riche (Markdown + LaTeX).
///
/// Utilise [GptMarkdown] pour rendre :
/// - Texte normal
/// - LaTeX inline : `$\frac{x}{2}$`
/// - LaTeX block : `$$\int_0^1 x^2 dx$$`
/// - Markdown : **gras**, *italique*, `code`, listes, liens, tableaux
///
/// Usage :
/// ```dart
/// AcademiaRichContent(content: r"La dérivée de $f(x) = x^2$ est $f'(x) = 2x$")
/// ```
class AcademiaRichContent extends StatelessWidget {
  const AcademiaRichContent({
    super.key,
    required this.content,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.linkColor,
  });

  /// Le contenu brut (texte + LaTeX inline/block + Markdown).
  final String content;

  /// Style de texte de base (taille, couleur, etc.).
  final TextStyle? style;

  /// Nombre max de lignes (null = illimité).
  final int? maxLines;

  /// Comportement en cas de dépassement.
  final TextOverflow? overflow;

  /// Alignement du texte.
  final TextAlign? textAlign;

  /// Couleur des liens cliquables.
  final Color? linkColor;

  @override
  Widget build(BuildContext context) {
    final effectiveContent = content.trim();
    if (effectiveContent.isEmpty) return const SizedBox.shrink();

    // Si le contenu ne contient ni LaTeX ni Markdown, rendu simple Text
    if (!_hasRichContent(effectiveContent)) {
      return Text(
        effectiveContent,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
      );
    }

    final theme = Theme.of(context);
    final baseStyle = style ?? theme.textTheme.bodyMedium ?? const TextStyle();

    return GptMarkdown(
      effectiveContent,
      style: baseStyle,
      onLinkTap: (url, title) => _handleLink(url),
    );
  }

  /// Détecte si le contenu contient du LaTeX ou du Markdown.
  static bool _hasRichContent(String text) {
    // LaTeX inline $...$
    if (text.contains(r'$')) return true;
    // Markdown bold/italic
    if (text.contains('**') || text.contains('__')) return true;
    if (text.contains('*') || text.contains('_')) return true;
    // Markdown code
    if (text.contains('`')) return true;
    // Markdown headers
    if (text.contains('\n#') || text.startsWith('#')) return true;
    // Markdown links
    if (text.contains('[') && text.contains('](')) return true;
    // Markdown lists
    if (RegExp(r'^\s*[-*+]\s', multiLine: true).hasMatch(text)) return true;
    if (RegExp(r'^\s*\d+\.\s', multiLine: true).hasMatch(text)) return true;
    // LaTeX commands
    if (text.contains(r'\frac') ||
        text.contains(r'\sqrt') ||
        text.contains(r'\int') ||
        text.contains(r'\sum') ||
        text.contains(r'\vec') ||
        text.contains(r'\pi') ||
        text.contains(r'\alpha') ||
        text.contains(r'\beta') ||
        text.contains(r'\theta') ||
        text.contains(r'\infty')) return true;
    return false;
  }

  Future<void> _handleLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
