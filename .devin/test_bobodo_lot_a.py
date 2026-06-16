#!/usr/bin/env python3
"""Test Bobodo sur les questions du LOT A"""

import requests
import json

# Configuration Supabase
url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
service_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

headers = {
    "apikey": service_key,
    "Authorization": f"Bearer {service_key}",
    "Content-Type": "application/json",
    "Accept": "application/json"
}

print("=" * 80)
print("TEST BOBODO – QUESTIONS LOT A")
print("=" * 80)

# Questions à tester
questions = [
    "Comment postuler ?",
    "Quels documents fournir ?",
    "Comment suivre ma candidature ?",
    "Comment acheter des crédits ?",
    "Mon paiement est en attente.",
    "Que signifie under_review ?"
]

for i, question in enumerate(questions, 1):
    print(f"\n{'=' * 80}")
    print(f"QUESTION {i}/{len(questions)}: {question}")
    print("=" * 80)
    
    # Appeler l'Edge Function bobodo-chat
    try:
        response = requests.post(
            f"{url}/functions/v1/bobodo-chat",
            headers=headers,
            json={"message": question},
            timeout=30
        )
        
        if response.status_code == 200:
            result = response.json()
            answer = result.get('answer', 'Pas de réponse')
            print(f"\nRéponse Bobodo:\n{answer}")
            
            # Vérifier si la réponse utilise les nouvelles connaissances
            keywords = ['candidature', 'document', 'paiement', 'crédit', 'under review', 'suivre']
            found_keywords = [kw for kw in keywords if kw.lower() in answer.lower()]
            
            if found_keywords:
                print(f"\n✅ Mots-clés trouvés: {', '.join(found_keywords)}")
            else:
                print(f"\n⚠️ Aucun mot-clé LOT A trouvé dans la réponse")
        else:
            print(f"❌ Erreur HTTP {response.status_code}: {response.text[:200]}")
    except Exception as e:
        print(f"❌ Erreur: {e}")

print("\n" + "=" * 80)
print("TESTS TERMINÉS")
print("=" * 80)
