# Studio visuel — ce que contiennent vraiment les capsules livrées

> **05/08/2026, soirée.** Suite de `STUDIO_VISUEL_REPRISE_2026-08-05.md`.
> Point de reprise n°2 : *« revoir visuellement les dix archétypes »*.
>
> Fait **sans louer de machine — 0,00 $**, en récupérant les deux capsules déjà
> déposées dans Storage et en les regardant.

---

## Ce qui a changé de statut

Jusqu'ici, « `comparaison` sort noir » était une **note**, sans mesure attachée.
C'est désormais un fait, établi sur l'artefact réel — et il s'accompagne d'un
défaut dans le garde-fou écrit le matin même.

---

## Les deux capsules, scène par scène

Les deux seules capsules jamais déposées ont été récupérées, mesurées, et
**regardées image par image**.

### `chaleur_corps` — 19,6 s, déposée le 05/08 à 13:41

| Scène | Archétype | Luminosité | Ce que l'image montre |
|---|---|---|---|
| accroche | `genere` | 1,11 | **noir**, seul le sous-titre |
| sueur | `genere` | 1,11 | **noir**, seul le sous-titre |
| seuil | **`comparaison`** | **1,09** | **noir**, seul le sous-titre |
| sortie | `flux` | 14,87 | spirale de particules, nette |

### `phase4_auto` — 15,2 s, déposée le 31/07

| Scène | Archétype | Luminosité | Ce que l'image montre |
|---|---|---|---|
| ouverture | `titre` | 7,07 | barre lumineuse — **mais illisible**, vue par la tranche |
| territoire | `carte` | 3,87 | un motif doré, petit mais présent |
| temps | `chronologie` | 5,94 | frise visible |
| propagation | `ondes` | 7,46 | disque vert, visible |

**Trois scènes sur huit sont vides.** Les cinq autres ont du contenu — parfois
maigre, jamais absent.

---

## Deux causes distinctes produisent le même noir

C'est le résultat qui change le plan de reprise.

`accroche` et `sueur` sont des scènes **`genere`** : leur noir vient de la
génération d'image par IA, et l'hypothèse en cours est un débordement du VAE.

`seuil` est une scène **`comparaison`** : **procédurale, sans la moindre image
IA**. Blender construit la géométrie, l'éclaire par émission, et rend. Le noir
ne peut donc pas avoir la même cause.

> **Corriger `produire_image` ne réparera pas `comparaison`.**
> Il y a deux défauts, et le plan de reprise n'en suivait qu'un.

### Ce que `comparaison` a de particulier

Mesuré, pas supposé : `comparaison` rend **exactement autant de lumière qu'une
scène sans aucune image** (1,09 contre 1,11). Ce n'est donc pas « trop sombre » :
il n'y a **rien** à l'écran.

Or `comparaison` est le seul archétype dont la totalité du contenu passe par
`style.filaire()` — deux maillages d'arêtes convertis en courbes biseautées, et
rien d'autre. `flux`, qui fonctionne, contient aussi une courbe (son rail) mais
survit grâce à ses 55 sphères, qui ne passent pas par `filaire()`.

**Hypothèse à mesurer, pas à croire :** `style.filaire()` ne produit toujours
rien sur les maillages en *réseau*. `bpy.ops.object.convert(target="CURVE")`
travaille sur des chaînes de segments ; les sommets reliés à trois arêtes ou
plus n'ont pas de représentation en courbe. Or `comparaison` relie **toutes**
les paires de nœuds distantes de moins de 1,7 — un graphe dense.

Prédiction falsifiable qui va avec : `reseau` devrait, lui aussi, être **sans
liens** (mais ses sphères le sauvent), tandis que `strates`, `carte` et
`chronologie` — des cercles et des chaînes — doivent passer. Les deux dernières
sont effectivement visibles ci-dessus. **`reseau` n'a jamais été rendu :** c'est
le prochain essai à faire, et il coûte une scène.

---

## Le garde-fou du matin refusait des capsules correctes

Le contrôle `scenes_sombres`, ajouté le 05/08 au matin, a été passé sur les deux
capsules réelles. Résultat :

