import requests
import json
import time
from datetime import datetime

# Configuration
SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
EDGE_FUNCTION_URL = f"{SUPABASE_URL}/functions/v1/whiteboard-generate-storyboard"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

# 20 sujets de test (8 matières)
TEST_SUBJECTS = [
    # Mathématiques (5)
    {"subject": "Dérivée d'une fonction", "mode": "simple_subject", "content": ""},
    {"subject": "Intégrale définie", "mode": "simple_subject", "content": ""},
    {"subject": "Équations du second degré", "mode": "simple_subject", "content": ""},
    {"subject": "Fonctions exponentielles", "mode": "simple_subject", "content": ""},
    {"subject": "Théorème de Pythagore", "mode": "simple_subject", "content": ""},
    
    # Physique (3)
    {"subject": "Loi d'Ohm", "mode": "simple_subject", "content": ""},
    {"subject": "Énergie cinétique", "mode": "simple_subject", "content": ""},
    {"subject": "Gravitation universelle", "mode": "simple_subject", "content": ""},
    
    # Chimie (2)
    {"subject": "Tableau périodique", "mode": "simple_subject", "content": ""},
    {"subject": "Réaction chimique", "mode": "simple_subject", "content": ""},
    
    # Biologie (2)
    {"subject": "La cellule", "mode": "simple_subject", "content": ""},
    {"subject": "Photosynthèse", "mode": "simple_subject", "content": ""},
    
    # Histoire (2)
    {"subject": "Révolution française", "mode": "simple_subject", "content": ""},
    {"subject": "Empire romain", "mode": "simple_subject", "content": ""},
    
    # Géographie (2)
    {"subject": "Les climats", "mode": "simple_subject", "content": ""},
    {"subject": "Les océans", "mode": "simple_subject", "content": ""},
    
    # Langues (2)
    {"subject": "Grammaire française", "mode": "simple_subject", "content": ""},
    {"subject": "Vocabulaire anglais", "mode": "simple_subject", "content": ""},
    
    # Informatique (2)
    {"subject": "Algorithmes de tri", "mode": "simple_subject", "content": ""},
    {"subject": "Bases de données relationnelles", "mode": "simple_subject", "content": ""},
]

