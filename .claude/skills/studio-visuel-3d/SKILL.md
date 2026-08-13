---
name: studio-visuel-3d
description: Travailler sur le Studio visuel 3D d'Academia — la grammaire visuelle de reference, ce qui existe deja dans le moteur, ce qui manque, et les regles de production des capsules animees Blender. A utiliser pour toute tache touchant academia_bobodo_backend/studio_visuel/, les capsules 3D, les archetypes, ou le rendu sur pod GPU.
---

# Le Studio visuel 3D

Deux produits DISTINCTS coexistent dans Academia. Ne jamais les confondre :

| Produit | Moteur | Sortie |
|---|---|---|
| **Tableau manuscrit** | `whiteboard_vision/`, HTML+CSS, Playwright | ecriture a la main animee |
| **Animation 3D** | `studio_visuel/`, Blender EEVEE Next sur pod GPU | capsule 3D |

Faire du tableau le defaut « parce qu'il est plus rapide », c'est **abandonner la
3D**. Cette erreur a deja ete commise et corrigee par Jocelyn.

## La grammaire visuelle de reference

Etablie a partir des references fournies par Jocelyn (30/07, puis 11/08 — TikTok
@matholic.ch). Dix elements :

| # | Element | Etat dans le moteur |
|---|---|---|
| 1 | filaire bleu emissif, aretes en tubes | `filaire()` — `style_reference.py:42` |
| 2 | sommets visibles, points lumineux | **absent** |
| 3 | surface translucide, Fresnel | `matiere_hologramme()` — `:125` |
| 4 | masse volumetrique rouge-orange | `matiere_feu()` — `:309` — **toujours pas branchee, et c'est voulu** |
| 5 | brouillard volumetrique bleu | `matiere_brume()` via `atmosphere()` — branchee le 11/08, debranchable par `STUDIO_BRUME=0` |
| 6 | bloom / halo | `compositing()`, Glare FOG_GLOW — `:456` |
| 7 | profondeur de champ | f/2.8 — `generateur_scenes.py:647` |
| 8 | particules chaudes | partiel, archetype `flux` |
| 9 | terrain en grille + lueur affleurante | `sol_grille()` — `:240` |
| 10 | sous-titres blancs gras incrustes | ASS — `montage.py:149` |

Format : **1080 x 1920 vertical**, 25 i/s (`academia_scene.py:187`).
Palette : bleu `(0.05, 0.28, 0.95)`, rouge `(1.0, 0.06, 0.01)`, fond quasi noir.
Discipline : **deux teintes, jamais trois** — bleu = la structure, rouge-orange =
l'energie expliquee.

**Ce qui manque n'est pas le style. C'est l'OBJET DU SUJET.** La reference montre
un corps humain et un oeuf ; aucune fonction ne sait les convoquer. C'est la cause
mesuree du defaut du 07/08 : « la sociologie » et « la germination » ont produit
la meme suite de formes, parce que 8 archetypes sur 11 n'acceptent que des nombres.

## Les regles de production

1. **La voix commande l'image.** La duree d'une scene est fixee par la narration
   mesuree, pas par un champ `duration_ms`. Le vrai levier sur la duree d'une
   capsule est le **nombre de mots**.
2. **Aucun calcul d'IA sur LWS** — 4 vCPU, pas de GPU. L'IA passe par une Edge
   Function, ou par le pod.
3. **Degradation gracieuse.** On nettoie, on ne rejette pas : rejeter fait perdre
   a l'etudiant ses credits **et** sa video.
4. **Ecrire du code de scene dans la boucle etudiant est impossible.** LL3M met
   ~4 min pour un seul objet ; la cible est P95 < 5 min pour 5-6 scenes. La
   generation de code sort du chemin critique — recettes fabriquees hors ligne,
   mises en cache, instanciees a la demande.

## La porte d'acceptation — six mesures, aucune IA

Le 05/08, une video **noire et muette** a ete livree a un etudiant comme « prete ».
« Noir », « vide », « fige », « muet » sont **mesurables**. Rien ne se publie sans :

