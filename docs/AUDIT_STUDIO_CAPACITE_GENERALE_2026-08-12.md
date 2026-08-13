# Audit — le Studio peut-il produire une vidéo pour N'IMPORTE QUEL sujet ?

**Date : 12/08/2026.** Audit **en lecture seule**, sur pièces. Aucune modification.
Périmètre demandé : Supabase, Flutter, RunPod, AWS — plus l'historique et la
documentation du dépôt.

> Chaque affirmation ci-dessous porte la table, le fichier ou la ligne qui l'a
> produite. Rien n'est repris de mémoire.

---

## 1. Ce qui existe, mesuré

### Supabase

| | |
|---|---|
| Tables `app` liées à la vidéo | **40** (dont `studio_jobs`, `gpu_pods`, `whiteboard_projects`, `whiteboard_renders`, `studio_config`) |
| RPC `studio_*` | **13** |
| RPC `gpu_pod*` | **13** |
| RPC `whiteboard_*` | **12** |
| Buckets | **15**, dont `studio-visuel` (privé) et `whiteboard-renders` (public) |
| Tâches cron | **13**, dont `studio-orchestrateur` (3 min), `runpod-watchdog` (2 min), `studio-reprise-orphelins` (2 min) |
| Edge Functions | **70+**, dont `whiteboard-generate-storyboard`, `studio-orchestrateur`, `runpod-control`, `runpod-watchdog`, `studio-jeton-huggingface`, `whiteboard-tts` |

### Ce qui a été réellement produit

| | |
|---|---|
| Projets whiteboard | **214** |
| Rendus tableau **terminés** | **95** |
| Objets dans `whiteboard-renders` | **119** |
| **Travaux 3D** | **13** — statuts : `preview_ready`, `archived`, `failed` |
| Objets dans `studio-visuel` | **27** |

**Lecture** : le **tableau manuscrit est un produit qui tourne** — 214 projets,
95 rendus terminés. La **3D est un prototype** — 13 travaux, aucun jamais passé
en `approved` ni `done`.

### Flutter

`academia_app/lib/features/challenge/smart_whiteboard/` : 4 écrans, 1 provider,
3 services, 2 modèles. Le choix du type de production **est exposé à l'étudiant** :

```dart
String get apiValue => this == ProductionType.tableau ? 'vision2' : 'studio';
```
*(`smart_whiteboard_input_screen.dart:427`)*

### RunPod

Plan de contrôle construit **aujourd'hui** : `runpod-control` v4 — `etat`,
`demarrer`, `arreter`, `creer`, `terminer`. Image autonome
`academia0/academia-studio:1.1.1` (4,47 Go) publiée, démarrage autonome prouvé
(GPU détecté, sonde produisant une vraie image, un seul démarrage).

### AWS

**Aucune trace.** Ni SDK, ni bucket, ni client, dans `academia_app/lib`,
`academia_bobodo_backend` ou `supabase`. Le projet n'utilise pas AWS.

---

## 2. LA TROUVAILLE CENTRALE

> **Le catalogue fermé de dix formes est présent aux TROIS couches.**
> Ce n'est pas un défaut du moteur de rendu. C'est une contrainte de bout en bout.

| Couche | Fichier | Ce qu'elle impose |
|---|---|---|
| **L'invite** | `prompt_capsule.ts:29-44` | énumère à l'IA les dix formes disponibles et lui demande d'en **choisir** une |
| **La validation** | `validate_capsule.ts:71-74` | `if (!ARCHETYPES.includes(archetype))` → **remplacé par `reseau`** |
| **Le rendu** | `generateur_scenes.py:622` | `ARCHETYPES = { … }` — dix fonctions, pas une de plus |

Les dix : `titre, reseau, flux, strates, comparaison, chronologie, carte, ondes,
terrain, silhouette`.

**Conséquence directe et vérifiable** : même si un modèle proposait une forme
adaptée à un sujet, la validation la **remplacerait par `reseau`** avant que le
moteur ne la voie. C'est ce qui explique, à la racine, que « la sociologie » et
« la germination » aient produit la même suite de formes le 07/08.

Et le correctif du rendu seul ne suffirait pas : il faut ouvrir les **trois**.

### Le seul point d'entrée du sujet, aujourd'hui

Sur les dix archétypes, trois seulement laissent passer quelque chose du sujet :

- `titre` — du texte ;
- `chronologie` — des jalons rendus en `texte_3d` ;
- `silhouette` — un contour SVG, **et il en existe cinq** : `amphore`, `coeur`,
  `feuille`, `goutte`, `spirale`.

Les sept autres n'acceptent que des **nombres** : `noeuds`, `couches`, `rayon`,
`points`, `cercles`, `ondes`, `tours`. Un nombre de nœuds ne dit rien d'un sujet.

---

## 3. Tableau de capacité — « n'importe quel sujet »

