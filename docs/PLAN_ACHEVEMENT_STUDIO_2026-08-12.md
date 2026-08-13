# Plan de mise à niveau et d'achèvement — Studio visuel

**Date : 12/08/2026.** Établi à partir de
`AUDIT_STUDIO_CAPACITE_GENERALE_2026-08-12.md`.

**L'objectif, en une phrase** : que le dispositif produise une vidéo **adaptée au
sujet**, quel que soit le sujet apporté par l'étudiant.

> **La règle qui commande tout le plan** : le catalogue fermé de dix formes est
> présent aux **trois** couches — invite, validation, rendu. Corriger une seule
> ne produit aucun effet observable. Les phases ci-dessous en tiennent compte.

---

## PHASE 0 — Mise à niveau : la dette qui gêne la suite

Rien de neuf ici. Ce sont des choses **déjà écrites** qui divergent, ne servent
plus, ou n'ont jamais été branchées. Chacune coûte peu et fait perdre du temps
tant qu'elle traîne.

| # | Dette | Pourquoi ça gêne | Vérification |
|---|---|---|---|
| 0.1 | `install_pod.sh` et le script d'amorçage de `studio_amorceur.py:156` **divergent** (ComfyUI n'est que dans le premier) | deux sources d'installation, dont une fausse. C'est l'amorceur qui tourne | un seul chemin d'installation subsiste |
| 0.2 | `agent_pod.sh` déduit « occupé » du **disque et de SSH** | c'est la cause racine de la fuite d'argent. Le veilleur ne l'écoute plus, mais l'agent écrit toujours un champ mensonger | `idle_since` n'est plus écrit par l'agent |
| 0.3 | `matiere_feu` et `matiere_brume` écrites, **jamais appelées** en production | deux éléments de la grammaire de référence dorment. La brume est mesurée inutile sans lumière ; le feu attend un sujet | décision écrite pour chacune |
| 0.4 | Archétype `genere` désactivé, cause établie le 06/08, **correctif non vérifié** | une capacité payée et inutilisable | soit vérifié sur GPU, soit retiré |
| 0.5 | **45 fichiers non commités** | toute régression devient indiscernable du travail en cours | dépôt propre |
| 0.6 | CLAUDE.md décrit un chantier du 28/07 | tout agent qui reprend part sur une fausse piste | à jour |

**Coût** : faible, aucun GPU. **Bloquant pour** : rien, mais tout va plus vite après.

---

## PHASE 1 — Fermer le cycle de vie de la machine

Reprise des étapes A8 à A10 du chronogramme. **A9 est fait** (réveil événementiel).

| # | Étape | Vérification |
|---|---|---|
| 1.1 | `gpu_pod_heartbeat` ne décide plus de l'inactivité | l'agent ne pose plus `idle_since` ; `studio_machine_sollicitee()` reste seule autorité |
| 1.2 | Grâce événementielle de 90–120 s à la fin de la dernière tâche | une tâche arrivant pendant la grâce **annule** l'arrêt |
| 1.3 | **Test de bout en bout**, les 5 points définis par Jocelyn | tâche `queued` → machine démarre → GPU détecté → sonde produit une vraie image → tâche exécutée → arrêt après grâce |
| 1.4 | **Activer l'arrêt automatique** | uniquement après 1.3 |
| 1.5 | Veilleur ramené à un rôle de récupération | il ne rattrape que les états bloqués |

**Coût** : une capsule complète pour le test, soit **75–82 min de machine ≈ 1,20 $**.
**Bloquant pour** : rien d'autre — mais tant que ce n'est pas fait, chaque essai
GPU risque de laisser une machine facturer.

---

## PHASE 2 — Les verbes de construction *(le seul vrai trou)*

C'est ici que se joue « n'importe quel sujet ». Aujourd'hui, seul `sculpter`
existe : on sait déformer une base, pas construire une forme.

| # | Verbe | Fabrique | Couvre |
|---|---|---|---|
| 2.1 | `silhouetter` | squelette de segments épaissi (modificateur Skin) | corps, membres, plantes, racines, neurones, vaisseaux |
| 2.2 | `revolutionner` | profil tourné autour d'un axe | vases, colonnes, entonnoirs, fusées, verres |
| 2.3 | `extruder` | contour 2D poussé en épaisseur | lettres, symboles, cartes, pièces, logos |
| 2.4 | Verbes d'arrangement en première classe : `relier`, `empiler`, `entourer`, `aligner` | — | *plusieurs*, *dedans*, *au-dessus*, *relié à* |
| 2.5 | Verbes d'énergie : `emettre_particules`, `croitre`, `traverser` | — | *ça circule*, *ça grandit*, *ça chauffe* |
| 2.6 | `ecrire` — accès direct à `texte_3d` | — | **le secours universel** |

**Pourquoi ces trois-là et pas d'autres** : tous se décrivent **en coordonnées**,
donc une IA peut les écrire ; et aucun ne demande de fichier téléchargé —
conforme à la doctrine de `contours/fabriquer_contours.py`.

**Vérification** : chaque verbe rend une image dans le conteneur, regardée.
**Coût : zéro.** Tout se fait sur LWS, sans GPU, comme les cinq calibrations
du 12/08. **Bloquant pour** : la phase 3.

---

## PHASE 3 — Ouvrir les trois couches, ENSEMBLE

Un seul changement, en trois endroits. Séparer les trois ne produirait aucun
effet observable.

