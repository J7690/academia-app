# ÉTAT — le document qui fait foi

> **Ce fichier prime sur tous les autres.** `docs/` en contient 220 ; dix
> s'annoncent comme « état », « plan » ou « chronogramme », et aucun ne dit
> lequel est vrai aujourd'hui. Celui-ci le dit. Les autres sont des **archives
> datées** : on les lit pour comprendre *pourquoi*, jamais pour savoir *où on en est*.
>
> **Relevé le : 19/08/2026, 17 h.** Toute ligne non datée est réputée périmée.
> Toute affirmation ici doit être **mesurée**, jamais supposée (cf. §7).

---

> **PASSATION** — pour reprendre le chantier sans ce fil de discussion :
> `docs/PASSATION_STUDIO_3D_2026-08-14.md` (architecture, huit couches du
> défaut), puis `docs/PLAN_MIGRATION_DEUX_CHAINES_2026-08-18.md` (la décision
> Blender → navigateur) et `docs/MESURE_NAVIGATEUR_VS_BLENDER_2026-08-18.md`
> (les chiffres qui l'ont tranchée).

## 1. Où on en est, en une phrase

**Le flux 3D est validé DEPUIS L'APPLICATION, sur téléphone.** Le 20/08 à 13:11,
Jocelyn a saisi « géomètre » sur son TECNO ; les traces de l'appareil montrent la
chaîne complète : commande → suivi → URL signée → `Building AcademiaPlaybackView`.
**Il a regardé sa vidéo dans l'application.** C'est le maillon que la base seule
ne pouvait pas prouver.

Deux sujets d'affilée, sans échec :

| | « les nuages » | « géomètre » |
|---|---|---|
| durée | 38,8 s | 42,1 s |
| commande → dépôt | 3 min 43 | **3 min 24** |
| poids | 9,5 Mo | **7,9 Mo** |
| voix (moyenne) | −19,5 dB | −19,7 dB |

Il a fallu trois essais pour y arriver, et les deux échecs sont instructifs :
la chaîne rendait parfaitement (945 puis 968 images) et **perdait la capsule au
dépôt**, faute d'un encodage borné (§4.1 bis). Le câblage de l'écran, lui, était
cassé et a été corrigé le même jour (§4.4).

Le théodolite sur trépied de « géomètre » est reconnaissable : **`silhouetter`,
l'un des trois verbes non conclus par l'audit croisé, se voit correctement**.

Détail d'un rendu nominal (travail `ea601c81`, sujet « le pétrole », 19/08) :

| Étape | Durée | Où |
|---|---|---|
| préparation (traduction, **voix**, calage des durées) | ≈ 35 s | LWS |
| amorçage de la machine | ≈ 20 s | RunPod |
| rendu de 977 images + montage + dépôt | **124 s** | pod, moteur navigateur |
| **total commande → vidéo lisible** | **2 min 40** | |

Coût : ≈ 0,04 $ la capsule. Machine coupée seule à 16:54 après 11,5 min de vie
— dont 8,8 min de veille facturée, cf. §8.

Le rendu ne passe **plus par Blender** : moteur navigateur (Three.js + Chromium)
en production depuis le 19/08. Sur la même carte, 154 s contre 1 615 s — **10 ×
plus rapide**, ≈ 0,04 $ au lieu de 0,30 $.

## 2. La chaîne, et qui exécute quoi

```
Étudiant (Flutter) — bouton « Animation 3D »
  └─> RPC `studio_creer_travail_etudiant(project_id)`      ← rend le travail
       │   existant plutôt que d'en refabriquer un à 0,21 $
       └─> app.studio_jobs (statut a_preparer)
            ├─ déclencheur `studio_reveiller_sur_file` → `runpod-control`
            └─> LWS `studio-preparateur.service`   ← /opt/studio_visuel/
                 traduit si besoin, SYNTHÉTISE LA VOIX, cale les durées
                 └─> statut queued
                      └─> Pod RunPod (image academia0/academia-studio:1.3.0,
                           moteur tiré depuis Storage — ici 1.4.2)
                           entree.sh → sonde → worker_pod.py → executer_capsule.py
                           → **Three.js / Chromium** → JPEG → montage → Storage
                           └─> statut preview_ready + chemin_video
  <─ RPC `studio_etat_travail` (5 s) puis URL signée par l'étudiant lui-même
```

`preview_ready` **est** l'état de livraison : l'app le traite comme prêt
(`smart_whiteboard_provider.dart:763`). `approved` reste réservé à une
validation humaine avant mise en ligne publique.

**Trois machines, trois codes différents — c'est la source des confusions :**

| Où | Quel code | Comment on le met à jour | Vérifié le |
|---|---|---|---|
| Supabase | Edge Functions + RPC | `supabase functions deploy` / migration | 18/08 |
| LWS `31.207.38.60` | `/opt/studio_visuel/*.py` | `scp` puis `systemctl restart studio-preparateur` | 19/08 |
| Pod RunPod | **moteur** tiré au démarrage | `publier_moteur.sh` sur LWS + bascule de `app.studio_config.version_moteur` | 19/08 — **1.4.2** |
| Pod RunPod | **image** (Blender, Chromium, Node, ffmpeg) | construction sur LWS, rare | 14/08 — 1.3.0 |

> Corriger le moteur ne demande **plus** de reconstruire l'image : un `.tar.gz`
> déposé dans le bucket `studio-moteur`, une bascule de `studio_config`, et la
> machine suivante l'exécute. La sonde refuse la machine si la version tirée ne
> correspond pas à celle demandée.

## 3. Ce qui est MESURÉ comme fonctionnant

Mesures du 19/08 sauf mention contraire.

- **Le flux complet, sous l'identité de l'étudiant propriétaire** (les trois
  maillons que touche l'app, exercés en base avec son `auth.uid()`) :
  - commande → `{success: true, job_id: …}` (et `deja_prete` si la capsule existe) ;
  - `studio_etat_travail` → `preview_ready | chemin_video | étape « Pret »` ;
  - objet visible sous sa politique RLS → l'URL signée sera délivrée.
- **La vidéo elle-même** — 39,1 s, H.264 + AAC, voix présente et mesurée
  (moyenne −19,4 dB, pic −4,3 dB), sous-titres incrustés.
- **Le cadrage montre le sujet** — 6 plans sur 6 : les trois masses organiques,
  la couche sédimentaire, **le derrick plein cadre**, l'oléoduc et le navire,
  la fiole finale. Images vérifiées une par une, pas déduites d'un code retour.
- **Composition par l'IA** — sujets jamais vus (« Poussée d'Archimède », « le
  pétrole ») : intentions distinctes, verbes variés, 0 correction.
- **Réveil événementiel** — machine créée ≈ 1,5 s après l'insertion du travail.
- **Arrêt automatique** — machine coupée seule après 10 min de silence.

## 4. Ce qui est CASSÉ, et ce qu'on en sait

### 4.1 Le cadrage mesurait le décor — CORRIGÉ le 19/08 (`6748e76`)
`napper` produit un terrain de 190 unités de côté. Compté dans la boîte
englobante, il écrasait tout : **4 plans sur 6 ne montraient que la grille du
sol**, derrick et navire réduits à un point (travail `be3b09ba`).

C'est le défaut de la distance fixe **retourné** : le 14/08 la caméra était trop
près parce que sa distance ignorait le sujet ; ici trop loin parce qu'elle
mesurait le décor.

Le point qui compte : **le défaut existait à l'identique côté Blender depuis le
14/08**, et ne s'était jamais déclenché — aucune capsule Blender n'avait utilisé
`napper`. Le moteur navigateur ne l'a pas créé, il l'a **révélé**. Corollaire :
avoir déclaré la migration réussie sur *une* capsule était vrai pour ce qu'elle
testait, et insuffisant pour conclure.

Corrigé dans les deux moteurs (`composer_scene.py`, `academia3d_web.js`), publié
en 1.4.2, **vérifié en image**.

### 4.1 bis La capsule pesait 75 Mo et était refusée au dépôt — CORRIGÉ le 20/08
Premier essai réel depuis le téléphone, sujet « les nuages » : **deux échecs de
suite à la DERNIÈRE étape**. 945 puis 968 images rendues, montage fait, contrôle
qualité passé — et le dépôt refusé. Quatre minutes de rendu jetées, deux fois.

Le message ne disait rien : `depot:HTTP Error 400: Bad Request`. Un code sans
cause. `str(HTTPError)` ne rend que cela, alors que Storage explique **toujours**
son refus dans le corps de la réponse — que nous jetions.

Moteur 1.4.3, qui lit ce corps. **Une itération a suffi** :
```
HTTP 400 {"statusCode":"413","error":"Payload too large",
          "code":"EntityTooLarge"} [cle=… octets=74688007]
```
**74,7 Mo pour 39 s, soit 15,4 Mbit/s.** `crf 20` sans plafond, sur des milliers
d'arêtes fines et mouvantes sur fond noir — le pire cas pour x264. « Le pétrole »
passait la veille à 46 Mo : **sous la limite par chance, pas par conception**.

Et même accepté par Storage, ce fichier serait inutilisable : 75 Mo pour 39 s de
cours, pour un étudiant qui paie ses données. Le commentaire du code visait juste
(« la qualité tient à débit contenu ») ; le réglage ne le servait pas.

Moteur 1.4.4 : `crf 24` + `maxrate 2500k`. **Mesuré : 9,5 Mo** au lieu de 74,7 —
sept fois plus léger, voix et sous-titres intacts, cinq plans sur cinq lisibles.
Le plafond **borne** la taille par construction (150 s restent sous 50 Mo).

**Non fait, délibérément** : relever la limite du bucket. C'était le geste le plus
rapide. Une limite basse est précisément ce qui protège l'étudiant d'une vidéo
qu'il ne peut pas télécharger — la contrainte avait raison, l'encodage avait tort.

### 4.2 Reste de qualité, non bloquant mais visible
Les formes sont justes mais **génériques** : le navire-citerne du plan 5 est un
bloc, les masses organiques du plan 1 sont trois ovoïdes. L'invite corrigée le
18/08 donne les bons verbes et les bonnes proportions ; elle ne donne pas encore
de silhouette reconnaissable pour les objets techniques. **Non traité.**

### 4.3 Ce que l'audit croisé a laissé en suspens
Audit des 6 verbes coupé par une limite de session : `revolutionner` et
`sculpter` conclus et corrigés ; `napper` conclu le 19/08 par le défaut de
cadrage ; **`silhouetter`, `extruder`, `ecrire` analysés mais non réfutés** —
donc *non conclus*, pas *sains*.

### 4.4 Le câblage de l'écran était CASSÉ — corrigé le 19/08, non encore essayé sur téléphone
J'avais écrit ici que le bouton n'avait pas été exercé. Une relecture du parcours
Flutter, le 19/08 au soir, a montré qu'il ne s'agissait pas d'une inconnue mais
d'un **défaut** :

`generateStoryboard` reconnaît une capsule, commande la fabrication et laisse
l'état à `rendering`. L'écran de saisie, lui, ne testait que `error` — donc il
poussait `/smart-whiteboard-editor`, **sans `projectId`**. L'étudiant tombait sur
une **page blanche** titrée « Éditeur de Storyboard » pendant que sa machine
tournait et que ses 15 crédits étaient débités. `suivreCapsule3d()` n'est appelé
que depuis l'écran d'aperçu : **personne ne demandait jamais l'état du travail,
ni l'URL signée.** La vidéo existait et n'arrivait pas.

Rien ne le signalait : aucune exception, aucun message. C'est la forme exacte que
ce dépôt traque — déduire une destination de l'absence d'erreur.

**Corrigé** (`smart_whiteboard_input_screen.dart`) : on route sur l'état
réellement atteint, `rendering` → écran d'aperçu. Le test ne nomme pas la 3D, il
restera juste si la chaîne du tableau enchaîne un jour de la même façon.

Trois défauts voisins corrigés dans la foulée :
- `suivreCapsule3d` n'avait **aucun `try/catch`** là où `pollRenderJob` en a un :
  une coupure réseau sur l'un des ~30 appels figeait la roue définitivement.
  Désormais 5 incidents tolérés, puis un message qui dit quoi faire.
- un `statut` **absent** (RPC sans ligne → `{success:false, error:'introuvable'}`)
  ne déclenchait aucune branche : 45 min d'attente pour un travail inexistant.
- l'attente annoncée disait « une dizaine de minutes », chiffre de l'ère Blender,
  soit **quatre fois** le rendu mesuré — et pousser l'étudiant à quitter l'écran
  est précisément ce qui lui fait perdre le suivi.

**Reste vrai** : l'appui dans l'application n'a pas encore été rejoué sur le
téléphone. C'est le prochain pas n°1.

### 4.5 Résolus, conservés pour la leçon
- **Le rendu GPU (14/08)** — ce n'était pas le GPU : **deux chaînes tournaient
  en parallèle**, la vieille attrapait le travail et le tuait en 4 s. Ce qui l'a
  masqué : j'avais « vérifié » l'image en comptant les occurrences d'un mot
  présent dans les **deux** versions. Une heure perdue sur une vérification faible.
- **Machines tuées avant d'avoir démarré** — le délai de silence courait depuis
  la création, or le tirage de 4,47 Go prend jusqu'à 10,4 min. Séparé en délai
  d'amorçage (25 min) et délai de silence (10 min).
- **Machines tuées en plein rendu** — l'avancement ne rafraîchissait pas
  `last_seen_at`. **L'avancement vaut signe de vie** ; le délai n'a pas été rallongé.
- **`moteur_archive_incomplete`** — faux échec : uid Windows dans l'archive,
  `tar` sortait en code 2 alors que l'extraction avait réussi.
- **Dépôt de fichiers cassé pour toute l'app depuis le 30/08** — une politique
  RLS de mon fait interrogeait une table illisible par `authenticated`. Trouvée
  par une capture d'écran de Jocelyn, pas par la supervision.

## 5. Le verrou d'architecture est levé

Corriger une ligne du moteur exigeait un poste allumé, Docker démarré, 4,5 Go
reconstruits. Depuis le 14/08 : l'**image** change quelques fois par an, le
**moteur** se livre par un fichier dans Storage. Trois moteurs ont été livrés le
19/08 (1.4.0 → 1.4.2) sans reconstruire une seule image.

## 6. Prochain pas, dans l'ordre

1. ~~Rejouer le flux depuis l'écran~~ — **fait le 20/08**, deux sujets, lecture
   confirmée dans l'application (§1).
2. **Essayer la RELECTURE sur téléphone** : rouvrir un cours 3D depuis
   « Mes cours », et le rouvrir après avoir fermé l'application. Les trois
   correctifs sont dans l'APK installé à 13:14 mais **n'ont pas encore été
   exercés** — c'est exactement la situation qui a produit le défaut du 19/08.
3. **Le projet coquille** (§8) : un cours vide créé à chaque génération.
4. **Silhouettes reconnaissables** (§4.2) — travailler l'invite, pas le moteur.
5. **Conclure `extruder` et `ecrire`** (§4.3) — `silhouetter` est conclu par
   l'image du théodolite.
6. **Reprise automatique** quand un travail attend sans machine : mesuré le
   18/08, « pluie » a attendu **81 min** sans que personne ne le sache.
7. **Alléger l'image** (4,47 Go pour un moteur de 82 Ko) maintenant que
   l'amorçage est le poste de temps dominant.

## 7. Les règles qui ne se négocient pas

1. **Ne jamais déduire un état de ce qu'on ne voit pas.** Un fichier valide ne
   dit rien de ce qu'il contient ; un code retour 0 ne dit rien de l'image.
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
| Deux jetons Docker Hub collés en conversation | 12/08 | **ouverte — à révoquer par Jocelyn** |
| 3 verbes sur 6 non conclus par l'audit croisé | 13/08 | **ouverte** — cf. §4.3 |
| Machine facturée ≈ 9 min après la fin du travail | 19/08 | **ouverte** — le délai de silence est à 10 min ; le fixer plus bas économiserait ≈ 0,02 $/capsule mais rapprocherait du seuil qui a déjà tué deux machines |
| Aucune reprise quand un travail attend sans machine | 18/08 | **ouverte** — mesuré : 81 min d'attente muette |
| Gabarit `universite-arbilo` inactif → clonage des mini-sites sans effet | 18/08 | **ouverte** — 4 universités créées depuis juillet à rattraper |
| Inscription téléphone : réglage Supabase « Confirm phone » non vérifié | 18/08 | **ouverte** — cf. journal 18/08 |
| Silhouettes génériques pour les objets techniques | 19/08 | **ouverte** — cf. §4.2 |
| Le compte « Universite Review » ne voit aucune candidature | 02/09 | **ouverte** — seul compte université sur 29 sans `university_id` ; réponse `university_not_configured`. Nom et date désignent le compte de revue Google Play : un examinateur verrait un espace vide. Le rattacher donne accès à de vrais dossiers — décision de Jocelyn |
| Le formulaire « Déclarer un paiement » n'est ouvert par aucun bouton | 02/09 | **ouverte** — il ne faisait rien et mentait à l'étudiant (corrigé le 02/09), mais rien ne l'ouvre. Le rebrancher rendrait possible la déclaration d'un paiement hors ligne (espèces, Orange Money) — décision produit |
| Pas de bon de courtage à présenter à l'université | 02/09 | **ouverte** — le reçu de paiement existe (18/18, PDF signé) et prouve le versement ; aucun document ne présente le candidat à l'établissement |
| Le système de quotas n'existe pas | 02/09 | **ouverte** — aucune table, colonne ni RPC côté candidature. À concevoir si la taxation par quotas est maintenue |
| **93 écrans sur 153 sans `SafeArea`, alors que l'app cible l'API 36** | 01/09 | **ouverte** — Android 16 rend l'affichage bord à bord obligatoire et a supprimé l'option de refus. Ces écrans ne plantent pas, mais leur contenu peut passer sous les barres système. Majorité d'écrans d'administration ; le parcours étudiant est mieux couvert. **Non vérifié faute d'appareil Android 16** |
| Déclaration `AD_ID` fausse en Play Console | 01/09 | **ouverte, côté Jocelyn** — la console déclare un identifiant publicitaire que l'app n'utilise pas (aucune bibliothèque pub dans le projet, permission retirée exprès du manifeste). Avertissement non bloquant, mais il reviendra à chaque version tant que la déclaration dit « oui » |
| `in_app_purchase` embarqué mais importé par aucun code Dart | 01/09 | **ouverte, décision produit** — la bibliothèque Billing pèse dans l'APK et impose sa contrainte de version (elle a causé un refus le 01/09) sans que rien ne s'en serve. À garder si la vente via Google Play est prévue, à retirer sinon |
| Capsule 3D injoignable après fermeture de l'app | 19/08 | **corrigée, TOUJOURS PAS EXERCÉE** — l'écran d'aperçu rattrape le travail via `studio_creer_travail_etudiant`, idempotente. L'essai du 20/08 14:04 n'a **pas** sollicité ce chemin : `URL already known, skipping poll` — l'URL vivait encore en mémoire. Il faut FERMER l'application (la sortir des récentes) avant de rouvrir le cours |
| ~~`estAnimation3d` n'est qu'un drapeau client~~ | 19/08 | **corrigée et VÉRIFIÉE sur téléphone le 20/08 14:04** — `loadProject` restaure `_typeProduction` depuis le storyboard ; la redirection vers l'aperçu en dépend et a eu lieu |
| ~~Rouvrir un cours 3D depuis « Mes cours » plante~~ | 19/08 | **corrigée et VÉRIFIÉE sur téléphone le 20/08 14:04** — « la date » ouverte depuis la liste : `loadProject` a lu la capsule sans planter, l'éditeur a redirigé, la vidéo s'est affichée |
| Un projet coquille est créé à chaque génération | 20/08 | **ouverte** — mesuré : `createProject` crée `67ce1bc4` (0 scène), puis le serveur crée le sien (`518ca1e4`) que le client adopte. Le premier reste en base, visible dans « Mes cours » comme un cours vide |
| L'URL signée 6 h est publiée telle quelle dans le Challenge | 19/08 | **ouverte** — le bucket est privé et la politique n'autorise que le propriétaire : la vidéo publiée meurt pour les spectateurs au bout de 6 h |
| Codes techniques affichés à l'étudiant (`invalid_capsule`, `storyboard_sans_scenes`…) | 19/08 | **ouverte** — `_messageForError` traduit six codes ; ceux de la chaîne 3D n'y sont pas |

## 9. Autre chantier ouvert, sans rapport avec le Studio 3D

Tout ce qui précède (§1-8) concerne le Smart Whiteboard / Studio 3D — **ça
reste l'état mesuré de ce chantier-là**, ne pas le lire comme périmé par la
ligne suivante.

### 9.1 Les JEUX de l'onglet Challenge — audité et partiellement corrigé le 20/08

**Onze entrées** dans le hub (`/games` → `GamesDomainHubScreen`) : Duel de
Concours, Mémoire éclair, Le comptoir, La consultation, Type de Cerveau, Défi
10 Secondes, Quel Étudiant Es-Tu ?, quatre jeux d'Économie, Tournois — plus
Mathématiques et Sciences annoncés « Bientôt disponible ». Tous les écrans ont
un appelant, sauf `GameRecordController` (`auto_record_game_wrapper.dart`).

**Corrigé (commit `d719db7`, version 1.0.1+25)** :
- **Consumer Choice était mathématiquement ingagnable.** L'objectif additionnait,
  pour chaque produit, ce qu'on pourrait acheter avec la totalité du budget.
  Mesuré sur les 40 budgets : le meilleur panier ne dépassait jamais **60,2 %**
  de l'objectif, et le seuil de repêchage à 70 % n'était franchissable dans
  **aucun** cas. Objectif désormais à 85 % du meilleur panier réel : atteignable
  40 fois sur 40.
- **Firm Tycoon était impossible à perdre.** Balayage des 194 481 réglages : ne
  rien faire donnait 650 points, jouer parfaitement 650 aussi. Ce n'était pas le
  modèle (son optimum vaut 3 × le réglage par défaut) mais **la notation**, qui
  saturait dès 500 de profit quand le profit ordinaire est de 8 712. Note
  relative désormais : 92 sans rien faire, 170 en jouant juste, faillite possible.
- « Score moyen : 0.0 » affiché en permanence (`endGame()` jamais appelé) →
  remplacé par la meilleure série. `best_streak` enregistrait la série **en
  cours**, remise à zéro par la dernière faute → enregistre la plus longue.
- **`lib/games/core/` supprimé** — 2 583 lignes (moteur Flame + une seconde copie
  des 4 jeux) qu'aucun écran n'instanciait, plus la dépendance `flame`. Le
  dossier nommé « core » était l'archive : c'était le piège de lecture du module.

**Ce que la base dit** : `game_results` est vide **non par défaut de code** — la
RPC est saine et `record()` est appelé depuis 4 écrans — mais parce que personne
n'a joué connecté ; dernière activité de jeu le **30/07**. Les 3 duels créés sont
tous restés en statut `waiting`. Le contenu existe : 147 questions, 18 matières.
Les tables `orientation_quiz_*` sans politique RLS ne sont **pas** un défaut :
l'accès passe par 4 RPC `SECURITY DEFINER`, toutes appelées. Sur 27 RPC de jeu,
24 sont utilisées.

**NON VÉRIFIÉ, et c'est la moitié du sujet** : sept jeux sur onze (Mémoire
éclair, Le comptoir, La consultation, Type de Cerveau, Défi 10 Secondes, Quel
Étudiant Es-Tu ?) ainsi que le parcours tournoi et le classement. L'audit
multi-agents a été coupé par une limite de session — **un lecteur sur six a
abouti**, et ses conclusions ont été revérifiées à la main faute de phase de
réfutation. Ne pas lire l'absence d'alerte sur ces sept jeux comme un satisfecit.

