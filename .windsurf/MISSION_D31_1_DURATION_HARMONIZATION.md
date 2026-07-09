# MISSION D31.1 — HARMONISATION DES DURÉES DU SMART WHITEBOARD

**Date :** 2026-06-30  
**Mode :** LECTURE SEULE — aucune modification appliquée  
**Objectif :** Déterminer où les durées doivent être définies et qui en est responsable, en préparation de la correction D31.1.

---

## PHASE 1 — AUDIT DU DÉCOUPAGE IA

### Source lue

- `supabase/functions/whiteboard-generate-storyboard/index.ts` (516 lignes, lu intégralement)
- `.windsurf/MISSION_D31_1_duration_audit_output.json` — 5 storyboards réels analysés
- `.windsurf/MISSION_D31_1_rpc_audit_output.json` — définitions RPC `fetch_queued_jobs`, `create_render_job`, `mark_done`

### Comment l'IA découpe un sujet

L'Edge Function utilise un `systemPrompt` avec des règles pédagogiques par mode :

- **Mode A (sujet simple)** : Introduction → Définitions → Exemples → Exercice → Correction.
- **Mode B (texte complet)** : Résumé → Points clés → Définitions → Exemples → Exercice → Correction.
- **Mode C (plan)** : Une scène par section du plan.
- **Mode D (cours existant)** : Résumé → Points clés → Définitions → Exemples → Exercice → Correction.

Règles imposées par le prompt (lignes 209-213) :
- 5–10 scènes.
- 3–6 blocs par scène.
- Types de blocs : title, paragraph, formula, definition, exercise, correction.

### Qui décide du nombre de scènes ?

**L'IA (Edge Function)**. Le prompt impose une plage (5–10) et une structure pédagogique. L'IA choisit le nombre exact et les titres.

### Comment `duration_ms` est actuellement généré

Dans le prompt, l'exemple JSON montre `"duration_ms": 5000` (ligne 238). Cependant, l'IA génère des durées **variées**.

**Preuve sur 5 storyboards réels :**

| Projet | Sujet | Scènes | `duration_ms` par scène | Total |
|---|---|---|---|---|
| `3993bb85...` | dérivés d'une fonction | 8 | 7000, 8000, 10000, 9000, 8000, 7000, 9000, 6000 | **64 000 ms** |
| `101747f4...` | dérivés d'une fonction | 8 | idem | **64 000 ms** |
| `da5fc34c...` | primitive d'une fonction | 8 | 8000, 10000, 9000, 12000, 15000, 10000, 12000, 7000 | **83 000 ms** |
| `a288a118...` | primitive d'une fonction | 8 | idem | **83 000 ms** |
| `3fa88728...` | dérivés d'une fonction | 9 | 7000, 8000, 6000, 7000, 9000, 10000, 7000, 8000, 7000 | **69 000 ms** |

**Conclusion :** `duration_ms` n'est **pas hardcodé** à 5000 ms par l'IA. L'IA produit des durées variables en fonction du contenu. Les valeurs sont **exploitables**.

---

## PHASE 2 — ANALYSE INDUSTRIELLE

### Recherches externes effectuées

- Canva Help — *Trim videos and change scene duration* : https://www.canva.com/help/trim-videos/
- Canva Help — *Record voiceover in the editor* : https://www.canva.com/help/record-voiceover/
- Explain Everything Help — *Introduction to Recording* : https://help.explaineverything.com/hc/en-us/articles/360013332774
- CapCut — *Text to Speech* : https://www.capcut.com/tools/text-to-speech
- CapCut Guide — *CapCut Text to Speech* : https://capcutguide.com/capcut-text-to-speech/
- Khan Academy Blog — *How Khan Academy Videos Are Made* : https://blog.khanacademy.org/how-khan-academy-videos-are-made-to-help-you-learn/

### Ce que font les leaders

