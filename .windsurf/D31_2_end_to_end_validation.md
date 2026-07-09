# D31_2_end_to_end_validation.md

**Date :** 2026-06-30T18:07:46Z
**Render job :** `4eb83d32-b476-4d3d-932e-32fc99f9569c`
**Project :** `3993bb85-1818-407b-810e-4bcfe1b983fa`
**Sujet :** dérivés d'une fonction

---

## 1. `duration_ms` total du storyboard

**64000 ms** (64.0 s) — 8 scènes

| Scène | Titre | `duration_ms` |
|---|---|---|
| 1 | Introduction aux Dérivées | 7000 |
| 2 | Qu'est-ce qu'une dérivée ? | 8000 |
| 3 | Définition Formelle | 10000 |
| 4 | Exemples de Dérivées Simples | 9000 |
| 5 | Application Concrète | 8000 |
| 6 | Exercice d'Application | 7000 |
| 7 | Correction de l'Exercice | 9000 |
| 8 | Conclusion | 6000 |

---

## 2. `duration_ms` total envoyé au worker (via `storyboard_json`)

**64000 ms**

Le worker lit `wp.storyboard_json` via `whiteboard_fetch_queued_jobs`.

---

## 3. Durée réelle du MP4 (ffprobe)

Commande : `ffprobe -v error -show_entries format=duration -of csv=p=0 /tmp/d31_2_test_4eb83d32-b476-4d3d-932e-32fc99f9569c.mp4`

Résultat : **64000 ms** (64.000 s)

---

## 4. `duration_ms` enregistrée dans Supabase

**64000 ms**

---

## 5. Tableau de cohérence

| Source | Valeur (ms) | Tolérance | Statut |
|---|---|---|---|
| Storyboard | 64000 | — | référence |
| Worker reçu | 64000 | — | ✅ identique |
| MP4 ffprobe | 64000 | ±500 ms | ✅ OK |
| Supabase DB | 64000 | ±500 ms | ✅ OK |

---

## 6. Worker log (extrait)

```
doybfvgs.supabase.co/rest/v1/rpc/whiteboard_fetch_queued_jobs "HTTP/1.1 200 OK"
Jun 30 18:07:23 academia00 python3[527612]: INFO:whiteboard_render_worker:[whiteboard_render_worker] Found 0 queued job(s)
Jun 30 18:07:25 academia00 python3[527612]: INFO:httpx:HTTP Request: POST https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/whiteboard_fetch_queued_jobs "HTTP/1.1 200 OK"
Jun 30 18:07:25 academia00 python3[527612]: INFO:whiteboard_render_worker:[whiteboard_render_worker] Found 1 queued job(s)
Jun 30 18:07:25 academia00 python3[527612]: INFO:httpx:HTTP Request: POST https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/whiteboard_mark_processing "HTTP/1.1 204 No Content"
Jun 30 18:07:25 academia00 python3[527612]: INFO:whiteboard_render_worker:[whiteboard_render_worker] Processing job 4eb83d32-b476-4d3d-932e-32fc99f9569c
Jun 30 18:07:25 academia00 python3[527612]: INFO:whiteboard_render_worker:[whiteboard_render_worker] Generating PNGs for job 4eb83d32-b476-4d3d-932e-32fc99f9569c
Jun 30 18:07:25 academia00 python3[527612]: INFO:whiteboard_render_worker:[whiteboard_render_worker] Assembling MP4 for job 4eb83d32-b476-4d3d-932e-32fc99f9569c
Jun 30 18:07:42 academia00 python3[527612]: INFO:whiteboard_render_worker:[whiteboard_render_worker] Uploading MP4 for job 4eb83d32-b476-4d3d-932e-32fc99f9569c
Jun 30 18:07:42 academia00 python3[527612]: INFO:httpx:HTTP Request: PUT https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/whiteboard-renders/renders/4eb83d32-b476-4d3d-932e-32fc99f9569c/072458be96bc421d9caf056543ea03dd.mp4 "HTTP/1.1 200 OK"
Jun 30 18:07:42 academia00 python3[527612]: INFO:httpx:HTTP Request: POST https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/whiteboard_mark_done "HTTP/1.1 204 No Content"
Jun 30 18:07:42 academia00 python3[527612]: INFO:whiteboard_render_worker:[whiteboard_render_worker] Job 4eb83d32-b476-4d3d-932e-32fc99f9569c completed successfully
Jun 30 18:07:44 academia00 python3[527612]: INFO:httpx:HTTP Request: POST https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/whiteboard_fetch_queued_jobs "HTTP/1.1 200 OK"
Jun 30 18:07:44 academia00 python3[527612]: INFO:whiteboard_render_worker:[whiteboard_render_worker] Found 0 queued job(s)
Jun 30 18:07:46 academia00 python3[527612]: INFO:httpx:HTTP Request: POST https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/whiteboard_fetch_queued_jobs "HTTP/1.1 200 OK"
Jun 30 18:07:46 academia00 python3[527612]: INFO:whiteboard_render_worker:[whiteboard_render_worker] Found 0 queued job(s)

```

---

## 7. Conclusion

**✅ Toutes les durées sont cohérentes dans la tolérance de ±500 ms.**
