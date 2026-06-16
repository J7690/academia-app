-- ========================================
-- BOBODO – Insertion fiches de connaissances Academia
-- ========================================

-- FICHE 1 : Présentation générale d'Academia
INSERT INTO app.bobodo_knowledge (title, content, category, tags)
VALUES (
    'Présentation générale d''Academia',
    'Academia est une plateforme numérique développée par Nexiom Group pour accompagner les étudiants, les nouveaux bacheliers, les universités, les enseignants et les partenaires. La plateforme centralise l''orientation, la recherche d''universités, les cours, les travaux dirigés, la préparation aux concours, les opportunités, la messagerie, les contenus pédagogiques et différents services destinés à faciliter la réussite académique et professionnelle. Bobodo est l''assistant intelligent intégré à Academia. Lorsqu''il répond à un utilisateur, il doit considérer qu''il se trouve déjà dans l''application et guider naturellement vers les espaces appropriés.',
    'NEXIOM_ACADEMIA_INTERNE',
    ARRAY['academia', 'plateforme', 'présentation', 'bobodo', 'nexiom']
);

-- FICHE 2 : Onglet Universités
INSERT INTO app.bobodo_knowledge (title, content, category, tags)
VALUES (
    'Onglet Universités',
    'L''onglet Universités permet aux utilisateurs de découvrir les établissements partenaires disponibles sur Academia. Chaque université dispose d''une fiche détaillée pouvant présenter les formations, les filières, les procédures de candidature et d''autres informations utiles. Lorsqu''un utilisateur recherche une université partenaire, Bobodo doit l''inviter à ouvrir directement l''onglet Universités de l''application pour consulter les informations les plus récentes.',
    'NEXIOM_ACADEMIA_INTERNE',
    ARRAY['universités', 'partenaires', 'formations', 'candidatures']
);

-- FICHE 3 : Onglet Marketplace
INSERT INTO app.bobodo_knowledge (title, content, category, tags)
VALUES (
    'Onglet Marketplace',
    'Le Marketplace Academia est un espace dédié aux besoins de la vie étudiante. Les utilisateurs peuvent y retrouver différents produits et services utiles comme des fournitures scolaires, du matériel informatique, des accessoires, des équipements pédagogiques et d''autres ressources adaptées aux études. Les offres peuvent évoluer au fil du temps selon les partenaires disponibles sur la plateforme.',
    'NEXIOM_ACADEMIA_INTERNE',
    ARRAY['marketplace', 'boutique', 'étudiant', 'matériel', 'fournitures']
);

-- FICHE 4 : Onglet TD
INSERT INTO app.bobodo_knowledge (title, content, category, tags)
VALUES (
    'Onglet TD',
    'L''espace TD est conçu pour accompagner les étudiants dans leurs travaux dirigés. Les utilisateurs peuvent soumettre des exercices, obtenir des explications, demander des corrections, générer des quiz et recevoir une aide pédagogique grâce à l''intelligence artificielle. Lorsqu''un accompagnement plus personnalisé est nécessaire, il est également possible de solliciter l''intervention d''un enseignant.',
    'NEXIOM_ACADEMIA_INTERNE',
    ARRAY['td', 'travaux dirigés', 'correction', 'quiz', 'enseignant']
);

-- FICHE 5 : Préparation Concours
INSERT INTO app.bobodo_knowledge (title, content, category, tags)
VALUES (
    'Préparation Concours',
    'L''espace Préparation Concours aide les étudiants et candidats à s''entraîner pour différents concours. Les utilisateurs peuvent consulter des contenus pédagogiques, soumettre des exercices, demander des corrections, générer des questionnaires d''entraînement et bénéficier d''un accompagnement spécifique. Des enseignants peuvent également intervenir pour un suivi personnalisé.',
    'NEXIOM_ACADEMIA_INTERNE',
    ARRAY['concours', 'préparation', 'correction', 'quiz', 'entraînement']
);

-- FICHE 6 : Crédits IA
INSERT INTO app.bobodo_knowledge (title, content, category, tags)
VALUES (
    'Crédits IA',
    'Certaines fonctionnalités avancées de l''application utilisent des crédits IA. Ces crédits permettent notamment d''accéder à certaines corrections, analyses, générations d''exercices ou services pédagogiques avancés. Les crédits sont utilisés uniquement pour certaines fonctionnalités identifiées dans l''application.',
    'NEXIOM_ACADEMIA_INTERNE',
    ARRAY['crédits', 'ia', 'paiement', 'services']
);

