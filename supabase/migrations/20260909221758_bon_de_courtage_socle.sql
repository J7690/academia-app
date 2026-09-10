-- LE BON DE COURTAGE : table, numérotation, émission, vérification.
--
-- CE QU'EST CE DOCUMENT. Le reçu prouve à l'étudiant ce qu'il a versé à Nexiom
-- Group. Le bon prouve à l'ÉTABLISSEMENT que Nexiom a négocié pour ce candidat.
-- Deux documents, deux destinataires. L'analogue métier n'est pas un reçu SaaS
-- mais le « right to represent » du recrutement : un enregistrement horodaté
-- de la présentation d'une personne à un client NOMMÉ, qui fonde le droit à
-- commission. Même fonction que le bon de visite immobilier, dont la
-- jurisprudence dit qu'il ne vaut pas contrat mais preuve de l'intervention.
--
-- MAQUETTE VALIDÉE LE 02/09, QR RÉEL ET SCANNÉ. Ce qui manquait : tout le
-- reste. Cette migration pose le socle.
--
-- ─── LES SIX RÉPONSES DU SCAN, arrêtées avec Jocelyn le 09/09 ──────────────
--
--   1. bonne école, bon valide ....... tout est montré, et on peut le clore
--   2. bonne école, déjà consommé .... quand, et par qui
--   3. bonne école, expiré ........... les dates, et quoi faire
--   4. MAUVAISE école ................ « émis par Nexiom Group, mais pas
--                                        adressé à votre établissement ».
--                                        RIEN d'autre. Pas même le nom de
--                                        l'école destinataire.
--   5. numéro ou code inconnu ........ UNE SEULE réponse pour les deux cas
--   6. compte non universitaire ...... refus
--
-- POURQUOI LE CAS 4 NE NOMME RIEN (correction de Jocelyn, et elle est juste).
-- J'avais proposé d'annoncer l'établissement destinataire, en raisonnant que
-- l'école tient le papier et connaît déjà tout. Faux : on peut lui envoyer une
-- PHOTO du QR, ou lui dicter le code au téléphone. Le scanneur n'a alors rien
-- entre les mains. Ne rien nommer est donc la seule règle sûre.
--
-- POURQUOI LE CAS 5 EST UNIQUE. Si « numéro inconnu » et « code faux » se
-- distinguaient, on retrouverait les codes en essayant. Une seule réponse.

-- ─── 1. La numérotation, jumelle de celle du reçu ──────────────────────────
CREATE SEQUENCE IF NOT EXISTS app.bon_numero_seq;

-- LE CODE EST UN SECRET : il vient d'une source cryptographique.
--
-- Première version signalée par la relecture de sécurité, à raison : elle
-- utilisait `random()`, un générateur PSEUDO-aléatoire dont l'état se
-- reconstitue à partir de sorties observées. Corrigé par la migration
-- `code_du_bon_source_cryptographique` : `gen_random_bytes` (pgcrypto), et un
-- alphabet de 32 lettres — celui de Crockford base32 — pour que le `% 32` soit
-- exact. Un alphabet de 31 aurait introduit un biais, 256 n'étant pas
-- divisible par 31. Voir cette migration pour le raisonnement complet.
--
-- La version ci-dessous est conservée telle qu'appliquée, pour que l'histoire
-- reste lisible ; c'est la migration suivante qui fait foi.
CREATE OR REPLACE FUNCTION app.code_verification_bon()
RETURNS TEXT
LANGUAGE sql
VOLATILE
AS $function$
  SELECT string_agg(
           substr('23456789ABCDEFGHJKMNPQRSTUVWXYZ',
                  1 + floor(random() * 31)::int, 1), '')
  FROM generate_series(1, 8);
$function$;

-- ─── 2. L'empreinte, même formule que le reçu ──────────────────────────────
CREATE OR REPLACE FUNCTION app.empreinte_bon(p_numero TEXT, p_application_id UUID,
                                             p_snapshot JSONB)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $function$
  -- jsonb ordonne ses clés de façon déterministe : le texte est stable, donc
  -- l'empreinte est rejouable à l'identique par la vue de contrôle.
  SELECT encode(sha256(CONCAT_WS('|',
    p_numero,
    p_application_id::text,
    COALESCE(p_snapshot, '{}'::jsonb)::text
  )::bytea), 'hex');
$function$;

-- ─── 3. La table ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS app.brokerage_vouchers (
  id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id            UUID NOT NULL REFERENCES app.applications(id),
  -- UN bon par paiement de courtage. L'unicité porte l'idempotence : réémettre
  -- rend le bon existant au lieu d'en fabriquer un second.
  payment_id                UUID NOT NULL UNIQUE
                                 REFERENCES app.application_payments(id),
  -- Dénormalisé À DESSEIN : c'est la valeur du jour de l'émission qui décide
  -- qui peut vérifier. Si la formation changeait d'établissement demain, le
  -- bon resterait adressé à celui qui a négocié.
  destination_university_id UUID NOT NULL REFERENCES app.universities(id),
  voucher_number            TEXT NOT NULL UNIQUE,
  verification_code         TEXT NOT NULL,
  issued_by                 UUID NOT NULL,
  issued_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at                TIMESTAMPTZ NOT NULL,
  snapshot                  JSONB NOT NULL,
  signature_hash            TEXT,
  -- 'automatique' : émis à la confirmation du paiement.
  -- 'saisie_manuelle' : saisi par un administrateur pour quelqu'un qui ne
  -- pouvait pas suivre le parcours. LE DOCUMENT EST LE MÊME et la
  -- vérification est la même ; l'origine ne sert qu'à la trace.
  origin                    TEXT NOT NULL DEFAULT 'automatique'
                                 CHECK (origin IN ('automatique', 'saisie_manuelle')),
  consumed_at               TIMESTAMPTZ,
  consumed_by               UUID
);

