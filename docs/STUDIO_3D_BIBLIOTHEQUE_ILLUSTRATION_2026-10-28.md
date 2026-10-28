# Studio 3D — une bibliothèque qui illustre vraiment le sujet (28/10/2026, nuit)

Suite de `STUDIO_3D_INVENTAIRE_APRES_PREMIER_ESSAI_2026-10-28.md`. La question de
Jocelyn : comment compacter les objets **sans perdre leur qualité**, et que
faut-il pour couvrir le plus de sujets possible, **avec de l'animation** ? Ses
exemples : de l'eau qui coule entre des cailloux, une forêt avec des oiseaux, des
serpents, des mouches et des souris. Son critère : « l'idée de la vidéo, c'est
l'illustration ». Une vidéo qui n'illustre pas ne fait pas mieux qu'un document écrit.

## 1. La réponse courte

1. **Le compactage ne coûte presque rien en qualité, parce que l'essentiel du poids
   ne s'affiche jamais.** Le lecteur n'utilise que la forme des objets, qu'il habille
   de notre verre, de nos arêtes et de nos points (`lecteur.js:221`). Retirer
   textures, couleurs et coordonnées de texture divise déjà le poids par 50 à 100
   sans toucher un seul triangle. Mesuré, §2.
2. **Une bibliothèque d'objets ne suffit pas.** Elle couvre au mieux la moitié des
   sujets réellement demandés (§3). Il faut sept étagères : objets, créatures
   animées, phénomènes, milieux, mathématiques, idées et société, accessoires
   (§4). Ce sont des étagères **fermées** : l'IA choisit dans un catalogue et
   n'invente rien (§5).

## 2. Le compactage — mesuré sur nos propres objets

Outil : gltf-transform 4.5.1 et meshoptimizer 0.22, tous deux **MIT** (licence lue
dans les paquets). Script : retrait de tout sauf la position des sommets, soudure,
simplification jusqu'à un plafond de triangles, puis compression meshopt.

| objet | poids actuel | triangles d'origine | allégé à 20 000 triangles |
|---|---|---|---|
| cerveau | 6,9 Mo | 18 003 | **72 Ko**, sans retirer **aucun** triangle |
| arbre | 9,5 Mo | 16 775 | **126 Ko**, sans retirer aucun triangle |
| cœur | 8,7 Mo | 258 171 | 93 Ko |
| poumon | 9,7 Mo | 133 944 | 98 Ko |
| oiseau | 27,6 Mo | 771 326 | 107 Ko |
| rivière | 35,8 Mo | 1 000 000 | 106 Ko |
| corps humain | 76,7 Mo | 2 330 624 | 110 Ko |

**À l'écran.** Dans le vrai lecteur, corps humain et oiseau, l'original et la
version allégée à 20 000 triangles ne se distinguent pas. Notre style filaire
lumineux ne montre pas un détail plus fin, et au-delà de 3 000 triangles le lecteur
ne trace déjà plus que les arêtes vives (`EdgesGeometry`).

**Le défaut trouvé, et réglé dans l'essai.** Une version **quantifiée** (positions en
entiers sur 16 bits) donne un **écran blanc** pour l'oiseau. Le lecteur applique la
transformation du nœud *dans* ces entiers, qui se retrouvent écrêtés. Sans
quantification, l'oiseau pèse 147 Ko et s'affiche parfaitement. Deux sorties
possibles : convertir en flottants dans `convoquer` (une ligne) ou ne pas quantifier.

**Ce qu'on y gagne** : les 69 objets reviennent sur le téléphone (25 seulement passent
aujourd'hui), chacun autour de 100 Ko au lieu de 4,9 Mo en médiane. Les données
mobiles de l'étudiant et le temps de chargement baissent d'autant.

## 3. Ce que les étudiants demandent réellement

- Capsules 3D en base : **46 capsules, 231 scènes, dont 36 montrent un objet réel
  (15,6 %)**. Les autres sont des formes abstraites, comme le feu de ce soir.
- Sujets demandés au tableau (`app.whiteboard_projects`, 273 projets, environ 40
  sujets réels une fois les essais retirés) :

