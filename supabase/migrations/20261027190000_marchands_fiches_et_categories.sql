-- Marketplace (27/10/2026) : B6 — tout marchand a ses deux fiches ; et la
-- boutique reçoit enfin des catégories (0 en base jusqu'ici).
--
-- B6, mesuré le 27/10 sur les 4 comptes `role = merchant` :
--   angeburkinabe        fiche marchand ✓  profil ✗  (2 annonces)
--   sabotagetravy        fiche marchand ✗  profil ✓
--   marketingnumerique   fiche marchand ✓  profil ✓
--   merchant.review      fiche marchand ✗  profil ✗  ← compte de revue Google Play :
--                        sans `marketplace_merchants`, la console ne trouve pas
--                        ses commandes (`v_merchant_id IS NULL`).
-- La console lit `marketplace_merchants` (commandes, revenus, versements) et
-- la vitrine lit `merchant_profiles` : il faut les deux.
--
-- Correctif : `app.marchand_assurer_fiches` crée la fiche manquante à partir
-- de ce qui existe (l'autre fiche, le nom étudiant, le début du courriel) ;
-- un déclencheur l'appelle dès qu'un compte prend le rôle `merchant`, quel que
-- soit le chemin de création ; les 4 comptes existants sont régularisés ici.
-- Une fiche créée ainsi reste `pending` (non vérifiée) : l'admin la valide.

-- ─── 1. Les deux fiches, garanties ─────────────────────────────────────────

CREATE OR REPLACE FUNCTION app.marchand_assurer_fiches(p_user uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $$
DECLARE
  v_nom     text;
  v_tel     text;
  v_mm      boolean := false;
  v_profil  boolean := false;
BEGIN
  IF p_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'user_requis');
  END IF;

  SELECT COALESCE(
           (SELECT NULLIF(trim(m.display_name), '') FROM app.marketplace_merchants m WHERE m.owner_user_id = p_user LIMIT 1),
           (SELECT NULLIF(trim(m.name), '') FROM app.marketplace_merchants m WHERE m.owner_user_id = p_user LIMIT 1),
           (SELECT NULLIF(trim(p.display_name), '') FROM app.merchant_profiles p WHERE p.user_id = p_user),
           (SELECT NULLIF(trim(s.full_name), '') FROM app.students s WHERE s.id = p_user),
           (SELECT NULLIF(split_part(u.email, '@', 1), '') FROM auth.users u WHERE u.id = p_user),
           'Boutique')
    INTO v_nom;

  SELECT COALESCE(NULLIF(s.whatsapp_phone, ''), NULLIF(s.phone, ''), NULLIF(u.phone, ''))
    INTO v_tel
  FROM auth.users u LEFT JOIN app.students s ON s.id = u.id
  WHERE u.id = p_user;

  IF NOT EXISTS (SELECT 1 FROM app.marketplace_merchants WHERE owner_user_id = p_user) THEN
    INSERT INTO app.marketplace_merchants (owner_user_id, name, display_name, contact_phone, status)
    VALUES (p_user, v_nom, v_nom, v_tel, 'pending');
    v_mm := true;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM app.merchant_profiles WHERE user_id = p_user) THEN
    INSERT INTO app.merchant_profiles (user_id, display_name)
    VALUES (p_user, v_nom);
    v_profil := true;
  END IF;

  RETURN jsonb_build_object('success', true, 'fiche_marchand_creee', v_mm,
                            'profil_cree', v_profil, 'nom', v_nom);
END;
$$;

REVOKE ALL ON FUNCTION app.marchand_assurer_fiches(uuid) FROM PUBLIC, anon, authenticated;

-- Le déclencheur ne bloque JAMAIS la création d'un compte : une erreur est
-- journalisée, le compte est créé, la régularisation pourra être rejouée.
CREATE OR REPLACE FUNCTION app.trg_marchand_assurer_fiches()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $$
BEGIN
  IF NEW.raw_app_meta_data->>'role' = 'merchant'
     AND (TG_OP = 'INSERT'
          OR OLD.raw_app_meta_data->>'role' IS DISTINCT FROM 'merchant') THEN
    BEGIN
      PERFORM app.marchand_assurer_fiches(NEW.id);
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'marchand_assurer_fiches(%) : %', NEW.id, SQLERRM;
    END;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_marchand_assurer_fiches ON auth.users;
CREATE TRIGGER trg_marchand_assurer_fiches
  AFTER INSERT OR UPDATE OF raw_app_meta_data ON auth.users
  FOR EACH ROW EXECUTE FUNCTION app.trg_marchand_assurer_fiches();

-- Régularisation des comptes existants.
SELECT app.marchand_assurer_fiches(u.id)
FROM auth.users u
WHERE u.raw_app_meta_data->>'role' = 'merchant';

-- ─── 2. Les catégories de la boutique ──────────────────────────────────────
-- Neuf rubriques pour une boutique étudiante au Burkina Faso, chacune avec ses
-- sous-rubriques. Les libellés recoupent `AlibabaMarketplaceTokens.categoryIcon`
-- (livre, info/téléphone, vêtement, aliment, maison, beauté, service, sport)
-- pour que chaque bulle reçoive la bonne icône. Insertion idempotente par code.

WITH racines(code, label, ordre) AS (VALUES
  ('livres-fournitures',      'Livres & fournitures',        10),
  ('informatique-telephones', 'Informatique & téléphones',   20),
  ('mode-vetements',          'Mode & vêtements',            30),
  ('alimentation',            'Alimentation',                40),
  ('maison-logement',         'Maison & logement',           50),
  ('beaute-sante',            'Beauté & santé',              60),
  ('services',                'Services',                    70),
  ('sport-loisirs',           'Sport & loisirs',             80),
  ('agriculture-elevage',     'Agriculture & élevage',       90)
)
INSERT INTO app.marketplace_categories (parent_id, code, label, sort_order, is_active)
SELECT NULL, r.code, r.label, r.ordre, true
FROM racines r
WHERE NOT EXISTS (SELECT 1 FROM app.marketplace_categories c WHERE c.code = r.code);

WITH sous(parent_code, code, label, ordre) AS (VALUES
  ('livres-fournitures',      'livres',                 'Livres',                   1),
  ('livres-fournitures',      'cours-polycopies',       'Cours & polycopiés',       2),
  ('livres-fournitures',      'fournitures-scolaires',  'Fournitures scolaires',    3),
  ('informatique-telephones', 'ordinateurs',            'Ordinateurs',              1),
  ('informatique-telephones', 'telephones',             'Téléphones',               2),
  ('informatique-telephones', 'accessoires-tech',       'Accessoires',              3),
  ('mode-vetements',          'vetements',              'Vêtements',                1),
  ('mode-vetements',          'chaussures',             'Chaussures',               2),
  ('mode-vetements',          'sacs-accessoires',       'Sacs & accessoires',       3),
  ('alimentation',            'plats-snacks',           'Plats & snacks',           1),
  ('alimentation',            'produits-locaux',        'Produits locaux',          2),
  ('alimentation',            'boissons',               'Boissons',                 3),
  ('maison-logement',         'meubles',                'Meubles',                  1),
  ('maison-logement',         'electromenager',         'Électroménager',           2),
  ('maison-logement',         'logement-colocation',    'Logement & colocation',    3),
  ('beaute-sante',            'soins',                  'Soins',                    1),
  ('beaute-sante',            'cosmetiques',            'Cosmétiques',              2),
  ('services',                'cours-particuliers',     'Cours particuliers',       1),
  ('services',                'reparation',             'Réparation',               2),
  ('services',                'impression-saisie',      'Impression & saisie',      3),
  ('services',                'transport-livraison',    'Transport & livraison',    4),
  ('sport-loisirs',           'equipement-sport',       'Équipement sportif',       1),
  ('sport-loisirs',           'jeux-loisirs',           'Jeux & loisirs',           2),
  ('agriculture-elevage',     'intrants',               'Intrants & aliments',      1),
  ('agriculture-elevage',     'animaux',                'Animaux',                  2),
  ('agriculture-elevage',     'materiel-agricole',      'Matériel',                 3)
)
INSERT INTO app.marketplace_categories (parent_id, code, label, sort_order, is_active)
SELECT p.id, s.code, s.label, s.ordre, true
FROM sous s
JOIN app.marketplace_categories p ON p.code = s.parent_code AND p.parent_id IS NULL
WHERE NOT EXISTS (SELECT 1 FROM app.marketplace_categories c WHERE c.code = s.code);
