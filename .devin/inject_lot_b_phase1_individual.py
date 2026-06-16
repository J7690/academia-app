#!/usr/bin/env python3
"""Injection LOT B Phase 1 - 5 fiches CRITIQUES (INSERT individuels)"""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("INJECTION LOT B PHASE 1 - 5 FICHES CRITIQUES (INSERT INDIVIDUELS)")
print("=" * 80)

# Compter les fiches avant injection
print("\n--- Comptage avant injection ---")
result = manager.execute_sql_auto("""
    SELECT COUNT(*) as count
    FROM app.bobodo_knowledge;
""")

if result and 'data' in result and len(result['data']) > 0:
    count_before = result['data'][0]['count']
    print(f"Nombre de fiches avant injection : {count_before}")
else:
    print("❌ Erreur lors du comptage avant injection")
    count_before = 0

# Fiches à injecter
fiches = [
    {
        'title': 'Comment créer un compte sur Academia ?',
        'content': "Pour créer ton compte sur Academia, tu as besoin de ton nom, prénom, email et un mot de passe. Va sur l'écran d'inscription, remplis ces informations et valide. Tu recevras un email de confirmation pour activer ton compte. Si tu as un code de parrainage, tu peux l'ajouter pour bénéficier d'avantages. Une fois ton compte activé, tu pourras accéder à toutes les fonctionnalités d'Academia.",
        'category': 'NEXIOM_ACADEMIA_INTERNE',
        'tags': "ARRAY['compte', 'inscription', 'création', 'email', 'mot de passe']"
    },
    {
        'title': 'Comment modifier mon profil ?',
        'content': "Pour modifier ton profil, va dans l'onglet 'Mon profil' depuis ton dashboard. Tu peux y changer tes informations personnelles : nom complet, téléphone, pays, ville, date de naissance. Tu peux aussi ajouter ou modifier tes informations scolaires : BEPC (année, établissement, mention) et BAC (année, série, mention, établissement). N'oublie pas de renseigner ton projet d'étude, cela aide à personnaliser ton accompagnement. Sauvegarde tes modifications pour qu'elles soient prises en compte.",
        'category': 'NEXIOM_ACADEMIA_INTERNE',
        'tags': "ARRAY['profil', 'modification', 'informations personnelles', 'BEPC', 'BAC', 'projet d'étude']"
    },
    {
        'title': 'Mon paiement est en attente',
        'content': "Si ton paiement est en attente, cela signifie que la transaction est en cours de validation. Cela peut prendre quelques minutes selon ton opérateur (Orange Money, Moov Money, Telecel Cash, LigdiCash). Vérifie que tu as bien reçu la confirmation de paiement de ton opérateur. Si après 24h ton paiement est toujours en attente, utilise l'icône flottante Support pour contacter l'équipe d'administration. Ils pourront vérifier le statut de ta transaction et t'aider.",
        'category': 'NEXIOM_ACADEMIA_INTERNE',
        'tags': "ARRAY['paiement', 'en attente', 'validation', 'Orange Money', 'Moov Money', 'Telecel Cash', 'LigdiCash']"
    },
    {
        'title': 'Ma candidature est bloquée',
        'content': "Si ta candidature est bloquée, vérifie d'abord son statut dans l'onglet 'Candidatures'. Les statuts possibles sont : brouillon (en cours de rédaction), envoyée (soumise à l'université), en examen (en cours d'étude), acceptée (admission confirmée), refusée (candidature rejetée), annulée. Si ton statut est 'en examen' depuis longtemps, c'est normal que l'université prenne du temps pour étudier ton dossier. Si tu as un doute ou si tu penses qu'il y a un problème, utilise l'icône flottante Support pour contacter l'équipe d'administration. Ils pourront vérifier l'état de ta candidature et t'indiquer la suite.",
        'category': 'NEXIOM_ACADEMIA_INTERNE',
        'tags': "ARRAY['candidature', 'bloquée', 'statut', 'brouillon', 'envoyée', 'en examen', 'acceptée', 'refusée', 'annulée']"
    },
    {
        'title': 'Comment accéder aux cours d''appui ?',
        'content': "Pour accéder aux cours d'appui (TD), va dans l'onglet 'TD' depuis ton dashboard. Tu y trouveras plusieurs sections : le catalogue des programmes disponibles, tes inscriptions en cours, les ressources pédagogiques, le classement, tes statistiques, l'IA Tuteur pour t'aider, les groupes locaux pour travailler avec d'autres étudiants, et les exercices pour t'entraîner. Pour t'inscrire à un programme, va dans le catalogue, choisis le programme qui t'intéresse et suis les instructions d'inscription. Une fois inscrit, tu pourras accéder aux cours, aux exercices et aux sessions de travail.",
        'category': 'NEXIOM_ACADEMIA_INTERNE',
        'tags': "ARRAY['cours d''appui', 'TD', 'travaux dirigés', 'catalogue', 'inscription', 'IA Tuteur', 'groupes locaux', 'exercices']"
    }
]

# Injecter chaque fiche individuellement
print("\n--- Injection des fiches ---")
for i, fiche in enumerate(fiches, 1):
    print(f"\nFiche {i}/{len(fiches)} : {fiche['title']}")
    
    sql = f"""
    INSERT INTO app.bobodo_knowledge (title, content, category, tags)
    VALUES (
        '{fiche['title']}',
        '{fiche['content']}',
        '{fiche['category']}',
        {fiche['tags']}
    );
    """
    
    try:
        result = manager.execute_sql_auto(sql)
        if result and 'error' in result:
            print(f"  ❌ Erreur : {result['error']}")
        else:
            print(f"  ✅ Injectée")
    except Exception as e:
        print(f"  ❌ Erreur : {e}")

# Compter les fiches après injection
print("\n--- Comptage après injection ---")
result = manager.execute_sql_auto("""
    SELECT COUNT(*) as count
    FROM app.bobodo_knowledge;
""")

if result and 'data' in result and len(result['data']) > 0:
    count_after = result['data'][0]['count']
    print(f"Nombre de fiches après injection : {count_after}")
    print(f"Différence : {count_after - count_before} fiches ajoutées")
else:
    print("❌ Erreur lors du comptage après injection")
    count_after = 0

# Vérifier les 5 nouvelles fiches
print("\n--- Vérification des 5 nouvelles fiches ---")
for fiche in fiches:
    result = manager.execute_sql_auto(f"""
        SELECT id, title, category, tags, is_active
        FROM app.bobodo_knowledge
        WHERE title = '{fiche['title']}';
    """)
    
    if result and 'data' in result and len(result['data']) > 0:
        fiche_data = result['data'][0]
        print(f"✅ {fiche['title']}")
        print(f"   ID : {fiche_data['id']}")
        print(f"   Catégorie : {fiche_data['category']}")
        print(f"   Tags : {fiche_data['tags']}")
        print(f"   Actif : {fiche_data['is_active']}")
    else:
        print(f"❌ {fiche['title']} - NON TROUVÉE")

print("\n" + "=" * 80)
print("INJECTION TERMINÉE")
print("=" * 80)
