# Studio challenge — changer de paradigme : veille externe, chiffrage, recommandation

**Date : 28/10/2026.** Étude en lecture seule : rien n'a été implémenté,
déployé ni commité. Elle suit
`STUDIO_CHALLENGE_REPRODUIRE_REFERENCE_2026-10-28.md` (état des lieux du même
jour) et répond à la question de Jocelyn :

> « Est-ce qu'on peut pas faire un changement de paradigme pour atteindre le
> même résultat avec des coûts très faibles et des temps de production très
> faibles ? »

Étiquettes utilisées : **mesuré** (avec la source interne), **lu à la source**
(fichier LICENSE ou page officielle, datée), **annoncé** (page de produit ou
agrégateur, non vérifié), **estimé** (mon calcul, hypothèses dites).

---

## 1. La réponse courte

**Oui, à une condition : cesser de fabriquer un fichier vidéo pour chaque
étudiant.**

Aujourd'hui, chaque capsule est filmée image par image sur une machine louée,
encodée, déposée, puis téléchargée par l'étudiant. Or la scène est déjà
**décrite par un programme** de quelques kilo-octets : intentions, gestes,
narration. Le paradigme proposé consiste à **envoyer ce programme au
téléphone et à le jouer en direct** dans un lecteur Three.js, avec la voix
et les sous-titres. On ne fabrique un MP4 que lorsque l'étudiant **partage**
sa vidéo hors de l'application.

| | aujourd'hui (mesuré) | lecture sur l'appareil (estimé) |
|---|---|---|
| machine GPU louée par capsule | oui, ≈ 0,04 $ | **aucune** |
| coût total d'une capsule de 90 s | ≈ 0,07 $ | **≈ 0,01 à 0,03 $** (LLM + voix) |
| délai avant la première image | 2,2 à 4,9 min | **≈ 30 à 40 s** (préparation actuelle, voix comprise) |
| poids téléchargé par l'étudiant | 8–12 Mo de vidéo | ≈ 1,5 Mo de voix + objets 3D mis en cache |
| halo, brume, particules | absents en production | dessinés en direct par des shaders |

C'est le modèle de **Lottie** et de **Rive** : une animation livrée sous forme
de données, et rendue par l'appareil. C'est aussi ce que fait le *Player* de
Remotion, qui joue une composition dans la page sans la rendre en fichier.
Le procédé est courant dans l'industrie. Ce qui le rend possible chez nous,
c'est que notre moteur est **déjà** une page web déterministe
(`academia3d_web.js`).

**Ce qui le menace, et qu'il faut mesurer avant toute chose :** la puissance
graphique des téléphones des étudiants. 60 % du parc burkinabè est du
Transsion d'entrée de gamme (§3.1). D'où un **prototype à mesurer sur le TECNO
de Jocelyn** avant toute décision (§7).

---

## 2. Les contraintes du dépôt, face à ce paradigme

| Contrainte | Tenue ? |
|---|---|
| 100 % CSS pour le **tableau** | non concernée : la 3D n'a jamais été du CSS, et ce paradigme ne touche pas `whiteboard_vision` |
| **Aucune IA sur LWS** | tenue. Le LLM et la voix restent dans des Edge Functions ; le rendu de secours sur LWS est du dessin, pas de l'IA |
| **Dégradation gracieuse** | tenue **à une condition** : un appareil sans WebGL2, ou trop lent, doit recevoir un MP4 rendu côté serveur par la chaîne actuelle, conservée en repli |
| **La voix commande l'image** | tenue : les durées restent calées sur la voix mesurée (`narration.caler`) |
| **Porte d'acceptation** (jamais de noir livré) | **à redéfinir**, le point le plus délicat. On ne mesure plus un fichier mais un programme : rendre **une image témoin par scène** côté serveur (6 images, ≈ 2 s de processeur) avant d'autoriser la lecture. Le rendu d'un téléphone donné, lui, ne se mesure pas : c'est un risque nouveau, à couvrir par le prototype |

