# Studio 3D — faire FABRIQUER la scène par l'IA : état de l'art et conception

**Date : 11/08/2026.** Recherche préalable, demandée avant toute écriture de code.
Suite et conception : `STUDIO_3D_CONCEPTION_SCENE_PAR_SUJET_2026-08-11.md`.
**Décision de Jocelyn : voie (c) uniquement.** Ni (a) images génératives, ni (b)
étiquettes posées sur des formes existantes en repêchage.

---

## 1. Le défaut qu'on cherche à corriger

Mesuré le 07/08 sur deux capsules réelles produites de bout en bout :

| Sujet | Enchaînement des formes |
|---|---|
| « la sociologie » | reseau → strates → comparaison → flux → comparaison |
| « la germination » | reseau → strates → comparaison → flux → comparaison |

Deux sujets sans rapport, la **même vidéo**. La cause est dans le catalogue
lui-même : sur les onze archétypes de `generateur_scenes.py`, huit n'acceptent
que des **réglages numériques** — `noeuds`, `couches`, `rayon`, `points`,
`cercles`, `ondes`, `tours`, `écart`. Un nombre de nœuds ne dit rien de la
sociologie. Trois seuls laissent passer du sens : `titre` (texte),
`silhouette` (SVG), `chronologie` (jalons rendus en `texte_3d`,
`generateur_scenes.py:514`).

Autrement dit : le modèle *choisit* aujourd'hui dans une bibliothèque de formes
muettes. Tant qu'il choisit, il ne peut pas parler du sujet.

---

## 2. Ce que fait la recherche (2024 → 2026)

### 2.1 La voie (c) est la voie principale du domaine

Tous les systèmes qui produisent des scènes 3D à partir d'un texte génèrent du
**code Blender (bpy)**, pas des paramètres :

| Système | Date | Ce qu'il produit |
|---|---|---|
| **SceneCraft** (Hu et al., ICML 2024) | 03/2024 | script Python Blender, via un graphe de scène intermédiaire |
| **BlenderLLM** (FreedomIntelligence) | 12/2024 | bpy, modèle affiné sur BlendNet (8 000 paires instruction → script) |
| **BlenderGym** (CVPR 2025) | 04/2025 | *banc d'essai* de l'édition graphique par VLM |
| **LL3M** | 08/2025 | bpy, équipe d'agents planifier/récupérer/écrire/déboguer/raffiner |
| **Planner-Actor-Critic** | 01/2026 | bpy, boucle critique |
| **3DCodeBench** | 06/2026 | *banc d'essai*, 12 VLM avancés |
| **SimWorlds** | 07/2026 | bpy **animé**, multi-agents |

La demande n'a donc rien d'exotique. C'est la direction du domaine.

### 2.2 Mais **personne** ne laisse le modèle écrire du bpy depuis une page blanche

C'est le point que je n'attendais pas, et c'est le plus utile. Chaque système
qui fonctionne interpose une couche entre le modèle et l'API Blender :

- **SceneCraft** apprend une *bibliothèque de compétences* : les fonctions
  utiles sont compilées et réutilisées d'une requête à l'autre — « library
  learning mechanism […] compiles common script functions into a reusable
  library ». Gain mesuré : **+45,1 % et +40,9 % de score CLIP** contre
  BlenderGPT (qui, lui, écrit du bpy brut).
- **LL3M** interpose **BlenderRAG**, une base de la documentation de l'API qui
  fournit à l'agent « examples, types, and functions » — pour la *correction du
  code* autant que pour la richesse.
- **BlenderLLM** interpose un **affinage** sur 8 000 exemples.

Trois équipes, trois moyens, une même conclusion : le bpy nu est trop large.
La version naïve de (c) est précisément la version qui échoue.

### 2.3 L'échec est la norme, et il est chiffré

- **3DCodeBench** (06/2026, 12 VLM) : les échecs viennent surtout de
  **discordances d'API** ; et *même les rendus réussis* présentent des
  **composants géométriques détachés ou flottants**.
- **BlenderGym** (CVPR 2025) : « even the state-of-the-art VLM system struggles
  with tasks relatively easy for human Blender users ».
