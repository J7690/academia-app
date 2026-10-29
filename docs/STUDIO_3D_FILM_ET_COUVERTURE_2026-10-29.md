# Studio 3D — des capsules qui ont l'air d'un film, et des éléments pour tous les sujets (29/10/2026)

Suite de `STUDIO_3D_VOCABULAIRE_UNIVERSEL_2026-10-29.md` (chimie exacte, résolveur) et
de `STUDIO_3D_BIBLIOTHEQUE_ILLUSTRATION_2026-10-28.md` (sept étagères).

La demande de Jocelyn :

> Fais vraiment des recherches externes. Qu'est-ce qui peut être fait pour avoir des
> scènes beaucoup plus animées, beaucoup plus film, avec beaucoup d'éléments
> d'illustration adaptés à chaque sujet ? Comment garantir la disponibilité des
> éléments sur l'ensemble des sujets ?

Recherche menée sur quatre angles : littérature, plateformes, dépôts publics et
licences lues à la source, et ce que nous avons déjà (§7).

## 1. Les recommandations, en bref

1. **« Film », c'est d'abord une grammaire de caméra et de montage, pas plus de décor.**
   Aujourd'hui, une scène, c'est un seul mouvement de caméra. Un film en enchaîne
   plusieurs : plan large qui situe, rapprochement, gros plan sur le détail, retour.
   Il coupe sur le rythme de la voix et passe d'une scène à l'autre par un raccord.
   C'est ce qui manque le plus, et c'est **du code à nous**, sans licence.
2. **Chaque effet de film doit servir l'explication.** La recherche est nette :
   l'animation qui *représente* le sujet aide (d ≈ 0,40), le décor qui distrait nuit
   (g ≈ −0,33), et guider le regard aide fortement (g ≈ 0,53 en mémorisation). La
   mise au point qui glisse vers ce que dit la voix, c'est du film **et** du guidage.
3. **La disponibilité se garantit par couches, de la plus sûre à la plus riche** :
   - couche 0, les équations à nous, jamais vide ;
   - couche 1, des banques ouvertes triées ;
   - couche 2, des objets fabriqués la nuit sur notre GPU et validés par un humain ;
   - couche 3, des décors d'ambiance en relief ;
   - couche 4 (optionnelle), des plans vidéo réutilisables.

   Chaque couche couvre ce que la précédente ne sait pas faire.
4. **On mesure la couverture au lieu de l'espérer** : un inventaire des notions des
   programmes, une carte notion → éléments, un banc qui donne la part de notions
   servies, et la liste des demandes non servies, qui devient la commande de
   fabrication de la nuit.

## 2. Ce que dit la recherche sur l'apprentissage — le garde-fou du « film »

| constat | chiffre | source | nature |
|---|---|---|---|
| l'animation bat l'image fixe, surtout quand elle **représente** le sujet | d = 0,37 en tout, **0,40** si elle représente, 0,76 pour la vidéo réaliste | Höffler et Leutner 2007, 26 études, 76 comparaisons | méta-analyse |
| l'effet est plus modeste dans les synthèses récentes | g = 0,23 | Berney et Bétrancourt 2016 (140 comparaisons) ; Castro-Alonso 2019 | méta-analyses |
| le **détail séduisant** (décor sans rapport) **nuit** | g = **−0,33**, pire en fin de séquence et chez les novices | Sundararajan et Adesope 2020, 58 études | méta-analyse, chiffre lu dans une synthèse |
| **guider le regard** dans une animation aide | g = **0,53** en mémorisation, 0,36 en transfert | méta-analyse de 43 études (2016) | méta-analyse |
| la vidéo courte, vive et enthousiaste retient | décrochage au-delà d'environ 6 min | Guo, Kim et Rubin 2014, 862 vidéos, 6,9 millions de sessions | mesure |

**Ce qu'on en tire.** Chaque effet doit **désigner** quelque chose : la caméra va là où
la voix parle, la mise au point isole le mot, la lumière monte sur le sujet. Les effets
gratuits sont à proscrire : particules sans objet, fond trop chargé, musique qui couvre
la voix. C'est la différence entre un film pédagogique et une bande-annonce.

## 3. Rendre les scènes « film » — ce qui se fait ailleurs, et ce qu'on en prend

### Comment les studios font

