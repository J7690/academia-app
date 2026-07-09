"""
Script pour Phase B.5 – Tests des RPCs whiteboard v2 (avec p_student_id)
"""

import requests
import json

# Configuration
url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

def execute_sql(sql):
    resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
    return resp.json()

print("=== TESTS RPCS WHITEBOARD V2 ===\n")

# Récupérer un student_id valide
sql = "SELECT id FROM app.students LIMIT 1"
result = execute_sql(sql)
student_id = result.get("rows", [{}])[0].get("id") if result.get("ok") and result.get("rows") else None
print(f"Student ID: {student_id}")

if student_id:
    # Test 1: create_project
    print("\nTEST 1: create_project")
    sql = f"""
    SELECT * FROM app.whiteboard_create_project(
      'Test Project',
      'scientific',
      'scientific',
      'none',
      '{{"version":"1.0","scenes":[]}}'::jsonb,
      '{student_id}'::uuid
    )
    """
    result = execute_sql(sql)
    print(f"Résultat: {result}")
    project_id = result.get("rows", [{}])[0].get("project_id") if result.get("ok") and result.get("rows") else None
    print(f"Project ID: {project_id}")

    if project_id:
        # Test 2: get_project
        print("\nTEST 2: get_project")
        sql = f"SELECT * FROM app.whiteboard_get_project('{project_id}'::uuid, '{student_id}'::uuid)"
        result = execute_sql(sql)
        print(f"Résultat: {result}")

        # Test 3: update_project
        print("\nTEST 3: update_project")
        sql = f"""
        SELECT * FROM app.whiteboard_update_project(
          '{project_id}'::uuid,
          'Updated Test Project',
          'draft',
          'notebook',
          'notebook',
          'tts',
          '{{"version":"1.0","scenes":[{{"id":"1"}}]}}'::jsonb,
          '{student_id}'::uuid
        )
        """
        result = execute_sql(sql)
        print(f"Résultat: {result}")

        # Test 4: list_projects
        print("\nTEST 4: list_projects")
        sql = f"SELECT * FROM app.whiteboard_list_projects(NULL, '{student_id}'::uuid)"
        result = execute_sql(sql)
        print(f"Résultat: {result}")

        # Test 5: create_render_job
        print("\nTEST 5: create_render_job")
        sql = f"SELECT * FROM app.whiteboard_create_render_job('{project_id}'::uuid, '{student_id}'::uuid)"
        result = execute_sql(sql)
        print(f"Résultat: {result}")
        render_id = result.get("rows", [{}])[0].get("render_id") if result.get("ok") and result.get("rows") else None
        print(f"Render ID: {render_id}")

        # Test 6: get_render_status
        if render_id:
            print("\nTEST 6: get_render_status")
            sql = f"SELECT * FROM app.whiteboard_get_render_status('{render_id}'::uuid, '{student_id}'::uuid)"
            result = execute_sql(sql)
            print(f"Résultat: {result}")

        # Test 7: delete_project
        print("\nTEST 7: delete_project")
        sql = f"SELECT * FROM app.whiteboard_delete_project('{project_id}'::uuid, '{student_id}'::uuid)"
        result = execute_sql(sql)
        print(f"Résultat: {result}")

# Test 8: Test échec - create_project sans auth
print("\nTEST 8: create_project sans auth (échec attendu)")
sql = """
SELECT * FROM app.whiteboard_create_project(
  'Test Project',
  'scientific',
  'scientific',
  'none',
  '{"version":"1.0","scenes":[]}'::jsonb,
  NULL
)
"""
result = execute_sql(sql)
print(f"Résultat: {result}")

# Test 9: Test échec - get_project non existant
print("\nTEST 9: get_project non existant (échec attendu)")
if student_id:
    sql = f"SELECT * FROM app.whiteboard_get_project('00000000-0000-0000-0000-000000000000'::uuid, '{student_id}'::uuid)"
    result = execute_sql(sql)
    print(f"Résultat: {result}")

# Test 10: Test échec - update_project non existant
print("\nTEST 10: update_project non existant (échec attendu)")
if student_id:
    sql = f"""
    SELECT * FROM app.whiteboard_update_project(
      '00000000-0000-0000-0000-000000000000'::uuid,
      'Updated Test Project',
      NULL,
      NULL,
      NULL,
      NULL,
      NULL,
      '{student_id}'::uuid
    )
    """
    result = execute_sql(sql)
    print(f"Résultat: {result}")

print("\n=== TESTS TERMINÉS ===\n")
