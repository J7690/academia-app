# CLAUDE.md — Academia

> ## ⚠️ L'ÉTAT DU CHANTIER N'EST PAS DANS CE FICHIER. Il est dans **`ETAT.md`** (racine).
>
> **Lire `ETAT.md` avant toute action.** Il est relevé et daté à chaque
> intervention ; ce fichier-ci décrit ce qui **ne bouge pas** — la structure du
> dépôt, les pièges permanents, les interdits.
>
> **Pourquoi cette séparation.** Ce fichier a annoncé « chantier en cours :
> Smart Whiteboard — latence » du 28/07 au 13/08, seize jours après qu'on ait
> changé de chantier. Un document qui mêle le durable et le courant vieillit
> à la vitesse du courant, et oriente alors chaque séance sur une fausse piste.
> Mesure du 13/08 : `docs/` contenait **219 fichiers**, dont dix s'annonçant
> comme « état » ou « plan », et aucun ne disait lequel faisait foi.
>
> | Où | Quoi | Qui le tient |
> |---|---|---|
> | **`ETAT.md`** | où on en est, ce qui marche (mesuré), ce qui est cassé, quoi ensuite | mis à jour à chaque intervention |
> | **`docs/JOURNAL_INTERVENTIONS.md`** | append-only, un acte par ligne — comment on y est arrivé | on n'y efface jamais rien |
> | **ce fichier** | structure, pièges permanents, commandes, interdits | rarement |
> | `docs/*.md` (219) | archives datées — pour comprendre *pourquoi*, jamais *où on en est* | figées |
>
> Deux hooks rendent cela exécutoire : `etat_projet.py` (SessionStart) injecte
> `ETAT.md` et les derniers actes ; `fin_intervention.py` (Stop) signale quand
> l'état a pris du retard sur les fichiers modifiés.

---

## 1. Ce qu'est le projet

