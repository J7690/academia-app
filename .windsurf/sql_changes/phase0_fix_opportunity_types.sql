-- ============================================================
-- PHASE 0 : Correction des types d'opportunités
-- Module : Opportunités Mini-Facebook
-- Date : 2025-01-04
-- ============================================================
-- OBJECTIF : Corriger les incohérences et ajouter les types manquants
-- SANS CASSER l'existant
-- ============================================================

-- 1. Mettre à jour le type existant incohérent (vendeur → job)
UPDATE app.opportunity_types
SET 
    code = 'job',
    label = 'Emploi / Stage',
    sort_order = 1,
    updated_at = NOW()
WHERE code = 'vendeur';

-- 2. Ajouter le type 'service' s'il n'existe pas
INSERT INTO app.opportunity_types (code, label, sort_order, is_active)
SELECT 'service', 'Service', 2, TRUE
WHERE NOT EXISTS (
    SELECT 1 FROM app.opportunity_types WHERE code = 'service'
);

-- 3. Ajouter le type 'product' s'il n'existe pas
INSERT INTO app.opportunity_types (code, label, sort_order, is_active)
SELECT 'product', 'Bien à vendre', 3, TRUE
WHERE NOT EXISTS (
    SELECT 1 FROM app.opportunity_types WHERE code = 'product'
);

-- 4. Mettre à jour l'opportunité existante qui utilise 'internship' → 'job'
-- (internship = stage, qui fait partie de la catégorie job/emploi)
UPDATE app.opportunities
SET 
    type = 'job',
    updated_at = NOW()
WHERE type = 'internship';

-- 5. Vérification finale : lister tous les types
SELECT id, code, label, sort_order, is_active 
FROM app.opportunity_types 
ORDER BY sort_order;
