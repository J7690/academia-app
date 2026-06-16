#!/usr/bin/env python3
"""Test Bobodo sur les cas réels étudiants"""

import requests
from pathlib import Path

# Charger la clé API depuis le fichier .env
root = Path(__file__).resolve().parents[1]
env_path = root / "academia_bobodo_backend" / ".env"

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = None

if env_path.exists():
    try:
        content = env_path.read_text(encoding="utf-8")
        for line in content.splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            
            if key == "SUPABASE_SERVICE_KEY":
                SERVICE_KEY = value
                break
    except Exception as e:
        print(f"Erreur lecture fichier .env: {e}")

if not SERVICE_KEY:
    print("❌ SUPABASE_SERVICE_KEY non trouvée")
    exit(1)

print("=" * 80)
print("TEST BOBODO - CAS RÉELS ÉTUDIANTS")
print("=" * 80)

# Questions réelles des étudiants
test_questions = [
    "Comment postuler ?",
    "Quels documents fournir ?",
    "Comment suivre ma candidature ?",
    "Je n'arrive pas à payer.",
    "Je veux acheter des crédits IA.",
    "Que signifie under_review ?",
    "Mon dossier est bloqué.",
]

headers = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
    "Accept": "application/json"
}

print(f"\n{len(test_questions)} questions à tester")

for i, question in enumerate(test_questions, 1):
    print(f"\n{'='*80}")
    print(f"Question {i}/{len(test_questions)}: \"{question}\"")
    print('='*80)
    
    payload = {
        "message": question,
        "session_id": f"test_session_{i}"
    }
    
    try:
        response = requests.post(
            f"{SUPABASE_URL}/functions/v1/bobodo-chat",
            headers=headers,
            json=payload,
            timeout=30
        )
        
        print(f"HTTP Status: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            answer = data.get('answer', 'N/A')
            
            print(f"\n✅ Réponse Bobodo:")
            print(f"   {answer[:300]}...")
            
            # Analyser la réponse
            answer_lower = answer.lower()
            
            # Indicateurs de qualité
            indicators = {
                "Utilise RAG (connaissances)": any(word in answer_lower for word in ['candidature', 'postuler', 'document', 'paiement', 'crédit', 'suivi']),
                "Guidage utilisateur": any(word in answer_lower for word in ['tu peux', 'voici', 'pour', 'comment', 'étape', 'clique']),
                "Compréhension contextuelle": len(answer) > 100,
            }
            
            print(f"\nIndicateurs de qualité:")
            for indicator, value in indicators.items():
                status = "✅" if value else "❌"
                print(f"  {status} {indicator}")
                
        else:
            print(f"❌ Erreur: {response.text[:200]}")
            
    except Exception as e:
        print(f"❌ Erreur: {e}")

print("\n" + "=" * 80)
print("CONCLUSION")
print("=" * 80)
print("Les tests ci-dessus utilisent l'Edge Function bobodo-chat en production.")
print("Cela permet de tester le RAG réel avec la recherche vectorielle pgvector.")
