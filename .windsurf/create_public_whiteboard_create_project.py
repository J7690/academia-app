import requests

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/execute_ddl"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

def execute_ddl(ddl):
    resp = requests.post(admin_url, headers=headers, json={"ddl_query": ddl}, timeout=30)
    return resp.json()

print("=" * 80)
print("CRÉATION RPC PUBLIC whiteboard_create_project")
print("=" * 80)

# Créer la RPC dans le schéma public qui appelle la RPC du schéma app
ddl = """
CREATE OR REPLACE FUNCTION public.whiteboard_create_project(
  p_student_id UUID,
  p_subject VARCHAR,
  p_renderer_id VARCHAR,
  p_theme_id VARCHAR,
  p_narration_mode VARCHAR,
  p_storyboard_json JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN app.whiteboard_create_project(
    p_student_id,
    p_subject,
    p_renderer_id,
    p_theme_id,
    p_narration_mode,
    p_storyboard_json
  );
END;
$$;
"""

result = execute_ddl(ddl)
print(f"Résultat : {result}")

print("\n" + "=" * 80)
print("CRÉATION RPC PUBLIC whiteboard_list_projects")
print("=" * 80)

ddl2 = """
CREATE OR REPLACE FUNCTION public.whiteboard_list_projects(p_status VARCHAR DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN app.whiteboard_list_projects(p_status);
END;
$$;
"""

result2 = execute_ddl(ddl2)
print(f"Résultat : {result2}")

print("\n" + "=" * 80)
print("CRÉATION TERMINÉE")
print("=" * 80)
