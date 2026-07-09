"""
Phase C.3G – Create Render Job
Crée un RenderJob réel avec status=queued
"""

import requests
import uuid

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

def execute_sql(sql):
    resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
    return resp.json()

print("=== PHASE C.3G – CRÉATION RENDER JOB ===\n")

# Créer un project avec Storyboard minimal
project_id = str(uuid.uuid4())
student_id = "c63e9c1e-92d9-43f3-ab41-066ec3dc788b"
storyboard_json = """
{
  "version": "1.0",
  "created_at": "2026-06-23T18:00:00Z",
  "created_by": "c63e9c1e-92d9-43f3-ab41-066ec3dc788b",
  "subject": "Test Pipeline",
  "renderer": "scientific",
  "theme": "scientific",
  "narration_mode": "none",
  "export_settings": {
    "format": "mp4",
    "resolution": {
      "width": 1080,
      "height": 1920
    },
    "frame_rate": 30,
    "video_codec": "h264",
    "audio_codec": "aac"
  },
  "scenes": [
    {
      "id": "scene-1",
      "order": 0,
      "title": "Titre Test",
      "duration_ms": 5000,
      "blocks": [
        {
          "id": "block-1",
          "type": "title",
          "content": "Test Pipeline Smart Whiteboard",
          "order": 0,
          "visible": true,
          "style": {
            "font_size": 48,
            "font_weight": "bold",
            "color": "#000000"
          }
        }
      ]
    },
    {
      "id": "scene-2",
      "order": 1,
      "title": "Paragraphe Test",
      "duration_ms": 5000,
      "blocks": [
        {
          "id": "block-2",
          "type": "paragraph",
          "content": "Ceci est un test de validation du pipeline Smart Whiteboard.",
          "order": 0,
          "visible": true,
          "style": {
            "font_size": 24,
            "color": "#333333"
          }
        }
      ]
    }
  ]
}
"""

sql = f"""
INSERT INTO app.whiteboard_projects (id, student_id, subject, status, renderer_id, theme_id, narration_mode, storyboard_json)
VALUES ('{project_id}', '{student_id}', 'Test Pipeline', 'completed', 'scientific', 'scientific', 'none', '{storyboard_json}'::jsonb);
"""
result = execute_sql(sql)
print(f"Création project : {result}")
print(f"Project ID : {project_id}")
print()

# Créer un render job avec status=queued
render_id = str(uuid.uuid4())
sql = f"""
INSERT INTO app.whiteboard_renders (id, project_id, status)
VALUES ('{render_id}', '{project_id}', 'queued');
"""
result = execute_sql(sql)
print(f"Création render job : {result}")
print(f"Render ID : {render_id}")
print()

print("=== RENDER JOB CRÉÉ ===")
print(f"Project ID : {project_id}")
print(f"Render ID : {render_id}")
print()