| Capacité | État | Preuve |
|---|---|---|
| **Style constant** pour toutes les vidéos | ✅ **fait** | `academia3d_style.py`, proportions et absolus séparés |
| **Porte d'acceptation** déterministe | ✅ **fait** | `montage.porte_acceptation`, 6 cas sur 6 |
| **Cycle de vie machine** (créer/démarrer/arrêter, réveil) | ✅ **fait aujourd'hui** | `runpod-control` v4, déclencheur `studio_jobs_reveil` |
| **Chaîne voix + montage + sous-titres** | ✅ existe | `narration.py`, `montage.py` (ASS incrustés) |
| **Arranger** (relier, empiler, entourer) | 🟡 **partiel** | existe *dans* les archétypes, pas comme verbes réutilisables |
| **Énergie** (chauffer, circuler, croître) | 🟡 **partiel** | `matiere_feu` écrite mais **jamais appelée en production** ; `affleurer` neuf |
| **Texte / symbole** (le secours universel) | 🟡 **partiel** | `texte_3d` existe, mais n'est atteignable que via `titre` et `chronologie` |
| **Construire une forme quelconque** | ❌ **manque** | seul `sculpter` existe. Ni squelette, ni révolution, ni extrusion |
| **Couche d'intention** (quelle stratégie visuelle pour ce sujet) | ❌ **manque** | l'invite demande une FORME, jamais une INTENTION |
| **L'IA qui compose la scène** | ❌ **manque** | elle choisit dans dix cases ; elle n'écrit rien |

---

## 4. Ce que l'historique avait déjà établi

- `docs/rapport_smart_whiteboard_2026-07/06_RESTE_A_FAIRE.md` pose **trois
  contraintes non négociables** qui tiennent toujours : 100 % CSS pour le
  tableau, aucun calcul d'IA sur LWS, **dégradation gracieuse obligatoire**.
- `docs/STUDIO_VISUEL_ETAT_2026-08-05.md` : sept défauts, dont **six cachés
  derrière une absence de message** et un derrière un message de **succès**.
- `contours/fabriquer_contours.py` : la doctrine des formes **générées par
  équation** plutôt que téléchargées, pour la traçabilité commerciale.
- `docs/STUDIO_3D_CONCEPTION_SCENE_PAR_SUJET_2026-08-11.md` : la voie retenue —
  l'IA **fabrique** la scène, contrat à deux étages, génération hors ligne.

---

## 5. Recommandations, dans l'ordre

### R1 — Ouvrir les trois couches **ensemble**, jamais une seule

Ouvrir le rendu sans l'invite ne sert à rien : l'IA continuerait de choisir
parmi dix. Ouvrir l'invite sans la validation non plus : le remplacement par
`reseau` annulerait tout. C'est un seul changement en trois endroits.

### R2 — Remplacer « choisis une forme » par « choisis une INTENTION »

Six intentions couvrent la pédagogie, et elles sont indépendantes du sujet :

> montrer **l'objet** · le **processus** · la **comparaison** · la **structure** ·
> l'**échelle** · le **flux**

C'est ce choix qui adapte la vidéo au sujet. La forme n'en est que la
conséquence, et c'est le programme qui la fabrique.

### R3 — Compléter les verbes de construction — c'est le seul vrai trou

| Verbe | Fabrique | Couvre |
|---|---|---|
| `silhouetter` | squelette de segments épaissi | corps, membres, plantes, racines, vaisseaux |
| `revolutionner` | profil tourné autour d'un axe | vases, colonnes, entonnoirs, fusées |
| `extruder` | contour 2D poussé en épaisseur | lettres, symboles, cartes, pièces |

Tous trois se décrivent **en coordonnées**, donc une IA peut les écrire, et
aucun ne demande de fichier téléchargé — conforme à la doctrine du dépôt.

### R4 — Garder les dix archétypes comme **raccourcis**, pas comme prison

Ils fonctionnent et sont éprouvés. Ils deviennent des compositions de verbes
parmi d'autres, appelables quand ils conviennent — au lieu d'être la seule
chose appelable.

### R5 — Rendre la dégradation VISIBLE

Aucun vocabulaire fini ne couvrira tout : un violon, une cathédrale, une
réaction chimique précise. Quand le dispositif ne sait pas montrer, il doit
retomber sur le texte et le symbole **et l'écrire dans la ligne de rendu**. La
contrainte du dépôt est « on nettoie, on ne rejette pas » — elle n'a jamais dit
« on se tait ».

### R6 — Ne pas relancer le rendu GPU avant R1–R3

Une capsule coûte 75 à 82 minutes de machine. Tant que les trois couches sont
fermées, chaque rendu produira la même chose avec un sujet différent. Toute la
mise au point des formes se fait **gratuitement** dans le conteneur sur LWS,
comme les cinq calibrations d'aujourd'hui.

---

## 6. Ce que cet audit n'a pas pu établir

1. **La qualité du choix d'intention par un modèle.** Rien dans la littérature
   lue le 11/08 ne dit qu'un modèle sait trouver la bonne image pour un sujet
   abstrait. À mesurer sur des sujets réels, pas à supposer.
2. **Le coût de rendu des nouveaux verbes.** `banc_rendu.py` existe et n'a pas
   été rejoué sur eux.
3. **L'état des 27 objets de `studio-visuel`** — comptés, pas ouverts.
4. **Le comportement du tableau manuscrit** : 95 rendus terminés, mais l'audit
   n'a pas vérifié leur qualité.