- **Kurzgesagt** : la voix off fixe le rythme de l'animation ; environ 200
  illustrations par vidéo de 10 minutes, découpées en centaines de calques ; personnages
  articulés ; plus de 1 200 heures par vidéo (estimation rapportée par un tiers). La
  leçon : **la voix commande le découpage**, et la profondeur vient des calques. C'est
  déjà notre règle d'or. La profondeur, elle, nous manque.
- **NotebookLM (Google), « Video Overviews »** : des diapositives commentées, illustrées
  par un générateur d'images (Nano Banana), dans un style choisi. Le format
  « Cinematic », lancé en mars 2026 sur Gemini 3 et Veo 3, fabrique de vraies images
  vidéo, mais il faut **30 minutes ou plus** et il est réservé aux offres hautes
  (articles de tiers ; la page d'aide de Google n'a pas été lue). Le marché va vers le
  « cinéma ». Notre avantage reste la science exacte, jouée sur le téléphone en
  quelques secondes et pour presque rien.

### Ce que la recherche sait automatiser

- **Planifier les plans d'après le script** : MovieAgent (arXiv 2503.07314) fait jouer
  à plusieurs agents réalisateur, scénariste et storyboarder. CinemaTraj (2026) compose
  des **trajectoires de caméra élémentaires** à partir du langage, sur le graphe de la
  scène. Un système récent pour le tournage virtuel transforme le script en liste de
  plans exécutable. **C'est la bonne forme pour nous** : l'IA choisit des plans dans un
  vocabulaire fermé, notre code calcule la caméra exacte (même doctrine que la chimie).
- **Le piège mesuré** : sur les scènes Three.js écrites par des modèles,
  WorldCoder-Bench montre qu'un jugement par capture d'écran **ne voit pas** si l'état
  est juste. On vérifie donc par la mesure (notre banc image par image), pas par un
  modèle.

### Ce qu'on recommande de construire (tout est du code à nous)

| élément de film | ce que voit l'étudiant | à qui il sert |
|---|---|---|
| **liste de plans par scène** : large, moyen, gros plan, plongée, travelling, orbite | 2 à 4 plans par scène au lieu d'un seul mouvement | rythme |
| **coupes calées sur la voix** : un plan change au début d'une phrase ou sur le mot | l'image suit la parole | guidage, contiguïté |
| **mise au point qui glisse** (profondeur de champ) vers l'élément nommé | le reste se floute, l'œil va au bon endroit | **guidage** (g ≈ 0,53) |
| **profondeur** : premier plan et arrière-plan qui défilent à des vitesses différentes | du relief, comme les calques de Kurzgesagt | lisibilité de l'espace |
| **raccords entre scènes** : l'objet de la scène 2 sort de celui de la scène 1, fondu lumineux | le cours devient un récit | continuité |
| **lumière et étalonnage par intention** : chaud pour l'énergie, froid pour la structure, montée de lumière sur le sujet | une ambiance, sans décor gratuit | attention |
| **son** : souffles sur les coupes, nappe musicale très basse | la sensation « film » | à doser (détail séduisant) |

**Bibliothèques** : `pmndrs/postprocessing` (licence zlib, lue) pour la profondeur de
champ, le vignettage et le grain. Le moteur de **Theatre.js** est sous Apache 2.0, mais
son **éditeur est sous AGPL v3** (lu) : on ne l'intègre pas, et nos trajectoires de
caméra s'écrivent comme le reste, en fonctions pures du temps.

**Limite connue** : la profondeur de champ est l'effet le plus coûteux sur téléphone
(forums Unity, Arm). Elle ne sera active que dans le **palier complet**. Le TECNO
passe au palier léger quand il descend sous 24 images par seconde : mécanisme déjà en
place.

## 4. Garantir les éléments sur tous les sujets — les couches

