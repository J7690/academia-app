#!/usr/bin/env python3
"""Audit ciblé v2 : colonnes, RPCs, source SQL via pg_catalog + direct REST.

Utilise pg_attribute / pg_class / pg_namespace au lieu de information_schema
(qui ne voit pas toujours le schéma app depuis une RPC SECURITY DEFINER).
"""

from __future__ import annotations

import json
import requests

from supabase_auto_manager import SupabaseAutoManager


def exec_sql(manager, label, sql):
    """Exécute du SQL et affiche le résultat."""
    print(f"\n=== {label} ===")
    r = manager.execute_sql_auto(sql)
    if r.get("success") and r.get("data"):
        print(json.dumps(r["data"], indent=2, ensure_ascii=False))
    elif r.get("success"):
        # Peut-être un JSONB retourné directement
        print("  (aucun résultat)")
    else:
        print(f"  ERREUR: {r.get('error', 'inconnu')}")
    return r


def call_rpc_raw(manager, rpc_name, payload=None):
    """Appelle une RPC via REST et retourne le body JSON brut."""
    url = f"{manager.url}/rest/v1/rpc/{rpc_name}"
    try:
        resp = requests.post(url, headers=manager.headers, json=payload or {}, timeout=15)
        return resp.status_code, resp.json() if resp.text else None
    except Exception as e:
        return 0, {"error": str(e)}