Academia : application **Flutter** éducative (Burkina Faso / Afrique de l'Ouest) adossée à
**Supabase**. Le module actif est le **Smart Whiteboard** : un étudiant tape un sujet, une IA
génère un storyboard de cours, et un VPS **fabrique une vidéo animée** façon spot pédagogique
(écriture manuscrite en direct, voix off, annotations, sound design).

---

## 2. Pièges de structure — À LIRE AVANT DE COMPILER

**Il y a DEUX projets Flutter dans ce dépôt :**

| Chemin | Rôle |
|---|---|
| `./pubspec.yaml` + `./lib/` | Projet racine `academia` (historique) |
| `./academia_app/pubspec.yaml` + `./academia_app/lib/` | **Application réelle du Smart Whiteboard** |

➡️ **Tout le travail Smart Whiteboard se fait dans `academia_app/`.** Les commandes `flutter`
doivent être lancées **depuis `academia_app/`**, pas depuis la racine.

Un **SDK Flutter complet** est aussi committé dans `./flutter/` : à **ignorer** (ce n'est pas
du code applicatif ; ne jamais y chercher un bug, ne jamais le modifier).

---

## 3. Infrastructure

| Élément | Valeur |
|---|---|
| **Supabase** | projet `thevdfcwlcqzdoybfvgs` — schéma métier **`app`**, RPC dans **`public`** |
| **VPS de rendu** | **LWS** `31.207.38.60` (hostname `vps122603`), Ubuntu 24.04, 4 vCPU / 8 Go / 147 Go |
| **Accès VPS** | alias SSH **`lws-nexiom`** (clé `~/.ssh/id_ed25519`) — **ne jamais lire ni committer la clé** |
| **Service de rendu** | systemd **`whiteboard-worker`** (dossier `/opt/whiteboard-worker/`) |
| **Hébergeurs abandonnés** | Railway (mort), **Kamatera** (coupé pour dépassement de quota) — ne pas y revenir |

Le worker **sort** vers Supabase (polling). **Aucun port entrant** n'est nécessaire : ne
touche pas au pare-feu.

---

## 4. Architecture du Smart Whiteboard

```
Étudiant (Flutter)
   └─> Edge Function `whiteboard-generate-storyboard`  → storyboard v3 (scènes/beats/blocs/narration)
        └─> table app.whiteboard_renders (status=queued)
             └─> worker LWS `whiteboard-worker`
                  1. NARRATION d'abord (elle FIXE la durée de chaque scène)
                  2. page HTML animée (2 passes : mesure des positions → caméra)
                  3. capture Playwright en 3 tranches parallèles  ─┬─> APERÇU (15 s) publié tôt
                  4. sound design (bruitages + ducking)            │
                  5. mux + upload Supabase Storage → status=done ──┘
```

**Règle d'or** : la **voix commande l'image**. `whiteboard_page_builder.plan()` calcule
`needed = max(scene_elapsed, narration, MIN_SCENE_SEC)` : le vrai levier sur la durée d'une
vidéo est le **nombre de mots de narration**, pas le champ `duration_ms`.

### Fichiers clés
| Où | Quoi |
|---|---|
| `supabase/functions/whiteboard-generate-storyboard/` | `index.ts`, `prompt.ts`, `validate.ts`, `validate_test.ts`, `llm.ts` |
| `academia_bobodo_backend/` | worker (`whiteboard_render_worker.py`, `whiteboard_narration.py`, `whiteboard_upload_renderer.py`) |
| `academia_bobodo_backend/whiteboard_vision/` | moteur de rendu (`whiteboard_page_builder.py`, `whiteboard_video_capture.py`, `whiteboard_vision_v2.py`, `record_scene.js`) |
| `academia_app/lib/features/challenge/smart_whiteboard/` | app : provider, services, écrans |

---

## 5. Les 3 contraintes NON NÉGOCIABLES

Issues de l'expérience ; toute évolution doit les respecter.

1. **100 % CSS pour les animations.** `record_scene.js` n'avance que les animations CSS
   (`document.getAnimations()`). GSAP / Lottie piloté en JS **cassent** la capture par
   tranches — donc la rapidité *et* l'aperçu. Écartés délibérément.
2. **Aucun calcul d'IA sur le VPS.** 4 vCPU dédiés à la capture. Kokoro-82M en local a été
   abandonné (RTF 3,25–4,5). Toute IA passe par une **Edge Function cloud**.
3. **Dégradation gracieuse obligatoire.** L'étudiant doit toujours obtenir son cours, même
   imparfait. On **nettoie, on ne rejette pas** (cf. `validate.ts`) : rejeter = il perd ses
   crédits *et* sa vidéo.

---

## 6. Commandes

### Flutter (depuis `academia_app/`)
```bash
cd academia_app
flutter pub get
flutter analyze
flutter build apk --debug
# L'IP du VPS est injectable au build :
flutter build apk --dart-define=VPS_HOST=31.207.38.60
```

### Tests de la validation du storyboard (Deno)
```bash
deno test supabase/functions/whiteboard-generate-storyboard/validate_test.ts
deno test supabase/functions/whiteboard-generate-storyboard/validate_capsule_test.ts
```
> ✅ **Exécutés le 11/08/2026 : 21 + 10 tests, 0 échec.** L'alerte précédente disait
> « pas de Deno dans l'environnement » ; c'était faux pour le **poste Windows**, qui
> dispose de Deno 2.9.4. La tâche est restée bloquée deux semaines sur une prémisse
> jamais vérifiée. **Deno est en revanche réellement absent de LWS** — d'où la
> confusion, et d'où la compétence `etat-des-moyens`.

### VPS
```bash
ssh lws-nexiom "systemctl status whiteboard-worker --no-pager | head -15"
ssh lws-nexiom "journalctl -u whiteboard-worker --since '2 hours ago' --no-pager | tail -60"
# Déployer un fichier du moteur :
scp academia_bobodo_backend/whiteboard_vision/<fichier> lws-nexiom:/opt/whiteboard-worker/vision_engine/
ssh lws-nexiom "systemctl restart whiteboard-worker"
```

### Diagnostic Supabase (SQL utile)
```sql
-- Temps de rendu réels et ratio (rendu / durée vidéo)
select id, duration_ms/1000.0 as video_sec,
       round(extract(epoch from (completed_at - started_at)))::int as rendu_sec,
       round(extract(epoch from (completed_at - started_at)) / nullif(duration_ms/1000.0,0), 2) as ratio
from app.whiteboard_renders
where status='done' order by created_at desc limit 10;

-- Les aperçus sont-ils publiés ? (doit être > 0)
select count(*) from storage.objects
where bucket_id='whiteboard-renders' and name like '%preview%';
```

---

## 7. ~~État au 28/07/2026~~ — **ARCHIVE, NE PLUS S'Y FIER**

> Cette section a été le « chantier en cours » jusqu'au 13/08/2026. Elle est
> conservée comme **trace du chantier Smart Whiteboard**, et n'a plus valeur
> d'état : voir `ETAT.md`. Ne pas la mettre à jour — la remplacer serait
> recréer le défaut qu'on vient de corriger.

### (archive) État au 28/07/2026 et travail à reprendre

### Contexte : le problème de latence
Mesuré : un cours de **201 s** rendu en **401 s** (ratio 2,0×) → l'étudiant attend **6 min 41**.
La génération IA n'est **pas** en cause (quelques secondes, $0,002). Deux causes réelles :
la **longueur des cours**, et l'**aperçu instantané qui ne fonctionne pas**.

### ✅ P2 — Format spot (fait, déployé v54)
Cible **90–150 s** (recherche 2026 : 91 % de complétion, +62 % de rétention).
- `prompt.ts` : 5–6 scènes, 2–3 blocs/scène, **budget de 250 mots de narration**, exemples alignés.
- `validate.ts` : `MAX_SCENES` 20→**7** (avec **préservation du récap final**),
  `MAX_BLOCKS_PER_SCENE` 10→**4**, bornes scène 4–25 s, **écrêtage proportionnel** si total > 150 s.
- `validate_test.ts` : test de troncature mis à jour + **3 tests ajoutés**. **NON EXÉCUTÉS.**

### ⏳ P1 — Aperçu instantané (à faire, priorité 1)
**0 aperçu publié sur 71 rendus.** Le seul `preview.mp4` du bucket est un test manuel.
Le code existe et les seuils sont bons (`MIN_DURATION_FOR_PREVIEW=60` < vidéos de 120–201 s) :
il **échoue à l'exécution**, et l'exception est avalée par le `except` de `record_page_parallel`
(« apercu non publie — rendu poursuivi »).
**Hypothèse principale** : `_publish_preview` (dans `whiteboard_render_worker.py`) fait un
upload **synchrone depuis un thread de capture**, alors que le worker est asyncio.
Procédure de diagnostic prête : **`docs/INSTRUCTIONS_WINDSURF_P1_APERCU.md`**.
Gain attendu : première image en **~20–30 s** au lieu de 6 min 41.

### 🔍 P3 — Dérive du ratio de rendu (à évaluer)
Ratio passé de **1,06× (25/07)** à **2,0× (27/07)** après les vagues typographie + sound design.
Isoler le surcoût et viser ~1,3×.

### Après correction : mesurer
Générer un cours réel, puis vérifier : durée vidéo (~100–130 s attendus), temps de rendu
(~200–260 s), et **délai avant aperçu**.

---

## 8. Valeurs couplées — modifier les DEUX côtés

| Valeur | Fichiers | Risque si désynchronisé |
|---|---|---|
| `INTRO_SEC = 3.2` | `whiteboard_page_builder.plan()` **et** `adelay` ffmpeg dans `whiteboard_render_worker.py` | Voix décalée sur **toute** la vidéo |
| `renders/<id>/preview.mp4` | `whiteboard_upload_renderer.preview_object_key` **et** `SmartWhiteboardRenderService._previewObjectKey` | Aperçu cassé **en silence** (404 traité comme « pas prêt ») |
| `TTS_SPEED = 0.88` | `whiteboard_narration.py` (via ffmpeg `atempo`) | L'Edge Function TTS **ignore** tout paramètre `speed` : ne pas perdre de temps dessus |

**Autre piège connu** : `proto_capture_bf.js` produit des **images blanches**. Pour toute
validation visuelle, utiliser `snap_still.js` / `snap_frames.sh`.

---

## 9. Documentation à lire (par ordre d'utilité)

| Document | Contenu |
|---|---|
| `docs/rapport_smart_whiteboard_2026-07/README.md` | Vue d'ensemble, architecture, résultats mesurés |
| `docs/rapport_smart_whiteboard_2026-07/08_LATENCE_2026-07-28.md` | **Le chantier en cours** : diagnostic latence, P1/P2/P3 |
| `docs/rapport_smart_whiteboard_2026-07/07_AUDIT_2026-07-27.md` | Audit 3 couches : 4 défauts trouvés (dont le code d'erreur mort côté Flutter) |
| `docs/rapport_smart_whiteboard_2026-07/04_DIFFICULTES_ET_DECISIONS.md` | Chaque problème, sa cause racine, la décision retenue |
| `docs/rapport_smart_whiteboard_2026-07/05_PROCEDURES.md` | Commandes de déploiement et de diagnostic |
| `docs/rapport_smart_whiteboard_2026-07/06_RESTE_A_FAIRE.md` | Pistes classées valeur/effort + ce qui est **délibérément écarté** |

---

## 10. Méthode de travail attendue

Le protocole du projet (cf. `docs/ACADEMIA_PERMANENT_EXECUTION_PROTOCOL.md`) :
**comprendre → auditer → analyser → comparer → proposer → implémenter → valider.**

En pratique, sur ce dépôt :
- **Mesurer avant de conclure.** Beaucoup de temps a été perdu sur des symptômes identiques
  ayant des causes différentes. Interroger Supabase / les logs plutôt que supposer.
- **Réparer l'observabilité d'abord.** Un défaut d'affichage d'erreur a rendu tout diagnostic
  impossible pendant une session entière.
- **Ne pas dupliquer.** Le dépôt contient des moteurs de rendu abandonnés
  (`whiteboard_engine_remotion/`, `scene_template.html`, chaîne Pillow) conservés comme
  archives : **le moteur de production est `whiteboard_vision/`**.
- **Documenter en ajoutant un fichier daté**, sans réécrire l'historique.

---

## 11. Environnement de l'agent (installé le 05/08/2026)

Le dépôt configure lui-même l'agent. Ces fichiers sont **versionnés exprès** :
ils doivent être lisibles et critiquables, pas subis.

| Fichier | Rôle |
|---|---|
| `.claude/settings.json` | garde-fous : `deny` / `ask` / `allow`, et les hooks |
| `.claude/settings.local.json` | autorisations **personnelles**, non versionné |
| `.mcp.json` | serveur MCP Supabase **en lecture seule**, aucun secret |
| `.claude/skills/` | 11 compétences : orientation, vérification, débogage, recherche, revues, **+ les 4 procédures obligatoires ci-dessous** |
| `.claude/agents/` | 4 sous-agents en lecture seule |
| `.claude/hooks/` | 3 hooks Python |

### Les trois hooks

- **`garde_secrets.py`** (PreToolUse) — refuse toute commande qui lirait une clé
  privée ou toucherait au pare-feu. Il rend exécutoires les deux interdits du §3.
- **`anti_boucle.py`** (PostToolUse) — compte les retouches d'un même fichier et
  alerte à la 4ᵉ **sans mesure entre-temps**. Une commande de vérification
  (`flutter analyze`, `deno test`, `pytest`…) remet le compteur à zéro.
- **`etat_projet.py`** (SessionStart) — annonce l'état **mesuré** du dépôt
  (branche, avance sur `origin`, fichiers non commités) plutôt que l'état
  supposé. Ce fichier-ci vieillit ; ce hook, non. Depuis le 11/08 il annonce
  aussi les **accès manquants** (jeton Supabase, Deno, Flutter) et rappelle les
  **procédures obligatoires**.

### Les quatre procédures obligatoires (11/08/2026)

Chacune répare une faute réellement commise, le 11/08, en une seule séance.

| Compétence | À charger avant | Faute qu'elle répare |
|---|---|---|
| **`etat-des-moyens`** | tout chiffrage de latence/coût/capacité, tout « on ne peut pas » | un coût fixe de machine annoncé à 3 min 25 alors qu'il approche la demi-heure — le chiffre était dans `install_pod.sh:17` |
| **`continuite-du-chantier`** | toute proposition touchant une couche non écrite dans la séance | une banque d'objets recommandée alors que `fabriquer_contours.py` tranchait la question dans l'autre sens, avec motif |
| **`veille-externe`** | toute décision d'architecture ou de composant | une conception rendue sans **aucune** étude des plateformes, et une licence lue dans un résumé au lieu du fichier `LICENSE` |
| **`studio-visuel-3d`** | toute tâche touchant `studio_visuel/` | la grammaire visuelle, les pièges déjà payés, et ce qui est **déjà tranché** |

**La règle commune** : ne jamais déduire un état de ce qu'on ne voit pas. Un accès
manquant se signale à la première seconde, pas à la centième.

Tous **échouent en laissant passer** : un garde-fou qui casse la session est un
garde-fou qu'on désactive.

### Ce qui est interdit sans autorisation explicite de Jocelyn

Écriture en base de production, déploiement d'Edge Function, migration distante,
`git commit`, `git push`, publication Facebook ou Canva. `.claude/settings.json`
les met en `deny` ou en `ask` : **ne pas contourner** en passant par une autre
commande.

### La règle qui prime sur toutes les autres

> **Ne jamais déduire un état de ce qu'on ne voit pas.**
> Vérifier qu'un fichier est valide ne dit rien de ce qu'il contient.

Elle vient des sept défauts recensés dans
`docs/STUDIO_VISUEL_ETAT_2026-08-05.md`. Six se cachaient derrière une absence
de message ; le septième derrière un message de **succès** — une vidéo noire et
muette livrée à un étudiant comme « prête ».

### Extensions installées

Cinq plugins officiels Anthropic, manifestes vérifiés avant installation :
`feature-dev`, `pr-review-toolkit`, `code-review`, `commit-commands`,
`security-guidance`. Les quatre premiers n'ajoutent **ni hook ni serveur MCP**.
`security-guidance` ajoute des hooks Python (dont une relecture par LLM à
l'arrêt) et installe l'Agent SDK au démarrage de session — c'est le seul à avoir
une empreinte sur la machine.

Écartés : `hookify` (hooks Python sur *chaque* appel d'outil) et `ralph-wiggum`
(boucles auto-référentielles, contraire à `anti_boucle.py`).