| famille | part | exemples réels |
|---|---|---|
| le monde concret | ≈ la moitié | eau, feu, foudre, volcan, pluie, nuages, germination, photosynthèse, cerveau, pétrole, ventilateur, paléontologie, électricité, univers, Archimède |
| mathématiques | 9 | dérivées, primitives, continuité, domaine de définition, loi normale, probabilités, topologie, système décimal |
| économie et société | 9 | marketing, économétrie, macro-économie, sociologie, management de projet, rendement |
| langue | 1 | ce, cet, cette |

**Conséquence** : même parfaite, une bibliothèque d'objets ne sert qu'une moitié des
sujets. Une dérivée ne se convoque pas, elle se **trace**.

## 4. Les sept étagères

Toutes restent des **fonctions pures du temps**. C'est ce qui garantit que la vidéo
téléchargée est image pour image celle qu'on a vue.

| # | étagère | ce qu'elle contient | d'où ça vient | comment ça s'anime |
|---|---|---|---|---|
| 1 | **objets** | cerveau, volcan, pyramide, tracteur… quelques centaines à terme | Objaverse (CC-BY, attribution affichée), allégés par §2 | entrée en scène, rotation, coupe |
| 2 | **créatures animées** | oiseaux, poissons, serpent, souris, insectes, bétail, humains | **Quaternius, CC0 vérifié** (12 animaux de plus de 12 animations, en glTF) ; Kenney, CC0 | squelette glTF lu par `AnimationMixer.setTime(t)`, présent dans notre Three.js |
| 3 | **phénomènes** | eau qui coule, feu, pluie, foudre, nuages, vent, évaporation, électricité, chute, croissance | **équations** : particules et shaders, sans fichier ni licence | le phénomène EST le mouvement |
| 4 | **milieux composés** | forêt, rivière avec cailloux, savane, océan, champ, ciel étoilé, ville | assemblage des étagères 1 à 3 : arbres répétés, cailloux, courant, faune | la faune suit des trajectoires calculées : vol, nage, reptation |
| 5 | **mathématiques** | courbe, tangente qui glisse, aire sous la courbe, cloche de Gauss, repère, suite, géométrie | équations | tracé progressif, point mobile, remplissage |
| 6 | **idées et société** | foule, groupes, flux d'argent, graphiques animés, frise du temps, carte | équations, plus les silhouettes humaines | barres qui montent, flux qui circulent |
| 7 | **accessoires** | flèches, étiquettes, loupe, coupe, mise en évidence, compteur | équations | ils apparaissent **quand la phrase les nomme** |

**Les exemples de Jocelyn, assemblés.**
- *L'eau qui coule* : un lit de rivière, des cailloux répétés, un courant de
  particules le long du lit et des reflets qui glissent (étagères 3 et 4).
- *La forêt* : des arbres de 2 ou 3 modèles répétés et variés, des oiseaux qui
  traversent, un serpent qui ondule au sol, un nuage de mouches et une souris
  (étagères 2 et 4).
- *Le feu de ce soir* : bois et bûches (étagère 1), flamme et fumée (étagère 3), une
  molécule O₂ tracée par équation (étagère 5), et une flèche « oxygène » qui
  apparaît sur le mot (étagère 7).

## 5. Pour que l'IA illustre au lieu d'inventer

- **Un catalogue fermé et versionné**, avec un identifiant par élément. Le
  générateur ne peut citer que ce qui existe. C'est déjà la règle des 69 termes ;
  elle s'étend aux sept étagères. `validate_capsule.ts` continue de **nettoyer**,
  jamais de rejeter.
- **Une carte « notion → éléments »** construite hors ligne. Le feu appelle bois,
  flamme, fumée, O₂ et chaleur ; la photosynthèse appelle feuille, soleil, CO₂ et
  sucre. Le modèle part de cette carte au lieu de chercher seul dans une liste.
- **Un banc de couverture automatique** : 200 sujets tirés des programmes du
  Burkina, et pour chacun la part de scènes qui montrent un élément pertinent. La
  cible est de passer de **15,6 % à plus de 80 %**. Un juge par modèle de vision
  peut **classer** en duel, jamais publier (doctrine du Studio).

