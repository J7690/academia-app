#!/usr/bin/env python3
"""Audit de la personnalité conversationnelle de Bobodo.

PHASE 3 – Audit personnalité conversationnelle
PHASE 4 – Audit salutations
"""

print("=" * 80)
print("PHASE 3 – AUDIT PERSONNALITÉ CONVERSATIONNELLE")
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

print("\n🎭 INSTRUCTIONS CONTEXTUELLES PAR ÉTAT ÉMOTIONNEL:")
print("-" * 80)

print("\n1. GREETING (salutation):")
print("   - Réponds naturellement et chaleureusement en 1-2 phrases")
print("   - Présente-toi brièvement si c'est le début, puis propose ton aide")

print("\n2. EMOTIONAL (émotion):")
print("   - Fais preuve d'empathie en 1-2 phrases")
print("   - Propose ton aide de façon bienveillante")

print("\n3. FRUSTRATED (frustration):")
print("   - REFORMULE ta réponse précédente différemment, plus simplement")
print("   - Avec un exemple concret")
print("   - Commence par 'Permettez-moi d'expliquer autrement :'")

print("\n4. SATISFIED (satisfaction):")
print("   - Réponds chaleureusement en 1-2 phrases")
print("   - Propose ton aide pour autre chose")
print("   - Ne développe pas de nouveau contenu")

print("\n5. CONFIRMATION (confirmation):")
print("   - Confirme simplement en 1-2 phrases ('Oui, exactement !', 'C'est bien ça !')")
print("   - Propose de continuer")
print("   - NE RÉPÈTE PAS tout le contenu")

print("\n6. FOLLOW_UP (relance):")
print("   - Utilise jusqu'à 2 messages précédents de Bobodo pour le contexte")
print("   - Réponds directement et brièvement (1-3 phrases max)")
print("   - Sans reformuler tout le contexte")
print("   - Si c'est une confirmation, confirme simplement et propose de continuer")

print("\n📊 DÉTECTION ÉMOTIONNELLE (detectEmotionalState, lignes 298-372):")
print("-" * 80)

print("\nCouches de détection:")
print("   1. Réactions à un seul mot (oui, non, ok, waw, vraiment?, etc.) → follow_up")
print("   2. Confirmation/reformulation (ah ok, donc c'est, si je comprends bien, etc.) → follow_up")
print("   3. Message court avec '?' (<80 chars) → follow_up")
print("   4. Message court en contexte actif (<100 chars, history >= 2) → follow_up")
print("   5. Frustration (pas clair, pas compris, reformule, etc.) → frustrated")
print("   6. Satisfaction (merci, super, parfait, etc.) → satisfied")
print("   7. Défaut → neutral")

print("\n" + "=" * 80)
print("PHASE 4 – AUDIT SALUTATIONS")
print("=" * 80)

print("\n🔍 Règle de salutation (ligne 923-924):")
print("-" * 80)
print("   'Ne commence JAMAIS ta réponse par \"Bonjour\", \"Bonsoir\", \"Salut\"'")
print("   'ou toute autre salutation. La conversation est déjà engagée.'")
print("   'Va directement au sujet.'")

print("\n🔍 Salutation enrichie côté serveur (lignes 1207-1256):")
print("-" * 80)
print("   SI c'est le PREMIER message de Bobodo de la session:")
print("   - Récupérer le prénom de l'étudiant via app_get_bobodo_student_first_name")
print("   - Ajouter préfixe: 'Bonjour {prénom}, on se rencontre, je suis Bobodo, l'assistant d'Academia. '")
print("   - Ou: 'Bonjour, je suis Bobodo, l'assistant d'Academia. '")
print("   - Concaténer avec la réponse IA")

print("\n🧪 Tests théoriques de salutations:")
print("-" * 80)

greetings = [
    ("bonjour", "SMALL_TALK_EMOTION", "greeting"),
    ("salut", "SMALL_TALK_EMOTION", "greeting"),
    ("coucou", "SMALL_TALK_EMOTION", "greeting"),
    ("hello", "SMALL_TALK_EMOTION", "greeting"),
    ("bonsoir", "SMALL_TALK_EMOTION", "greeting"),
    ("ça va", "SMALL_TALK_EMOTION", "greeting"),
    ("cc", "SMALL_TALK_EMOTION", "greeting"),
    ("yo", "SMALL_TALK_EMOTION", "greeting"),
    ("slt", "SMALL_TALK_EMOTION", "greeting"),
    ("bjr", "SMALL_TALK_EMOTION", "greeting")
]

for greeting, expected_category, expected_intent in greetings:
    print(f"\n   Test: '{greeting}'")
    print(f"   - Catégorie détectée: {expected_category}")
    print(f"   - Intention détectée: {expected_intent}")
    print(f"   - Prompt final: instruction contextuelle greeting")
    print(f"   - Réponse attendue: 1-2 phrases chaleureuses + présentation si premier message")
    print(f"   - Message système injecté: Préfixe salutation enrichi si premier message")

print("\n🔍 Pourquoi Bobodo produit des réponses longues et administratives:")
print("-" * 80)
print("   CAUSE PRINCIPALE: Règle 5 du prompt système maître")
print("   'Après une réponse utile, termine par une courte question d'engagement'")
print("   ('Y a-t-il autre chose sur lequel je peux t'aider ?')")
print("   ")
print("   Cette règle force systématiquement une question de fin,")
print("   ce qui rallonge les réponses et les rend plus 'administratives'.")

print("\n" + "=" * 80)
print("FIN PHASES 3 ET 4")
print("=" * 80)
