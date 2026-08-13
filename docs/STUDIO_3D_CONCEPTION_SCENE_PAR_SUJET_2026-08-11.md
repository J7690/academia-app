# Studio 3D — la scène en fonction du sujet : conception

**Date : 11/08/2026.** Fait suite à `STUDIO_3D_RECHERCHE_SCENE_GENEREE_2026-08-11.md`
(état de l'art) et à la vidéo de référence fournie par Jocelyn (TikTok @matholic.ch,
deux images analysées).

**Exigence** : « les images, les animés, les scènes, les lumières doivent être en
rapport avec le sujet abordé […] pas de forme préenregistrée qui serait utilisée à
tous les cours ». Voie (c) : l'IA **fabrique** la scène.

---

## 1. La grammaire de la référence, élément par élément

| # | Élément observé | Rôle |
|---|---|---|
| 1 | Filaire bleu émissif, arêtes triangulées | la structure, le connu |
| 2 | Sommets visibles comme des points lumineux | densité, lecture « donnée » |
| 3 | Surface translucide qui s'allume en incidence rasante | le volume sans masquer l'intérieur |
| 4 | Masse volumétrique rouge-orange incandescente | l'énergie, le phénomène expliqué |
| 5 | Brouillard volumétrique bleu en bandes ondulantes | profondeur, jamais de fond plat |
| 6 | Bloom / halo sur les émissifs | le « premium » |
| 7 | Flou de profondeur de champ marqué | cinéma plutôt que schéma |
| 8 | Particules chaudes qui se dispersent | le mouvement de l'énergie |
| 9 | Terrain en grille jusqu'à l'horizon, lueur affleurante | l'échelle et l'horizon |
| 10 | Sous-titres blancs gras incrustés, tiers inférieur | 60–85 % regardent sans le son |

Et par-dessus tout : **les objets sont reconnaissables et liés au sujet** — un corps
humain, un œuf. Jamais des formes abstraites décoratives.

---

## 2. Ce que notre moteur sait déjà faire — et ce qu'il n'utilise pas

`style_reference.py` a été bâti le 30/07 à partir d'une référence de la même famille.
La grammaire est donc **déjà codée**. Vérifié ligne à ligne :

| Élément | Chez nous | Utilisé en production ? |
|---|---|---|
| 1 filaire | `filaire()` — conversion en courbe + biseau, [style_reference.py:42](../academia_bobodo_backend/studio_visuel/style_reference.py) | oui |
| 2 sommets lumineux | — | **absent** |
| 3 translucide Fresnel | `matiere_hologramme()` — [:125] | oui (`titre`, `silhouette`, `chronologie`) |
| 4 masse chaude | `matiere_feu()` — bruit 4D animé, atténuation verticale × radiale, rouge→orange→cœur — [:309] | **NON — appelée seulement dans `essai_style.py:67`** |
| 5 brouillard | `matiere_brume()` — Volume Scatter bleu — [:436] | **NON — appelée seulement dans `essai_style.py:71`** |
| 6 bloom | `compositing()` — Glare FOG_GLOW + exposition −0,6 + AgX — [:456] | oui |
| 7 profondeur de champ | f/2.8 — [generateur_scenes.py:647] | oui |
| 8 particules | archétype `flux` uniquement | partiel |
| 9 terrain en grille | `sol_grille()` — [:240] | oui (4 archétypes) |
| 10 sous-titres | ASS, DejaVu Bold, zone basse protégée — [montage.py:149] | oui |

Format déjà **1080 × 1920 vertical** ([academia_scene.py:187]), palette déjà celle de
la référence : bleu `(0.05, 0.28, 0.95)`, rouge `(1.0, 0.06, 0.01)`, fond quasi noir.

### La trouvaille qui explique la platitude de nos capsules

> **`matiere_feu` et `matiere_brume` ne sont appelées par AUCUN archétype de
> production.** Elles n'existent que dans `essai_style.py`, un fichier d'essai.

Les deux éléments qui donnent à la référence son atmosphère — la masse incandescente
et le brouillard volumétrique — sont écrits, sophistiqués, et **jamais joués**. Le
moteur EEVEE est pourtant déjà réglé à 96 échantillons volumétriques
(`moteur_eevee`, [:499]) : on paie le réglage sans en tirer l'image. C'est une
correction à coût quasi nul et à effet immédiat, indépendante de tout le reste.

---

## 3. Le vrai trou : le sujet

Sur les 10 éléments, 8 sont là. Ce qui manque n'est pas le style, c'est **l'objet dont
on parle**. Aucune fonction du dépôt ne sait convoquer un corps humain ni un œuf.