| Plateforme | Qui fixe la durée | Comment |
|---|---|---|
| **Canva** | Scène / timeline | L'utilisateur peut changer la durée d'une scène. Les clips audio/voix off sont alignés sur la timeline. |
| **Explain Everything** | Slide + timeline | Chaque slide a sa propre timeline. La durée dépend de l'enregistrement et des interactions. |
| **CapCut** | Clip / TTS | Le TTS génère un clip audio de durée réelle, placé sur la timeline. La durée visuelle est ajustée en conséquence. |
| **Khan Academy** | Narrateur / monteur | Les vidéos sont montées manuellement (Camtasia/Premiere) avec narration humaine. |
| **GoodNotes** | N/A | Pas de génération vidéo automatique ; audio lié à la page. |

### Meilleure pratique industrielle

**A + B + C combinées :**

1. **Le storyboard fixe une durée initiale** (A) — estimation pédagogique, souvent basée sur la complexité du contenu.
2. **Le TTS recalcule la durée réelle** (B) — la narration générée impose sa propre longueur.
3. **Le renderer finalise** (C) — il assemble les images et l'audio selon la durée déterminée.

**FFmpeg n'est jamais le décideur de la durée.** Il est un exécutant : il reçoit une durée explicite (concat demuxer, loops, audio track) et produit le MP4 correspondant.

---

## PHASE 3 — TRAÇAGE COMPLET DE `duration_ms`

| Étape | Valeur de `duration_ms` | Utilisée ? | Responsable |
|---|---|---|---|
| **Input Flutter** | Aucune | Non | Utilisateur (saisit le sujet) |
| **Edge Function `whiteboard-generate-storyboard`** | Généré par l'IA (ex. 6000–15000 ms) | ✅ Oui, stocké dans `storyboard_json` | IA / Prompt |
| **Validation Edge Function** | Vérifié présent dans chaque scène | ✅ Oui | Edge Function |
| **Stockage Supabase** | `storyboard_json` dans `app.whiteboard_projects` | ✅ Oui | Supabase |
| **`updateProject` Flutter** | Peut être modifié par l'utilisateur | ✅ Oui | Flutter / Utilisateur |
| **`createRenderJob` Flutter** | Seul `project_id` est envoyé | Non directement | Flutter (déclencheur) |
| **RPC `whiteboard_create_render_job`** | Crée ligne `whiteboard_renders` avec `project_id` | Non | Supabase |
| **Worker `whiteboard_fetch_queued_jobs`** | Récupère `storyboard_json` complet | ✅ Oui, mais **ignoré ensuite** | Kamatera |
| **`whiteboard_render_worker.py`** | `storyboard_json` disponible | ❌ **NON utilisée** | Kamatera |
| **`whiteboard_png_renderer.py`** | Génère 1 PNG par scène | Non | Kamatera |
| **`whiteboard_ffmpeg_assembler.py`** | `SECONDS_PER_SCENE = 5` | ❌ **REMPLACE** `duration_ms` | Kamatera / FFmpeg |
| **RPC `whiteboard_mark_done`** | `duration_ms = len(scenes) * 5000` | ❌ **FAUX** | Kamatera |
| **Supabase `whiteboard_renders.duration_ms`** | Valeur erronée (ex. 45000 ms pour 9 scènes) | ❌ Utilisée par Flutter mais incorrecte | Supabase |

### Détail des points de rupture

1. **Edge Function → Storyboard** : OK. `duration_ms` est généré et validé.
2. **Storyboard → Supabase** : OK. Stocké dans `storyboard_json`.
3. **Supabase → Worker** : OK. `whiteboard_fetch_queued_jobs` retourne `storyboard_json`.
4. **Worker → Assembler** : RUPTURE. Le worker appelle `assemble_pngs_to_mp4(png_paths, temp_path)` sans passer les durées.
5. **Assembler** : RUPTURE. `SECONDS_PER_SCENE = 5` ignore totalement les `duration_ms`.
6. **Worker → mark_done** : RUPTURE. `duration_ms = len(scenes) * 5000` est faux.

