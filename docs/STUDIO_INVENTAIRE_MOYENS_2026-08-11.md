# Inventaire des moyens du Studio — relevé mesuré du 11/08/2026

**Pourquoi ce document.** Les conclusions du 11/08 sur la scène 3D par sujet
(`STUDIO_3D_CONCEPTION_SCENE_PAR_SUJET_2026-08-11.md`) reposaient sur un état
d'infrastructure **supposé**, hérité de sessions passées. Jocelyn a demandé si le tour
avait été fait. Il ne l'avait pas été. Voici le relevé, fait à la commande.

Tout ce qui suit est **mesuré aujourd'hui**, sauf mention contraire explicite.

---

## 1. LWS — `lws-nexiom` (31.207.38.60)

| Poste | Valeur mesurée |
|---|---|
| CPU | **4 vCPU** |
| Mémoire | **8 Go** (7 libres) |
| Disque | 147 Go, **136 Go libres** (8 % utilisés) |
| GPU | **aucun** |

**Services actifs (4) :**
`studio-amorceur` · `studio-preparateur` · `whiteboard-worker` · `video-worker`

**Outils installés :**

| Outil | État |
|---|---|
| python3 | 3.12.3 |
| ffmpeg | 6.1.1 |
| node | v20.20.2 |
| git | 2.43.0 |
| **docker** | **29.6.2** ← non exploité |
| blender | **ABSENT** |
| deno | **ABSENT** |

**Conséquences immédiates :**

1. **Docker est installé et inutilisé, avec 136 Go libres.** C'est le moyen de
   fabriquer nous-mêmes l'image des pods (voir §2). Il était sous nos yeux.
2. **Deno est absent** : la tâche marquée « première chose à faire » dans CLAUDE.md
   (`deno test validate_test.ts`) **ne peut pas non plus être exécutée sur LWS**. Elle
   attend toujours une machine qui en dispose.
3. `/opt/whiteboard-engine-remotion` occupe la machine — moteur abandonné, cf. CLAUDE.md §10.

---

## 2. RunPod — le coût fixe réel, bien supérieur à ce qui était retenu

Image de base : `runpod/pytorch:1.0.2-cu1281-torch280-ubuntu2404`
Machine : `NVIDIA A40`, `volumeInGb: 20`, `containerDiskInGb: 30`

### Ce qui se passe à CHAQUE location

| Étape | Durée | Source |
|---|---|---|
| démarrage du pod jusqu'à sshd | **3 min 25** (médiane sur 10 amorçages, 07/08) | mesure antérieure |
| `apt-get` + `pip install diffusers transformers accelerate…` + téléchargement et extraction de Blender | **~15 min** | `install_pod.sh:17`, écrit dans notre propre code |
| re-téléchargement du modèle HuggingFace | **~10 min** | `studio_amorceur.py:209` |
| compilation des shaders EEVEE (1ʳᵉ image) | **31 s** | mesure antérieure |

> **Le coût fixe par machine n'est donc pas 3 min 25. Il approche la demi-heure.**
> Tout mon raisonnement de latence de ce matin était bâti sur le seul chiffre du
> démarrage. Il est faux à la baisse, et il l'est massivement.

### Ce que notre propre code dit déjà

`install_pod.sh` ligne 17, mot pour mot :

> « Ce script est donc la base de l'image Docker de la phase 4 du cahier des charges.
> Tant qu'elle n'existe pas, il faut le rejouer à chaque location — compter ~15 minutes. »

L'image Docker est un **chantier connu, écrit, jamais fait**. RunPod accepte les images
personnalisées via `imageName` — c'est déjà le paramètre que passe
`studio-orchestrateur` (ligne 55). Le remplacer par notre image supprime les ~15 min,
sans changer une ligne d'architecture.

Pour le modèle HF, RunPod documente le **volume réseau** : montage persistant partagé
entre pods, ~60 % de gain sur le temps de chargement des poids. Aujourd'hui `HF_HOME`
pointe sur le disque conteneur **éphémère** — choix délibéré du 06/08, parce que le
volume de 20 Go était plein aux trois quarts par le cache lui-même.

