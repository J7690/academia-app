#!/usr/bin/env python3
"""Injection LOT A Bobodo Knowledge - Version 4 avec API REST directe"""

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
print("INJECTION LOT A – BOBODO KNOWLEDGE (VERSION 4 - API REST DIRECTE)")
print("=" * 80)

# Fiches du LOT A
fiches = [
    {
        'title': 'Comment déposer une candidature sur Academia',
        'content': 'Pour postuler, va d\'abord dans l\'onglet "Accueil" ou "Partenaires" pour trouver une formation qui t\'intéresse. Quand tu as choisi, un formulaire s\'ouvre : tu indiques ton niveau (Licence, Master...), ton mode d\'étude (présentiel, en ligne...), tes disponibilités et tu peux ajouter un commentaire. Si tu veux une réduction ou un échelonnement, coche la case et explique ta situation. Si ton profil n\'est pas complet, on te dira ce qu\'il manque. Les critères d\'admission dépendent de chaque université, donc regarde leur fiche détaillée pour plus d\'infos.',
        'category': 'NEXIOM_ACADEMIA_INTERNE',
        'tags': ['candidature', 'dépôt', 'formulaire', 'dossier incomplet']
    },
    {
        'title': 'Documents nécessaires pour une candidature',
        'content': 'Academia ne te donne pas une liste fixe de documents obligatoires. Quand tu déposes ta candidature, le système vérifie automatiquement si ton dossier est complet. Si quelque chose manque, on te le dira. Tu peux uploader tes documents (PDF, JPG, PNG, DOC, DOCX) un par un depuis l\'onglet "Documents" de ta candidature, avec le bouton "+". Tu peux en ajouter à tout moment si nécessaire.',
        'category': 'NEXIOM_ACADEMIA_INTERNE',
        'tags': ['documents', 'formats', 'upload', 'dossier incomplet']
    },
    {
        'title': 'Critères d\'admission des universités partenaires',
        'content': 'Les critères d\'admission dépendent de chaque université, donc je ne peux pas te répondre directement. Pour savoir si tu es éligible, regarde la fiche détaillée de l\'université qui t\'intéresse dans l\'onglet "Partenaires". Tu y trouveras leurs critères spécifiques (notes, diplômes, langues...). Tu peux aussi les contacter directement depuis leur fiche pour plus d\'infos. Academia vérifie juste que ton dossier est complet, mais les décisions d\'admission reviennent aux universités.',
        'category': 'NEXIOM_ACADEMIA_INTERNE',
        'tags': ['critères', 'admission', 'universités', 'partenaires']
    },
    {
        'title': 'Comprendre les statuts de candidature',
        'content': 'Draft (gris) : ton brouillon en cours de rédaction. Submitted (bleu) : candidature envoyée à l\'université. Under Review (orange) : en cours d\'examen par l\'université. Accepted (vert) : candidature acceptée. Rejected (rouge) : candidature refusée. Canceled (gris) : candidature annulée. Les changements de statut sont gérés par l\'université ou l\'administration. Tu peux filtrer tes candidatures par statut dans l\'onglet "Candidatures" pour suivre l\'évolution de chaque dossier.',
        'category': 'NEXIOM_ACADEMIA_INTERNE',
        'tags': ['statuts', 'candidature', 'draft', 'submitted', 'under review', 'accepted', 'rejected', 'canceled']
    },
    {
        'title': 'Effectuer un paiement sur Academia',
        'content': 'Pour déclarer un paiement, va dans l\'onglet "Paiements" de ta candidature et clique sur "Déclarer un paiement". Choisis ton canal : Orange Money, Moov Money, Telecel Money, Cash ou LigdiCash. Entre le montant payé. Pour le mobile money, n\'oublie pas la référence de l\'opérateur (ID Transaction ou SMS), c\'est obligatoire. Tu peux ajouter une note si tu veux. Après validation, ton paiement passe en vérification puis sera confirmé par l\'administration. Les motifs possibles sont : frais de candidature, frais d\'inscription, acompte scolarité, accès TD ou autre.',
        'category': 'NEXIOM_ACADEMIA_INTERNE',
        'tags': ['paiement', 'orange money', 'moov money', 'telecel money', 'ligdicash', 'déclaration', 'référence opérateur']
    },
    {
        'title': 'Guide complet des crédits IA',
        'content': 'Les crédits IA te donnent accès aux fonctionnalités avancées : correction TD, quiz concours, tuteur IA, etc. Ton solde s\'affiche dans le chip "Crédits" en haut des écrans Préparation Concours et TD. Pour en acheter, passe par LigdiCash après paiement confirmé. Tu as aussi un bonus hebdomadaire gratuit (tous les 6 jours minimum). Tes crédits sont consommés automatiquement quand tu utilises les fonctionnalités IA. Chaque action a un coût spécifique. Tu peux voir ton historique de transactions et les packs disponibles dans la section crédits.',
        'category': 'NEXIOM_ACADEMIA_INTERNE',
        'tags': ['crédits', 'ia', 'ligdicash', 'bonus hebdomadaire', 'consommation', 'achat']
    },
    {
        'title': 'Comment suivre sa candidature',
        'content': 'Tu peux suivre tes candidatures dans l\'onglet "Candidatures" de ton dashboard. Utilise les filtres par statut pour trouver rapidement ce que tu cherches. En cliquant sur une candidature, tu verras 4 onglets : Détails (infos de ta candidature), Documents (pour en ajouter avec le bouton +), Messages (pour discuter avec l\'université) et Paiements (pour déclarer ou voir tes paiements). Si l\'université t\'a envoyé un message, tu verras un badge rouge sur l\'onglet Messages.',
        'category': 'NEXIOM_ACADEMIA_INTERNE',
        'tags': ['suivi', 'candidature', 'documents', 'messages', 'paiements', 'filtre']
    }
]

success_count = 0

for i, fiche in enumerate(fiches, 1):
    print(f"\nInsertion fiche {i}/{len(fiches)}: {fiche['title']}")
    
    # Préparer les données
    data = {
        'title': fiche['title'],
        'content': fiche['content'],
        'category': fiche['category'],
        'tags': fiche['tags'],
        'language': 'fr',
        'is_active': True
    }
    
    try:
        response = requests.post(
            f"{url}/rest/v1/app/bobodo_knowledge",
            headers=headers,
            json=data,
            timeout=30
        )
        
        if response.status_code == 201:
            print(f"✅ Insertion réussie (ID: {response.json().get('id')})")
            success_count += 1
        else:
            print(f"❌ Erreur HTTP {response.status_code}: {response.text}")
    except Exception as e:
        print(f"❌ Erreur: {e}")

print(f"\n{success_count}/{len(fiches)} fiches insérées avec succès")
print("=" * 80)