| couche | contenu | sources (licence **lue**) | quand c'est fabriqué | ce qui la limite |
|---|---|---|---|---|
| **0. Équations à nous** | phénomènes, chimie équilibrée, maths, schémas, texte, accessoires | aucune licence (code à nous) | à la lecture, sur le téléphone | ne dessine pas un lion |
| **1. Banques ouvertes triées** | objets, animaux animés, anatomie, espace, matières | Quaternius et Kenney (CC0, d'après des tiers) ; Poly Haven (CC0, FAQ) ; Smithsonian (CC0 **objet par objet**) ; NASA (sans droit d'auteur, consignes d'usage) ; NIH 3D (licence par entrée) ; Sketchfab et Objaverse en CC-BY, attribution affichée | une fois, hors ligne, allégés (chaîne de la phase A) | droits à vérifier objet par objet |
| **2. Fabriqués la nuit sur notre GPU** | tout objet absent : une image d'abord, puis un objet 3D, puis un squelette s'il bouge | FLUX.1 schnell (Apache 2.0) → TRELLIS.2 (**MIT, code et poids lus**) → UniRig (**MIT, lu**) → notre allègement | **en lot, la nuit**, jamais pendant que l'étudiant attend | qualité variable : **validation humaine** avant d'entrer au catalogue |
| **3. Décors d'ambiance en relief** | un marché de Ouaga, une savane, un laboratoire, une salle de classe | image FLUX.1 schnell + carte de profondeur Depth Anything V2 **Small** (Apache 2.0, lu) → décor en relief que la caméra traverse, joué par le téléphone | la nuit, réutilisable | pour situer, **jamais** pour une donnée scientifique |
| **4. Plans vidéo réutilisables** (option) | quelques secondes d'ambiance : pluie sur un champ, foule, rivière | Wan 2.2 (**Apache 2.0, code et poids lus**) | la nuit, bibliothèque de plans | lent (plusieurs minutes pour 5 s, d'après des tiers) ; non déterministe |

**Pourquoi « la nuit » et pas « à la demande » dans la boucle étudiant.** Notre pod GPU
met près d'une demi-heure à démarrer (`install_pod.sh`, compétence `etat-des-moyens`).
L'étudiant attend aujourd'hui une dizaine de secondes. La fabrication remplit donc le
catalogue **avant** qu'on en ait besoin. Le résolveur (document précédent, §5) sert ce
qui existe, note ce qui manque, et la nuit fabrique ce qui a été le plus demandé.

**Coût de la couche 2** : une RTX 4090 coûte de 0,34 à 0,74 $ de l'heure chez RunPod
(sources de tiers, 2026). Le temps de TRELLIS.2 par objet n'est **pas mesuré** (3 s
annoncées sur H100, sans méthode). Il faut le mesurer sur notre pod avant de chiffrer
un catalogue.

**Ce qu'on écarte, licence lue** :

| écarté | motif |
|---|---|
| Hunyuan3D 2.1 | licence propre qui **exclut l'Union européenne, le Royaume-Uni et la Corée du Sud** |
| Depth Anything V2 Base et Large | CC-BY-NC : pas d'usage commercial |
| Stable Fast 3D | licence propre, accès sous conditions |
| éditeur de Theatre.js | AGPL v3 |
| Z-Anatomy et BodyParts3D | partage à l'identique (CC BY-SA), et une partie en CC BY-NC-SA ; à rouvrir seulement si Jocelyn accepte le partage à l'identique pour l'anatomie |
| ConceptNet pour la carte des notions | CC BY-SA, et plus mis à jour depuis 2021 |
| objets Objaverse en NC ou SA | non commercial, ou partage à l'identique |

## 5. Mesurer la couverture au lieu de l'espérer

1. **L'inventaire des notions.** Les programmes officiels du Burkina (physique-chimie,
   SVT, mathématiques, histoire-géographie…) **n'ont pas été trouvés en ligne**. Il faut
   les obtenir (ministère, enseignants partenaires) : c'est la liste de référence.
2. **La carte notion → éléments**, fabriquée hors ligne. Par exemple, pour « la
   photosynthèse » : feuille, soleil, CO₂, H₂O, glucose et la réaction équilibrée.
   L'IA la propose, un enseignant la relit, et elle entre dans la consigne du
   générateur.
3. **Le banc de couverture**, qui tourne à chaque version du catalogue :
   - la part des notions qui ont au moins trois éléments pertinents ;
   - la part des scènes qui montrent ce que dit la phrase (15,6 % mesurés le 28/10) ;
   - la part des scènes servies en repli texte.
4. **Le tableau des demandes non servies**, alimenté par le résolveur : il donne l'ordre
   de fabrication de la nuit.
5. **La promesse faite à l'étudiant ne dépend pas des couches 1 à 4.** Sans objet
   trouvé, la couche 0 montre toujours quelque chose de juste (phénomène, équation,
   schéma, mot), et le repli est nommé dans les corrections.

## 6. Le plan proposé

