# CLAUDE.md — Academia

> Point d'entrée pour tout agent (Claude Code, Windsurf, Cowork) reprenant ce projet.
> Dernière mise à jour : **28/07/2026**.
> Chantier en cours : **Smart Whiteboard — réduction de la latence (P1/P2)**.

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
```
> ⚠️ **À exécuter en priorité** : des tests ont été ajoutés le 28/07 sans avoir pu être lancés
> (pas de Deno dans l'environnement Cowork). C'est la **première chose à faire**.

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

## 7. État au 28/07/2026 et travail à reprendre

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