CREATE INDEX IF NOT EXISTS brokerage_vouchers_numero_idx
  ON app.brokerage_vouchers (voucher_number);
CREATE INDEX IF NOT EXISTS brokerage_vouchers_universite_idx
  ON app.brokerage_vouchers (destination_university_id);
CREATE INDEX IF NOT EXISTS brokerage_vouchers_application_idx
  ON app.brokerage_vouchers (application_id);

ALTER TABLE app.brokerage_vouchers ENABLE ROW LEVEL SECURITY;
-- Aucune politique : la table ne se lit que par les fonctions ci-dessous,
-- toutes SECURITY DEFINER. C'est le choix déjà fait pour les reçus.

-- ─── 4. Le registre des vérifications ──────────────────────────────────────
-- « Qui a scanné quoi, et qu'a-t-il vu » : sans cela, une tentative de
-- présentation à la mauvaise école ne laisse aucune trace, et le litige de
-- commission qu'elle annonce se plaide sans pièce.
CREATE TABLE IF NOT EXISTS app.brokerage_voucher_checks (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  voucher_id    UUID REFERENCES app.brokerage_vouchers(id),
  voucher_number TEXT,
  checked_by    UUID,
  university_id UUID,
  resultat      TEXT NOT NULL,
  checked_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE app.brokerage_voucher_checks ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS brokerage_voucher_checks_bon_idx
  ON app.brokerage_voucher_checks (voucher_id, checked_at DESC);

-- ─── 5. L'immuabilité ──────────────────────────────────────────────────────
-- Un bon est une pièce probante : il ne se modifie pas. Seules deux colonnes
-- bougent, et une seule fois : celles de la consommation.
CREATE OR REPLACE FUNCTION app.bon_immuable()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Un bon de courtage ne se supprime pas (%).', OLD.voucher_number;
  END IF;
  IF NEW.voucher_number IS DISTINCT FROM OLD.voucher_number
     OR NEW.application_id IS DISTINCT FROM OLD.application_id
     OR NEW.payment_id IS DISTINCT FROM OLD.payment_id
     OR NEW.destination_university_id IS DISTINCT FROM OLD.destination_university_id
     OR NEW.snapshot IS DISTINCT FROM OLD.snapshot
     OR NEW.signature_hash IS DISTINCT FROM OLD.signature_hash
     OR NEW.issued_at IS DISTINCT FROM OLD.issued_at
     OR NEW.verification_code IS DISTINCT FROM OLD.verification_code THEN
    RAISE EXCEPTION 'Le contenu d''un bon de courtage est figé (%).', OLD.voucher_number;
  END IF;
  IF OLD.consumed_at IS NOT NULL AND NEW.consumed_at IS DISTINCT FROM OLD.consumed_at THEN
    RAISE EXCEPTION 'Ce bon a déjà été consommé le %.', OLD.consumed_at;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_bon_immuable ON app.brokerage_vouchers;
CREATE TRIGGER trg_bon_immuable
  BEFORE UPDATE OR DELETE ON app.brokerage_vouchers
  FOR EACH ROW EXECUTE FUNCTION app.bon_immuable();

-- ─── 6. Les vues de contrôle ───────────────────────────────────────────────
-- Délibérément des VUES, pas des déclencheurs : un déclencheur qui échoue à
-- écrire le bon ferait échouer le paiement, et l'étudiant perdrait son argent
-- ET son bon. C'est le raisonnement déjà retenu pour les reçus le 02/09.
CREATE OR REPLACE VIEW app.courtages_sans_bon AS
SELECT p.id AS payment_id, p.reference_code, p.amount_paid, p.amount_due,
       p.confirmed_at, s.full_name AS etudiant, a.id AS application_id,
       a.discount_rate
FROM app.application_payments p
JOIN app.applications a ON a.id = p.application_id
LEFT JOIN app.students s ON s.id = p.student_id
WHERE p.payment_reason = 'application_fee'::public.payment_reason
  AND p.status = 'confirmed'
  AND NOT EXISTS (SELECT 1 FROM app.brokerage_vouchers b WHERE b.payment_id = p.id);

COMMENT ON VIEW app.courtages_sans_bon IS
  'Courtages encaissés dont le bon n''a pas été émis. Doit rester vide.';

CREATE OR REPLACE VIEW app.bons_a_verifier AS
SELECT b.voucher_number, b.issued_at, b.application_id,
       b.signature_hash AS empreinte_stockee,
       app.empreinte_bon(b.voucher_number, b.application_id, b.snapshot) AS empreinte_recalculee,
       CASE WHEN b.signature_hash IS NULL THEN 'empreinte absente'
            ELSE 'empreinte differente' END AS motif
FROM app.brokerage_vouchers b
WHERE b.signature_hash IS NULL
   OR b.signature_hash <> app.empreinte_bon(b.voucher_number, b.application_id, b.snapshot);

COMMENT ON VIEW app.bons_a_verifier IS
  'Bons dont l''empreinte ne correspond plus au contenu. Doit rester vide.';
