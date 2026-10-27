-- Formations courtes : un motif de paiement à part entière.
--
-- Isolé dans sa propre migration : une valeur d'énumération ajoutée ne peut pas
-- être utilisée dans la transaction qui l'ajoute. La migration suivante
-- (20261027120000) s'en sert dès sa première ligne.

ALTER TYPE public.payment_reason ADD VALUE IF NOT EXISTS 'short_training';
