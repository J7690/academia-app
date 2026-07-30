# Chronogramme — Studio visuel Academia

> Établi le **30/07/2026** par le chef de projet, à suivre sans validation
> intermédiaire. Chaque phase se termine par une **preuve mesurée**, pas par
> une impression.
>
> **Objectif** : produire des capsules verticales de très haute qualité sur
> **n'importe quel sujet** — médecine, archéologie, histoire, géographie,
> religion, art, musique, agroalimentaire — avec voix naturelle et son.

---

## Principe directeur

Les références analysées (`mathoholic.ch`, quatre vidéos) ne sont pas quatre
styles : c'est **une grammaire appliquée à des sujets différents**. Et surtout,
elles ne dessinent pas un schéma à côté du propos — **elles rendent le propos
lui-même en géométrie lumineuse**.

C'est de là que vient l'universalité. On ne modélisera jamais un violon, une
molécule et une pyramide. Mais **toute discipline se ramène à sept formes** :

| Forme | Ce qu'elle montre | Exemples de thèmes |
|---|---|---|
| `titre` | le sujet en toutes lettres | tous |
| `silhouette` | un contour quelconque en volume | médecine, archéologie, musique, agro |
| `reseau` | des relations | généalogie, écosystèmes, commerce |
| `flux` | ce qui circule | sang, migrations, nutriments, son |
| `strates` | ce qui se superpose | **stratigraphie**, géologie, périodes |
| `ondes` | ce qui se propage | son, chaleur, épidémie, influence |
| `chronologie` | ce qui se succède | histoire, archéologie, biographie |

`strates` **est** littéralement la stratigraphie archéologique. `flux` **est**
la circulation sanguine autant que la route de la soie. Le vocabulaire porte
plus loin qu'il n'y paraît.

---

## Phase 0 — Vérifier ce qui est déjà écrit

**Pourquoi d'abord** : six archétypes, les sous-titres et l'assemblage sont
écrits mais jamais vus. Deux bugs invisibles ont déjà coûté une demi-journée —
l'émission volumétrique et le modificateur Wireframe. Aucun n'apparaissait dans
un journal ; il a fallu ouvrir l'image.

- une seule location groupée, tout d'un coup
- les six archétypes, sous-titres incrustés, assemblage, dépôt dans le bucket
- **preuve** : un MP4 lisible dans `studio-visuel`, vérifié par `ffprobe`

**Coût** ~0,25 $ · **Bloque tout le reste**

---

## Phase 1 — L'universalité des thèmes

Trois briques manquent pour couvrir toutes les disciplines :

**`silhouette`** — importe un contour SVG et l'extrude en hologramme. C'est la
brique décisive : un organe, un os, un pays, un instrument, une feuille, un
bâtiment, un symbole. **Des fichiers SVG de quelques kilo-octets remplacent des
semaines de modélisation 3D.**

**`chronologie`** — une frise dans l'espace, jalons qui s'allument.

**`carte`** — un territoire, des points, des routes.

Plus une **bibliothèque de contours** par discipline, et le registre d'assets
qui trace pour chacun : origine, auteur, licence, droit commercial.

**Preuve** : une capsule rendue dans trois disciplines sans écrire une ligne de
code nouvelle.

---

## Phase 2 — La voix

L'exigence est explicite : **naturelle, pas robotique**.

État actuel : la voix passe par OpenRouter, avec repli sur `gTTS` — ce dernier
est franchement robotique et ne tiendra pas la comparaison.

Décision : **ElevenLabs multilingue**, qui reste la référence en français
(MOS 4,14 ; 82 % de mots correctement prononcés contre 77 % pour OpenAI).
Tarif ~0,10 $ les 1 000 caractères, soit **~0,15 $ par capsule** de 250 mots.

Travail associé, qui compte autant que le moteur :
- narration **écrite pour l'oreille** — phrases courtes, aucune parenthèse,
  aucun sigle non explicité ;
- `TTS_SPEED` calé comme sur le Smart Whiteboard (~150 mots/min) ;
- normalisation `loudnorm` pour un niveau constant d'une capsule à l'autre.

**Il me faut de toi** : un compte ElevenLabs et sa clé d'API, déposée dans les
secrets Supabase. Je ne crée pas de compte et je ne paie pas.

---

## Phase 3 — Musique et sound design

Le Smart Whiteboard possède déjà `whiteboard_sound_design.py` — bruitages
synthétisés et *ducking* musical. **On le porte, on ne le réécrit pas.**

- nappe musicale sous la voix, atténuée automatiquement quand elle parle ;
- accents sonores sur les révélations et les transitions ;
- **question de licence à trancher** : une musique entièrement générée par IA
  n'est pas protégée par le droit d'auteur dans la plupart des juridictions en
  2026 — c'est la licence du fournisseur qui gouverne, pas une propriété que tu
  détiendrais. Pour une plateforme commerciale, une bibliothèque sous licence
  classique est plus sûre.

---

## Phase 4 — L'automatisation

Aujourd'hui **je crée les machines à la main**. C'est le plus gros écart
opérationnel qui reste.

- une tâche `pg_cron` détecte une file non vide et appelle `runpod-pod` ;
- le pod prend le travail, rend, dépose, et s'éteint quand la file est vide ;
- le veilleur reste le filet.

**Preuve** : une capsule mise en file produit un MP4 sans aucune intervention.

---

## Phase 5 — L'interface éditoriale

Un administrateur crée la capsule, prévisualise, valide, publie au feed.
Jamais de publication automatique — le cahier des charges l'interdit.

**Ce n'est pas une fonction étudiante.** Une capsule demande 25 à 40 minutes et
coûte 0,20 à 0,60 $ ; le Smart Whiteboard, lui, promet une image en 15 secondes.
Deux produits distincts : le Whiteboard fabrique un cours **pour un** étudiant,
le Studio fabrique le contenu **que tout le feed** regarde.

---

## Phase 6 — L'image Docker

Chaque location repaie aujourd'hui 15 minutes d'installation. Une image
préconstruite ramène ça à quelques secondes, et c'est le préalable au mode
Serverless — qui facture à la seconde et retombe à zéro tout seul.

---

## Discipline de coût

Leçon payée : sur une machine de 66 minutes, **12 minutes de calcul** et le
reste en attente pendant que je réfléchissais.

**Règle** : tout préparer hors ligne, lancer **une fois**, la machine rend tout,
on récupère, elle s'éteint. Jamais de va-et-vient interactif sur une ressource
au compteur.

Garde-fous en place : inactivité, silence de l'agent, durée maximale de 4 h —
soit **1,76 $ au pire** pour une machine oubliée.

---

## Veille externe

**Tous les quinze jours**, et systématiquement avant d'engager une dépense :
moteurs de rendu, modèles de voix, tarifs GPU, formats des plateformes.

Le rythme du domaine impose de vérifier plutôt que de se souvenir : la mesure
EEVEE contre Cycles a donné 2,4× là où j'avançais 10× d'après une intuition.

---

## Ce qu'il me faut de toi, et que je ne peux pas obtenir seul

1. **Une clé d'API ElevenLabs** — création de compte et paiement.
2. **Une décision sur la musique** : bibliothèque sous licence, ou génération.
3. **Le rechargement des crédits RunPod** quand les 8,70 $ restants s'épuisent.
4. **La relecture des contenus sensibles** — un médecin pour la santé, comme
   déjà signalé pour les jeux cliniques.

Tout le reste, je le fais.