def main() -> int:
    manager = SupabaseAutoManager()

    print("=" * 70)
    print("AUDIT V2 — COMMUNAUTÉS VOCAUX & DOCS (pg_catalog)")
    print("=" * 70)

    # ── 1. Colonnes app.community_posts via pg_catalog ──
    exec_sql(manager, "1. COLONNES app.community_posts",
    """
    SELECT a.attname AS column_name,
           pg_catalog.format_type(a.atttypid, a.atttypmod) AS data_type,
           NOT a.attnotnull AS is_nullable
    FROM pg_catalog.pg_attribute a
    JOIN pg_catalog.pg_class c ON a.attrelid = c.oid
    JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
    WHERE n.nspname = 'app'
      AND c.relname = 'community_posts'
      AND a.attnum > 0
      AND NOT a.attisdropped
    ORDER BY a.attnum
    """)

    # ── 2. Colonnes app.direct_messages ──
    exec_sql(manager, "2. COLONNES app.direct_messages",
    """
    SELECT a.attname AS column_name,
           pg_catalog.format_type(a.atttypid, a.atttypmod) AS data_type,
           NOT a.attnotnull AS is_nullable
    FROM pg_catalog.pg_attribute a
    JOIN pg_catalog.pg_class c ON a.attrelid = c.oid
    JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
    WHERE n.nspname = 'app'
      AND c.relname = 'direct_messages'
      AND a.attnum > 0
      AND NOT a.attisdropped
    ORDER BY a.attnum
    """)

    # ── 3. Colonnes app.direct_conversations ──
    exec_sql(manager, "3. COLONNES app.direct_conversations",
    """
    SELECT a.attname AS column_name,
           pg_catalog.format_type(a.atttypid, a.atttypmod) AS data_type,
           NOT a.attnotnull AS is_nullable
    FROM pg_catalog.pg_attribute a
    JOIN pg_catalog.pg_class c ON a.attrelid = c.oid
    JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
    WHERE n.nspname = 'app'
      AND c.relname = 'direct_conversations'
      AND a.attnum > 0
      AND NOT a.attisdropped
    ORDER BY a.attnum
    """)

    # ── 4. Colonnes app.students ──
    exec_sql(manager, "4. COLONNES app.students",
    """
    SELECT a.attname AS column_name,
           pg_catalog.format_type(a.atttypid, a.atttypmod) AS data_type
    FROM pg_catalog.pg_attribute a
    JOIN pg_catalog.pg_class c ON a.attrelid = c.oid
    JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
    WHERE n.nspname = 'app'
      AND c.relname = 'students'
      AND a.attnum > 0
      AND NOT a.attisdropped
    ORDER BY a.attnum
    """)

    # ── 5. Source SQL de app_student_list_community_posts ──
    exec_sql(manager, "5. SOURCE app_student_list_community_posts",
    """
    SELECT pg_catalog.pg_get_functiondef(p.oid) AS source
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = 'app_student_list_community_posts'
    """)

    # ── 6. Source SQL de app_student_list_direct_messages ──
    exec_sql(manager, "6. SOURCE app_student_list_direct_messages",
    """
    SELECT pg_catalog.pg_get_functiondef(p.oid) AS source
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = 'app_student_list_direct_messages'
    """)

    # ── 7. Source SQL de app_student_add_community_post ──
    exec_sql(manager, "7. SOURCE app_student_add_community_post",
    """
    SELECT pg_catalog.pg_get_functiondef(p.oid) AS source
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = 'app_student_add_community_post'
    """)

    # ── 8. Source SQL de app_student_send_direct_message ──
    exec_sql(manager, "8. SOURCE app_student_send_direct_message",
    """
    SELECT pg_catalog.pg_get_functiondef(p.oid) AS source
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = 'app_student_send_direct_message'
    """)

    # ── 9. Toutes les RPCs communauté/DM ──
    exec_sql(manager, "9. TOUTES RPCs COMMUNAUTÉ/DM",
    """
    SELECT n.nspname AS schema, p.proname AS function_name,
           pg_catalog.pg_get_function_arguments(p.oid) AS args
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname LIKE 'app_student_%communit%'
       OR p.proname LIKE 'app_admin_%communit%'
       OR p.proname LIKE 'app_student_%dm%'
       OR p.proname LIKE 'app_student_%direct%'
    ORDER BY p.proname
    """)

    # ── 10. Bucket storage ──
    exec_sql(manager, "10. BUCKET community-media",
    """
    SELECT id, name, public, file_size_limit, allowed_mime_types
    FROM storage.buckets
    WHERE name = 'community-media'
    """)

    # ── 11. Policies storage ──
    exec_sql(manager, "11. POLICIES STORAGE community-media",
    """
    SELECT pol.polname, pol.polcmd
    FROM pg_catalog.pg_policy pol
    JOIN pg_catalog.pg_class c ON pol.polrelid = c.oid
    JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
    WHERE n.nspname = 'storage' AND c.relname = 'objects'
      AND pol.polname ILIKE '%community%'
    """)

    # ── 12. Posts non-texte ──
    exec_sql(manager, "12. POSTS NON-TEXTE (échantillon)",
    """
    SELECT id, community_id, author_id, type, media_url,
           LEFT(content, 50) AS content_preview, created_at
    FROM app.community_posts
    WHERE type IS DISTINCT FROM 'text' AND is_deleted = FALSE
    ORDER BY created_at DESC
    LIMIT 10
    """)

    # ── 13. DMs non-texte ──
    exec_sql(manager, "13. DMs NON-TEXTE (échantillon)",
    """
    SELECT id, conversation_id, sender_id, type, media_url,
           LEFT(content, 50) AS content_preview, created_at
    FROM app.direct_messages
    WHERE type IS DISTINCT FROM 'text' AND is_deleted = FALSE
    ORDER BY created_at DESC
    LIMIT 10
    """)

    # ── 14. Nombre total de posts par type ──
    exec_sql(manager, "14. RÉPARTITION POSTS PAR TYPE",
    """
    SELECT type, COUNT(*) AS cnt
    FROM app.community_posts
    WHERE is_deleted = FALSE
    GROUP BY type
    ORDER BY cnt DESC
    """)

    # ── 15. Nombre total de DMs par type ──
    exec_sql(manager, "15. RÉPARTITION DMs PAR TYPE",
    """
    SELECT type, COUNT(*) AS cnt
    FROM app.direct_messages
    WHERE is_deleted = FALSE
    GROUP BY type
    ORDER BY cnt DESC
    """)

    print("\n" + "=" * 70)
    print("FIN AUDIT V2")
    print("=" * 70)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
