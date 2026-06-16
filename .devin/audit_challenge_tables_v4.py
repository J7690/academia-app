#!/usr/bin/env python3
"""Audit Supabase via admin_execute_sql — sans point-virgule."""

import requests
import json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {
    "apikey": KEY,
    "Authorization": f"Bearer {KEY}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}

def run_sql(sql):
    sql = sql.rstrip().rstrip(';')
    resp = requests.post(
        f"{URL}/rest/v1/rpc/admin_execute_sql",
        headers=HEADERS,
        json={"p_sql": sql},
        timeout=30,
    )
    if resp.status_code != 200:
        return None, f"HTTP {resp.status_code}: {resp.text[:300]}"
    data = resp.json()
    if isinstance(data, dict) and data.get('ok') == False:
        return None, data.get('error', 'unknown')
    return data, None

def extract_rows(data):
    if isinstance(data, dict):
        return data.get('rows', data.get('result', []))
    if isinstance(data, list):
        return data
    return []

def main():
    tables = [
        'app.free_videos',
        'app.challenge_participations',
        'app.challenges',
        'app.video_assets',
        'app.video_renditions',
        'app.video_asset_contexts',
    ]

    print("=" * 80)
    print("AUDIT SUPABASE — COLONNES DES TABLES")
    print("=" * 80)

    for table in tables:
        schema, tname = table.split('.')
        sql = f"SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_schema = '{schema}' AND table_name = '{tname}' ORDER BY ordinal_position"
        data, err = run_sql(sql)
        print(f"\n--- {table} ---")
        if err:
            print(f"  ERREUR: {err}")
            continue
        rows = extract_rows(data)
        if not rows:
            print("  TABLE INEXISTANTE ou aucune colonne")
        else:
            for row in rows:
                if isinstance(row, dict):
                    print(f"  {row.get('column_name','?'):35s} {row.get('data_type','?'):25s} null={row.get('is_nullable','?')}")
                elif isinstance(row, (list, tuple)):
                    print(f"  {str(row[0]):35s} {str(row[1]) if len(row)>1 else '?':25s}")
                else:
                    print(f"  {row}")

    print("\n" + "=" * 80)
    print("AUDIT SUPABASE — NOMBRE DE LIGNES")
    print("=" * 80)
    for table in ['app.free_videos', 'app.challenge_participations', 'app.challenges', 'app.video_assets', 'app.video_renditions']:
        data, err = run_sql(f"SELECT COUNT(*) as cnt FROM {table}")
        if err:
            print(f"  {table:40s} ERREUR: {err}")
        else:
            rows = extract_rows(data)
            if rows and isinstance(rows[0], dict):
                print(f"  {table:40s} {rows[0].get('cnt', '?')} lignes")
            elif rows:
                print(f"  {table:40s} {rows[0]}")
            else:
                print(f"  {table:40s} RAW: {str(data)[:200]}")

    print("\n" + "=" * 80)
    print("AUDIT — ÉCHANTILLON free_videos")
    print("=" * 80)
    data, err = run_sql("SELECT * FROM app.free_videos ORDER BY created_at DESC LIMIT 3")
    if err:
        print(f"  ERREUR: {err}")
    else:
        rows = extract_rows(data)
        if not rows:
            print("  Aucune free_video")
        for i, row in enumerate(rows):
            print(f"\n  [Row {i}]")
            if isinstance(row, dict):
                for k, v in sorted(row.items()):
                    print(f"    {k:35s} = {str(v)[:120] if v is not None else 'NULL'}")
            else:
                print(f"    {row}")

    print("\n" + "=" * 80)
    print("AUDIT — ÉCHANTILLON challenge_participations")
    print("=" * 80)
    data, err = run_sql("SELECT * FROM app.challenge_participations ORDER BY started_at DESC LIMIT 3")
    if err:
        print(f"  ERREUR: {err}")
    else:
        rows = extract_rows(data)
        if not rows:
            print("  Aucune participation")
        for i, row in enumerate(rows):
            print(f"\n  [Row {i}]")
            if isinstance(row, dict):
                for k, v in sorted(row.items()):
                    print(f"    {k:35s} = {str(v)[:120] if v is not None else 'NULL'}")
            else:
                print(f"    {row}")

    print("\n" + "=" * 80)
    print("AUDIT — RPCs CHALLENGE/VIDEO")
    print("=" * 80)
    sql = """SELECT routine_schema, routine_name FROM information_schema.routines
    WHERE routine_type = 'FUNCTION' AND (
        routine_name LIKE '%challenge%' OR routine_name LIKE '%free_video%'
        OR routine_name LIKE '%video_feed%' OR routine_name LIKE '%videoasset%'
    ) ORDER BY routine_schema, routine_name"""
    data, err = run_sql(sql)
    if err:
        print(f"  ERREUR: {err}")
    else:
        rows = extract_rows(data)
        for row in rows:
            if isinstance(row, dict):
                print(f"  {row.get('routine_schema','?'):10s} {row.get('routine_name','?')}")
            elif isinstance(row, (list, tuple)):
                print(f"  {str(row[0]):10s} {str(row[1]) if len(row)>1 else '?'}")
            else:
                print(f"  {row}")

if __name__ == '__main__':
    main()
