#!/usr/bin/env python3
"""Audit Supabase: tables et RPCs liées aux lives et cours en ligne."""

import json
import requests
from supabase_auto_manager import SupabaseAutoManager

def sql(m, query):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": query}, timeout=30)
    return r.json()

def main():
    m = SupabaseAutoManager()
    results = {}

    # 1. Tables live sessions
    print("=== 1. Tables live sessions ===")
    q = """
    SELECT table_name, 
           (SELECT count(*) FROM information_schema.columns c WHERE c.table_schema='app' AND c.table_name=t.table_name) as col_count
    FROM information_schema.tables t
    WHERE table_schema='app' 
    AND (table_name LIKE '%live%' OR table_name LIKE '%online_course%')
    ORDER BY table_name;
    """
    res = sql(m, q)
    print(json.dumps(res, indent=2, ensure_ascii=False))
    results["live_tables"] = res

    # 2. Colonnes des tables live
    print("\n=== 2. Colonnes online_course_live_sessions ===")
    q2 = """
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='online_course_live_sessions'
    ORDER BY ordinal_position;
    """
    res2 = sql(m, q2)
    print(json.dumps(res2, indent=2, ensure_ascii=False))
    results["online_course_live_sessions_cols"] = res2

    # 3. Colonnes participants
    print("\n=== 3. Colonnes online_course_live_session_participants ===")
    q3 = """
    SELECT column_name, data_type, is_nullable
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='online_course_live_session_participants'
    ORDER BY ordinal_position;
    """
    res3 = sql(m, q3)
    print(json.dumps(res3, indent=2, ensure_ascii=False))
    results["online_course_live_session_participants_cols"] = res3

    # 4. RPCs liées aux lives et cours en ligne
    print("\n=== 4. RPCs live/online_course ===")
    q4 = """
    SELECT routine_name
    FROM information_schema.routines
    WHERE routine_schema='public'
    AND (routine_name LIKE '%live%' OR routine_name LIKE '%online_course%')
    ORDER BY routine_name;
    """
    res4 = sql(m, q4)
    print(json.dumps(res4, indent=2, ensure_ascii=False))
    results["live_rpcs"] = res4

    # 5. RPCs cours (student_course, course_library, catalog)
    print("\n=== 5. RPCs cours/library/catalog ===")
    q5 = """
    SELECT routine_name
    FROM information_schema.routines
    WHERE routine_schema='public'
    AND (routine_name LIKE '%course_library%' 
         OR routine_name LIKE '%courses_catalog%'
         OR routine_name LIKE '%student_online%'
         OR routine_name LIKE '%student_list_my_online%')
    ORDER BY routine_name;
    """
    res5 = sql(m, q5)
    print(json.dumps(res5, indent=2, ensure_ascii=False))
    results["course_rpcs"] = res5

    # 6. Tables cours en ligne
    print("\n=== 6. Tables online_courses ===")
    q6 = """
    SELECT column_name, data_type, is_nullable
    FROM information_schema.columns
    WHERE table_schema='app' AND table_name='online_courses'
    ORDER BY ordinal_position;
    """
    res6 = sql(m, q6)
    print(json.dumps(res6, indent=2, ensure_ascii=False))
    results["online_courses_cols"] = res6

    # 7. RLS policies sur les tables live
    print("\n=== 7. RLS policies live sessions ===")
    q7 = """
    SELECT schemaname, tablename, policyname, permissive, roles, cmd
    FROM pg_policies
    WHERE schemaname='app' 
    AND (tablename LIKE '%live%' OR tablename LIKE '%online_course%')
    ORDER BY tablename, policyname;
    """
    res7 = sql(m, q7)
    print(json.dumps(res7, indent=2, ensure_ascii=False))
    results["rls_policies"] = res7

    # 8. Données existantes
    print("\n=== 8. Données existantes ===")
    q8 = """
    SELECT 
      (SELECT count(*) FROM app.online_course_live_sessions) as live_sessions_count,
      (SELECT count(*) FROM app.online_course_live_session_participants) as participants_count,
      (SELECT count(*) FROM app.online_courses) as online_courses_count,
      (SELECT count(*) FROM app.prep_live_sessions) as prep_live_sessions_count;
    """
    res8 = sql(m, q8)
    print(json.dumps(res8, indent=2, ensure_ascii=False))
    results["data_counts"] = res8

    # Save
    out_path = __file__.replace('.py', '_results.json')
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    print(f"\nResults saved to {out_path}")

if __name__ == "__main__":
    main()