---

## PHASE 4 — RESPONSABILITÉ FINALE

### 1. Qui est responsable du découpage pédagogique ?

**L'IA (Edge Function `whiteboard-generate-storyboard`).**  
Le prompt définit la structure pédagogique et le nombre de scènes. Flutter permet ensuite l'édition (ajout/suppression de blocs, modification de texte), mais pas encore de réorganiser les scènes de manière avancée.

### 2. Qui doit déterminer la durée initiale d'une scène ?

**L'IA, dans le storyboard JSON.**  
L'IA est la mieux placée pour estimer la durée en fonction du contenu (nombre de blocs, complexité, type de bloc). Les données réelles montrent qu'elle produit déjà des durées variées et cohérentes (scènes denses = plus longues).

### 3. Qui doit ajuster la durée finale lorsqu'un TTS existe ?

**Le worker/renderer, à partir de la durée audio TTS réelle.**  
L'industrie (CapCut, Canva) synchronise la narration sur la timeline. La durée de la scène doit donc être recalculée à partir de la longueur de l'audio TTS, éventuellement avec une marge visuelle. L'IA fournit une estimation, le TTS fournit la vérité.

### 4. FFmpeg doit-il utiliser `SECONDS_PER_SCENE = 5` ou respecter `duration_ms` ?

**B) Respecter strictement `duration_ms` du storyboard.**

**Justification :**
- Aucune plateforme industrielle majeure n'utilise de durée hardcodée par scène.
- Canva, Explain Everything, CapCut utilisent la durée explicite de la scène/timeline.
- `duration_ms` est déjà généré, stocké, validé et retourné au worker. Le seul composant qui l'ignore est l'assembleur FFmpeg.
- Le hardcodage de 5s est une simplification temporaire de la Phase C.3 (commentaire dans D25).

---

## PHASE 5 — PLAN DE CORRECTION D31.1

**Aucune modification appliquée dans cette mission.**

| ID | Correction | Fichier | Responsable | Impact | Temps estimé |
|---|---|---|---|---|---|
| **C1** | Passer les durées des scènes au `assemble_pngs_to_mp4` | `whiteboard_render_worker.py` | Kamatera | Worker transmet les `duration_ms` | 15 min |
| **C2** | Utiliser `duration_ms` dans `concat.txt` au lieu de `SECONDS_PER_SCENE` | `whiteboard_ffmpeg_assembler.py` | Kamatera | MP4 avec durée correcte | 20 min |
| **C3** | Supprimer `SECONDS_PER_SCENE = 5` (ou le rendre fallback) | `whiteboard_ffmpeg_assembler.py` | Kamatera | Élimine le hardcodage | 10 min |
| **C4** | Corriger `duration_ms` retournée à `whiteboard_mark_done` | `whiteboard_render_worker.py` | Kamatera | DB reflète la vraie durée | 10 min |
| **C5** | Mettre à jour la preview Flutter pour utiliser `duration_ms` du storyboard si besoin | `smart_whiteboard_preview_screen.dart` (optionnel) | Flutter | Affichage cohérent avant rendu | 20 min |
| **C6** | Test end-to-end : storyboard 69s → MP4 69s | Device + Kamatera | QA | Validation | 30 min |

### Dépendances

```
C1 → C2 → C3
C2 → C4
C6 dépend de C2+C4
```

### Implémentation suggérée (non appliquée)

**Dans `whiteboard_render_worker.py` :**
```python
scenes = storyboard.get("scenes", [])
durations_ms = [s.get("duration_ms", 5000) for s in scenes]
mp4_path = assemble_pngs_to_mp4(png_paths, durations_ms, temp_path)
total_duration_ms = sum(durations_ms)
await _mark_job_done(job_id, video_url, total_duration_ms)
```

