import requests
import uuid

supabase_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=" * 80)
print("UTILISER PROJET EXISTANT POUR TEST")
print("=" * 80)

# Get existing project
sql_get_project = """
SELECT id, student_id, subject, status, renderer_id, theme_id, narration_mode, storyboard_json
FROM app.whiteboard_projects
ORDER BY created_at DESC
LIMIT 1;
"""

print(f"\n--- Récupération projet existant ---")
resp = requests.post(supabase_url, headers=headers, json={"p_sql": sql_get_project}, timeout=30)
data = resp.json()

print(f"STATUS: {resp.status_code}")

project_id = None
if data.get("ok") and data.get("rows"):
    print("✅ Projet trouvé:")
    for row in data["rows"]:
        project_id = row['id']
        print(f"  ID: {row['id']}")
        print(f"  Subject: {row['subject']}")
        print(f"  Status: {row['status']}")
        print(f"  Renderer ID: {row.get('renderer_id', 'N/A')}")
        print(f"  Theme ID: {row.get('theme_id', 'N/A')}")
        print(f"  Narration Mode: {row.get('narration_mode', 'N/A')}")
        print(f"  Has storyboard: {row.get('storyboard_json') is not None}")
else:
    print("❌ Aucun projet trouvé")
    exit(1)

# Create render job using existing project
render_id = str(uuid.uuid4())

sql_create_render = f"""
INSERT INTO app.whiteboard_renders (id, project_id, status)
VALUES ('{render_id}', '{project_id}', 'queued')
RETURNING id;
"""

print(f"\n--- Création render job ---")
print(f"Render ID: {render_id}")
print(f"Project ID: {project_id}")

resp = requests.post(supabase_url, headers=headers, json={"p_sql": sql_create_render}, timeout=30)
data = resp.json()

print(f"STATUS: {resp.status_code}")
print(f"BODY: {resp.text}")

if data.get("ok"):
    print("✅ Render job créé")
    print(f"\n✅ Job test créé avec succès")
    print(f"   Project ID: {project_id}")
    print(f"   Render ID: {render_id}")
    print(f"   Worker traitera ce job automatiquement")
else:
    print("❌ Erreur création render job")

print("\n" + "=" * 80)
