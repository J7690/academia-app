#!/usr/bin/env python3
"""Audit détaillé de la personnalité actuelle de Bobodo.

CHANTIER 4 – Réécriture complète de la personnalité
"""

print("=" * 80)
print("CHANTIER 4 – AUDIT PERSONNALITÉ ACTUELLE")
print("=" * 80)

print("\n📋 PROMPT SYSTÈME MAÎTRE (bobodo-chat/index.ts lignes 899-927):")
print("-" * 80)

master_prompt = """Tu es Bobodo, assistant IA de Nexiom Group et de la plateforme Academia.

RÈGLES ABSOLUES:
1. COMPRÉHENSION SÉMANTIQUE: Comprends toujours l'INTENTION de l'utilisateur, même si sa question 
est mal formulée, partielle, ou formulée autrement qu'avant. La même idée exprimée différemment 
doit obtenir la même réponse cohérente.

2. SUIVI CONTEXTUEL: Si l'utilisateur répond brièvement (oui, non, d'accord, ok, pourquoi, 
comment, continue...) à quelque chose que tu viens de dire ou demander, connecte toujours 
sa réponse à ton dernier message. Ne traite jamais un "oui" ou "non" isolément.

3. FRUSTRATION: Si l'utilisateur dit que ta réponse n'est pas claire ou reformule sa question — 
reformule immédiatement de façon plus simple ou avec un exemple concret. 
Commence par "Permettez-moi d'expliquer autrement :" et reformule.

4. SATISFACTION: Si l'utilisateur exprime satisfaction (merci, super, parfait...), 
réponds chaleureusement en 1-2 phrases ("Avec plaisir !") et propose ton aide pour autre chose.

5. FIN DE RÉPONSE: Après une réponse utile, termine par une courte question d'engagement 
("Y a-t-il autre chose sur lequel je peux t'aider ?") — SAUF si l'utilisateur a exprimé satisfaction/fin.

6. HORS DOMAINE: Pour les sujets extérieurs (ni études, ni orientation, ni Academia, ni Nexiom), 
explique brièvement et dis à l'utilisateur de contacter l'equipe Academia (support@nexiom.com) 
ou un professionnel compétent. Donne toujours une piste utile.

7. UNIVERSITÉS ET ÉTABLISSEMENTS: Ne donne JAMAIS d'informations sur les universités, 
écoles, instituts ou centres de formation, qu'ils soient partenaires ou non. 
Redirige TOUJOURS l'utilisateur vers l'onglet Universités de la plateforme Academia.

8. STYLE: Français clair, professionnel, chaleureux. Sans intro inutile. 
Questions simples → 2-3 phrases max. Questions complexes → max 7 phrases.

9. SALUTATIONS: Ne commence JAMAIS ta réponse par "Bonjour", "Bonsoir", "Salut" 
ou toute autre salutation. La conversation est déjà engagée. Va directement au sujet.

10. CONFIRMATION: Si l'utilisateur reformule ce qu'il a compris avec "ah ok", "donc c'est", 
"c'est bien ça ?", "au cas par cas" etc., confirme-le simplement en 1-2 phrases 
("Oui, exactement !", "C'est bien ça !") et propose de continuer. Ne répète pas tout."""

print(master_prompt)

print("\n📊 Analyse de la personnalité actuelle:")
print("-" * 80)

print("\n✅ POINTS POSITIFS:")
print("   - Compréhension sémantique (règle 1)")
print("   - Suivi contextuel (règle 2)")
print("   - Gestion frustration (règle 3)")
print("   - Gestion satisfaction (règle 4)")
print("   - Redirection hors domaine (règle 6)")
print("   - Blocage universités (règle 7)")
print("   - Style défini (règle 8)")
print("   - Gestion confirmation (règle 10)")

print("\n❌ POINTS NÉGATIFS:")
print("   - Question d'engagement FORCÉE (règle 5) → réponses administratives")
print("   - Ton trop professionnel/formel")
print("   - Pas de chaleur émotionnelle")
print("   - Pas d'encouragement spontané")
print("   - Pas de félicitations")
print("   - Pas de questions de découverte")
print("   - Pas de personnalisation")

print("\n📊 Analyse du ton actuel:")
print("-" * 80)

print("\nCaractéristiques:")
print("   - Professionnel: ✅")
print("   - Chaleureux: ⚠️  (limité)")
print("   - Intelligent: ✅")
print("   - Naturel: ❌ (trop formel)")
print("   - Encourageant: ❌")
print("   - Concis: ⚠️  (question forcée rallonge)")

print("\n📊 Analyse des instructions contextuelles:")
print("-" * 80)

print("\nÉtat émotionnel → Instruction:")
print("   - greeting → Réponds naturellement et chaleureusement en 1-2 phrases")
print("   - emotional → Fais preuve d'empathie en 1-2 phrases")
print("   - frustrated → REFORMULE avec 'Permettez-moi d'expliquer autrement :'")
print("   - satisfied → Réponds chaleureusement en 1-2 phrases")
print("   - confirmation → Confirme en 1-2 phrases sans répéter")
print("   - follow_up → Utilise 2 derniers messages, 1-3 phrases max")

print("\n✅ Les instructions contextuelles sont bien conçues")
print("❌ Mais le prompt maître force une question d'engagement systématique")

print("\n📊 Analyse des questions forcées:")
print("-" * 80)

print("\nRègle 5 du prompt maître:")
print("   'Après une réponse utile, termine par une courte question d'engagement'")
print("   'Y a-t-il autre chose sur lequel je peux t'aider ?'")

print("\n❌ PROBLÈME:")
print("   - Cette question est systématique")
print("   - Elle rallonge toutes les réponses")
print("   - Elle donne un ton administratif")
print("   - Elle n'est pas contextuelle")
print("   - Elle est répétitive")

print("\n📊 Analyse des salutations:")
print("-" * 80)

print("\nRègle 9 du prompt maître:")
print("   'Ne commence JAMAIS ta réponse par Bonjour, Bonsoir, Salut'")
print("   'La conversation est déjà engagée. Va directement au sujet.'")

print("\n❌ PROBLÈME:")
print("   - Cette règle est contradictoire avec l'enrichissement côté serveur")
print("   - Côté serveur: ajout de 'Bonjour {prénom}, on se rencontre...'")
print("   - Résultat: confusion entre règle prompt et enrichissement serveur")

print("\n📊 Analyse de l'encouragement:")
print("-" * 80)

print("\n❌ PAS D'ENCOURAGEMENT SPONTANÉ:")
print("   - Aucune règle d'encouragement")
print("   - Aucune détection de difficulté")
print("   - Aucune détection de motivation")
print("   - Aucune détection de progression")

print("\n📊 Analyse des félicitations:")
print("-" * 80)

print("\n❌ PAS DE FÉLICITATIONS:")
print("   - Aucune règle de félicitation")
print("   - Aucune détection de réussite")
print("   - Aucune détection de validation")
print("   - Aucune détection d'admission")

print("\n📊 Analyse des questions de découverte:")
print("-" * 80)

print("\n❌ PAS DE QUESTIONS DE DÉCOUVERTE:")
print("   - Aucune règle de découverte")
print("   - Bobodo ne pose jamais de questions")
print("   - Bobodo ne cherche pas à connaître l'utilisateur")
print("   - Relation unidirectionnelle (réponse uniquement)")

print("\n" + "=" * 80)
print("FIN CHANTIER 4 – AUDIT")
print("=" * 80)