-- FICHE 7 : Accompagnement par des enseignants
INSERT INTO app.bobodo_knowledge (title, content, category, tags)
VALUES (
    'Accompagnement par des enseignants',
    'Academia ne repose pas uniquement sur l''intelligence artificielle. Les utilisateurs peuvent également bénéficier de l''accompagnement d''enseignants qualifiés. Selon les besoins, cet accompagnement peut prendre la forme de séances en ligne ou de rencontres physiques lorsque cela est possible.',
    'NEXIOM_ACADEMIA_INTERNE',
    ARRAY['enseignant', 'tuteur', 'cours particuliers', 'accompagnement']
);

-- FICHE 8 : Bibliothèque de cours
INSERT INTO app.bobodo_knowledge (title, content, category, tags)
VALUES (
    'Bibliothèque de cours',
    'L''espace Cours fonctionne comme une bibliothèque pédagogique numérique. Les utilisateurs peuvent consulter des ressources éducatives, accéder à différents contenus académiques et approfondir leurs connaissances dans plusieurs matières. Cet espace est destiné à soutenir l''apprentissage autonome et la révision.',
    'NEXIOM_ACADEMIA_INTERNE',
    ARRAY['cours', 'bibliothèque', 'ressources', 'pédagogie']
);

-- FICHE 9 : Espace Live
INSERT INTO app.bobodo_knowledge (title, content, category, tags)
VALUES (
    'Espace Live',
    'L''espace Live permet l''organisation de séances pédagogiques interactives en direct. Les utilisateurs peuvent participer à des cours, des ateliers, des conférences, des séances de soutien ou des rencontres avec des enseignants et intervenants.',
    'NEXIOM_ACADEMIA_INTERNE',
    ARRAY['live', 'visioconférence', 'cours direct', 'atelier']
);

-- FICHE 10 : Espace Challenge
INSERT INTO app.bobodo_knowledge (title, content, category, tags)
VALUES (
    'Espace Challenge',
    'L''espace Challenge permet aux utilisateurs de participer à des défis éducatifs, à des activités interactives et à des jeux à vocation pédagogique. Les étudiants peuvent partager du contenu, relever des défis et interagir avec d''autres utilisateurs dans un cadre stimulant et motivant.',
    'NEXIOM_ACADEMIA_INTERNE',
    ARRAY['challenge', 'défis', 'jeux', 'communauté']
);

-- FICHE 11 : Espace Opportunités
INSERT INTO app.bobodo_knowledge (title, content, category, tags)
VALUES (
    'Espace Opportunités',
    'L''espace Opportunités est un espace communautaire où les utilisateurs peuvent publier du contenu, partager des informations, poser des questions, échanger des expériences et découvrir des opportunités utiles pour leurs études ou leur développement professionnel.',
    'NEXIOM_ACADEMIA_INTERNE',
    ARRAY['opportunités', 'communauté', 'publication', 'réseau']
);

-- FICHE 12 : Messagerie et groupes
INSERT INTO app.bobodo_knowledge (title, content, category, tags)
VALUES (
    'Messagerie et groupes',
    'Academia intègre un système de messagerie permettant aux utilisateurs de communiquer entre eux. Des groupes peuvent être créés selon les centres d''intérêt, les formations, les matières ou d''autres thématiques. Cet espace favorise l''entraide et les échanges entre étudiants.',
    'NEXIOM_ACADEMIA_INTERNE',
    ARRAY['messagerie', 'groupes', 'discussion', 'entraide']
);

-- FICHE 13 : Orientation académique et professionnelle
INSERT INTO app.bobodo_knowledge (title, content, category, tags)
VALUES (
    'Orientation académique et professionnelle',
    'Academia propose des services d''orientation destinés à aider les utilisateurs dans leurs choix d''études et leurs projets professionnels. Lorsqu''une situation nécessite une analyse approfondie ou un accompagnement personnalisé, l''utilisateur peut être orienté vers un conseiller humain spécialisé.',
    'ORIENTATION_ETUDES_EMPLOI',
    ARRAY['orientation', 'carrière', 'métier', 'accompagnement']
);
