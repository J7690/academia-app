---
name: security-review
description: Relire un changement sous l'angle de la securite — RLS, secrets, paiements, donnees etudiantes. A utiliser avant toute poussee touchant Supabase, l'authentification, les paiements ou une Edge Function.
---

# Relire sous l'angle de la securite

Academia porte des **comptes etudiants**, des **credits** et des **paiements**
(LigDiCash). Un defaut ici ne se repare pas par un correctif : l'argent est
parti, ou la donnee est sortie.

## Ce qu'il faut verifier, dans l'ordre du risque

### 1. Les secrets

Aucun secret dans le depot. Ils vivent dans les **secrets Supabase** ou dans
l'environnement. Les JWT de role `anon` sont **publics par conception** — les
signaler comme fuite est un faux positif. Ce qui compte : `service_role`, les
cles OpenRouter (`sk-or-v1-`), RunPod, HuggingFace (`hf_`), et toute cle privee.

Verification reelle, avant poussee :

```bash
git diff origin/main..HEAD | grep -nE "eyJ[A-Za-z0-9_-]{20,}\.|sk-or-v1-|hf_[A-Za-z0-9]{30,}|BEGIN [A-Z ]*PRIVATE KEY"
```

Une correspondance n'est pas une fuite : **decoder le JWT** et lire son champ
`role` avant de conclure. Et un `-----BEGIN PRIVATE KEY-----` dans un
`.replace(...)` est du code qui retire un en-tete, pas une cle.

### 2. Le cloisonnement des donnees

Le schema metier est **`app`**, non expose a PostgREST ; les fonctions
appelables sont dans **`public`**. Consequence : **une RPC de `public` est une
surface d'attaque**. Pour chaque RPC touchee, se demander :

- est-elle `SECURITY DEFINER` ? si oui, qui peut l'appeler ?
- verifie-t-elle que `auth.uid()` a le droit sur la ligne visee, ou fait-elle
  confiance a un identifiant passe en parametre ?
- peut-on lui passer l'identifiant d'un **autre** etudiant ?

Une RPC `SECURITY DEFINER` qui accepte un `user_id` en parametre sans le
comparer a `auth.uid()` est une fuite de donnees, meme si la RLS est activee
sur la table.

### 3. Les paiements

Le rappel de LigDiCash est une entree **non authentifiee**. Regles :

- ne jamais faire confiance a un montant ou un statut venus du corps de la
  requete sans les reverifier aupres du fournisseur ;
- un jeton de rappel doit etre **verifie**, pas seulement present ;
- l'attribution de credits doit etre **idempotente** : deux rappels pour le
  meme paiement ne creditent qu'une fois.

### 4. Ce qui sort de l'appareil

Les journaux ne doivent contenir ni jeton, ni identite complete. Un `print` de
debogage laisse dans une Edge Function finit dans les journaux Supabase.

## Les outils disponibles

L'agent `pr-review-toolkit:silent-failure-hunter` est particulierement adapte a
ce depot : le defaut le plus grave du projet etait un echec silencieux presente
comme un succes.

```bash
# conseils de securite de Supabase sur le projet
# (outil MCP en lecture : get_advisors, type "security")
```

## Ce qui n'est PAS de la securite

Ne pas transformer une relecture de securite en revue de style. Si aucun risque
n'est trouve, le dire : « aucun risque identifie sur les N fichiers touches,
voici ce qui a ete verifie ». Une liste de remarques cosmetiques presentee comme
une revue de securite fait perdre confiance dans les vraies alertes.
