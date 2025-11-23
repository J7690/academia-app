#!/usr/bin/env python3
"""Audit des mini-sites université (médias + hero) via SupabaseAutoManager.

Ce script est conçu pour être utilisé par Windsurf dans le dossier .windsurf.
Il utilise la clé service_role déjà configurée dans SupabaseAutoManager
pour appeler les RPC publiques et les tables REST, en lecture seule.

Objectifs pour chaque université (principalement `universite-arbilo` pour l'instant) :
- Vérifier les médias vidéo publics (is_active = TRUE) visibles côté étudiant
  via la RPC app_public_university_site(slug).
- Vérifier la configuration hero (hero_poster_media_id) et sa cohérence avec les médias.
- Comparer avec la table brute app.university_media (via API REST, profil app)
  pour repérer les médias inactifs ou incohérents.
"""

from __future__ import annotations

import json
import sys
from typing import Any, Dict, List

import requests

from supabase_auto_manager import SupabaseAutoManager


def _print_json(obj: Any, max_chars: int = 800) -> None:
    try:
        txt = json.dumps(obj, indent=2, ensure_ascii=False)
    except Exception:
        txt = str(obj)
    print(txt[:max_chars])


def audit_university_site(slug: str, manager: SupabaseAutoManager) -> int:
    base = manager.url
    headers = manager.headers

    print(f"=== Audit mini-site université pour slug='{slug}' ===")

    # 1) Appeler la RPC publique utilisée par le mini-site étudiant
    url_rpc = f"{base}/rest/v1/rpc/app_public_university_site"
    try:
        r = requests.post(url_rpc, headers=headers, json={"p_slug": slug}, timeout=30)
    except Exception as e:
        print(f"❌ Exception lors de l'appel RPC app_public_university_site: {e}")
        return 1

    print("RPC app_public_university_site HTTP", r.status_code)
    try:
        data = r.json()
    except Exception:
        print(r.text[:800])
        return 1

    if not isinstance(data, dict):
        print("❌ Réponse inattendue (non-JSON objet)")
        _print_json(data)
        return 1

    if not data.get("success"):
        print("❌ RPC app_public_university_site a renvoyé success=false")
        _print_json(data)
        return 1

    university = data.get("university") or {}
    media_public: List[Dict[str, Any]] = data.get("media") or []
    config = data.get("config") or {}

    uni_id = university.get("id")
    uni_name = university.get("name")

    print("Université:", uni_name, "(id=", uni_id, ")")
    print("Médias publics totaux (RPC):", len(media_public))

    video_public = [
        m
        for m in media_public
        if "video" in (m.get("media_type") or "").lower()
    ]
    print("Médias vidéo publics (RPC):", len(video_public))

    hero_id = config.get("hero_poster_media_id")
    print("hero_poster_media_id:", hero_id)

    if hero_id:
        hero_pub = next((m for m in media_public if str(m.get("id")) == str(hero_id)), None)
        if hero_pub:
            print("✔ Hero trouvé parmi les médias publics:")
            _print_json(
                {
                    "id": hero_pub.get("id"),
                    "title": hero_pub.get("title"),
                    "media_type": hero_pub.get("media_type"),
                    "is_active": hero_pub.get("is_active"),
                    "url": (hero_pub.get("url") or "")[:200],
                }
            )
        else:
            print("⚠ hero_poster_media_id ne correspond à aucun média public renvoyé par la RPC.")
    else:
        print("⚠ Aucun hero_poster_media_id défini dans la config du mini-site.")

    # 2) Lire la table brute app.university_media via API REST (profil app)
    if not uni_id:
        print("⚠ Impossible de charger app.university_media: university.id manquant dans la RPC.")
        return 0

    headers_app = dict(headers)
    headers_app["Accept-Profile"] = "app"
    headers_app["Content-Profile"] = "app"

    url_media = f"{base}/rest/v1/university_media?select=*&university_id=eq.{uni_id}"
    try:
        r_media = requests.get(url_media, headers=headers_app, timeout=30)
    except Exception as e:
        print(f"❌ Exception lors de la lecture de app.university_media: {e}")
        return 1

    print("REST app.university_media HTTP", r_media.status_code)
    try:
        media_all = r_media.json()
    except Exception:
        print(r_media.text[:800])
        return 1

    if not isinstance(media_all, list):
        print("❌ Réponse inattendue pour university_media (attendu: liste)")
        _print_json(media_all)
        return 1

    print("Médias totaux (table app.university_media):", len(media_all))

    video_all = [
        m
        for m in media_all
        if "video" in (m.get("media_type") or "").lower()
    ]
    video_active = [m for m in video_all if m.get("is_active") is not False]

    print("Médias vidéo (tous):", len(video_all))
    print("Médias vidéo actifs (table):", len(video_active))

    if video_all and not video_active:
        print("⚠ Il existe des vidéos, mais aucune n'est active (is_active = TRUE). L'étudiant ne verra aucune vidéo.")

    # Si un hero est défini, vérifier son statut dans la table brute
    if hero_id:
        hero_row = next((m for m in media_all if str(m.get("id")) == str(hero_id)), None)
        if hero_row:
            print("État du hero dans app.university_media:")
            _print_json(
                {
                    "id": hero_row.get("id"),
                    "media_type": hero_row.get("media_type"),
                    "is_active": hero_row.get("is_active"),
                    "url": (hero_row.get("url") or "")[:200],
                    "storage_path": hero_row.get("storage_path"),
                    "sort_order": hero_row.get("sort_order"),
                }
            )
        else:
            print("⚠ hero_poster_media_id ne correspond à aucun enregistrement dans app.university_media.")

    print("\nRésumé rapide:")
    print(" - Université:", uni_name or "(sans nom)")
    print(" - Médias vidéo publics (RPC):", len(video_public))
    print(" - Médias vidéo actifs (table):", len(video_active))
    print(" - Hero défini:", bool(hero_id))

    return 0


def main() -> int:
    manager = SupabaseAutoManager()

    # Slug passé en argument, sinon défaut universite-arbilo (cas actuel)
    if len(sys.argv) > 1:
        slug = sys.argv[1]
    else:
        slug = "universite-arbilo"

    return audit_university_site(slug, manager)


if __name__ == "__main__":
    raise SystemExit(main())
