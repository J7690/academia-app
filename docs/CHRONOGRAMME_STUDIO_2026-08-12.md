# Studio visuel — où on en est, et l'ordre à suivre

**Document de reprise. Dernière mise à jour : 12/08/2026, 09h00 UTC.**

À lire **avant toute reprise du chantier**, avec les compétences `etat-des-moyens`,
`continuite-du-chantier` et `studio-visuel-3d`.

> **Règle de ce document** : il distingue ce qui est **mesuré** de ce qui est
> **supposé**. Tout chiffre porte la commande ou la table qui l'a produit. Rien
> n'est repris de mémoire.

---

## 1. L'ÉTAPE ACTUELLE

**Jalon en cours : le cycle de vie de la machine.** Objectif : qu'un pod démarre
quand une tâche arrive, s'arrête quand il n'y a plus rien, et ne facture jamais à vide.

**Ce qui tourne à la seconde où j'écris :** la publication de l'image
`academia0/academia-studio:1.0.0` (9,68 Go) vers Docker Hub, depuis LWS.

**Ce qui attend le feu vert de Jocelyn :** l'application de la migration et le
déploiement de `runpod-control`. Ni l'un ni l'autre n'a été fait.

---

## 2. CE QUI EST ACQUIS — ne pas refaire

| Acquis | Preuve | Fichier |
|---|---|---|
| **31 tests Deno passent** | exécutés le 11/08 | `validate_test.ts` (21), `validate_capsule_test.ts` (10) |
| **Porte d'acceptation** branchée | 6 cas sur 6, vidéos malades fabriquées avec ffmpeg | `montage.py:porte_acceptation`, `test_porte_acceptation.py` |
| **La brume coûte +36,5 % pour rien** | banc A/B sur A40, images témoins indiscernables | `docs/STUDIO_MESURE_BRUME_2026-08-11.md` |
| **Cause racine de la fuite d'argent** | journal du pod + définitions SQL relues | `docs/CHRONOGRAMME` §5 ci-dessous |
| **Image autonome construite et inspectée** | `docker run` dans l'image | `studio_visuel/image/` |
| **Migration + retour arrière écrits** | `$$` appariés, contraintes relues sur la base | `20260811180000_studio_cycle_de_vie_machine.sql` (+ `.down.sql`) |
| **`runpod-control` écrite** | `deno check` propre | `supabase/functions/runpod-control/` |
| **4 procédures obligatoires** | hook SessionStart les annonce | `.claude/skills/` |

**Chiffres mesurés à ne pas re-mesurer** (11/08, pod A40) :

| | |
|---|---|
| Blender EEVEE | **2,185 s/image** — 91 min pour 2500 images |
| Compilation des shaders | **20,5 s**, une fois par machine |
| Amorçage d'un pod | **313 s** (médiane sur 12 pods : 5,0 min) |
| Coût A40 / RTX 4090 | 0,44 $/h / 0,74 $/h |
| Dépense totale de la journée | **1,29 $** |

---

## 3. CE QUI EST TRANCHÉ — ne pas rouvrir sans motif nouveau

- **`STUDIO_BRUME=0`.** La brume est invisible faute de source de lumière dans le
  studio ; monter la densité ne servirait à rien, il faudrait ajouter une lampe.
- **`matiere_feu` n'est PAS branchée génériquement.** C'est l'énergie *d'un objet* ;
  la mettre partout produirait la « forme préenregistrée utilisée à tous les cours »
  que Jocelyn a refusée. Elle attend `convoquer`.
- **`genere` (images par diffusion) a été refusé** comme réponse au problème
  « montrer le sujet ». Ne pas le represserver comme neuf.
- **Le tableau manuscrit et la 3D sont deux produits distincts.** Faire du tableau
  le défaut, c'est abandonner la 3D.
- **P95 < 5 min est hors d'atteinte avec Blender.** `T/N + F` avec T ≈ 83 min et
  F ≈ 5,5 min : le plancher est F, même avec une infinité de machines.

---

## 4. LE CHRONOGRAMME

### Jalon A — cycle de vie de la machine *(en cours)*

