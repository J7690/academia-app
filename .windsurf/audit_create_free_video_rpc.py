#!/usr/bin/env python3
"""Audit de la RPC app_student_create_free_video et du flux Flutter qui l'appelle."""

import requests
import json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}

def q(sql):
    r = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=HEADERS, json={"sql_query": sql}, timeout=30)
    if r.status_code == 200:
        return r.json()
    return f"ERR {r.status_code}: {r.text[:500]}"

def show(label, rows):
    print(f"\n{'='*70}")
    print(f"  {label}")
    print(f"{'='*70}")
    if isinstance(rows, list):
        if not rows:
            print("  (aucune ligne)")
        for r in rows:
            print(f"  {json.dumps(r, indent=2, ensure_ascii=False, default=str)[:500]}")
    elif isinstance(rows, dict):
        print(f"  {json.dumps(rows, indent=2, ensure_ascii=False, default=str)[:1000]}")
    else:
        print(f"  {rows}")

# 1) Code source de la RPC app_student_create_free_video
show("1. CODE SOURCE: app_student_create_free_video", q("""
    SELECT routine_name, routine_definition
    FROM information_schema.routines
    WHERE routine_name = 'app_student_create_free_video'
      AND routine_schema = 'public'
"""))

# 2) Code source de la RPC app_student_upload_free_video (si elle existe)
show("2. CODE SOURCE: app_student_upload_free_video", q("""
    SELECT routine_name, routine_definition
    FROM information_schema.routines
    WHERE routine_name = 'app_student_upload_free_video'
      AND routine_schema = 'public'
"""))

# 3) Code source de la RPC set_free_video_main_renditions
show("3. CODE SOURCE: app_student_set_free_video_main_renditions", q("""
    SELECT routine_name, routine_definition
    FROM information_schema.routines
    WHERE routine_name = 'app_student_set_free_video_main_renditions'
      AND routine_schema = 'public'
"""))

# 4) Toutes les RPCs contenant 'free_video' dans le nom
show("4. TOUTES LES RPCs contenant 'free_video'", q("""
    SELECT routine_name
    FROM information_schema.routines
    WHERE routine_name LIKE '%free_video%'
      AND routine_schema = 'public'
    ORDER BY routine_name
"""))

# 5) Code source de fetchPlaybackForDirectUrl (si elle existe)
show("5. RPCs contenant 'playback' ou 'manifest'", q("""
    SELECT routine_name
    FROM information_schema.routines
    WHERE (routine_name LIKE '%playback%' OR routine_name LIKE '%manifest%' OR routine_name LIKE '%resolve%')
      AND routine_schema = 'public'
    ORDER BY routine_name
"""))

# 6) Paramètres de app_student_create_free_video
show("6. PARAMETRES: app_student_create_free_video", q("""
    SELECT parameter_name, data_type, parameter_mode, ordinal_position
    FROM information_schema.parameters
    WHERE specific_name LIKE 'app_student_create_free_video%'
      AND specific_schema = 'public'
    ORDER BY ordinal_position
"""))

# 7) Code source complet via pg_proc
show("7. CODE SOURCE COMPLET (pg_proc): app_student_create_free_video", q("""
    SELECT p.prosrc
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = 'app_student_create_free_video'
      AND n.nspname = 'public'
"""))

# 8) Code source complet: app_student_set_free_video_main_renditions
show("8. CODE SOURCE COMPLET (pg_proc): app_student_set_free_video_main_renditions", q("""
    SELECT p.prosrc
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = 'app_student_set_free_video_main_renditions'
      AND n.nspname = 'public'
"""))
