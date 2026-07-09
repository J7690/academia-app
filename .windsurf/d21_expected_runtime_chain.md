# D.21 – PHASE 2 : CHAÎNE D'EXÉCUTION RUNTIME ATTENDUE

**Date** : 2026-06-28  
**Mission** : D.21 – Audit runtime ground truth  
**Sources** : ACADEMIA_TECHNICAL_CONSTITUTION.md, ACADEMIA_ARCHITECTURE_DECISIONS.md, SMART_WHITEBOARD_DATA_CONTRACT.md, PHASE_C3J_REAL_PIPELINE_SUCCESS.md

---

## CHAÎNE COMPLÈTE ATTENDUE

```
[FLUTTER – InputScreen]
  Saisie : subject (string), renderer, theme, narration_mode
  Validation : subject.isNotEmpty
  Action : provider.createProject(subject, rendererId, themeId, narrationMode)
    │
    ▼
[FLUTTER – SmartWhiteboardProvider.createProject()]
  Appel : SmartWhiteboardService.createProject(...)
  Paramètres : {p_student_id: auth.currentUser.id, p_subject: subject, ...}
    │
    ▼
[SUPABASE – RPC whiteboard_create_project]
  Schéma : public
  Action : INSERT INTO app.whiteboard_projects
  Retour : {success: true, project_id: UUID}
  ← HTTP 200
    │
    ▼
[FLUTTER – Provider]
  _currentProjectId = UUID
  _currentProject = WhiteboardProject(id, subject, rendererId, themeId, ...)
  État → idle
  Action : provider.generateStoryboard(mode, content)
    │
    ▼
[FLUTTER – SmartWhiteboardProvider.generateStoryboard()]
  userId = client.auth.currentUser.id (non-null)
  Payload :
    {
      mode: "simple_subject",
      subject: _currentProject.subject,    ← doit être le vrai sujet
      content: content,
      renderer: _currentProject.rendererId,
      theme: _currentProject.themeId,
      narration_mode: _currentProject.narrationMode
    }
  Appel : client.functions.invoke('whiteboard-generate-storyboard', body: payload)
  JWT utilisateur : inclus automatiquement par supabase_flutter
    │
    ▼
[SUPABASE – Edge Function whiteboard-generate-storyboard]
  Auth : getUser(jwt) → user valide
  Vérification : crédits utilisateur ≥ 15
  Appel : OpenRouter API (LLM)
  Prompt : générer storyboard JSON pour le sujet donné
  Validation : JSON schema storyboard
  Sauvegarde : UPDATE app.whiteboard_projects SET storyboard_json = ...
  Retour : {success: true, storyboard_json: {...}}
  ← HTTP 200
    │
    ▼
[FLUTTER – Provider]
  data = response.data as Map<String, dynamic>
  storyboardJson = data['storyboard_json'] as Map<String, dynamic>
  _currentStoryboard = Storyboard.fromJson(storyboardJson)
  État → editing
    │
    ▼
[FLUTTER – InputScreen]
  Navigator.pushNamed('/smart-whiteboard-editor')
    │
    ▼
[FLUTTER – SmartWhiteboardStoryboardEditorScreen]
  Affichage du storyboard généré (scènes, blocs)
  Édition possible
  Bouton "Rendre"
    │
    ▼
[FLUTTER – SmartWhiteboardProvider.createRenderJob()]
  1. updateProject(storyboard.toJson())
     → RPC whiteboard_update_project
     → UPDATE app.whiteboard_projects SET storyboard_json = ...
     ← HTTP 200
  2. renderService.createRenderJob(projectId)
     → RPC whiteboard_create_render_job
     → INSERT INTO app.whiteboard_renders (status='queued')
     ← HTTP 200 {success: true, render_id: UUID}
  _currentRenderJobId = UUID
  État → rendering
    │
    ▼
[FLUTTER – SmartWhiteboardProvider.pollRenderJob()]
  Loop : renderService.waitForRenderCompletion(renderId)
    → Poll RPC whiteboard_get_render_status toutes 5s
    → HTTP 200 {success: true, render: {status: "queued|processing|done|failed", ...}}
    │
    ├─ status == "done" → _renderVideoUrl = render['video_url'] → État done
    └─ status == "failed" → _setError(render['error_message'])
    │
    ▼
[KAMATERA – whiteboard_render_worker.py (PID 395272)]
  Poll : POST /rpc/whiteboard_fetch_queued_jobs (toutes 2s)
  ← HTTP 200 [{id, storyboard, created_at}, ...]
    │
  [Si job trouvé]
    │
    ▼
  POST /rpc/whiteboard_mark_processing(job_id)
  ← HTTP 204
    │
    ▼
  render_storyboard_to_pngs(storyboard_json)
  → whiteboard_png_renderer.py (Pillow)
  → PNG files : scene_001.png, scene_002.png, ...
  ← List[Path]
    │
    ▼
  assemble_pngs_to_mp4(png_paths, output_dir)
  → whiteboard_ffmpeg_assembler.py (FFmpeg H.264)
  → output.mp4
  ← Path
    │
    ▼
  upload_mp4_to_storage(mp4_path, render_id)
  → whiteboard_upload_renderer.py (httpx)
  → PUT /storage/v1/object/whiteboard-renders/renders/{render_id}/{uuid}.mp4
  ← HTTP 200 {video_url: "https://...mp4"}
    │
    ▼
  POST /rpc/whiteboard_mark_done(job_id, video_url, duration_ms)
  ← HTTP 204
    │
    ▼
[FLUTTER – pollRenderJob()]
  status == "done"
  _renderVideoUrl = video_url
  État → done
    │
    ▼
[FLUTTER – SmartWhiteboardPreviewScreen]
  Affichage MP4 via video_player
  URL : https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/whiteboard-renders/...
```

---

## CONTRATS DE DONNÉES ATTENDUS

### whiteboard_create_project

**Input** :
```json
{
  "p_student_id": "UUID",
  "p_subject": "string (non-vide)",
  "p_renderer_id": "scientific|notebook",
  "p_theme_id": "scientific|notebook",
  "p_narration_mode": "none|tts|user_recording",
  "p_storyboard_json": {}
}
```

**Output attendu** :
```json
{"success": true, "project_id": "UUID"}
```

### whiteboard-generate-storyboard

**Input** :
```json
{
  "mode": "simple_subject|full_text|plan|existing_course",
  "subject": "string (non-vide)",
  "content": "string",
  "renderer": "scientific|notebook",
  "theme": "scientific|notebook",
  "narration_mode": "none|tts|user_recording"
}
```

**Output attendu** :
```json
{
  "success": true,
  "storyboard_json": {
    "version": "1.0",
    "subject": "...",
    "renderer": "...",
    "theme": "...",
    "scenes": [
      {
        "id": "...",
        "order": 1,
        "title": "...",
        "duration_ms": 5000,
        "blocks": [...]
      }
    ]
  }
}
```

### whiteboard_get_render_status

**Input** :
```json
{"p_render_id": "UUID"}
```

**Output attendu** :
```json
{
  "success": true,
  "render": {
    "id": "UUID",
    "status": "queued|processing|done|failed",
    "video_url": "https://...mp4",
    "duration_ms": 12000,
    "error_message": null
  }
}
```

---

**DOCUMENT CLÔTURÉ**
