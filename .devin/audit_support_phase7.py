#!/usr/bin/env python3
"""Phase 7 — Audit Supabase avant ajout médias au Support.
Vérifie:
1. Colonnes exactes de app.support_messages
2. Source exacte des 4 RPCs à modifier
3. Buckets de stockage disponibles
4. Edge Function setup-storage-policies existence
5. Config du bucket community-media
"""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

def run_sql(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=30)
    d = r.json() if r.text else {}
    rows = d.get("rows", []) if isinstance(d, dict) else []
    if not isinstance(rows, list): rows = []
    print(f"\n{'='*60}")
    print(f"AUDIT: {label}")
    print(f"{'='*60}")
    for row in rows[:30]:
        # Truncate src fields for readability
        display = {}
        for k, v in row.items():
            sv = str(v) if v is not None else "NULL"
            display[k] = sv[:300] if len(sv) > 300 else sv
        print(f"  {json.dumps(display, ensure_ascii=False)}")
    if not rows:
        print("  (0 rows)")
    return rows

def main():
    m = SupabaseAutoManager()

    # 1. Colonnes exactes de support_messages
    run_sql(m, "1. Colonnes de app.support_messages",
        """SELECT column_name, data_type, column_default, is_nullable
           FROM information_schema.columns
           WHERE table_schema='app' AND table_name='support_messages'
           ORDER BY ordinal_position""")

    # 2. Colonnes exactes de support_conversations
    run_sql(m, "2. Colonnes de app.support_conversations",
        """SELECT column_name, data_type
           FROM information_schema.columns
           WHERE table_schema='app' AND table_name='support_conversations'
           ORDER BY ordinal_position""")

    # 3. Source de app_send_support_message
    run_sql(m, "3. Source app_send_support_message",
        """SELECT pg_get_functiondef(p.oid) AS src
           FROM pg_catalog.pg_proc p
           JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
           WHERE n.nspname='public' AND p.proname='app_send_support_message'""")

    # 4. Source de app_admin_send_support_message
    run_sql(m, "4. Source app_admin_send_support_message",
        """SELECT pg_get_functiondef(p.oid) AS src
           FROM pg_catalog.pg_proc p
           JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
           WHERE n.nspname='public' AND p.proname='app_admin_send_support_message'""")

    # 5. Source de app_list_support_messages
    run_sql(m, "5. Source app_list_support_messages",
        """SELECT pg_get_functiondef(p.oid) AS src
           FROM pg_catalog.pg_proc p
           JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
           WHERE n.nspname='public' AND p.proname='app_list_support_messages'""")

    # 6. Source de app_admin_list_support_messages
    run_sql(m, "6. Source app_admin_list_support_messages",
        """SELECT pg_get_functiondef(p.oid) AS src
           FROM pg_catalog.pg_proc p
           JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
           WHERE n.nspname='public' AND p.proname='app_admin_list_support_messages'""")

    # 7. Buckets storage
    run_sql(m, "7. Buckets de stockage",
        """SELECT id, name, public, file_size_limit, allowed_mime_types
           FROM storage.buckets
           ORDER BY name""")

    # 8. Check existing data in support_messages
    run_sql(m, "8. Messages support existants (sample)",
        """SELECT id, conversation_id, sender_side, LEFT(content, 50) AS content_preview, created_at
           FROM app.support_messages
           ORDER BY created_at DESC LIMIT 5""")

    print(f"\n{'='*60}")
    print("AUDIT PHASE 7 TERMINÉ")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()