| lot | contenu | effort estimé | dépend de |
|---|---|---|---|
| **F1 réalisation** | liste de plans par scène (vocabulaire fermé), coupes calées sur la voix, raccords entre scènes, lumière par intention ; consigne du générateur ; banc | 3 à 4 jours | rien |
| **F2 profondeur** | mise au point qui suit le mot, premier plan et arrière-plan, vignettage, grain ; palier complet seulement ; mesure sur le TECNO | 2 jours | F1 |
| **C1 banques ouvertes** | 300 à 500 objets et animaux triés (CC0 d'abord), allégés, licences enregistrées, animaux animés lus par `AnimationMixer` | 4 à 5 jours | chaîne d'allègement (phase A) |
| **C2 fabrication de nuit** | FLUX schnell → TRELLIS.2 → UniRig sur le pod, file nourrie par les demandes non servies, page de validation humaine | 5 jours, après une **mesure** du temps par objet | pod GPU |
| **C3 décors en relief** | 20 décors d'ambiance (Burkina d'abord), image et profondeur, traversée par la caméra | 2 à 3 jours | C2 (même pod) |
| **M couverture** | inventaire des programmes, carte notion → éléments, banc, tableau des demandes | 3 jours, plus la relecture enseignante | les programmes officiels |

Ordre conseillé : **F1 puis F2**, parce que c'est ce qui change le plus l'impression de
film, sur tous les sujets à la fois, sans aucune dépendance. Ensuite **M**, qui dit où
porter l'effort. Puis **C1, C2 et C3**.

## 7. Ce qui existe déjà et sert

- la règle d'or « la voix commande l'image » (`recalerSurVoix`) : base des coupes calées ;
- `cadreur()` et son vocabulaire d'intentions (`objet`, `processus`, …) : base de la
  liste de plans ;
- les paliers complet et léger avec bascule automatique : place naturelle des effets
  coûteux ;
- la chaîne d'allègement des objets (phase A) : sert les couches 1 et 2 ;
- le pod GPU et `studio-orchestrateur` : servent la fabrication de nuit ;
- le banc de vérification image par image : porte d'entrée de tout élément.

## 8. Non vérifié, nommément

