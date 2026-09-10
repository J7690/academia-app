-- Le jeton du QR est un secret : il se fige comme le reste du bon.
--
-- Le verrou posé par `bon_de_courtage_socle` énumérait les colonnes figées.
-- `scan_token` n'existait pas encore. Sans cet ajout, un secret de 128 bits
-- serait la seule partie modifiable d'une pièce par ailleurs immuable.
--
-- Deux colonnes de plus au passage, oubliées au premier jet : `expires_at` et
-- `origin`. Repousser une échéance ou requalifier une saisie manuelle en
-- émission automatique, ce serait réécrire ce que le document atteste.
--
-- LA ROTATION N'EST PAS PRÉVUE, ET C'EST UN CHOIX. Faire tourner le jeton
-- invaliderait le QR déjà imprimé sur un papier remis au candidat. Si le
-- besoin apparaît — un bon photographié et diffusé — il faudra une fonction
-- dédiée, qui RÉÉMETTE le document plutôt qu'elle ne le modifie en silence.

CREATE OR REPLACE FUNCTION app.bon_immuable()
RETURNS TRIGGER LANGUAGE plpgsql AS $function$
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
     OR NEW.expires_at IS DISTINCT FROM OLD.expires_at
     OR NEW.origin IS DISTINCT FROM OLD.origin
     OR NEW.scan_token IS DISTINCT FROM OLD.scan_token
     OR NEW.verification_code IS DISTINCT FROM OLD.verification_code THEN
    RAISE EXCEPTION 'Le contenu d''un bon de courtage est fige (%).', OLD.voucher_number;
  END IF;
  IF OLD.consumed_at IS NOT NULL AND NEW.consumed_at IS DISTINCT FROM OLD.consumed_at THEN
    RAISE EXCEPTION 'Ce bon a deja ete consomme le %.', OLD.consumed_at;
  END IF;
  RETURN NEW;
END;
$function$;