**28/08/2026** — recherche + proposition pour une « carte de conduite »
(suivi des séances d'entraînement des candidats auto-école, sur le pan
`partner_type = 'auto_ecole'` du système de candidature). Rien codé, rien
migré. Détail complet, sources datées, décisions ouvertes :
`docs/CARTE_CONDUITE_RECHERCHE_ET_PROPOSITION_2026-08-28.md`.

### 9.2 Les DOCUMENTS de paiement — reçu livré le 02/09, bon de courtage conçu seulement

**Le reçu est fait, de la base à l'écran.** Une seule fonction l'émet désormais :
`app.emettre_recu(payment_id, issued_by, complement)`, appelée par les trois
chemins de confirmation (admin, achat de crédits, LigdiCash). Vérifié : plus
aucune autre fonction ne contient `INSERT INTO app.payment_receipts`.

| Avant le 02/09 | Depuis |
|---|---|
| 3 fonctions écrivaient chacune leur reçu | 1 seule, idempotente |
| 4 colonnes remplies sur 10 | 10 sur 10 |
| 2 formats de numéro (`REC-…`, `REC-CR-…`) | série continue `REC-2026-000001` |
| `signature_hash` **NULL sur les 18 reçus** | empreinte SHA-256 calculée et vérifiable |
| aucune vue de contrôle | `app.paiements_sans_recu`, `app.recus_a_verifier` |

