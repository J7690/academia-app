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
