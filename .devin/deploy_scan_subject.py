#!/usr/bin/env python3
"""Déployer la table de logs de scan et vérifier l'infrastructure."""
from __future__ import annotations
import requests
import time
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    print("\n🚀 DÉPLOIEMENT — Scanner Sujet (table + vérifications)\n")

    components = [
        {
            "name": "Table prep_scan_logs",
            "sql": """
CREATE TABLE IF NOT EXISTS app.prep_scan_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    extracted_text text,
    answers text,
    concours_type text,
    image_size_bytes integer,
    created_at timestamptz DEFAULT now()
)
            """
        },
        {
            "name": "Index prep_scan_logs student",
            "sql": "CREATE INDEX IF NOT EXISTS idx_scan_logs_student ON app.prep_scan_logs(student_id, created_at DESC)"
        },
        {
            "name": "RLS prep_scan_logs",
            "sql": "ALTER TABLE app.prep_scan_logs ENABLE ROW LEVEL SECURITY"
        },
    ]

    for c in components:
        print(f"📦 {c['name']}...")
        try:
            r = requests.post(
                f"{m.url}/rest/v1/rpc/execute_ddl",
                headers=m.headers,
                json={"ddl_query": c['sql']},
                timeout=30
            )
            if r.status_code == 200:
                print(f"   ✅ OK")
            elif 'already exists' in r.text.lower():
                print(f"   ⚠️  Existe déjà")
            else:
                print(f"   ❌ {r.text[:150]}")
        except Exception as e:
            print(f"   ❌ {str(e)[:150]}")
        time.sleep(0.2)

    # Vérifier que le bucket prep-documents existe
    print("\n🔍 Vérification bucket storage...")
    try:
        r = requests.post(
            f"{m.url}/rest/v1/rpc/execute_sql",
            headers=m.headers,
            json={"sql_query": "SELECT id, name FROM storage.buckets WHERE name = 'prep-documents'"},
            timeout=15
        )
        data = r.json() if r.status_code == 200 else []
        if isinstance(data, list) and data:
            print(f"   ✅ Bucket 'prep-documents' existe")
        else:
            print(f"   ⚠️  Bucket 'prep-documents' non trouvé — à créer dans Supabase Dashboard")
    except Exception as e:
        print(f"   ❌ {str(e)[:100]}")

    print("\n✅ Déploiement terminé.\n")

if __name__ == "__main__":
    main()