- Sur l'édition de **géométrie**, tous les VLM ouverts sauf un **n'arrivent pas
  à produire un script exécutable sur plus de 75 % des cas**.
- La boucle de critique **plafonne vers la 3ᵉ itération** : au-delà, « the
  modeling quality degrades or converge » — et l'exécutant n'intègre pas
  toujours la remarque du critique.

### 2.4 L'avertissement qui nous vise directement

> « The code execution approach often relies on modeling with primitives, which
> limits expressiveness. »

Un modèle qui écrit du bpy libre retombe sur des **cubes, sphères et cylindres**.
Il faut le dire franchement : la voie (c) mal conduite ne donne pas des visuels
supérieurs aux nôtres — elle donne des **primitives flottantes**, donc *moins
bien* que nos onze archétypes, qui sont au moins soignés et éclairés.

Et le point faible désigné par les bancs d'essai — les **geometry nodes** et les
**nœuds de shader** — est exactement là où vit la richesse visuelle.

### 2.5 Sécurité : ce n'est pas un détail de fin de page

Exécuter du Python écrit par un modèle sur le pod GPU, c'est de l'**exécution de
code arbitraire** sur une machine qui détient notre clé de service Supabase. La
réponse du domaine est constante : isolation de classe gVisor ou conteneur,
**pas de réseau**, système de fichiers réduit, budget CPU/mémoire, processus
**éphémère détruit après usage**.

---

## 3. Conception retenue

### 3.1 Le principe

> **L'IA écrit du code — mais contre NOTRE API, pas contre `bpy`.**

C'est ce que sont, au fond, la bibliothèque de compétences de SceneCraft et le
BlenderRAG de LL3M. Un module `academia3d` expose des **verbes composables**,
et le modèle écrit un programme court qui les compose librement :

```python
# ce que le modèle écrirait pour « la germination »
graine  = masse("ovoide", echelle=0.6, matiere=terre())
enveloppe = coque_autour(graine, epaisseur=0.08, matiere=verre_teinte())
revele(enveloppe, a=0.0, duree=1.4)
fissure(enveloppe, a=2.1, depuis=direction(0, 0, -1))
radicule = tige(depuis=graine, vers=bas(1.8), courbure=0.3, matiere=vivant())
croissance(radicule, a=2.4, duree=3.2, sens="racine")
tigelle  = tige(depuis=graine, vers=haut(2.4), courbure=-0.15, matiere=vivant())
croissance(tigelle, a=3.8, duree=4.0)
cotyledons(tigelle, nombre=2, a=7.2, ouverture=1.1)
lumiere_rasante(azimut=35, chaleur=0.7)
camera_suit(tigelle, marge=1.3, mouvement="montee_lente")
```

Le modèle **invente la forme** : rien ici n'existait avant qu'il l'écrive. Il n'y
a pas de « germination » au catalogue. Mais il ne peut pas écrire `import os`,
ni appeler une API Blender qui n'existe pas — la classe d'échec n°1 mesurée par
3DCodeBench disparaît par construction.

**En quoi ce n'est pas (b).** Dans (b), la forme préexistait et on lui collait
une étiquette. Ici, **il n'y a aucune forme avant que le modèle l'écrive**. Ce
qui préexiste, c'est un vocabulaire de gestes — comme une langue préexiste aux
phrases qu'on y écrit.

### 3.2 Les trois pièces obligatoires

1. **La geôle d'exécution.** Le pod détient la clé de service : pas de réseau
   depuis le processus de scène, pas d'écriture hors du dossier du travail,
   liste blanche d'imports, borne de temps et de mémoire, processus jeté après
   la scène.

2. **La boucle de réparation.** Le code s'exécute ou non. S'il échoue, la trace
   d'erreur repart au modèle. **Deux tentatives, trois au maximum** : la
   recherche est nette, la quatrième n'achète rien. Au-delà, on tombe sur
   l'archétype le plus proche *et on le journalise comme un échec*, sans le
   présenter comme un succès.

