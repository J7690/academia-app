import requests
import json

url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

print("=" * 80)
print("AUDIT STORAGE - PHASE D.4A")
print("=" * 80)

results = {}

# 1. Vérifier bucket whiteboard-renders
print("\n1. Vérification bucket whiteboard-renders...")
bucket_url = f"{url}/storage/v1/bucket/whiteboard-renders"
resp = requests.get(bucket_url, headers=headers, timeout=30)
print(f"STATUS: {resp.status_code}")

if resp.status_code == 200:
    data = resp.json()
    results['whiteboard_renders'] = {'exists': True, 'details': data}
    print(f"  ✅ Bucket whiteboard-renders existe")
    print(f"    - ID: {data.get('id')}")
    print(f"    - Name: {data.get('name')}")
    print(f"    - Public: {data.get('public')}")
    print(f"    - File size limit: {data.get('file_size_limit')}")
    print(f"    - Allowed mime types: {data.get('allowed_mime_types')}")
elif resp.status_code == 404:
    results['whiteboard_renders'] = {'exists': False}
    print("  ❌ Bucket whiteboard-renders n'existe pas")
else:
    results['whiteboard_renders'] = {'exists': False, 'error': resp.text}
    print(f"  ❌ Error: {resp.text}")

# 2. Vérifier bucket whiteboard-narrations
print("\n2. Vérification bucket whiteboard-narrations...")
bucket_url = f"{url}/storage/v1/bucket/whiteboard-narrations"
resp = requests.get(bucket_url, headers=headers, timeout=30)
print(f"STATUS: {resp.status_code}")

if resp.status_code == 200:
    data = resp.json()
    results['whiteboard_narrations'] = {'exists': True, 'details': data}
    print(f"  ✅ Bucket whiteboard-narrations existe")
    print(f"    - ID: {data.get('id')}")
    print(f"    - Name: {data.get('name')}")
    print(f"    - Public: {data.get('public')}")
    print(f"    - File size limit: {data.get('file_size_limit')}")
    print(f"    - Allowed mime types: {data.get('allowed_mime_types')}")
elif resp.status_code == 404:
    results['whiteboard_narrations'] = {'exists': False}
    print("  ❌ Bucket whiteboard-narrations n'existe pas")
else:
    results['whiteboard_narrations'] = {'exists': False, 'error': resp.text}
    print(f"  ❌ Error: {resp.text}")

# 3. Lister les fichiers dans whiteboard-renders
if results.get('whiteboard_renders', {}).get('exists'):
    print("\n3. Liste des fichiers dans whiteboard-renders...")
    list_url = f"{url}/storage/v1/object/whiteboard-renders?limit=100"
    resp = requests.get(list_url, headers=headers, timeout=30)
    print(f"STATUS: {resp.status_code}")
    
    if resp.status_code == 200:
        data = resp.json()
        files = data if isinstance(data, list) else []
        results['whiteboard_renders']['files'] = files
        print(f"  Nombre de fichiers: {len(files)}")
        
        total_size = 0
        for file in files:
            size = file.get('metadata', {}).get('size', 0)
            total_size += size
            print(f"    - {file.get('name')}: {size} bytes, Created: {file.get('created_at')}")
        
        results['whiteboard_renders']['total_size'] = total_size
        print(f"  Taille totale: {total_size} bytes ({total_size / 1024 / 1024:.2f} MB)")
    else:
        print(f"  ❌ Error: {resp.text}")

# 4. Lister les fichiers dans whiteboard-narrations
if results.get('whiteboard_narrations', {}).get('exists'):
    print("\n4. Liste des fichiers dans whiteboard-narrations...")
    list_url = f"{url}/storage/v1/object/whiteboard-narrations?limit=100"
    resp = requests.get(list_url, headers=headers, timeout=30)
    print(f"STATUS: {resp.status_code}")
    
    if resp.status_code == 200:
        data = resp.json()
        files = data if isinstance(data, list) else []
        results['whiteboard_narrations']['files'] = files
        print(f"  Nombre de fichiers: {len(files)}")
        
        total_size = 0
        for file in files:
            size = file.get('metadata', {}).get('size', 0)
            total_size += size
            print(f"    - {file.get('name')}: {size} bytes, Created: {file.get('created_at')}")
        
        results['whiteboard_narrations']['total_size'] = total_size
        print(f"  Taille totale: {total_size} bytes ({total_size / 1024 / 1024:.2f} MB)")
    else:
        print(f"  ❌ Error: {resp.text}")

# Sauvegarder les résultats
with open('audit_storage_d4a_results.json', 'w') as f:
    json.dump(results, f, indent=2)

print("\n" + "=" * 80)
print("RÉSULTATS SAUVEGARDÉS DANS audit_storage_d4a_results.json")
print("=" * 80)
