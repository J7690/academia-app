# ÉTAT — le document qui fait foi

> **Ce fichier prime sur tous les autres.** `docs/` en contient 219 ; dix
> s'annoncent comme « état », « plan » ou « chronogramme », et aucun ne dit
> lequel est vrai aujourd'hui. Celui-ci le dit. Les autres sont des **archives
> datées** : on les lit pour comprendre *pourquoi*, jamais pour savoir *où on en est*.
>
> **Relevé le : 13/08/2026.** Toute ligne non datée est réputée périmée.
> Toute affirmation ici doit être **mesurée**, jamais supposée (cf. §7).

---

> **PASSATION** — un rapport complet pour reprendre le chantier existe :
> `docs/PASSATION_STUDIO_3D_2026-08-14.md`. Il contient l'architecture, les
> chiffres mesurés, les huit couches du défaut, et cinq points de reprise
> ordonnés. Le lire avant ce fichier si l'on découvre le projet.

> **ATTENTION — un AUTRE chantier travaille sur ce dépôt.** Relevé le 18/08 :
> 28 fichiers non commités qui ne relèvent pas du Studio 3D (écrans étudiants,
> inscription/connexion par téléphone, `main.dart`, `notification_router.dart`,
> quatre widgets neufs, deux fichiers supprimés, et
> `docs/CANDIDATURE_DIALOGUES_EXPLICITES_2026-08-14.md`) — plus `capsule.mp4`
> à la racine, origine non confirmée. Ne pas les committer avec du travail
> Studio : une régression deviendrait indiscernable.
>
> **Ce chantier a été audité puis complété le 18/08**, à la demande de
> Jocelyn : le parrainage est désormais retiré **entièrement côté client**
> (et plus seulement l'écran) sur les deux parcours d'inscription, et le
> passage de l'OTP au mot de passe pour le téléphone est fini (textes,
> imports et fichier mort nettoyés). Détail complet dans
> `docs/JOURNAL_INTERVENTIONS.md` (section 2026-08-18). Point ouvert le plus
> sensible, inchangé : l'inscription par téléphone (`phone_signup_screen.dart`)
> suppose « Confirm phone » désactivé côté Supabase pour ouvrir une session
> sans SMS ; **non vérifié** — l'accès MCP Supabase en lecture seule manquait
> de jeton cette session. Rien commité, rien poussé, rien touché côté serveur.

## 1. Où on en est, en une phrase

Le **Studio visuel 3D** fabrique des capsules dont la forme est **composée par
l'IA** (verbes + coordonnées) et non plus choisie dans un catalogue. Depuis le
14/08, **la chaîne rend réellement des images sur GPU** (mesuré : 119/1154 puis
au-delà, travail `8b7c72d0`). Restent à vérifier : la vidéo livrée, et surtout
le **cadrage**, jamais contrôlé sur une image réelle.

## 2. La chaîne, et qui exécute quoi

```
Étudiant (Flutter, APK du 13/08 18h18)
  └─> Edge Function `whiteboard-generate-storyboard`   ← Supabase, déployée 13/08
       │   engine=studio → capsule COMPOSÉE (intention + gestes)
       └─> app.studio_jobs (statut a_preparer)
            ├─ déclencheur `studio_reveiller_sur_file` → `runpod-control` (créer)
            └─> LWS `studio-preparateur.service`        ← /opt/studio_visuel/
                 traduit si besoin, SYNTHÉTISE LA VOIX, cale les durées
                 └─> statut queued
                      └─> Pod RunPod (image academia0/academia-studio:1.2.0)
                           entree.sh → sonde → worker_pod.py → executer_capsule.py
                           → Blender EEVEE → images → montage → Storage
```

**Trois machines, trois codes différents — c'est la source des confusions :**

| Où | Quel code | Comment on le met à jour | Vérifié le |
|---|---|---|---|
| Supabase | Edge Functions | `supabase functions deploy` (CLI locale, projet lié) | 13/08 |
| LWS `31.207.38.60` | `/opt/studio_visuel/*.py` | `scp` puis `systemctl restart studio-preparateur` | 13/08 |
| Pod RunPod | dans l'image Docker | **construction + publication SUR LWS**, puis bascule de `app.studio_config` | 14/08 — **1.3.0** |