**Dans `whiteboard_ffmpeg_assembler.py` :**
```python
def assemble_pngs_to_mp4(png_paths: List[Path], durations_ms: List[int], output_dir: Path) -> Path:
    ...
    with open(concat_file, "w") as f:
        for p, d in zip(png_paths, durations_ms):
            safe = str(p).replace("'", "'\\''")
            f.write(f"file '{safe}'\n")
            f.write(f"duration {d / 1000.0}\n")
        last = str(png_paths[-1]).replace("'", "'\\''")
        f.write(f"file '{last}'\n")
```

---

## PHASE 6 — VERDICT FINAL

### 1. Le vrai responsable des durées est-il l'IA, le TTS ou FFmpeg ?

- **Durée initiale :** l'IA.
- **Durée finale (avec TTS) :** le TTS.
- **Exécution de la durée :** FFmpeg (mais il ne doit **jamais** décider lui-même).

Actuellement, FFmpeg a pris la place de l'IA/TTS via `SECONDS_PER_SCENE = 5`. C'est une inversion des responsabilités.

### 2. Le découpage pédagogique actuel est-il cohérent ?

**OUI.** Les storyboards réels montrent une structure pédagogique logique (Introduction, Définition, Formule, Exemple, Exercice, Correction) avec des durées adaptées à la complexité.

### 3. Les `duration_ms` existants sont-ils déjà exploitables ?

**OUI.** Les valeurs sont variées (6000–15000 ms), validées par l'Edge Function, stockées en JSONB, et retournées au worker via `whiteboard_fetch_queued_jobs`. Seul l'assembleur FFmpeg les ignore.

### 4. Quelle est la première correction à faire avant toute implémentation TTS ?

**Respecter `duration_ms` du storyboard dans `whiteboard_ffmpeg_assembler.py`.**

Tant que la durée est hardcodée à 5s, même un TTS parfait serait désynchronisé. La correction D31.1 (C1-C4) est le **pré-requis absolu** à toute narration audio.

---

## PREUVES TECHNIQUES

### Prompt IA avec `duration_ms` en exemple

```ts
@supabase/functions/whiteboard-generate-storyboard/index.ts:238
"duration_ms": 5000,
```

### Validation obligatoire de `duration_ms`

```ts
@supabase/functions/whiteboard-generate-storyboard/index.ts:136
const sceneRequired = ['id', 'order', 'title', 'duration_ms', 'blocks'];
```

### Hardcodage FFmpeg

```python
@.windsurf/kamatera_snapshot/whiteboard_ffmpeg_assembler.py:18
SECONDS_PER_SCENE = 5
```

### Worker qui ignore les durées

```python
@.windsurf/kamatera_snapshot/whiteboard_render_worker.py:135-139
storyboard = storyboard_json if isinstance(storyboard_json, dict) else {}
scenes = storyboard.get("scenes", [])
duration_ms = len(scenes) * 5000
```

### Storyboards réels avec durées variées

Fichier : `.windsurf/MISSION_D31_1_duration_audit_output.json`

Exemple :
```json
{
  "project_id": "da5fc34c-384d-48f0-8e54-8d6eb8e06928",
  "subject": "primitive d'une fonction",
  "num_scenes": 8,
  "durations_ms": [8000, 10000, 9000, 12000, 15000, 10000, 12000, 7000],
  "total_duration_ms": 83000
}
```

### RPC retournant le storyboard au worker

Fichier : `.windsurf/MISSION_D31_1_rpc_audit_output.json`

```sql
SELECT wr.id, wr.project_id, wr.status, wr.created_at, wr.storyboard_json
FROM app.whiteboard_renders wr
JOIN app.whiteboard_projects wp ON wr.project_id = wp.id
WHERE wr.status = 'queued'
ORDER BY wr.created_at ASC
LIMIT p_limit;
```

---

**MISSION D31.1 CLÔTURÉE**  
Harmonisation des durées effectuée. Responsabilités identifiées. Plan de correction D31.1 produit. Aucune modification appliquée.
