#!/usr/bin/env python3
"""Patch Flutter: supprimer les fallbacks de lecture externe pour les vidéos.

Ce script modifie uniquement :
- CourseResourceViewerScreen (erreur vidéo)
- MiniSiteMediaViewerScreen (erreur vidéo)

Comportement :
- En cas d'erreur (_error != null), on affiche le message d'erreur dans un
  simple Padding/Text, sans bouton "Ouvrir dans un lecteur externe".
- L'ouverture externe des ressources non vidéo (PDF/docs) est conservée.
"""

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

    old_error = (
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

    new_error = (
        "    if (_error != null) {\n"
        "      return Padding(\n"
        "        padding: const EdgeInsets.all(16),\n"
        "        child: Text(_error!),\n"
        "      );\n"
        "    }\n"
    )

    if "Ouvrir dans un lecteur externe" in text and old_error in text:
        text = text.replace(old_error, new_error)
        COURSE_VIEWER.write_text(text, encoding="utf-8")
        print("CourseResourceViewerScreen: suppression du fallback externe vidéo effectuée")
    else:
        print("CourseResourceViewerScreen: bloc d'erreur vidéo attendu introuvable ou déjà modifié")


def patch_mini_site_media_viewer() -> None:
    text = MINI_SITE_VIEWER.read_text(encoding="utf-8")

    old_error = (
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

    new_error = (
        "    if (_error != null) {\n"
        "      return Padding(\n"
        "        padding: const EdgeInsets.all(16),\n"
        "        child: Text(_error!),\n"
        "      );\n"
        "    }\n"
    )

    if "Ouvrir dans un lecteur externe" in text and old_error in text:
        text = text.replace(old_error, new_error)
        MINI_SITE_VIEWER.write_text(text, encoding="utf-8")
        print("MiniSiteMediaViewerScreen: suppression du fallback externe vidéo effectuée")
    else:
        print("MiniSiteMediaViewerScreen: bloc d'erreur vidéo attendu introuvable ou déjà modifié")


def main() -> int:
    patch_course_resource_viewer()
    patch_mini_site_media_viewer()
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
