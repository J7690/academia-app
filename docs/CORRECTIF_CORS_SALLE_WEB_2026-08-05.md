# Correctif — « Impossible de rejoindre la salle » sur le web (05/08/2026)

**Symptôme :** sur `academiea.com`, lancer une séance de consultation aboutit à
« Impossible de rejoindre la salle ». L'application mobile fonctionne.

**Appliqué en production**, vérifié.

---

## 1. Le diagnostic

Le message affiché est le **repli générique** de `_humanReadableError` : aucun
motif connu ne correspondait. L'échec ne venait donc pas d'un refus métier.

Les journaux des Edge Functions ont donné la réponse en une ligne :

```
OPTIONS | 200 | .../functions/v1/livekit-token
OPTIONS | 200 | .../functions/v1/livekit-token
OPTIONS | 200 | .../functions/v1/livekit-token
```

**Trois préambules CORS, pas un seul POST.** Le navigateur envoyait la requête
préalable, recevait 200, puis **bloquait la vraie requête**.

Vérifié directement :

```
Access-Control-Request-Headers: authorization,apikey,content-type,x-client-info
→ access-control-allow-headers: authorization,apikey,content-type,accept
```

`x-client-info` n'était pas autorisé. Le client Supabase l'envoie
**systématiquement**. Le navigateur refusait donc d'émettre le POST.

### Pourquoi le mobile marchait

**CORS est une règle de navigateur.** En natif (Android, iOS) elle n'est pas
appliquée : la requête part quoi qu'il arrive. Le défaut était donc invisible
sur l'application et bloquant sur le web — la définition même d'un angle mort.

### Ce que montrait la base

Cinq séances d'orientation créées le 05/08, **toutes en `ended`** : le
conseiller a réessayé cinq fois. À chaque tentative, `startSession` passait
(PostgREST a un CORS correct), puis le jeton était bloqué, l'écran d'erreur
s'affichait, et le retour clôturait la séance.

---

## 2. Origine — et ma part

La ligne fautive vient de la version 67 de `livekit-token`, que j'ai
**rapatriée telle quelle** depuis la production le 02/08 lors du réalignement du
dépôt. Je ne l'ai pas introduite, mais je ne l'ai pas vue non plus : je
transcrivais fidèlement sans relire ce que je transcrivais.

**Quatre autres fonctions portaient le même défaut** — jamais détecté parce que
personne n'avait encore utilisé la salle depuis un navigateur.

---

## 3. Le correctif

Ajout de `x-client-info` et `x-supabase-api-version` à la liste autorisée, sur
les cinq fonctions appelées depuis la salle :

| Fonction | Rôle | État |
|---|---|---|
| `livekit-token` | entrer dans la salle | ✅ v70 |
| `livekit-recording` | enregistrer la séance | ✅ |
| `livekit-admin` | couper un micro, exclure | ✅ |
| `livekit-moderate` | modération serveur | ✅ |
| `learning-session-summary` | fiche de séance | ✅ |

`send-push-notifications` n'a pas d'en-têtes CORS : elle n'est appelée que par
les déclencheurs de la base, jamais depuis un navigateur. C'est correct.

Les quatre dernières ont été déployées **par la CLI Supabase** plutôt que
retranscrites à la main — plus rapide et sans risque d'erreur de copie.

### Vérification

```
livekit-token             OK        ligdicash-initiate   OK
livekit-recording         OK        ligdicash-confirm    OK
livekit-admin             OK
livekit-moderate          OK
learning-session-summary  OK
```

Et le POST atteint désormais la fonction :

```
POST /functions/v1/livekit-token  →  HTTP 401 (Missing authorization header)
```

401 est la bonne réponse pour un appel sans jeton : **la requête n'est plus
bloquée en amont**.

---

## 4. Ce qui reste à faire

**Vérifier depuis le navigateur.** Je ne peux pas relancer une consultation
réelle à votre place : la correction est démontrée au niveau du transport, pas
au niveau de l'expérience. Relancez une consultation sur `academiea.com` — si
l'écran d'erreur revient, le message sera différent, et ce sera une autre cause.

**Une leçon de méthode.** Ce défaut était invisible sur mobile et bloquant sur
le web. Toute vérification future d'une fonctionnalité de salle devrait se faire
**sur les deux surfaces**, pas seulement sur l'application.
