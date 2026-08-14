# Passation — Studio visuel 3D d'Academia
**Rédigé le 14/08/2026, pour la personne qui reprend le chantier.**

> Ce document dit ce qui **marche**, ce qui est **cassé**, ce qui a été **trouvé**,
> et par où **commencer**. Tout chiffre ici a été mesuré, jamais estimé.
> L'état courant vit dans `ETAT.md` (racine) ; l'historique acte par acte dans
> `docs/JOURNAL_INTERVENTIONS.md`.

---

## 1. Ce que fait le produit

L'étudiant tape un sujet dans l'app Flutter et choisit **« Animation 3D »**. Une
IA compose une **capsule** : 4 à 6 scènes, chacune portant une *intention*, une
*narration* et des **gestes** — des verbes géométriques avec leurs coordonnées.
Une machine GPU louée à l'heure fabrique la vidéo verticale 9:16 avec voix et
sous-titres.

**Le point de conception à comprendre avant tout le reste** : l'IA ne choisit
plus une forme dans un catalogue, elle **décrit** la forme. Auparavant, dix
archétypes existaient et deux sujets sans rapport donnaient la même vidéo.

## 2. L'architecture — trois machines, trois codes

C'est la source de la moitié des confusions. **Modifier un fichier ≠ changer ce
qui s'exécute.**

| Machine | Quel code | Comment on le met à jour | Comment on VÉRIFIE |
|---|---|---|---|
| **Supabase** `thevdfcwlcqzdoybfvgs` | Edge Functions, RPC, cron | `supabase functions deploy <nom>` (CLI liée, aucun secret à saisir) | tableau de bord, ou appel réel |
| **LWS** `31.207.38.60` | `/opt/studio_visuel/*.py` — prépare la voix, cale les durées | `scp` puis `systemctl restart studio-preparateur` | `diff` en neutralisant les fins de ligne |
| **Pod RunPod** | l'image Docker **+ le moteur tiré au démarrage** | voir §3 | `docker create` + `docker cp`, puis lire les fichiers |

```
Étudiant (Flutter)
  └─> Edge Function whiteboard-generate-storyboard   engine=studio → capsule composée
       └─> app.studio_jobs (a_preparer)
            ├─ déclencheur studio_reveiller_sur_file → runpod-control (créer)
            └─> LWS studio-preparateur : voix + durées mesurées → queued
                 └─> Pod : entrée → tirage du moteur → sonde → Blender → montage
                      └─> porte d'acceptation → Storage → preview_ready
```

## 3. Le mécanisme qui évite de reconstruire l'image — **prouvé**

Le moteur (82 Ko de Python) vivait **dans** l'image Docker (4,47 Go). Corriger
une ligne exigeait un poste allumé, Docker démarré, une reconstruction et une
publication.

**Désormais séparés :**
- l'**image** = Blender 4.5.12, Chromium, Node, ffmpeg, EGL — change rarement,
  **se construit sur LWS** (Docker 29.6.2 + buildx, 117 Go, déjà connecté à
  Docker Hub comme `academia0`) ;
- le **moteur** = les `.py` — se publie dans **Supabase Storage**, bucket
  `studio-moteur`, et chaque machine le tire au démarrage.

Journal d'amorçage réel du 14/08 :
```
demarre (image 1.3.0) > moteur_tirage (1.3.1) > moteur_installe (1.3.1)
  > sonde_lancee > sonde_finie (code 0) > prete
```

