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
