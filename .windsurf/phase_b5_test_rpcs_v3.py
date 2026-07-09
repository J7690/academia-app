"""
Script pour Phase B.5 – Tests des RPCs whiteboard v3 (via API REST)
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

print("=== TESTS RPCS WHITEBOARD V3 ===\n")

# Récupérer un student_id valide
sql = "SELECT id FROM app.students LIMIT 1"
result = execute_sql(sql)
student_id = result.get("rows", [{}])[0].get("id") if result.get("ok") and result.get("rows") else None
print(f"Student ID: {student_id}")

if student_id:
    # Test 1: create_project
    print("\nTEST 1: create_project")
    params = {
        "p_subject": "Test Project",
        "p_renderer_id": "scientific",
        "p_theme_id": "scientific",
        "p_narration_mode": "none",
        "p_storyboard_json": {"version": "1.0", "scenes": []},
        "p_student_id": student_id
    }
    result = call_rpc("whiteboard_create_project", params)
    print(f"Résultat: {result}")
    project_id = result.get("project_id") if result.get("success") else None
    print(f"Project ID: {project_id}")

    if project_id:
        # Test 2: get_project
        print("\nTEST 2: get_project")
        params = {
            "p_project_id": project_id,
            "p_student_id": student_id
        }
        result = call_rpc("whiteboard_get_project", params)
        print(f"Résultat: {result}")

        # Test 3: update_project
        print("\nTEST 3: update_project")
        params = {
            "p_project_id": project_id,
            "p_subject": "Updated Test Project",
            "p_status": "draft",
            "p_renderer_id": "notebook",
            "p_theme_id": "notebook",
            "p_narration_mode": "tts",
            "p_storyboard_json": {"version": "1.0", "scenes": [{"id": "1"}]},
            "p_student_id": student_id
        }
        result = call_rpc("whiteboard_update_project", params)
        print(f"Résultat: {result}")

        # Test 4: list_projects
        print("\nTEST 4: list_projects")
        params = {
            "p_status": None,
            "p_student_id": student_id
        }
        result = call_rpc("whiteboard_list_projects", params)
        print(f"Résultat: {result}")

        # Test 5: create_render_job
        print("\nTEST 5: create_render_job")
        params = {
            "p_project_id": project_id,
            "p_student_id": student_id
        }
        result = call_rpc("whiteboard_create_render_job", params)
        print(f"Résultat: {result}")
        render_id = result.get("render_id") if result.get("success") else None
        print(f"Render ID: {render_id}")

        # Test 6: get_render_status
        if render_id:
            print("\nTEST 6: get_render_status")
            params = {
                "p_render_id": render_id,
                "p_student_id": student_id
            }
            result = call_rpc("whiteboard_get_render_status", params)
            print(f"Résultat: {result}")

        # Test 7: delete_project
        print("\nTEST 7: delete_project")
        params = {
            "p_project_id": project_id,
            "p_student_id": student_id
        }
        result = call_rpc("whiteboard_delete_project", params)
        print(f"Résultat: {result}")

# Test 8: Test échec - create_project sans auth
print("\nTEST 8: create_project sans auth (échec attendu)")
params = {
    "p_subject": "Test Project",
    "p_renderer_id": "scientific",
    "p_theme_id": "scientific",
    "p_narration_mode": "none",
    "p_storyboard_json": {"version": "1.0", "scenes": []},
    "p_student_id": None
}
result = call_rpc("whiteboard_create_project", params)
print(f"Résultat: {result}")

# Test 9: Test échec - get_project non existant
print("\nTEST 9: get_project non existant (échec attendu)")
if student_id:
    params = {
        "p_project_id": "00000000-0000-0000-0000-000000000000",
        "p_student_id": student_id
    }
    result = call_rpc("whiteboard_get_project", params)
    print(f"Résultat: {result}")

# Test 10: Test échec - update_project non existant
print("\nTEST 10: update_project non existant (échec attendu)")
if student_id:
    params = {
        "p_project_id": "00000000-0000-0000-0000-000000000000",
        "p_subject": "Updated Test Project",
        "p_student_id": student_id
    }
    result = call_rpc("whiteboard_update_project", params)
    print(f"Résultat: {result}")

print("\n=== TESTS TERMINÉS ===\n")