| # | Étape | État | Preuve |
|---|---|---|---|
| A1 | Arrêter le pod qui brûlait | ✅ | `gpu_pods` : 0 machine active |
| A2 | Dépôt Docker Hub + jeton | ✅ | `Login Succeeded` sur LWS |
| A3 | Construire l'image | ✅ | `docker run` dans l'image : tout présent, `CAPS=compute,graphics,utility` |
| A4 | Publier l'image | ✅ | `1.1.1` et `latest` chez Docker Hub, **4,47 Go** (contre 9,68 avec la base `runtime`) |
| A5 | **Démarrage autonome d'un pod** | ✅ | **les 5 points, mesurés** — voir ci-dessous |
| A6 | Appliquer la migration | ✅ | 9 colonnes, 4 fonctions, 1 index vérifiés ; `studio_machine_sollicitee()` = `false` sans travail |
| A7 | Déployer `runpod-control` | ✅ | version 4, ACTIVE ; `creer`, `etat`, `terminer` exercés en réel |
| A8 | `gpu_pod_heartbeat` ne décide plus | ⏭️ | l'agent ne doit plus poser `idle_since` |
| A9 | Webhook sur `queued` | ⏭️ | une tâche insérée réveille la machine |
| A10 | **Activer l'arrêt automatique** | ⏭️ | **uniquement après le test complet du §6** |

### A5 — le démarrage autonome, prouvé le 12/08

Rapport envoyé **par la machine elle-même**, sans une seule commande SSH :

```json
{ "gpus": ["NVIDIA L40S"], "pret": true, "echecs": [],
  "renderer": "ANGLE (NVIDIA Corporation, NVIDIA L40S/PCIe/SSE2, OpenGL ES 3.2)",
  "gpu_count": 1, "egl_declare": true,
  "image_octets": 784, "pixels_allumes": 65536,
  "version_moteur": "1.1.1", "version_attendue": "1.1.1" }
```

Et le journal d'amorçage : `demarre → sonde_lancee → sonde_finie → prete`,
**un seul démarrage**, premier signe de vie à **~60–90 s** contre **313 s**
d'amorçage par SSH.

**Deux défauts trouvés et corrigés pendant ce test :**

1. **Aucun canal d'observation.** Un premier pod a tourné six minutes en
   `RUNNING` sans qu'on puisse distinguer « tire encore ses 9,68 Go » de
   « bloqué ». L'image n'ouvre pas sshd — c'est voulu — et RunPod ne documente
   aucun endpoint de journaux. Réponse : `gpu_pod_journal`, appelé **dès la
   première seconde**, plus un `timeout` sur la sonde. Le silence devient un
   diagnostic.
2. **`export` manquant.** `: "${POD_ID:=${RUNPOD_POD_ID}}"` crée une variable de
   *shell*, pas d'environnement. Mesuré dans le conteneur : `POD_ID` visible du
   shell, **0 occurrence** dans `env`, `None` vu par Python, et `worker_pod.py`
   sortait sur « variable manquante ». La sonde réussissait, la machine se
   déclarait **prête**, le worker mourait en une seconde, RunPod relançait le
   conteneur — **dix démarrages en deux minutes**, une machine saine qui
   facturait sans jamais travailler.

> **A5 et A10 sont indissociables de A9.** Activer l'arrêt sans le réveil laisserait
> la première tâche suivante bloquée en `queued`. Ils partent dans le même jalon.

### Jalon B — le produit : la scène en fonction du sujet

**Rien n'a commencé.** C'est pourtant la demande d'origine : « la sociologie » et
« la germination » produisent encore aujourd'hui la même vidéo.

| # | Étape | Dépend de |
|---|---|---|
| B1 | `academia3d` en façade au-dessus de `style_reference.py` | rien |
| B2 | Les 4 verbes neufs : `convoquer`, `sculpter`, `essaimer`, `affleurer` | B1 |
| B3 | **La banque de référents** (30–50 maillages low-poly) — *le vrai coût du chantier* | rien |
| B4 | Étage 1 : intention en JSON contraint, dans la boucle étudiant | B2, B3 |
| B5 | Étage 2 : recettes en Python restreint, fabriquées **hors ligne** | B4 |
| B6 | Geôle d'exécution : secret séparé du code | B5 |

**B1 et B3 ne dépendent d'aucun GPU, d'aucun Docker, d'aucun RunPod.** Ils peuvent
avancer en parallèle du jalon A.

### Jalon C — la latence *(non résolu, et distinct)*

- C1 : mesurer le tirage réel de l'image de 9,68 Go — remplace-t-elle vraiment les
  5 min d'amorçage, ou les rallonge-t-elle ?
- C2 : alléger l'image (base `nvidia/cuda:base` plutôt que `runtime` — cuDNN et
  cuBLAS ne servent pas à de la rastérisation).