### Deux chemins d'installation divergents

- `install_pod.sh` installe **ComfyUI** (clone + `requirements.txt`).
- Le script en ligne de `studio_amorceur.py:156` installe **seulement** `diffusers
  transformers accelerate protobuf sentencepiece ftfy`, **sans ComfyUI**.

C'est celui de l'amorceur qui tourne en production. `install_pod.sh` n'est plus la
vérité. Deux sources d'installation qui divergent, c'est une panne en attente.

---

## 3. Supabase — `thevdfcwlcqzdoybfvgs`

**70+ Edge Functions.** Celles qui touchent le Studio :

| Fonction | Rôle |
|---|---|
| `studio-orchestrateur` | loue les machines (déployée v6 le 07/08) |
| `studio-jeton-huggingface` | le pod obtient le jeton HF contre son propre jeton |
| `runpod-pod`, `runpod-watchdog` | le veilleur |
| `whiteboard-generate-storyboard` | génération du script par l'IA |
| `whiteboard-tts` | la voix |
| `assemble-video-chunks`, `merge-video-segments`, `transcode-video`, `compress-video`, `transcode-multi-resolution`, `content-watermark` | **chaîne vidéo déjà en place, non utilisée par le Studio 3D** |

**Migrations du Studio :** `20260730_studio_visuel_file_de_travaux`,
`20260730_veilleur_gpu_decouverte`, `20260730_veilleur_pods_gpu`,
`20260730_agent_pod_battement_authentifie`, `20260731_studio_orchestrateur`,
`20260807120000_studio_travail_etudiant`.

### 3.1 Deux connecteurs Supabase, pas un — et j'avais raté le second

| Connecteur | Source | État | Écriture |
|---|---|---|---|
| `supabase-lecture` | `.mcp.json` du dépôt | **ne démarre pas** — `SUPABASE_ACCESS_TOKEN` absent | interdite (`--read-only`) |
| connecteur claude.ai | compte de Jocelyn | **fonctionne** | **POSSIBLE** — `execute_sql`, `apply_migration`, `deploy_edge_function` |

J'ai annoncé « je n'ai pas pu interroger la base » **sans avoir essayé le second**.
Il était listé dès le début de la session. C'est la faute que `etat-des-moyens` est
censée empêcher, commise le jour même où je l'écrivais.

> **Attention permanente** : le connecteur claude.ai n'est **pas** en lecture seule.
> Il peut écrire en production, appliquer une migration et déployer une Edge Function.
> Les interdits du §11 de CLAUDE.md s'appliquent par **discipline**, plus par
> contrainte technique. C'est précisément pourquoi `.mcp.json` déclare l'autre avec
> `--read-only` : les deux ne se remplacent pas.

### 3.2 Mesures faites sur la base vivante (11/08)

**Travaux 3D — 13 au total, 8 aboutis (62 %).**

| Sujet | avant démarrage | rendu | total | images |
|---|---|---|---|---|
| la photosynthèse | 24,9 min | 57,3 min | **82,2 min** | 2486 / 2486 |
| la sociologie | 40,8 min | 77,4 min | **118,2 min** | 2224 / 2224 |
| la germination | 7,3 min | 81,7 min | **89,0 min** | 2375 / 2375 |
| l'eau dans un arbre | 4,7 min | 42,8 min | **47,5 min** | 1052 / 1052 |
| l'univers | 43,8 min | 23,5 min | 67,2 min | **908 / 1924 — incomplet** |
| « le ventilo » ×2 | — | — | archivés | **jamais eu de machine** |
| ESSAI 3D marketing | — | 309 min | archivé | **0 image, 5 h d'attente pour rien** |

Vitesse de rendu réelle : **1,38 à 2,44 s/image**. Capsules de **1050 à 2490 images**,
soit 42 à 100 s de vidéo à 25 i/s.

**Machines — 14 pods, tous A40 à 0,44 $/h.**

