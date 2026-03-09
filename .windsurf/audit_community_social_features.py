#!/usr/bin/env python3
"""
Audit Supabase: tables communautaires sociales existantes
- community_post_reactions, community_polls, community_poll_votes
- community_read_states, community_stories (si existe)
- app.students colonnes (avatar_url?)
- RPCs liées aux reactions/polls/read_states
"""

import requests, json, sys

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {
    "apikey": KEY,
    "Authorization": f"Bearer {KEY}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}

def run_sql(sql):
    """Execute SQL via admin_execute_sql RPC"""
    r = requests.post(
        f"{URL}/rest/v1/rpc/admin_execute_sql",
        headers=HEADERS,
        json={"sql_text": sql},
        timeout=30,
    )
    if r.status_code == 200:
        data = r.json()
        if isinstance(data, dict) and "result" in data:
            return data["result"]
        return data
    else:
        # Fallback: try execute_sql
        r2 = requests.post(
            f"{URL}/rest/v1/rpc/execute_sql",
            headers=HEADERS,
            json={"sql_query": sql},
            timeout=30,
        )
        if r2.status_code == 200:
            return r2.json()
        return {"error": f"HTTP {r.status_code}: {r.text[:500]}"}

def section(title):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")

# ─── 1) Lister toutes les tables du schema app liées aux communautés ───
section("1. TABLES SCHEMA APP (community*)")
result = run_sql("""
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'app'
      AND table_name LIKE 'community%'
    ORDER BY table_name
""")
print(json.dumps(result, indent=2, default=str))

# ─── 2) Colonnes de community_post_reactions ───
section("2. COLONNES: community_post_reactions")
result = run_sql("""
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema = 'app' AND table_name = 'community_post_reactions'
    ORDER BY ordinal_position
""")
print(json.dumps(result, indent=2, default=str))

# ─── 3) Colonnes de community_polls ───
section("3. COLONNES: community_polls")
result = run_sql("""
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema = 'app' AND table_name = 'community_polls'
    ORDER BY ordinal_position
""")
print(json.dumps(result, indent=2, default=str))

# ─── 4) Colonnes de community_poll_votes ───
section("4. COLONNES: community_poll_votes")
result = run_sql("""
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema = 'app' AND table_name = 'community_poll_votes'
    ORDER BY ordinal_position
""")
print(json.dumps(result, indent=2, default=str))

# ─── 5) Colonnes de community_read_states ───
section("5. COLONNES: community_read_states")
result = run_sql("""
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema = 'app' AND table_name = 'community_read_states'
    ORDER BY ordinal_position
""")
print(json.dumps(result, indent=2, default=str))

# ─── 6) Colonnes de community_posts ───
section("6. COLONNES: community_posts")
result = run_sql("""
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema = 'app' AND table_name = 'community_posts'
    ORDER BY ordinal_position
""")
print(json.dumps(result, indent=2, default=str))

# ─── 7) Colonnes de community_memberships ───
section("7. COLONNES: community_memberships")
result = run_sql("""
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema = 'app' AND table_name = 'community_memberships'
    ORDER BY ordinal_position
""")
print(json.dumps(result, indent=2, default=str))

# ─── 8) Colonnes de app.students ───
section("8. COLONNES: app.students")
result = run_sql("""
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema = 'app' AND table_name = 'students'
    ORDER BY ordinal_position
""")
print(json.dumps(result, indent=2, default=str))

# ─── 9) Vérifier si community_stories existe ───
section("9. TABLE community_stories EXISTE?")
result = run_sql("""
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'app'
      AND table_name LIKE '%stor%'
""")
print(json.dumps(result, indent=2, default=str))

# ─── 10) RPCs liées aux communautés ───
section("10. RPCs COMMUNAUTE (fonctions publiques)")
result = run_sql("""
    SELECT routine_name
    FROM information_schema.routines
    WHERE routine_schema = 'public'
      AND routine_name LIKE '%community%'
    ORDER BY routine_name
""")
print(json.dumps(result, indent=2, default=str))

# ─── 11) RPCs liées aux reactions/polls/read ───
section("11. RPCs REACTIONS/POLLS/READ")
result = run_sql("""
    SELECT routine_name
    FROM information_schema.routines
    WHERE routine_schema = 'public'
      AND (routine_name LIKE '%reaction%'
           OR routine_name LIKE '%poll%'
           OR routine_name LIKE '%read_state%'
           OR routine_name LIKE '%read%community%')
    ORDER BY routine_name
""")
print(json.dumps(result, indent=2, default=str))

# ─── 12) RLS policies sur les tables communautaires ───
section("12. RLS POLICIES (community tables)")
result = run_sql("""
    SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
    FROM pg_policies
    WHERE schemaname = 'app'
      AND tablename LIKE 'community%'
    ORDER BY tablename, policyname
""")
print(json.dumps(result, indent=2, default=str))

# ─── 13) Données existantes: compter les lignes ───
section("13. COMPTAGE DONNEES EXISTANTES")
for table in [
    "community_post_reactions",
    "community_polls",
    "community_poll_votes",
    "community_read_states",
    "community_posts",
    "community_memberships",
    "communities",
]:
    result = run_sql(f"SELECT COUNT(*) as cnt FROM app.{table}")
    print(f"  {table}: {json.dumps(result, default=str)}")

# ─── 14) Storage buckets ───
section("14. STORAGE BUCKETS")
result = run_sql("""
    SELECT id, name, public, file_size_limit, allowed_mime_types
    FROM storage.buckets
    ORDER BY name
""")
print(json.dumps(result, indent=2, default=str))

# ─── 15) Sample community_post_reactions ───
section("15. SAMPLE community_post_reactions (5 rows)")
result = run_sql("""
    SELECT * FROM app.community_post_reactions LIMIT 5
""")
print(json.dumps(result, indent=2, default=str))

# ─── 16) Sample community_polls ───
section("16. SAMPLE community_polls (5 rows)")
result = run_sql("""
    SELECT * FROM app.community_polls LIMIT 5
""")
print(json.dumps(result, indent=2, default=str))

print("\n\n✅ Audit terminé.")
