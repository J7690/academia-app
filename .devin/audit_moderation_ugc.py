#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Audit UGC moderation system for Google Play compliance."""
import sys, json, requests
sys.stdout.reconfigure(encoding='utf-8')
from supabase_auto_manager import SupabaseAutoManager
m = SupabaseAutoManager()

def sql(q, timeout=60):
    r = requests.post(f"{m.url}/rest/v1/rpc/admin_execute_sql",
        headers=m.headers, json={"p_sql": q.strip()}, timeout=timeout).json()
    return r

R = {}

# 1. Tables de moderation existantes
print("=== 1. TABLES MODERATION / REPORT / BLOCK ===")
r = sql("""
    SELECT tablename FROM pg_tables WHERE schemaname='app'
    AND (tablename LIKE '%report%' OR tablename LIKE '%block%'
         OR tablename LIKE '%mute%' OR tablename LIKE '%ban%'
         OR tablename LIKE '%moderat%' OR tablename LIKE '%flag%')
    ORDER BY tablename
""")
R["moderation_tables"] = r.get("rows", [])
for row in R["moderation_tables"]:
    print(f"  {row['tablename']}")
if not R["moderation_tables"]:
    print("  AUCUNE TABLE DE MODERATION")

# 2. RPCs de moderation
print("\n=== 2. RPCs MODERATION ===")
r = sql("""
    SELECT proname FROM pg_proc
    WHERE (proname LIKE '%report%' OR proname LIKE '%block%'
           OR proname LIKE '%mute%' OR proname LIKE '%ban%'
           OR proname LIKE '%moderat%' OR proname LIKE '%suspend%'
           OR proname LIKE '%flag%')
    AND pronamespace IN (SELECT oid FROM pg_namespace WHERE nspname IN ('public','app'))
    ORDER BY proname
""")
R["moderation_rpcs"] = r.get("rows", [])
for row in R["moderation_rpcs"]:
    print(f"  {row['proname']}")

# 3. Colonnes moderation dans tables existantes
print("\n=== 3. COLONNES MODERATION ===")
for tbl in ["challenge_participations", "free_videos", "community_posts", "communities", "community_memberships"]:
    r = sql(f"SELECT column_name FROM information_schema.columns WHERE table_schema='app' AND table_name='{tbl}' AND (column_name LIKE '%moderat%' OR column_name LIKE '%report%' OR column_name LIKE '%ban%' OR column_name LIKE '%block%' OR column_name LIKE '%flag%') ORDER BY column_name")
    cols = [row["column_name"] for row in r.get("rows", [])]
    if cols:
        print(f"  {tbl}: {', '.join(cols)}")

# 4. Tables user_admin_status (pour suspension/ban)
print("\n=== 4. USER_ADMIN_STATUS ===")
r = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='user_admin_status' ORDER BY ordinal_position")
for row in r.get("rows", []):
    print(f"  {row['column_name']} ({row['data_type']})")

# 5. Tables communities (blocage/ban existants?)
print("\n=== 5. COMMUNITY MEMBERSHIPS - colonnes ban ===")
r = sql("SELECT column_name FROM information_schema.columns WHERE table_schema='app' AND table_name='community_memberships' ORDER BY ordinal_position")
for row in r.get("rows", []):
    print(f"  {row['column_name']}")

# 6. Check for content_reports table
print("\n=== 6. CONTENT_REPORTS ===")
r = sql("SELECT 1 FROM pg_tables WHERE schemaname='app' AND tablename='content_reports'")
exists = bool(r.get("rows"))
R["content_reports_exists"] = exists
print(f"  Exists: {exists}")

# 7. Check for user_blocks table
print("\n=== 7. USER_BLOCKS ===")
r = sql("SELECT 1 FROM pg_tables WHERE schemaname='app' AND tablename='user_blocks'")
exists = bool(r.get("rows"))
R["user_blocks_exists"] = exists
print(f"  Exists: {exists}")

# 8. Check video moderation
print("\n=== 8. VIDEO MODERATION STATUS ===")
r = sql("SELECT moderation_status, count(*)::int AS n FROM app.challenge_participations GROUP BY moderation_status ORDER BY moderation_status")
for row in r.get("rows", []):
    print(f"  {row.get('moderation_status','NULL')}: {row['n']}")

r2 = sql("SELECT moderation_status, count(*)::int AS n FROM app.free_videos GROUP BY moderation_status ORDER BY moderation_status")
for row in r2.get("rows", []):
    print(f"  free_videos.{row.get('moderation_status','NULL')}: {row['n']}")

# 9. Community reports
print("\n=== 9. COMMUNITY REPORTS ===")
r = sql("SELECT 1 FROM pg_tables WHERE schemaname='app' AND tablename='community_reports'")
print(f"  community_reports exists: {bool(r.get('rows'))}")
r = sql("SELECT proname FROM pg_proc WHERE proname LIKE '%report_community%' ORDER BY proname")
for row in r.get("rows", []):
    print(f"  RPC: {row['proname']}")

print("\n[OK]")