| # | Couche | Aujourd'hui | Après |
|---|---|---|---|
| 3.1 | `prompt_capsule.ts` | énumère dix formes, demande d'en **choisir** une | demande une **intention** et un **référent** |
| 3.2 | `validate_capsule.ts` | toute forme inconnue → **remplacée par `reseau`** | valide une **composition**, refuse seulement l'inexécutable |
| 3.3 | `generateur_scenes.py` | dix fonctions | exécute une composition ; les dix deviennent des **raccourcis** |

### Les six intentions

> montrer **l'objet** · le **processus** · la **comparaison** · la **structure** ·
> l'**échelle** · le **flux**

Elles sont indépendantes du sujet, et c'est ce choix qui adapte la vidéo. La
forme n'en est que la conséquence.

**Vérification** : trois sujets sans rapport donnent trois compositions
**différentes**. C'est le seul test qui compte, et il se fait sur le JSON
d'intention — sans rendu, donc sans coût.

---

## PHASE 4 — L'IA compose la scène

| # | Étape | Pourquoi |
|---|---|---|
| 4.1 | **Étage 1 — intention**, JSON contraint, dans la boucle étudiant, en secondes | ne doit **jamais** échouer : sinon l'étudiant perd crédits et vidéo |
| 4.2 | **Étage 2 — fabrication**, Python restreint contre `academia3d`, **hors ligne**, mis en cache | LL3M met ~4 min pour un seul objet ; écrire du code pendant que l'étudiant attend est arithmétiquement exclu |
| 4.3 | **La geôle** : secret séparé du code, liste blanche d'imports, bornes, processus éphémère | le pod détient la clé de service |
| 4.4 | **Le critique visuel** : image témoin par scène, questions **fermées**, jamais une note | les juges VLM s'écartent de 2 points ou plus dans 24–30 % des cas |
| 4.5 | **Dégradation VISIBLE** : quand le dispositif ne sait pas montrer, il retombe sur le texte **et l'écrit** | « on nettoie, on ne rejette pas » n'a jamais voulu dire « on se tait » |

**Le chiffre qui commande cette phase** : dans 3DCodeBench, deux reprises sur
erreur font **+27,2 points d'exécutabilité et −0,010 de pertinence**. La boucle
de réparation corrige les plantages, pas le hors-sujet. **Ne pas investir dans
le retry avant les verbes.**

---

## PHASE 5 — La latence *(distincte, non résolue)*

| # | Étape | Question à trancher |
|---|---|---|
| 5.1 | Mesurer le tirage réel de l'image de 4,47 Go | remplace-t-elle vraiment les 313 s d'amorçage ? |
| 5.2 | Volume réseau pour le cache des modèles | RunPod annonce −60 % sur le chargement des poids |
| 5.3 | **Refaire la mesure WebGL** avec une méthode auto-vérifiante | trois harnais successifs ont mesuré du vide le 11/08 |
| 5.4 | Trancher le moteur | Blender = 91 min, plancher 5,5 min ; navigateur GPU = inconnu, potentiellement < 1 min |

**Acté** : P95 < 5 min est **hors d'atteinte avec Blender**, même avec une
infinité de machines — `T/N + F` avec F ≈ 5,5 min. Ce n'est pas une opinion.

---

## PHASE 6 — Mise en production

| # | Étape | Vérification |
|---|---|---|
| 6.1 | Parcours étudiant complet depuis l'application | l'étudiant choisit « animation 3D » et obtient sa vidéo |
| 6.2 | L'attente est **annoncée** et visible | pas d'écran figé sur « tâche déjà en cours » |
| 6.3 | Compilation APK et essai sur le téléphone | les deux types de production fonctionnent |
| 6.4 | Mesure du coût réel par capsule | décision de tarification possible |

---

## ORDRE ET DÉPENDANCES

```
PHASE 0  (dette)          ──┐
PHASE 1  (cycle machine)  ──┤
                            ├──> PHASE 5 (latence)  ──> PHASE 6 (production)
PHASE 2  (verbes)  ──> PHASE 3 (trois couches)  ──> PHASE 4 (l'IA compose) ──┘
```

**Les phases 2, 3 et 4 sont le produit.** Les phases 0, 1 et 5 sont la
machinerie. Elles peuvent avancer en parallèle : elles ne se disputent ni les
mêmes fichiers, ni les mêmes ressources.

**Ce qui coûte de l'argent** : la phase 1 (un test, ≈ 1,20 $), la phase 5
(mesures GPU), la phase 6 (production réelle). **Les phases 2, 3 et 4 se font
gratuitement** dans le conteneur sur LWS.

---

## CE QUI DÉPEND DE JOCELYN

| Action | Phase |
|---|---|
| Révoquer les deux jetons Docker exposés le 12/08 | immédiat |
| Autoriser l'activation de l'arrêt automatique après le test | 1.4 |
| Trancher : Blender assumé asynchrone, ou bascule moteur | 5.4 |
| Valider la tarification une fois le coût réel mesuré | 6.4 |

---

## CE QUI RESTE NON ÉTABLI, ET QU'IL NE FAUT PAS SUPPOSER

1. **Qu'un modèle sache choisir la bonne intention pour un sujet ABSTRAIT.**
   Rien dans la littérature lue le 11/08 ne l'affirme. SceneCraft et LL3M
   démontrent sur des objets et des intérieurs, pas sur des métaphores
   pédagogiques. **C'est peut-être la vraie difficulté du chantier.**
2. Le coût de rendu des nouveaux verbes — `banc_rendu.py` existe, non rejoué.
3. La qualité réelle des 95 rendus tableau — comptés, jamais regardés.
4. Le taux de faux positifs du critique visuel sur **nos** rendus.
