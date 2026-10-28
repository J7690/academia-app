# Studio 3D sur le téléphone — inventaire après le premier essai réussi (28/10/2026, soir)

Suite de `STUDIO_ARCHITECTURE_LECTURE_APPAREIL_2026-10-28.md` et de
`RECOMMANDATION_APRES_LWS_2026-10-28.md`. Ce document ne remplace ni l'un ni
l'autre.

## 1. Le point de départ, mesuré

Le 28/10 à 19:40, sur le TECNO LD7 (application 1.0.9+38, `main` = `0f74a80`),
le cours « Le Feu : Comprendre sa Nature et ses Usages » (travail `818a6e6e`) a
été joué de bout en bout. Mesures tirées du journal du téléphone :

| | mesure |
|---|---|
| lecteur prêt | 10,5 s |
| première image parlée, voix à fabriquer | 9,985 s |
| première image parlée en revoyant (voix gardées) | 4,227 s |
| fin de lecture | atteinte deux fois |

Pour y arriver, il a fallu corriger deux défauts que seul l'essai réel a révélés :

- la capsule rangée sous `manifeste.storyboard` (`b8384ca`, plus `studio-voix` v3) ;
- des objets trop lourds : « rivière » pèse 35,8 Mo (`0f74a80`).

**Ce que Jocelyn relève, et que la base confirme** : la vidéo ne montre rien qui
ressemble au feu. Les 4 scènes ne contiennent **aucun geste `convoquer`**, seulement
`sculpter`, `extruder` et `ecrire`. Il n'y a ni bois, ni flamme, ni air.

## 2. Les cinq demandes de Jocelyn, face à l'existant

### 2.1 Des objets qui cadrent avec le sujet, quel qu'il soit

| Ce qui existe | Mesure |
|---|---|
| index Objaverse, licences vérifiées objet par objet (`contours/index_objets.json`) | **69 termes** |
| le générateur connaît exactement ces 69 termes et **n'a pas le droit d'en employer d'autres** (`prompt_capsule.ts:103`, puis « si le sujet n'a aucun objet dans cette liste, n'emploie pas convoquer ») | « feu », « bois », « flamme », « air » : **absents**, d'où la capsule vide d'objets |
| poids de l'index (requêtes HEAD, 28/10) | 1,2 Go en tout, médiane **4,9 Mo**, neurone 370 Mo, cristal 111 Mo, corps humain 77 Mo |
| **jouables sur téléphone avec le plafond de 3 Mo de `0f74a80`** | **25 sur 69** : adn, aimant, bacterie, balance, circuit, engrenage, feuille, foie, globe, goutte, graine, maison, molecule, nuage, oeil, outil, panneau solaire, pile, planete, prisme, puits, pyramide, racine, sang, thermometre |
| la génération en production | **v1** : `whiteboard-generate-storyboard` v70. La v2, avec ses décors corps et gouttes et 50 sujets éprouvés, **n'est pas déployée** |

**À dire franchement** : le plafond de 3 Mo, posé ce soir pour que la lecture
démarre, écarte aujourd'hui le cerveau, le cœur, le volcan, le squelette et le
poumon. C'était le bon choix contre un écran muet, et c'est une perte de qualité
qu'il faut réparer en priorité (§3, P2).

### 2.2 De vraies animations, des accessoires

| Ce qui existe | Ce qui manque |
|---|---|
| la caméra tourne autour de la scène, différemment selon l'intention (`cadreur`, `lecteur.js:424`) | les objets **n'entrent pas en scène** : ils sont là dès la première image |
| décor gouttes : flottement et rotation ; décor corps : foyer rouge et particules (`foyerEtFlux`) | **rien n'est calé sur la phrase** : un mot prononcé ne fait rien apparaître |
| `phrasesDe` découpe déjà la narration en phrases horodatées, pour les sous-titres | pas d'**accessoires** : flèches, étiquettes, mise en évidence d'une partie |

### 2.3 Le logo Academia animé « comme sur TikTok »

| Ce qui existe | Où |
|---|---|
| un filigrane qui saute aux 4 coins toutes les 3 s, opacité 0,35, 8 % de la hauteur, le « bon » système d'après l'audit du 22/07 | `academia_app/lib/games/services/watermark_service.dart` (FFmpeg, jeux seulement) |
| le logo de marque **léger** (5 Ko) | `whiteboard_vision/marque/academia_logo.png` |
| le logo de l'application | `academia_app/assets/ACADEMIA_logo1.png`, **2 Mo**, trop lourd pour le lecteur |
| dans le lecteur 3D | **rien** |

Il suffit de le dessiner dans le calque des sous-titres du lecteur. Il apparaît
alors à la lecture **et** dans le MP4 exporté, avec les mêmes images, puisque le
rendu est une fonction du temps.

### 2.4 Télécharger et envoyer la production depuis le téléphone

