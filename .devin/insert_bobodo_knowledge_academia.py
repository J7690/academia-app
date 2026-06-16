#!/usr/bin/env python3
"""Insertion de fiches de connaissances Academia dans app.bobodo_knowledge."""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("INSERTION FICHES DE CONNAISSANCES ACADEMIA")
print("=" * 80)

# Fiches de connaissances
knowledge_entries = [
    {
        "title": "Présentation générale d'Academia",
        "content": "Academia est une plateforme numérique développée par Nexiom Group pour accompagner les étudiants, les nouveaux bacheliers, les universités, les enseignants et les partenaires. La plateforme centralise l'orientation, la recherche d'universités, les cours, les travaux dirigés, la préparation aux concours, les opportunités, la messagerie, les contenus pédagogiques et différents services destinés à faciliter la réussite académique et professionnelle. Bobodo est l'assistant intelligent intégré à Academia. Lorsqu'il répond à un utilisateur, il doit considérer qu'il se trouve déjà dans l'application et guider naturellement vers les espaces appropriés.",
        "category": "NEXIOM_ACADEMIA_INTERNE",
        "tags": ["academia", "plateforme", "présentation", "bobodo", "nexiom"]
    },
    {
        "title": "Onglet Universités",
        "content": "L'onglet Universités permet aux utilisateurs de découvrir les établissements partenaires disponibles sur Academia. Chaque université dispose d'une fiche détaillée pouvant présenter les formations, les filières, les procédures de candidature et d'autres informations utiles. Lorsqu'un utilisateur recherche une université partenaire, Bobodo doit l'inviter à ouvrir directement l'onglet Universités de l'application pour consulter les informations les plus récentes.",
        "category": "NEXIOM_ACADEMIA_INTERNE",
        "tags": ["universités", "partenaires", "formations", "candidatures"]
    },
    {
        "title": "Onglet Marketplace",
        "content": "Le Marketplace Academia est un espace dédié aux besoins de la vie étudiante. Les utilisateurs peuvent y retrouver différents produits et services utiles comme des fournitures scolaires, du matériel informatique, des accessoires, des équipements pédagogiques et d'autres ressources adaptées aux études. Les offres peuvent évoluer au fil du temps selon les partenaires disponibles sur la plateforme.",
        "category": "NEXIOM_ACADEMIA_INTERNE",
        "tags": ["marketplace", "boutique", "étudiant", "matériel", "fournitures"]
    },
    {
        "title": "Onglet TD",
        "content": "L'espace TD est conçu pour accompagner les étudiants dans leurs travaux dirigés. Les utilisateurs peuvent soumettre des exercices, obtenir des explications, demander des corrections, générer des quiz et recevoir une aide pédagogique grâce à l'intelligence artificielle. Lorsqu'un accompagnement plus personnalisé est nécessaire, il est également possible de solliciter l'intervention d'un enseignant.",
        "category": "NEXIOM_ACADEMIA_INTERNE",
        "tags": ["td", "travaux dirigés", "correction", "quiz", "enseignant"]
    },
    {
        "title": "Préparation Concours",
        "content": "L'espace Préparation Concours aide les étudiants et candidats à s'entraîner pour différents concours. Les utilisateurs peuvent consulter des contenus pédagogiques, soumettre des exercices, demander des corrections, générer des questionnaires d'entraînement et bénéficier d'un accompagnement spécifique. Des enseignants peuvent également intervenir pour un suivi personnalisé.",
        "category": "NEXIOM_ACADEMIA_INTERNE",
        "tags": ["concours", "préparation", "correction", "quiz", "entraînement"]
    },
    {
        "title": "Crédits IA",
        "content": "Certaines fonctionnalités avancées de l'application utilisent des crédits IA. Ces crédits permettent notamment d'accéder à certaines corrections, analyses, générations d'exercices ou services pédagogiques avancés. Les crédits sont utilisés uniquement pour certaines fonctionnalités identifiées dans l'application.",
        "category": "NEXIOM_ACADEMIA_INTERNE",
        "tags": ["crédits", "ia", "paiement", "services"]
    },
    {
        "title": "Accompagnement par des enseignants",
        "content": "Academia ne repose pas uniquement sur l'intelligence artificielle. Les utilisateurs peuvent également bénéficier de l'accompagnement d'enseignants qualifiés. Selon les besoins, cet accompagnement peut prendre la forme de séances en ligne ou de rencontres physiques lorsque cela est possible.",
        "category": "NEXIOM_ACADEMIA_INTERNE",
        "tags": ["enseignant", "tuteur", "cours particuliers", "accompagnement"]
    },
    {
        "title": "Bibliothèque de cours",
        "content": "L'espace Cours fonctionne comme une bibliothèque pédagogique numérique. Les utilisateurs peuvent consulter des ressources éducatives, accéder à différents contenus académiques et approfondir leurs connaissances dans plusieurs matières. Cet espace est destiné à soutenir l'apprentissage autonome et la révision.",
        "category": "NEXIOM_ACADEMIA_INTERNE",
        "tags": ["cours", "bibliothèque", "ressources", "pédagogie"]
    },
    {
        "title": "Espace Live",
        "content": "L'espace Live permet l'organisation de séances pédagogiques interactives en direct. Les utilisateurs peuvent participer à des cours, des ateliers, des conférences, des séances de soutien ou des rencontres avec des enseignants et intervenants.",
        "category": "NEXIOM_ACADEMIA_INTERNE",
        "tags": ["live", "visioconférence", "cours direct", "atelier"]
    },
    {
        "title": "Espace Challenge",
        "content": "L'espace Challenge permet aux utilisateurs de participer à des défis éducatifs, à des activités interactives et à des jeux à vocation pédagogique. Les étudiants peuvent partager du contenu, relever des défis et interagir avec d'autres utilisateurs dans un cadre stimulant et motivant.",
        "category": "NEXIOM_ACADEMIA_INTERNE",
        "tags": ["challenge", "défis", "jeux", "communauté"]
    },
    {
        "title": "Espace Opportunités",
        "content": "L'espace Opportunités est un espace communautaire où les utilisateurs peuvent publier du contenu, partager des informations, poser des questions, échanger des expériences et découvrir des opportunités utiles pour leurs études ou leur développement professionnel.",
        "category": "NEXIOM_ACADEMIA_INTERNE",
        "tags": ["opportunités", "communauté", "publication", "réseau"]
    },
    {
        "title": "Messagerie et groupes",
        "content": "Academia intègre un système de messagerie permettant aux utilisateurs de communiquer entre eux. Des groupes peuvent être créés selon les centres d'intérêt, les formations, les matières ou d'autres thématiques. Cet espace favorise l'entraide et les échanges entre étudiants.",
        "category": "NEXIOM_ACADEMIA_INTERNE",
        "tags": ["messagerie", "groupes", "discussion", "entraide"]
    },
    {
        "title": "Orientation académique et professionnelle",
        "content": "Academia propose des services d'orientation destinés à aider les utilisateurs dans leurs choix d'études et leurs projets professionnels. Lorsqu'une situation nécessite une analyse approfondie ou un accompagnement personnalisé, l'utilisateur peut être orienté vers un conseiller humain spécialisé.",
        "category": "ORIENTATION_ETUDES_EMPLOI",
        "tags": ["orientation", "carrière", "métier", "accompagnement"]
    }
]

# Insérer chaque fiche
for i, entry in enumerate(knowledge_entries, 1):
    print(f"\n📝 Fiche {i}/{len(knowledge_entries)}: {entry['title']}")
    print("-" * 80)
    
    try:
        result = manager.execute_sql_auto("""
            INSERT INTO app.bobodo_knowledge (title, content, category, tags)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (title) DO UPDATE SET
                content = EXCLUDED.content,
                category = EXCLUDED.category,
                tags = EXCLUDED.tags,
                updated_at = NOW()
            RETURNING id
        """, (entry['title'], entry['content'], entry['category'], entry['tags']))
        
        if result and len(result) > 0:
            print(f"✅ Insérée avec succès (ID: {result[0]['id']})")
        else:
            print("⚠️  Insertion réussie mais pas d'ID retourné")
    except Exception as e:
        print(f"❌ Erreur lors de l'insertion: {e}")

print("\n" + "=" * 80)
print("INSERTION TERMINÉE")
print("=" * 80)