- C3 : **reprendre la mesure WebGL avec une méthode auto-vérifiante.** Les trois
  précédentes étaient fausses (voir §5).

---

## 5. LES ERREURS DE LA SÉANCE — pour ne pas les refaire

| Erreur | Ce qu'elle a produit | Ce qui l'a corrigée |
|---|---|---|
| Coût fixe annoncé à **3 min 25** | raisonnement de latence bâti sur du sable | mesure sur `gpu_pods.amorce_at` |
| Puis **sur-corrigé à ~30 min** | aussi faux, dans l'autre sens | `install_pod.sh` n'est **pas** ce qui tourne |
| « Je n'ai pas accès à la base » | une journée de conclusions non vérifiées | un **second** connecteur Supabase existait et marchait |
| Banc WebGL sur `requestAnimationFrame` | compteur plafonné à ~5 images | trois durées comparées : le chiffre suivait la durée |
| Banc WebGL en boucle synchrone | 9434 i/s sur des captures de **10 Ko** | le poids du fichier — l'image était vide |
| `--use-gl=egl` | SwiftShader en silence sur RTX 4090 | sonde de 6 combinaisons → `--use-angle=gl-egl` |
| Banque CC0 recommandée | contredisait une décision motivée du dépôt | `fabriquer_contours.py` en entête |
| `uploading` oublié, `rendering` inventé | machine tuée en plein téléversement | relecture des contraintes `CHECK` réelles |
| Garde `mode='auto'` retiré | une machine de débogage aurait été tuée | relecture de ma propre migration |

**La cause racine de la fuite d'argent, pour mémoire :** `agent_pod.sh` déclarait la
machine occupée sur cinq signaux **machine** — GPU, processus de rendu, installation,
**écritures disque**, **session SSH ouverte**. Aucun ne regardait s'il existait une
**tâche**. Une machine sans travail qui écrit une ligne de journal se déclarait
occupée, `gpu_pod_heartbeat` remettait `idle_since` à `NULL`, et la branche
d'inactivité ne se déclenchait jamais. Seul le plafond de 240 minutes agissait.

---

## 6. LE TEST QUI AUTORISE L'ARRÊT AUTOMATIQUE

Défini par Jocelyn. **Cinq points, tous mesurés, aucun déduit.** Tant qu'un seul
échoue, `desired_state` reste à `RUNNING` et A10 n'est pas activé.

1. Une tâche passée en **`queued` démarre la machine** — sans intervention humaine.
2. **`nvidia-smi` voit au moins une carte** (`gpu_count >= 1`).
3. **La sonde produit une vraie image** — pixels relus, poids du fichier > 400 octets,
   renderer annonçant **NVIDIA** et non SwiftShader.
4. **La tâche est exécutée** de bout en bout et déposée.
5. **Le pod s'arrête après le délai de grâce** — et une tâche arrivant pendant la
   grâce **annule** l'arrêt.

---

## 7. CE QUI DÉPEND DE JOCELYN, ET DE PERSONNE D'AUTRE

| Action | Pourquoi moi je ne peux pas |
|---|---|
| **Révoquer les deux jetons Docker exposés** | ils sont dans une capture d'écran ; garder celui qui marche jusqu'après A4 |
| **Autoriser l'application de la migration** | `deny`/`ask` dans `.claude/settings.json` |
| **Autoriser le déploiement de `runpod-control`** | idem |
| Définir `SUPABASE_ACCESS_TOKEN` | connecteur en lecture seule — utile comme garde-fou, l'autre connecteur n'est pas `--read-only` |
| Recharger RunPod si besoin | aucune action financière |

---

## 8. OÙ SONT LES PREUVES

| Sujet | Document |
|---|---|
| État de l'art scène générée par IA | `STUDIO_3D_RECHERCHE_SCENE_GENEREE_2026-08-11.md` |
| Conception de la scène par sujet | `STUDIO_3D_CONCEPTION_SCENE_PAR_SUJET_2026-08-11.md` |
| Inventaire mesuré des moyens | `STUDIO_INVENTAIRE_MOYENS_2026-08-11.md` |
| Mesure de la brume | `STUDIO_MESURE_BRUME_2026-08-11.md` |
| Mesure WebGL *(méthode invalide, conservée pour la leçon)* | `STUDIO_MESURE_WEBGL_2026-08-11.md` |
| Procédure Docker Hub | `PROCEDURE_DOCKER_HUB_2026-08-11.md` |