C'est exactement le défaut mesuré le 07/08 : « la sociologie » et « la germination »
ont produit la même suite de formes, parce que 8 archétypes sur 11 n'acceptent que des
nombres (`noeuds`, `couches`, `rayon`…).

### Le chiffre qui interdit de croire qu'une boucle de correction suffira

3DCodeBench (06/2026) sépare deux mesures. Deux reprises sur erreur font passer
l'**exécutabilité** de 0,702 à 0,974 — **+27,2 points**. Sur la **qualité de forme
conditionnelle** (le résultat ressemble-t-il au sujet, sachant qu'il a tourné), le
gain est de **−0,010**.

> La réparation corrige les plantages, pas le hors-sujet.
> La pertinence ne viendra jamais du *retry* : elle vient du **vocabulaire**.

Corollaire opérationnel : **ne pas investir dans la boucle de réparation avant d'avoir
investi dans les verbes et la banque de référents.**

---

## 4. Le contrat : deux étages, et la génération de code hors du chemin étudiant

### L'arithmétique qui tranche

| Source | Coût mesuré |
|---|---|
| LL3M (08/2025) | ~4 min de création + ~6 min d'auto-raffinement **pour un seul objet** |
| 3DCodeBench (06/2026) | budget de **240 s par script**, au-delà `ERR_TIMEOUT` |
| SimWorlds (07/2026) | jusqu'à 10 reprises + 5 replanifications **par étape** |
| Notre cible | **P95 < 5 min de bout en bout**, pour 5–6 scènes |

Faire écrire le code pendant que l'étudiant attend est **arithmétiquement impossible**.

### Étage 1 — INTENTION, à chaque demande, en secondes

JSON contraint par schéma. Ne porte que des **choix fermés** : pour chaque scène, le
ou les référents du sujet, le rôle de chaque objet (structure / énergie / atmosphère),
le plan de caméra, la narration, le sous-titre.

Précaution mesurée : faire raisonner le modèle **en langue naturelle d'abord, formater
ensuite**. La contrainte de format dégrade le raisonnement — GSM8K passe de 76,6 % à
49,3 % en mode JSON forcé (arXiv 2408.02442). L'adhérence au schéma, elle, est quasi
parfaite en décodage contraint (100 % contre < 40 %).

Cet étage **ne doit jamais échouer** : s'il échoue, l'étudiant a quand même son cours
avec l'archétype de repli. (Contrainte §5.3 : on nettoie, on ne rejette pas.)

### Étage 2 — FABRICATION, hors ligne, une fois par famille de sujet

Python restreint contre `academia3d`, écrit dans un atelier asynchrone, relu, puis figé
en **recette paramétrable et mise en cache**. C'est la boucle **externe** de SceneCraft
(*library learning* : 20 exemples d'apprentissage, puis généralisation), pas sa boucle
interne.

Contrat d'écriture repris de 3DCodeBench et resserré :
- code source pur, sans balises ;
- liste blanche d'imports `{math, random, itertools, functools, dataclasses, typing, mathutils, academia3d}` ;
- **`bpy` interdit en direct** — c'est le sens même de la façade ;
- aucun accès réseau, fichier, ou GUI ;
- 3 tentatives au maximum (1 + 2 reprises) — deux tours captent 76–95 % des gains
  atteignables (arXiv 2604.10508) ;
- **arrêt immédiat si la signature d'erreur se répète** (type + verbe + ligne
  normalisée + message sans adresses mémoire).

---

## 5. Le vocabulaire `academia3d` — 17 verbes, dont 4 seulement sont neufs

`academia3d` n'est **pas un nouveau moteur** : c'est une façade nommée au-dessus de
`style_reference.py`. C'est un chantier d'exposition, pas de réécriture.

**A. SUJET — ce qui manque, et qui porte toute la pertinence**
- `convoquer(referent, pose, echelle, position)` → charge un maillage reconnaissable
  depuis la banque **← NEUF**
- `sculpter(base, deformations, facettes)` → fabrique un volume quand la banque n'a
  rien (ovoïde, tore, capsule, lobe, tige) **← NEUF**
- `essaimer(objet, nombre, etendue, echelles, profondeurs, graine)` → les œufs de
  l'image 2 **← NEUF**

**B. STRUCTURE** — `filairer` (+ sommets), `vitrer`, `napper`
**C. ÉNERGIE** — `incandescer`, `emettre_particules`, `affleurer` (la lueur sous la
résille, motif signature de l'image 2) **← NEUF**
**D. ATMOSPHÈRE ET CAMÉRA** — `embrumer`, `nuiter`, `cadrer`, `haloter`
**E. TEMPS ET TEXTE** — `apparaitre`, `pulser`, `deriver`, `sous_titrer`

### Test d'acceptation du vocabulaire

Les deux images de référence doivent se composer avec ces verbes, sinon le vocabulaire
est faux. Vérifié à la main :

```
IMAGE 1 — nuiter() ; embrumer(bandes=4) ; corps = convoquer('corps_humain','allonge')
          filairer(corps, sommets=True) ; foyer = incandescer(zone(corps,'thorax'), ROUGE)
          emettre_particules(foyer, 'lateral') ; deriver(corps) ; pulser(foyer)
          haloter() ; cadrer(corps, ouverture=faible, mise_au_point=foyer) ; sous_titrer(...)

IMAGE 2 — nuiter() ; embrumer(altitude='ciel') ; sol = napper(26, 52) ; filairer(sol)
          affleurer(sol, incandescer(...)) ; oeuf = sculpter('ovoide', facettes=basse)
          vitrer(oeuf) ; filairer(oeuf) ; essaimer(oeuf, 6, profondeurs='echelonnees')
          haloter() ; cadrer(mise_au_point=oeuf_proche) ; sous_titrer(...)
```

**Règle : un verbe qui ne sert dans aucune des deux compositions n'entre pas en v1.**

Ce que le code apporte et qu'un arbre JSON n'apporterait pas : les boucles (essaimer 9
œufs à des profondeurs échelonnées), l'arithmétique de position relative (*la masse
chaude est DANS le thorax*, calculée depuis la boîte englobante du corps), et la
composition de verbes que nous n'avions pas prévue. Un JSON déclaratif serait isomorphe
au système actuel — des noms de formes plus des nombres, c'est-à-dire le défaut.

---

## 6. La banque de référents — le vrai coût, et les licences vérifiées

`convoquer` ne vaut que par la banque derrière lui. **C'est le poste de coût dominant
du chantier, pas l'API.**

Bonne nouvelle : dans cette esthétique, la géométrie est **filaire, low-poly,
translucide et lumineuse**. La barre de fidélité est basse — un corps humain en filaire
bleu stylisé n'a besoin d'aucune exactitude anatomique. Les maillages CC0 low-poly sont
donc exactement le bon matériau, pas un pis-aller.

| Source | Licence | Vérifiée |
|---|---|---|
| **Poly Haven** | **CC0** — aucune restriction, aucune attribution | oui |
| **Kenney** | **CC0** | oui |
| **Quaternius** | **CC0**, milliers de modèles low-poly stylisés | oui |
| **TRELLIS.2** (Microsoft, 4B, image→3D) | **MIT** — commercial libre, aucun territoire, aucun seuil | oui |
| **Hunyuan3D-2.1** (Tencent) | Territoire = monde **sauf UE, Royaume-Uni, Corée du Sud** ; licence commerciale à demander au-delà de **1 M d'utilisateurs actifs mensuels** ; Tencent ne revendique rien sur les sorties | oui |
| Objaverse / Objaverse-XL | licences **hétérogènes**, à vérifier pièce par pièce | — |

**Ordre retenu : CC0 d'abord, TRELLIS.2 (MIT) pour combler, Hunyuan3D en dernier
recours.** Raison : le Burkina Faso est bien dans le « Territoire » de la licence
Tencent, mais la clause exclut l'UE et le Royaume-Uni — si Academia sert un jour des
étudiants là-bas, la question se rouvre. CC0 et MIT ne posent jamais cette question.

Point qui allège tout : la banque se construit **hors ligne**, et nous distribuons une
**vidéo rendue**, pas des maillages. L'exposition est faible. Ce n'est pas une raison
de la prendre à la légère — c'en est une de choisir CC0 quand c'est possible.

---

## 7. La porte d'acceptation déterministe — à poser AVANT tout le reste

Le 05/08, une vidéo **noire et muette** a été livrée à un étudiant comme « prête ».
Du code écrit par un modèle échouera de façons que nous n'avons pas prévues.

**« Noir », « vide », « figé » et « muet » sont des propriétés MESURABLES.** Les mesurer
coûte des millisecondes ; les demander à un modèle de vision coûte des secondes et une
incertitude. Six mesures, aucune IA :

1. nombre d'objets mesh dans la scène **> 0** (c'est `ERR_NO_MESH` de 3DCodeBench) ;
2. part de pixels non-fond sur l'image témoin **> 3 %** ;
3. luminance moyenne **et écart-type** au-dessus d'un plancher — une image
   uniformément grise doit échouer aussi ;