> **La construction de l'image ne passe plus par le poste de Jocelyn.** LWS a
> Docker 29.6.2 + buildx, 117 Go, et des identifiants Docker Hub déjà en place
> (`academia0`, vérifiés par une poussée d'essai le 14/08). Contexte de
> construction : `/opt/construction/`. Commande :
> `docker build -f image/Dockerfile --build-arg VERSION_MOTEUR=<v> -t academia0/academia-studio:<v> .`
>
> **Vérifier l'image avant de la publier**, jamais après :
> `docker run --rm -v /opt/construction/verifier.sh:/verifier.sh --entrypoint bash <image> /verifier.sh`

## 3. Ce qui est MESURÉ comme fonctionnant

- **Choix de l'étudiant transmis** — `engine: "studio"` arrive au serveur (12/08).
- **Composition par l'IA** — « Poussée d'Archimède », sujet jamais vu : 5 scènes,
  5 intentions distinctes (objet → flux → processus → comparaison → échelle),
  verbes `revolutionner`/`sculpter`/`extruder`, **0 correction**.
- **La composition survit à toute la chaîne** — manifeste préparé : 5 scènes sur 5
  portant leurs `gestes`, archétype vide (13/08, travail `afd29a95`).
- **Réveil événementiel** — machine créée **1,5 s** après l'insertion du travail.
- **Arrêt automatique** — machine coupée seule après 12 min de silence (`agent_muet`).
- **Rendu et style** — sur LWS *sans GPU*, Blender sort des PNG : filaire bleu
  émissif sur noir, conforme à la référence. Image témoin : `s1_0001.png`.
- **Dépense totale du chantier** : **0,19 $** (deux machines, 3,6 et 12,0 min).

## 4. Ce qui est CASSÉ, et ce qu'on en sait

### 4.1 ~~Le rendu GPU~~ — RÉSOLU le 14/08, et ce n'était PAS le GPU
Cause réelle : **deux chaînes de production tournaient en parallèle.** Le cron
`studio-orchestrateur` (toutes les 3 min) créait une machine avec une image
générique `runpod/pytorch:…` — sans Blender ni moteur — amorcée à chaud par
`studio-amorceur` sur LWS. Le 14/08 à 10:36:02 elle a créé sa machine ; à
10:36:03 la nouvelle chaîne a créé la sienne. **La vieille a attrapé le travail
et l'a tué en 4 secondes** ; la bonne machine, prête et vérifiée, est restée
inutilisée puis coupée pour silence.

Ce qui l'a longtemps masqué : le message d'erreur reçu (`aucune_image_produite`
sans détail) venait de l'ancien moteur, alors que l'image publiée contenait le
nouveau. J'avais « vérifié » l'image en comptant les occurrences du mot plutôt
qu'en cherchant la forme exacte du nouveau message — une vérification faible
qui a coûté une heure.

**Corrigé** : cron `studio-orchestrateur` désactivé (jobid 15), service
`studio-amorceur` arrêté et désinstallé sur LWS. `runpod-watchdog` conservé —
c'est le seul filet si une machine naissait par accident.

### 4.1 bis Le tirage du moteur — corrigé, à revérifier au prochain démarrage
`moteur_archive_incomplete` était un **faux échec** : l'archive portait un uid
Windows (197609) ; `tar` lancé en root échouait à le restituer et sortait en
code 2 **alors que l'extraction avait réussi**. Archive republiée avec un
propriétaire neutre (extraction vérifiée, code 0) et `entree.sh` extrait
désormais avec `--no-same-owner` — **pas encore dans une image publiée**.

### 4.-1 Le démarrage d'une machine prend jusqu'à 10 min, et on la tuait à 10
`silence_timeout_minutes` (10) courait **depuis la création de la machine**, pas
depuis le démarrage du conteneur. Or RunPod tire d'abord l'image — 4,47 Go — et
la durée dépend de l'hôte : 35 s le matin (image en cache), **10,4 min**
l'après-midi. Deux machines tuées pour `agent_muet` **sans avoir jamais émis un
mot**, pas même le « demarre » de la première seconde.

Écarté par la mesure avant de conclure : image toujours publiée (digest comparé),
dépôt **public** (`is_private: false`, 406 tirages), et `gpu_pod_journal` appelée
avec le jeton de la machine muette répond `success: true` — le canal marchait.

**Corrigé** : `gpu_pods_a_eteindre()` distingue deux états sur un fait observable
— le journal d'amorçage est-il vide ?
- jamais parlé → **délai d'amorçage 25 min** (`amorcage_jamais_abouti`)
- a parlé puis s'est tue → délai de silence 10 min (`agent_muet`)

Vérifié : la machine `xh08r0ktpmpiqm` a démarré à **10,4 min** et rendu ensuite.
Sous l'ancienne règle elle mourait quelques secondes avant d'être prête.

**Coût caché à traiter un jour** : 4,47 Go d'image pour un moteur de 82 Ko.

### 4.-2 Le moteur tiré depuis Storage — PROUVÉ le 14/08
Journal d'amorçage réel :
`demarre (image 1.3.0) > moteur_tirage (1.3.1) > moteur_installe (1.3.1) >
sonde_lancee > sonde_finie (code 0) > prete`

L'image reste en **1.3.0**, le moteur exécuté est **1.3.1**. Une correction du
moteur se livre désormais par un fichier déposé dans Storage
(`supabase storage cp`, CLI déjà liée, aucun secret manipulé) — **plus aucune
reconstruction d'image**. Si le tirage échoue, la sonde constate
`1.3.0 ≠ 1.3.1` et **refuse la machine** plutôt que de rendre avec un moteur
qu'on croyait remplacé.

### 4.0 La capsule est rendue ENTIÈREMENT, mais REFUSÉE à la livraison
Travail `8b7c72d0`, 14/08 : **1 155 images sur 1 154 rendues sur GPU**, montage
compris, machine tenue 50+ min. La porte d'acceptation a refusé :

```
image_figee : scene(s) noire(s) : s1=1.15, s2=0.84, s3=0.92 ; image figee 46.17 s
```

C'est le garde-fou du 05/08 qui fonctionne — une vidéo noire n'est pas livrée.
**Deux défauts réels derrière ce refus :**

**(a) Aucune animation dans le chemin composé.** `cadrer_sur` posait une caméra
FIXE, sans une image-clé. Les 1 154 images étaient identiques : 25 min de GPU
pour rendre 1 154 fois la même photo. Le chemin des archétypes, lui, animait
depuis toujours (`generateur_scenes._camera`). En écrivant le compositeur j'ai
porté la géométrie et le style, **et oublié le mouvement**.
→ Corrigé : `academia3d._orbiter()`, balayage par intention (14° comparaison →
34° échelle), interpolation LINÉAIRE. `generateur_scenes` passe `images` au
compositeur. **Rendu en cours de vérification, jamais vu en image.**

**(b) Trop sombre.** Luminance ≈ 1/255. Traits d'un pixel sur noir : illisible
sur un téléphone. La référence a des traits épais et un halo franc.
→ **NON corrigé.** Ne pas régler à l'aveugle : mesurer d'abord.

**(c) `sculpter` ne se voit pas.** Mesuré le 14/08 sur image réelle : le bécher
(`revolutionner`) s'affiche, la sphère (`sculpter`) est **absente de l'image**
alors que le compositeur la déclare faite et que `cadrer_sur` mesure sa boîte
englobante (11,65 unités pour la sphère seule → elle a bien une géométrie).
Deux causes possibles, **non tranchées** : arêtes devenues sub-pixel (la
division par l'échelle introduite le 13/08), ou surface du bécher qui masque.
Essai en cours en 270×480 avec une scène « sphère seule » pour trancher.

### 4.2 ~~Le cadrage~~ — VÉRIFIÉ EN IMAGE le 14/08, il fonctionne
`cadrage « objet » à 23,82 unités` au lieu des 9,0 fixes : le bécher entier
tient dans le cadre, centré. Le style filaire bleu sur noir est conforme à la
référence. C'était le point ouvert depuis deux jours ; il est clos.

### 4.2 bis (archive) Le cadrage — corrigé, NON VÉRIFIÉ
La caméra était à distance **constante** par intention. À 9 unités, une focale
50 mm sur cadre 9:16 ne montre que 3,6 unités de large ; l'IA avait écrit un
bécher de 6. L'image ne contenait que la paroi. Remplacé par
`academia3d.cadrer_sur()`, qui **mesure** la boîte englobante. **Jamais rendu.**

### 4.3 Ce que l'audit croisé a laissé en suspens
Audit des 6 verbes coupé par une limite de session : `revolutionner` et
`sculpter` conclus et corrigés ; **`silhouetter`, `extruder`, `napper`, `ecrire`
analysés mais non réfutés** — donc *non conclus*, pas *sains*.

## 5. Le verrou d'architecture : le moteur vit dans l'image

Corriger une ligne de Python du moteur exigeait : un poste allumé, Docker
démarré, 4,5 Go reconstruits, une publication. **Décision du 13/08 : on sépare.**

- l'**image** = Blender, Chromium, Node, ffmpeg, EGL — change quelques fois par an
- le **moteur** = les `.py` — tiré au démarrage depuis **Supabase Storage**

Écrit, non livré : `image/entree.sh` (tirage), `image/publier_moteur.sh` (dépôt).
**Reconstruction sur LWS**, qui a Docker 29.6.2 + buildx + 117 Go — **plus jamais
sur le poste de Jocelyn**.

## 6. Prochain pas, dans l'ordre

1. ~~`docker login` sur LWS~~ — **déjà fait par Jocelyn le 12/08**, vérifié le
   14/08 par une poussée d'essai. Je l'avais demandé sans avoir regardé.
2. ~~Construire et publier l'image **1.3.0** depuis LWS~~ — **fait le 14/08**,
   contenu vérifié *dans* l'image avant publication.
3. ~~Basculer `app.studio_config`~~ — **fait** (`image_pod`, `version_moteur` → 1.3.0).
4. ~~Relancer « Poussée d'Archimède »~~ — **lancé** le 14/08 12:21, travail
   `9c1d62d0`. Reconnu `capsule native — 5 scenes`.
5. ~~Lire la cause GPU~~ — **trouvée le 14/08, et ce n'était pas le GPU** (§4.1).
6. ~~Rendre le tirage du moteur utilisable~~ — bucket `studio-moteur` créé
   (public), `moteur-1.3.0.tar.gz` publié et **relu** (81 766 octets).
   Téléversement fait depuis le poste avec `supabase storage cp`, **sans
   manipuler de secret** : la CLI est déjà liée au projet. La clé de LWS, elle,
   n'a pas les droits (mesuré : `permission denied for table studio_jobs`).
7. **EN COURS** — la vidéo se dépose-t-elle ? (travail `8b7c72d0`, 1 154 images)
8. **VÉRIFIER LE CADRAGE sur une image réelle.** `cadrer_sur` n'a jamais été
   rendu ; c'est la seule inconnue de qualité qui reste.
9. Publier une image **1.3.1** portant `entree.sh --no-same-owner`, puis
   confirmer `moteur_installe` dans le journal d'amorçage.
10. Conclure les 4 verbes laissés en suspens par l'audit croisé (§4.3).

## 7. Les règles qui ne se négocient pas

1. **Ne jamais déduire un état de ce qu'on ne voit pas.** Le 12/08, l'image du
   pod n'a pas pu être inspectée (Docker éteint) : ça a été **dit**, pas supposé.
2. **100 % CSS** pour les animations du Smart Whiteboard (`record_scene.js`).
3. **Aucun calcul d'IA sur le VPS.**
4. **Dégradation gracieuse** : on nettoie, on ne rejette pas.
5. **Interdit sans accord explicite de Jocelyn** : écriture en base de
   production, déploiement d'Edge Function, migration distante, `git commit`,
   `git push`, publication Facebook ou Canva.
6. **Ne jamais lire ni committer** `~/.ssh/id_ed25519`. **Ne pas toucher au pare-feu.**

## 8. Dettes ouvertes

| Dette | Depuis | État |
|---|---|---|
| ~~65 fichiers non commités~~ | 07/08 | **soldée le 13/08** — 5 commits (`b2052b5` → `8f52c2a`), dépôt propre, **non poussé** |
| Deux jetons Docker Hub collés en conversation | 12/08 | **ouverte — à révoquer par Jocelyn** |
| ~~`CLAUDE.md` annonce un chantier abandonné~~ | 28/07 | **soldée le 13/08** — en-tête réécrit, §7 archivé, pointe vers ce fichier |
| 4 verbes sur 6 non conclus par l'audit croisé | 13/08 | **ouverte** — cf. §4.3 |
| Inscription téléphone : réglage Supabase « Confirm phone » non vérifié ; comptes de l'ancien parcours OTP potentiellement bloqués (plus de repli dans l'UI) | 18/08 | **ouverte** — cf. journal 18/08 ; demande un jeton MCP lecture seule ou une vérification par Jocelyn dans le tableau de bord |

---

## Comment on tient ce fichier à jour

- **Au début de chaque intervention** : le hook `etat_projet.py` en affiche
  l'essentiel. On le lit avant d'agir.
- **À chaque acte significatif** (déploiement, migration, image, mesure,
  décision) : une ligne dans `docs/JOURNAL_INTERVENTIONS.md`.
- **À la fin de chaque intervention** : §1, §3, §4 et §6 sont remis à jour.
  Le hook `fin_intervention.py` le rappelle si le dépôt a bougé sans que ce
  fichier ait été touché.
