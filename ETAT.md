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
| ~~Capsule 3D injoignable après fermeture de l'app~~ | 19/08 | **corrigée le 20/08** — l'écran d'aperçu rattrape le travail via `studio_creer_travail_etudiant`, idempotente : elle rend la capsule déjà prête au lieu d'en refabriquer une. **Non essayé sur téléphone** |
| ~~`estAnimation3d` n'est qu'un drapeau client~~ | 19/08 | **corrigée le 20/08** — `loadProject` restaure `_typeProduction` depuis le storyboard (présence de `gestes`), au lieu d'un drapeau qui mourait avec l'application. **Non essayé sur téléphone** |
| ~~Rouvrir un cours 3D depuis « Mes cours » plante~~ | 19/08 | **corrigée le 20/08** — `loadProject` reconnaît une capsule et cesse de l'analyser comme un storyboard de tableau ; l'éditeur redirige vers l'aperçu. **Non essayé sur téléphone** |
| Un projet coquille est créé à chaque génération | 20/08 | **ouverte** — mesuré : `createProject` crée `67ce1bc4` (0 scène), puis le serveur crée le sien (`518ca1e4`) que le client adopte. Le premier reste en base, visible dans « Mes cours » comme un cours vide |
| L'URL signée 6 h est publiée telle quelle dans le Challenge | 19/08 | **ouverte** — le bucket est privé et la politique n'autorise que le propriétaire : la vidéo publiée meurt pour les spectateurs au bout de 6 h |
| Codes techniques affichés à l'étudiant (`invalid_capsule`, `storyboard_sans_scenes`…) | 19/08 | **ouverte** — `_messageForError` traduit six codes ; ceux de la chaîne 3D n'y sont pas |

---

## Comment on tient ce fichier à jour

- **Au début de chaque intervention** : le hook `etat_projet.py` en affiche
  l'essentiel. On le lit avant d'agir.
- **À chaque acte significatif** (déploiement, migration, image, mesure,
  décision) : une ligne dans `docs/JOURNAL_INTERVENTIONS.md`.
- **À la fin de chaque intervention** : §1, §3, §4 et §6 sont remis à jour.
  Le hook `fin_intervention.py` le rappelle si le dépôt a bougé sans que ce
  fichier ait été touché.