4. `ffmpeg blackdetect` → **0 s** de noir hors fondus déclarés ;
5. `ffmpeg freezedetect` → **0 s** de figé ;
6. piste audio présente, durée > 0, **RMS au-dessus d'un plancher**.

Rien ne se publie sans ces six mesures **écrites dans la ligne de rendu**, image témoin
conservée à côté. Faisable en une journée, sans IA, et indépendamment de tout le reste.

### Le critique visuel : jamais une note, et jamais le droit de publier

Les juges VLM savent **classer**, pas **noter** : accord exact 32–34 % sur une échelle
à 5 points, et 24–30 % des jugements s'écartent de 2 points ou plus (arXiv 2604.25235).
Formulation retenue — questions fermées, et un duel :

- Q1 « Énumère les objets que tu vois. » *(énumérer avant de juger)*
- Q2 « Un `<référent>` est-il reconnaissable ? oui / non »
- Q3 « Cette image illustre-t-elle `<sujet>`, ou pourrait-elle illustrer n'importe quel
  autre sujet ? spécifique / générique »
- Q4, en duel : « Laquelle de ces deux images illustre le mieux `<sujet>` ? » — contre
  le rendu de l'archétype actuel.

**Q4 est la seule qui mesure notre progrès**, parce qu'elle compare à ce qu'on avait.

