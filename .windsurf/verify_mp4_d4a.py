import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/whiteboard-renders/renders/5ab36d99-05df-40d6-8a7b-dfe6dc89de6c/b0ce9580019344abb951137c29040ca8f.mp4"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
}

print("=" * 80)
print("VÉRIFICATION MP4 URL PHASE C.3J")
print("=" * 80)

print(f"\nURL: {url}")

resp = requests.head(url, headers=headers, timeout=30)
print(f"\nHEAD STATUS: {resp.status_code}")

if resp.status_code == 200:
    print("✅ Fichier existe")
    print(f"Content-Type: {resp.headers.get('Content-Type')}")
    print(f"Content-Length: {resp.headers.get('Content-Length')} bytes")
    print(f"Last-Modified: {resp.headers.get('Last-Modified')}")
    
    # Essayer de télécharger le fichier pour vérifier
    resp = requests.get(url, headers=headers, timeout=30)
    print(f"\nGET STATUS: {resp.status_code}")
    
    if resp.status_code == 200:
        content = resp.content
        print(f"✅ Fichier téléchargeable")
        print(f"Taille réelle: {len(content)} bytes")
        
        # Vérifier si c'est vraiment un MP4
        if content[:4] == b'\x00\x00\x00\x20' or content[:4] == b'\x00\x00\x00\x18':
            print("✅ Signature MP4 valide")
        else:
            print("⚠️ Signature MP4 invalide")
    else:
        print(f"❌ Erreur téléchargement: {resp.text}")
elif resp.status_code == 404:
    print("❌ Fichier n'existe pas")
else:
    print(f"❌ Erreur: {resp.status_code} - {resp.text}")

print("\n" + "=" * 80)