## 6. Ce qui a été cherché pour contredire

- **Le style des créatures CC0** est *low poly*. Dans notre filaire lumineux,
  c'est plutôt un atout, puisqu'il donne des arêtes nettes. **Non vu à l'écran.**
- **Les créatures animées ne passent pas telles quelles** : `convoquer` copie la
  forme figée (`applyMatrix4`), ce qui casse le squelette, et les arêtes vives ne
  suivent pas une déformation. Il faut un habillage propre aux objets animés,
  avec un filaire porté par le matériau.
- **Le marché** : Vyond, référence de la vidéo à bibliothèque, revendique « des
  dizaines de milliers » d'éléments animés. C'est un chiffre de tiers, non
  officiel. Quand un élément manque, Vyond le génère (« Text to Prop »). Notre
  équivalent hors ligne serait TRELLIS.2, mais les licences de ses dépendances
  NVIDIA **ne sont toujours pas lues**. On ne rivalisera pas sur le nombre. On peut
  rivaliser sur la **pertinence pédagogique**, grâce à la carte notion → éléments.
- **Smithsonian** (CC0, scans de musée, idéal pour la paléontologie et l'histoire) :
  la page des conditions a refusé la lecture (HTTP 403). **Non vérifié.**
- **Poly Pizza** : la licence varie d'un modèle à l'autre. À lire objet par objet.

## 7. Le plan, chiffré

| phase | contenu | effort (estimé) | nouvel APK ? |
|---|---|---|---|
| A | chaîne d'allègement, les 69 objets sur Supabase, correctif de lecture, plafond relevé | 1 à 2 jours | non |
| B | phénomènes (eau, feu, pluie, foudre, nuages, vent, croissance) et accessoires | 3 à 4 jours | non |
| C | créatures animées Quaternius et milieux composés (forêt, rivière, savane, océan) | 3 à 5 jours | non |
| D | étagères mathématiques et société | 3 à 4 jours | non |
| E | catalogue fermé, carte notion → éléments, consigne du générateur, validation, banc de 200 sujets | 2 à 3 jours | non |

Total : **environ trois semaines** de travail, tout côté lecteur et serveur. Ton
application en profite sans réinstallation. Le téléchargement et le partage (P4 de
l'inventaire) restent à part, et c'est lui qui demande un nouvel APK.

## 8. Non vérifié, nommément

- le temps de décodage meshopt sur le TECNO (seul le PC a été mesuré) ;
- l'allègement des 62 autres objets de l'index (7 mesurés) ;
- le rendu des créatures Quaternius dans notre style ;
- la licence du fichier livré **dans** chaque archive Quaternius (seuls la FAQ et
  les pages des packs ont été lus) ;
- les conditions de la Smithsonian.

## Sources (consultées le 28/10/2026)

- Quaternius : [FAQ](https://quaternius.com/faq.html), [Ultimate Animated Animal Pack](https://quaternius.com/packs/ultimateanimatedanimals.html)
- Kenney : [support et licence](https://kenney.nl/support)
- Poly Pizza : [conditions](https://poly.pizza/docs/tos)
- Smithsonian Open Access : [FAQ](https://www.si.edu/openaccess/faq) (HTTP 403), [annonce de 2020](https://www.cgchannel.com/2020/03/get-2000-free-3d-models-from-the-smithsonian-collection/)
- Vyond : [Wikipédia](https://en.wikipedia.org/wiki/Vyond), [annonce de Vyond Go](https://trainingindustry.com/press-release/content-development/vibrant-business-videos-in-seconds-vyond-introduces-first-ever-prompt-based-script-and-video-creator/)
- Mesures : `academia_bobodo_backend/studio_visuel/outils_objets/alleger.mjs` (essai : `npm i @gltf-transform/core@4 @gltf-transform/functions@4 @gltf-transform/extensions@4 meshoptimizer@0.22`, puis `node alleger.mjs <entrée> <sortie> 8000,20000,60000`) ; poids de l index relevés par requêtes HEAD.