> Le juge n'a jamais le droit de **publier**, seulement celui de **refuser** ou de
> **classer**. Sinon on recrée le défaut du 05/08 avec une couche d'IA en plus.

---

## 8. La geôle — et ce qu'elle ne fait pas

Trois impossibilités actées sur RunPod, à ne pas concevoir contre le vide :
pas de `CAP_NET_ADMIN` ni de `/dev/net/tun` (donc **aucune isolation réseau par le
noyau**), pas de namespaces non privilégiés (le profil seccomp Docker conditionne
`unshare` à `CAP_SYS_ADMIN`), pas de mode privilégié.

Les leviers réels sont donc au niveau du **processus**, du **système de fichiers** et
du **secret** :

1. **Séparer le secret du code** — la mesure la plus rentable, une vingtaine de lignes.
   Un superviseur détient `SUPABASE_SERVICE_KEY`, fait le polling et le dépôt, et
   n'exécute jamais de code de modèle. Un sous-processus Blender tourne avec un
   environnement **lavé**. *Le code du modèle ne peut pas exfiltrer une clé qu'il n'a
   pas, même avec le réseau ouvert.*
2. **UID dédié** sans répertoire personnel ; clé en 0600 appartenant au superviseur.
3. **Répertoire éphémère** par travail ; `/opt/academia3d` en lecture seule.
4. **Bornes dures** — `setrlimit` (CPU 120 s, AS 8 Gio, FSIZE, NOFILE, NPROC),
   `start_new_session=True`, `killpg` à 240 s. *`RLIMIT_AS` ne borne pas la VRAM :
   garde séparée nécessaire.*
5. **Liste blanche d'imports au niveau AST**, avant exécution.
6. **Processus éphémère** par travail, plus un checkpoint `.blend` par étape (SimWorlds)
   pour ne pas propager une scène corrompue.

**Ce que ça ne fait pas.** Une liste blanche AST est un filtre contre l'accident, **pas
contre un adversaire** — la documentation de RestrictedPython le dit elle-même. Le
contrôle réellement solide est double : le processus qui exécute ne détient pas la clé,
**et** le code n'est pas généré à la demande d'un étudiant mais compilé hors ligne,
relu, mis en cache. On passe de « exécution de code arbitraire déclenchée par un champ
de saisie public » à « exécution dans une chaîne de fabrication ».

Point complémentaire : le **sujet tapé par l'étudiant est une entrée non fiable** qui
atteint le modèle rédacteur. Il doit être transmis comme **donnée délimitée**, jamais
concaténé dans les consignes.

---

## 9. Ce que ce chantier ne résout PAS

> Il améliore la **pertinence**. Il ne touche **pas** la **latence**.

Après ce chantier, une capsule 3D coûtera toujours 75–82 min de rendu, contre une cible
P95 de 5 min. Pire : `embrumer` et `incandescer` sont **volumétriques**, donc parmi les
postes les plus chers d'EEVEE (un rapport ouvert chez Blender signale même les
volumétriques d'EEVEE Next plus lents que ceux d'EEVEE Legacy — issue #125364).

Il faut l'acter clairement pour que ce chantier ne serve pas de diversion sur la
question du temps d'attente, qui reste entière et distincte.

---

## 10. Ordre de marche

