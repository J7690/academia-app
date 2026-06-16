#!/usr/bin/env python3
"""Vérification des tables prep_assignments, prep_assignment_submissions, prep_live_sessions, prep_live_participants"""
import requests
import json

def main():
    m_url = 'https://thevdfcwlcqzdoybfvgs.supabase.co'
    m_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
    
    headers = {
        'apikey': m_key,
        'Authorization': f'Bearer {m_key}',
        'Content-Type': 'application/json'
    }
    
    print("\n" + "="*60)
    print("  VÉRIFICATION TABLES PREP")
    print("="*60 + "\n")
    
    target_tables = [
        'prep_assignments',
        'prep_assignment_submissions',
        'prep_live_sessions',
        'prep_live_participants',
    ]
    
    # Vérifier chaque table via information_schema
    for table in target_tables:
        sql = f"""
        SELECT table_name, column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = '{table}'
        ORDER BY ordinal_position
        """
        
        try:
            resp = requests.post(
                f"{m_url}/rest/v1/rpc/admin_execute_sql",
                headers=headers,
                json={"p_sql": sql},
                timeout=10
            )
            
            if resp.status_code == 200:
                data = resp.json()
                if data.get('ok') and data.get('rows'):
                    rows = data['rows']
                    print(f"✅ {table}")
                    print(f"   Colonnes: {len(rows)}")
                    for col in rows[:5]:  # Afficher les 5 premières colonnes
                        print(f"   - {col['column_name']}: {col['data_type']}")
                    if len(rows) > 5:
                        print(f"   ... et {len(rows) - 5} autres colonnes")
                    
                    # Vérifier RLS
                    rls_sql = f"""
                    SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
                    FROM pg_policies
                    WHERE schemaname = 'app' AND tablename = '{table}'
                    """
                    rls_resp = requests.post(
                        f"{m_url}/rest/v1/rpc/admin_execute_sql",
                        headers=headers,
                        json={"p_sql": rls_sql},
                        timeout=10
                    )
                    if rls_resp.status_code == 200:
                        rls_data = rls_resp.json()
                        if rls_data.get('ok') and rls_data.get('rows'):
                            print(f"   RLS: {len(rls_data['rows'])} politiques")
                        else:
                            print(f"   RLS: Aucune politique")
                else:
                    print(f"❌ {table} — NON TROUVÉE")
            else:
                print(f"⚠️  {table} — Erreur HTTP: {resp.status_code}")
        except Exception as e:
            print(f"❌ {table} — Exception: {str(e)[:50]}")
    
    print("\n✅ Vérification terminée.\n")

if __name__ == "__main__":
    main()
