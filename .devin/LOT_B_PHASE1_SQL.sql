-- ============================================================================
-- LOT B PHASE 1 – 5 FICHES CRITIQUES
-- Date : 9 juin 2026
-- Catégorie : NEXIOM_ACADEMIA_INTERNE
-- ============================================================================

-- ============================================================================
-- FICHE 1 : Création de compte
-- ============================================================================
INSERT INTO app.bobodo_knowledge (title, content, category, tags)
VALUES (
    'Comment créer un compte sur Academia ?',
    'Pour créer ton compte sur Academia, tu as besoin de ton nom, prénom, email et un mot de passe. Va sur l''écran d''inscription, remplis ces informations et valide. Tu recevras un email de confirmation pour activer ton compte. Si tu as un code de parrainage, tu peux l''ajouter pour bénéficier d''avantages. Une fois ton compte activé, tu pourras accéder à toutes les fonctionnalités d''Academia.',
    'NEXIOM_ACADEMIA_INTERNE',
    ARRAY['compte', 'inscription', 'création', 'email', 'mot de passe']
);

-- ============================================================================
-- FICHE 2 : Modification du profil
-- ============================================================================
INSERT INTO app.bobodo_knowledge (title, content, category, tags)
VALUES (
    'Comment modifier mon profil ?',
    'Pour modifier ton profil, va dans l''onglet "Mon profil" depuis ton dashboard. Tu peux y changer tes informations personnelles : nom complet, téléphone, pays, ville, date de naissance. Tu peux aussi ajouter ou modifier tes informations scolaires : BEPC (année, établissement, mention) et BAC (année, série, mention, établissement). N''oublie pas de renseigner ton projet d''étude, cela aide à personnaliser ton accompagnement. Sauvegarde tes modifications pour qu''elles soient prises en compte.',
    'NEXIOM_ACADEMIA_INTERNE',
    ARRAY['profil', 'modification', 'informations personnelles', 'BEPC', 'BAC', 'projet d''étude']
);

-- ============================================================================
-- FICHE 3 : Paiement en attente
-- ============================================================================
INSERT INTO app.bobodo_knowledge (title, content, category, tags)
VALUES (
    'Mon paiement est en attente',
    'Si ton paiement est en attente, cela signifie que la transaction est en cours de validation. Cela peut prendre quelques minutes selon ton opérateur (Orange Money, Moov Money, Telecel Cash, LigdiCash). Vérifie que tu as bien reçu la confirmation de paiement de ton opérateur. Si après 24h ton paiement est toujours en attente, utilise l''icône flottante Support pour contacter l''équipe d''administration. Ils pourront vérifier le statut de ta transaction et t''aider.',
    'NEXIOM_ACADEMIA_INTERNE',
    ARRAY['paiement', 'en attente', 'validation', 'Orange Money', 'Moov Money', 'Telecel Cash', 'LigdiCash']
);

-- ============================================================================
-- FICHE 4 : Candidature bloquée
-- ============================================================================
INSERT INTO app.bobodo_knowledge (title, content, category, tags)
VALUES (
    'Ma candidature est bloquée',
    'Si ta candidature est bloquée, vérifie d''abord son statut dans l''onglet "Candidatures". Les statuts possibles sont : brouillon (en cours de rédaction), envoyée (soumise à l''université), en examen (en cours d''étude), acceptée (admission confirmée), refusée (candidature rejetée), annulée. Si ton statut est "en examen" depuis longtemps, c''est normal que l''université prenne du temps pour étudier ton dossier. Si tu as un doute ou si tu penses qu''il y a un problème, utilise l''icône flottante Support pour contacter l''équipe d''administration. Ils pourront vérifier l''état de ta candidature et t''indiquer la suite.',
    'NEXIOM_ACADEMIA_INTERNE',
    ARRAY['candidature', 'bloquée', 'statut', 'brouillon', 'envoyée', 'en examen', 'acceptée', 'refusée', 'annulée']
);

-- ============================================================================
-- FICHE 5 : Accès aux cours d''appui
-- ============================================================================
INSERT INTO app.bobodo_knowledge (title, content, category, tags)
VALUES (
    'Comment accéder aux cours d''appui ?',
    'Pour accéder aux cours d''appui (TD), va dans l''onglet "TD" depuis ton dashboard. Tu y trouveras plusieurs sections : le catalogue des programmes disponibles, tes inscriptions en cours, les ressources pédagogiques, le classement, tes statistiques, l''IA Tuteur pour t''aider, les groupes locaux pour travailler avec d''autres étudiants, et les exercices pour t''entraîner. Pour t''inscrire à un programme, va dans le catalogue, choisis le programme qui t''intéresse et suis les instructions d''inscription. Une fois inscrit, tu pourras accéder aux cours, aux exercices et aux sessions de travail.',
    'NEXIOM_ACADEMIA_INTERNE',
    ARRAY['cours d''appui', 'TD', 'travaux dirigés', 'catalogue', 'inscription', 'IA Tuteur', 'groupes locaux', 'exercices']
);