> **Correction du 11/08, après écriture du code.** L'étape 2 disait « brancher
> `matiere_feu` **et** `matiere_brume` ». C'était faux pour le feu. La brume est une
> **atmosphère générique** : elle habille toute scène, quel que soit le sujet.
> La masse incandescente, elle, est *l'énergie d'un objet* — le foyer **dans le
> thorax**. La brancher partout ferait une colonne de feu décorative dans chaque
> capsule, c'est-à-dire exactement la « forme préenregistrée utilisée à tous les
> cours » que Jocelyn a refusée. `matiere_feu` attend `convoquer` : elle a besoin
> d'un sujet où se loger. Seule la brume est branchée.

| # | Étape | Produit | Vérification |
|---|---|---|---|
| 1 | Porte d'acceptation déterministe (§7) | 6 mesures dans la ligne de rendu | rejouer une capsule noire connue : elle doit être **refusée** |
| 2 | Brancher `matiere_brume` en production (§2) | atmosphère de la référence | banc `banc_rendu.py` : coût en s/image avec et sans |
| 3 | `academia3d` en façade + les 4 verbes neufs (§5) | API composable | recomposer les **deux images de référence** à la main |
| 4 | Banque de référents CC0, 30–50 maillages (§6) | le sujet devient dicible | 20 sujets réels : combien trouvent leur référent |
| 5 | Geôle (§8) | secret séparé du code | tenter une lecture de la clé depuis le sous-processus |
| 6 | Étage 1 (intention JSON) puis étage 2 (recettes hors ligne) | scènes propres au sujet | duel Q4 contre l'archétype actuel |
| 7 | Boucle de réparation | robustesse | **en dernier** — elle ne gagne rien sur la pertinence |

---

## 11. Inconnues — à mesurer, jamais à supposer

1. **Le taux de faux positifs de NOTRE critique visuel sur NOS rendus.** Aucun chiffre
   publié ne s'applique. Protocole : 60 images témoins (20 bonnes, 20 noires ou vides,
   20 correctes mais hors sujet), les faire juger, compter. Une demi-journée.
2. **Le taux d'exécutabilité d'un modèle contre `academia3d`**, API absente de tout
   corpus d'entraînement. Les 0,910 d'Opus 4.7 dans 3DCodeBench portent sur `bpy`,
   massivement documenté. Peut être très inférieur — ou supérieur, l'API étant plus
   petite. À mesurer sur 30 sujets.
3. **Le coût réel de la banque.** Combien de maillages couvrent quelle proportion du
   programme burkinabè ? 30 ? 200 ? Non chiffré.
4. **Le taux de couverture du cache de recettes.** En dessous d'un certain seuil, le
   pari « génération hors ligne » s'effondre. Mesurable sur les sujets déjà en base.
5. **Le surcoût de rendu des verbes volumétriques** sur A40. `banc_rendu.py` existe
   déjà pour le mesurer.
6. **Le choix du bon référent pour un sujet abstrait.** Rien dans les sources lues ne
   dit qu'un modèle sait choisir la bonne image pour « la sociologie ». SceneCraft et
   LL3M démontrent sur des objets et des intérieurs, pas sur des métaphores
   pédagogiques. **C'est peut-être la vraie difficulté, et elle n'est traitée nulle
   part.**

---

## Sources

- SceneCraft — ICML 2024 — https://arxiv.org/abs/2403.01248
- LL3M: Large Language 3D Modelers — 08/2025 — https://arxiv.org/abs/2508.08228
- 3DCodeBench — 06/2026 — https://arxiv.org/abs/2606.01057
- SimWorlds — 07/2026 — https://arxiv.org/abs/2607.01766
- BlenderGym — CVPR 2025 — https://arxiv.org/abs/2504.01786
- Let Me Speak Freely? (format contraint et raisonnement) — https://arxiv.org/abs/2408.02442
- OpenAI Structured Outputs — https://openai.com/index/introducing-structured-outputs-in-the-api/
- MLLM-as-a-Judge (fiabilité des juges VLM) — https://arxiv.org/abs/2604.25235
- Auto-réparation itérative, plafonnement — https://arxiv.org/abs/2604.10508
- TRELLIS.2 (MIT) — https://github.com/microsoft/TRELLIS.2
- Hunyuan3D-2.1, licence — https://huggingface.co/tencent/Hunyuan3D-2.1/blob/main/LICENSE
- Poly Haven (CC0) — https://polyhaven.com/
- RestrictedPython, « ce n'est pas une sandbox » — https://restrictedpython.readthedocs.io/en/latest/idea.html
- ffmpeg blackdetect / freezedetect — https://ffmpeg.org/ffmpeg-filters.html
- EEVEE Next volumétriques plus lents que Legacy — https://projects.blender.org/blender/blender/issues/125364