- **Amorçage médian : 5,0 min** (min 2,9 — max 9,2), mesuré sur `amorce_at - created_at`.
- 3 pods tués en `agent_muet` le 05/08 (15–20 min chacun) — l'agent meurt avant son
  premier battement.
- 4 pods allés jusqu'à `duree_maximale_depassee` (183 à 242 min), 1,35 à 1,77 $ pièce.
- **Coût total de toute l'expérimentation 3D : environ 8 $.** Le coût n'a jamais été
  le problème.

### 3.3 Correction : je me suis trompé DEUX FOIS sur le coût fixe

| Moment | Chiffre annoncé | Fondement |
|---|---|---|
| matin | 3 min 25 | démarrage seul, mesure partielle |
| après-midi | ~30 min | `install_pod.sh` (~15 min) + modèle (~10 min) — **mais `install_pod.sh` n'est pas ce qui tourne** |
| **mesure** | **5,0 min (médiane, 12 pods)** | `app.gpu_pods.amorce_at - created_at` |

La sur-correction était aussi fausse que la sous-estimation. Le script en ligne de
`studio_amorceur.py` est plus léger qu'`install_pod.sh`, et le modèle HuggingFace se
télécharge **paresseusement**, à la première scène `genere` — pas à l'amorçage.

**Leçon** : corriger un chiffre supposé par un autre chiffre supposé ne corrige rien.

### 3.4 Ce que l'arithmétique dit, maintenant qu'elle est mesurée

Temps mural d'un rendu découpé sur N machines : `T/N + F`, avec
**T ≈ 83 min** (2500 images à 2 s) et **F ≈ 5,5 min** (amorçage + shaders).

| N machines | temps mural |
|---|---|
| 1 | 88 min |
| 12 | **12,4 min** |
| 20 | 9,7 min |
| ∞ | **5,5 min — le plancher, c'est F** |

> **P95 < 5 min est hors d'atteinte même avec une infinité de machines**, tant que
> F vaut 5,5 min. L'image Docker (F → ~2 min) ne suffit pas non plus seule :
> il faudrait ~28 machines ET l'image pour approcher 5 minutes.

Cela ferme une question qui trainait : le découpage multi-machines n'amène pas à
5 minutes. Soit on abaisse F **et** on réduit le nombre d'images, soit on change de
moteur de rendu. C'est une arithmétique, pas une opinion.

---

## 4. Ce que le dépôt contient déjà et que j'avais manqué

### 4.1 Une banque de référents existe — cinq formes

`studio_visuel/contours/` : `amphore.svg`, `coeur.svg`, `feuille.svg`, `goutte.svg`,
`spirale.svg`, plus `fabriquer_contours.py`.

C'est l'embryon exact de `convoquer`. L'archétype `silhouette` les consomme, et
`studio_amorceur.py:116` les dépose sur chaque pod — « sans eux, `silhouette` retombe
sur son texte de secours et la capsule perd le sujet qu'elle devait montrer ».

### 4.2 Et une DOCTRINE explicite, qui contredit ma recommandation CC0

`fabriquer_contours.py`, en entête :

> « Un contour récupéré sur internet arrive avec sa licence, son auteur, et le doute qui
> va avec. Pour une plateforme commerciale, chaque fichier devrait être tracé, vérifié,
> renouvelé. Ceux-ci sont générés par des équations : ils nous appartiennent sans
> discussion, ils sont déterministes, et ils pèsent quelques kilo-octets. »

J'ai recommandé ce matin une banque CC0 (Poly Haven, Kenney, Quaternius) sans savoir que
la question avait déjà été tranchée dans l'autre sens, et avec un motif.

**Arbitrage.** Le CC0 répond à l'objection de licence — pas d'auteur, pas d'attribution,
pas de renouvellement — mais pas à celle de la **traçabilité** : il faut quand même
vérifier que chaque fichier est bien CC0 à la source. La doctrine « généré par
équations » garde donc sa valeur pour les formes **géométriques** (goutte, spirale,
onde, amphore). Elle atteint sa limite exactement là où la référence commence : **on ne
génère pas un corps humain allongé avec une équation.** Les deux voies coexistent ; ce
n'est pas l'une contre l'autre.

