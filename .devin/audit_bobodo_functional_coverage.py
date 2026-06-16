#!/usr/bin/env python3
"""Audit du taux de couverture fonctionnelle de Bobodo.

DOMAINE 1.2 – Taux de couverture fonctionnelle
- Liste des sujets que Bobodo devrait maîtriser
- Identification: sujets couverts, partiellement couverts, absents
"""

import requests
import json

url = 'https://thevdfcwlcqzdoybfvgs.supabase.co'
sk = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h = {'Authorization': f'Bearer {sk}', 'apikey': sk, 'Content-Type': 'application/json'}

print("=" * 80)
print("DOMAINE 1.2 – AUDIT TAUX DE COUVERTURE FONCTIONNELLE")
print("=" * 80)

# Récupérer toutes les fiches actives
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': 'SELECT id, category, title, content, tags FROM app.bobodo_knowledge WHERE is_active = TRUE ORDER BY category, title'}, timeout=30)
fiches = r.json()

# Indexer le contenu pour recherche
all_content = " ".join([f['title'] + " " + f['content'] + " " + " ".join(f.get('tags', [])) for f in fiches]).lower()

# Liste des sujets que Bobodo devrait maîtriser
sujets_attendus = {
    "Academia": ["academia", "plateforme", "fonctionnement", "compte", "inscription", "espace étudiant"],
    "Nexiom Group": ["nexiom", "groupe", "présentation", "courtage", "formation", "partenaire"],
    "Orientation": ["orientation", "conseil", "bibliothèque", "accompagnement"],
    "Processus de candidature": ["candidature", "postuler", "inscription", "demande"],
    "Paiements": ["paiement", "crédit", "réduction", "frais", "bourse"],
    "Crédits": ["crédit", "système de crédit", "achat", "consommation"],
    "Partenaires": ["partenaire", "université", "structure", "établissement"],
    "Étudiants": ["étudiant", "espace étudiant", "profil", "accès"],
    "Administration": ["admin", "administration", "gestion", "validation"],
    "Universités": ["université", "établissement", "partenaire", "offre"],
    "Formations": ["formation", "cours", "appui", "atelier", "certifiante", "diplômante"],
    "Accompagnement": ["accompagnement", "conseil", "orientation", "suivi"],
    "Messagerie": ["message", "communication", "échange", "contact"],
    "Bibliothèque": ["bibliothèque", "ressource", "document", "contenu"],
    "Concours": ["concours", "prépa", "examen", "sujet"],
    "TD": ["td", "travaux dirigés", "exercice", "groupe local"],
    "Certifications": ["certification", "diplôme", "certifiante"],
    "Marketplace": ["marketplace", "marché", "produit", "vendeur"],
    "Espace enseignant": ["enseignant", "professeur", "tuteur", "espace enseignant"],
    "Espace partenaire": ["partenaire", "structure", "espace partenaire"],
    "Espace université": ["université", "espace université", "établissement"]
}

print(f"\n📚 Analyse de {len(sujets_attendus)} domaines fonctionnels attendus\n")

couverts = []
partiellement_couverts = []
absents = []

for domaine, keywords in sujets_attendus.items():
    # Compter combien de mots-clés sont présents
    matches = sum(1 for kw in keywords if kw.lower() in all_content)
    coverage = matches / len(keywords)
    
    if coverage >= 0.7:
        couverts.append((domaine, coverage, matches, len(keywords)))
    elif coverage >= 0.3:
        partiellement_couverts.append((domaine, coverage, matches, len(keywords)))
    else:
        absents.append((domaine, coverage, matches, len(keywords)))

print("✅ SUJETS COUVERTS (≥70%):")
print("-" * 80)
for domaine, coverage, matches, total in sorted(couverts, key=lambda x: -x[1]):
    print(f"   {domaine:<30} {coverage*100:.0f}% ({matches}/{total} mots-clés)")

print(f"\n⚠️  SUJETS PARTIELLEMENT COUVERTS (30-69%):")
print("-" * 80)
for domaine, coverage, matches, total in sorted(partiellement_couverts, key=lambda x: -x[1]):
    print(f"   {domaine:<30} {coverage*100:.0f}% ({matches}/{total} mots-clés)")

print(f"\n❌ SUJETS ABSENTS (<30%):")
print("-" * 80)
for domaine, coverage, matches, total in sorted(absents, key=lambda x: x[1]):
    print(f"   {domaine:<30} {coverage*100:.0f}% ({matches}/{total} mots-clés)")

# Résumé statistique
total_sujets = len(sujets_attendus)
nb_couverts = len(couverts)
nb_partiels = len(partiellement_couverts)
nb_absents = len(absents)

print(f"\n📊 RÉSUMÉ:")
print(f"   Total sujets analysés: {total_sujets}")
print(f"   ✅ Couverts: {nb_couverts} ({nb_couverts/total_sujets*100:.1f}%)")
print(f"   ⚠️  Partiellement couverts: {nb_partiels} ({nb_partiels/total_sujets*100:.1f}%)")
print(f"   ❌ Absents: {nb_absents} ({nb_absents/total_sujets*100:.1f}%)")

# Analyse par catégorie existante
print(f"\n📁 CONTENU ACTUEL PAR CATÉGORIE:")
print("-" * 80)
for f in fiches:
    print(f"\n   [{f['category'].upper()}] {f['title']}")
    print(f"   Tags: {', '.join(f.get('tags', []))}")
    preview = f['content'][:150] + "..." if len(f['content']) > 150 else f['content']
    print(f"   Contenu: {preview}")

print("\n" + "=" * 80)
print("FIN DU DOMAINE 1.2")
print("=" * 80)