**Publier un correctif de moteur** (depuis n'importe où) :
```bash
tar --owner=0 --group=0 --numeric-owner -czf moteur-<v>.tar.gz .
supabase storage cp ./moteur-<v>.tar.gz "ss:///studio-moteur/moteur-<v>.tar.gz" --experimental
```
puis `update app.studio_config set valeur='<v>' where cle='version_moteur';`

**Sécurité intégrée** : si le tirage échoue, la sonde constate que la version
installée ≠ la version attendue et **refuse la machine**, plutôt que de rendre
avec un moteur qu'on croyait remplacé.

⚠️ `--owner=0` n'est pas cosmétique : une archive faite sous Windows porte un
uid que le conteneur ignore ; `tar` sort alors en code 2 **alors que
l'extraction a réussi**. Faux échec, une heure perdue.

## 4. Ce qui MARCHE, mesuré le 14/08

| Élément | Mesure |
|---|---|
| Vidéo livrée | **47,6 s, 1080×1920, H.264 + AAC, 11,5 Mo**, statut `preview_ready` |
| Composition par l'IA | 5 scènes, 5 intentions distinctes, **0 correction** |
| Réveil de la machine | **1,5 s** après l'insertion du travail |
| Démarrage du conteneur | 3 s (image en cache) à **10,4 min** (hôte froid) |
| Rendu | 1 193 images en **27 min** sur RTX 4090 |
| Coût d'une capsule | **≈ 0,30 $** |
| Coût total de la journée | **1,52 $** |
| Porte d'acceptation | fonctionne : elle a **refusé** une capsule figée, puis **accepté** la suivante |

## 5. Ce qui NE VA PAS — le seul problème qui reste

**La vidéo est techniquement parfaite et ne dit pas le sujet.**

Preuve, capsule « Poussée d'Archimède » livrée :
- scène 5, narration : « …la conception des **bateaux**, des **sous-marins** et
  même des **montgolfières** » → gestes : `sculpter(galet)` + 2 `sculpter(sphere)`.
  Aucun bateau, aucun sous-marin, aucune montgolfière.
- scènes 1, 2 et 3 : gestes **strictement identiques**, mêmes coordonnées.

### 5.1 La cause n'est PAS le modèle — c'est un désaccord de convention

`extruder` construisait le contour dans le plan **XY, c'est-à-dire à plat sur le
sol**, alors que l'invite enseigne au modèle que « **Z est la hauteur** ». Le
modèle dessinait donc `y` vers le haut ; la machine lisait `y` comme la
profondeur.

Le modèle avait écrit une flèche parfaite — hampe et pointe, montant à 2 unités
— pour une scène intitulée « Force vers le haut ». **Le moteur l'a couchée par
terre, pointe vers le fond.** `ecrire` souffrait du même défaut, alors que c'est
le secours universel.

➡️ **Corrigé, compilé, NON DÉPLOYÉ** (`academia3d.extruder`, `composer_scene._g_ecrire`).

### 5.2 Ce que la machine sait vraiment faire — et que l'invite ne dit pas

| Verbe | Capacité réelle mesurée |
|---|---|
| `silhouetter` | **orientation libre, 120 points** — le seul verbe général. Sous-marin, coque, corps, circuit : atteignables **là et nulle part ailleurs** |
| `revolutionner` | tout solide de révolution autour de la verticale — **une montgolfière est atteignable dès aujourd'hui** |
| `sculpter` | **5 ellipsoïdes fixes**, allongement maximal **3,1**, toujours sur l'axe vertical — une coque (8:1) lui est **impossible** |
| `extruder` | contour debout (depuis le correctif) |
| `napper` | terrain 190×190 à l'origine, ni position ni inclinaison |
| `ecrire` | 60 caractères |

Le modèle a écrit `galet` pour « bateau » parce que c'était **la meilleure
approximation du verbe qu'il avait choisi**. Personne ne lui a dit que
`silhouetter` savait le faire.

### 5.3 Rien ne l'oblige, rien ne le vérifie

- L'invite ne relie **jamais** les gestes aux **mots** de la narration. Le mot
  « narration » n'y apparaît qu'une fois, pour définir un champ JSON.
- « On ne remontre pas la même chose deux fois » est une phrase de conseil,
  dans une section de conseils. **Aucune vérification.**
- La validation traite chaque scène **isolément** : six scènes identiques
  passent avec `corrections.length === 0`.
- L'invite ne montre **qu'un seul exemple** de scène — un gabarit à recopier —
  et l'appel se fait à température 0,35, qui favorise la répétition.

## 6. Les huit couches du même défaut — l'histoire à connaître

Le catalogue fermé de dix archétypes existait à **huit endroits**, chacun
corrigeant en silence vers un défaut. **Sept sur huit ne levaient aucune erreur.**

1. l'invite · 2. la validation serveur · 3. la normalisation du pod ·
4. le dictionnaire de rendu · 5. le choix d'engine dans l'app ·
6. l'analyse côté app · 7. la reconnaissance de capsule du préparateur LWS ·
8. les chemins codés en dur dans l'image

**Tous fermés.** La leçon est dans `.claude/skills/tracer-la-valeur/` : quand un
symptôme survit à un correctif juste, **il y a une autre couche** — ne jamais
écrire une deuxième variante du même correctif.

## 7. Les autres défauts trouvés aujourd'hui

| Défaut | Cause | État |
|---|---|---|
| Deux chaînes concurrentes | cron `studio-orchestrateur` créait une machine **image PyTorch générique** toutes les 3 min ; elle attrapait le travail et le tuait en 4 s | cron **désactivé**, `studio-amorceur` arrêté sur LWS |
| Machines tuées en plein rendu | le veilleur jugeait le silence sur `last_seen_at`, que l'avancement ne rafraîchissait pas | **l'avancement vaut signe de vie** |
| Machines tuées avant de démarrer | délai de silence (10 min) compté depuis la **création**, pas depuis le démarrage du conteneur | **délai d'amorçage 25 min** distinct, sur un fait observable |
| Image figée 46 s | le compositeur posait une caméra **fixe**, zéro image-clé | **orbite** par intention (14° à 34°) |
| Sujet hors cadre | distance caméra **constante** par intention | **mesurée** sur la boîte englobante |
| Sphère invisible | le verre n'était posé que sur le rôle « sujet » ; la structure restait opaque et masquait | **toute surface conservée est traversable** |
| Arête d'épaisseur ×échelle² | modificateur Wireframe en espace local | corrigé |

## 8. Ce qui a été mis en place pour ne pas repartir de zéro

- **`ETAT.md`** (racine) — l'autorité unique. `docs/` contient 219 fichiers dont
  dix s'annoncent comme « état » ; aucun ne faisait foi. Celui-ci fait foi.
- **`docs/JOURNAL_INTERVENTIONS.md`** — append-only, un acte par ligne.
- **Hook `etat_projet.py`** (SessionStart) — injecte `ETAT.md` et les derniers
  actes, et **signale quand l'état a pris du retard** sur les fichiers modifiés.
- **Hook `fin_intervention.py`** (Stop) — rappelle de mettre à jour.
- **`studio_supervision()`** — une ligne d'état, six alertes surveillées :
  échec récent, machine condamnée en plein rendu, rendu figé, machine muette
  dès l'amorçage, plus d'une machine vivante, travail sans machine, dépense.
- **Veilleur `/opt/studio_visuel/veille.sh`** sur LWS — interroge, ne parle que
  si ça cloche, point d'étape toutes les 10 min, et crie `VEILLE AVEUGLE` s'il
  ne peut plus interroger.
- **Deux compétences** : `ou-tourne-le-code` (trois machines, trois codes) et
  `tracer-la-valeur` (mesurer la donnée à chaque frontière).

## 9. Par où commencer — dans cet ordre

1. **Déployer le moteur avec les contours redressés** (§5.1). C'est écrit et
   compilé ; publier en 1.3.2 et relancer une capsule. **Coût : ~0,30 $.**
   C'est la correction qui rendra les flèches lisibles.
2. **Réécrire l'invite** (`prompt_capsule.ts`) sur trois points :
   - dire ce que chaque verbe **ne sait pas** faire, et aiguiller (objet
     allongé → `silhouetter`, jamais `sculpter`) ;
   - **exiger** que les gestes représentent les mots de la narration de leur
     propre scène — pas du sujet en général ;
   - donner **trois à quatre exemples chiffrés d'objets concrets** (le profil
     d'une montgolfière est dans `ETAT.md`), au lieu d'un seul gabarit.
3. **Ajouter à la validation la comparaison entre scènes** — deux scènes aux
   gestes identiques doivent produire une **correction nommée**, jamais un refus
   (règle du dépôt : on nettoie, on ne rejette pas).
4. **Retirer trois sélecteurs morts** de l'écran Flutter — thème, renderer,
   narration ne sont jamais relus en 3D, et « Narration : aucune » est faux
   puisque la voix est obligatoire. Changer l'exemple du champ Sujet :
   « Dérivée d'une fonction » est le pire cas possible, il n'a aucune forme.
5. **Réduire l'image** — 4,47 Go pour un moteur de 82 Ko. C'est ce qui fait
   qu'un démarrage peut prendre 10 minutes.

## 10. Ce qu'il faut savoir avant de toucher quoi que ce soit

- **Ne jamais déduire un état de ce qu'on ne voit pas.** Vérifier qu'un fichier
  est valide ne dit rien de ce qu'il contient. J'ai « vérifié » une image en
  comptant les occurrences d'un mot présent dans les deux versions : une heure
  perdue et une fausse piste.
- **Vérifier avant de demander une action à Jocelyn.** Je lui ai demandé de
  faire un `docker login` déjà fait depuis deux jours.
- **Ne jamais écrire dans l'état qu'on observe.** Mon appel de diagnostic a
  écrit dans le journal d'amorçage d'une machine et a changé la règle qui lui
  était appliquée.
- **Interdits sans accord explicite** : écriture en base de production,
  déploiement d'Edge Function, migration distante, `git commit`, `git push`.
  Ne jamais lire ni committer la clé SSH ; ne pas toucher au pare-feu.
- **Dette ouverte** : deux jetons Docker Hub ont été exposés en conversation le
  12/08. **À révoquer.**

---

*Tout le travail de la semaine est commité (`1c5da77` et précédents). Aucune
machine ne tourne. Dépense cumulée du chantier : environ 2,5 $.*