| | Attrapait le noir | Refusait à tort |
|---|---|---|
| Version du matin (image entière, seuil 6,0) | 3 scènes ✅ | **4 scènes** ❌ |

Les quatre scènes de `phase4_auto` mesuraient entre 5,05 et 5,99 — toutes sous
le seuil de 6,0, **toutes visibles**. Comme `executer_capsule` ne dépose rien
quand une scène est déclarée noire, la capsule entière était perdue.

### Pourquoi la mesure était fausse

Elle moyennait l'image entière. Or l'image entière contient deux choses qui ne
disent rien du rendu :

1. **les bandes noires du cadre cinéma** — 38 % de la hauteur, noires *par
   construction* : un lest constant qui écrase toutes les valeurs ;
2. **le sous-titre incrusté** — blanc vif sur fond noir.

Le second est le plus traître, et c'est mesurable : sur une scène **également
noire**, deux lignes de sous-titre pèsent 4,18 et trois lignes pèsent 5,91. Le
seuil de 6,0 tombait entre les deux. **Il séparait des longueurs de phrase, pas
des images.**

C'est le défaut n°7 pour la troisième fois — un contrôle qui regarde le mauvais
agrégat — et cette fois il ne livrait plus du noir : il jetait du bon.

### Le correctif

On mesure la **bande réellement rendue, sous-titre exclu**. La fenêtre est
dérivée des constantes existantes (`PROPORTION_CINEMA`, et la marge du
sous-titre calculée par `ecrire_sous_titres`), pas estimée à l'œil.

La séparation devient franche :

```
plancher sans image      1,11
plus faible scène visible 3,87   (carte)
seuil retenu              2,00   -- milieu géométrique, x1,8 / x1,9
```

Le seuil est placé au milieu **géométrique** : ces valeurs se comparent en
rapports, pas en écarts. Et il penche du côté qui livre, parce que **le coût
des deux erreurs n'est pas le même** — laisser passer une scène noire abîme une
capsule, refuser à tort les fait toutes perdre.

### Vérification

Les huit scènes, confrontées à ce que l'œil voit :

```
accroche    genere        oeil=NOIRE     garde-fou=REJETEE   OK
sueur       genere        oeil=NOIRE     garde-fou=REJETEE   OK
seuil       comparaison   oeil=NOIRE     garde-fou=REJETEE   OK
sortie      flux          oeil=visible   garde-fou=acceptee  OK
ouverture   titre         oeil=visible   garde-fou=acceptee  OK
territoire  carte         oeil=visible   garde-fou=acceptee  OK
temps       chronologie   oeil=visible   garde-fou=acceptee  OK
propagation ondes         oeil=visible   garde-fou=acceptee  OK
```

**8 sur 8, aucun désaccord.**

Le contrôle global, lui, ne rattrape plus `chaleur_corps` seul (4,46 pour une
capsule aux trois quarts noire). C'est voulu : sa question est « y a-t-il une
image », pas « chaque scène tient-elle ». C'est le contrôle par scène qui
tranche.

---

## Deux constats à ne pas perdre

**Les deux capsules déposées sont MUETTES.** `a_du_son = False` sur les deux,
alors que `narration.wav` (3,7 Mo) est bien dans Storage pour `chaleur_corps`.
Le code ne fait qu'en avertir. Aucun étudiant n'a donc jamais reçu une capsule
sonore.

**`titre` est visible mais illisible.** La scène rend une barre lumineuse vue
par la tranche : le texte existe, il n'est pas orienté vers la caméra. La
mesure de luminosité ne pouvait pas l'attraper — elle ne sait pas lire. Seul le
regard le voit, ce qui justifie la revue visuelle archétype par archétype.

---

## Ce qui reste ouvert

1. **Cause de `comparaison`** — hypothèse `style.filaire()` sur graphe dense,
   ci-dessus. Test : rendre une scène `reseau` et regarder si les liens sont là.
2. **Cause du noir de `genere`** — inchangée, exige un GPU.
3. **Narration jamais jointe** — à reprendre, indépendant des deux précédents.
4. **`titre` illisible** — orientation de l'objet texte face caméra.
5. Les archétypes `strates`, `terrain`, `silhouette` n'ont toujours **jamais**
   été rendus. Aucune capsule ne les contient.
