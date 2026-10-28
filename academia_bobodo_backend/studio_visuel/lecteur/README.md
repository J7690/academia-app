# Le lecteur de capsule — lot 1 (28/10/2026)

La capsule est **jouée** par l'appareil, et non plus filmée sur un serveur
GPU. Conception : `docs/STUDIO_ARCHITECTURE_LECTURE_APPAREIL_2026-10-28.md`.
Le prototype qui l'a prouvée : `../prototype_lecture_appareil/`.

| Fichier | Rôle |
|---|---|
| `lecteur.js` | le moteur : normalisation v0/v1/v2, les 7 verbes, les décors corps et gouttes, le foyer, les paliers, les sous-titres et l'attribution dans l'image |
| `index.html` | la page : lecture (l'horloge est la voix), bascule de palier, export MP4 de 10 s, vérification d'une capsule ou d'un lot |
| `FORMAT_CAPSULE_V2.md` | le format accepté |
| `assets/corps.json` | corps MakeHuman, **CC0 1.0**, 2 975 triangles |
| `exemple/` | « le cerveau » en v2 : narration et durées réelles (`168ccb14`), décors choisis à la main |
| `vendor/three/` | three.js 0.178.0, **MIT** (LICENSE inclus) : modules utilisés seulement |
| `vendor/mediabunny/` | Mediabunny 1.61.3, **MPL-2.0** (LICENSE inclus), chargé seulement à l'export |
| `vendor/poppins/` | Poppins 600 latin, **OFL 1.1** (OFL.txt inclus) |

**Aucun appel réseau tiers**, sauf pour `convoquer` sans objets résolus : le
lecteur va alors chercher le modèle sur HuggingFace (Objaverse), comme le pod.
En production, c'est au serveur de fournir `objets`.

**Fusion, pas réécriture** : les verbes reprennent les paramètres, les
proportions et la convention d'axes de `../web/academia3d_web.js`. Le cadrage
par intention est porté tel quel. Le moteur du pod n'est pas touché.

## Servir en local

Le lecteur s'ouvre depuis `studio_visuel/` (il lit
`../contours/index_objets.json`) : `http://127.0.0.1:<port>/lecteur/`.

## Lot 2 — la voix par scène, en flux (28/10/2026)

**Côté serveur** : Edge Function `studio-voix` (`supabase/functions/studio-voix/`),
**déployée le 28/10 avec l'accord de Jocelyn** (version 2, `verify_jwt` actif).
Une requête TTS par scène, toutes lancées ensemble ; réponse NDJSON, une
ligne par scène dans l'ordre d'arrivée. Voix déposées sous
`studio-visuel/capsules/voix/<job>/<scène>.mp3` et resservies sans être
refaites. Un étudiant lit sa capsule **avec son propre jeton** (règle d'accès
« l'étudiant lit ses propres travaux ») ; l'appel interne fournit le manifeste.
Tests Deno : `voix_test.ts`, 5/5.

**Côté lecteur** (`?flux=`) : l'appui lance la demande ; la scène 1 se joue
dès que sa voix est décodée ; une scène dont la voix manque attend sur son
début (« voix en préparation… »), jamais muette. Voix ralentie à 0,88 sans
changer de hauteur (`ralentir`, WSOLA : rapport mesuré 0,882), à 24 kHz.

**Mesures réelles** (« le cerveau » `168ccb14`, 5 scènes, 710 caractères) :

| | mesure |
|---|---|
| serveur : voix de la scène 1 prête | **2,52 s** (synthèse 2,19 s) |
| serveur : les 5 voix prêtes | **5,73 s**, 0 échec — contre ≈ 35 s en série sur LWS |
| second appel (voix déjà faites) | **0,13 s**, aucune synthèse |
| lecteur, poste : appui → **première image parlée** | **3,13 s** (vrai flux rejoué, vraies voix téléchargées depuis Supabase) |
| coût de la voix | ≈ 0,011 $ (0,016 $ / 1 000 caractères) |

Chemin vers 3,13 s, mesuré pas à pas : 5,15 s au premier essai → 4,64 s
(traiter la scène 1 avant les autres) → 3,13 s (24 kHz, et ne rien traiter
d'autre tant que l'image attend la scène 1).

**Défauts trouvés et corrigés à l'essai** : le premier appui plantait (contexte
audio absent) ; l'horloge partait de 0, la scène 1 était sautée ; la fonction
lisait la table avec le rôle de service, qui n'en a pas le droit (« permission
denied ») — corrigé par la lecture avec le jeton de l'étudiant, **sans toucher
aux droits de la base**.

**Non mesuré** :
- **la mesure sur le TECNO** : le téléphone n'était plus branché ;
- **le temps de l'IA qui écrit la capsule**, à ajouter avant ces 3,13 s.
  Il est noté « quelques secondes » en juillet et n'a pas été rechronométré ;
- **l'écoute de la voix ralentie par le lecteur**.

## Preuve du lot 1 — les 23 capsules livrées, rejouées (28/10, poste Intel UHD)

Les 23 capsules `preview_ready` de `app.studio_jobs`, extraites en lecture
seule (hors dépôt), passées une à une par `?lot=` : pour chaque scène, trois
images (15 %, 50 %, 85 % du plan), avec la porte du dépôt transposée — un
objet au moins, plus de 0,4 % de pixels allumés, une image qui **bouge**.

| | résultat |
|---|---|
| capsules | **23/23** chargées |
| scènes | **115/115 acceptées, 0 refus** |
| v1 (gestes, 15 capsules) | **73/73**, **aucune dégradation** — y compris `ecrire` (inconnu du moteur du pod) et `convoquer` (volcan, montagne, plante, planète chargés depuis HuggingFace) |
| v0 (archétypes, 8 capsules) | **42/42** en **repli texte**, chacune déclarée « archétype v0 non porté » |
| pixels allumés | min 3,2 %, médiane 21,6 % |

**Vu à l'image**, pas seulement compté :
- le volcan convoqué est lisible en arêtes : **l'aplat blanc d'ETAT §4.2 bis
  a disparu** ;
- les textes 3D (« ACTIF / ÉTEINT », « 100 m ») s'affichent ;
- l'attribution CC-BY est inscrite dans l'image pendant les scènes concernées.

**Trois défauts trouvés et corrigés à l'essai** :
1. le voile « Chargement… » restait posé (sans `[hidden]{display:none}`,
   `display: grid` l'emportait) ;
2. le texte 3D bavait sous le halo, illisible de près ;
3. les dégradations de la capsule n'étaient affichées nulle part.

**Non fait, et dit** :
- **les archétypes v0 ne sont pas portés**. Ces 8 capsules sont antérieures
  au 12/08 et se rejouent en texte : les réécrire en gestes coûterait plus
  que de les refabriquer ;
- **le lecteur n'a pas encore été mesuré sur le TECNO** : seul le prototype
  l'a été. Ce sera fait au lot 4, dans l'application ;
- `convoquer` va encore chercher les modèles sur HuggingFace à la lecture.
  En production, le serveur devra fournir `objets` (lot 3).