**Deux défauts de sécurité corrigés dans la foulée, tous deux mesurés :**

1. **N'importe qui lisait tous les reçus.** La politique RLS était `USING (true)`.
   Mesuré en endossant les rôles : `anon` — dont la clé est embarquée dans
   l'application — lisait les **18 reçus**, un étudiant tiers aussi. `anon` et
   `authenticated` détenaient de surcroît `INSERT/UPDATE/DELETE/TRUNCATE` au
   niveau table, bloqués seulement par l'*absence* de politique. Le trou
   préexistait mais était peu chargé : les colonnes nominatives étaient vides.
   **C'est le travail du 02/09 qui l'aurait rendu grave**, en y écrivant nom,
   téléphone et courriel. Après correction : `anon` refusé dès le droit de
   table, tiers = 0, propriétaire = ses reçus, admin = tout.
2. **`app.generate_receipt_signature()` portait un secret en clair** dans son
   corps (`academia_receipt_secret_2026`), **et n'a jamais rien produit** :
   appelée en `BEFORE INSERT` avec `NEW.id`, elle cherchait une ligne qui
   n'existe pas encore. Supprimée. Remplacée par `app.empreinte_recu()`, un
   SHA-256 **sans clé** — nommé pour ce qu'il est : une somme de contrôle qui
   permet de confronter un papier à la base, pas une signature.