- le chiffre −0,33 des détails séduisants (lu dans une synthèse, pas dans l'article) ;
- la page d'aide de NotebookLM (accès au format Cinematic, temps de génération) ;
- le temps de TRELLIS.2 par objet sur notre pod, et sa qualité dans notre style filaire ;
- le temps de Wan 2.2 sur notre pod ;
- les packs Quaternius : licence du fichier livré dans chaque archive ;
- les consignes d'usage NASA et la mention CC0 objet par objet du Smithsonian ;
- le coût de la profondeur de champ sur le TECNO (Mali-G52) ;
- les programmes officiels du Burkina.

## Sources (consultées le 29/10/2026)

Apprentissage
- Höffler et Leutner 2007 : [Leibniz IPN](https://www.leibniz-ipn.de/en/research/publications/instructional-animation-versus-static-pictures-a-meta-analysis), [PDF](https://wikicap.ulb.be/images/e/ef/Hoffler_Leutner_2007.pdf)
- Berney et Bétrancourt 2016 : [EARLI](https://tecfa.unige.ch/perso/sandra/pdf/Earli2016_berney_betrancourt_FINAL.pdf) ; synthèse sur Castro-Alonso 2019 : [Springer](https://link.springer.com/article/10.1007/s11251-021-09541-w)
- Détails séduisants : [ACU](https://inspire.acu.edu.au/articles/seductive-details), [WSU](https://news.wsu.edu/2020/03/19/seductive-details-inhibit-learning/), [QIC](https://www.qic-wd.org/sites/default/files/Umbrella%20Summary%20-%20Seductive%20Details%20in%20Training%20041821.pdf)
- Guidage du regard : [méta-analyse 2016](https://journal.psych.ac.cn/xlxb/CN/Y2016/V48/I5/540), [Boucheix et al.](https://espace.curtin.edu.au/handle/20.500.11937/3517?show=full)
- Guo, Kim et Rubin 2014 : [PDF](https://up.csail.mit.edu/other-pubs/las2014-pguo-engagement.pdf)

Film et réalisation
- Kurzgesagt : [présentation](https://kurzgesagt.org/what-we-do?visit=videos), [10 Studio](https://10.studio/the-incredible-amount-of-work-behind-kurzgesagts-beautiful-animated-videos/)
- MovieAgent : [arXiv 2503.07314](https://arxiv.org/html/2503.07314v1) ; CinemaTraj : [arXiv 2607.26910](https://arxiv.org/abs/2607.26910v1) ; réalisation virtuelle pilotée par le script : [JKCGS](http://journal.cg-korea.org/archive/view_article?pid=jkcgs-32-3-121)
- WorldCoder-Bench : [arXiv 2606.01869](https://arxiv.org/pdf/2606.01869)
- NotebookLM : [blog Google](https://blog.google/innovation-and-ai/models-and-research/google-labs/video-overviews-nano-banana/), [Cinematic](https://thesciencetalk.com/news/notebooklm-cinematic-video-overviews-2026/)
- Post-traitement sur mobile : [Arm](https://developer.arm.com/community/arm-community-blogs/b/mobile-graphics-and-gaming-blog/posts/post-processing-effects-on-mobile-optimization-and-alternatives)
- Theatre.js : [moteur, LICENSE Apache 2.0](https://raw.githubusercontent.com/theatre-js/theatre/main/LICENSE), [éditeur, LICENSE AGPL v3](https://raw.githubusercontent.com/theatre-js/theatre/main/packages/studio/LICENSE) ; pmndrs/postprocessing : [LICENSE](https://raw.githubusercontent.com/pmndrs/postprocessing/main/LICENSE.md)

Éléments et licences
- Poly Haven : [FAQ](https://polyhaven.com/faq) ; Smithsonian : [Khronos](https://www.khronos.org/news/press/khronos-smithsonian-collaborate-to-diffuse-knowledge-for-education-research-and-creative-use) ; NIH 3D : [exemple d'entrée](https://3d.nih.gov/entries/3DPX-013408) ; NASA : [dépôt](https://github.com/nasa/NASA-3D-Resources), [portail](https://science.nasa.gov/3d-resources/)
- Sketchfab : [consignes de l'API de téléchargement](https://sketchfab.com/developers/download-api/guidelines) ; Objaverse-XL : [README](https://huggingface.co/datasets/allenai/objaverse-xl/raw/de861da082fda4f313582528a77cccf8c05183fb/README.md)
- Quaternius et Kenney : [Cinevva](https://app.cinevva.com/game-assets/free-3d-animal-models) (tiers)
- Z-Anatomy : [GitHub](https://github.com/Z-Anatomy/Models-of-human-anatomy) ; ConceptNet : [conceptnet-lite](https://pypi.org/project/conceptnet-lite)
- TRELLIS.2 : [LICENSE MIT](https://raw.githubusercontent.com/microsoft/TRELLIS.2/main/LICENSE), poids MIT (Hugging Face `microsoft/TRELLIS.2-4B`)
- Wan 2.2 : [LICENSE Apache 2.0](https://raw.githubusercontent.com/Wan-Video/Wan2.2/main/LICENSE.txt), poids Apache 2.0 (Hugging Face `Wan-AI/Wan2.2-TI2V-5B`, `Wan2.2-T2V-A14B`) ; temps : [MindStudio](https://www.mindstudio.ai/blog/what-is-wan-2-2-video-open-source), [Magic Hour](https://magichour.ai/blog/ltx-2-3-vs-wan-2-2)
- UniRig : [arXiv 2504.12451](https://arxiv.org/pdf/2504.12451), [LICENSE MIT](https://raw.githubusercontent.com/VAST-AI-Research/UniRig/main/LICENSE), poids MIT (Hugging Face `VAST-AI/UniRig`)
- FLUX.1 schnell : poids Apache 2.0 (Hugging Face) ; dev non commercial : [guide](https://www.promptzone.com/zuzanna_choi/flux-ai-license-key-insights-2g8d)
- Depth Anything V2 : [LICENSE](https://raw.githubusercontent.com/DepthAnything/Depth-Anything-V2/main/LICENSE), Small Apache 2.0 et Large CC-BY-NC (Hugging Face)
- Hunyuan3D : [LICENSE 2.1](https://gitserver.onethingai.com/ai-models/Hunyuan3D-2.1/raw/branch/main/LICENSE)
- Mouvement : [HY-Motion](https://rits.shanghai.nyu.edu/ai/tencent-open-sources-hy-motion-1-0-a-billion-parameter-text-to-motion-ai-model/), [ARDY](https://replicate.com/wanjon/ardy2vrm/readme) (licences NVIDIA et Llama 3 en plus : non retenu)
- Prix GPU : [RunPod, comparatif](https://www.hostinger.com/tutorials/?p=158956), [computeprices](https://computeprices.com/providers/runpod/gpus/rtx4090)
- Licences des poids relevées par l'API Hugging Face (`/api/models/<id>`, champ `license`) le 29/10/2026.
