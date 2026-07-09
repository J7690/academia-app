"""
Script pour Phase B.5 – Création des RLS policies whiteboard
"""

import requests

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

print("=== CRÉATION RLS POLICIES WHITEBOARD ===\n")

# RLS policies pour whiteboard_projects
print("RLS policies whiteboard_projects:")

# SELECT - Étudiant (propriétaire)
sql = """
CREATE POLICY whiteboard_projects_select_student 
ON app.whiteboard_projects FOR SELECT 
USING (auth.uid() = student_id)
"""
result = execute_sql(sql)
print(f"  SELECT student: {result}")

# INSERT - Étudiant (propriétaire)
sql = """
CREATE POLICY whiteboard_projects_insert_student 
ON app.whiteboard_projects FOR INSERT 
WITH CHECK (auth.uid() = student_id)
"""
result = execute_sql(sql)
print(f"  INSERT student: {result}")

# UPDATE - Étudiant (propriétaire)
sql = """
CREATE POLICY whiteboard_projects_update_student 
ON app.whiteboard_projects FOR UPDATE 
USING (auth.uid() = student_id)
"""
result = execute_sql(sql)
print(f"  UPDATE student: {result}")

# DELETE - Étudiant (propriétaire)
sql = """
CREATE POLICY whiteboard_projects_delete_student 
ON app.whiteboard_projects FOR DELETE 
USING (auth.uid() = student_id)
"""
result = execute_sql(sql)
print(f"  DELETE student: {result}")

# Service role - accès complet
sql = """
CREATE POLICY whiteboard_projects_service_role 
ON app.whiteboard_projects FOR ALL 
USING (auth.role() = 'service_role')
"""
result = execute_sql(sql)
print(f"  Service role: {result}")

# RLS policies pour whiteboard_renders
print("\nRLS policies whiteboard_renders:")

# SELECT - Étudiant (via project_id)
sql = """
CREATE POLICY whiteboard_renders_select_student 
ON app.whiteboard_renders FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM app.whiteboard_projects wp
    WHERE wp.id = whiteboard_renders.project_id
      AND wp.student_id = auth.uid()
  )
)
"""
result = execute_sql(sql)
print(f"  SELECT student: {result}")

# INSERT - Étudiant (via project_id)
sql = """
CREATE POLICY whiteboard_renders_insert_student 
ON app.whiteboard_renders FOR INSERT 
WITH CHECK (
  EXISTS (
    SELECT 1 FROM app.whiteboard_projects wp
    WHERE wp.id = whiteboard_renders.project_id
      AND wp.student_id = auth.uid()
  )
)
"""
result = execute_sql(sql)
print(f"  INSERT student: {result}")

# UPDATE - Étudiant (via project_id)
sql = """
CREATE POLICY whiteboard_renders_update_student 
ON app.whiteboard_renders FOR UPDATE 
USING (
  EXISTS (
    SELECT 1 FROM app.whiteboard_projects wp
    WHERE wp.id = whiteboard_renders.project_id
      AND wp.student_id = auth.uid()
  )
)
"""
result = execute_sql(sql)
print(f"  UPDATE student: {result}")

# DELETE - Étudiant (via project_id)
sql = """
CREATE POLICY whiteboard_renders_delete_student 
ON app.whiteboard_renders FOR DELETE 
USING (
  EXISTS (
    SELECT 1 FROM app.whiteboard_projects wp
    WHERE wp.id = whiteboard_renders.project_id
      AND wp.student_id = auth.uid()
  )
)
"""
result = execute_sql(sql)
print(f"  DELETE student: {result}")

# Service role - accès complet
sql = """
CREATE POLICY whiteboard_renders_service_role 
ON app.whiteboard_renders FOR ALL 
USING (auth.role() = 'service_role')
"""
result = execute_sql(sql)
print(f"  Service role: {result}")

print("\n=== CRÉATION RLS POLICIES TERMINÉE ===\n")
