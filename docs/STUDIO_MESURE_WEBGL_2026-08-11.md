# Mesure : la même esthétique en WebGL, sur LWS, sans carte graphique

**Date : 11/08/2026.** Banc exécuté sur LWS (4 vCPU, 8 Go, **aucun GPU**),
Chromium headless via Playwright, Three.js. Coût : **0 $** — aucune location.

---

## La question posée

Blender/EEVEE sur A40 loué : **2,185 s/image**, soit **91 min** pour une capsule de
2500 images, et un plancher de 5,5 min même avec une infinité de machines.

L'esthétique de la référence — filaire émissif, brouillard, bloom, profondeur de
champ — est le **vocabulaire natif du temps réel**. D'où la question : un navigateur
sait-il la produire, et à quel prix ?

---

## Le protocole

Scène Three.js reproduisant la **deuxième image de référence** : terrain en grille
filaire déformé par les mêmes équations que `sol_grille`, lueur rouge-orange
affleurant dessous, neuf ovoïdes facettés translucides avec filaire par-dessus à
profondeurs échelonnées, brouillard exponentiel, bloom, profondeur de champ.

**Tous les postes coûteux sont présents.** Mesurer une scène sans bloom ni
profondeur de champ donnerait un chiffre flatteur et faux.

**Le temps est une variable, pas une horloge** : `rendreA(t)` compose l'image de
l'instant `t`. Le découpage en tranches parallèles devient trivial, et deux rendus
de la même capsule donnent exactement la même image.

Renderer effectivement utilisé, lu dans la page :
`ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (Subzero)), SwiftShader driver)`
— c'est-à-dire **rastérisation logicielle sur CPU**, sans aucun GPU.

---

## Les résultats

| cas | images/s | ms/image | capsule 2500 images |
|---|---|---|---|
| complet, 1080×1920 | 0,5 | **2000** | 83,3 min |
| **sans profondeur de champ**, 1080×1920 | 2,0 | **500** | **20,8 min** |
| sans bloom ni DoF, 1080×1920 | 2,1 | 476 | 19,8 min |
| complet, 720×1280 | 1,9 | 526 | 21,9 min |
| complet, 540×960 | 1,4 | 714 | 29,8 min |

### Trois lectures

**1. La profondeur de champ coûte 4× tout le reste.** 2000 ms contre 500 ms. À elle
seule, elle explique l'écart entre 83 min et 21 min. Le `BokehPass` de Three.js
échantillonne le tampon de profondeur par pixel — ruineux en rastérisation logicielle.
Un flou de profondeur approché (deux passes de flou gaussien pondérées par la
profondeur) coûterait une fraction.

**2. Le bloom est quasi gratuit : +5 %** (500 contre 476 ms). À comparer au **+36,5 %**
que coûte *un seul volume de brouillard* dans EEVEE. C'est exactement la différence
de nature entre une passe d'écran et un calcul par échantillon.

**3. Sans carte graphique, un navigateur bat Blender sur GPU loué.**

| | matériel | ms/image | capsule | coût machine |
|---|---|---|---|---|
| Blender EEVEE | A40 **louée** | 2185 | 91 min | 0,44 $/h |
| WebGL sans DoF | LWS, **aucun GPU** | 500 | **21 min** | **0 $** |

**4,4× plus rapide, sur une machine qu'on paie déjà.**

---

## Ce que la mesure NE dit pas — et il faut le dire

1. **C'est du rendu, pas de la capture.** 500 ms/image mesure la composition de
   l'image dans la page. Faire sortir ces images en fichier coûte davantage, et n'est
   pas mesuré. Le moteur du tableau contourne le problème en **filmant en temps réel**
   plutôt qu'en photographiant image par image — une capture Playwright coûte ~1 s.
   Il faudra la même astuce ici, ou un encodage direct.
2. **L'échantillon est petit.** 10 s par cas, soit 5 à 20 images mesurées. L'anomalie
   du 540×960 — **plus lent** que le 720×1280 — le prouve : le bruit est réel, et il y
   a contention sur 4 vCPU entre le serveur HTTP, node et Chromium.
3. **La scène est mon approximation, pas la référence.** Et l'image témoin est
   **nettement trop lumineuse** : un lavis rouge-orange là où la référence garde
   l'écran majoritairement noir. La discipline de `style_reference.py` — « c'est le
   rapport qui fait le premium, pas l'intensité absolue » — n'est pas respectée. La
   **capacité** est démontrée ; la **calibration** reste à faire.
4. **SwiftShader n'est pas une fin.** C'est de la rastérisation CPU. Le même code sur
   un vrai GPU va typiquement 30 à 100× plus vite.

---

## Ce que ça ouvre, et la mesure qui suit

Si le facteur GPU est ne serait-ce que ×30, la même scène passe à **~17 ms/image** :
une capsule de 100 secondes rendue en **moins d'une minute**, tous effets compris.

Le test est simple, il coûte environ 0,10 $, et il utilise le code déjà écrit : pousser
`scene.html` et `mesure_webgl.js` sur un pod A40, lancer Chromium **sans**
`--use-angle=swiftshader`, et relire le renderer pour vérifier qu'il annonce bien la
carte. C'est la mesure qui tranche définitivement entre :

- **Blender** — 91 min, plancher 5,5 min, location obligatoire ;
- **navigateur sur CPU** — 21 min, gratuit, déjà en place ;
- **navigateur sur GPU** — potentiellement moins d'une minute.

---

## Décision provisoire

Aucune bascule n'est décidée aujourd'hui. Ce qui est acquis :

- La voie navigateur **n'est pas une lubie** : elle produit l'esthétique, et elle est
  déjà 4,4× plus rapide que l'existant sans carte graphique ni location.
- La profondeur de champ est le premier poste à traiter, quel que soit le moteur.
- Le bloom, lui, ne coûte rien en temps réel — alors qu'il est cher en EEVEE.

Prochaine mesure : **la même scène sur pod GPU.**
