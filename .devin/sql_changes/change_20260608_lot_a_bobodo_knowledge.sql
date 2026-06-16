-- ============================================================================
-- LOT A – INJECTION IMMÉDIATE BOBODO KNOWLEDGE
-- Date : 8 juin 2026
-- Basé sur l'audit du code réel (écrans, providers, RPC, enums)
-- ============================================================================

-- ============================================================================
-- FICHE 1 : Processus de candidature
-- ============================================================================
INSERT INTO app.bobodo_knowledge (title, content, category, tags)
VALUES (
    'Comment déposer une candidature sur Academia',
    'Pour postuler, va d''abord dans l''onglet "Accueil" ou "Partenaires" pour trouver une formation qui t''intéresse. Quand tu as choisi, un formulaire s''ouvre : tu indiques ton niveau (Licence, Master...), ton mode d''étude (présentiel, en ligne...), tes disponibilités et tu peux ajouter un commentaire. Si tu veux une réduction ou un échelonnement, coche la case et explique ta situation. Si ton profil n''est pas complet, on te dira ce qu''il manque. Les critères d''admission dépendent de chaque université, donc regarde leur fiche détaillée pour plus d''infos.',
    'NEXIOM_ACADEMIA_INTERNE',
    ARRAY['candidature', 'dépôt', 'formulaire', 'dossier incomplet']
);

-- ============================================================================
-- FICHE 2 : Documents requis pour candidature
-- ============================================================================
INSERT INTO app.bobodo_knowledge (title, content, category, tags)
VALUES (
    'Documents nécessaires pour une candidature',
    'Academia ne te donne pas une liste fixe de documents obligatoires. Quand tu déposes ta candidature, le système vérifie automatiquement si ton dossier est complet. Si quelque chose manque, on te le dira. Tu peux uploader tes documents (PDF, JPG, PNG, DOC, DOCX) un par un depuis l''onglet "Documents" de ta candidature, avec le bouton "+". Tu peux en ajouter à tout moment si nécessaire.',
    'NEXIOM_ACADEMIA_INTERNE',
    ARRAY['documents', 'formats', 'upload', 'dossier incomplet']
);

-- ============================================================================
-- FICHE 3 : Critères d''admission
-- ============================================================================
INSERT INTO app.bobodo_knowledge (title, content, category, tags)
VALUES (
    'Critères d''admission des universités partenaires',
    'Les critères d''admission dépendent de chaque université, donc je ne peux pas te répondre directement. Pour savoir si tu es éligible, regarde la fiche détaillée de l''université qui t''intéresse dans l''onglet "Partenaires". Tu y trouveras leurs critères spécifiques (notes, diplômes, langues...). Tu peux aussi les contacter directement depuis leur fiche pour plus d''infos. Academia vérifie juste que ton dossier est complet, mais les décisions d''admission reviennent aux universités.',
    'NEXIOM_ACADEMIA_INTERNE',
    ARRAY['critères', 'admission', 'universités', 'partenaires']
);

-- ============================================================================
-- FICHE 4 : Statuts de candidature
-- ============================================================================
INSERT INTO app.bobodo_knowledge (title, content, category, tags)
VALUES (
    'Comprendre les statuts de candidature',
    'Draft (gris) : ton brouillon en cours de rédaction. Submitted (bleu) : candidature envoyée à l''université. Under Review (orange) : en cours d''examen par l''université. Accepted (vert) : candidature acceptée. Rejected (rouge) : candidature refusée. Canceled (gris) : candidature annulée. Les changements de statut sont gérés par l''université ou l''administration. Tu peux filtrer tes candidatures par statut dans l''onglet "Candidatures" pour suivre l''évolution de chaque dossier.',
    'NEXIOM_ACADEMIA_INTERNE',
    ARRAY['statuts', 'candidature', 'draft', 'submitted', 'under review', 'accepted', 'rejected', 'canceled']
);

-- ============================================================================
-- FICHE 5 : Effectuer un paiement sur Academia
-- ============================================================================
INSERT INTO app.bobodo_knowledge (title, content, category, tags)
VALUES (
    'Effectuer un paiement sur Academia',
    'Pour déclarer un paiement, va dans l''onglet "Paiements" de ta candidature et clique sur "Déclarer un paiement". Choisis ton canal : Orange Money, Moov Money, Telecel Money, Cash ou LigdiCash. Entre le montant payé. Pour le mobile money, n''oublie pas la référence de l''opérateur (ID Transaction ou SMS), c''est obligatoire. Tu peux ajouter une note si tu veux. Après validation, ton paiement passe en vérification puis sera confirmé par l''administration. Les motifs possibles sont : frais de candidature, frais d''inscription, acompte scolarité, accès TD ou autre.',
    'NEXIOM_ACADEMIA_INTERNE',
    ARRAY['paiement', 'orange money', 'moov money', 'telecel money', 'ligdicash', 'déclaration', 'référence opérateur']
);

-- ============================================================================
-- FICHE 6 : Guide complet des crédits IA
-- ============================================================================
INSERT INTO app.bobodo_knowledge (title, content, category, tags)
VALUES (
    'Guide complet des crédits IA',
    'Les crédits IA te donnent accès aux fonctionnalités avancées : correction TD, quiz concours, tuteur IA, etc. Ton solde s''affiche dans le chip "Crédits" en haut des écrans Préparation Concours et TD. Pour en acheter, passe par LigdiCash après paiement confirmé. Tu as aussi un bonus hebdomadaire gratuit (tous les 6 jours minimum). Tes crédits sont consommés automatiquement quand tu utilises les fonctionnalités IA. Chaque action a un coût spécifique. Tu peux voir ton historique de transactions et les packs disponibles dans la section crédits.',
    'NEXIOM_ACADEMIA_INTERNE',
    ARRAY['crédits', 'ia', 'ligdicash', 'bonus hebdomadaire', 'consommation', 'achat']
);

-- ============================================================================
-- FICHE 7 : Comment suivre sa candidature
-- ============================================================================
INSERT INTO app.bobodo_knowledge (title, content, category, tags)
VALUES (
    'Comment suivre sa candidature',
    'Tu peux suivre tes candidatures dans l''onglet "Candidatures" de ton dashboard. Utilise les filtres par statut pour trouver rapidement ce que tu cherches. En cliquant sur une candidature, tu verras 4 onglets : Détails (infos de ta candidature), Documents (pour en ajouter avec le bouton +), Messages (pour discuter avec l''université) et Paiements (pour déclarer ou voir tes paiements). Si l''université t''a envoyé un message, tu verras un badge rouge sur l''onglet Messages.',
    'NEXIOM_ACADEMIA_INTERNE',
    ARRAY['suivi', 'candidature', 'documents', 'messages', 'paiements', 'filtre']
);