**Une décision passée à rouvrir, et je la nomme.** Le 18/08, la décision
écrite était : « On migre le rendu des capsules 3D vers le navigateur **sur
LWS** » (`MESURE_NAVIGATEUR_VS_BLENDER_2026-08-18.md:88`). La production
tourne pourtant sur **pod GPU** (`env_pod` : `--use-angle=gl-egl`, mesuré le
28/10). Je n'ai pas retrouvé le motif de ce revirement. Il compte ici : le
repli serveur de ce paradigme suppose de pouvoir rendre sans GPU.

---

## 3. Les pistes, une par une — sources, chiffres, réfutation

### 3.1 Lecture sur l'appareil (WebGL2 ; WebGPU plus tard)

**Pour.**
- Notre moteur est déjà une page Three.js déterministe : l'image *i* ne
  dépend que de *i* (`academia3d_web.js:254-260`).
- Le **bloom** s'obtient par `UnrealBloomPass`, ou par un flou à mipmaps,
  moins cher : une étude de 2026 sur GPU mobile à tuiles mesure le bloom à
  mipmaps comme le plus rapide, à 10,29 ms par image (etasr.com).
- La **brume**, les **particules** et la **grille lumineuse** sont des
  shaders, sans aucun fichier.
- L'**export au partage** existe dans le navigateur : l'API WebCodecs
  `VideoEncoder` est disponible dans Chrome Android depuis la version 94 et
  dans la WebView Android (MDN), et **Mediabunny** produit le MP4. Licence
  lue à la source : **MPL-2.0**, une licence par fichier, compatible avec une
  application fermée tant qu'on ne modifie pas ses fichiers.

**Contre, cherché exprès.**
- **Le parc.** Statcounter, septembre 2026, Burkina Faso : **Tecno 38,5 %,
  Infinix 15,6 %, Itel 6,1 %**, soit 60 % de Transsion, suivis de Samsung
  (11,2 %). Ce sont souvent des puces MediaTek à GPU Mali-G52/G57, ou
  PowerVR. Un forum Unity relève **6 images/s** sur un Redmi 12 (Mali-G52 MC2)
  pour une scène mobile basse qualité. Ce n'est pas notre scène, mais ce
  chiffre interdit de supposer que ça passe.
- **WebGPU** : présent dans Chrome Android 12+ sur GPU Qualcomm et ARM, et
  Imagination seulement à partir d'Android 16. **Aucune source fiable sur
  WebGPU dans la WebView.** Le socle doit donc rester **WebGL2**, que notre
  moteur utilise déjà.
- **Versions d'Android** au Burkina (Statcounter, 09/2026) : Android 12 ou
  plus ≈ **75 %** ; 11 ≈ 10 % ; le reste inconnu.
- **Les données** : un objet Objaverse pèse jusqu'à **4,2 Mo** (le volcan,
  ETAT §1 bis). Il faut une compression (Draco ou meshopt) et une
  simplification, sinon l'étudiant paie en données ce qu'on économise en GPU.
- **Le flux Challenge** : hors de l'application (TikTok, WhatsApp), il faut un
  MP4. D'où l'export au partage, par le téléphone ou par le serveur en repli.

**Verdict** : la piste la plus prometteuse, **conditionnée à une mesure de
fluidité** sur un appareil Transsion réel.

### 3.2 Remotion, Revideo, Motion Canvas — le rendu serveur sans GPU

- **Remotion** — licence lue à la source : gratuite pour les particuliers, les
  associations et les entreprises de **3 salariés au plus**. Au-delà, licence
  « Company ». Le texte annonce un changement en version 5.0.
- **Revideo** — MIT d'après le README (le fichier LICENSE lui-même n'a pas
  été affiché). Rendu sans interface, découpable entre plusieurs workers.
- **Motion Canvas** — MIT, orienté 2D.