| Ce qui existe | Mesure ou état |
|---|---|
| export MP4 dans le lecteur (Mediabunny et WebCodecs), **piste audio comprise** | prototype : **limité à 250 images (10 s)**, `index.html:414` |
| vitesse sur le TECNO | 10 s de vidéo en 21,2 s, soit **≈ 3 min 10 pour 90 s** (extrapolé) |
| enregistrement et partage dans l'application | `saver_gallery` ^4.1.0 et `share_plus` ^10.0.3 **déjà dans le pubspec** |
| le pont entre le lecteur et l'application | **absent** : le canal `Academia` ne transporte que des messages courts |

### 2.5 Une qualité au-dessus du marché

La veille du 28/10 (`STUDIO_CHANGEMENT_DE_PARADIGME_2026-10-28.md` §3.9) a déjà
regardé les outils « faceless » : InVideo, HeyGen, Pictory, Captions. Leur chaîne
assemble un script, des plans tirés d'une banque, une voix et des sous-titres. **On
n'en retient que la méthode** : un plan court par idée, une accroche, des
sous-titres gros et centrés. Ce qui nous distingue de ces outils, c'est la 3D
pédagogique jouée **gratuitement sur l'appareil**. Cette différence ne vaut que
si l'objet montré est le bon : la qualité perçue se joue donc d'abord au §2.1.

## 3. Le plan proposé, dans l'ordre

| # | Quoi | Pourquoi d'abord | Effort (estimé) | Faut-il recompiler l'appli ? |
|---|---|---|---|---|
| **P1** | **Déployer la génération v2.** Les décors corps et gouttes sont éprouvés sur 50 sujets (lot 3) | elle est prête et testée (12 tests) ; c'est elle qui donne l'image de la référence | 1 h | non (Edge Function, **accord de Jocelyn**) |
| **P2** | **Alléger les 69 objets** hors ligne : simplification, Draco ou meshopt, quantification (gltf-transform, MIT), puis hébergement sur Supabase Storage. Cible **≤ 500 Ko** par objet | rend au téléphone les 44 objets écartés (cerveau, cœur, volcan…) et réduit les données mobiles de l'étudiant | 1 jour | non |
| **P3** | **Logo Academia animé** dans le lecteur : saut aux 4 coins toutes les 3 s, comme `watermark_service.dart`, avec le logo de 5 Ko | demande explicite ; présent à la lecture et dans l'export | ½ jour | non |
| **P4** | **Télécharger et partager** : export de la durée entière, barre de progression, transfert du fichier du lecteur vers l'application, puis `saver_gallery` et `share_plus` | demande explicite ; l'étape 4 de la recommandation | 1 à 2 jours | **oui** (nouvel APK ou AAB) |
| **P5** | **Le vocabulaire du sujet** : une carte « notion → objets et accessoires » (le feu → bois, flamme, molécule d'O₂ ; la photosynthèse → feuille, soleil, CO₂…), la liste élargie de 69 à quelques centaines de termes tirés des programmes du Burkina, et des **accessoires procéduraux** sans licence (flamme par particules, molécules boules et bâtonnets tirées d'une formule, flèches, étiquettes) | c'est ce qui manquait au cours sur le feu ; les molécules et la flamme sont des équations, donc à nous (doctrine de `fabriquer_contours.py`) | 3 à 5 jours | non |
| **P6** | **Animer avec la voix** : entrée de chaque geste (tracé du filaire, montée, assemblage) et accessoires qui apparaissent quand la phrase les nomme, à partir des horodatages de `phrasesDe` | « qu'il y ait vraiment de l'animation » ; rester une fonction pure du temps, sans quoi l'export diverge de la lecture | 2 à 3 jours | non |

P1, P2, P3, P5 et P6 se font **côté serveur ou dans le lecteur** : ton
application 1.0.9+38 en profite sans réinstallation. Seul P4 exige un nouveau
paquet.

## 4. Ce qui contredit ou rouvre une décision passée

- **Les images par diffusion (`genere`) restent écartées** : Jocelyn les a
  refusées comme réponse au problème « montrer le sujet ». Ce plan ne les propose pas.
- **Les contours par équation** (`fabriquer_contours.py`) : P5 étend cette
  doctrine aux flammes, molécules et flèches. Elle ne couvre pas un corps ni un
  cerveau, qui restent dans la banque Objaverse, avec leur licence CC-BY **et
  l'attribution affichée**. Le lecteur l'affiche déjà, en haut à droite.
- **TRELLIS.2** (image vers 3D, MIT) pourrait combler les trous de la banque hors
  ligne, mais les licences de ses dépendances NVIDIA **n'ont pas été lues**. À
  lire avant tout usage.

## 5. Non vérifié, nommément

- le gain réel de la compression (P2) : la cible de 500 Ko est une estimation, à
  **mesurer sur « rivière » (35,8 Mo) en premier** ;
- l'export de 90 s sur le TECNO : seuls 10 s ont été mesurés ;
- la tenue de la WebView pendant un export de 3 min si l'étudiant quitte l'écran ;
- le comportement sur des téléphones plus faibles que le TECNO (Itel, Infinix d'entrée de gamme).
