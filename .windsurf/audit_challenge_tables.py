#!/usr/bin/env python3
"""Audit Supabase: vérifie les colonnes réelles des tables challenge_* et free_videos
et compare avec ce que les RPCs attendent."""

from supabase_auto_manager import SupabaseAutoManager

def main():
    mgr = SupabaseAutoManager()

    tables_to_audit = [
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
    print("AUDIT SUPABASE — COLONNES DES TABLES CHALLENGE/VIDEO")
    print("=" * 80)

    for table in tables_to_audit:
        schema, tname = table.split('.')
        sql = f"""
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = '{schema}' AND table_name = '{tname}'
        ORDER BY ordinal_position;
        """
        print(f"\n--- {table} ---")
        try:
            result = mgr.client.rpc('admin_execute_sql', {'p_sql': sql}).execute()
            data = result.data
            if isinstance(data, list) and len(data) > 0:
                for row in data:
                    if isinstance(row, dict):
                        print(f"  {row.get('column_name', '?'):30s} {row.get('data_type', '?'):20s} nullable={row.get('is_nullable', '?')}")
                    else:
                        print(f"  {row}")
            elif isinstance(data, dict):
                # admin_execute_sql may return {rows: [...]}
                rows = data.get('rows', data.get('result', []))
                if isinstance(rows, list):
                    for row in rows:
                        if isinstance(row, dict):
                            print(f"  {row.get('column_name', '?'):30s} {row.get('data_type', '?'):20s} nullable={row.get('is_nullable', '?')}")
                        elif isinstance(row, list) and len(row) >= 2:
                            print(f"  {str(row[0]):30s} {str(row[1]):20s}")
                        else:
                            print(f"  {row}")
                else:
                    print(f"  RAW: {data}")
            else:
                print(f"  RAW: {data}")
        except Exception as e:
            print(f"  ERREUR: {e}")

    # Also check which RPCs exist for challenges/videos
    print("\n" + "=" * 80)
    print("AUDIT SUPABASE — RPCs CHALLENGE/VIDEO EXISTANTES")
    print("=" * 80)

    rpc_sql = """
    SELECT routine_name, routine_schema
    FROM information_schema.routines
    WHERE routine_type = 'FUNCTION'
      AND (
        routine_name LIKE '%challenge%'
        OR routine_name LIKE '%free_video%'
        OR routine_name LIKE '%video_feed%'
        OR routine_name LIKE '%videoasset%'
        OR routine_name LIKE '%video_like%'
        OR routine_name LIKE '%video_comment%'
        OR routine_name LIKE '%video_report%'
      )
    ORDER BY routine_schema, routine_name;
    """
    try:
        result = mgr.client.rpc('admin_execute_sql', {'p_sql': rpc_sql}).execute()
        data = result.data
        if isinstance(data, dict):
            rows = data.get('rows', data.get('result', []))
            if isinstance(rows, list):
                for row in rows:
                    if isinstance(row, dict):
                        print(f"  {row.get('routine_schema', '?'):10s} {row.get('routine_name', '?')}")
                    elif isinstance(row, list) and len(row) >= 2:
                        print(f"  {str(row[0]):10s} {str(row[1])}")
                    else:
                        print(f"  {row}")
            else:
                print(f"  RAW: {data}")
        elif isinstance(data, list):
            for row in data:
                print(f"  {row}")
        else:
            print(f"  RAW: {data}")
    except Exception as e:
        print(f"  ERREUR: {e}")

    # Count rows in key tables
    print("\n" + "=" * 80)
    print("AUDIT SUPABASE — NOMBRE DE LIGNES")
    print("=" * 80)

    count_tables = [
        'app.free_videos',
        'app.challenge_participations',
        'app.challenges',
        'app.video_assets',
        'app.video_renditions',
    ]
    for table in count_tables:
        try:
            result = mgr.client.rpc('admin_execute_sql', {'p_sql': f"SELECT COUNT(*) as cnt FROM {table};"}).execute()
            data = result.data
            if isinstance(data, dict):
                rows = data.get('rows', data.get('result', []))
                if isinstance(rows, list) and len(rows) > 0:
                    r = rows[0]
                    cnt = r.get('cnt', r) if isinstance(r, dict) else r
                    print(f"  {table:40s} {cnt} lignes")
                else:
                    print(f"  {table:40s} RAW: {data}")
            else:
                print(f"  {table:40s} RAW: {data}")
        except Exception as e:
            print(f"  {table:40s} ERREUR: {e}")

    # Sample free_videos to see actual data
    print("\n" + "=" * 80)
    print("AUDIT SUPABASE — ÉCHANTILLON free_videos (5 dernières)")
    print("=" * 80)
    try:
        sample_sql = "SELECT * FROM app.free_videos ORDER BY created_at DESC LIMIT 5;"
        result = mgr.client.rpc('admin_execute_sql', {'p_sql': sample_sql}).execute()
        data = result.data
        if isinstance(data, dict):
            rows = data.get('rows', data.get('result', []))
            if isinstance(rows, list):
                for i, row in enumerate(rows):
                    print(f"\n  [Row {i}]")
                    if isinstance(row, dict):
                        for k, v in row.items():
                            val_str = str(v)[:100] if v is not None else 'NULL'
                            print(f"    {k:30s} = {val_str}")
                    else:
                        print(f"    {row}")
        else:
            print(f"  RAW: {data}")
    except Exception as e:
        print(f"  ERREUR: {e}")

    # Sample challenge_participations
    print("\n" + "=" * 80)
    print("AUDIT SUPABASE — ÉCHANTILLON challenge_participations (5 dernières)")
    print("=" * 80)
    try:
        sample_sql = "SELECT * FROM app.challenge_participations ORDER BY started_at DESC LIMIT 5;"
        result = mgr.client.rpc('admin_execute_sql', {'p_sql': sample_sql}).execute()
        data = result.data
        if isinstance(data, dict):
            rows = data.get('rows', data.get('result', []))
            if isinstance(rows, list):
                for i, row in enumerate(rows):
                    print(f"\n  [Row {i}]")
                    if isinstance(row, dict):
                        for k, v in row.items():
                            val_str = str(v)[:100] if v is not None else 'NULL'
                            print(f"    {k:30s} = {val_str}")
                    else:
                        print(f"    {row}")
        else:
            print(f"  RAW: {data}")
    except Exception as e:
        print(f"  ERREUR: {e}")

if __name__ == '__main__':
    main()
