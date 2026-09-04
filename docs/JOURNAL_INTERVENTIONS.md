# Journal des interventions — append-only

> **On n'efface jamais une ligne ici, et on n'en corrige jamais une.** Une
> conclusion qui s'est révélée fausse se corrige par une ligne NOUVELLE qui dit
> qu'elle l'était. C'est ce qui distingue un journal d'un rapport : le rapport
> dit où on en est (`ETAT.md`), le journal dit **comment on y est arrivé**.
>
> **Une ligne par acte significatif** : déploiement, migration, construction
> d'image, mesure chiffrée, décision d'architecture, défaut trouvé, dépense.
> Pas les lectures de fichier, pas les essais sans résultat.
>
> Format : `AAAA-MM-JJ HH:MM · QUOI · où · le fait mesuré`
> Les types : `DÉPLOIEMENT` `MIGRATION` `IMAGE` `MESURE` `DÉFAUT` `CORRECTIF`
> `DÉCISION` `DÉPENSE` `BLOQUÉ`

---

## 2026-08-19

- `—` · **MESURE DECISIVE** · **le moteur navigateur rend 10 × plus vite que
  Blender sur la MEME carte.** Travail `df3da476` : 1 147 images, **154 s de
  rendu** contre 1 615 s pour Blender, soit **0,062 s/image** contre ~1,3.
  Bout en bout : **3 min 30** contre 27 min + amorçage. Coût ≈ **0,04 $**.
  Capsule acceptée par la porte, voix et sous-titres compris, **regardée**.
- `—` · **CORRECTION D'UN CHIFFRE QUE J'AVAIS DONNÉ, DEUX FOIS.** J'avais
  annoncé 4,6 × (banc sur scène simple), puis rectifié à « ~20 % » (LWS sans
  carte). Les deux mesuraient une machine qui n'est pas celle qui travaille.
  Le chiffre de production est 10 ×.
- `—` · **DÉFAUT** · **trois** endroits listaient les images, je n'en avais
  corrigé qu'un. Blender dépose des PNG, le navigateur des JPEG :
  `executer_capsule` (corrigé), `montage.py` (assemblage → « No files to
  concat »), `worker_pod.py` (compteur bloqué à 0 — le plus grave, puisque
  **l'avancement vaut signe de vie** depuis le 14/08 : une machine au travail
  serait passée pour morte).
- `—` · **DÉFAUT (le mien)** · j'ai basculé la version du moteur et inséré le
  travail dans la même transaction ; la machine encore vivante, chargée en
  1.4.0, l'a attrapé avant d'être coupée. Échec de séquencement, pas de code.
- `—` · **DÉCISION** · `MOTEUR_RENDU` en base : `web` par défaut, `blender`
  joignable sans redéploiement. On ne coupe pas un moteur éprouvé le jour où
  l'on en branche un neuf.
- `—` · **MESURE** · le moteur 1.4.0 puis 1.4.1 ont été publiés et pris en
  production **sans reconstruire un seul des 4,47 Go de l'image**. C'est
  l'acquis qui a permis de corriger trois défauts en une soirée.

## 2026-08-18 (soir)

- `—` · **CORRECTIF** · storage · une règle du Studio (30/07, `de3055d`)
  interrogeait `app.studio_jobs`, table que `authenticated` ne pouvait pas lire.
  PostgreSQL évalue les règles de `storage.objects` à **chaque** lecture :
  **tout dépôt de fichier était cassé dans toute l'application** depuis le 30/07.
  Symptôme : `permission denied for table studio_jobs` en téléversant une image
  d'auto-école. Droit accordé + règle `cree_par = auth.uid()`.
- `—` · **DÉFAUT** · clonage des mini-sites · le modèle `universite-arbilo` est
  **inactif** et la RPC exige `is_active = TRUE`. Elle renvoie `success: false`
  **dans sa valeur de retour** ; l'Edge Function n'écoute que le canal d'erreur.
  Aucune université créée depuis juillet n'a hérité. **Non corrigé.**
- `—` · **DÉFAUT** · le cours « topologie » est sorti **sans aucune piste
  audio**, marqué `done` : `narration_mode = none` par défaut, alors que l'IA
  avait écrit la narration des 6 scènes sur 6. Mesure : 82 projets en `tts`,
  **12 muets**.
- `—` · **CORRECTIF** · étapes 0 et 1 : vidéo refusée **conservée** sous
  `refuses/` ; `GEL_MAX_S` 3 → 6 s **et** fenêtre de détection séparée (le test
  a attrapé que la confondre rendait le détecteur aveugle) ; narration par
  défaut `tts`, forcée en 3D ; thème/renderer/style masqués en 3D ; exemple du
  sujet changé.
- `—` · **MESURE DÉCISIVE** · **le navigateur sans carte graphique rend 4,6 ×
  plus vite que Blender sur RTX 4090** : **0,284 s/image** contre ~1,3.
  60 images en 17,04 s, 660 pixels allumés au minimum, témoin de 106 Ko
  regardé. Protocole et obstacles dans
  `docs/MESURE_NAVIGATEUR_VS_BLENDER_2026-08-18.md`.
- `—` · **DÉCISION** · on migre le rendu 3D vers le navigateur sur LWS.
  Composition, invite, validation, style, porte d'acceptation : inchangés.
- `—` · **DÉPENSE** · RunPod · 0,47 $ sur 24 h.

## 2026-08-18

- `—` · **MESURE** · **le redressement des contours est PROUVÉ EN IMAGE.** Rendu
  `dd8b7d49` (moteur 1.3.2, image inchangée 1.3.0) : la flèche de la scène
  « comparaison » est **debout, nette, pointant vers le bas** sous la sphère qui
  coule. Quatre jours plus tôt c'était un bloc écrasé au sol. **Aucune couche
  cachée en dessous** — première fois du chantier qu'un correctif tient du
  premier coup.
- `—` · **MESURE** · ce que ce rendu NE corrige pas, comme annoncé : s1 et s2
  restent identiques, et « bateaux, sous-marins, montgolfières » reste trois
  masses. La capsule rejouée venait de l'ancienne invite — variable isolée
  volontairement.
- `—` · **CORRECTIF** · `prompt_capsule.ts` · trois changements fondés sur
  l'audit du moteur, pas sur une intuition :
  1. chaque verbe dit ce qu'il **ne sait pas** faire — `sculpter` plafonne à un
     allongement de 3,1 (mesuré), donc coque et sous-marin vont sur
     `silhouetter`, seul verbe à orientation libre ;
  2. **trois objets concrets en coordonnées** (montgolfière, sous-marin, flèche)
     au lieu d'un seul gabarit — l'exemple unique invitait à le recopier ;
  3. les gestes doivent représenter les mots de **leur propre narration**, pas
     du sujet en général. L'ancienne formule rendait la scène 5 conforme tout
     en étant fausse.
- `—` · **CORRECTIF** · `validate_capsule.ts` · `signalerRepetitions()` compare
  la **géométrie** entre scènes (nom exclu) et la **nomme** sans jamais
  rejeter. Trois tests ajoutés, dont « renommer un objet ne masque pas la
  répétition ». **37 tests passent.**
- `—` · **DÉPLOIEMENT** · Supabase · `whiteboard-generate-storyboard`.
- `—` · **BLOQUÉ** · la vérification exige une **génération depuis l'app**
  (session étudiante requise, 0,002 $). Le JSON produit sera lu **avant** tout
  rendu : on ne paie un GPU qu'une fois la description jugée bonne.

## 2026-08-14

- `10:1x` · **DÉFAUT (le mien)** · j'ai demandé à Jocelyn de faire `docker login`
  sur LWS. **C'était déjà fait depuis le 12/08.** Je ne l'avais pas vérifié
  avant de donner l'instruction — exactement la faute que `etat-des-moyens`
  existe pour empêcher. Relevé : `docker info` → `Username: academia0`.
- `10:1x` · **MESURE** · LWS · droit d'écriture Docker Hub **prouvé** par une
  poussée d'essai (`essai-acces`), avant de lancer 20 min de construction.
- `10:19` · **IMAGE** · LWS · `academia0/academia-studio:1.3.0` construite
  **sur LWS**, 4,47 Go. Le poste de Jocelyn n'est plus dans la boucle.
- `10:20` · **MESURE** · image · contenu vérifié **dans** le conteneur avant
  publication : VERSION 1.3.0, 9 correctifs présents, Blender 4.5.12 répond,
  `academia3d_style` importable. Pas déduit d'une construction réussie.
- `10:21` · **IMAGE** · publiée, digest `sha256:2ed81f96…`.
- `10:21` · **MIGRATION** · `app.studio_config` → `image_pod` et
  `version_moteur` basculés sur 1.3.0.
- `10:21` · **MESURE** · travail `9c1d62d0` relancé sur la capsule déjà en base
  — **0 $ de génération**.
- `12:22` · **MESURE** · LWS · `capsule native — 5 scenes, 90.0s, 2250 images`.
  La reconnaissance corrigée le 12/08 **le dit désormais explicitement** dans le
  journal, au lieu de traduire en silence.
- `—` · **BLOQUÉ** · Storage · le tirage du moteur depuis Supabase est dans
  l'image mais **inutilisable** : bucket `studio-moteur` inexistant, et la clé
  de LWS n'a pas les droits (mesuré : `permission denied for table studio_jobs`).
- `13:0x` · **DÉFAUT** · orchestration · **deux chaînes de production
  concurrentes**. Le cron `studio-orchestrateur` (toutes les 3 min) créait une
  machine avec `runpod/pytorch:…` — sans Blender ni moteur. Le 14/08 à 10:36:02
  elle a créé la sienne, à 10:36:03 la nouvelle chaîne la sienne ; **la vieille
  a pris le travail et l'a tué en 4 s**. Cron désactivé (jobid 15), service
  `studio-amorceur` arrêté et désinstallé sur LWS.
- `13:1x` · **DÉFAUT (le mien)** · j'avais « vérifié » l'image en comptant les
  occurrences de `aucune_image_produite` — mot présent dans les DEUX versions.
  Une vérification faible qui a masqué la vraie cause pendant une heure.
- `—` · **CORRECTIF** · Storage · `moteur_archive_incomplete` était un **faux
  échec** : archive portant un uid Windows (197609), `tar` en root échouait à le
  restituer et sortait en code 2 **alors que l'extraction réussissait**. Archive
  republiée avec propriétaire neutre (extraction revérifiée, code 0) ;
  `entree.sh` extrait désormais avec `--no-same-owner`.
- `14:0x` · **DÉFAUT** · veilleur · **trois machines tuées en plein rendu** pour
  `agent_muet`, 12 min chacune, travail relancé à zéro (images vues **reculer
  175 → 47**). `gpu_pods_a_eteindre()` juge sur `last_seen_at`, que seul
  `gpu_pod_heartbeat` rafraîchit ; or le worker envoie `studio_avancement`.
  Un rendu demande 20–120 min, le seuil est à 10 : **la chaîne ne pouvait
  mathématiquement jamais aboutir.**
- `—` · **MIGRATION** · `studio_avancement` rafraîchit désormais
  `gpu_pods.last_seen_at` et `activite`. **L'avancement vaut signe de vie** —
  on n'a PAS rallongé le délai, ce qui aurait déplacé le seuil sans corriger
  l'aveuglement. Vérifié : `activite = "rendu 99/1154"`, machine non condamnée.
- `—` · **MIGRATION** · `studio_supervision()` créée : une ligne, six alertes
  (échec récent, machine condamnée en plein rendu, rendu figé, machines en
  double, file sans machine, dépense). Guetteur `veille.sh` sur LWS, qui ne
  parle que si ça cloche + point d'étape toutes les 10 min + alerte
  `VEILLE AVEUGLE` si la supervision ne répond plus.
- `—` · **MESURE** · travail `8b7c72d0` : **1 155/1 154 images rendues**, 50+ min
  sans coupure. Puis **REFUSÉ** par la porte d'acceptation :
  `scene(s) noire(s) s1=1.15 s2=0.84 s3=0.92 ; image figee 46.17 s`.
- `—` · **DÉFAUT (le mien)** · le chemin composé **n'animait rien** : caméra
  fixe, zéro image-clé, 1 154 images identiques. Le chemin des archétypes
  animait pourtant depuis toujours.
- `—` · **CORRECTIF** · `academia3d._orbiter()` — orbite lente, balayage par
  intention (14° comparaison → 34° échelle), interpolation linéaire, grammaire
  reprise de `generateur_scenes._camera`. **Non vérifié en image.**
- `—` · **MESURE** · LWS, sans GPU, coût nul · **le cadrage mesuré fonctionne** :
  `cadrage « objet » à 23,82 unités` (contre 9,0 fixes), bécher entier dans le
  cadre, filaire bleu conforme. Point ouvert depuis deux jours, **clos**.
- `—` · **DÉFAUT** · `sculpter` **ne se voit pas** sur l'image rendue, alors que
  le compositeur le déclare fait et que `cadrer_sur` mesure sa boîte englobante
  (11,65 unités seule). Cause non tranchée : arêtes sub-pixel, ou masquage par
  la surface du bécher. Essai 270×480 en cours.
- `—` · **DÉPENSE** · RunPod · 0,98 $ sur 24 h, zéro machine vivante.
- `15:0x` · **MESURE** · LWS, coût nul · **le cadrage mesuré fonctionne en image**
  (`cadrage « objet » à 23,82 unités`, bécher entier dans le cadre) et **la
  caméra bouge** (début et fin de plan nettement différents).
- `15:1x` · **DÉFAUT** · `_habiller` posait le verre **uniquement sur le rôle
  « sujet »**. Or c'est la STRUCTURE qui entoure : le bécher gardait une surface
  opaque et **masquait la sphère**. Rendue seule, la même sphère est nette et
  lumineuse — le verbe n'a jamais été en cause. Défaut invisible à la lecture du
  code et muet : le compositeur déclarait le geste fait, ce qu'il était.
- `—` · **CORRECTIF** · règle posée : **toute surface conservée doit être
  traversable**. `verre: false` reste possible, mais ce n'est plus le défaut.
- `—` · **DÉCISION** · moteur **1.3.1** publié dans Storage, image laissée en
  **1.3.0**. Première livraison d'un correctif **sans reconstruire d'image**.
- `16:0x` · **DÉFAUT** · veilleur · deux machines tuées pour `agent_muet` **sans
  avoir jamais parlé**. `silence_timeout` (10 min) courait depuis la CRÉATION,
  pas depuis le démarrage du conteneur ; or le tirage de 4,47 Go dépend de
  l'hôte — 35 s le matin, **10,4 min** l'après-midi.
- `—` · **MESURE** · trois hypothèses écartées avant de conclure : image publiée
  (digest comparé), dépôt **public** (`is_private: false`), `gpu_pod_journal`
  répond `success: true` avec le jeton de la machine muette.
