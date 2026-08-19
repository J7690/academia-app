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

**Le flux 3D est fonctionnel de bout en bout, mesuré le 19/08 : 2 min 40 entre
la commande et la vidéo disponible pour l'étudiant** — voix, sous-titres, et
**six plans sur six montrant leur sujet**.

Détail de ces 2 min 40 (travail `ea601c81`, sujet « le pétrole ») :

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

### 4.4 Le maillon que je n'ai PAS exercé
Le bouton lui-même. Les trois RPC que l'écran appelle ont été exercées sous
l'identité de l'étudiant propriétaire, mais **l'appui dans l'application n'a pas
été rejoué** : je n'ouvre pas de session sur un compte utilisateur. Ce qui reste
non prouvé est donc le câblage écran → service, pas la chaîne serveur.

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

1. **Rejouer le flux depuis l'écran**, sur le téléphone de Jocelyn — c'est le
   seul maillon non exercé (§4.4).
2. **Vérifier l'invite sur un troisième sujet** non technique, pour savoir si la
   qualité tient hors physique/industrie.
3. **Silhouettes reconnaissables** (§4.2) — travailler l'invite, pas le moteur.
4. **Conclure `silhouetter`, `extruder`, `ecrire`** (§4.3).
5. **Reprise automatique** quand un travail attend sans machine : mesuré le
   18/08, « pluie » a attendu **81 min** sans que personne ne le sache.
6. **Alléger l'image** (4,47 Go pour un moteur de 82 Ko) maintenant que
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

---

## Comment on tient ce fichier à jour

- **Au début de chaque intervention** : le hook `etat_projet.py` en affiche
  l'essentiel. On le lit avant d'agir.
- **À chaque acte significatif** (déploiement, migration, image, mesure,
  décision) : une ligne dans `docs/JOURNAL_INTERVENTIONS.md`.
- **À la fin de chaque intervention** : §1, §3, §4 et §6 sont remis à jour.
  Le hook `fin_intervention.py` le rappelle si le dépôt a bougé sans que ce
  fichier ait été touché.
