# Studio 3D — la capsule fabriquée en couches, un modèle OpenRouter par métier (29/10/2026)

> Demande de Jocelyn : « des couches pour qu'il génère les chaînes, les objets, les
> animations, le plan », puis « que les agents appelés en fonction de leur spécificité
> correspondent aux agents d'OpenRouter : qui est qualifié, et sa disponibilité
> effective ». Ce document dit ce qui a été construit, ce qui a été **mesuré** sur un
> banc de 20 sujets, ce qui a été écarté, et ce qui n'est pas vérifié.

## 1. Ce qui existe désormais

| Couche | Qui | Ce qu'elle reçoit | Ce qu'elle rend |
|---|---|---|---|
| 1. scénariste | **modèle** (`anthropic/claude-sonnet-5.5`) | le sujet, les décors, **la liste de ce que le moteur sait montrer** (69 objets, phénomènes, chimie) | le cours : scènes, voix, décor, intention, et `a_montrer` par scène — aucune coordonnée |
| 2. illustrateur | **modèle** (`anthropic/claude-haiku-5.5`, sans raisonnement), une scène par appel, **toutes en parallèle** | une scène, son `a_montrer`, le résumé des autres scènes | les gestes, en coordonnées |
| 3. contrôleur | **du code** : `validateCapsule` puis `defautsParScene` | la capsule assemblée | les défauts par scène ; **une** reprise ciblée des seules scènes fautives |
| (après) | du code : `resoudreChimie` | les réactions et molécules | coefficients exacts, géométrie PubChem |

La règle du projet tient : **l'IA choisit, notre code calcule et vérifie.**

Fichiers : `supabase/functions/whiteboard-generate-storyboard/chaine_capsule.ts`
(la chaîne), `llm.ts` (`appelerRole`, `ROLES_PAR_DEFAUT`, `REGLAGES_PAR_DEFAUT`),
`prompt_capsule.ts` (l'invite découpée en sections, recollée **à l'octet près** pour
le mode un appel — vérifié par `chaine_capsule_test.ts`). Tests : 73/73.

**En production depuis le 29/10 à 18 h 57 UTC** (génération v73, `main` = `52ee1dd`),
pour les capsules 3D en « sujet simple ». Les autres modes (texte, plan, cours fourni)
gardent l'appel unique, qui lit ce que l'étudiant a fourni.

## 2. Le choix des modèles : qualification, puis disponibilité, puis le banc

### 2.1 Disponibilité effective — relevée sur OpenRouter le 29/10 vers 17 h

`GET https://openrouter.ai/api/v1/models/<id>/endpoints` (champ `uptime_last_30m`) :

| Modèle | Fournisseurs | Disponibilité 30 min | `reasoning` / `response_format` |
|---|---|---|---|
| anthropic/claude-sonnet-5.5 | 10 | 100 % sur les 4 premiers | oui / oui |
| anthropic/claude-haiku-5.5 | 10 | 100 % | oui / oui |
| deepseek/deepseek-v4.1-flash | 41 | 100 % | oui / oui |
| google/gemini-3.8-flash | 7 | 100 %, **un fournisseur à 82,6 %** | oui / oui |
| google/gemini-2.5-flash (production actuelle) | 3 | 96,4 à 100 % | oui / oui |
| openai/gpt-6.1-sol | 8 | 96,7 à 100 % | oui / oui (Bedrock : non) |
| openai/gpt-6-luna | 7 | **un fournisseur à 16,7 %**, les autres 100 % | oui / oui |

Prix (`/api/v1/models`, en $ par million de jetons, entrée / sortie) : Sonnet 5.5
2 / 10 ; Haiku 5.5 0,10 / 0,50 ; Gemini 3.8 Flash 0,825 / 4,125 ; Gemini 2.5 Flash
0,30 / 2,50.

Ce que ce tableau ne dit pas : **la latence**. OpenRouter ne la publie pas par
modèle de façon exploitable ; seul notre banc la donne (§3).

### 2.2 Qualification

- Écriture d'un cours (scénariste) : Claude est en tête des classements d'écriture
  (LMArena, catégorie écriture créative) ; c'est l'appel qui porte la pédagogie et le
  français, et il ne coûte qu'environ 1 100 jetons de sortie.
- Traduction en gestes (illustrateur) : JSON strict, court (220 à 700 jetons), répété
  six fois : la vitesse et le prix comptent plus que le raisonnement.
