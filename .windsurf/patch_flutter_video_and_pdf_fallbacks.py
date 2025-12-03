from __future__ import annotations

from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent.parent
FLUTTER_DIR = BASE_DIR / "academia_app"
COURSE_VIEWER = (
    FLUTTER_DIR
    / "lib"
    / "features"
    / "student"
    / "course_resource_viewer_screen.dart"
)
MINI_SITE_VIEWER = (
    FLUTTER_DIR
    / "lib"
    / "features"
    / "student"
    / "mini_site_media_viewer_screen.dart"
)


def patch_course_resource_viewer() -> None:
    text = COURSE_VIEWER.read_text(encoding="utf-8")

    # 1) Ajouter _resolvedUrl dans les champs d'état
    if "_resolvedUrl" not in text:
        old_fields = "  String? _url;\n  String? _error;\n  bool _isLoading = true;\n"
        new_fields = (
            "  String? _url;\n  String? _resolvedUrl;\n  String? _error;\n  bool _isLoading = true;\n"
        )
        if old_fields not in text:
            raise SystemExit("CourseResourceViewer: state fields anchor not found")
        text = text.replace(old_fields, new_fields)

    # 2) Sauvegarder resolvedUrl dans _resolvedUrl juste avant le traitement du type
    if "_resolvedUrl = resolvedUrl;" not in text:
        marker = "      final lowerUrl = resolvedUrl.toLowerCase();\n"
        if marker not in text:
            raise SystemExit(
                "CourseResourceViewer: 'final lowerUrl' marker not found for insertion"
            )
        replacement = (
            "      _resolvedUrl = resolvedUrl;\n\n" + marker
        )
        text = text.replace(marker, replacement)

    # 3) Remplacer l'affichage d'erreur par une version avec bouton de fallback
    old_error = (
        "    if (_error != null) {\n"
        "      return Padding(\n"
        "        padding: const EdgeInsets.all(16),\n"
        "        child: Text(_error!),\n"
        "      );\n"
        "    }\n"
    )
    new_error = (
        "    if (_error != null) {\n"
        "      final url = _resolvedUrl;\n"
        "      return Padding(\n"
        "        padding: const EdgeInsets.all(16),\n"
        "        child: Column(\n"
        "          mainAxisSize: MainAxisSize.min,\n"
        "          children: [\n"
        "            Text(_error!),\n"
        "            if (url != null && url.isNotEmpty) ...[\n"
        "              const SizedBox(height: 16),\n"
        "              ElevatedButton.icon(\n"
        "                onPressed: () async {\n"
        "                  final uri = Uri.tryParse(url);\n"
        "                  if (uri == null) {\n"
        "                    return;\n"
        "                  }\n"
        "                  await launchUrl(\n"
        "                    uri,\n"
        "                    mode: LaunchMode.externalApplication,\n"
        "                  );\n"
        "                },\n"
        "                icon: const Icon(Icons.open_in_new),\n"
        "                label: const Text('Ouvrir dans un lecteur externe'),\n"
        "              ),\n"
        "            ],\n"
        "          ],\n"
        "        ),\n"
        "      );\n"
        "    }\n"
    )
    if "Ouvrir dans un lecteur externe" not in text:
        if old_error not in text:
            raise SystemExit("CourseResourceViewer: error display block not found")
        text = text.replace(old_error, new_error)

    # 4) Pour les ressources non vidéo (PDF, docs), ouvrir en application externe
    old_launch = (
        "              await launchUrl(\n"
        "                uri,\n"
        "                mode: LaunchMode.inAppWebView,\n"
        "              );\n"
        "            },\n"
    )
    new_launch = (
        "              await launchUrl(\n"
        "                uri,\n"
        "                mode: LaunchMode.externalApplication,\n"
        "              );\n"
        "            },\n"
    )
    if "LaunchMode.externalApplication" not in text:
        if old_launch not in text:
            raise SystemExit("CourseResourceViewer: launchUrl block not found")
        text = text.replace(old_launch, new_launch)

    COURSE_VIEWER.write_text(text, encoding="utf-8")
    print("Patched CourseResourceViewerScreen with video/PDF fallbacks")


def patch_mini_site_media_viewer() -> None:
    text = MINI_SITE_VIEWER.read_text(encoding="utf-8")

    # 0) S'assurer que l'import url_launcher est présent
    if "url_launcher.dart" not in text:
        import_marker = "import 'package:video_player/video_player.dart';\n"
        if import_marker not in text:
            raise SystemExit(
                "MiniSiteMediaViewer: video_player import marker not found for url_launcher import"
            )
        replacement_imports = (
            import_marker
            + "import 'package:url_launcher/url_launcher.dart';\n"
        )
        text = text.replace(import_marker, replacement_imports)

    # 1) Ajouter _resolvedUrl dans les champs d'état
    if "_resolvedUrl" not in text:
        old_fields = "  String? _url;\n  String? _error;\n  bool _isLoading = true;\n"
        new_fields = (
            "  String? _url;\n  String? _resolvedUrl;\n  String? _error;\n  bool _isLoading = true;\n"
        )
        if old_fields not in text:
            raise SystemExit("MiniSiteMediaViewer: state fields anchor not found")
        text = text.replace(old_fields, new_fields)

    # 2) Sauvegarder resolvedUrl dans _resolvedUrl avant le test HLS
    if "_resolvedUrl = resolvedUrl;" not in text:
        marker = "      final isHls = resolvedUrl.toLowerCase().contains('.m3u8');\n"
        if marker not in text:
            raise SystemExit(
                "MiniSiteMediaViewer: 'final isHls' marker not found for insertion"
            )
        replacement = "      _resolvedUrl = resolvedUrl;\n\n" + marker
        text = text.replace(marker, replacement)

    # 3) Remplacer l'affichage d'erreur par une version avec bouton de fallback
    old_error = (
        "    if (_error != null) {\n"
        "      return Padding(\n"
        "        padding: const EdgeInsets.all(16),\n"
        "        child: Text(_error!),\n"
        "      );\n"
        "    }\n"
    )
    new_error = (
        "    if (_error != null) {\n"
        "      final url = _resolvedUrl;\n"
        "      return Padding(\n"
        "        padding: const EdgeInsets.all(16),\n"
        "        child: Column(\n"
        "          mainAxisSize: MainAxisSize.min,\n"
        "          children: [\n"
        "            Text(_error!),\n"
        "            if (url != null && url.isNotEmpty) ...[\n"
        "              const SizedBox(height: 16),\n"
        "              ElevatedButton.icon(\n"
        "                onPressed: () async {\n"
        "                  final uri = Uri.tryParse(url);\n"
        "                  if (uri == null) {\n"
        "                    return;\n"
        "                  }\n"
        "                  await launchUrl(\n"
        "                    uri,\n"
        "                    mode: LaunchMode.externalApplication,\n"
        "                  );\n"
        "                },\n"
        "                icon: const Icon(Icons.open_in_new),\n"
        "                label: const Text('Ouvrir dans un lecteur externe'),\n"
        "              ),\n"
        "            ],\n"
        "          ],\n"
        "        ),\n"
        "      );\n"
        "    }\n"
    )
    if "Ouvrir dans un lecteur externe" not in text:
        if old_error not in text:
            raise SystemExit("MiniSiteMediaViewer: error display block not found")
        text = text.replace(old_error, new_error)

    MINI_SITE_VIEWER.write_text(text, encoding="utf-8")
    print("Patched MiniSiteMediaViewerScreen with video fallbacks")


def main() -> int:
    patch_course_resource_viewer()
    patch_mini_site_media_viewer()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
