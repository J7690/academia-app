#!/usr/bin/env python3
"""Audit Supabase: colonnes réelles des tables challenge/video vs RPCs."""

from supabase_auto_manager import SupabaseAutoManager
import json

def run_sql(mgr, sql):
    """Execute SQL and return parsed result."""
    result = mgr.execute_sql_auto(sql)
    if not result.get('success'):
        return None, result.get('error', 'unknown error')
    return result.get('data', []), None

def main():
    mgr = SupabaseAutoManager()

    tables = [
        'app.free_videos',
        'app.challenge_participations',
        'app.challenges',
        'app.video_assets',
        'app.video_renditions',
        'app.video_asset_contexts',
        'app.video_likes',
        'app.video_comments',
        'app.video_reports',
        'app.challenge_favorites',
        'app.challenge_video_overlays',
        'app.free_video_overlays',
        'app.challenge_user_bans',
    ]

    print("=" * 80)
    print("AUDIT SUPABASE — COLONNES DES TABLES")
    print("=" * 80)

    for table in tables:
        schema, tname = table.split('.')
        sql = f"SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_schema = '{schema}' AND table_name = '{tname}' ORDER BY ordinal_position;"
        data, err = run_sql(mgr, sql)
        print(f"\n--- {table} ---")
        if err:
            print(f"  ERREUR: {err}")
        elif data:
            for row in data:
                if isinstance(row, dict):
                    print(f"  {row.get('column_name','?'):35s} {row.get('data_type','?'):25s} null={row.get('is_nullable','?')}")
                else:
                    print(f"  {row}")
        else:
            print("  TABLE INEXISTANTE ou vide")

    print("\n" + "=" * 80)
    print("AUDIT SUPABASE — NOMBRE DE LIGNES")
    print("=" * 80)

    for table in ['app.free_videos', 'app.challenge_participations', 'app.challenges', 'app.video_assets', 'app.video_renditions']:
        sql = f"SELECT COUNT(*) as cnt FROM {table};"
        data, err = run_sql(mgr, sql)
        if err:
            print(f"  {table:40s} ERREUR: {err}")
        elif data and isinstance(data, list) and len(data) > 0:
            row = data[0]
            cnt = row.get('cnt', row) if isinstance(row, dict) else row
            print(f"  {table:40s} {cnt} lignes")
        else:
            print(f"  {table:40s} 0 ou erreur")

    print("\n" + "=" * 80)
    print("AUDIT SUPABASE — ÉCHANTILLON free_videos")
    print("=" * 80)
    data, err = run_sql(mgr, "SELECT id, user_id, video_asset_id, title, is_active, moderation_status, created_at FROM app.free_videos ORDER BY created_at DESC LIMIT 5;")
    if err:
        print(f"  ERREUR: {err}")
    elif data:
        for i, row in enumerate(data):
            print(f"\n  [Row {i}]")
            if isinstance(row, dict):
                for k, v in row.items():
                    print(f"    {k:30s} = {str(v)[:100] if v else 'NULL'}")
            else:
                print(f"    {row}")
    else:
        print("  Aucune free_video trouvée")

    print("\n" + "=" * 80)
    print("AUDIT SUPABASE — ÉCHANTILLON challenge_participations")
    print("=" * 80)
    data, err = run_sql(mgr, "SELECT id, user_id, challenge_id, video_asset_id, is_active, moderation_status, started_at FROM app.challenge_participations ORDER BY started_at DESC LIMIT 5;")
    if err:
        print(f"  ERREUR: {err}")
    elif data:
        for i, row in enumerate(data):
            print(f"\n  [Row {i}]")
            if isinstance(row, dict):
                for k, v in row.items():
                    print(f"    {k:30s} = {str(v)[:100] if v else 'NULL'}")
            else:
                print(f"    {row}")
    else:
        print("  Aucune participation trouvée")

    # Test the feed RPC directly
    print("\n" + "=" * 80)
    print("AUDIT SUPABASE — TEST DIRECT app_student_unified_video_feed")
    print("=" * 80)
    data, err = run_sql(mgr, "SELECT app_student_unified_video_feed(NULL, 5);")
    if err:
        print(f"  ERREUR: {err}")
    elif data:
        print(f"  RAW: {json.dumps(data, indent=2, default=str)[:2000]}")
    else:
        print("  Aucun résultat")

    # List RPCs
    print("\n" + "=" * 80)
    print("AUDIT SUPABASE — RPCs VIDEO/CHALLENGE")
    print("=" * 80)
    sql = """SELECT routine_schema, routine_name FROM information_schema.routines
    WHERE routine_type = 'FUNCTION' AND (
        routine_name LIKE '%challenge%' OR routine_name LIKE '%free_video%'
        OR routine_name LIKE '%video_feed%' OR routine_name LIKE '%videoasset%'
    ) ORDER BY routine_schema, routine_name;"""
    data, err = run_sql(mgr, sql)
    if err:
        print(f"  ERREUR: {err}")
    elif data:
        for row in data:
            if isinstance(row, dict):
                print(f"  {row.get('routine_schema','?'):10s} {row.get('routine_name','?')}")
            else:
                print(f"  {row}")

if __name__ == '__main__':
    main()