- La littérature va dans le sens du découpage : Code2Video (NeurIPS 2025,
  [arXiv 2510.01174](https://arxiv.org/pdf/2510.01174)) sépare planificateur, codeur
  et critique ; TheoremExplainAgent ([arXiv 2502.19400](https://arxiv.org/pdf/2502.19400))
  et MovieAgent ([arXiv 2503.07314](https://arxiv.org/html/2503.07314v1)) aussi.
  Leurs gains sont mesurés sur **leurs** tâches, pas la nôtre : c'est pourquoi le
  banc tranche.

### 2.3 Ce que le banc a changé dans le choix initial

Le choix initial mettait **Gemini 3.8 Flash** en illustrateur. Le banc l'a déplacé
en dernier recours :

- Flash rend une scène en 3 à 5 s… et **11 appels sur une soixantaine ont pris 16 à
  20 s**, pour 220 à 340 jetons — autant que les rapides. C'est de l'attente chez le
  fournisseur, pas de l'écriture. La chaîne attend la scène la plus lente : 25 s
  par capsule au lieu de 12.
- Flash **refuse** qu'on coupe son raisonnement : HTTP 400 « Reasoning is mandatory
  for this endpoint and cannot be disabled ». `appelerRole` le rappelle alors avec un
  raisonnement court (vérifié en ligne : « raisonnement obligatoire, rappel en low »).
- Haiku 5.5 **sans raisonnement** rend une scène en 1,4 à 2,8 s, pour un huitième
  du prix de Flash, avec autant de gestes par scène.

Ordre retenu : illustrateur = Haiku → DeepSeek v4.1 Flash → Gemini 3.8 Flash.
DeepSeek est second sur **une seule** mesure (1,4 s, lors d'une reprise) : à
confirmer.

Rien de ceci n'exige de redéployer pour changer d'avis : la requête d'essai accepte
`roles` et `reglages`, la production lira le secret `OPENROUTER_ROLES`.

## 3. Le banc : 20 sujets, deux modes

Sujets : photosynthèse, respiration cellulaire, volcans, combustion, digestion,
circulation sanguine, théorème de Pythagore, inflation, démocratie, germination du
maïs, électricité statique, rouille du fer, fractions, paludisme, gravitation,
érosion des sols, neutralisation acide-base, système solaire, leviers, empire du
Mali. Appels par `net.http_post` vers `whiteboard-storyboard-smoke`, réponses lues
dans `net._http_response` (ids 138383 à 138479).

| | Un appel (production, Gemini 2.5 Flash) | Chaîne v6 (illustrateur Flash) | **Chaîne v7 (illustrateur Haiku sans raisonnement)** |
|---|---|---|---|
| capsules valides | 20/20 | 20/20 | 10/10 |
| durée médiane | **9,2 s** (7,1 – 12,6) | 15,7 s (10,9 – 28,1) | **10,1 s** (8,8 – 11,4 ; une à 30,6 s, voir §4) |
| coût moyen | ≈ 0,009 $ **estimé** (jetons × prix ; la fonction ne le rend pas) | 0,038 $ **mesuré** | **0,019 $ mesuré** |
| corrections | **29**, dans 9 capsules sur 20 | **0** | 4, dans 3 capsules sur 10 |
| — objet hors des 69 termes | 13 (pain ×6, chameau ×2, mosquée, masque, médicament, moteur, désertification) | 0 | 0 |
| — verbe inconnu (« flux ») | 4 | 0 | 0 |
| — organe posé sur le décor corps | 9 | 0 | 4 |
| gestes par scène | 4,03 | 3,92 | 3,96 |
| phénomènes et accessoires par scène | 1,48 | 1,83 | 1,42 |
| réactions chimiques | 4 (dont une illisible : « Fe2O3.nH2O ») | 6 | 2 sur 10 sujets |

Lecture :

1. **La chaîne supprime les fautes qui font disparaître un objet de l'image.** En un
   appel, 13 objets demandés n'existent pas dans la bibliothèque : la scène les
   annonce et ne les montre pas. Dans la chaîne, le scénariste reçoit la liste des 69
   termes et l'illustrateur un `a_montrer` déjà conforme : zéro.
2. **Avec Haiku, la chaîne coûte une seconde de plus qu'un appel**, pas quinze.
3. **Elle coûte environ deux fois plus** (0,019 $ contre ≈ 0,009 $ estimés). Sur la
   chaîne, le scénariste Sonnet pèse ~0,016 $ ; les six illustrateurs ~0,003 $.
4. Les « organes sur le décor corps » reviennent avec Haiku (4) : la validation les
   retire déjà, la scène reste juste, mais l'illustrateur a ignoré la consigne.

## 4. Pannes rencontrées, et leur cause

| Panne | Cause mesurée | Suite |
|---|---|---|
| JSON coupé au 2 445ᵉ caractère après 22 s (premier essai) | budget de sortie 3 000 mangé par le raisonnement | `appelerRole` : réponse tronquée ou illisible → modèle suivant ; budgets 6 000 / 4 000 ; raisonnement « low » |
| 3 réponses HTTP 503 sur 51 | 11 à 20 requêtes **simultanées** sur une fonction froide : 9 instances démarrées, les 2 restantes attendent 10 s et la passerelle renonce (journaux 16:59:06 → 16:59:16) | artefact de banc ; un étudiant envoie une requête à la fois. Concerne les deux modes |
| une capsule à 30,6 s (« le paludisme ») | une **reprise** : Haiku a répondu en prose (« Je ne peux… »), Flash a dépassé 15 s, DeepSeek a répondu en 1,4 s | Flash passe en dernier ; et la mesure était fausse (ci-dessous) |
| une étape annoncée à 1,4 s qui en a pris ~20 | `ms` ne comptait que le modèle qui avait répondu | corrigé : `ms` compte tous les essais (local, **pas encore dans la fonction d'essai v7**) |

## 5. Ce qui a été écarté

- **Un modèle de raisonnement pour l'illustrateur.** Il ne fait que traduire une
  scène écrite en coordonnées ; le raisonnement triple le temps sans gain mesuré.
- **Flash en premier illustrateur** : sa queue de latence (§2.3).
- **Un « critique » modèle en couche 3.** Le contrôle par le code (validation +
  `defautsParScene`) a ramené les corrections à 0 sur 20 sans coûter un appel ; un
  critique modèle n'aurait de sens que pour juger ce que le code ne voit pas
  (la justesse pédagogique, la ressemblance visuelle).
- **`openai/gpt-6-luna` en réalisateur** sans réserve : un de ses fournisseurs était à
  16,7 % de disponibilité au moment du relevé.

## 6. Ce qui n'est PAS vérifié

- **L'image.** Le banc compte des gestes, pas leur beauté. Aucune capsule de la
  chaîne n'a encore été **regardée** dans le lecteur ni sur le TECNO. C'est la
  vérification suivante, avant toute mise en production.
- Le coût exact du mode un appel (estimé, la fonction ne le rend pas).
- La couche **réalisateur** (choix des plans, F1) : prévue dans `ROLES_PAR_DEFAUT`,
  **non écrite**.
- DeepSeek en second illustrateur : une seule mesure.
- Le refus en prose de Haiku pendant une reprise : cause non établie (la consigne de
  défaut transmise n'a pas été relue).

## 7. Mise en production (29/10, sur décision de Jocelyn)

1. Lecteur sur `main` d'abord (`a3bfbc0`), vérifié sur Netlify : sans lui, les
   téléphones n'auraient pas su jouer les équations.
2. Génération v72 (chimie exacte), puis v73 (chaîne allumée par défaut).
3. **Le secret qui devait l'allumer n'a jamais atteint les fonctions** : trois relevés
   `capsule_chaine_present: false`, dont un sur une fonction redéployée APRÈS la pose.
   Le sens a donc été inversé : la chaîne tourne par défaut, **`CAPSULE_CHAINE=0` la
   coupe**, sans redéploiement. Un interrupteur dont l'absence prive les étudiants de
   la fonction est fragile ; un interrupteur de panne ne l'est pas.
4. Contrôle sans commande d'étudiant : `whiteboard-storyboard-smoke`
   `{"engine":"etat"}` dit si un secret coupe la chaîne, jamais sa valeur.

## 8. L'ambiance de la capsule (29/10, soir — écrite, non en ligne)

Demande de Jocelyn : « on n'est pas obligé de choisir le décor bleu ». Une **ambiance**
par capsule, choisie par le **scénariste** d'après la matière, nettoyée par le code :

| ambiance | couleur | lointain | matières |
|---|---|---|---|
| `nuit` | bleu d'origine | aucun | corps humain, santé, technologie |
| `savane` | ambre du soir | baobabs, soleil couchant | histoire, géographie, société, Afrique |
| `foret` | vert | lisière de conifères | le vivant, l'agriculture |
| `cosmos` | violet | étoiles, planète | physique, chimie, astronomie |
| `ardoise` | gris craie | aucun | mathématiques, langues |

- **Valeur couplée** : `AMBIANCES` de `validate_capsule.ts`, l'invite du scénariste, et
  `AMBIANCES` de `lecteur.js`. `validate_capsule_ambiance_test.ts` compare les trois.
- **Dégradation** : absente → `nuit` en silence ; inconnue → `nuit`, nommée dans
  `corrections`. Un lecteur ancien ignore le champ et joue `nuit`.
- **Mesuré** (fonction d'essai v11) : 5 sujets, 5 ambiances attendues. Planche des
  capsules réelles : `captures_ambiances_2026-10-29/planche_capsules_reelles.jpg`.
- **Écarté** : `papier` (fond clair) — le halo additif s'inverse en taches ; le
  lointain en 3D — traits parasites dès que la caméra plonge ; le vert « protégé »
  dans la passe — mesuré sans effet, le halo le délave déjà en `nuit`.
- **Ordre de mise en ligne** : lecteur sur `main` d'abord, génération ensuite.