3. **Le critique qui REGARDE.** Rendre **une image à la seconde 2 de chaque
   scène**, la faire lire par un VLM : est-ce noir, est-ce vide, est-ce hors
   sujet ? Ce n'est pas un luxe. Le septième défaut du 05/08 était une vidéo
   **noire et muette livrée à un étudiant comme « prête »**. Du code écrit par
   un modèle échouera de façons que nous n'avons pas prévues ; la seule défense
   qui généralise, c'est de regarder l'image.
   **Coût mesuré : négligeable.** Une image = 2,04 s ; six scènes = ~12 s sur
   une capsule de 75 à 82 minutes.

### 3.3 Où tourne quoi

| Étape | Où | Pourquoi |
|---|---|---|
| écriture du programme de scène | Edge Function | §5.2 de CLAUDE.md : aucun calcul d'IA sur nos machines |
| réparation (≤ 3 tours) | Edge Function | quelques secondes, **hors** du chemin GPU |
| exécution + rendu | pod GPU, en geôle | seul endroit qui a Blender et la carte |
| lecture de l'image témoin | Edge Function | le pod n'appelle pas de modèle |

La latence ajoutée au parcours étudiant se compte en **secondes**, à la
génération du storyboard. Elle ne touche pas les 75–82 minutes de rendu.

---

## 4. Ce que ça coûte, dit franchement

- Cela **remplace** les onze archétypes de `generateur_scenes.py`. Ce n'est pas
  une retouche, c'est le cœur du moteur de scène.
- Le risque d'obtenir d'abord **moins bien** qu'aujourd'hui est réel et mesuré
  par trois bancs d'essai indépendants (§2.3, §2.4).
- Donc : **on ne débranche pas l'existant.** On fait tourner les deux sur le
  **même sujet**, côte à côte, et la nouvelle voie ne prend la place que le jour
  où elle gagne à l'écran. C'est la seule manière de ne pas remplacer un défaut
  connu par un défaut inconnu.

---

## 5. Ce qui manque encore, et que la recherche ne donnera pas

La vidéo de référence. Elle ne change **rien** à l'architecture ci-dessus — elle
fixe le **contrat de style**, qui est l'autre moitié du travail :

- la palette et la température de lumière ;
- la grammaire de caméra (quels mouvements, à quelle vitesse, jamais lesquels) ;
- la typographie 3D et son entrée à l'écran ;
- le rythme : durée d'un plan, moment de la coupe, respiration entre deux idées.

Ce contrat devient à la fois l'invite système du modèle et les **valeurs par
défaut de `academia3d`** — pour que la liberté d'invention porte sur *ce qui est
montré*, jamais sur *la manière dont c'est éclairé et cadré*. C'est ainsi que
les capsules se ressembleront d'un épisode à l'autre tout en parlant chacune de
son sujet.

Je ne peux pas écrire le vocabulaire des verbes avant d'avoir vu cette
référence : ce sont les gestes de la vidéo modèle qui déterminent quels verbes
existent.

---

## Sources

- SceneCraft: An LLM Agent for Synthesizing 3D Scene as Blender Code — ICML 2024 — https://arxiv.org/abs/2403.01248
- BlenderLLM: Training LLMs for Computer-Aided Design with Self-improvement — 12/2024 — https://huggingface.co/papers/2412.14203 · https://github.com/FreedomIntelligence/BlenderLLM
- BlenderGym: Benchmarking Foundational Model Systems for Graphics Editing — CVPR 2025 — https://arxiv.org/abs/2504.01786
- LL3M: Large Language 3D Modelers — 08/2025 — https://arxiv.org/abs/2508.08228
- From Idea to Co-Creation: A Planner-Actor-Critic Framework for Agent Augmented 3D Modeling — 01/2026 — https://arxiv.org/pdf/2601.05016
- 3DCodeBench: Benchmarking Agentic Procedural 3D Modeling Via Code — 06/2026 — https://arxiv.org/abs/2606.01057
- SimWorlds: A Multi-Agent System for Dynamic 3D Scene Creation — 07/2026 — https://arxiv.org/pdf/2607.01766
- SandboxEval: Towards Securing Test Environment for Untrusted Code — https://arxiv.org/pdf/2504.00018
