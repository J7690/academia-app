# Mesure : la brume volumétrique coûte 36 % et ne se voit pas

**Date : 11/08/2026.** Banc exécuté sur pod RunPod A40, Blender 4.5.12 LTS, EEVEE Next.
Machine `42u0p1w0y45u55`, amorcée en **313 s**, coût total de l'expérience **0,375 $**.

---

## Ce qui était supposé

Le relevé du 11/08 avait établi que `matiere_brume()` et `matiere_feu()` sont écrites,
abouties, et **appelées par aucun archétype de production** — seulement par
`essai_style.py`. Le brouillard volumétrique étant l'un des dix éléments de la
grammaire de référence et l'un des trois qui font « cinéma » plutôt que « schéma »,
la conclusion semblait évidente : **le brancher est un gain à coût quasi nul.**

Elle était fausse sur les deux termes.

---

## Le protocole

`atmosphere()` ajoutée dans `style_reference.py`, appelée par `rendre_scene()` entre
l'archétype et la caméra — la brume se dimensionne sur la distance rendue par
l'archétype, et la caméra doit être construite **à l'intérieur** du volume.

Deux passages identiques. Une seule variable change : `STUDIO_BRUME`.
Archétype `reseau`, **1080 × 1920**, **64 échantillons**, 60 images, graine fixe.
Ce sont les valeurs de production : mesurer à une qualité qu'on ne livre pas
donnerait un chiffre sans usage.

---

## Le résultat

| | sans brume | avec brume | écart |
|---|---|---|---|
| régime médian | **2,185 s/image** | **2,982 s/image** | **+36,5 %** |
| P95 | 2,413 s | 3,258 s | +35,0 % |
| première image (shaders) | 20,46 s | 6,04 s¹ | — |
| construction de la scène | 1,34 s | 1,29 s | — |
| **projection sur 2500 images** | **91,0 min** | **124,3 min** | **+33 min** |

¹ La première image du second passage bénéficie du cache de shaders du premier. Le
coût réel de compilation à froid est donc **20,5 s**, une fois par machine.

**Et les deux images témoins sont indiscernables à l'œil.**

> **+33 minutes par capsule pour aucune différence visible.**

---

## Pourquoi elle ne se voit pas — hypothèse fondée, NON mesurée

`matiere_brume` est un `ShaderNodeVolumeScatter` : il **diffuse** de la lumière, il
n'en émet pas. Or :

- ce studio n'a **aucune lampe** — « le style veut que les objets s'éclairent
  eux-mêmes », `style_reference.filaire` ;
- le monde vaut `(0.0015, 0.0045, 0.014)`, c'est-à-dire noir.

Il n'y a donc quasiment **rien à diffuser**. Le brouillard de la référence, lui, est
**éclairé** : ses bandes ont une structure et une lueur.

**Ce point reste une hypothèse.** Le test qui l'aurait tranchée — un passage à densité
treize fois supérieure — n'a pas pu être fait : RunPod avait retiré la machine
(`absent_chez_runpod`) avant que je le lance. À faire lors du prochain passage sur
pod, en une minute.

---

## Décision

**`STUDIO_BRUME` par défaut à `0`.** La brume ne s'allume plus qu'explicitement.

Le code reste en place : le jour où le studio aura une source de lumière, la fonction
est prête et dimensionnée. Ce qu'il ne faut pas faire, c'est monter la densité — le
problème n'est pas la quantité de brume, c'est l'absence de lumière à diffuser.
La rendre visible demanderait d'**ajouter une lampe**, ce qui change le parti pris du
studio et coûterait **davantage**, pas moins.

---

## Ce que cette mesure apprend au-delà de la brume

1. **Le volumétrique est hors de portée d'EEVEE dans notre budget.** +36 % pour un
   seul volume de faible densité, sans lumière. La référence en empile davantage.
   Cela **renforce** l'hypothèse du moteur temps réel, où brouillard, bloom et
   profondeur de champ sont des passes de post-traitement quasi gratuites.
2. **Le régime mesuré, 2,185 s/image, confirme les 2,04 s connus.** La projection de
   91 min pour 2500 images recoupe les 82 à 118 min observés en base sur les capsules
   réelles. Les chiffres de latence tiennent.
3. **La compilation des shaders coûte 20,5 s par machine**, une seule fois. C'est une
   composante du coût fixe `F` : dans un découpage sur N machines, elle est payée
   N fois.
4. **« Écrit mais jamais appelé » ne veut pas dire « oublié ».** Il valait mieux
   dépenser 0,375 $ et vingt minutes pour l'apprendre que de livrer un ralentissement
   de 36 % en croyant embellir l'image.
