#!/usr/bin/env python3
"""Analyser la couverture actuelle de Bobodo pour identifier les zones non couvertes"""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("ANALYSE COUVERTURE BOBODO")
print("=" * 80)

# Récupérer toutes les fiches actuelles
result = manager.execute_sql_auto("""
    SELECT title, category, tags
    FROM app.bobodo_knowledge
    WHERE is_active = true
    ORDER BY category, title
""")

if result and 'data' in result and len(result['data']) > 0:
    fiches = result['data']
    
    print(f"\nTotal fiches: {len(fiches)}")
    
    # Analyser par catégorie
    categories = {}
    for fiche in fiches:
        category = fiche['category']
        if category not in categories:
            categories[category] = []
        categories[category].append(fiche['title'])
    
    print("\n" + "=" * 80)
    print("FICHES PAR CATÉGORIE")
    print("=" * 80)
    
    for category, titles in sorted(categories.items()):
        print(f"\n{category} ({len(titles)} fiches):")
        for title in titles:
            print(f"  - {title}")
    
    # Identifier les zones potentiellement non couvertes
    print("\n" + "=" * 80)
    print("ZONES POTENTIELLEMENT NON COUVERTES")
    print("=" * 80)
    
    # Zones basées sur les besoins étudiants typiques
    zones_non_couvertes = [
        "Universités partenaires (liste, critères spécifiques)",
        "Processus de sélection universitaire",
        "Calendrier des admissions",
        "Bourses et aides financières",
        "Logement étudiant",
        "Transport vers les universités",
        "Visas et documents de voyage",
        "Assurance étudiante",
        "Coût de la vie par ville/université",
        "Programmes d'échange",
        "Reconnaissance des diplômes",
        "Conditions linguistiques (TOEFL, IELTS)",
        "Processus de visa étudiant",
        "Travail étudiant pendant les études",
        "Services de santé sur le campus",
        "Clubs et activités étudiantes",
        "Support psychologique",
        "Orientation carrière",
        "Stages et opportunités professionnelles",
        "Alumni et réseau",
    ]
    
    print("\nZones identifiées comme potentiellement non couvertes:")
    for i, zone in enumerate(zones_non_couvertes, 1):
        print(f"{i}. {zone}")
    
    # Vérifier si certaines zones sont partiellement couvertes
    print("\n" + "=" * 80)
    print("VÉRIFICATION COUVERTURE PARTIELLE")
    print("=" * 80)
    
    covered_keywords = {
        "Universités partenaires": ["université", "partenaire", "partenaires"],
        "Processus de sélection": ["sélection", "admission", "critère"],
        "Paiements": ["paiement", "crédit", "ligdicash"],
        "Suivi candidature": ["suivi", "candidature", "statut"],
        "Documents": ["document", "dossier", "papier"],
    }
    
    for zone, keywords in covered_keywords.items():
        found = False
        for fiche in fiches:
            title_lower = fiche['title'].lower()
            if any(kw in title_lower for kw in keywords):
                found = True
                break
        status = "✅" if found else "❌"
        print(f"{status} {zone}")
        
else:
    print("❌ Erreur lors de la récupération des fiches")
