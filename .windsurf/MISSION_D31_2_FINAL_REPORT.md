# MISSION D31.2 — CORRECTION CONTRÔLÉE DE L'HARMONISATION DES DURÉES

**Date :** 2026-06-30  
**Statut :** ✅ TERMINÉE — correction appliquée et validée
**Périmètre :** Smart Whiteboard uniquement — aucun autre flow vidéo touché

---

## RÉSUMÉ EXÉCUTIF

La durée des vidéos Smart Whiteboard était hardcodée à 5 secondes par scène côté Kamatera, bien que l'IA générât des `duration_ms` variées dans le storyboard. Cette mission a corrigé l'assembleur FFmpeg et le worker pour que la durée du MP4 reflète exactement la somme des `duration_ms` du storyboard.

**Résultat :** 4 mesures identiques à 0 ms près sur le test réel "dérivés d'une fonction" (64 000 ms).

---

## PHASE 1 — TRAÇAGE COMPLET AVANT MODIFICATION

Livrable : `D31_2_duration_trace.md`

### Constat

| Étape | `duration_ms` présent ? | Utilisé ? | Responsable |
|---|---|---|---|
| Storyboard JSON | ✅ Oui | — | IA |
| `whiteboard_fetch_queued_jobs` | ✅ Oui (alias `storyboard`) | — | Supabase |
| `_process_single_job` | ✅ Oui | ❌ Non lu | Worker |
| `assemble_pngs_to_mp4` | ❌ Non reçu | ❌ Non | FFmpeg |
| `concat.txt` | ❌ Non | ❌ Remplacé par 5 | FFmpeg |
| `_mark_job_done` | ❌ Faux | ❌ Faux | Worker |

### Projet de test

- **Project ID :** `3993bb85-1818-407b-810e-4bcfe1b983fa`
- **Sujet :** dérivés d'une fonction
- **8 scènes** : 7000, 8000, 10000, 9000, 8000, 7000, 9000, 6000 ms
- **Total :** 64 000 ms

---

## PHASE 2 — CORRECTION MINIMALE

Livrable : `D31_2_ffmpeg_changes.md`

### Fichiers modifiés sur Kamatera

1. **`/opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py`**
   - Suppression de `SECONDS_PER_SCENE = 5`.
   - Ajout du paramètre `durations_ms`.
   - Utilisation des durées réelles dans `concat.txt`.
   - Suppression de la duplication de la dernière image.
   - Ajout de `-t total_duration_s` pour forcer la durée exacte.

2. **`/opt/whiteboard-worker/whiteboard_render_worker.py`**
   - Extraction de `duration_ms` depuis le storyboard.
   - Passage de `durations_ms` à l'assembleur.
   - Correction de `duration_ms` pour `whiteboard_mark_done` : `sum(duration_ms)` au lieu de `len(scenes) * 5000`.

### Gestion des régressions

- Fallback à 5s/scène si `durations_ms` absent ou invalide.
- API rétrocompatible : `assemble_pngs_to_mp4` accepte toujours 2 arguments.
- Backup timestampé sur Kamatera : `/opt/whiteboard-worker/backup_d31_2/`.

---

## PHASE 3 — CORRECTION DE `mark_done`

**Avant :**
```python
duration_ms = len(scenes) * 5000
```

**Après :**
```python
if durations_ms is not None:
    duration_ms = sum(durations_ms)
else:
    duration_ms = len(scenes) * 5000
```

**Résultat :** `whiteboard_renders.duration_ms` reflète la vraie durée du storyboard.

---

## PHASE 4 — REDÉMARRAGE CONTRÔLÉ

Livrable : `D31_2_worker_reload_proof.md`

| Étape | Valeur |
|---|---|
| PID avant | 526693 |
| PID après | 527612 |
| Pycache supprimé | ✅ |
| `systemctl restart whiteboard-worker` | ✅ |
| Nouveau code chargé | ✅ (SHA256 modifié) |
| Uptime processus | 8 secondes après redémarrage |

---

## PHASE 5 — TEST END-TO-END

Livrable : `D31_2_end_to_end_validation.md`

### Conditions

- **Sujet :** dérivés d'une fonction
- **Project ID :** `3993bb85-1818-407b-810e-4bcfe1b983fa`
- **Render job :** `4eb83d32-b476-4d3d-932e-32fc99f9569c`
- **Tolérance :** ±500 ms

### Résultats

| Source | Valeur | Statut |
|---|---|---|
| Storyboard (`duration_ms`) | 64 000 ms | Référence |
| Worker reçu | 64 000 ms | ✅ |
| MP4 réel (ffprobe) | 64 000 ms | ✅ |
| Supabase (`duration_ms`) | 64 000 ms | ✅ |

**Écart total : 0 ms.**

### Log worker (extrait)

```
Found 1 queued job(s)
Processing job 4eb83d32-b476-4d3d-932e-32fc99f9569c
Generating PNGs...
Assembling MP4...
Uploading MP4...
POST whiteboard_mark_done "HTTP/1.1 204 No Content"
Job completed successfully
```

---

## PHASE 6 — AUDIT INDUSTRIEL FINAL

Livrable : `D31_2_industry_compliance.md`

### Standard

**Storyboard → Timeline → Renderer**

- La durée est définie par le storyboard.
- FFmpeg est un exécutant, pas un décideur.
- Le TTS (futur) recalculera la durée finale.

### Comparaison

| Plateforme | Durée définie par | Conformité D31.2 |
|---|---|---|
| Canva Video | Timeline/scène | ✅ Equivalent |
| CapCut | Clip/TTS | ✅ Base storyboard prête |
| Explain Everything | Slide/timeline | ✅ Equivalent |
| Khan Academy | Monteur humain | ✅ Logique comparable |
| GoodNotes | N/A | N/A |

**Verdict :** Le pipeline est conforme au standard industriel de base. L'ajustement TTS final reste à implémenter (D31.5+).

---

## IMPACT ET RISQUES

| Aspect | Impact | Risque |
|---|---|---|
| Smart Whiteboard | ✅ Durée correcte | Aucun |
| Filmer / Importer / Feed | ❌ Aucun | Aucun (fichiers non touchés) |
| Compression existante | ❌ Aucun | Aucun |
| Rétrocompatibilité | ✅ Fallback 5s conservé | Faible |

---

## CORRECTIONS RESTANTES AVANT PRODUCTION

D31.2 résout la durée mais ne traite pas :

1. **TTS inexistant** (audio silencieux `anullsrc`).
2. **H.264 Level 3.1** sous-spécifié.
3. **Player Flutter** sans filtre MediaTek.
4. **Bitrate / qualité** très faible.
5. **Publication Challenge** non validée.

Ces points restent dans le plan D31.3+.

---

## LIVRABLES

- `D31_2_duration_trace.md`
- `D31_2_ffmpeg_changes.md`
- `D31_2_worker_reload_proof.md`
- `D31_2_end_to_end_validation.md`
- `D31_2_industry_compliance.md`
- `MISSION_D31_2_FINAL_REPORT.md` (ce fichier)

---

**MISSION D31.2 CLÔTURÉE**  
Correction appliquée, testée et conforme. Pipeline Smart Whiteboard prêt pour l'étape TTS.
