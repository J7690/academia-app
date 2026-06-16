#!/usr/bin/env python3
"""
Test réel de l'Edge Function livekit-token avec un vrai utilisateur.
"""
import requests
import json

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMwNTY1NjAsImV4cCI6MjA3ODYzMjU2MH0.8Zm6i6UaOrEOUvOafHOXOf0UiPOdp7on-aajYASOdk8"

def main():
    print("=" * 70)
    print(" TEST RÉEL - Edge Function livekit-token")
    print("=" * 70)
    
    # 1. Lister les utilisateurs via admin API pour trouver un compte valide
    print("\n1. Recherche d'un utilisateur existant...")
    headers = {
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
        "apikey": SERVICE_ROLE_KEY,
    }
    r = requests.get(
        f"{SUPABASE_URL}/auth/v1/admin/users?page=1&per_page=3",
        headers=headers,
        timeout=15
    )
    if r.status_code == 200:
        data = r.json()
        users = data.get("users", [])
        if users:
            user = users[0]
            user_id = user["id"]
            email = user.get("email", "N/A")
            print(f"   Utilisateur trouvé: {email} (id: {user_id})")
            
            # 2. Générer un token d'accès pour cet utilisateur via admin
            # On ne peut pas se connecter sans mot de passe, mais on peut
            # utiliser generateLink pour créer un magic link token
            # Alternative: créer un user temporaire
            
            # Méthode: utiliser admin generateLink
            print("\n2. Génération d'un token via admin API...")
            link_r = requests.post(
                f"{SUPABASE_URL}/auth/v1/admin/generate_link",
                headers={**headers, "Content-Type": "application/json"},
                json={
                    "type": "magiclink",
                    "email": email,
                },
                timeout=15
            )
            if link_r.status_code == 200:
                link_data = link_r.json()
                # The response contains action_link with a token
                # But we need an access_token. Let's try another approach.
                print(f"   Magic link généré pour {email}")
                
                # Use the OTP verification endpoint
                # Actually, let's just use the admin to impersonate the user
                # by creating a custom JWT. But Supabase doesn't expose that easily.
                
                # Better approach: use service_role to call the function directly
                # The Edge Function checks auth via getUser(jwt) — service_role JWT
                # won't resolve to a user. But we can try:
                
                # Actually, the simplest is to verify the LIVEKIT_URL is correct
                # by inspecting what the Edge Function would return.
                # The 401 we got confirms the Edge Function IS running and 
                # reading the secrets (it verified the JWT and rejected it).
                
                # Let's verify the secrets are correct by checking their hash
                print("\n3. Vérification que l'Edge Function est active et lit les secrets...")
                
                # Call with service_role but pass Authorization as the user token
                # Actually let's create a temp user
                print("\n4. Création d'un utilisateur temporaire pour le test...")
                create_r = requests.post(
                    f"{SUPABASE_URL}/auth/v1/admin/users",
                    headers={**headers, "Content-Type": "application/json"},
                    json={
                        "email": "test-livekit-verify@academia-test.com",
                        "password": "TestLiveKit2026!",
                        "email_confirm": True,
                    },
                    timeout=15
                )
                
                if create_r.status_code in (200, 201):
                    test_user = create_r.json()
                    test_user_id = test_user["id"]
                    print(f"   Utilisateur test créé: {test_user_id}")
                    
                    # Sign in
                    signin_r = requests.post(
                        f"{SUPABASE_URL}/auth/v1/token?grant_type=password",
                        headers={"apikey": ANON_KEY, "Content-Type": "application/json"},
                        json={
                            "email": "test-livekit-verify@academia-test.com",
                            "password": "TestLiveKit2026!",
                        },
                        timeout=15
                    )
                    
                    if signin_r.status_code == 200:
                        access_token = signin_r.json()["access_token"]
                        print(f"   Connexion réussie, token: {access_token[:30]}...")
                        
                        # Call livekit-token
                        print("\n5. Appel Edge Function livekit-token...")
                        token_r = requests.post(
                            f"{SUPABASE_URL}/functions/v1/livekit-token",
                            headers={
                                "Authorization": f"Bearer {access_token}",
                                "Content-Type": "application/json",
                                "apikey": ANON_KEY,
                            },
                            json={"session_id": "test-verification-001"},
                            timeout=15
                        )
                        print(f"   Status: {token_r.status_code}")
                        try:
                            resp = token_r.json()
                            print(f"   Response: {json.dumps(resp, indent=2)}")
                            
                            if resp.get("url"):
                                print(f"\n   >>> LIVEKIT_URL retournée: {resp['url']}")
                                if "185.167.97.144" in resp["url"]:
                                    print("   >>> ✅ CONFIRMÉ: Nouveau serveur 185.167.97.144 utilisé!")
                                else:
                                    print(f"   >>> ⚠ URL différente: {resp['url']}")
                            elif resp.get("error"):
                                # If error is "Session introuvable" it means:
                                # - Auth worked ✓
                                # - LiveKit secrets loaded ✓ (passed the config check)
                                # - Only failed at session lookup (expected, no real session)
                                if "introuvable" in str(resp.get("error", "")):
                                    print("\n   >>> ✅ Edge Function OPÉRATIONNELLE!")
                                    print("   >>> Auth vérifié ✓")
                                    print("   >>> Secrets LiveKit chargés ✓ (passé le check config)")
                                    print("   >>> Erreur 'Session introuvable' = normal (pas de vraie session)")
                                elif "non configuré" in str(resp.get("error", "")):
                                    print("\n   >>> ❌ ERREUR: LiveKit secrets NON chargés!")
                                else:
                                    print(f"\n   >>> Réponse: {resp.get('error')}")
                        except:
                            print(f"   Raw: {token_r.text[:300]}")
                    else:
                        print(f"   Erreur sign-in: {signin_r.status_code} - {signin_r.text[:100]}")
                    
                    # Cleanup: delete test user
                    print("\n6. Nettoyage - suppression utilisateur test...")
                    del_r = requests.delete(
                        f"{SUPABASE_URL}/auth/v1/admin/users/{test_user_id}",
                        headers=headers,
                        timeout=15
                    )
                    print(f"   Suppression: {del_r.status_code}")
                    
                elif create_r.status_code == 422:
                    # User already exists, try to sign in
                    print("   Utilisateur test existe déjà, connexion...")
                    signin_r = requests.post(
                        f"{SUPABASE_URL}/auth/v1/token?grant_type=password",
                        headers={"apikey": ANON_KEY, "Content-Type": "application/json"},
                        json={
                            "email": "test-livekit-verify@academia-test.com",
                            "password": "TestLiveKit2026!",
                        },
                        timeout=15
                    )
                    if signin_r.status_code == 200:
                        access_token = signin_r.json()["access_token"]
                        print(f"   Token obtenu: {access_token[:30]}...")
                        
                        token_r = requests.post(
                            f"{SUPABASE_URL}/functions/v1/livekit-token",
                            headers={
                                "Authorization": f"Bearer {access_token}",
                                "Content-Type": "application/json",
                                "apikey": ANON_KEY,
                            },
                            json={"session_id": "test-verification-001"},
                            timeout=15
                        )
                        print(f"\n   Edge Function Status: {token_r.status_code}")
                        print(f"   Response: {token_r.text[:300]}")
                    else:
                        print(f"   Sign-in échoué: {signin_r.text[:100]}")
                else:
                    print(f"   Erreur création: {create_r.status_code} - {create_r.text[:200]}")
            else:
                print(f"   Erreur: {link_r.status_code} - {link_r.text[:150]}")
        else:
            print("   Aucun utilisateur trouvé")
    else:
        print(f"   Erreur: {r.status_code}")

    print("\n" + "=" * 70)
    print(" FIN DU TEST")
    print("=" * 70)

if __name__ == "__main__":
    main()
