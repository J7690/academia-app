"""
Audit du système de référenciation via API REST Supabase directe
"""

import requests
import json

# Configuration API REST
base_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
}

print("=== AUDIT SYSTÈME RÉFÉRENCIATION (API REST) ===\n")

# Test 1: Essayer de lire commission_rules
print("Test 1: GET /rest/v1/commission_rules")
try:
    resp = requests.get(f"{base_url}/commission_rules", headers=headers, timeout=30)
    print(f"Status: {resp.status_code}")
    if resp.status_code == 200:
        data = resp.json()
        print(f"✅ Table accessible - {len(data)} enregistrements")
        if len(data) > 0:
            print(f"   Premier enregistrement: {json.dumps(data[0], default=str)}")
    elif resp.status_code == 404:
        print("❌ Table non trouvée (404)")
    else:
        print(f"❌ Erreur: {resp.text}")
except Exception as e:
    print(f"❌ Exception: {e}")
print()

# Test 2: Essayer de lire referral_commissions
print("Test 2: GET /rest/v1/referral_commissions")
try:
    resp = requests.get(f"{base_url}/referral_commissions", headers=headers, timeout=30)
    print(f"Status: {resp.status_code}")
    if resp.status_code == 200:
        data = resp.json()
        print(f"✅ Table accessible - {len(data)} enregistrements")
        if len(data) > 0:
            print(f"   Premier enregistrement: {json.dumps(data[0], default=str)}")
    elif resp.status_code == 404:
        print("❌ Table non trouvée (404)")
    else:
        print(f"❌ Erreur: {resp.text}")
except Exception as e:
    print(f"❌ Exception: {e}")
print()

# Test 3: Essayer de lire commercial_profiles
print("Test 3: GET /rest/v1/commercial_profiles")
try:
    resp = requests.get(f"{base_url}/commercial_profiles", headers=headers, timeout=30)
    print(f"Status: {resp.status_code}")
    if resp.status_code == 200:
        data = resp.json()
        print(f"✅ Table accessible - {len(data)} enregistrements")
        if len(data) > 0:
            print(f"   Premier enregistrement: {json.dumps(data[0], default=str)}")
    elif resp.status_code == 404:
        print("❌ Table non trouvée (404)")
    else:
        print(f"❌ Erreur: {resp.text}")
except Exception as e:
    print(f"❌ Exception: {e}")
print()

# Test 4: Essayer de lire students avec filtre sur referred_by
print("Test 4: GET /rest/v1/students?select=referred_by")
try:
    resp = requests.get(f"{base_url}/students?select=referred_by", headers=headers, timeout=30)
    print(f"Status: {resp.status_code}")
    if resp.status_code == 200:
        data = resp.json()
        print(f"✅ Table accessible - {len(data)} enregistrements")
        if len(data) > 0:
            print(f"   Premier enregistrement: {json.dumps(data[0], default=str)}")
            # Vérifier si referred_by existe
            if 'referred_by' in data[0]:
                print(f"   ✅ Colonne referred_by existe")
            else:
                print(f"   ❌ Colonne referred_by n'existe pas")
    elif resp.status_code == 404:
        print("❌ Table non trouvée (404)")
    else:
        print(f"❌ Erreur: {resp.text}")
except Exception as e:
    print(f"❌ Exception: {e}")
print()

# Test 5: Essayer de lire students avec select=*
print("Test 5: GET /rest/v1/students?select=*&limit=1")
try:
    resp = requests.get(f"{base_url}/students?select=*&limit=1", headers=headers, timeout=30)
    print(f"Status: {resp.status_code}")
    if resp.status_code == 200:
        data = resp.json()
        print(f"✅ Table accessible")
        if len(data) > 0:
            print(f"   Colonnes disponibles: {', '.join(data[0].keys())}")
            # Chercher des colonnes liées aux références
            ref_cols = [col for col in data[0].keys() if 'ref' in col.lower() or 'commercial' in col.lower()]
            if ref_cols:
                print(f"   ⚠️  Colonnes liées aux références: {', '.join(ref_cols)}")
            else:
                print(f"   ✅ Aucune colonne de référenciation trouvée")
    elif resp.status_code == 404:
        print("❌ Table non trouvée (404)")
    else:
        print(f"❌ Erreur: {resp.text}")
except Exception as e:
    print(f"❌ Exception: {e}")
print()

print("=== AUDIT TERMINÉ ===")
