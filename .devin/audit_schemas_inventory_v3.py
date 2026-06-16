#!/usr/bin/env python3
"""Inventaire complet des schémas Supabase - version 3 via API REST directe"""
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
    print("  PHASE 1 — INVENTAIRE DES SCHÉMAS")
    print("="*60 + "\n")
    
    # Schémas à vérifier
    schemas = ['public', 'app']
    
    for schema in schemas:
        print(f"\n{'='*60}")
        print(f"  SCHÉMA: {schema}")
        print(f"{'='*60}")
        
        # Lister les tables via API REST
        # Pour le schéma public, on peut utiliser /rest/v1/
        # Pour le schéma app, on peut utiliser /rest/v1/app_*
        
        if schema == 'public':
            # Essayer de lister les tables via un appel générique
            # On utilise information_schema via RPC
            sql = f"""
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = '{schema}' AND table_type = 'BASE TABLE'
            ORDER BY table_name
            """
            
            resp = requests.post(
                f"{m_url}/rest/v1/rpc/admin_execute_sql",
                headers=headers,
                json={"p_sql": sql},
                timeout=30
            )
            
            if resp.status_code == 200:
                try:
                    data = resp.json()
                    if isinstance(data, dict) and data.get('ok'):
                        rows = data.get('rows', [])
                        print(f"  Tables: {len(rows)}")
                        if rows:
                            table_names = [r['table_name'] for r in rows]
                            print(f"  Liste: {', '.join(table_names[:15])}")
                            if len(table_names) > 15:
                                print(f"         ... et {len(table_names) - 15} autres")
                    else:
                        print(f"  Tables: ? (réponse: {data})")
                except:
                    print(f"  Tables: ? (erreur parsing)")
            else:
                print(f"  Tables: ? (HTTP {resp.status_code})")
        
        elif schema == 'app':
            # Pour le schéma app, les tables sont accessibles via /rest/v1/app_*
            # On peut essayer de lister via information_schema
            sql = f"""
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = '{schema}' AND table_type = 'BASE TABLE'
            ORDER BY table_name
            """
            
            resp = requests.post(
                f"{m_url}/rest/v1/rpc/admin_execute_sql",
                headers=headers,
                json={"p_sql": sql},
                timeout=30
            )
            
            if resp.status_code == 200:
                try:
                    data = resp.json()
                    if isinstance(data, dict) and data.get('ok'):
                        rows = data.get('rows', [])
                        print(f"  Tables: {len(rows)}")
                        if rows:
                            table_names = [r['table_name'] for r in rows]
                            print(f"  Liste: {', '.join(table_names[:15])}")
                            if len(table_names) > 15:
                                print(f"         ... et {len(table_names) - 15} autres")
                    else:
                        print(f"  Tables: ? (réponse: {data})")
                except:
                    print(f"  Tables: ? (erreur parsing)")
            else:
                print(f"  Tables: ? (HTTP {resp.status_code})")
    
    print("\n✅ Inventaire des schémas terminé.\n")

if __name__ == "__main__":
    main()