### 4.3 `genere` visait déjà EXACTEMENT ta référence

`capsules/chaleur_corps.json`, scène d'accroche, `archetype: "genere"`, invite :

> `holographic wireframe human body seen from the side, glowing red hot core inside the
> chest, blue wireframe skin`

C'est mot pour mot ta première image. Le Studio avait donc déjà une réponse au problème
« montrer le sujet » : **la diffusion d'images**, avec un mouvement de caméra
(`mode: mouvement`, `sens: zoom`). C'est la voie (a). Jocelyn l'a refusée.

Modèle utilisé : `shuttleai/shuttle-3-diffusion` (`generateur_ia.py:43`).
Cause d'échec établie le 06/08 : quota du volume, correctif **non vérifié sur GPU**.

### 4.4 Une capacité image→vidéo est déjà câblée

`generateur_ia.py:226` : `AutoencoderKLWan`, `WanImageToVideoPipeline`.
Le Studio sait, en principe, animer une image fixe par un modèle vidéo. Non mesuré,
non vérifié, jamais mentionné dans mes conclusions de ce matin.

---

## 5. Ce que le relevé change dans les conclusions du matin

| Conclusion du matin | Après relevé |
|---|---|
| « le coût fixe par machine est de 3 min 25 » | **Faux à la baisse.** ≈ 30 min avec installation et modèle. Le calcul `T/N + F` change de nature. |
| « la banque viendra du CC0 » | À arbitrer contre une **doctrine existante** (§4.2), pas à imposer. |
| « le trou, c'est l'objet du sujet » | Exact — mais le projet avait **déjà** une réponse (`genere`), refusée par Jocelyn. Il faut le dire. |
| — | **Docker sur LWS, 136 Go libres, inutilisé.** L'image de pod est écrite comme TODO dans notre propre code. |
| — | **Chaîne vidéo Supabase complète** (assemble, merge, transcode, compress, watermark) que le Studio 3D n'utilise pas. |
| — | **Wan image→vidéo déjà câblé**, jamais évalué. |

---

## 6. Ce qui reste NON mesuré, et qu'il ne faut pas supposer

1. **L'état vivant de la base** — connecteur MCP tombé. Nombre de travaux, durées
   réelles, pods actifs : inconnus aujourd'hui.
2. **Le compte RunPod** — la clé est chez Supabase, pas ici. Types de GPU réellement
   disponibles, tarifs du jour, quotas : non vérifiés.
3. **Le coût de rendu des verbes volumétriques** sur A40. `banc_rendu.py` existe et
   n'a pas été rejoué.
4. **Le gain réel d'une image Docker maison** — estimé à ~15 min par machine d'après
   notre propre commentaire, jamais chronométré.
5. **Wan image→vidéo** — présent dans le code, jamais exécuté à ma connaissance.
6. **La comparaison externe des plateformes** reste incomplète : je n'ai pas évalué
   sérieusement la voie « modèle vidéo génératif » ni la voie « moteur temps réel »
   (Three.js / Remotion), alors que l'esthétique de la référence — filaire, émissif,
   brouillard, bloom — est typiquement du temps réel, et que
   `/opt/whiteboard-engine-remotion` montre qu'on a déjà tenté cette famille.

---

## 7. Ce qui devient prioritaire, et qui n'était pas dans le plan du matin

**L'image Docker du pod.** Elle ne demande aucune recherche, elle est déjà écrite comme
travail à faire dans `install_pod.sh`, Docker est installé sur LWS avec 136 Go libres,
et `studio-orchestrateur` passe déjà `imageName` en paramètre. Gain estimé : **~15 min
par machine**, sur un coût fixe qui borne toute stratégie de découpage — puisque le
temps mural d'un rendu découpé sur N machines vaut `T/N + F`, et qu'aucun N ne descend
sous `F`.

C'est le seul poste identifié aujourd'hui qui attaque directement le grief principal de
Jocelyn — « c'est impossible d'attendre cinq minutes » — sans rien changer à
l'architecture.
