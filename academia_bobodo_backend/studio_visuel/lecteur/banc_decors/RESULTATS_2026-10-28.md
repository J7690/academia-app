# Banc des décors — premier passage (28/10/2026)

**Ce qui a été lancé.** La consigne v2 (`prompt_capsule.ts`) sur les 50 sujets
de `sujets.json`, par `whiteboard-storyboard-smoke` (mode capsule, réservé à
la clé de service, sans écriture en base ni crédit), appelée depuis la base.
Requêtes `net` 135605 à 135654. Modèle : `google/gemini-2.5-flash` (50/50).
Résultats bruts : `essai_1_2026-10-28.json`.

## Ce qui est mesuré

| | |
|---|---|
| capsules valides | **49/50** — l'échec est un `BOOT_ERROR` de la fonction (50 appels simultanés), pas l'invite |
| **temps de l'IA** | **médiane 9,7 s**, 90 % sous 12,9 s, min 6,2 s, max 15,2 s |
| décors (239 scènes) | gestes **61 %**, gouttes **24 %**, corps **15 %** |
| capsules utilisant au moins un décor nouveau | **41/49** |
| foyers | tête 12, thorax 15, ventre 4, bras 2, bassin 1, jambes 1 ; « sujet » 2 (volcan) |
| flux (particules qui s'échappent) | 28 scènes |
| objets convoqués | 112, dont **6 hors banque** (soleil, bateau, oreille, médicament, main, usine) |
| corrections de la validation | 8 (foyer donné par organe ×4, base inconnue ×3, image répétée ×1) |

**La chaîne complète, désormais chronométrée maillon par maillon :**
IA ≈ 9,7 s (médiane), puis voix de la scène 1 et première image ≈ 3,1 s (lot 2).
Soit **≈ 13 s de l'appui à la première image parlée** (estimation par somme de
deux mesures ; non mesurée d'un seul tenant).

## Relu sujet par sujet

**Juste.** Tous les sujets du corps prennent le décor corps, avec des foyers
cohérents : cerveau et vertige à la tête, circulation et respiration au thorax.
La digestion suit le trajet de la tête (dents) au thorax, au ventre puis au
bassin, et le paludisme passe du bras (piqûre) au foie. Les populations
prennent les gouttes : molécules des états de la matière, électrons,
cellules, neurones. L'épidémie occupe 4 scènes de gouttes avec flux. Le volcan
reçoit le seul foyer « sujet », sur l'éruption.

**Forcé — 6 scènes sur 239 (2,5 %).** Décor corps sans rapport avec la phrase,
toujours en fin de capsule, pour « varier » :

| sujet | scène | foyer |
|---|---|---|
| photosynthèse | la transformation en sucres | ventre |
| la pluie | importance de la pluie pour la vie | ventre |
| l'inflation | les effets sur l'économie | ventre |
| dérivées d'une fonction | vitesse et accélération | tête |
| loi macro-économique | les politiques économiques | tête |
| économie | décisions économiques | tête |

Six autres emplois du corps hors des sujets biologiques sont **défendables** :
la sueur (ventilateur), les doigts qui comptent (système décimal), l'enfant
(sciences de l'éducation), le corps et l'énergie (rendement), le cerveau du
consommateur (marketing), la circulation comme exemple (continuité).

**Encombrant — 21 scènes sur 35 en décor corps** ajoutaient un organe
convoqué (cerveau, cœur…) qui se serait posé par-dessus le corps.

## Ce qui a été corrigé après lecture (non encore éprouvé sur le modèle)

1. Invite : le décor corps **seulement** si la scène parle du corps humain ;
   « varier » ne justifie jamais un corps sans rapport.
2. Invite **et** validation : aucun organe convoqué en décor corps ; la
   validation les retire et le dit.
3. Validation : un foyer donné par organe est rangé dans sa zone (foie → ventre).

Tests : 49/49 dans le dossier de génération. **Un second passage est
nécessaire pour vérifier que les 6 scènes forcées disparaissent** : le
diagnostic déployé porte encore la consigne du premier passage.

## Ce qui reste ouvert

- 6 objets hors banque sur 112 (5 %) : le moteur les signale et dégrade. Les
  ajouter à la banque, ou les annoncer comme absents dans la consigne.
- Le décor gouttes sert parfois de métaphore vague (« méthodes
  d'enseignement », « impact des politiques »). Lisible, mais générique.
- Les 37 sujets réels de la base sont surtout des sujets de test ou de
  mathématiques ; l'échantillon ne représente pas encore les étudiants.

---

# Second passage — consigne corrigée (28/10/2026, 12:45 UTC)

Requêtes `net` 135675 à 135724, précédées d'un appel de chauffe (135674).
Résultats bruts : `essai_2_2026-10-28.json`.

| | 1er passage | **2e passage** |
|---|---|---|
| capsules valides | 49/50 | **48/50** (2 `BOOT_ERROR` malgré la chauffe : 50 démarrages simultanés) |
| sujets du corps en décor corps | 9/9 | **9/9** |
| décor corps hors des sujets du corps | 12, dont 6 forcés | **4, tous défendables, 0 forcé** |
| scènes corps avec un organe par-dessus | 21 | **0** — dont 18 retirés par la validation : **l'IA en ajoute encore malgré la consigne** |
| décors | gestes 61 % · gouttes 24 % · corps 15 % | gestes 65 % · gouttes 24 % · corps 11 % |
| capsules avec un décor nouveau | 41/49 | 40/48 |
| temps de l'IA | médiane 9,7 s, p90 12,9 s | **médiane 9,8 s, p90 11,8 s** |
| objets hors banque | 6/112 | 7/100 (usine ×2, voiture, ordinateur, moustiquaire, médicament, bateau) |

Les quatre emplois du corps qui restent : « le rôle du cerveau dans
l'apprentissage » (sciences de l'éducation), l'évaporation de la sueur
(ventilateur), la circulation sanguine prise comme exemple (continuité),
l'énergie du corps humain (rendement).

**Leçon.** La consigne a supprimé les erreurs de **jugement** (le décor
forcé). Elle n'a pas supprimé l'**habitude** d'ajouter l'organe : c'est la
validation qui la corrige, en le disant. Les deux couches servent.

**Reste ouvert** : les objets hors banque (7 %). Le moteur les signale et
dégrade ; il faut soit les ajouter à la banque, soit ne plus les proposer.
Les `BOOT_ERROR` ne concernent que le banc : en production, chaque étudiant
fait un seul appel, pas 50 à la fois.
