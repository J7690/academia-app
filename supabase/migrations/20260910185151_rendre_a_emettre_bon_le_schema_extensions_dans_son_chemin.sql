-- Correction immédiate d'une régression introduite quelques minutes plus tôt
-- par `20260910184933_les_fabriques_de_documents_ne_sont_plus_ouvertes_a_tous.sql`.
--
-- En réécrivant `app.emettre_bon` pour y poser la garde de statut, j'ai écrit
-- `SET search_path TO 'public', 'app', 'pg_temp'` -- de mémoire, au lieu de
-- relever ce que la fonction portait. Elle avait `'app', 'public',
-- 'extensions', 'pg_temp'`, et le schéma `extensions` n'y était pas par
-- hasard : c'est là que vit pgcrypto, donc `gen_random_bytes`, la source
-- cryptographique du jeton de scan posée le 09/09 pour remplacer `random()`.
--
-- Symptôme immédiat, vu dans l'essai en transaction annulée qui suivait :
--
--   ERROR 42883: function gen_random_bytes(integer) does not exist
--   QUERY: v_jeton := encode(gen_random_bytes(16), 'hex')
--
-- Plus aucun bon de courtage n'était émissible. `app.brokerage_vouchers` étant
-- vide, aucun document réel n'a été perdu -- mais la saisie au comptoir livrée
-- ce matin aurait échoué devant un candidat.
--
-- `ALTER FUNCTION ... SET` ne touche pas au corps : le condensé de `prosrc`
-- reste celui de la migration précédente, et le dépôt continue de décrire la
-- base.
--
-- Ce qu'on retient : un `SET search_path` fait partie du contrat de la
-- fonction, au même titre que sa signature. Le recopier de mémoire revient à
-- réécrire une dépendance sans la lire.

ALTER FUNCTION app.emettre_bon(UUID, UUID, TEXT, JSONB)
  SET search_path TO 'app', 'public', 'extensions', 'pg_temp';
