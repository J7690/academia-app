#!/usr/bin/env python3
"""Run community audit queries one by one and print results."""
import json
import sys
sys.stdout.reconfigure(encoding='utf-8')

from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()

queries = [
    ("TABLES_COMMUNAUTES_APP", "SELECT table_schema, table_name FROM information_schema.tables WHERE table_schema = 'app' AND table_name ILIKE '%communit%' ORDER BY table_name"),
    ("TOUTES_TABLES_APP", "SELECT table_schema, table_name FROM information_schema.tables WHERE table_schema = 'app' ORDER BY table_name"),
    ("COLONNES_COMMUNITIES", "SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_schema = 'app' AND table_name = 'communities' ORDER BY ordinal_position"),
    ("COLONNES_COMMUNITY_MEMBERSHIPS", "SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_schema = 'app' AND table_name = 'community_memberships' ORDER BY ordinal_position"),
    ("COLONNES_COMMUNITY_POSTS", "SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_schema = 'app' AND table_name = 'community_posts' ORDER BY ordinal_position"),
    ("COLONNES_COMMUNITY_POLLS", "SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_schema = 'app' AND table_name = 'community_polls' ORDER BY ordinal_position"),
    ("COLONNES_COMMUNITY_POLL_VOTES", "SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_schema = 'app' AND table_name = 'community_poll_votes' ORDER BY ordinal_position"),
    ("COLONNES_COMMUNITY_POST_REACTIONS", "SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_schema = 'app' AND table_name = 'community_post_reactions' ORDER BY ordinal_position"),
    ("COLONNES_COMMUNITY_READ_STATES", "SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_schema = 'app' AND table_name = 'community_read_states' ORDER BY ordinal_position"),
    ("COLONNES_COMMUNITY_JOIN_REQUESTS", "SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_schema = 'app' AND table_name = 'community_join_requests' ORDER BY ordinal_position"),
    ("COLONNES_SPECIALES", "SELECT table_name, column_name, data_type FROM information_schema.columns WHERE table_schema = 'app' AND table_name ILIKE '%communit%' AND column_name IN ('is_pinned','edited_at','role','is_announcement','is_admin','is_moderator','pinned_post_id','edited_content') ORDER BY table_name, column_name"),
    ("FONCTIONS_COMMUNITY", "SELECT n.nspname AS schema, p.proname AS function_name, pg_get_function_arguments(p.oid) AS arguments FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE p.proname ILIKE '%communit%' AND n.nspname NOT IN ('pg_catalog','information_schema') ORDER BY p.proname"),
    ("ROW_COUNTS", "SELECT 'communities' AS t, COUNT(*) AS n FROM app.communities UNION ALL SELECT 'community_memberships', COUNT(*) FROM app.community_memberships UNION ALL SELECT 'community_posts', COUNT(*) FROM app.community_posts UNION ALL SELECT 'community_polls', COUNT(*) FROM app.community_polls"),
]

for label, sql in queries:
    print(f"\n### {label} ###")
    r = m.execute_sql_auto(sql)
    if r.get("success"):
        data = r.get("data", [])
        if data:
            print(json.dumps(data, indent=2, ensure_ascii=False, default=str))
        else:
            print("  (vide)")
    else:
        print(f"  ERR: {r.get('error','?')}")

print("\n### AUDIT DONE ###")