1. nombre d'objets mesh dans la scene **> 0** ;
2. part de pixels non-fond sur l'image temoin **> 3 %** ;
3. luminance moyenne **et ecart-type** au-dessus d'un plancher ;
4. `ffmpeg blackdetect` → **0 s** hors fondus declares ;
5. `ffmpeg freezedetect` → **0 s** ;
6. piste audio presente, duree > 0, **RMS** au-dessus d'un plancher.

Un juge par modele de vision peut **refuser** ou **classer**. Il n'a **jamais** le
droit de publier : les juges VLM s'ecartent de 2 points ou plus dans 24 a 30 % des
cas en notation absolue. Les interroger en questions fermees et en duel, jamais
par une note.

## Les pieges deja payes

| Piege | Consequence | Ou |
|---|---|---|
| `convert(target="CURVE")` cree une donnee **sans materiau** | tube gris sur fond noir = invisible, et il n'y a **aucune lampe** dans le studio | `style_reference.py:57` |
| Modificateur Wireframe sur une geometrie **sans faces** | ne produit rien, **en silence** | `style_reference.py:42` |
| Emission du Principled Volume **non multipliee par la densite** | bloc plein, la turbulence est noyee | `style_reference.py:404` |
| `objet.dimensions` lu avant `view_layer.update()` | vaut zero, et **ment** | `style_reference.py:214` |
| ffmpeg concat s'arrete sur un fichier illisible, **code 0** | capsule tronquee livree comme complete | `montage.py` |
| `proto_capture_bf.js` | images blanches — utiliser `snap_still.js` | — |

## Le pod GPU — ce qui coute vraiment

A **chaque** location : demarrage ~3 min 25, puis reinstallation complete
(apt, pip, telechargement de Blender) **~15 min**, puis modele HuggingFace
**~10 min**. Le coût fixe approche la demi-heure.

`install_pod.sh:17` le dit : « la base de l'image Docker de la phase 4 […] tant
qu'elle n'existe pas, il faut le rejouer a chaque location ». **Docker est
installe sur LWS** avec 136 Go libres, et `studio-orchestrateur` passe deja
`imageName`. L'image maison est le seul levier identifie qui attaque directement
le temps d'attente sans toucher a l'architecture.

Attention : `install_pod.sh` et le script en ligne de `studio_amorceur.py:156`
**divergent** (ComfyUI n'est installe que par le premier). **C'est l'amorceur qui
tourne en production.**

## Atmosphere generique vs energie du sujet — la distinction qui tranche

`atmosphere()` (la brume) est branchee dans `rendre_scene`. `matiere_feu` ne l'est
pas, et ne doit pas l'etre tant que `convoquer` n'existe pas :

| | brume | feu |
|---|---|---|
| ce que c'est | une **ambiance** | l'**energie d'un objet** |
| ou ca vit | partout, quel que soit le sujet | DANS quelque chose — le thorax, la graine |
| brancher partout ? | oui, c'est son role | **non** — ce serait une colonne de feu decorative dans chaque capsule |

Brancher le feu generiquement produirait exactement « la forme preenregistree
utilisee a tous les cours » que Jocelyn a refusee. Il attend un sujet ou se loger.

**La regle generale** : avant de brancher un element de style, demander s'il
habille la scene ou s'il DIT quelque chose. Ce qui dit quelque chose a besoin d'un
referent ; sans referent, ca devient du decor, et le decor identique d'un cours a
l'autre est le defaut qu'on corrige.

## Ce qui est deja tranche

- **`genere` (images par diffusion) a ete refuse par Jocelyn** comme reponse au
  probleme « montrer le sujet ». `capsules/chaleur_corps.json` en contient une
  tentative visant exactement la reference. Ne pas le represerver comme neuf.
- **Les contours SVG sont generes par equations**, pas telecharges — pour la
  tracabilite (`contours/fabriquer_contours.py`). Cinq formes existent. Cette
  doctrine tient pour les formes geometriques ; elle ne peut pas produire un corps
  humain. Les deux voies coexistent : le dire, ne pas trancher en silence.
- **Le format court est cible 90-150 s**, 5-6 scenes, budget de 250 mots.

## Avant de toucher au moteur

Charger `etat-des-moyens` (relever, ne pas supposer), `continuite-du-chantier`
(ce qui est deja decide) et `veille-externe` (comment font les autres). Le Studio
a coûte cher en diagnostics repetes ; ces trois-la existent pour ca.
