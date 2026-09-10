-- Le code de vérification du bon devient un vrai secret.
--
-- SIGNALÉ PAR LA RELECTURE DE SÉCURITÉ AUTOMATIQUE, et le signalement est
-- fondé. La première version tirait le code avec `random()`, un générateur
-- PSEUDO-aléatoire : son état se reconstitue à partir de sorties observées, et
-- il est semé par processus. Or les connexions sont mutualisées, si bien que
-- plusieurs bons peuvent sortir du même processus. Quelqu'un qui fait émettre
-- plusieurs bons pourrait alors prédire les suivants. Ce code autorise une
-- vérification : c'est un secret, il doit venir d'une source cryptographique.
--
-- TROIS CORRECTIONS, DONT DEUX QUE LE SIGNALEMENT NE DEMANDAIT PAS.
--
-- 1. LA SOURCE. `gen_random_bytes` (pgcrypto 1.3, déjà installé dans le schéma
--    `extensions` de ce projet) remplace `random()`.
--
-- 2. LE BIAIS DE MODULO. Le correctif suggéré gardait un alphabet de 31
--    lettres et un `% 31`. Or 256 n'est pas divisible par 31 : les huit
--    premières lettres sortiraient plus souvent que les autres
--    (256 = 8 × 31 + 8). On passe donc à un alphabet de 32, où `% 32` est
--    exact et sans biais. L'alphabet retenu est celui de **Crockford base32**
--    (chiffres et lettres, moins I, L, O et U), conçu précisément pour être lu
--    à l'oeil, recopié à la main et dicté au téléphone. C'est notre besoin,
--    et il est déjà résolu ailleurs.
--
-- 3. LA CONFUSION SE CORRIGE À LA LECTURE, PAS PAR L'EXCLUSION. Crockford
--    n'interdit pas O et I : il les DÉCODE vers 0 et 1. Une transcription
--    humaine fautive se rattrape donc au lieu d'échouer. D'où
--    `app.normaliser_code_bon`, appliquée à toute saisie.
--
-- CE QUE JE N'AI PAS FAIT, ET POURQUOI. Le signalement propose d'allonger le
-- code à 10 ou 12 caractères. **Écarté pour l'instant** : huit caractères,
-- c'est ce que porte la maquette validée par Jocelyn le 02/09, et c'est aussi
-- ce qu'utilise diplome.gouv.fr. Changer la longueur change le document
-- imprimé : c'est une décision produit, pas technique. L'entropie reste de
-- 32^8, soit 40 bits, et elle est compensée par un ÉTRANGLEMENT des tentatives
-- (migration `verification_du_bon_normalisation_et_etranglement`) : au-delà de
-- 20 échecs par compte et par heure, la vérification refuse. À ce rythme,
-- épuiser l'espace demanderait plus de cinquante milliards d'heures.
--
-- Aucun bon n'existait au moment du changement : le nouvel alphabet ne casse
-- rien.

CREATE OR REPLACE FUNCTION app.code_verification_bon()
RETURNS TEXT
LANGUAGE sql
VOLATILE
SET search_path TO 'app', 'public', 'extensions', 'pg_temp'
AS $function$
  SELECT string_agg(
           substr('0123456789ABCDEFGHJKMNPQRSTVWXYZ',
                  1 + (get_byte(b, i) % 32), 1), '' ORDER BY i)
  FROM (SELECT gen_random_bytes(8) AS b) t, generate_series(0, 7) AS i;
$function$;

CREATE OR REPLACE FUNCTION app.normaliser_code_bon(p_code TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $function$
  SELECT TRANSLATE(
           UPPER(REGEXP_REPLACE(COALESCE(p_code, ''), '[^0-9A-Za-z]', '', 'g')),
           'OILoil', '011011');
$function$;

COMMENT ON FUNCTION app.normaliser_code_bon(TEXT) IS
  'Normalise un code de bon lu sur papier : casse, séparateurs, et les '
  'confusions O/0 et I,L/1 selon Crockford base32.';