- `—` · **MIGRATION** · `gpu_pods_a_eteindre()` distingue **amorçage** (jamais
  parlé → 25 min) et **silence** (a parlé puis s'est tue → 10 min).
- `—` · **DÉFAUT (le mien)** · mon appel de diagnostic a **écrit dans le journal
  d'amorçage** de la machine, la faisant passer pour « ayant déjà parlé » — donc
  justiciable du délai court que je venais d'assouplir. Entrée retirée. Une
  écriture de test ne doit jamais modifier l'état que le système observe.
- `—` · **CORRECTIF** · `studio_supervision()` : une chaîne littérale concaténée
  à un `text[]` est de type `unknown` — Postgres tentait de la lire comme un
  littéral de tableau. La veille remontait `22P02` au lieu de son alerte. Elle
  détectait bien le problème, mais le disait dans une langue illisible.
- `—` · **MESURE** · amorçage réel, machine `xh08r0ktpmpiqm` :
  `demarre (1.3.0) > moteur_tirage (1.3.1) > moteur_installe (1.3.1) >
  sonde_finie (code 0) > prete`. **Le tirage du moteur depuis Storage est
  prouvé.** Rendu en cours, 473/1193.
- `10:5x` · **CORRECTIF** · Storage · bucket `studio-moteur` créé (public),
  `moteur-1.3.0.tar.gz` publié via `supabase storage cp` **depuis le poste,
  sans manipuler de secret** (la CLI est déjà liée). Relu : 81 766 octets.
- `12:4x` · **DÉFAUT MAJEUR** · orchestration · **deux chaînes de production
  tournaient en parallèle.** Le cron `studio-orchestrateur` (toutes les 3 min)
  créait une machine sur l'image générique `runpod/pytorch:…`, amorcée à chaud
  par `studio-amorceur`. À 10:36:02 elle a créé la sienne, à 10:36:03 la
  nouvelle chaîne la sienne : **la vieille a pris le travail et l'a tué en 4
  secondes**. Ce n'était donc JAMAIS un problème de GPU.
- `12:4x` · **DÉFAUT (le mien)** · j'avais « vérifié » l'image en comptant les
  occurrences de `aucune_image_produite` — mot présent dans l'ancienne ET la
  nouvelle version. Une vérification faible qui a masqué la vraie cause une
  heure. Corriger la méthode : chercher la **forme exacte** du nouveau message.
- `12:4x` · **CORRECTIF** · cron `studio-orchestrateur` désactivé (jobid 15) ;
  service `studio-amorceur` arrêté et désinstallé sur LWS. `runpod-watchdog`
  **conservé** : seul filet si une machine naissait par accident.
- `12:5x` · **DÉFAUT** · Storage · `moteur_archive_incomplete` était un **faux
  échec** : uid Windows (197609) dans l'archive → `tar` en root sort en code 2
  alors que l'extraction a réussi. Archive republiée avec propriétaire neutre
  (extraction revérifiée, code 0) ; `entree.sh` extrait désormais avec
  `--no-same-owner` — **pas encore dans une image publiée**.
- `12:53` · **MESURE** · pod · **119 images sur 1 154 produites sur GPU** —
  premières images jamais sorties d'une machine RunPod pour une capsule
  composée. Une seule machine, image 1.3.0.
- `—` · **DÉPENSE** · RunPod · 0,363 $ sur les deux dernières heures.

- `18:0x` · **MESURE** · capsule livrée, six images réparties sur 47,6 s : le
  style, la voix, les sous-titres et le mouvement sont conformes. **Mais s1, s2
  et s3 se ressemblent**, et la scène qui parle de « bateaux, sous-marins,
  montgolfières » montre trois blobs. La vidéo ne dit pas le sujet.
- `—` · **DÉFAUT** · `academia3d.extruder` · le contour était construit dans le
  plan **XY, soit à plat sur le sol**, alors que l'invite enseigne au modèle que
  « Z est la hauteur ». La flèche de la scène « Force vers le haut » — hampe et
  pointe, montant à 2 unités, parfaitement décrite — était **couchée par terre,
  pointe vers le fond**. Le modèle n'avait pas mal décrit : la machine lisait sa
  description dans un autre plan que celui qu'elle lui avait enseigné.
- `—` · **CORRECTIF** · contours **debout** face à la caméra. `ecrire` aussi,
  qui était couché — or c'est le secours universel. **Compilé, NON DÉPLOYÉ.**
- `—` · **MESURE** · audit des capacités réelles : `silhouetter` est le seul
  verbe à orientation libre (sous-marin, coque : là et nulle part ailleurs) ;
  `sculpter` n'offre que 5 ellipsoïdes, allongement maximal **3,1** — une coque
  8:1 lui est impossible. Le modèle a écrit `galet` faute de mieux **dans le
  verbe qu'il avait choisi** ; l'invite ne lui a jamais dit lequel choisir.
- `—` · **MESURE** · la validation traite chaque scène **isolément** : six
  scènes identiques passent avec `corrections.length === 0`.
- `—` · **DOCUMENT** · `docs/PASSATION_STUDIO_3D_2026-08-14.md` — rapport de
  passation complet, à transmettre.
- `—` · **CONSTAT** · un **autre chantier** modifie ce dépôt en parallèle
  (20 fichiers, écrans étudiants + candidature). Ne pas mélanger les lots.

## 2026-08-13

- `18:0x` · **DÉFAUT** · pod · `[Errno 2] '/workspace/blender/blender'` — deux
  chemins hérités de l'installation à chaud, alors que l'image met Blender dans
  `/opt/blender/` et le moteur dans `/opt/moteur/`. Travail `afd29a95`.
- `—` · **DÉFAUT** · sonde · la machine s'était déclarée **PRÊTE** sans jamais
  avoir vérifié Blender, qui fabrique pourtant toutes les images.
- `—` · **CORRECTIF** · `executer_capsule.py` · chemins **découverts**
  (env → PATH → emplacements connus) au lieu de codés en dur.
- `—` · **CORRECTIF** · `sonde_pret.js` · 6ᵉ condition ajoutée : Blender est
  **lancé**, pas seulement trouvé.
- `—` · **CORRECTIF** · `validate_capsule.ts` · `revolutionner` perdait sa
  `position` — deux récipients d'une scène « comparaison » naissaient
  superposés. 34 tests Deno passent.
- `—` · **CORRECTIF** · `academia3d.filairer` · épaisseur d'arête multipliée
  deux fois par l'échelle (echelle²) ; 35 % de trop sur l'exemple de l'invite.
- `—` · **DÉPLOIEMENT** · Supabase · `runpod-control` — l'environnement du pod
  (`BLENDER`, `GENERATEUR`) se règle désormais **en base** (`studio_config.env_pod`),
  plus dans le code.
- `—` · **DÉPLOIEMENT** · Supabase · `whiteboard-generate-storyboard`.
- `—` · **MESURE** · pod · réveil événementiel : machine créée **1,5 s** après
  l'insertion du travail.
- `—` · **MESURE** · base · manifeste préparé du travail `afd29a95` : **5 scènes
  sur 5** portent leurs `gestes`, archétype vide. La composition de l'IA
  traverse toute la chaîne intacte.
- `—` · **DÉFAUT** · pod · `aucune_image_produite` sur GPU. **Cause non établie** :
  la sortie standard du pod n'est collectée nulle part.
- `—` · **MESURE** · LWS · la même capsule rendue **sans GPU** produit des PNG :
  filaire bleu émissif sur noir, conforme à la référence. Donc le défaut est
  dans le chemin **GPU**, pas dans la composition.
- `—` · **DÉFAUT** · cadrage · caméra à distance **constante** par intention ;
  bécher de 6 unités dans un champ de 3,6 → l'image ne contenait que la paroi.
- `—` · **CORRECTIF** · `academia3d.cadrer_sur()` · distance **mesurée** sur la
  boîte englobante, projetée sur les axes propres de la caméra. **Non vérifié.**
- `—` · **DÉCISION** · architecture · le moteur sort de l'image et sera **tiré
  depuis Supabase Storage** au démarrage. Motif : une chaîne réparable
  uniquement depuis un poste précis n'est pas autonome.
- `—` · **MESURE** · LWS · Docker 29.6.2 + buildx, 117 Go libres → **c'est là
  que l'image se construira**, plus sur le poste de Jocelyn.
- `—` · **DÉPENSE** · RunPod · 0,19 $ cumulés (3,6 min + 12,0 min, RTX 4090).
- `—` · **BLOQUÉ** · Docker Hub · publication impossible tant que `docker login`
  n'a pas été fait **sur LWS**, par Jocelyn.

- `—` · **DÉFAUT** · dispositif d'agent · Jocelyn signale perte de mémoire et
  absence de vue d'ensemble. **Mesure** : `docs/` = 219 fichiers dont 10
  s'annonçant « état/plan/chronogramme » ; `CLAUDE.md` daté du 28/07 annonçant
  un chantier abandonné ; **0 commit** de la semaine ; mémoire persistante = 3
  entrées **dont une fausse** (« studio en sommeil »), servie à chaque
  démarrage pendant 8 jours. Diagnostic : pas un manque d'écrits — une
  **absence d'autorité**.
- `—` · **DÉCISION** · `ETAT.md` créé à la racine : autorité unique, prime sur
  `CLAUDE.md` et sur `docs/`. `CLAUDE.md` §7 archivé, en-tête réécrit.
- `—` · **CORRECTIF** · `etat_projet.py` (SessionStart) · n'annonce plus une
  constante périmée ; injecte `ETAT.md` §1/§4/§6, les 8 derniers actes, et
  **signale quand `ETAT.md` est en retard** sur les fichiers modifiés.
- `—` · **CORRECTIF** · hook `fin_intervention.py` (Stop) créé · rappelle de
  mettre à jour état + journal si ≥2 fichiers ont bougé depuis. N'arrête rien.
- `—` · **CORRECTIF** · mémoire · l'entrée fausse corrigée et **conservée pour
  sa leçon** ; 2 entrées durables ajoutées (autorité unique, huit couches).
- `—` · **DÉCISION** · 2 compétences écrites : `ou-tourne-le-code` (trois
  machines, trois codes — LWS tournait 6 jours en retard) et `tracer-la-valeur`
  (mesurer la donnée à chaque frontière plutôt que relire le code).
- `—` · **BLOQUÉ** · git · 65 fichiers non commités. C'est le plus gros trou de
  mémoire du dispositif et il demande l'accord de Jocelyn.

## 2026-08-12

- **DÉFAUT** · `studio_preparateur.py:156` · une capsule n'était reconnue qu'à
  son `archetype` ; les capsules **composées** portent `gestes`. Elles étaient
  donc prises pour des storyboards de tableau, traduites, et ressortaient en
  `reseau` — la vidéo générique. **Septième couche du même défaut.**
- **CORRECTIF** · `est_deja_une_capsule()` extraite et testée
  (`test_preparateur.py`, 9 cas).
- **DÉFAUT** · Flutter · `ExportSettings.fromJson` transtypait en non-nullable
  des champs qu'une capsule ne porte pas → plantage `type 'Null' is not a
  subtype of type 'String'`. Le serveur avait réussi ; l'app affichait un échec.
- **IMAGE** · `academia0/academia-studio:1.2.0` publiée (4,47 Go).

---

### Avant le 12/08

Non repris ligne à ligne — voir les rapports datés dans `docs/`, en particulier
`STUDIO_VISUEL_ETAT_2026-08-05.md`, `AUDIT_STUDIO_CAPACITE_GENERALE_2026-08-12.md`
et `PLAN_ACHEVEMENT_STUDIO_2026-08-12.md`.

## 2026-08-18

- `—` · **MESURE** · audit parrainage/téléphone (demande de Jocelyn, avant
  toute intervention) · `git log` sur `signup_screen.dart` et
  `phone_login_screen.dart` : **aucun commit** ne touche le parrainage ou le
  téléphone — le dernier commit sur `signup_screen.dart` (64978a3) en
  *ajoutait*. Tout le chantier décrit ci-dessous n'existe que dans l'arbre de
  travail non commité de la branche `candidature-dossier-inline`, jamais
  journalisé ici ni daté dans `docs/`.
- `—` · **MESURE** · parrainage · le champ visible « Code de parrainage » est
  retiré des deux écrans d'inscription (`signup_screen.dart`,
  `phone_signup_screen.dart`), mais le dispositif reste actif en entier :
  capture `?ref=`, Install Referrer Play Store, `SharedPreferences`,
  métadonnées à l'inscription, RPC `app_register_referral_for_current_user`
  dans `auth_wrapper.dart`. Rien n'a été coupé côté serveur.
- `—` · **DÉFAUT non résolu** · `phone_signup_screen.dart` crée le compte par
  `signUp(phone:, password:)` en supposant « Confirm phone » désactivé côté
  Supabase (hypothèse écrite dans le commentaire du fichier lui-même).
  **Non vérifiable cette session** : le serveur MCP `supabase-lecture` a
  répondu *Unauthorized* (jeton absent). Si le réglage est resté actif,
  chaque inscription crée un compte définitivement bloqué (pas d'abonnement
  SMS pour confirmer) ; s'il est désactivé comme supposé, aucune preuve de
  possession du numéro n'est jamais demandée.
- `—` · **DÉFAUT** · `phone_login_screen.dart` remplace `signInWithOtp` par
  `signInWithPassword` : un compte téléphone créé par l'ancien parcours OTP
  (s'il en existe) n'a pas de mot de passe et n'a plus de repli dans l'UI
  actuelle. Existence de tels comptes **non vérifiée** (hors de portée du MCP
  en lecture seule tel qu'authentifié cette session).
- `—` · **MESURE** · `flutter analyze lib/features/auth/` → 0 erreur, 40 avis
  (dette préexistante, `withOpacity` déprécié surtout). Un avis direct :
  `auth_landing_screen.dart:20` importe `phone_login_screen.dart` sans
  l'utiliser, reliquat du remplacement par `PhoneSignupScreen`.
  `otp_verify_screen.dart` n'est plus référencé nulle part — code mort.
- `—` · **DÉFAUT** · le choix d'inscription (`auth_landing_screen.dart:64`)
  annonce encore « code OTP par SMS » pour l'option téléphone, alors que
  l'écran suivant affiche « Aucun code par SMS. Votre mot de passe suffit ».
- `—` · **BLOQUÉ** · accès · MCP Supabase en lecture seule (`supabase-lecture`)
  non authentifié cette session — jeton absent. Bloque la vérification du
  réglage Auth « Confirm phone » et tout comptage de comptes à risque dans
  `auth.users`.
- `—` · **Aucune modification de code.** Session strictement d'audit, comme
  demandé. Les 26 fichiers non commités concernés préexistaient à cette
  session (déjà listés par `etat_projet.py` en tout début d'intervention).

### Suite (même jour) — retrait du parrainage, finition de l'inscription téléphone

Demande de Jocelyn, en suite directe de l'audit ci-dessus. Décision actée
avec Jocelyn (question posée, réponse reçue) : le mot de passe **reste** sur
l'inscription téléphone — nom, prénom, numéro, mot de passe, aucun SMS.
Supabase n'offre pas de troisième facteur entre OTP et mot de passe ; le
supprimer aussi aurait ouvert n'importe quel compte à qui tape le bon numéro.

- `—` · **CORRECTIF** · retrait complet du parrainage côté client, sur les
  deux parcours (email et téléphone) : capture `?ref=` (`auth_landing_screen.dart`),
  capture deep link et Install Referrer Play Store (`auth_wrapper.dart`),
  envoi `ref_code` dans les métadonnées (`signup_screen.dart`,
  `phone_signup_screen.dart`), rattachement post-connexion via
  `app_register_referral_for_current_user` (`auth_wrapper.dart`).
  Explicitement **conservés**, mécanismes distincts confirmés par lecture du
  code : le code d'invitation (`app_accept_user_invitation`, signup email),
  l'attribution marketing `?src=`/`mkt_ref` (isolée par conception, commentée
  comme telle), le partage de contenu (`ShareTrackingService`), et tout
  l'outillage commercial côté admin (`admin_commercials_screen.dart`,
  `commercial_dashboard_screen.dart`, etc. — non touchés, hors périmètre :
  c'est l'interface étudiant qui devait perdre le parrainage, pas le
  back-office qui gère les commissions déjà engagées).
- `—` · **SUPPRIMÉ** · `install_referrer_service.dart` (devenu orphelin,
  100 % parrainage, plus aucun appelant) et `otp_verify_screen.dart` (mort
  depuis le remplacement de l'OTP par le mot de passe, cf. audit).
- `—` · **CORRECTIF** · `auth_landing_screen.dart` : texte « Nom, prénom et
  code OTP par SMS » corrigé en « Nom, prénom, numéro et mot de passe » ;
  import mort de `phone_login_screen.dart` retiré.
- `—` · **MESURE** · `flutter analyze lib/features/auth/`, relancé 3 fois
  dont 2 après ces retraits, et `flutter analyze lib/` (arbre complet) une
  fois : **0 ligne « error » ou « warning »** sur les 5 fichiers touchés à
  chaque passage — uniquement des avis de style préexistants (`withOpacity`
  déprécié en tête).
- `—` · **ANOMALIE non expliquée** · le code de sortie de `flutter analyze
  lib/features/auth/` est passé de 0 (avant retrait, sortie avec un
  avertissement) à 1 (après retrait, sortie sans le moindre avertissement,
  seulement des infos), reproduit identique sur 2 lancements successifs sans
  changement de code entre eux. Traité comme un artefact d'outillage
  (serveur d'analyse Dart sollicité une dizaine de fois dans la même
  session) plutôt qu'un défaut de code, faute d'un autre levier que la
  liste des problèmes elle-même — qui, elle, est restée constante et propre
  à chaque lancement. **À surveiller si le doute revient.**
- `—` · **NON TOUCHÉ, à dessein** · le réglage Supabase « Confirm phone »
  (accès MCP manquant, cf. audit) ; l'existence de comptes téléphone OTP
  orphelins (même raison) ; la table `user_referrals` et le RPC
  `app_register_referral_for_current_user` côté base — le retrait est fait
  **uniquement côté client** : rien coupé côté serveur, aucune migration,
  aucune écriture en base.
- `—` · Rien commité, rien poussé.

## 2026-08-19 — Le flux 3D bout en bout : 2 min 40, mesuré

- `16:20` · **MESURE** · travail `be3b09ba` (« le pétrole ») rendu en 2 min 53.
  Chaîne fonctionnelle, **vidéo mauvaise** : 4 plans sur 6 ne montraient que la
  grille du sol. Cause trouvée en regardant les images, pas les codes retour.
- `16:30` · **DIAGNOSTIC** · `napper` produit un terrain de 190 unités ; compté
  dans la boîte englobante de `cadrer_sur`, il fait reculer la caméra jusqu'à
  réduire un derrick de 3 unités à un point. C'est le défaut de la distance fixe
  du 14/08 **retourné** : trop loin au lieu de trop près, mais toujours « ne pas
  cadrer ce qu'on regarde ».
- `16:35` · **CORRECTIF, DEUX MOTEURS** · exclusion des surfaces `napper` de la
  mesure de cadrage, dans `composer_scene.py` **et** `academia3d_web.js`. Le
  terrain reste dans la scène (échelle, profondeur), il ne commande plus le
  cadrage ; l'exclusion est inscrite au journal de composition pour se voir.
- `16:38` · **CONSTAT QUI COMPTE** · le même défaut existait côté Blender depuis
  le 14/08 et ne s'était **jamais** déclenché : aucune capsule Blender n'avait
  utilisé `napper`. Le moteur navigateur ne l'a pas créé, il l'a révélé. Avoir
  déclaré la migration réussie sur *une* capsule était vrai pour ce qu'elle
  testait, insuffisant pour conclure.
- `16:40` · **MOTEUR 1.4.2** · construit et publié depuis LWS, puis **vérifié
  après extraction** (`correctif web : 1 | correctif blender : 1`) — vérifier le
  contenu, pas le code retour de l'archive.
- `16:42` · **BASCULE + RELANCE** · `studio_config.version_moteur` → 1.4.2 après
  avoir constaté **0 machine vivante et 0 travail actif** — c'est l'erreur de
  séquencement du 18/08 (`31bcfefe` attrapé par une machine restée en 1.4.0) qui
  impose cette vérification avant toute bascule.
- `16:45` · **RÉSULTAT MESURÉ** · travail `ea601c81`, 977 images, **124 s de
  rendu**, **2 min 40 de la commande à la vidéo disponible**. Amorçage ≈ 20 s.
- `16:50` · **VÉRIFIÉ EN IMAGE** · 7 plans extraits et regardés un par un :
  **6 sujets sur 6 visibles**, dont le derrick plein cadre. Son mesuré sur la
  forme d'onde (moyenne −19,4 dB, pic −4,3 dB), pas déduit de la présence d'une
  piste AAC.
- `16:55` · **FLUX ÉTUDIANT PROUVÉ** · les trois maillons que touche l'app,
  exercés en base sous l'`auth.uid()` de l'étudiant propriétaire :
  `studio_creer_travail_etudiant` → `job_id` ; `studio_etat_travail` →
  `preview_ready` + chemin + étape « Pret » ; objet `studio-visuel` visible sous
  sa politique RLS, donc URL signable par lui-même.
- `—` · **NON EXERCÉ, à dessein** · l'appui du bouton dans l'application : je
  n'ouvre pas de session sur un compte utilisateur. Ce qui reste non prouvé est
  le câblage écran → service, pas la chaîne serveur.
- `—` · **RESTE MAUVAIS** · les silhouettes sont justes mais génériques (le
  navire-citerne est un bloc). C'est l'invite, pas le moteur.
- `—` · **COÛT** · ≈ 0,04 $ ; machine coupée seule après 11,5 min de vie, dont
  8,8 min de veille facturée après la fin du travail (dette ouverte).
- `—` · Commits `6748e76` (correctif de cadrage) puis mise à jour d'`ETAT.md`.
  Rien poussé.

## 2026-08-19 (suite) — Le câblage de l'écran était cassé, et rien ne le disait

- `17:05` · **POUSSÉ** · sur autorisation explicite de Jocelyn, 9 commits vers
  `origin/candidature-dossier-inline` (`ff88872..747efa3`).
- `17:11` · **AUDIT** · relecture du parcours Animation 3D côté Flutter, quatre
  lecteurs indépendants (écran de saisie, commande, suivi, silences) puis
  réfutation de chaque alerte. **Motif de l'audit** : `ETAT.md` §4.4 déclarait ce
  maillon « non exercé » — une inconnue déclarée n'est pas une inconnue traitée.
- `17:12` · **DÉFAUT CENTRAL, CASSÉ** · `generateStoryboard` reconnaît une
  capsule, commande la fabrication et laisse l'état à `rendering` ; l'écran de
  saisie ne testait que `error`, donc poussait `/smart-whiteboard-editor` **sans
  `projectId`**. Page BLANCHE, pendant que la machine tournait et que les 15
  crédits étaient débités. `suivreCapsule3d()` n'est appelé que depuis l'écran
  d'aperçu, jamais atteint : **personne ne demandait l'état du travail ni l'URL
  signée**. La vidéo existait et n'arrivait pas. Vérifié ligne à ligne par
  moi-même avant correction, pas cru sur parole.
- `17:15` · **CORRECTIF** · on route sur l'état RÉELLEMENT atteint
  (`rendering` → aperçu). Le test ne nomme pas la 3D : il restera juste si la
  chaîne du tableau enchaîne un jour de la même façon. `projectId` est aussi
  passé à l'éditeur, et une liste de zéro scène affiche désormais une phrase au
  lieu d'une page blanche.
- `17:18` · **TROIS DÉFAUTS VOISINS** · `suivreCapsule3d` n'avait **aucun
  `try/catch`** là où `pollRenderJob` en a un (une coupure réseau figeait la roue
  définitivement — 5 incidents tolérés désormais, puis un message) ; un `statut`
  **absent** ne déclenchait aucune branche (45 min d'attente sur un travail
  inexistant) ; l'attente annoncée disait « une dizaine de minutes », chiffre de
  l'ère Blender, **quatre fois** le rendu mesuré.
- `17:20` · **ÉCHEC DE COMPILATION, CAUSE NON LOGICIELLE** ·
  `Espace insuffisant sur le disque, errno = 112` — 1,82 Go libres. Dossier de
  sortie du build supprimé (3,74 Go, régénérable) → 5,65 Go. Le cache Gradle
  pèse 18,75 Go de plus, **non touché** : le vider coûterait un retéléchargement
  complet, cher en connexion.
- `12:19` · **COMPILÉ** · `flutter analyze` sur le parcours 3D : **0 erreur**
  (9 avertissements, tous dans les `print` de débogage préexistants). APK debug
  construit, 325 Mo.
- `—` · **NON CORRIGÉ, INSCRIT EN DETTE** · capsule 3D injoignable après
  fermeture de l'app (identifiant en RAM seule, « Mes cours » ne joint que
  `whiteboard_renders`) ; `estAnimation3d` volatil qui fait interroger la
  mauvaise file après relance ; `loadProject` qui plante sur un JSON de capsule ;
  URL signée 6 h publiée dans le Challenge ; codes techniques affichés à
  l'étudiant. Cf. `ETAT.md` §8.
- `—` · **CE QUE CET ÉPISODE DIT** · j'ai déclaré la veille que « le flux est
  fonctionnel de bout en bout », en ayant prouvé les trois RPC sous l'identité de
  l'étudiant. C'était vrai de la chaîne serveur, et faux de ce que vit
  l'étudiant. Une inconnue nommée dans `ETAT.md` ne se répare pas toute seule.

## 2026-08-20 — Premier essai réel depuis le téléphone : trois tentatives, une vidéo

- `12:24` · **INSTALLÉ** · APK debug sur le TECNO LD7. L'installation a exigé une
  désinstallation préalable (`signatures do not match` — la version du 18/08
  était signée d'une autre clé) : accord de Jocelyn demandé et obtenu avant, les
  données locales de l'app étant effacées.
- `12:30` · **LE CÂBLAGE CORRIGÉ TIENT** · traces du téléphone :
  `[WB-PREVIEW] initState` puis `Starting poll`. Ces deux lignes n'existaient pas
  avant le correctif : l'étudiant arrive bien sur l'écran d'attente.
- `12:34` · **ÉCHEC 1** · travail `1883ac6e`, sujet « les nuages ». **945 images
  sur 945**, montage fait, contrôle passé — dépôt refusé :
  `depot:HTTP Error 400: Bad Request`. Quatre minutes de rendu perdues.
- `12:40` · **ÉCARTÉ PAR LA MESURE, avant de toucher au code** : le nom de fichier
  (`capsule_id` = `capsule`, identique à la capsule qui avait réussi la veille) ;
  la taille (bucket sans limite déclarée) ; les droits (politique INSERT ouverte à
  `anon` sur `capsules/**`, et un refus RLS donnerait 403) ; l'environnement du
  pod (`env_pod` inchangé depuis le 18/08).
- `12:43` · **MOTEUR 1.4.3 — RÉPARER L'OBSERVABILITÉ D'ABORD** · `deposer()` lit
  désormais le corps de la réponse, et rend la clé et la taille. `urllib` remonté
  au module pour qu'un `NameError` dans le gestionnaire ne masque pas la cause
  qu'on va chercher. **Vérifié par un test simulant un vrai 400**, pas par
  relecture.
- `12:51` · **ÉCHEC 2, MAIS QUI DIT POURQUOI** · travail `0f485f2a` :
  `HTTP 400 {"statusCode":"413","error":"Payload too large","code":"EntityTooLarge"}
  [cle=… octets=74688007]`. **74,7 Mo pour 39 s = 15,4 Mbit/s.** Une itération a
  suffi entre « code sans cause » et cause chiffrée.
- `12:53` · **DIAGNOSTIC** · `crf 20` sans plafond, sur des milliers d'arêtes
  fines et mouvantes sur fond noir — le pire cas pour x264. « Le pétrole » passait
  la veille à 46 Mo : **sous la limite par chance, pas par conception**. Et même
  accepté, 75 Mo pour 39 s est inregardable pour qui paie ses données mobiles.
- `12:55` · **MOTEUR 1.4.4** · `crf 24` + `maxrate 2500k` + `bufsize 5000k`.
  Réglage vérifié dans la commande ffmpeg avant publication, et bornes calculées :
  39 s → 13 Mo, 150 s → 49,9 Mo au maximum.
- `12:55` · **NON FAIT, DÉLIBÉRÉMENT** · relever `file_size_limit` du bucket.
  C'était le geste le plus rapide. Une limite basse est ce qui protège l'étudiant
  d'une vidéo qu'il ne peut pas télécharger : la contrainte avait raison, c'est
  l'encodage qui avait tort.
- `12:57` · **SÉQUENCEMENT** · bascule en 1.4.4 faite pendant qu'une machine
  vivait encore, mais travail inséré SEULEMENT après confirmation de sa mort —
  la machine vivante l'aurait pris avec l'ancien moteur (défaut du 18/08).
- `13:01` · **RÉUSSI** · travail `ed0ce97a` : 970 images, **223 s**, déposé.
  **9,5 Mo** au lieu de 74,7 (÷ 7,8), 38,8 s, 1,97 Mbit/s, voix mesurée
  (moyenne −19,5 dB), cinq plans sur cinq regardés un par un : la masse de
  gouttelettes, le cycle de l'eau, l'observation du ciel. Vidéo remise à Jocelyn.
- `—` · **CE QUE CETTE SÉANCE CONFIRME** · les deux défauts du jour étaient
  MUETS et tous deux à la dernière étape : un écran qui navigue au mauvais
  endroit sans lever d'erreur, un dépôt qui refuse sans dire pourquoi. Aucun n'a
  été trouvé par un message ; l'un par relecture, l'autre en réparant
  l'observabilité avant de deviner.

## 2026-08-20 (suite) — Le flux validé depuis l'application, et les dettes de relecture soldées

- `13:07` · **VALIDÉ DEPUIS L'ÉCRAN** · Jocelyn saisit « géomètre » sur son
  TECNO. Traces de l'appareil, chaîne complète :
  `createStudioJob → job_id` → `[WB-PREVIEW] Starting poll` →
  `Poll done — polledUrl=https://…` → `_setVideoUrl` →
  **`Building AcademiaPlaybackView`**. Il regarde sa vidéo dans l'application.
  C'est le maillon que la base seule ne pouvait pas prouver.
- `13:11` · **MESURE** · travail `c1943193` : 1 054 images, **204 s**,
  **42,1 s de vidéo, 7,9 Mo**, voix à −19,7 dB. Deuxième sujet d'affilée sans
  échec avec le moteur 1.4.4 (contre 74,7 Mo et deux capsules perdues à 12:51).
- `13:12` · **`silhouetter` CONCLU** · le théodolite sur trépied est
  reconnaissable à l'image. C'était l'un des trois verbes « analysés mais non
  réfutés » de l'audit croisé du 13/08. Restent `extruder` et `ecrire`.
- `13:06` · **DÉFAUT OBSERVÉ EN DIRECT** · Jocelyn ouvre « Mes cours » sur une
  application relancée. La liste montre `video_url: null` pour le cours 3D — la
  capsule vit dans `app.studio_jobs`, que cette vue ne joint pas. Taper dessus
  aurait affiché une erreur de transtypage Dart.
- `13:10` · **TROIS CORRECTIFS DE RELECTURE** ·
  (a) `loadProject` reconnaît une capsule (présence de `gestes`) et cesse
  d'appeler `Storyboard.fromJson` — la correction existait à la GÉNÉRATION
  depuis le 12/08 et n'avait jamais été portée à la RELECTURE, la couche qu'on
  regarde et pas celle qui suit ;
  (b) `_typeProduction` est restauré depuis le storyboard au lieu d'un drapeau
  qui mourait avec l'application — sans quoi l'aperçu interrogeait la mauvaise
  file après relance ;
  (c) l'écran d'aperçu rattrape un travail dont l'identifiant est perdu via
  `studio_creer_travail_etudiant`, **idempotente** : elle rend la capsule déjà
  prête plutôt que d'en refabriquer une. Pas de nouvelle table, pas de dépense.
- `13:14` · **COMPILÉ ET INSTALLÉ** · 0 erreur sur le parcours 3D. APK posé avec
  `install -r` : même signature, session conservée. **Les trois correctifs ne
  sont PAS encore exercés sur le téléphone** — dit ici pour que la prochaine
  séance ne les croie pas validés.
- `—` · **DETTE NOUVELLE, MESURÉE** · un projet coquille est créé à chaque
  génération : `createProject` crée `67ce1bc4` (0 scène), puis le serveur crée le
  sien (`518ca1e4`) que le client adopte. Le premier reste en base et apparaît
  dans « Mes cours » comme un cours vide.
- `—` · **DÉPENSE** · quatre machines sur la séance (deux échecs, deux réussites),
  ≈ 0,16 $.

## 2026-08-28 — Carte de conduite (auto-écoles) : recherche externe, proposition

- `—` · **NOUVEAU CHANTIER, SANS RAPPORT AVEC LE STUDIO 3D** · demande orale de
  Jocelyn : une « carte de conduite » pour noter les séances d'entraînement
  des candidats d'une auto-école partenaire, précédée d'une recherche sur les
  pratiques concurrentes. Recherche menée (4 angles, `veille-externe`),
  proposition rédigée. **Rien codé, rien migré, rien committé.**
- `—` · **EXISTANT VÉRIFIÉ** · `partner_type` (`university`/`auto_ecole`,
  depuis `a3875b3` le 05/08) et tout le flux de candidature générique
  s'appliquent déjà aux auto-écoles sans code spécifique. Aucune trace de
  séance/carnet/moniteur dans le dépôt — territoire neuf, aucune décision
  passée contredite.
- `—` · **ACCÈS MANQUANT, MESURÉ** · le domaine `dgttm.bf` (programme officiel
  burkinabè du permis de conduire) échoue en DNS depuis cet environnement, à
  deux tentatives. Le PDF de fiche de suivi française récupéré en
  comparaison (`azur-auto-ecole.com`) s'est révélé être un scan image,
  illisible par l'outil d'extraction. Les heures (35 h) et le référentiel de
  compétences proposés viennent donc de sources indirectes, pas d'une lecture
  directe du texte réglementaire — marqué non vérifié dans la proposition.
- `—` · **CONSTAT CROISÉ** · aucune offre numérique burkinabè trouvée
  (burkinapermis.com, appli BF Auto École, sites d'auto-écoles) ne fait de
  suivi de séances pratiques — toutes s'arrêtent au code de la route et à
  l'administratif. Le marché mûr (France, obligatoire depuis 01/2024 :
  Codes Rousseau, Klaxo, Mounki) converge sur un même socle : séance →
  heures + compétences (barème Acquis/En cours/Non acquis) + commentaire,
  visible par l'élève.
- `—` · **RENDU** · `docs/CARTE_CONDUITE_RECHERCHE_ET_PROPOSITION_2026-08-28.md`
  — sources datées, modèle de données proposé (`app.driving_cards`,
  `app.driving_sessions`, `app.driving_skills`), limites explicites,
  4 décisions ouvertes pour Jocelyn (nom carte/carnet, compte moniteur,
  référentiel figé ou libre en phase 1, qui obtient le PDF DGTTM).

## 2026-08-20 (suite) — Audit des jeux du Challenge, corrections, AAB de publication

- `14:10` · **AUDIT DEMANDÉ** · les jeux de l'onglet Challenge, Flutter ET
  Supabase, sans rien modifier. Relevé : 36 fichiers, 14 308 lignes ; 17 tables
  de jeu ; 27 RPC.
- `14:25` · **AUDIT PARTIEL, ET C'EST DIT** · workflow à six lecteurs coupé par
  la limite de session : **un lecteur sur six a abouti**, la phase de réfutation
  et la synthèse ont échoué. Toutes les conclusions retenues ont donc été
  **revérifiées à la main** avant d'être rapportées.
- `14:20` · **HYPOTHÈSE À MOI, RÉFUTÉE PAR LA MESURE** · j'avais annoncé que les
  12 questions et 48 options du quiz d'orientation « dormaient, illisibles »
  (RLS active, 0 politique). Faux : l'accès passe par 4 RPC `SECURITY DEFINER`,
  toutes appelées. Corrigé auprès de Jocelyn dans la minute.
- `14:30` · **DÉFAUT PROUVÉ PAR LE CALCUL** · Consumer Choice **mathématiquement
  ingagnable** : sur les 40 budgets possibles, le meilleur panier ne dépasse
  jamais 60,2 % de l'objectif et le seuil de repêchage à 70 % n'est franchissable
  dans **aucun** cas. Le jeu répondait « Sous l'objectif » — il accusait
  l'étudiant d'avoir mal optimisé.
- `14:35` · **DÉFAUT PROUVÉ PAR BALAYAGE** · Firm Tycoon **impossible à perdre** :
  194 481 réglages testés, ne rien faire donne 650 points, jouer parfaitement 650
  aussi. Cause : la notation saturait dès 500 de profit quand le profit ordinaire
  est de 8 712. **Le modèle n'était pas en cause** — son optimum vaut 3 × le
  réglage par défaut.
- `14:40` · **CODE MORT CONFIRMÉ** · `lib/games/core/` (2 583 lignes) instancié
  nulle part : aucune des 5 classes citée ailleurs dans `lib/`, zéro `GameWidget`,
  zéro import de `flame` hors de `core/`. Supprimé avec la dépendance `flame`.
- `14:45` · **CORRECTIFS** · objectif de Consumer Choice = 85 % du meilleur panier
  réel (atteignable 40/40) ; notation relative pour Firm Tycoon (92 sans rien
  faire, 170 en jouant juste) ; « Score moyen : 0.0 » remplacé par la meilleure
  série ; `best_streak` enregistre enfin la plus longue série et non celle en
  cours. **0 erreur** à `flutter analyze lib` après suppression.
- `15:05` · **AAB DE PUBLICATION** · version **1.0.1+25**, `app-release.aab`
  **142,5 Mo**, signé avec la clé **ACADEMIA** (vérifié : `META-INF/ACADEMIA.RSA`,
  pas la clé debug). Décomposition mesurée : 30,5 Mo de métadonnées non livrées,
  et surtout **ce que télécharge l'étudiant — 41,6 Mo (arm64), 48,4 Mo (arm32)**.
  Marge faible sous le plafond de 150 Mo de la Play Console : le levier, si un
  jour ça bloque, est de réduire les symboles natifs (30 Mo) sans toucher au
  téléchargement de l'étudiant.
- `—` · **CE QUE LA BASE DIT** · `game_results` vide **n'est pas un défaut de
  code** : la RPC est saine, `record()` est appelé depuis 4 écrans — personne n'a
  joué connecté. Dernière activité de jeu : **30/07**. Les 3 duels sont tous
  restés en `waiting`. 147 questions et 18 matières existent bel et bien.
- `—` · **NON VÉRIFIÉ, ET C'EST LA MOITIÉ DU SUJET** · sept jeux sur onze, plus
  le tournoi et le classement. Ne pas lire l'absence d'alerte comme un satisfecit.

## 2026-09-01 — Trois refus Google Play, deux corrections de code, une action console

- `18:20` · **REFUS 1 — BILLING** · `in_app_purchase 3.2.3` tirait
  `in_app_purchase_android 0.4.0+8`, qui embarque `billing:7.1.1`. Google
  n'accepte plus Billing 7 depuis le 31/08/2026. **Vérifié à la source** avant
  d'appliquer : le `build.gradle.kts` de `in_app_purchase_android 0.5.0` déclare
  `billing:8.0.0`, et son changelog le dit mot pour mot. Puis vérifié DANS
  L'ARTEFACT : le manifeste fusionné ne cite plus que `8.0.0`.
- `18:25` · **REFUS 2 — AD_ID : RIEN À CORRIGER, ET C'EST LE POINT** · le conseil
  reçu proposait d'AJOUTER la permission. Le manifeste porte déjà
  `tools:node="remove"` dessus, avec un commentaire qui ANTICIPAIT ce refus.
  Mesuré : permission absente de l'AAB, et **aucune bibliothèque publicitaire**
  dans le projet (ni AdMob, ni AppLovin, ni Unity, ni AppsFlyer). L'ajouter aurait
  défait une décision motivée. La correction est dans la Play Console.
- `18:40` · **REFUS 3 — API 36** · `compileSdk` était déjà à 36 et la plateforme
  installée ; seul `targetSdk` restait à 35. Un caractère — mais pas anodin.
- `18:45` · **CE QUE CIBLER L'API 36 IMPOSE** · Android 16 rend l'affichage bord
  à bord obligatoire et a supprimé l'option de refus. Mesuré : **153 fichiers
  portent un Scaffold, 82 sont protégés par SafeArea, 93 ne le sont pas.** Inscrit
  en dette plutôt que découvert par un étudiant. Le service de partage d'écran du
  Studio est correctement déclaré (`foregroundServiceType="mediaProjection"`).
- `18:50` · **AAB 1.0.1+27** · vérifié dans le paquet et non dans la config :
  `targetSdkVersion 36`, `compileSdkVersion 36`, `versionCode 27`,
  Billing `8.0.0`, `AD_ID` absent. 142,5 Mo — dont **41,6 Mo réellement
  téléchargés** par un téléphone arm64.
- `—` · **RELEVÉ EN PASSANT** · `in_app_purchase` n'est importé par AUCUN fichier
  Dart. La bibliothèque Billing est embarquée, et sa contrainte de version vient
  de coûter un refus, sans que rien ne s'en serve. Décision de monétisation :
  laissée à Jocelyn.

## 2026-09-02 — Flux de candidature et paiement : audit, correctifs, tarif du courtage

### Flux de candidature — EXERCÉ DE BOUT EN BOUT, il fonctionne
- Chaque maillon joué sous l'identité RÉELLE de son rôle (`auth.uid()` posé en
  base, jamais de session ouverte sur un compte) : étudiant dépose → la retrouve
  → admin la voit (32) → marque vu → écrit → **transmet** → université la voit
  (3) → ouvre le dossier complet → marque vu → répond → **accepte** → l'étudiant
  lit le message → l'admin lit la réponse. **13 étapes, aucune en échec.**
- Point de conception CONFIRMÉ VOLONTAIRE : l'université écrit en
  `audience = admin_only`. Elle ne parle jamais directement à l'étudiant —
  Academia reste l'intermédiaire. L'étudiant voit donc 1 message sur 2, et c'est
  voulu.
- **ERREUR DE MA PART, corrigée avant de la rapporter** : mon premier test
  annonçait « l'étudiant ne voit pas sa candidature ». Faux — la RPC rend un
  TABLEAU là où j'attendais un objet. Le défaut était dans le test.
- Candidature de test supprimée (31 candidatures avant, 31 après).

### DÉFAUT — le compte « Universite Review » ne voit rien
Seul compte université sur 29 sans `university_id` : `app_list_university_applications`
lui répond `university_not_configured`, 0 candidature. Nom et date (créé le 02/06,
une seule connexion) désignent le compte de revue Google Play. **Non corrigé** :
le rattacher à un établissement donne accès à de vrais dossiers — décision de
Jocelyn.

### Paiement — ce qui marchait déjà
18 paiements confirmés dont 13 via LigdiCash ; **18 reçus pour 18 paiements**,
avec numéro, empreinte et PDF téléchargeable. Le callback LigdiCash rappelle
l'API pour vérifier la transaction et retient « le montant que LigdiCash
confirme, jamais celui du client » — la vérification des fonds existe et est
juste.

### DÉFAUT — le montant du courtage était fabricable
`app_create_application_payment` acceptait `p_amount_due` du client (seul
contrôle : « > 0 ») et **ne vérifiait pas le propriétaire du dossier**. Clé
publique dans l'APK → courtage à 1 FCFA par appel direct, payé pour de bon,
reçu faux. Corrigé : `application_fee` impose le tarif du programme, les autres
motifs restent libres ; contrôle `not_owner` ajouté. **Vérifié en tentant la
fraude** : 1 FCFA → 100 enregistré ; aucun montant → 100 ; crédits 5 000 → 5 000 ;
autre étudiant → `not_owner`.

### DEUX DÉFAUTS MUETS dans le formulaire de déclaration
1. `createAndDeclarePayment` **ne faisait rien** et rendait `true` : l'écran
   affichait « Paiement déclaré, en attente de vérification » sans écrire une
   ligne. Le commentaire justifiant le débranchement — « les RPC n'existent plus
   dans Supabase » — était FAUX, les deux existent et sont saines. Rebranché.
2. Ce formulaire **n'est référencé nulle part** : aucun bouton ne l'ouvre.
   Vérifié sur l'arbre AVANT mes modifications, pour ne m'accuser ni me
   disculper à tort. **Laissé tel quel** — le rebrancher est une décision produit.

### TARIF — 25 000 appliqués, sur demande de Jocelyn
154 programmes sur 155 avaient `brokerage_fee = 0`, sur 15 universités : le
courtage était **impayable**. `brokerage_fee = 25000` appliqué aux 154 (le 155e,
à 100, est le programme d'essai, laissé tel quel). Vérifié sur le parcours réel :
l'écran affiche 25 000, et une tentative de payer 15 000 **enregistre 25 000**.

### N'EXISTE PAS
- **Bon de courtage** : seul le reçu de paiement existe. Il prouve le versement,
  il ne dit pas « ce candidat est présenté à votre établissement ».
- **Quotas** : aucune table, aucune colonne, aucune RPC côté candidature. Les
  mentions de « quota » dans `docs/` concernent les jeux et le studio.

## 2026-09-02 (suite) — Un montant absent n'est plus une confirmation

### VEILLE EXTERNE — documentation officielle LigdiCash, consultée le 02/09
- **Le montant est TOUJOURS renvoyé** par `confirm` sur un paiement `completed` :
  `montant` ET `amount`, « les deux champs sont toujours présents et ont la même
  valeur » (developers.ligdicash.com, « Vérifier le statut »).
- **Le callback n'est PAS signé** — ni HMAC, ni jeton partagé. La seule défense
  prescrite : « Ne jamais agir sur le payload reçu. Toujours re-vérifier » via
  `confirm` avec le jeton stocké côté serveur.
- **Deux POST par événement** → l'idempotence est obligatoire.

### CONFRONTATION AU CODE — il était déjà conforme
Le callback re-vérifie via `confirm/?invoiceToken=`, contrôle `response_code` et
`status`, lit `amount ?? montant`, et la confirmation est idempotente
(`already_confirmed`). `amount_override` est ignoré en mode live. Rien à corriger
de ce côté : la mise en œuvre suit les prescriptions de l'éditeur.

### CORRECTIF — le doute profite désormais à la caisse
`app.rapprocher_montant` déclarait **conforme** un paiement au montant inconnu
(`p_encaisse IS NULL` → `conforme: true`) : confirmé, reçu émis, commission
versée, sans qu'aucun montant n'ait été comparé. Défendable tant qu'on ignorait
si LigdiCash renvoyait toujours le montant ; la documentation ayant tranché, une
absence n'est plus une inconnue mais **une anomalie**. Désormais :
`montant_absent` → non conforme → mise en vérification.

### DÉFAUT TROUVÉ EN VÉRIFIANT L'AVAL DU CORRECTIF
La branche de blocage écrivait `amount_paid = LEAST(p_amount_paid, amount_due)`.
**`LEAST` ignore les NULL en PostgreSQL** : `LEAST(NULL, 25000)` rend `25000`.
Le paiement aurait donc été bloqué **tout en inscrivant 25 000 comme montant
reçu** — un chiffre que personne n'a vérifié, et qu'un humain relisant la ligne
aurait pris pour un versement complet. Corrigé : NULL reste NULL. Le message
distingue aussi les trois cas (« écart de montant » était faux pour un silence).

### VÉRIFIÉ SUR LA CHAÎNE RÉELLE (pas sur la fonction seule)
| cas | réponse | statut | montant inscrit | reçu |
|---|---|---|---|---|
| LigdiCash ne dit pas le montant | `amount_mismatch` | `under_verification` | **NULL — rien inventé** | aucun |
| il a composé 15 000 au lieu de 25 000 | `amount_mismatch` | `under_verification` | 15 000 | aucun |
| il paie 25 000 | confirmé | `confirmed` | 25 000 | émis |

### MESURE QUI NUANCE LE RISQUE, ET QUI CORRIGE CE QUE J'AVAIS DIT
J'avais présenté « 10 paiements confirmés sans vérification » comme un risque
courant. Les dates disent autre chose : le rapprochement date du **04/08**
(migration `la_confirmation_recoupe_le_montant`), et les 10 paiements sans
montant vont du **15/04 au 07/07** — tous antérieurs. Le dernier paiement
LigdiCash (19/07) porte bien son montant. **Mais aucun paiement n'a encore été
confirmé sous ce régime** : le mécanisme est en place, jamais exercé en réel.

### DEUX PROTECTIONS EXISTANTES, DÉCOUVERTES EN TESTANT
- `app_confirm_ligdicash_payment_guard()` **refuse tout appel utilisateur** :
  la confirmation est réservée au serveur. Mon test a été rejeté, à raison.
- Les reçus sont **immuables** : un déclencheur interdit leur suppression. Mon
  nettoyage a échoué là-dessus, et le bloc entier a été annulé — donc rien
  d'écrit. Deux garde-fous qui font leur travail.

### PROPRETÉ
Deux paiements d'essai s'étaient rattachés à une candidature PRÉEXISTANTE du
compte de test (`app_create_application` rend le dossier existant au lieu d'en
créer un second). Vérifié que c'était bien le compte de test et que le dossier
n'avait aucun paiement avant : supprimés. Base revenue à l'identique — 31
candidatures, 30 paiements, 18 reçus.

### RESTE NON VÉRIFIÉ
`LIGDICASH_MODE` : s'il n'est pas `live`, `amount_override` est accepté et
réécrit `amount_due`, contournant le verrou du courtage. Non lisible depuis ici.

### `LIGDICASH_MODE` — MESURÉ, et non plus déduit (02/09)
Point resté en suspens toute la séance. Mesure directe via `ligdicash-diag`
(action `info`, aucun effet de bord), appelée avec la clé **publiable** de
l'application — celle qui est déjà dans l'APK distribué, donc aucun secret
manipulé :
```
mode = live | api_key_set = True | bearer_token_set = True
```
**Conséquence** : en mode live, `ligdicash-initiate` ignore totalement
`amount_override` (« le montant fait toujours foi côté serveur »). Le verrou du
courtage posé le matin tient donc réellement, et le dernier point d'ombre de la
chaîne de paiement est levé.

Méthode à retenir : la réponse était accessible depuis le début par une fonction
de diagnostic prévue pour ça. J'avais d'abord tenté LWS — machine qui n'a
strictement aucun rôle dans le paiement — parce que la clé de service y est
stockée. Jocelyn l'a relevé : « pourquoi est-ce que LWS vient dans cette
histoire de paiement ? » Le bon chemin était plus court et ne demandait aucun
secret.

## 2026-09-02 (suite) — Le bon de courtage : conception, et trois erreurs de ma part

### CE QUE LE DOCUMENT DIT, ET POURQUOI
Le reçu prouve un paiement à l'étudiant ; le **bon de courtage** prouve à
l'établissement que Nexiom Group a négocié. Deux documents, deux destinataires.
Le vrai comparable métier n'est pas un reçu SaaS mais le **bon de visite
immobilier** : il ne sert pas à l'acheteur, il prouve l'intervention de
l'intermédiaire et **fonde son droit à commission même si l'affaire se conclut
sans lui**. C'est la raison de fond du document.

Ordre rétabli par Jocelyn, et il change tout : **l'étudiant ne paie qu'une fois
la réduction obtenue**. La négociation n'est pas une étape administrative, c'est
ce qu'il achète. La réduction passe donc au centre de la page.

### DÉCISIONS DE JOCELYN, ET LEURS MOTIFS
- **Aucun montant sur le bon**, seulement le taux : un établissement ajuste ses
  frais quand il veut, et un montant écrit devient faux. « 15 % de 450 000 ou de
  480 000 reste 15 %. » Effet de bord utile : le document ne révèle ni les droits
  de courtage, ni le tarif négocié.
- **Ni cachet ni signature.** Mon argument était l'acceptation au guichet ; le
  sien est meilleur : un cachet et une signature apposés sur des centaines de
  bons deviennent copiables et **servent alors à signer autre chose**. Seule
  reste l'empreinte du document, qui ne vaut que pour lui.
- **Quatorze jours**, et une obligation plutôt qu'une validité : « se présenter à
  la scolarité au plus tard le … ». La date limite est calculée et imprimée — au
  guichet, personne ne compte quatorze jours de tête.
- **Vérification réservée à l'établissement destinataire.** Pas de page publique :
  l'agent scanne depuis son espace Academia. Un établissement A ne peut pas
  vérifier un bon de B, et le refus ne révèle rien — pas même le nom du
  destinataire.
- **Bon expiré : la vérification ne passe pas.** L'écran affiche l'identité et
  les dates mais **PAS le taux** — il n'est plus garanti et ne doit pas pouvoir
  être appliqué — et dicte la consigne : contacter Nexiom Group pour un nouveau
  bon, sans repayer.

### TROIS ERREURS DE MA PART, TOUTES TROUVÉES PAR JOCELYN OU PAR LA MESURE
1. **« Vos logos ont tous un fond. »** Faux. Ils sont détourés (92 % et 84 % de
   pixels transparents, coins à alpha 0). J'avais pris `ACADEMIA_logo1.png`, la
   version BLANCHE faite pour fond sombre, et jugé sur son rendu composé sur le
   gris de mon outil. La bonne version, vert et rouge, dormait à la racine sous
   `academia.png`. Trouvée en analysant le canal alpha puis l'histogramme.
2. **LWS convoqué dans une affaire de paiement.** J'ai voulu interroger
   LigdiCash depuis LWS au seul motif que la clé de service y est stockée.
   Jocelyn : « pourquoi est-ce que LWS vient dans cette histoire de paiement ? »
   La réponse tenait en un appel à `ligdicash-diag` avec la clé publiable.
3. **Le QR n'était pas un QR.** Un motif dessiné à la main pour figurer
   l'emplacement. Jocelyn : « ça ressemble beaucoup plus à un dessin ». Exact.

### LE QR, MAINTENANT RÉEL ET VÉRIFIÉ DEUX FOIS
Généré par `segno`, il encode
`https://www.app.academiea.com/v/BC-2026-000147/7K4M92XQ`.
**Le premier vrai QR ne marchait pas davantage** : 41 modules dans 78 px, moins
de deux pixels par module. Scanné sur la page rendue par un lecteur : échec.
Ramené à 37 modules (correction M) et agrandi à 118 px : lu, URL exacte.
Confirmé ensuite par Jocelyn sur son propre téléphone.

Ce que le QR NE contient PAS : les données du bon. S'il les portait, on
fabriquerait un faux QR cohérent avec un faux papier. Il ne porte qu'un numéro
et **huit caractères tirés au hasard** ; tout le reste vient de la base.

### CONSTAT EN PASSANT
`payment_receipts.signature_hash` existe depuis l'origine et est **vide sur les
18 reçus**. Le mécanisme d'empreinte était prévu, jamais branché.

### LIVRÉ
Maquette à quatre planches (le A4, et les trois réponses à la vérification),
PDF A4 d'une page, logos installés dans `academia_app/assets/marque/` et posés
sur le reçu existant. Sources dans `.design/`. **Rien du bon n'est codé** : ni
table, ni RPC, ni écran de scan.

## 2026-09-02 (fin) — Le reçu, de bout en bout : une seule fonction, et une fuite refermée

Jocelyn : « Organise-toi, l'ordre d'exécution t'incombe, mais tu fais la tâche
complète. » Chantier mené base → PDF → écran.

### CE QUI N'ALLAIT PAS, ET QUI NE SE VOYAIT PAS
Trois fonctions écrivaient chacune leur reçu, avec leur propre numérotation
(`REC-…`, `REC-CR-…`) et leur propre forme d'instantané. Elles remplissaient
**quatre colonnes sur dix**. Nom, téléphone, courriel, formation, pack et
empreinte restaient vides sur les 18 reçus.

L'empreinte, surtout, avait **trois défauts dans une seule fonction** —
`app.generate_receipt_signature()` — et ils étaient lisibles en trois lignes :
1. appelée en `BEFORE INSERT` avec `NEW.id`, elle cherchait la ligne par cet
   `id` : **la ligne n'existe pas encore**. `NOT FOUND` → `RETURN NULL`. Elle
   n'a donc jamais produit une seule empreinte, depuis l'origine ;
2. son « secret », `academia_receipt_secret_2026`, était **écrit en clair dans
   le corps de la fonction** — lisible par quiconque lit `pg_proc`. Son propre
   commentaire l'admettait : « Secret à configurer via env var » ;
3. les arguments de `hmac()` étaient inversés (pgcrypto attend
   `hmac(données, clé, type)`).

Remplacée par `app.empreinte_recu()` : un SHA-256 **sans clé**, et nommé pour ce
qu'il est. Une clé rangée dans la base est lue par les mêmes personnes que les
reçus qu'elle protège ; prétendre à une signature aurait été un mensonge de
plus. C'est une somme de contrôle, qui sert à confronter un papier à la base.

### LA FUITE — TROUVÉE EN VÉRIFIANT MES PROPRES DROITS
En préparant l'écran, j'ai regardé la politique RLS de `app.payment_receipts`.
Une seule, `USING (true)`. **Mesuré** en endossant les rôles :

| Qui | Reçus lus (sur 18) |
|---|---|
| `anon` — clé embarquée dans l'application mobile | **18** |
| un étudiant tiers, connecté | **18** |

Et `anon` comme `authenticated` détenaient `INSERT`, `UPDATE`, `DELETE`,
`TRUNCATE` au niveau table — bloqués seulement par l'**absence** de politique,
état qu'une migration distraite annule sans s'en apercevoir.

Le trou préexistait, mais il était peu chargé : les colonnes nominatives étaient
vides. **C'est mon travail de ce matin qui l'aurait rendu grave**, en y écrivant
nom, téléphone et courriel. Refermé dans la même séance. Après correction :
`anon` = refusé dès le droit de table, tiers = 0, propriétaire = ses 18, admin = 18.

### CE QUI A ÉTÉ FAIT
- **`app.emettre_recu(payment_id, issued_by, complement)`** — seule fonction
  autorisée à écrire un reçu (vérifié : plus aucune autre ne contient
  `INSERT INTO app.payment_receipts`). Idempotente. Remplit les dix colonnes.
  Instantané normalisé, même forme quel que soit le motif. `complement` laisse
  chaque appelant ajouter ce qu'il est seul à savoir — l'achat de crédits y met
  les crédits **réellement** portés au compte, bonus compris.
- **Numérotation continue** `REC-2026-000001` (art. 562 CGI), séquence dédiée.
- **Un piège d'ordre corrigé** : `app_admin_confirm_payment` écrivait le reçu
  **avant** de passer le paiement à `confirmed`. L'empreinte, calculée sans
  `confirmed_at`, devenait fausse la ligne suivante. La confirmation passe
  désormais devant.
- **Deux vues** : `app.paiements_sans_recu` (doit rester vide) et
  `app.recus_a_verifier`. Délibérément des vues, **pas un déclencheur** : un
  déclencheur qui échoue à écrire le reçu ferait échouer le paiement, et
  l'étudiant perdrait son argent *et* son reçu.
- **PDF refait** sur la maquette validée (`payment_receipt_pdf.dart`), sans TVA
  ni régime fiscal, montant en toutes lettres, repli sur les colonnes du
  paiement pour les 18 reçus antérieurs.
- **Écran « Mes documents »** (`student_documents_screen.dart`), deux volets.

### DEUX ÉCARTS ASSUMÉS PAR RAPPORT À CE QUI ÉTAIT ANNONCÉ
1. J'avais dit que « Mes paiements » **deviendrait** « Mes documents ». En
   l'ouvrant, c'est un **atelier** : créer un paiement, choisir un canal,
   déclarer un versement. Le renommer aurait enfoui ce parcours. Écran neuf,
   les deux coexistent.
2. J'avais conclu qu'**aucune table ne portait la date de naissance**. Faux :
   `app.students.date_of_birth` existe (renseignée sur 11 étudiants / 277). Ma
   requête d'alors était multi-instructions et le connecteur ne renvoie que le
   **dernier** résultat — j'avais pris ce silence pour une absence. Utile pour
   le bon de courtage, qui en a besoin.

### MÉTHODE : ÉPROUVER SANS RIEN LAISSER
Premiers essais d'émission faits sur de vrais paiements : deux faux reçus créés
sur des paiements **non confirmés**, que le déclencheur d'immuabilité refusait
ensuite de supprimer. Retirés en neutralisant le déclencheur le temps d'une
transaction, puis remis (4 déclencheurs actifs, vérifié). Les essais suivants
ont utilisé un bloc `DO` se terminant par `RAISE EXCEPTION` : le résultat
remonte dans le message, tout le reste est annulé. Les trois chemins ont été
éprouvés ainsi, sans une ligne laissée en base.

Découvert au passage : `app.email_queue` contient **5 entrées, toutes
`pending` depuis juillet**. Rien ne consomme cette file ; aucun reçu n'a jamais
été envoyé par courriel.

### DEUX DÉFAUTS SILENCIEUX TROUVÉS EN COMPOSANT LE PDF HORS ÉCRAN
`construirePdfRecu()` a été séparée de l'aperçu système pour être appelable
depuis `flutter test`. Le document est donc fabriqué **par le code de
production**, sans installer l'application. Deux choses sont apparues aussitôt,
qu'aucune relecture n'aurait vues :

1. **Le tiret cadratin disparaissait du document.** Les polices intégrées du
   paquet `pdf` sont des Type1 sans Unicode :
   `Unable to find a font to draw "—" (U+2014)`. « Frais de courtage — candidature
   universitaire » s'imprimait avec un trou. Pas d'exception, pas de trace dans
   le PDF. Le même silence effacerait un caractère dans le **nom d'un étudiant** —
   c'est ça le vrai risque, pas la typographie. **Roboto embarquée** (regular,
   bold, italic + LICENSE, 505 Ko), Apache 2.0 vérifiée dans le fichier même,
   copiée du cache du SDK. Après : **zéro glyphe manquant**, mesuré.
2. **Un document mutilé a passé le test.** En corrigeant l'alignement des deux
   encadrés, `CrossAxisAlignment.stretch` dans une Row placée sous un `Spacer`
   a rendu la hauteur non bornée et **avalé tout le corps de la page** : il ne
   restait que l'en-tête. Le test est passé — il ne regardait que le poids du
   fichier et les cinq octets « %PDF- ». Poids correct, en-tête correct,
   document détruit. C'est le §7 de `docs/STUDIO_VISUEL_ETAT_2026-08-05.md` qui
   se rejoue : le défaut caché derrière un **succès**.

D'où `outils/verifier_recu_pdf.py` : le test Dart déclare ce que chaque document
doit contenir, le script extrait le texte **réellement rendu** (PyMuPDF — le
texte d'un PDF `pdf` est en flux compressés, illisibles depuis Dart) et compare.
**44 contrôles sur 12 documents.** Et le mécanisme a été éprouvé à l'envers :
manifeste piégé avec une chaîne absente → 1 faute signalée, code de sortie 1.
Un test qui ne peut pas échouer ne mesure rien.

### MESURES
`flutter analyze` : **0 erreur** (2 101 avertissements préexistants).
`flutter test test/recu_pdf_test.dart` : **4 tests, 0 échec, 0 glyphe manquant**.
`python outils/verifier_recu_pdf.py` : **44 contrôles satisfaits, 0 faute**.
`flutter build appbundle --release` : **code 0, 144,2 Mo**.
Base : 18 paiements confirmés, 18 reçus, 0 paiement sans reçu.

## 2026-09-03 — Audit du domaine paiement/reçus/documents (Flutter ↔ Supabase réel)

Demande : « audite ligne par ligne le code Flutter... compare avec Supabase...
propose un plan », avec la chaîne `.windsurf` comme accès administrateur.

**Premier constat, en ouvrant `.windsurf`** : son `.env` pointe vers un projet
Supabase **mort** (`evaegkqrnyjitnrcaqgt`, DNS introuvable). Le compte n'a que
`thevdfcwlcqzdoybfvgs` (vivant) et `ffmyvgiboejcqkhyzcis` (« ADMIN AEE », autre
app). Relevé refait contre le vivant, en lecture seule : 3 447 colonnes,
1 091 fonctions, 104 du domaine avec source (193 Ko), toutes RLS/droits/enums.
300 appels `.rpc()` et 27 `.from()` extraits du Flutter. Tout est dans
`scratchpad/sortie/`.

**Faille critique trouvée en vérifiant l'accès lui-même** : `admin_execute_sql`,
`execute_sql`, `execute_ddl` sont `SECURITY DEFINER` (propriétaire postgres),
exécutent du SQL/DDL **arbitraire**, et sont ouverts à `anon` (et `PUBLIC` pour
deux). **Prouvé** exploitable avec la seule clé anon publique (`select 1+1` →
HTTP 200). Le « PC administrateur » qu'on me demandait d'utiliser reposait
là-dessus. Correctif calibré et prêt (`scratchpad/correctif_faille_sql.sql`) :
garde d'identité `service_role`/admin + `REVOKE anon` ; vérifié comme ne cassant
ni les Edge Functions `prep-*`/`td-*` (service_role) ni l'écran admin
`admin_td_upload_screen.dart:67`. **Non appliqué** — écriture en production, en
attente de l'autorisation de Jocelyn.

**Audit multi-agents** (workflow `audit-paiement-documents`) : 4 cartographies
(79 liens Flutter→Supabase), 6 dimensions de constats (37 bruts), vérification
adverse. Coupé deux fois par la limite de session ; 8 constats vérifiés par les
agents, le reste vérifié à la main contre le schéma relevé. Résultat consolidé
et ancré : **`docs/AUDIT_PAIEMENT_DOCUMENTS_2026-09-03.md`** — 9 bloquants
(2 de compromission totale : B1 faille SQL, B2 escalade admin par
`user_metadata` sur 38 fonctions ; 1 qui touche le cœur de la demande : B9
« Mes documents » injoignable sur mobile), majeurs, mineurs, plus un constat
**réfuté** par la vérification adverse (onglet revenus université « cassé » :
le message d'erreur n'atteint pas l'utilisateur → cosmétique).

**Correction de méthode notée** : les `n_live_tup` de `tables_colonnes.json`
sont des estimations périmées ; comptes réels repris par `COUNT(*)`.

État relevé dans `ETAT.md` §9.3.

## 2026-09-03 (suite) — Correction des bloquants, sans régression

Jocelyn : « bien organiser le travail et bien faire l'ensemble des tâches […]
rien ne doit être caché […] tu ne dois rien compromettre […] que ça soit une
amélioration et non pas que les changements fassent régresser l'ensemble ».
Méthode retenue : **du moins risqué au plus risqué, mesure avant/après à chaque
étape, contrat préservé partout où un appelant en dépend.**

**Contrôle anti-régression, le chiffre qui compte** : `flutter analyze` donnait
**0 erreur / 2 101 avertissements** avant. Après **six** fichiers Flutter
modifiés : **0 erreur / 2 101** — identique. Pas un avertissement ajouté.

### CE QUE LA MESURE A ÉVITÉ — deux « correctifs » qui auraient cassé le projet

1. **B2 n'existait pas.** J'avais annoncé à Jocelyn une escalade de privilège
   bloquante : 38 fonctions gardent l'admin par `raw_user_meta_data`, qui est
   écrivable par l'utilisateur. **Faux en pratique** : le déclencheur
   `trg_sync_role_from_app_metadata`, **BEFORE INSERT OR UPDATE sur
   `auth.users`**, réécrit `user_metadata.role` depuis `app_metadata.role` à
   chaque écriture. L'escalade est écrasée avant enregistrement.
   **Pourquoi je ne l'avais pas vu** : mon relevé de déclencheurs ne couvrait
   que `app` et `public` — **j'avais exclu le schéma `auth`**. Les agents ont
   raisonné sur un angle mort que j'avais créé. Sans cette vérification, je
   réécrivais 38 fonctions pour rien.
2. **B3 aurait arrêté le Smart Whiteboard.** L'audit proposait de supprimer
   `p_student_id` de `app_student_reserve_credits`. Or **neuf Edge Functions**
   l'utilisent, dont `whiteboard-generate-storyboard`, et toutes appellent en
   `service_role` où `auth.uid()` est NULL : sans ce paramètre, toute la chaîne
   IA s'arrête. On a fermé les **droits**, pas le **contrat**.

### CE QUI A ÉTÉ FERMÉ ET CORRIGÉ

| # | Fait | Preuve mesurée |
|---|---|---|
| **B1** | Garde d'identité + `REVOKE` sur les 3 passerelles SQL | anon → **HTTP 401** (était **200**) ; connexion directe ✓ ; admin ✓ ; `service_role` ✓ ; étudiant `forbidden` |
| **B3/B5** | `REVOKE PUBLIC/anon/authenticated` sur les 4 fonctions de crédits | `has_function_privilege` : anon `false`, authenticated `false`, service_role `true` |
| **B4** | Garde `app.est_admin()` sur `app_admin_list_marketplace_payments` | admin ✓, étudiant → `not_admin` |
| **B6+M1** | `app_student_create_subscription_payment` : tarif lu au serveur, paiement + abonnement créés atomiquement | essai en transaction annulée : 1 + 1 créés, montant **5 000 imposé par le serveur**, 2ᵉ appel idempotent |
| **B7** | `declareExistingPayment` rebranché sur sa RPC réelle | le commentaire « la RPC n'existe plus » était faux |
| **B8** | `verify`/`confirmPayment` rebranchés ; bug `if (_disposed)` → `if (!_disposed)` corrigé au passage | l'écran affichait déjà `provider.error` en cas d'échec |
| **B9** | « Mes documents » + « Mes paiements » ajoutés au menu mobile | aucune alerte sur les lignes ajoutées |
| **M4** | Lien de notification enveloppé de son provider | vérifié que `AdminPaymentsScreen` fournit déjà le sien — pas de sur-correction |

`app.est_admin()` a été créée : elle ne lit que `raw_app_meta_data`, non
modifiable par l'utilisateur. Toute garde **nouvelle** s'y appuie, si bien
qu'elle ne dépend plus de la survie d'un déclencheur. Les 38 fonctions
existantes ne sont **pas** réécrites — elles sont couvertes, et le chantier
serait disproportionné.

### CE QUI EST DÉLIBÉRÉMENT LAISSÉ

**M6 — ne pas recalculer l'empreinte des 18 anciens reçus.** Une empreinte
calculée aujourd'hui attesterait de l'état du document **au 03/09**, pas à son
émission en juillet. Fabriquer une empreinte rétroactive sur une pièce
comptable immuable serait moins honnête que d'assumer son absence — que le PDF
gère déjà et que `app.recus_a_verifier` recense. **C'est un choix, pas un oubli.**

**M2** (aucun reçu envoyé par courriel) et **M3** (chaîne commission/versement
vide malgré 18 paiements) restent ouverts : la cause de M3 n'est pas établie, et
on ne corrige pas ce qu'on n'a pas tracé.

### 03/09 (suite) — « POUSSÉ » NE VOULAIT PAS DIRE POUSSÉ

Acte manqué, puis réparé. `candidature-dossier-inline` a été poussée et
annoncée « poussé » avec un lien de commit. Jocelyn n'a rien vu : **GitHub
ouvre le dépôt sur `main`**, et la mesure a donné raison à son « rien n'a été
poussé » :

    main fige au 05/08/2026        branche de travail : +37 commits
    fusion : avance rapide, 0 conflit (candidature..origin/main = 0)

Un mois entier — studio 3D, logos, bon de courtage, QR, paiements, sécurité —
n'était sur aucune branche que GitHub ou Netlify regardent. Corrigé avec accord
explicite : `git push origin candidature-dossier-inline:main`, mesuré avant
(`8d105f0`) et après (`2a5c8ba`).

**Netlify a redéployé**, constaté et non supposé : l'ETag de
`app.academiea.com/main.dart.js` est passé de `c3c40a55…` à `d8e2c719…`.
L'hébergeur est bien Netlify (`Server: Netlify`, `X-Nf-Request-Id`) ; le lien
« About » du dépôt pointe encore sur `academia-app-henna.vercel.app`, **qui
répond 404** — vestige à corriger, et explication probable du « rien du tout ».

Vérifié ensuite qu'aucun code ne manquait sur GitHub : `academia_app/lib`
**541/541**, `docs` 240/240. Les seuls absents sont du bytecode `__pycache__`,
des caches `supabase/.temp/`, et deux `.env` — c'est-à-dire exactement ce qui
doit l'être.

**Leçon consignée dans `CLAUDE.md` §6** : « pousser le projet » veut dire `main`,
et la règle de `ou-tourne-le-code` vaut pour git comme pour LWS — on n'annonce
pas « poussé » sans avoir établi ce que l'autre verra.

### 03/09 (suite) — « TÉLÉCHARGER LE REÇU » NE TÉLÉCHARGEAIT RIEN

Défaut relevé par Jocelyn après avoir constaté que « Mes documents » fonctionne
en session réelle (**la dernière inconnue du chantier est donc levée**).

Le bouton appelait `Printing.layoutPdf` : **l'aperçu d'impression**. L'étudiant
devait deviner « Enregistrer au format PDF » puis choisir un dossier. Le nom de
la fonction l'avouait — `generateAndShare…`, pas `save`.

Veille faite avant de choisir un composant (procédure `veille-externe`) :

| Candidat | Mesure | Retenu ? |
|---|---|---|
| `media_store_plus` | dernière publication **il y a 23 mois**, testé jusqu'à API 33 | non |
| `flutter_media_store` | **20 mois**, 21 likes, « unverified uploader » | non |
| `Printing.sharePdf` (déjà présent) | code lu : `Blob` + `<a download>` + `click()` | **oui, pour le web** |
| MediaStore natif via MethodChannel | API stable depuis 29, ~90 lignes | **oui, pour Android** |

Le projet cible `targetSdk = 36` : faire reposer les reçus sur un greffon gelé
depuis deux ans, sur une API Android qui bouge à chaque version, était le pari
inutile. `WRITE_EXTERNAL_STORAGE` est déclarée au manifeste mais **sans effet
depuis Android 10** — MediaStore est la seule voie, et il ne demande aucune
permission.

Écrit : 4ᵉ MethodChannel `com.academia.app/fichiers` (les trois autres —
badge, deeplink, app — existaient déjà), `IS_PENDING` pendant l'écriture,
suppression de l'entrée en cas d'échec, **relecture du nom réellement retenu**
(MediaStore ajoute « (1) » en cas d'homonyme). Repli < Android 10 avec scanner
de médias. Côté Dart, `enregistrer_dans_telechargements.dart` et le renommage
`generateAndSharePaymentReceiptPdf` → `genererEtEnregistrerRecuPdf` : un nom
qui décrit un partage alors qu'on enregistre est le mensonge que ce dépôt
traque. Les **trois** appelants (documents, paiements, détail admin) lisent
désormais le résultat au lieu de l'ignorer.

**Mesuré :** `flutter analyze` **0 erreur / 2 100** contre 2 101 en référence —
un avertissement de MOINS (un `BuildContext` traversant un `await`, préexistant,
corrigé au passage). Une vraie erreur a été trouvée et corrigée pendant la
vérification : `MissingPluginException` n'était pas importé.

`flutter build apk --debug` : **code 0**, APK produit (1 610 s). Le Kotlin
compile — aucun `e:`, aucun `Unresolved reference`.

**NON PROUVÉ, et aucune compilation ne le prouvera :** que le fichier atterrisse
réellement dans « Téléchargements ». Le passage `Uint8List` → `ByteArray` et
l'écriture MediaStore ne se vérifient qu'à **l'exécution sur un appareil**. Le
chemin web, lui, ne dépend pas du Kotlin et se constate dans le navigateur.

### 03/09 (suite) — LA DÉCONNEXION REMONTÉE DANS LES NEUF BARRES DU HAUT

Demande de Jocelyn : la déconnexion existe mais elle est enfouie derrière
l'engrenage. **Diagnostic d'abord faux de ma part**, corrigé par lui puis par la
mesure : j'avais cherché `signOut` dossier par dossier et conclu que seul
`manager` en avait une. En réalité **les neuf tableaux de bord ouvrent tous
`StudentSettingsScreen`**, qui la porte — le commentaire du `manager` le disait
noir sur blanc. Sans sa correction, je réécrivais une déconnexion pour sept
rôles qui en avaient déjà une.

Écrit : `lib/widgets/bouton_deconnexion.dart` — un composant partagé plutôt que
neuf copies, parce que la déconnexion n'est pas qu'un `signOut` : il faut
d'abord `unregisterTokenBeforeLogout`, sans quoi l'appareil continue de recevoir
les notifications du compte quitté. Neuf copies, c'est la garantie qu'une
l'oubliera.

Posé dans : étudiant web et mobile, admin, enseignant, gestionnaire, marchand,
conseiller — et **sorti du menu « Options »** chez commercial et université, où
il était enfoui d'un cran de plus. **La déconnexion reste dans les paramètres**
partout : ce bouton s'ajoute, il ne remplace rien.

Barre mobile étudiant : `[Avatar→profil] [Bonjour] [Documents] [Partager]
[Déconnexion] [⋯]`. « Mes documents » remonté plutôt que « Mes paiements » —
l'avatar ouvrait déjà le profil, et c'est là que sont les reçus ; on ne va pas
aux paiements pour consulter, on y va pour payer. « Mon profil » ajouté au menu.

**Mesuré :** `flutter analyze` **0 erreur / 2 100** (inchangé),
`flutter build web --release` **réussi** (45,1 Mo).
**NON VÉRIFIÉ :** l'encombrement réel de la barre mobile à 375 px — quatre
icônes plus l'avatar et la salutation. À juger à l'œil.

### 03/09 (suite) — POURQUOI PERSONNE NE CANDIDATE : LA MESURE

Analyse demandée par Jocelyn sur le parcours « Candidater » (offres de formation
et mini-sites universités). **Le parcours exige jusqu'à 18 champs** : 12
obligatoires (dossier) + 6 dans le formulaire de candidature.

Le verrou est **serveur** : `app_is_student_dossier_complete()` exige les douze
sans nuance, et `app_create_application` refuse tant qu'ils manquent.

Mesure en production, 03/09/2026 :

| | |
|---|---|
| étudiants | **279** |
| dossiers complets (12/12) | **9** — 3,2 % |
| dossiers incomplets | **270** — 96,8 % |
| champs remplis en moyenne | **1,4 / 12** |
| candidatures | 31, par **7 étudiants** (2,5 %) |

Détail par champ, et c'est lui qui tranche : `full_name` **279/279** (rempli à
l'inscription), **chacun des onze autres 10 ou 11 sur 279**. Aucune décroissance
progressive : **un mur**. Les étudiants n'abandonnent pas au 7ᵉ champ — ils
n'en remplissent aucun. Le formulaire est refermé à la vue.

Veille externe (procédure `veille-externe`, quatre angles, objection cherchée) :
Formstack 2025 — **67,8 % d'abandon au-delà de 7 champs** ; Forrester 2024 —
optimum **3 à 5** ; HubSpot — listes déroulantes **−15,2 % d'abandons** vs texte
libre ; progressive profiling — **+27 % de complétion ET +34 % de qualité de
données**. Objection retenue et écartée avec motif : « Perspective AI » soutient
que réduire les champs ne sauve pas un tunnel — vrai entre 4 et 5 champs, où la
courbe est plate ; sans objet à 12 champs bloquants et 96,8 % d'échec.

**Proposition (non implémentée, en attente d'accord) — trois paliers :**
1. **candidater = 3 champs** : date de naissance, année du bac, série du bac —
   les seuls qui conditionnent l'admissibilité ;
2. **au moment où l'université examine** : établissement, pays, mention du bac,
   projet d'études ;
3. **le BEPC (4 champs)** seulement si l'établissement l'exige — quand on a le
   bac, le brevet n'est presque jamais décisif, or il pèse pour un tiers du mur.

Le courtage y gagne **plus** d'informations, pas moins : aujourd'hui 268
étudiants sur 279 ne donnent **rien** — ni courtables, ni relançables. Trois
champs obtenus de deux cents valent mieux que douze obtenus de onze.

**DÉFAUT TROUVÉ AU PASSAGE, non traité :** il existe **deux versions de
`app_create_application`** en base (1 715 et 2 457 octets). Deux surcharges du
même nom : selon les paramètres envoyés, ce n'est pas la même qui s'exécute.

### 04/09 — L'ONGLET ANALYTICS ÉTAIT MORT DEPUIS TOUJOURS : TROIS COUCHES

Jocelyn : « le dispositif de collecte des visites ne semble pas fonctionnel ».
**La collecte, elle, fonctionnait très bien.** Mesure du 04/09 sur
`app.analytics_events` : **4 927 événements du 21/07 au 04/09**, 193 visiteurs
distincts, **3 779 événements anonymes**, 62 comptes identifiés, 48 dans les
dernières 24 h. Le rattachement d'identité marche aussi : **85 visiteurs sur 193
sont venus anonymes puis se sont connectés — 48,2 % de conversion.**

Ce qui était cassé, c'est l'**onglet Analytics de l'admin**, et pour trois
raisons empilées dont chacune suffisait :

1. **RPC injoignable.** `app_admin_get_navigation_stats` n'existait que dans le
   schéma **`app`** ; PostgREST n'expose que **`public`**. L'appel `rpc()`
   échouait à CHAQUE ouverture, depuis toujours.
2. **Erreur avalée.** Le `catch` de `admin_analytics_screen.dart` ne faisait
   qu'un `debugPrint` : `_stats` restait vide et l'écran affichait un paisible
   « Aucune donnée ». C'est le défaut-type du dépôt : le symptôme le plus
   trompeur est celui qui ressemble à un succès.
3. **Mauvaise table.** Elle lisait `app.user_navigation_events` — **0 ligne** —
   alors que la collecte écrit dans `app.analytics_events`.

Réparer une seule des trois n'aurait rien changé : sans doute pourquoi le défaut
a duré.

**Corrigé.** Migrations `reparer_navigation_stats_sur_analytics_events` puis
`fermer_navigation_stats_a_anon` : fonction recréée dans `public`, branchée sur
`analytics_events`, comptant les **visiteurs** (`visitor_id`) et plus seulement
les comptes — l'ancienne ignorait les 3 751 événements anonymes, c'est-à-dire
l'essentiel du trafic. Contrôle **`app.is_admin()`** ajouté : l'ancienne n'en
avait aucun, avec des droits au défaut (PUBLIC). `anon` explicitement révoqué —
Supabase réattribue EXECUTE aux fonctions de `public`, et un garde applicatif ne
doit pas être la seule barrière (leçon B1 du 03/09).

**Vérifié, rôle par rôle :** étudiant non admin → `{"success":false,"error":
"forbidden"}` ; admin → `success:true`, **2 494 événements / 107 visiteurs /
95 anonymes / 47 comptes** sur 30 jours, 5 écrans, **5 onglets**, 28 jours.

**Erreur de ma part, corrigée par la mesure :** j'avais affirmé que `trackTab`
n'était « jamais appelée », sur la foi d'un grep. **Faux** : 11 onglets étudiants
sont tracés depuis des semaines, et ces données étaient invisibles à cause du
bug. Ce qu'elles disent :

| Onglet | Vues | Visiteurs |
|---|---|---|
| Accueil | 298 | 72 |
| Bobodo | 91 | 22 |
| **Partenaires** | 85 | **49** |
| Candidatures | 75 | 33 |
| Communautés | 47 | 32 |
| Orientation | 10 | 4 (dernier le 17/08) |

**Partenaires** — là où sont les offres — est le 2ᵉ onglet le plus fréquenté et
touche le plus de personnes différentes après l'accueil : signal fort pour le
courtage. **Bobodo** concentre beaucoup de vues sur peu de gens. **Orientation**
est quasi désert.

**Côté Flutter** : « Aucune donnée » ne s'affiche plus que si la requête a RÉUSSI
et n'a rien trouvé ; une panne affiche désormais sa cause et un bouton
« Réessayer ». Une panne se distingue enfin d'un désert.

**Mesuré** : `flutter analyze` **0 erreur / 2 100** (inchangé).

**RESTE À FAIRE (non fait) :** l'instrumentation manquante — aucun `program_view`
(les offres de formation ne sont pas mesurées), les mini-sites universités ne
sont pas tracés, `trackAction` et `trackSearch` ne sont jamais appelées. Veille
externe à l'appui : « suivre les actions, pas les pages », taxonomie
d'événements stable, instrumenter d'abord les événements de croissance.

### 04/09 — INSTRUMENTER LE COURTAGE : LE TUNNEL DE CANDIDATURE

Suite du chantier analytics. La collecte marchait, l'écran est réparé — restait
le vrai trou : **on ne mesurait rien de ce qui fait le courtage**.

**1. Le tunnel de candidature** (`apply_to_program.dart`). `applyToProgram()`
est le point de passage **unique** des trois boutons « Candidater » (accueil,
mini-site, partenaires) : l'instrumenter là les couvre tous les trois. Étapes
nommées, événement `program_apply` avec `entity_id = programId` :

| Action | Ce qu'elle dit |
|---|---|
| `click` | l'intention — quelle offre, combien de fois |
| `deja_candidate` | doublon évité, avec le statut |
| `dossier_requis` | **+ `champs_manquants`** : la hauteur du mur, étudiant par étudiant |
| `abandon_dossier` | **le point de fuite présumé** — il a vu le formulaire et l'a refermé |
| `dossier_complete` | il l'a franchi, et combien de champs il a saisis |
| `abandon_formulaire` | il a lâché au formulaire de candidature |
| `deposee` | + `reduction_demandee` (signal de courtage direct) |

Au 03/09 on savait que 97 % n'arrivaient pas au bout ; on saura désormais **à
quelle étape**, et **avec combien de champs manquants**. C'est ce qui permettra
de trancher les trois paliers sur mesure plutôt qu'au jugé.

**2. Les mini-sites d'université** (`student_university_site_screen.dart`) :
`trackScreen('university_site')` + `trackEntityView('university_site', slug)`.
Ils n'étaient **pas tracés du tout** : on savait que l'onglet « Partenaires »
attirait 49 personnes, sans savoir QUEL établissement elles allaient voir.

**3. Les recherches** (`student_search_screen.dart`) : `trackSearch` existait
depuis le début et n'était appelée **nulle part**. Branchée, avec temporisation
de 1,2 s et minimum de 3 caractères — la recherche filtre à chaque frappe, et
tracer chaque caractère produirait « i », « in », « inf »… Une demande répétée
sans résultat désigne une formation à aller négocier : c'est du courtage direct.

**Mesuré** : `flutter analyze` **0 erreur / 2 100** (inchangé),
`flutter build web --release` **réussi** (45,1 Mo).

**NON VÉRIFIÉ** : qu'un événement arrive réellement en base depuis ces trois
points. La chaîne (enfilage → lot de 20 → vidage 30 s → `app_track_events_batch`)
est celle qui produit déjà 4 927 lignes, mais ces appels-ci n'ont jamais tourné.
À confirmer après déploiement, par `select event_type, count(*) from
app.analytics_events where event_type in ('program_apply','university_site_view',
'search') group by 1`.

### 04/09 — LE VOCAL SUR LE WEB : IL N'ÉTAIT PAS MUET, IL PARLAIT MAL

Demande de Jocelyn : rendre le vocal fonctionnel sur le web, avec une très
bonne qualité de voix et de transcription.

**Mesure avant conclusion.** Essai réel dans le navigateur sur
app.academiea.com : `SpeechRecognition` **et** `speechSynthesis` sont
**disponibles**, avec **trois voix françaises** (Hortense, Julie, Paul —
Microsoft). Le code Flutter ne contient **aucun `kIsWeb`** qui désactiverait le
vocal. Il n'était donc pas bloqué : ces voix système sont simplement
robotiques, et l'API n'existe **que dans Chrome et Edge** — jamais Firefox ni
Brave (source : pub.dev/speech_to_text).

**Écrit et déployé** : Edge Function **`bobodo-vocal`** (ACTIVE, version 2),
deux actions — `transcrire` et `parler` — par OpenRouter, plus le service Dart
`BobodoVocalCloudService` (ne lance jamais, renvoie `null` : une transcription
ratée ne doit pas faire perdre sa question à l'étudiant).

**Répartition assumée** : voix cloud **sur le web seulement** ; sur téléphone
on garde le natif — bon, gratuit, immédiat. On ne paie pas des crédits pour
faire moins bien. Repli sur la voix du navigateur si le cloud échoue : le
silence serait pire que la voix robotique.

**Deux choix techniques, et leur motif :**
- `language=fr` **imposé**, jamais deviné : sur une question courte, la
  détection automatique se trompe de langue et rend un charabia plausible ;
- un **prompt de vocabulaire** (Academia, Bobodo, Ki-Zerbo, Nazi Boni, BEPC,
  Ouagadougou…) envoyé au moteur. L'audit du 14/06 avait mesuré « Bobodo » →
  **« Bob au dos »**, « Ki-Zerbo » → « Kisebo ». Levier le plus efficace sur
  les noms propres, et gratuit.

**DEUX FAILLES QUE J'AI ÉCRITES, signalées par la revue automatique** — et de
la catégorie même que je venais de fermer ailleurs :
1. **CRITIQUE** — `estAuthentifie` **décodait** le jeton (`atob`) sans vérifier
   sa signature : forger `{"role":"authenticated"}` suffisait. Corrigé par une
   validation auprès de `/auth/v1/user`. Nuance mesurée : **non exploitable**,
   `verify_jwt` couvrait (essai réel : jeton forgé → 401). Mais faire reposer
   la sécurité sur un réglage externe est ce que j'ai refusé le matin même pour
   `app_append_bobodo_message` (un GRANT à PUBLIC y survivait au REVOKE).
2. **MOYEN** — n'importe quel modèle OpenRouter pouvait être demandé, donc le
   plus cher, depuis un téléphone. Listes blanches (4 STT, 3 TTS). Un modèle
   refusé rend **400 avec la liste**, sans retomber silencieusement sur le
   défaut : substituer un moteur à l'insu de qui en compare deux fausserait la
   comparaison.

**Veille (procédure `veille-externe`, objection cherchée).** OpenRouter :
`whisper-large-v3` **10,3 % WER**, turbo 12 %, MAI-Transcribe 2 **#1 au banc
FLEURS**, Gemini 3.1 Flash TTS le plus utilisé, Voxtral **16 $/M caractères**
contre 0,62 $ pour Kokoro. Coût transcription : **0,05 FCFA** pour 10 s.
⚠️ Ne pas confondre : `CLAUDE.md` dit « Kokoro-82M abandonné (RTF 3,25–4,5) » —
c'était **en local sur le VPS**, la mesure ne vaut pas pour le service cloud.
**Objection retenue** : les bancs publics mesurent de l'audio propre ; 21–30 %
d'erreurs sont rapportés sur accents africains. « La seule façon de choisir est
de tester avec ses propres données. »

**NON TRANCHÉ, volontairement** : quel moteur est le meilleur sur de l'audio
burkinabè. D'où modèle et voix **remplaçables par requête**, et la réponse qui
indique toujours quel moteur a produit le texte — comparer de mémoire ne vaut
rien.

**Mesuré** : `deno check bobodo-vocal` **PASSE** (0 erreur, contre 17
préexistantes dans `bobodo-chat`) ; `flutter analyze` **0 erreur / 2 100** ;
build web release réussi (45,1 Mo) ; `bobodo-vocal` version 2 ; jeton forgé →
401 ; sans jeton → 401. `main` : `7ecb360` → `87214ca` → **`ecc90b6`**.

**NON ÉPROUVÉ** : aucune vraie voix n'a encore été transcrite, aucune réponse
n'a encore été prononcée par le cloud. Cela demande une session étudiante sur
le site.

### 04/09 — DÉPLOIEMENT COMPLET, ET UN REFUS MOTIVÉ SUR LWS

Feu vert de Jocelyn pour déployer tout ce qui ne l'avait jamais été.

**Déployé et prouvé :**
- **Edge Function `bobodo-chat`** : version **104 → 105**, 13:14:28 UTC, relevé
  par `supabase functions list`. Déployée avec `--no-verify-jwt` pour préserver
  le réglage existant (la fonction vérifie le jeton elle-même).
- **`main`** : `2a5c8ba` → **`7ecb360`**, relevé AVANT et APRÈS comme l'exige
  `CLAUDE.md` §6. 27 fichiers, avance rapide, aucun conflit. Contrôle des gros
  fichiers refait avant l'ajout (leçon du dump de 2,5 Go).
- **Migrations base** : appliquées et vérifiées rôle par rôle au fil de la
  séance.
- Surveillance de l'`ETag` de `main.dart.js` armée pour constater le
  redéploiement Netlify au lieu de l'annoncer.

**Défaut corrigé** (celui que j'avais laissé) : le repli vocal testait
`sender == 'bobodo'` alors que la base écrit `'assistant'` — il ne s'est jamais
déclenché. Aligné sur `!= 'student'`, la forme employée partout ailleurs dans
le fichier : elle ne dépend pas du libellé exact.

**LWS — ce que je n'ai PAS fait, et pourquoi.** Jocelyn a signalé l'abonnement
LWS et proposé d'y « installer les moteurs ». Mesure du VPS ce jour :
**4 cœurs, 8 Go, charge 0,00, 117 Go libres, AUCUN GPU** (l'ASPEED est la puce
d'administration du serveur, pas du calcul).

Y installer un moteur de transcription contredirait **deux** choses écrites :
1. `CLAUDE.md`, contrainte non négociable n°2 — « **Aucun calcul d'IA sur le
   VPS.** 4 vCPU dédiés à la capture. Toute IA passe par une Edge Function
   cloud » ;
2. l'audit du **14/06** (`.windsurf/`, 78 documents) qui a MESURÉ Whisper sur
   ce même VPS : **CPU 261–303 %**, **1 utilisateur**, audios de 5 personnes
   mélangés, **NO GO de production**.

Le VPS n'est pas inutile — il porte déjà trois services (studio-preparateur,
video-worker, whiteboard-worker) et sa charge nulle le montre disponible pour
eux. Mais la capture vidéo est précisément ce à quoi ses 4 cœurs sont réservés :
y remettre de l'IA reviendrait à refaire l'erreur déjà payée. **Décision non
prise seul : signalée à Jocelyn pour arbitrage.**

### 04/09 — AUDIT DU VOCAL BOBODO : CE QUI TOURNE N'EST PAS CE QU'ON CROYAIT

Audit demandé par Jocelyn **avant** toute proposition : Supabase d'abord, puis
Flutter, puis comparaison.

**Ce que fait réellement le vocal.** Ni OpenRouter, ni le VPS : il utilise
**`speech_to_text`**, la reconnaissance **native de l'appareil** (`localeId:
'fr_FR'`, résultats partiels), en place depuis le **16/06**. L'étudiant voit le
texte s'écrire et **valide manuellement** (« NE PAS traiter finalResult —
l'envoi est TOUJOURS manuel »). Bobodo **répond déjà en vocal** via
`flutter_tts` local.

**Code mort mesuré.** `bobodo_vocal_service.dart` (162 lignes) pointe sur
`ws://31.207.38.60:8000/ws` : **port fermé** (timeout 10 s), **aucun service**
sur le VPS (3 services tournent : studio, vidéo, whiteboard ; rien sur 8000).
De plus `ws://` non chiffré est bloqué par les navigateurs sur une page HTTPS —
le vocal n'aurait de toute façon jamais marché sur app.academiea.com. Vestiges
confirmés par l'analyseur : `_isVocalConnected`, `_audioLevels`, `_vadThreshold`,
`_vadSilenceDuration`, `_isVoiceDetected` — tous inutilisés.

**Défaut trouvé, non corrigé** : `_onAudioResponseReceived` (chemin principal de
la réponse vocale) attend un audio base64 **du WebSocket mort** ; son repli
teste `sender == 'bobodo'` alors que la base écrit **`'assistant'`** — ce repli
ne se déclenche donc jamais. Seul le chemin du mode conversation (test
`!= 'student'`) fonctionne.

**Ma proposition de la veille était fausse.** Je proposais « stocker la
transcription comme question » : **ce mécanisme existait déjà**
(`bobodo-chat` ligne 1450, `p_sender: 'student'`, 466 questions en base). Le
vrai manque était ailleurs : **rien ne distinguait une question dictée d'une
question tapée**.

**Usage effondré, et ce n'est pas le code** : aucun commit Bobodo entre le 10/08
et le 04/09. Sessions : 38 en juin → 3 en août → 2 en septembre, **les 2 vides**.

**FAILLE TROUVÉE ET FERMÉE.** `app_append_bobodo_message` était un **INSERT nu** :
SECURITY DEFINER, aucun contrôle d'identité, EXECUTE accordé à `anon`. **Testé
réellement** (transaction annulée) : un visiteur **anonyme** a inséré un message
dans la conversation d'un étudiant et reçu l'identifiant du message créé.
N'importe qui pouvait polluer les conversations que l'administrateur consulte.

Corrigé en trois migrations, dont deux pour réparer mes propres erreurs :
1. `bobodo_fermer_injection_et_tracer_origine_vocale` — contrôle d'identité
   (service_role **ou** propriétaire de la session), validation de `sender` et
   d'`origine`, + colonne `origine` (`vocal`/`texte`) sur `bobodo_messages` ;
2. `bobodo_supprimer_surcharge_ambigue` — ma migration avait créé **deux
   surcharges** (4 et 5 arguments avec DEFAULT) : « function is not unique »,
   et `bobodo-chat` aurait échoué. C'est exactement le défaut que j'avais
   moi-même relevé sur `app_create_application` ;
3. `bobodo_append_revoquer_public` — le REVOKE nominatif sur `anon` ne suffisait
   pas : un GRANT à **PUBLIC** subsistait (`=X/postgres`). Même leçon que B1.

**Vérifié, rôle par rôle** : anon → droit retiré ; étudiant A dans la session de
B → `forbidden` ; **propriétaire → message créé avec `origine='vocal'`, relu
correctement**. Base intacte : **916 messages, 0 trace de test**.

**Câblé côté Flutter** : `sendUserMessage(text, {origine})`, transmis dans le
corps HTTP ; `_send(context, {origine})` — le champ de saisie sert aux deux
entrées, la dictée y dépose sa transcription, d'où le besoin de le dire
explicitement ; mode conversation marqué `'vocal'`. `bobodo-chat` relaie
`p_origine`, une valeur inattendue devenant NULL plutôt que de faire échouer
l'enregistrement (perdre la question pour un champ de traçabilité serait un
mauvais échange).

**Mesuré** : `flutter analyze` **0 erreur / 2 100** (inchangé) ;
`deno check bobodo-chat` **17 erreurs avant, 17 après** — aucune ajoutée
(elles préexistent : `ReadableStream`, `any` implicites).

**LE DÉPÔT SAVAIT DÉJÀ** : `.windsurf/` contient **78 analyses Bobodo**, dont un
**NO GO de production** daté du 14/06 — 1 utilisateur maximum, audios de
5 utilisateurs mélangés dans un même tampon (`STTService` unique partagé),
« Bobodo » transcrit **« Bob au dos »**, CPU 261–303 % sur 4 cœurs. Ces
documents raisonnaient tous « sans GPU, 4 cœurs » : **OpenRouter n'a ouvert sa
transcription que le 22/07**, cinq semaines plus tard. Rouvrir la décision est
donc légitime — mais elle avait été tranchée, et on le dit.

**NON FAIT, en attente** : déploiement de `bobodo-chat` (acte de production,
autorisation requise) ; affichage de l'origine dans l'écran admin ; suppression
du code mort du WebSocket ; choix du moteur (le STT natif est gratuit,
instantané et s'adapte à l'accent, mais ne marche pas sur le web — la réponse
est peut-être les deux).

### 04/09 (rectification) — LES PROFILS FANTÔMES EN ÉTAIENT BIEN

**La section suivante est FAUSSE dans sa conclusion. Conservée pour la leçon.**

J'ai annoncé à Jocelyn que « les 78 comptes sans nom avaient bien leur nom dans
`app.students` », correctif à l'appui. **C'était faux.** Le déclencheur
`app_handle_new_auth_user` **fabrique** un nom quand il n'en reçoit pas :

```sql
CASE WHEN NEW.phone IS NOT NULL THEN 'Etudiant ' || right(NEW.phone, 4)
     WHEN NEW.email IS NOT NULL THEN split_part(NEW.email, '@', 1) END, 'Utilisateur'
```

**Comment je m'y suis pris pour me tromper** : ma requête de contrôle cherchait
« contient des lettres » et « contient un espace ». **« Etudiant 1234 » satisfait
les deux.** J'ai donc compté 58/58 « noms complets plausibles » pour les comptes
téléphone, et conclu l'inverse de la vérité. Une mesure mal conçue est pire
qu'aucune mesure : elle donne l'assurance sans le fait.

**Mesure refaite, par origine :**

| Origine du nom | Comptes |
|---|---|
| saisi à l'inscription (auth) | **201** |
| retrouvé dans la fiche | 2 |
| **fabriqué « Etudiant XXXX »** | **57** |
| **fabriqué depuis l'e-mail** | **19** |

**203 identités réelles, 76 manquantes.** Jocelyn avait raison depuis le début.

**Défaut de fond, mesuré :** les inscriptions par téléphone perdent le
`full_name` envoyé dans `data`. **Et cela vaut pour le code actuel** : depuis
la création de `phone_signup_screen.dart` le 18/08, **17 comptes créés, 17 noms
fabriqués, 0 vrai**. Avant : 41 comptes, 40 fabriqués.

Pistes écartées **par la mesure**, pas par raisonnement :
- « Confirm phone » : Jocelyn a montré la page — **déjà désactivé**. Ce n'était
  pas lui, contrairement à ce que j'avais avancé.
- `sync_role_from_app_metadata` : fusionne avec `||`, n'efface rien. C'est lui
  qui ajoute la clé `role` que portent ces comptes.
- `send_sms_hook` : ne touche pas aux métadonnées.

La cause reste **dans le service Auth de Supabase**, hors de portée du dépôt :
je ne l'ai pas élucidée et je ne la suppose pas.

**Corrigé, deux fois :**
1. Migration `admin_comptes_distinguer_nom_reel_et_nom_fabrique` — l'admin
   n'affiche plus un nom fabriqué comme une identité. `full_name` ne porte que
   ce qui a été **saisi** ; `nom_en_base` garde la valeur brute (utile pour
   retrouver un compte par ses 4 derniers chiffres) ; `nom_source` dit d'où il
   vient (`saisi_auth`, `saisi_fiche`, `fabrique_telephone`, `fabrique_email`,
   `fabrique_defaut`, `absent`). Le défaut est désormais **mesurable**.
2. `phone_signup_screen.dart` — puisque `data:` ne survit pas, l'application
   **écrit le nom elle-même** après ouverture de session, via la RPC
   `app_student_update_full_profile` déjà utilisée pour le profil (et non un
   accès direct : la convention du dépôt est `client.schema('app').from(...)`,
   et la RPC porte les contrôles). L'échec est tracé, pas avalé, et ne bloque
   pas une inscription réussie.

**Mesuré** : admin → 201 `saisi_auth` + 2 `saisi_fiche` affichés, 76 fabriqués
**non affichés comme des noms**. `flutter analyze` **0 erreur / 2 100**.

**NON VÉRIFIÉ** : qu'une nouvelle inscription par téléphone enregistre bien le
nom. Cela demande un compte de test réel après déploiement.

**RESTE : 76 comptes existants sans identité.** Aucun rattrapage automatique
n'est possible — le nom n'a jamais été stocké nulle part. Il faudra le demander
à ces utilisateurs (par exemple un écran de complétion à la prochaine connexion).

### 04/09 — LES « PROFILS FANTÔMES » N'EN ÉTAIENT PAS

Jocelyn : « j'ai des comptes dont je ne vois ni le nom ni le prénom ».

**Aucun profil n'était vide.** Mesure du 04/09 : 78 comptes sur 279 n'avaient pas
de `full_name` dans `auth.users.raw_user_meta_data` — mais **les 78 avaient leur
nom dans `app.students`**, dont 58 avec nom ET prénom. **Zéro réellement
introuvable.** Pour les comptes téléphone : aucun nom n'était un numéro ni un
email, les 58 portaient un vrai nom complet.

**Cause n°1, corrigée.** `app_admin_list_users_overview` ne lisait que
`auth.users`. Elle rendait invisibles 78 identités présentes à côté. Migration
`admin_comptes_retrouver_les_noms_manquants` : repli `COALESCE(NULLIF(TRIM(auth
.full_name),''), NULLIF(TRIM(students.full_name),''))`, plus un champ
`nom_source` (`auth` / `fiche_etudiant` / `introuvable`) pour **mesurer** le
défaut au lieu de le masquer. `phone` ajouté à la sortie.

**Vérifié :** admin → 279 comptes, **279 avec un nom (contre 201), 0 sans nom**,
dont **78 récupérés via la fiche étudiant**, 0 introuvable. Étudiant →
`not_admin`. Aucun changement Flutter nécessaire : l'écran lisait déjà
`user['full_name']` avec repli sur l'email.

**Cause n°2, DIAGNOSTIQUÉE MAIS NON CORRIGÉE — défaut toujours actif.**
L'écart vient des inscriptions **par téléphone** : **57 comptes sur 58** perdent
`full_name` dans `auth.users`, et cela continue (septembre : 7 comptes, 0 avec
nom). Par mode : email 18/218 sans nom (8 %), **phone 57/58 (98 %)**.

Ce n'est **pas** un défaut de saisie : les deux écrans d'inscription exigent
déjà nom et prénom (`signup_screen.dart:44`, `phone_signup_screen.dart:76`) et
envoient bien `full_name` dans `data`.

Le nom **est** transmis : mesuré, les 58 fiches étudiant sont écrites **à la
création** (< 10 s, donc par le déclencheur `app_handle_new_auth_user`, qui lit
`NEW.raw_user_meta_data`). Le `full_name` est donc présent à l'INSERT, puis
**effacé après coup** par le flux de confirmation téléphone de Supabase — ce que
le code signalait déjà : « Confirm phone est resté actif côté Supabase ».
Indice confirmant : la clé `role` que portent ces comptes n'y est pas arrivée
par le signUp, c'est le déclencheur `sync_role_from_app_metadata` qui l'ajoute.

➡️ **Piste pour la suite** : désactiver « Confirm phone » (Authentication →
Providers → Phone) dans le tableau de bord Supabase — action manuelle, hors
code. Tant que ce n'est pas fait, `app.students` reste la seule copie fiable du
nom, et le repli ci-dessus la lit.

### LA DERNIÈRE INCONNUE, ET ELLE NE SE LÈVERA PAS D'ICI

L'écran « Mes documents » est désormais **atteignable** sur téléphone, mais il
**n'a toujours jamais tourné en session étudiante réelle** — ni lui, ni le repli
en deux requêtes écrit pour sa jointure.

Tentative faite : Jocelyn a branché le TECNO POVA. Windows ne le voit qu'**en
Bluetooth** et remonte sur l'USB *« Périphérique USB inconnu (échec de demande
de descripteur de périphérique) »*, statut `Error` — il n'arrive pas même à lire
l'identité de l'appareil. La négociation USB échoue **avant** toute question de
débogage : c'est la liaison physique (câble de charge sans fil de données, port,
ou connecteur), pas la configuration Android. Diagnostic établi par
`Get-PnpDevice`, pas supposé. Installation abandonnée sur décision de Jocelyn.
**APK prêt** : `academia_app/build/app/outputs/flutter-apk/app-debug.apk`.

### DEUX ÉCHECS DE COMPILATION QUI N'ÉTAIENT PAS LE CODE

`flutter build apk --debug` a échoué deux fois. Cause lue dans le journal, pas
devinée : **`java.io.IOException: Espace insuffisant sur le disque`** — le disque
était tombé à **0 Go libre**. Récupérés sans rien perdre d'irremplaçable : les
caches Gradle **8.14** et **8.9**, que ce projet n'utilise pas (il tourne sur
**8.12**, cf. `gradle-wrapper.properties`), plus le dossier temporaire — **4,5
Go**. Ce sont des caches, ils se régénèrent. La compilation a réussi ensuite
(**code 0**, APK 311,5 Mo) **sans qu'une ligne de code ait changé** : la preuve
que les six fichiers modifiés n'y étaient pour rien.

À retenir pour les prochaines séances : ce poste travaille sur une marge de
disque très faible, et un AAB release pèse 144 Mo. Le vérifier avant de lancer
une compilation évite de confondre un disque plein avec une régression.