**Réfutation.** Ces outils pilotent un Chromium sans interface, exactement
comme `rendre_capsule_web.js`. Ils n'apportent **ni la 3D, ni le style**, et
sans GPU ils se heurtent au même mur : rendu logiciel. Chez nous, la mesure
du 18/08 donne **0,284 s par image** sur LWS pour une scène à **deux objets
sans post-traitement**
(`MESURE_NAVIGATEUR_VS_BLENDER_2026-08-18.md`). Pour 90 s à 25 i/s, soit
2 250 images, il faut **≥ 10,7 min** sur une machine de 4 vCPU qui fait aussi
tourner le tableau. Une source externe confirme que SwiftShader tombe à moins
de 10 images/s sur des scènes lourdes (agent-browser.dev).
**Verdict** : utile comme **repli d'export**, pas comme chaîne principale.
Notre propre page suffit, et Remotion poserait en plus une question de licence.

### 3.3 Modèles vidéo ouverts, hébergés par nous

Prix RunPod lus le 28/10 (page mise à jour le 08/10/2026), à l'heure :
RTX 4090 **0,34 $** (communautaire) / 0,89 $ (sécurisé) ; H100 SXM **2,69 $** /
3,99 $ ; A40 0,35 $ / 0,59 $.

| Modèle | Licence (lue à la source) | Vitesse | Coût estimé pour 90 s |
|---|---|---|---|
| **Wan 2.2** | **Apache-2.0** (`LICENSE.txt`, texte standard) | 5B : « 5 s de 720p en moins de 9 min » sur carte grand public (annonce) ; 14B : **80 Go de VRAM** | 18 plans × 9 min = 2 h 42 de 4090 → **0,92 à 2,40 $**, et **2 h 42** de délai sur une seule machine |
| **LTX-Video** 0.9.x | OpenRAIL-M depuis 0.9.5 (d'après le README) | 13B distillé : « HD en 10 s sur H100 », FP8 « temps réel » (annonce) | 18 plans × 10–30 s ≈ 3–9 min de H100 → **0,15 à 0,60 $** plus l'amorçage |
| **LTX-2** | licence maison : **gratuite sous 10 M$ de chiffre d'affaires**, interdite pour concurrencer Lightricks — **pas open source** | — | — |
| **HunyuanVideo 1.5** | Tencent Community : **exclut l'UE, le Royaume-Uni et la Corée du Sud** ; sorties à étiqueter comme générées | — | écartée pour la licence |

**Réfutation.**
1. **L'amorçage domine** : nous l'avons mesuré à 5,0 min en médiane, jusqu'à
   plus de 25 min (inventaire du 11/08). Les poids de ces modèles font
   15 à 60 Go à télécharger par machine, sauf volume réseau.
2. **La cohérence d'un plan à l'autre** n'est pas garantie : le même corps
   change d'un plan à l'autre.
3. **L'exactitude scientifique** n'est le but d'aucun de ces modèles. Un cours
   d'anatomie inventée est pire que pas de cours.
4. **TikTok** renforce depuis juillet 2026 l'étiquetage des contenus générés
   par IA, et vise nommément la santé (rapport précédent, §5.1).

**Verdict** : écarté à la demande. Seule réserve : **LTX sur H100** est la
voie générative la moins chère que j'aie trouvée, et peut servir **hors
ligne** à fabriquer une banque d'ambiances (§3.6).

### 3.4 Modèles vidéo par API, payés à la seconde

Repris du rapport précédent : de **0,05 à 0,40 $/s** annoncés, soit **4,50 à
36 $** pour 90 s. La page de Google, mise à jour le 27/10, ne montre même plus
Veo. **Écarté à la demande** pour l'économie : un étudiant paie environ
0,02 $ par capsule (mesuré le 28/10, `app.credit_packs`).

### 3.5 Gaussian splats et NeRF

**Spark** (`sparkjs.dev`) affiche des splats dans Three.js en WebGL2 et
annonce un rendu « rapide même sur mobile modeste ». C'est une annonce, sans
mesure Android. **Réfutation** : un splat restitue une scène **réelle captée**
avec un rendu photographique. Il ne se génère pas en quelques secondes à
partir d'un sujet tapé (aucune source trouvée), et son esthétique est
l'opposé du filaire holographique. **Écarté.**

### 3.6 Image vers 3D, pour agrandir la banque d'objets

**TRELLIS.2** (Microsoft) — licence **MIT, lue dans le fichier**. Le README
annonce **≈ 3 s par objet en 512³ et ≈ 17 s en 1024³ sur H100**, et au moins
24 Go de VRAM. **Réfutation** : ses dépendances de rendu (nvdiffrast,
nvdiffrec) ont **leurs propres licences**, et celle de NVIDIA est souvent
restreinte. **Non lue aujourd'hui : à lire avant tout usage.** Il faut aussi
une image d'entrée, donc un modèle d'image à licence commerciale.
**Hunyuan3D-2.1** a la même clause territoriale que HunyuanVideo.

**Verdict** : excellent **hors ligne**, pour combler la banque. 500 objets en
1024³ ≈ 2 h 20 de H100, soit **≈ 6 à 10 $ une fois** (estimé). Jamais dans
la boucle étudiant.

### 3.7 Le corps en fil de fer, les particules : tout procédural ?

- **Particules, brume, grille, lueur, foyer rouge** : **oui, 100 %
  procédural**, par shaders, avec une graine fixe. Aucun fichier, aucune
  licence.
- **Le corps humain** : **non**, aucune équation raisonnable ne donne une
  silhouette crédible. En revanche, **un seul fichier libre suffit**.
  **MakeHuman** — fichier `LICENSE.md` lu : le maillage de base, les cibles
  et les proxys sont sous **CC0 1.0** ; les exports appartiennent à
  l'utilisateur ; seul le code du logiciel est sous AGPL. Un corps exporté
  une fois, simplifié, et habillé de notre filaire : c'est exactement
  l'image 1 de la référence.
- **Anatomie détaillée** (organes) : Z-Anatomy / BodyParts3D, en
  **CC BY-SA** d'après des sources secondaires (le README du dépôt est
  introuvable aujourd'hui). Le *partage à l'identique* imposerait la même
  licence aux dérivés : **à faire lire avant usage**.

**Rappel de doctrine** (`fabriquer_contours.py`) : les formes générées par
équation nous appartiennent sans discussion. Le CC0 de MakeHuman respecte cet
esprit, sans auteur ni attribution. Ce ne serait pas le cas du CC BY, que la
banque Objaverse impose aujourd'hui **sans l'afficher** (rapport précédent,
§4.3).

### 3.8 La voix

| Option | Licence / prix | Pour 90 s (≈ 1 500 caractères) |
|---|---|---|
| **Voxtral TTS** (actuel, par l'API) | API : **0,016 $ / 1 000 caractères** (page Mistral). Les poids ouverts sont sous **CC BY-NC 4.0**, donc pas d'auto-hébergement commercial | **≈ 0,024 $**, à lui seul autant que ce que paie l'étudiant |
| Gemini 2.5 Flash TTS | Google Cloud : 10 $ par million de jetons audio, 25 jetons par seconde | ≈ 0,023 $ |
| Google Cloud TTS, voix standard | tarif public de Google Cloud (non relu aujourd'hui) | ≈ 0,006 $ (estimé) |
| **Kokoro** dans le navigateur | modèle Apache-2.0 ; mais le français passe par **espeak-ng, sous GPL-3.0** | 0 $ ; **risque de licence** à lever |
| **Piper** | dépôt MIT **archivé le 06/10/2025** ; la suite `piper1-gpl` est sous **GPL-3.0** | écarté pour une application fermée |
| Voix système Android | gratuite, sur l'appareil, qualité variable selon le téléphone | 0 $ ; **bon repli**, jamais par défaut |

**Une découverte en passant** : le coût du LLM journalisé en base est
**0,00116 $** en moyenne sur 140 storyboards `google/gemini-2.5-flash`
(mesuré le 28/10). Mais il est calculé à un tarif **codé en dur** à
0,10 $ / 0,40 $ le million de jetons (`llm.ts:31`). Au tarif public annoncé
pour Gemini 2.5 Flash, environ 2,50 $ le million en sortie, le coût réel
serait plutôt de **≈ 0,007 $** (estimé). Le journal sous-estime donc d'un
facteur 5 à 6.

### 3.9 Les outils « faceless »

InVideo, HeyGen, Pictory, Captions : leur chaîne type est script, plans de
banque d'images ou génératifs, voix, puis sous-titres calés. Ils se vendent
par abonnement, pour un humain qui monte. **OpenMontage** automatise cette
chaîne, mais sous **AGPL-3.0**. Rien de tout cela ne vise des milliers de
vidéos par sujet à 0,02 $. **On n'en retient que la méthode** : un plan court
par idée, une accroche, des sous-titres gros et centrés.

---

## 4. Tableau de synthèse — une vidéo de 90 s

| Piste | Coût / vidéo | Délai | Proximité à la référence | Exactitude | Effort | Risque principal |
|---|---|---|---|---|---|---|
| **Actuel** (pod, Three.js sans style) | ≈ 0,07 $ | 2–5 min | faible (style absent) | contrôlée | — | style perdu au portage |
| **A. Actuel + style** (rapport précédent) | ≈ 0,07–0,10 $ | 3–6 min (*bloom non mesuré*) | bonne | contrôlée | 2–3 j | coût GPU toujours supérieur au prix payé |
| **B. Lecture sur l'appareil + export au partage** | **≈ 0,01–0,03 $** | **≈ 30–40 s** | bonne si le téléphone suit | contrôlée | **≈ 1–2 semaines** | **fluidité sur Transsion d'entrée de gamme** |
| C. Rendu serveur CPU (LWS, Remotion…) | ≈ 0,03 $ + LWS saturé | ≥ 11 min | bonne | contrôlée | 1 sem. | débit : environ 5 vidéos/h, en concurrence avec le tableau |
| D. Vidéo ouverte auto-hébergée (LTX, Wan) | 0,15–2,40 $ | 10 min à 3 h | la plus proche (*hypothèse*) | **non contrôlée** | 2–3 sem. | amorçage, cohérence, exactitude |
| E. Vidéo par API | 4,50–36 $ | quelques min | la plus proche | **non contrôlée** | 1 sem. | ×200 à ×1 400 le prix payé |
| F. Splats / NeRF | — | — | style opposé | — | — | écarté |

---

## 5. La recommandation : B, avec A pour le style et C pour le repli

**Le paradigme : « la vidéo est un programme ; on ne fabrique un fichier que
pour le partage ».**

```
Étudiant tape un sujet
 └─> Edge Function (inchangée) : LLM → capsule = intentions + gestes + narration
 └─> préparation (LWS, inchangée) : voix + durées mesurées + nappe sonore
 └─> NOUVEAU — garde-fou serveur : 1 image témoin par scène (CPU, ≈ 2 s),
      porte d'acceptation sur ces images, sinon correction / repli
 └─> le téléphone reçoit : capsule.json (≈ 10 Ko) + narration.mp3 (≈ 1,4 Mo)
      + objets 3D compressés, mis en cache (corps MakeHuman CC0, banque)
 └─> LECTEUR Three.js dans une WebView (et tel quel dans l'app web) :
      filaire + verre + bloom à mipmaps + brume + particules + grille
      + foyer rouge — palier « léger » automatique si l'image/s chute
 └─> « Partager » : export MP4 sur l'appareil (WebCodecs + Mediabunny),
      ou, à défaut, rendu serveur (la chaîne actuelle, gardée en repli)
```

Ce que cela garde :
- l'invite, la validation, les sept verbes, `convoquer` et la banque ;
- la voix qui commande l'image et la nappe sonore ;
- la chaîne pod actuelle, qui **devient le repli d'export** au lieu d'être le
  chemin de chaque capsule.

Ce que cela supprime **pour chaque capsule regardée dans l'application** :
la location de la machine, l'amorçage (5 min en médiane, plus de 25 min dans
le pire cas mesuré), l'encodage et le dépôt de 8 à 12 Mo, ainsi que les
échecs « dépôt refusé » et « image figée » du fichier.

**Pourquoi pas la vidéo générative, même ouverte.** Elle reste la plus
proche de la référence, et c'est probablement ainsi que la référence a été
faite. Mais elle coûte de 5 à 1 000 fois plus, ne garantit ni la cohérence ni
l'exactitude, et ajoute un risque d'étiquetage sur TikTok. Elle garde
**une** place : fabriquer **hors ligne** une banque d'ambiances, ou les
capsules d'un catalogue relu par un humain (rapport précédent, §6.4).

---

## 6. Ce qui contredit encore la recommandation — et n'est pas levé

1. **Aucune mesure sur un téléphone d'étudiant.** Tout repose sur la fluidité
   d'un Mali-G52 ou d'un PowerVR. C'est l'objet unique du prototype.
2. **La porte d'acceptation change de nature.** On prouvera qu'un programme
   rend une image, pas que **ce** téléphone l'a rendue. Une erreur WebGL côté
   client doit remonter au serveur (télémétrie), sinon on recrée le défaut du
   05/08 : un écran noir présenté comme prêt.
3. **La WebView du téléphone** est une version de Chromium mise à jour par le
   Play Store : sur un vieil appareil, elle peut être ancienne. Non mesuré.
4. **L'export sur l'appareil** encode en temps réel ou plus lentement : sur un
   téléphone lent, 90 s de vidéo peuvent prendre plusieurs minutes et vider
   la batterie. Le repli serveur doit rester.
5. **Le coût de la voix** (≈ 0,024 $ avec Voxtral) égale à lui seul le prix
   payé. Le paradigme ramène le coût **près** du prix, pas en dessous, tant
   que la voix ou le prix ne changent pas. C'est une décision de Jocelyn.

---

## 7. Le prototype minimal qui tranche — à construire, pas construit

**Une seule page HTML autonome**, sans serveur ni chaîne, qui :

1. charge une capsule réelle déjà en base (« le volcan » `44198332`, ou
   `chaleur_corps.json`) et **sa** narration ;
2. dessine les deux images de la référence : corps MakeHuman (CC0) en filaire
   avec foyer rouge au thorax et particules ; gouttes de verre sur une grille
   à lueur affleurante, dans la brume ;
3. joue la voix avec les sous-titres, caméra en mouvement ;
4. affiche les **images par seconde**, avec bascule automatique vers un palier
   léger (bloom à demi-résolution, moins de particules) ;
5. propose un bouton **« Exporter 10 s »** : WebCodecs + Mediabunny vers un MP4
   téléchargeable.

**Les mesures qui décident :**

| Mesure | Où | Seuil pour adopter |
|---|---|---|
| images/s, palier complet et palier léger | TECNO de Jocelyn, **dans Chrome et dans une WebView** | ≥ 24 i/s au moins en palier léger |
| temps avant la première image | idem, réseau mobile réel | < 3 s une fois les données reçues |
| données téléchargées | outils du navigateur | < 3 Mo hors voix |
| durée de l'export de 10 s | TECNO | < 30 s |
| même page en rendu serveur | LWS (CPU) | pour chiffrer le repli |
| ressemblance | Jocelyn, côte à côte avec les deux captures | « même famille » |

**Coût** : 1 à 2 jours d'agent, **0 $** de machine (estimé). **Ce qu'on fait
du résultat** : si le seuil est tenu en palier léger, on bascule vers B ; s'il
ne l'est pas, on fait le lot 1 du rapport précédent (A, style porté sur le
pod) et la lecture sur l'appareil attend un parc plus puissant.

---

## 8. Sources (consultées le 28/10/2026)

- RunPod, tarifs (mis à jour le 08/10/2026) — https://www.runpod.io/pricing
- Wan 2.2, `LICENSE.txt` (Apache-2.0) — https://raw.githubusercontent.com/Wan-Video/Wan2.2/main/LICENSE.txt · fiche du modèle — https://huggingface.co/Wan-AI/Wan2.2-I2V-A14B
- LTX-Video, README — https://github.com/Lightricks/LTX-Video · licence LTX-2 — https://static.lightricks.com/legal/ltx-2-open-weights-license-0.X.pdf
- HunyuanVideo 1.5, `LICENSE` — https://raw.githubusercontent.com/Tencent-Hunyuan/HunyuanVideo-1.5/main/LICENSE
- TRELLIS.2, `LICENSE` (MIT) et README — https://github.com/microsoft/TRELLIS.2
- MakeHuman, `LICENSE.md` (ressources CC0) — https://raw.githubusercontent.com/makehumancommunity/makehuman/master/LICENSE.md
- Z-Anatomy — https://github.com/Z-Anatomy/Models-of-human-anatomy (README non récupéré ; licence CC BY-SA d'après des sources secondaires)
- Remotion, `LICENSE.md` — https://raw.githubusercontent.com/remotion-dev/remotion/main/LICENSE.md
- Revideo — https://github.com/redotvideo/revideo
- Mediabunny, `LICENSE` (MPL-2.0) — https://raw.githubusercontent.com/Vanilagy/mediabunny/main/LICENSE · guide — https://mediabunny.dev/guide/introduction
- WebCodecs (MDN) — https://developer.mozilla.org/Web/API/WebCodecs_API
- WebGPU, état — https://en.wikipedia.org/wiki/WebGPU · https://webgpu.com/news/webgpu-hits-critical-mass-all-major-browsers/
- flutter_scene (pré-1.0, canal master) — https://pub.dev/packages/flutter_scene
- three.js UnrealBloomPass — https://threejs.org/docs/pages/UnrealBloomPass.html
- Bloom sur GPU mobile à tuiles (2026) — https://etasr.com/index.php/ETASR/article/download/19101/6940
- Mali-G52 sous Unity — https://discussions.unity.com/t/introducing-the-new-urp-3d-sample/929894?page=2
- Rendu WebGL sans GPU — https://agent-browser.dev/webgpu · https://microlink.io/blog/webgl-without-a-gpu
- Spark (gaussian splats) — https://github.com/sparkjsdev/spark
- Statcounter Burkina Faso, constructeurs (09/2026) — https://gs.statcounter.com/vendor-market-share/mobile/burkina-faso · versions d'Android — https://gs.statcounter.com/android-version-market-share/mobile/burkina-faso
- Voxtral TTS, tarif — https://mistral.ai/en/pricing · poids CC BY-NC — https://huggingface.co/mistralai/voxtral-4b-tts-2603
- Google Cloud TTS, tarifs — https://cloud.google.com/text-to-speech/pricing
- Kokoro dans le navigateur — https://www.npmjs.com/package/kokoro-js · eSpeak NG (GPL-3.0) — https://npmjs.com/package/espeak-ng
- Piper, passage en GPL — https://www.promptquorum.com/power-local-llm/piper-tts-review
- OpenMontage (AGPL-3.0) — https://github.com/calesthio/OpenMontage

**Non lu à la source, et nommé comme tel** : les licences de nvdiffrast et de
nvdiffrec, le README de Z-Anatomy, le fichier LICENSE de Revideo, les tarifs
officiels d'OpenAI TTS (page refusée, HTTP 403), le statut de WebGPU dans la
WebView Android.
