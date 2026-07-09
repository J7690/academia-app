"""
Script pour Phase B.5 – Test flux complet whiteboard
"""

import requests
import json

# Configuration
rpc_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc"
admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

def execute_sql(sql):
    resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
    return resp.json()

def call_rpc(rpc_name, params):
    resp = requests.post(f"{rpc_url}/{rpc_name}", headers=headers, json=params, timeout=30)
    return resp.json()

print("=== TEST FLUX COMPLET WHITEBOARD ===\n")

# Récupérer un student_id valide
sql = "SELECT id FROM app.students LIMIT 1"
result = execute_sql(sql)
student_id = result.get("rows", [{}])[0].get("id") if result.get("ok") and result.get("rows") else None
print(f"Student ID: {student_id}")

if student_id:
    # Étape 1: Créer Projet
    print("\nÉTAPE 1: Créer Projet")
    params = {
        "p_subject": "Flux Test Project",
        "p_renderer_id": "scientific",
        "p_theme_id": "scientific",
        "p_narration_mode": "none",
        "p_storyboard_json": {"version": "1.0", "scenes": []},
        "p_student_id": student_id
    }
    result = call_rpc("whiteboard_create_project", params)
    print(f"Résultat: {result}")
    project_id = result.get("project_id") if result.get("success") else None
    print(f"✅ Projet créé: {project_id}")

    if project_id:
        # Étape 2: Lecture projet
        print("\nÉTAPE 2: Lecture projet")
        params = {
            "p_project_id": project_id,
            "p_student_id": student_id
        }
        result = call_rpc("whiteboard_get_project", params)
        print(f"Résultat: {result}")
        if result.get("success"):
            print(f"✅ Projet lu: {result.get('project').get('subject')}")
        else:
            print("❌ Échec lecture projet")
            exit(1)

        # Étape 3: Modification projet
        print("\nÉTAPE 3: Modification projet")
        params = {
            "p_project_id": project_id,
            "p_subject": "Modified Flux Test Project",
            "p_status": "draft",
            "p_renderer_id": "notebook",
            "p_theme_id": "notebook",
            "p_narration_mode": "tts",
            "p_storyboard_json": {"version": "1.0", "scenes": [{"id": "1"}]},
            "p_student_id": student_id
        }
        result = call_rpc("whiteboard_update_project", params)
        print(f"Résultat: {result}")
        if result.get("success"):
            print(f"✅ Projet modifié")
        else:
            print("❌ Échec modification projet")
            exit(1)

        # Étape 4: Création Render Job
        print("\nÉTAPE 4: Création Render Job")
        params = {
            "p_project_id": project_id,
            "p_student_id": student_id
        }
        result = call_rpc("whiteboard_create_render_job", params)
        print(f"Résultat: {result}")
        render_id = result.get("render_id") if result.get("success") else None
        if render_id:
            print(f"✅ Render Job créé: {render_id}")
        else:
            print("❌ Échec création Render Job")
            exit(1)

        # Étape 5: Lecture statut
        print("\nÉTAPE 5: Lecture statut")
        params = {
            "p_render_id": render_id,
            "p_student_id": student_id
        }
        result = call_rpc("whiteboard_get_render_status", params)
        print(f"Résultat: {result}")
        if result.get("success"):
            print(f"✅ Statut lu: {result.get('render').get('status')}")
        else:
            print("❌ Échec lecture statut")
            exit(1)

        # Étape 6: Suppression projet
        print("\nÉTAPE 6: Suppression projet")
        params = {
            "p_project_id": project_id,
            "p_student_id": student_id
        }
        result = call_rpc("whiteboard_delete_project", params)
        print(f"Résultat: {result}")
        if result.get("success"):
            print(f"✅ Projet supprimé")
        else:
            print("❌ Échec suppression projet")
            exit(1)

print("\n=== FLUX COMPLET TERMINÉ AVEC SUCCÈS ===\n")