def get_test_user_jwt():
    """Obtient un JWT utilisateur de test"""
    # Essayer de se connecter avec un utilisateur de test
    auth_url = f"{SUPABASE_URL}/auth/v1/token?grant_type=password"
    headers = {
        "apikey": SERVICE_ROLE_KEY,
        "Content-Type": "application/json",
    }
    body = {
        "email": "test@academia.bf",
        "password": "Test123456!",
    }
    
    try:
        response = requests.post(auth_url, headers=headers, json=body, timeout=10)
        if response.status_code == 200:
            data = response.json()
            return data.get('access_token')
        else:
            print(f"Erreur auth: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        print(f"Erreur auth: {e}")
        return None

def generate_storyboard(jwt, subject, mode, content, renderer="scientific", theme="scientific", narration_mode="none"):
    """Génère un Storyboard via l'Edge Function"""
    headers = {
        "Authorization": f"Bearer {jwt}",
        "Content-Type": "application/json",
    }
    
    body = {
        "mode": mode,
        "subject": subject,
        "content": content,
        "renderer": renderer,
        "theme": theme,
        "narration_mode": narration_mode,
    }
    
    start_time = time.time()
    
    try:
        response = requests.post(EDGE_FUNCTION_URL, headers=headers, json=body, timeout=30)
        elapsed_time = time.time() - start_time
        
        if response.status_code == 200:
            data = response.json()
            storyboard_json = data.get('storyboard_json', {})
            
            # Calculer les métriques
            json_size = len(json.dumps(storyboard_json))
            num_scenes = len(storyboard_json.get('scenes', []))
            num_blocks = sum(len(scene.get('blocks', [])) for scene in storyboard_json.get('scenes', []))
            
            return {
                "success": True,
                "subject": subject,
                "mode": mode,
                "elapsed_time": elapsed_time,
                "json_size": json_size,
                "num_scenes": num_scenes,
                "num_blocks": num_blocks,
                "model": data.get('model'),
                "tokens_input": data.get('tokens_input'),
                "tokens_output": data.get('tokens_output'),
                "cost_usd": data.get('cost_usd'),
                "credits_used": data.get('credits_used'),
                "error": None,
            }
        else:
            return {
                "success": False,
                "subject": subject,
                "mode": mode,
                "elapsed_time": elapsed_time,
                "json_size": 0,
                "num_scenes": 0,
                "num_blocks": 0,
                "model": None,
                "tokens_input": 0,
                "tokens_output": 0,
                "cost_usd": 0,
                "credits_used": 0,
                "error": response.text,
            }
    except Exception as e:
        elapsed_time = time.time() - start_time
        return {
            "success": False,
            "subject": subject,
            "mode": mode,
            "elapsed_time": elapsed_time,
            "json_size": 0,
            "num_scenes": 0,
            "num_blocks": 0,
            "model": None,
            "tokens_input": 0,
            "tokens_output": 0,
            "cost_usd": 0,
            "credits_used": 0,
            "error": str(e),
        }

def main():
    print("=" * 80)
    print("GÉNÉRATION DE 20 STORYBOARDS RÉELS VIA OPENROUTER")
    print("=" * 80)
    
    # Obtenir JWT utilisateur
    print("\nObtention JWT utilisateur de test...")
    jwt = get_test_user_jwt()
    if not jwt:
        print("❌ Impossible d'obtenir un JWT utilisateur")
        print("   Veuillez créer un utilisateur de test: test@academia.bf / Test123456!")
        return
    
    print("✅ JWT obtenu")
    
    results = []
    success_count = 0
    failure_count = 0
    
    for i, test in enumerate(TEST_SUBJECTS, 1):
        print(f"\n[{i}/20] Génération : {test['subject']} ({test['mode']})")
        result = generate_storyboard(
            jwt=jwt,
            subject=test['subject'],
            mode=test['mode'],
            content=test['content'],
        )
        results.append(result)
        
        if result['success']:
            success_count += 1
            print(f"  ✅ SUCCÈS")
            print(f"     Temps: {result['elapsed_time']:.2f}s")
            print(f"     Taille: {result['json_size']} octets")
            print(f"     Scènes: {result['num_scenes']}")
            print(f"     Blocs: {result['num_blocks']}")
            print(f"     Modèle: {result['model']}")
            print(f"     Tokens: {result['tokens_input']} + {result['tokens_output']}")
            print(f"     Coût: ${result['cost_usd']:.6f}")
        else:
            failure_count += 1
            print(f"  ❌ ÉCHEC")
            print(f"     Erreur: {result['error'][:200]}")
    
    # Résumé
    print("\n" + "=" * 80)
    print("RÉSUMÉ")
    print("=" * 80)
    print(f"Total: {len(results)}")
    print(f"Succès: {success_count}")
    print(f"Échec: {failure_count}")
    print(f"Taux de succès: {(success_count / len(results) * 100):.1f}%")
    
    if success_count > 0:
        avg_time = sum(r['elapsed_time'] for r in results if r['success']) / success_count
        avg_size = sum(r['json_size'] for r in results if r['success']) / success_count
        avg_scenes = sum(r['num_scenes'] for r in results if r['success']) / success_count
        avg_blocks = sum(r['num_blocks'] for r in results if r['success']) / success_count
        total_cost = sum(r['cost_usd'] for r in results if r['success'])
        total_tokens_in = sum(r['tokens_input'] for r in results if r['success'])
        total_tokens_out = sum(r['tokens_output'] for r in results if r['success'])
        
        print(f"\nMoyennes (succès uniquement):")
        print(f"  Temps: {avg_time:.2f}s")
        print(f"  Taille: {avg_size:.0f} octets")
        print(f"  Scènes: {avg_scenes:.1f}")
        print(f"  Blocs: {avg_blocks:.1f}")
        print(f"\nTotaux:")
        print(f"  Coût total: ${total_cost:.6f}")
        print(f"  Tokens input: {total_tokens_in}")
        print(f"  Tokens output: {total_tokens_out}")
    
    # Sauvegarder les résultats
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"whiteboard_generation_results_{timestamp}.json"
    with open(filename, 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"\nRésultats sauvegardés dans: {filename}")

if __name__ == "__main__":
    main()
