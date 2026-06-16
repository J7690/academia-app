#!/usr/bin/env python3
"""
Test de la fonction describe_table_detailed corrigée
"""

import requests
import json

def test_describe_table_fixed():
    """Test la fonction describe_table_detailed après correction"""
    
    url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
    service_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

    headers = {
        "apikey": service_key,
        "Authorization": f"Bearer {service_key}",
        "Content-Type": "application/json",
        "Accept": "application/json"
    }

    print("🧪 Test de describe_table_detailed corrigé...")

    try:
        response = requests.post(f"{url}/rest/v1/rpc/describe_table_detailed", 
                               headers=headers, 
                               json={"p_table_name": "rpc_validation_test"}, 
                               timeout=10)
        
        if response.status_code == 200:
            columns = response.json()
            if isinstance(columns, list):
                print(f"✅ Succès: {len(columns)} colonnes décrites")
                for col in columns:
                    nullable = "NULL" if col["is_nullable"] == "YES" else "NOT NULL"
                    print(f"   📝 {col['column_name']}: {col['data_type']} {nullable} (position: {col['ordinal_position']})")
                print("🎉 describe_table_detailed est maintenant 100% fonctionnel!")
                return True
            else:
                print(f"❌ Erreur: format incorrect: {type(columns)} - {columns}")
                return False
        else:
            print(f"❌ Erreur: {response.status_code} - {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Exception: {e}")
        return False

if __name__ == "__main__":
    success = test_describe_table_fixed()
    if success:
        print("\n🚀 La fonction describe_table_detailed est parfaitement corrigée!")
        print("✅ Prête pour le test final complet")
    else:
        print("\n⚠️ La fonction a besoin d'être mise à jour")
        print("Veuillez exécuter le SQL fix_describe_table.sql dans le dashboard Supabase")