**Côté application** : `payment_receipt_pdf.dart` refait sur la maquette validée
(sans TVA ni régime fiscal, retirés sur décision de Jocelyn ; montant en toutes
lettres ; repli sur les colonnes du paiement pour les 18 reçus antérieurs), et
un écran **« Mes documents »** neuf (`student_documents_screen.dart`), deux
volets. Ce n'est **pas** le renommage de « Mes paiements » annoncé : cet
écran-là est un atelier (créer, choisir un canal, déclarer), le renommer aurait
enfoui son parcours. Les deux coexistent.

**Le PDF se fabrique et se contrôle sans installer l'application** :
```bash
cd academia_app
flutter test test/recu_pdf_test.dart     # produit les PDF, par le code de prod
python ../outils/verifier_recu_pdf.py    # vérifie leur CONTENU réel
```
Les documents sortent dans `academia_app/build/apercus_recu/`. Deux défauts
silencieux ont été trouvés par là, et par là seulement :
- **le tiret cadratin disparaissait** du document (Type1 sans Unicode) — le même
  silence effacerait un caractère dans le **nom d'un étudiant**. Roboto est
  désormais embarquée (`assets/polices/`, Apache 2.0, 505 Ko) ;
- **un document mutilé a passé le test** (il ne restait que l'en-tête) parce que
  le test ne regardait que le poids et « %PDF- ». D'où le contrôle Python, qui
  lit le texte rendu. Éprouvé à l'envers : manifeste piégé → faute signalée.

Mesures : `flutter analyze` **0 erreur** · `flutter test` **4 tests, 0 échec,
0 glyphe manquant** · contrôle du contenu **44/44** · `flutter build appbundle
--release` **code 0, 144,2 Mo**. 18 paiements confirmés, 18 reçus, 0 sans reçu.

**NON VÉRIFIÉ, et c'est le point à reprendre en premier** : l'écran « Mes
documents » n'a **jamais tourné**. La liste se charge par une jointure
imbriquée PostgREST qui ne peut s'exercer qu'avec une session étudiante — je
n'en ouvre pas. Un repli en deux requêtes a été écrit pour ce cas, lui non plus
jamais exécuté. **À essayer sur téléphone avant toute publication.**

**PAS ENCORE CODÉ — le bon de courtage.** Maquette validée, QR réel et scanné
(cf. journal du 02/09), mais **ni table, ni RPC, ni écran de scan, ni champs de
négociation**. Le volet « Bons de courtage » de l'écran est vide et l'écrit.

**Bon à savoir** : `app.students.date_of_birth` **existe** (renseignée sur
11 étudiants sur 277) — j'avais conclu l'inverse le 02/09 au matin, à tort. Le
bon de courtage en a besoin.

**Découvert en passant** : `app.email_queue` contient 5 entrées, **toutes
`pending` depuis juillet**. Rien ne consomme cette file — aucun reçu n'a jamais
été envoyé par courriel. Le déclencheur qui l'alimente, lui, fonctionne.

### 9.3 AUDIT du domaine paiement/reçus/documents — 03/09/2026

Audit ligne par ligne (Flutter ↔ Supabase réel), conduit par workflow
multi-agents avec vérification adverse. **Rapport complet et ancré :
`docs/AUDIT_PAIEMENT_DOCUMENTS_2026-09-03.md`.**

> **CORRIGÉ LE MÊME JOUR — 8 bloquants sur 9 fermés, le 9ᵉ rétrogradé.**
> Contrôle anti-régression : `flutter analyze` donnait **0 erreur / 2 101
> avertissements** avant ; après six fichiers modifiés, **0 erreur / 2 101** —
> identique, aucun avertissement ajouté. Détail et preuves au §5 du rapport.
>
> Le tableau ci-dessous conserve le constat d'origine ; la colonne « état » dit
> où on en est.

| # | État | Bloquant | Vérification |
|---|---|---|---|
| B1 | ✅ **fermé** | `admin_execute_sql`/`execute_sql`/`execute_ddl` : SQL arbitraire ouvert à `anon` (clé publique de l'APK) | anon → **HTTP 401** (était 200). Connexion directe ✓, admin ✓, `service_role` ✓, étudiant `forbidden` |
| B2 | ↓ **rétrogradé** | Rôle admin lu dans `raw_user_meta_data`. **NON EXPLOITABLE** : `trg_sync_role_from_app_metadata` (BEFORE, sur `auth.users`) écrase la valeur. Mon relevé excluait le schéma `auth` — c'est mon angle mort, pas une faille | `app.est_admin()` créée pour les gardes nouvelles |
| B3 | ✅ **fermé** | `app_student_reserve_credits(3 args)` : IDOR, appelable `anon`. **Contrat conservé** — 9 Edge Functions en dépendent, dont le Smart Whiteboard | anon/authenticated `false`, service_role `true` |
| B4 | ✅ **fermé** | `app_admin_list_marketplace_payments` : aucun contrôle d'identité | admin ✓, étudiant → `not_admin` |
| B5 | ✅ **fermé** | `confirm_credits`/`refund_credits` : aucune vérif d'appartenance | idem B3 |
| B6 | ✅ **corrigé** | Abonnement : INSERT refusé par RLS → Premium ne s'activait **jamais** (0 en base) | essai annulé : 1 abonnement + 1 paiement créés, 2ᵉ appel idempotent |
| B7 | ✅ **corrigé** | Déclaration manuelle : **no-op** affichant un faux succès (le commentaire « la RPC n'existe plus » était faux) | rebranché sur `app_student_declare_payment` |
| B8 | ✅ **corrigé** | Écran admin : `verify`/`confirm` étaient des **stubs vides** retournant `true` | rebranchés sur leurs RPC réelles |
| B9 | ✅ **corrigé** | **« Mes documents » injoignable sur mobile** | ajouté au menu de `student_home_mobile.dart:269` |

> ### ✅ 03/09 — « MES DOCUMENTS » A TOURNÉ EN SESSION RÉELLE
>
> Jocelyn l'a constaté sur **app.academiea.com** : l'écran s'ouvre et les reçus
> s'affichent. **La dernière inconnue du chantier est levée.**
>
> **Poussé sur `main`** (`8d105f0` → `2a5c8ba`, mesuré avant/après) après une
> erreur à retenir : la branche de travail avait été poussée et annoncée
> « poussé », alors que GitHub et Netlify ne regardent que `main` — figée
> depuis le 05/08, avec **37 commits** de retard. Procédure désormais écrite
> dans `CLAUDE.md` §6. **Netlify a redéployé**, constaté par le changement
> d'ETag de `main.dart.js` (`c3c40a55…` → `d8e2c719…`).
>
> ⚠️ Le lien « About » du dépôt GitHub pointe sur
> `academia-app-henna.vercel.app`, **qui répond 404**. Vestige d'un hébergeur
> abandonné, à corriger dans les paramètres du dépôt.
>
> ### 🚀 04/09 — TOUT EST EN LIGNE (constaté, pas supposé)
>
> | Maillon | Preuve |
> |---|---|
> | `main` sur GitHub | `2a5c8ba` → **`7ecb360`** (relevé avant *et* après) |
> | Edge Function `bobodo-chat` | version **104 → 105**, 13:14:28 UTC |
> | Migrations base | appliquées, vérifiées rôle par rôle |
> | **Netlify** | **ETag `d8e2c71…` → `cfedc589…`** — reconstruit |
> | app.academiea.com | **HTTP 200**, sert le nouveau `main.dart.js` |
>
> **Reste NON ÉPROUVÉ en usage réel** (le code est en ligne, personne ne s'en
> est encore servi) : téléchargement d'un reçu, barre mobile à 375 px, arrivée
> des événements `program_apply` / `university_site_view` / `search` en base,
> inscription par téléphone conservant le nom, colonne `origine` se remplissant.
>
> Requête de contrôle, à passer dans quelques jours :
> `select event_type, count(*) from app.analytics_events where event_type in
> ('program_apply','university_site_view','search') group by 1;`
> et `select origine, count(*) from app.bobodo_messages group by 1;`
>
> ⚠️ **LWS — décision NON prise seul.** Jocelyn a ouvert l'accès au VPS pour
> « installer les moteurs ». Mesuré ce jour : **4 cœurs, 8 Go, charge 0,00,
> AUCUN GPU**. Y mettre un moteur de transcription contredirait la contrainte
> non négociable n°2 de `CLAUDE.md` (« aucun calcul d'IA sur le VPS ») **et**
> l'audit mesuré du 14/06 (Whisper y saturait à 261–303 % de CPU pour
> 1 utilisateur, NO GO). Signalé pour arbitrage, pas exécuté.
>
> ### 🔒 04/09 — VOCAL BOBODO : FAILLE FERMÉE, ORIGINE TRACÉE
>
> **Faille (fermée)** : `app_append_bobodo_message` était un INSERT nu ouvert à
> `anon`. **Testé** : un visiteur anonyme insérait un message dans la
> conversation de n'importe quel étudiant. Contrôle ajouté (service_role **ou**
> propriétaire), PUBLIC et `anon` révoqués. Vérifié : anon refusé, étudiant A
> chez B → `forbidden`, propriétaire → OK. Base intacte (916 messages).
>
> **Ce que fait vraiment le vocal** : `speech_to_text` **natif de l'appareil**
> (fr_FR), pas OpenRouter, pas le VPS. L'étudiant valide le texte avant envoi.
> Bobodo **répond déjà en vocal** via `flutter_tts`.
> **Code mort** : `bobodo_vocal_service.dart` → `ws://VPS:8000` — port fermé,
> aucun service, et `ws://` bloqué sur HTTPS de toute façon.
>
> **Ajouté** : colonne `origine` (`vocal`/`texte`) sur `bobodo_messages`, câblée
> de l'écran jusqu'à la RPC. L'administrateur pourra enfin distinguer une
> question dictée (donc faillible) d'une question tapée.
>
> ⚠️ **NON FAIT** : déployer `bobodo-chat` (autorisation requise), afficher
> l'origine côté admin, retirer le code mort. **Défaut non corrigé** : le repli
> TTS teste `sender == 'bobodo'` alors que la base écrit `'assistant'` — il ne
> se déclenche jamais.
>
> 📚 `.windsurf/` contient **78 analyses Bobodo** dont un **NO GO** du 14/06
> (1 utilisateur max, audios mélangés, « Bobodo » → « Bob au dos »). Toutes
> antérieures à l'ouverture de la transcription OpenRouter (22/07).
>
> ### 🚨 04/09 — 76 COMPTES SANS IDENTITÉ RÉELLE
>
> Jocelyn avait raison : ce sont bien des profils fantômes. **Ma première
> conclusion (« aucun n'est vide ») était fausse** — le déclencheur
> `app_handle_new_auth_user` **fabrique** un nom quand il n'en reçoit pas
> (`'Etudiant ' || 4 derniers chiffres`, ou le préfixe de l'e-mail), et ma
> requête de contrôle (« des lettres + un espace ») validait « Etudiant 1234 ».
>
> | Origine du nom | Comptes |
> |---|---|
> | saisi à l'inscription | **201** |
> | retrouvé dans la fiche | 2 |
> | **fabriqué (téléphone)** | **57** |
> | **fabriqué (e-mail)** | **19** |
>
> **203 identités réelles sur 279.**
>
> **Défaut ACTIF** : les inscriptions par téléphone perdent le `full_name` —
> depuis la mise en place de l'écran le 18/08, **17 comptes, 17 noms fabriqués,
> 0 vrai**. Écartés par la mesure : « Confirm phone » (déjà désactivé, vérifié
> par Jocelyn), `sync_role_from_app_metadata` (fusionne, n'efface pas),
> `send_sms_hook` (ne touche pas aux métadonnées). **Cause dans le service Auth
> de Supabase, non élucidée.**
>
> **Corrigé** : (1) l'admin distingue le nom **saisi** du nom **fabriqué**
> (`nom_source`) et n'affiche plus une identité inventée ; (2) l'application
> **écrit le nom elle-même** après l'inscription téléphone, via
> `app_student_update_full_profile` — elle ne dépend plus de `data:`.
> **NON VÉRIFIÉ** : qu'une inscription réelle enregistre bien le nom.
>
> ⚠️ **Reste : 76 comptes sans identité récupérable.** Le nom n'a jamais été
> stocké : aucun rattrapage automatique n'est possible. Il faudra le demander à
> ces utilisateurs (écran de complétion à la prochaine connexion, par exemple).
>
> ### ✅ 04/09 — L'ONGLET ANALYTICS RÉPARÉ (il était mort depuis toujours)
>
> **La collecte n'a jamais été en panne** : 4 927 événements du 21/07 au 04/09,
> 193 visiteurs, 3 779 anonymes, et **48,2 % de conversion visite → connexion**
> (85 visiteurs sur 193 venus anonymes puis connectés).
>
> C'est l'**écran admin** qui était cassé, par trois défauts empilés :
> RPC dans le schéma `app` (non exposé par PostgREST) → échec à chaque
> ouverture ; erreur avalée par un `debugPrint` → « Aucune donnée » trompeur ;
> lecture de `user_navigation_events` (**0 ligne**) au lieu de
> `analytics_events`. Réparer une seule n'aurait rien changé.
>
> **Corrigé et vérifié par rôle** : étudiant → `forbidden` ; admin → 2 494
> événements / 107 visiteurs / 95 anonymes sur 30 jours. Contrôle `is_admin()`
> ajouté (l'ancienne n'en avait aucun), `anon` révoqué.
>
> **Ce que les données montraient sans qu'on les voie** — onglets étudiants :
> Accueil 298 vues / 72 visiteurs, Bobodo 91/22, **Partenaires 85/49**,
> Candidatures 75/33, Orientation 10/4 (dernier le 17/08). Partenaires — les
> offres — touche le plus de personnes après l'accueil.
>
> ### ✅ 04/09 — LE COURTAGE EST ENFIN INSTRUMENTÉ
>
> Le trou signalé ci-dessus est comblé (écrit et compilé, **pas encore vérifié
> en base**) :
> - **tunnel de candidature** : `program_apply` avec sept étapes nommées —
>   `click`, `deja_candidate`, `dossier_requis` (+ `champs_manquants`),
>   **`abandon_dossier`**, `dossier_complete`, `abandon_formulaire`, `deposee`.
>   Posé dans `applyToProgram()`, point de passage **unique** des trois boutons
>   « Candidater » : on saura enfin **à quelle étape** les 97 % décrochent ;
> - **mini-sites universités** : `university_site_view` par `slug` ;
> - **recherches** : `trackSearch` branchée (temporisation 1,2 s, ≥ 3 lettres).
>   Une demande répétée sans résultat = une formation à aller négocier.
>
> **Mesuré** : analyze 0 erreur / 2 100 (inchangé), build web réussi (45,1 Mo).
> **NON VÉRIFIÉ** : qu'un événement arrive réellement en base depuis ces points.
> À confirmer après déploiement :
> `select event_type, count(*) from app.analytics_events where event_type in
> ('program_apply','university_site_view','search') group by 1;`
>
> ### 🚨 03/09 — 2,5 % DES ÉTUDIANTS ARRIVENT À CANDIDATER
>
> **Le chiffre le plus important de cette séance.** Mesuré en production :
> **279 étudiants, 9 dossiers complets, 7 candidats.** Le parcours exige jusqu'à
> **18 champs** (12 obligatoires bloqués côté serveur + 6 au formulaire).
>
> Détail par champ : `full_name` **279/279** (rempli à l'inscription), **chacun
> des onze autres 10 ou 11 sur 279**. Ce n'est pas un abandon progressif, c'est
> **un mur** — le formulaire est refermé à la vue, pas quitté en cours de route.
>
> Verrou serveur : `app_is_student_dossier_complete()` exige les douze sans
> nuance ; `app_create_application` refuse tant qu'ils manquent.
>
> **Proposition en attente d'accord** — trois paliers : candidater avec
> **3 champs** (naissance, année et série du bac, les seuls qui conditionnent
> l'admissibilité), le reste différé à l'examen du dossier, le BEPC seulement si
> l'établissement l'exige. Veille à l'appui (Formstack 2025 : 67,8 % d'abandon
> au-delà de 7 champs ; progressive profiling : +27 % de complétion **et** +34 %
> de qualité de données). Détail et sources : `docs/JOURNAL_INTERVENTIONS.md`.
>
> ⚠️ **Défaut trouvé, non traité** : **deux versions de `app_create_application`**
> coexistent en base (1 715 et 2 457 octets). Selon les paramètres envoyés, ce
> n'est pas la même qui s'exécute.
>
> ### ✅ 03/09 — DÉCONNEXION VISIBLE DANS LES NEUF TABLEAUX DE BORD
>
> Elle existait partout (les neuf ouvrent `StudentSettingsScreen`) mais enfouie
> derrière l'engrenage. Un composant partagé — `lib/widgets/bouton_deconnexion.dart`,
> qui porte aussi le `unregisterTokenBeforeLogout` — est posé dans les neuf
> barres du haut, et **reste dans les paramètres**. Barre mobile étudiant :
> `[Avatar→profil] [Bonjour] [Documents] [Partager] [Déconnexion] [⋯]`.
> **Mesuré** : analyze 0 erreur / 2 100 (inchangé), build web réussi.
> **NON VÉRIFIÉ** : l'encombrement réel à 375 px.
>
> ### ⏳ 03/09 — LE TÉLÉCHARGEMENT DU REÇU, ÉCRIT MAIS NON PROUVÉ
>
> Défaut suivant relevé par Jocelyn : « Télécharger le reçu » appelait
> `Printing.layoutPdf`, donc **l'aperçu d'impression** — aucun fichier n'était
> enregistré nulle part.
>
> Écrit : MediaStore natif (4ᵉ MethodChannel `com.academia.app/fichiers`) pour
> Android, `Printing.sharePdf` pour le web (code lu : `Blob` + `<a download>`).
> Aucune dépendance ajoutée — les deux greffons MediaStore de pub.dev sont
> figés depuis 20 et 23 mois et testés jusqu'à l'API 33, alors que le projet
> cible **36**.
>
> **Mesuré** : `flutter analyze` **0 erreur / 2 100** (référence 2 101 — un
> avertissement de moins). `flutter build apk --debug` **code 0**, APK produit :
> le Kotlin compile, aucun `e:` ni `Unresolved reference`.
>
> **NON PROUVÉ, et la compilation ne le prouvera jamais** : que le fichier
> atterrisse réellement dans « Téléchargements ». Le passage `Uint8List` →
> `ByteArray` et l'écriture MediaStore ne se vérifient qu'à **l'exécution sur un
> appareil**. **À essayer en premier** : le chemin web sur app.academiea.com —
> il ne dépend pas du Kotlin et se constate immédiatement dans le navigateur.

**B9 répond à la question laissée ouverte au §9.2** (« l'écran n'a jamais
tourné ») : sur téléphone, il n'était même pas atteignable. Il l'est désormais —
et **il a tourné en session réelle le 03/09** (voir l'encadré ci-dessus).

Tentative du 03/09 : le TECNO POVA branché n'est vu qu'**en Bluetooth**, et
l'USB remonte *« Périphérique USB inconnu (échec de demande de descripteur »*.
Windows ne lit même pas l'identité de l'appareil : la liaison physique est en
cause (câble sans fil de données, port, connecteur), pas la configuration
Android. **L'APK est prêt** :
`academia_app/build/app/outputs/flutter-apk/app-debug.apk` (311,5 Mo, code 0).

**Ce qui reste à vérifier sur l'appareil**, et qui ne peut pas l'être d'ici :
menu « … » de l'accueil → « Mes documents » ; l'onglet Reçus se remplit (la
jointure PostgREST sous RLS étudiante) ; « Télécharger le reçu » sort le PDF.

**Preuve anti-régression du chantier** : `flutter analyze` **0 erreur / 2 101**
(identique à avant), `flutter build apk --debug` **code 0**. Les deux échecs de
compilation rencontrés venaient du **disque plein** (0 Go ; `IOException:
Espace insuffisant`), pas du code : 4,5 Go récupérés sur les caches Gradle 8.14
et 8.9, inutilisés par ce projet qui tourne sur 8.12.

Majeurs corrigés : **M1** (sous-paiement d'abonnement — le tarif est désormais lu
au serveur, comme le courtage figé le 02/09), **M4** (lien de notification qui
plantait faute de provider), et **M5** (l'empreinte porte enfin sur le `snapshot`
figé, ce qui **est** le reçu, et non sur la ligne de paiement mutable ; éprouvé
dans les deux sens : reçu émis `intacte=true`, snapshot altéré `intacte=false`.
Fait maintenant **parce qu'aucun reçu ne portait encore d'empreinte** — plus
tard, il aurait fallu choisir entre casser des documents et garder une formule
fausse).

Majeurs restants : **M2** aucun reçu envoyé par courriel (file sans
consommateur) ; **M3** chaîne commission/versement **vide** malgré 18 paiements
(cause non établie — on ne corrige pas ce qu'on n'a pas tracé) ; **M6** les 18
reçus antérieurs sans `signature_hash` — **délibérément non corrigé**, une
empreinte calculée aujourd'hui attesterait du 03/09 et non de l'émission.

**Correction de mesure** : les `n_live_tup` de `tables_colonnes.json` sont
périmés. Comptes réels 03/09 : `credit_transactions` **279** (les crédits sont
très utilisés), `student_credits` 18, `student_dossier_documents` 5,
`subscriptions`/`referral_commissions`/`actor_balances`/`payout_queue`/
`marketplace_payments` **0**.

**Découverte de méthode** : la chaîne `.windsurf/` (le « PC administrateur »)
pointe, dans son `.env`, vers un projet Supabase **mort** (`evaegkqrnyjitnrcaqgt`).
Le relevé a été refait contre le projet vivant. Elle repose en outre sur B1.

---

## Comment on tient ce fichier à jour

- **Au début de chaque intervention** : le hook `etat_projet.py` en affiche
  l'essentiel. On le lit avant d'agir.
- **À chaque acte significatif** (déploiement, migration, image, mesure,
  décision) : une ligne dans `docs/JOURNAL_INTERVENTIONS.md`.
- **À la fin de chaque intervention** : §1, §3, §4 et §6 sont remis à jour.
  Le hook `fin_intervention.py` le rappelle si le dépôt a bougé sans que ce
  fichier ait été touché.
