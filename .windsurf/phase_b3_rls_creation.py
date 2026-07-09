"""
Script RPC administrateur pour Phase B.3 – RLS Security
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

print("=== ÉTAPE 1 : ACTIVATION RLS ===\n")

sql = "ALTER TABLE app.whiteboard_projects ENABLE ROW LEVEL SECURITY"
result = execute_sql(sql)
print(f"RLS whiteboard_projects: {result}")

sql = "ALTER TABLE app.whiteboard_renders ENABLE ROW LEVEL SECURITY"
result = execute_sql(sql)
print(f"RLS whiteboard_renders: {result}")

print("\n=== ÉTAPE 2 : POLITIQUES whiteboard_projects ===\n")

# Politique SELECT pour étudiants
sql = """
CREATE POLICY whiteboard_projects_select_student 
ON app.whiteboard_projects FOR SELECT 
USING (auth.uid()::text = student_id::text)
"""
result = execute_sql(sql)
print(f"SELECT student: {result}")

# Politique INSERT pour étudiants
sql = """
CREATE POLICY whiteboard_projects_insert_student 
ON app.whiteboard_projects FOR INSERT 
WITH CHECK (auth.uid()::text = student_id::text)
"""
result = execute_sql(sql)
print(f"INSERT student: {result}")

# Politique UPDATE pour étudiants
sql = """
CREATE POLICY whiteboard_projects_update_student 
ON app.whiteboard_projects FOR UPDATE 
USING (auth.uid()::text = student_id::text)
"""
result = execute_sql(sql)
print(f"UPDATE student: {result}")

# Politique DELETE pour étudiants
sql = """
CREATE POLICY whiteboard_projects_delete_student 
ON app.whiteboard_projects FOR DELETE 
USING (auth.uid()::text = student_id::text)
"""
result = execute_sql(sql)
print(f"DELETE student: {result}")

# Politique SELECT pour admin
sql = """
CREATE POLICY whiteboard_projects_select_admin 
ON app.whiteboard_projects FOR SELECT 
USING (auth.jwt() ->> 'role' = 'admin')
"""
result = execute_sql(sql)
print(f"SELECT admin: {result}")

# Politique INSERT pour admin
sql = """
CREATE POLICY whiteboard_projects_insert_admin 
ON app.whiteboard_projects FOR INSERT 
WITH CHECK (auth.jwt() ->> 'role' = 'admin')
"""
result = execute_sql(sql)
print(f"INSERT admin: {result}")

# Politique UPDATE pour admin
sql = """
CREATE POLICY whiteboard_projects_update_admin 
ON app.whiteboard_projects FOR UPDATE 
USING (auth.jwt() ->> 'role' = 'admin')
"""
result = execute_sql(sql)
print(f"UPDATE admin: {result}")

# Politique DELETE pour admin
sql = """
CREATE POLICY whiteboard_projects_delete_admin 
ON app.whiteboard_projects FOR DELETE 
USING (auth.jwt() ->> 'role' = 'admin')
"""
result = execute_sql(sql)
print(f"DELETE admin: {result}")

# Politique SELECT pour service role
sql = """
CREATE POLICY whiteboard_projects_select_service_role 
ON app.whiteboard_projects FOR SELECT 
USING (auth.role() = 'service_role')
"""
result = execute_sql(sql)
print(f"SELECT service_role: {result}")

# Politique INSERT pour service role
sql = """
CREATE POLICY whiteboard_projects_insert_service_role 
ON app.whiteboard_projects FOR INSERT 
WITH CHECK (auth.role() = 'service_role')
"""
result = execute_sql(sql)
print(f"INSERT service_role: {result}")

# Politique UPDATE pour service role
sql = """
CREATE POLICY whiteboard_projects_update_service_role 
ON app.whiteboard_projects FOR UPDATE 
USING (auth.role() = 'service_role')
"""
result = execute_sql(sql)
print(f"UPDATE service_role: {result}")

# Politique DELETE pour service role
sql = """
CREATE POLICY whiteboard_projects_delete_service_role 
ON app.whiteboard_projects FOR DELETE 
USING (auth.role() = 'service_role')
"""
result = execute_sql(sql)
print(f"DELETE service_role: {result}")

print("\n=== ÉTAPE 3 : POLITIQUES whiteboard_renders ===\n")

# Politique SELECT pour propriétaire du projet (via FK)
sql = """
CREATE POLICY whiteboard_renders_select_owner 
ON app.whiteboard_renders FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM app.whiteboard_projects 
    WHERE whiteboard_projects.id = whiteboard_renders.project_id 
    AND whiteboard_projects.student_id::text = auth.uid()::text
  )
)
"""
result = execute_sql(sql)
print(f"SELECT owner: {result}")

# Politique INSERT pour propriétaire du projet
sql = """
CREATE POLICY whiteboard_renders_insert_owner 
ON app.whiteboard_renders FOR INSERT 
WITH CHECK (
  EXISTS (
    SELECT 1 FROM app.whiteboard_projects 
    WHERE whiteboard_projects.id = whiteboard_renders.project_id 
    AND whiteboard_projects.student_id::text = auth.uid()::text
  )
)
"""
result = execute_sql(sql)
print(f"INSERT owner: {result}")

# Politique UPDATE pour propriétaire du projet
sql = """
CREATE POLICY whiteboard_renders_update_owner 
ON app.whiteboard_renders FOR UPDATE 
USING (
  EXISTS (
    SELECT 1 FROM app.whiteboard_projects 
    WHERE whiteboard_projects.id = whiteboard_renders.project_id 
    AND whiteboard_projects.student_id::text = auth.uid()::text
  )
)
"""
result = execute_sql(sql)
print(f"UPDATE owner: {result}")

# Politique DELETE pour propriétaire du projet
sql = """
CREATE POLICY whiteboard_renders_delete_owner 
ON app.whiteboard_renders FOR DELETE 
USING (
  EXISTS (
    SELECT 1 FROM app.whiteboard_projects 
    WHERE whiteboard_projects.id = whiteboard_renders.project_id 
    AND whiteboard_projects.student_id::text = auth.uid()::text
  )
)
"""
result = execute_sql(sql)
print(f"DELETE owner: {result}")

# Politiques pour admin
sql = """
CREATE POLICY whiteboard_renders_select_admin 
ON app.whiteboard_renders FOR SELECT 
USING (auth.jwt() ->> 'role' = 'admin')
"""
result = execute_sql(sql)
print(f"SELECT admin: {result}")

sql = """
CREATE POLICY whiteboard_renders_insert_admin 
ON app.whiteboard_renders FOR INSERT 
WITH CHECK (auth.jwt() ->> 'role' = 'admin')
"""
result = execute_sql(sql)
print(f"INSERT admin: {result}")

sql = """
CREATE POLICY whiteboard_renders_update_admin 
ON app.whiteboard_renders FOR UPDATE 
USING (auth.jwt() ->> 'role' = 'admin')
"""
result = execute_sql(sql)
print(f"UPDATE admin: {result}")

sql = """
CREATE POLICY whiteboard_renders_delete_admin 
ON app.whiteboard_renders FOR DELETE 
USING (auth.jwt() ->> 'role' = 'admin')
"""
result = execute_sql(sql)
print(f"DELETE admin: {result}")

# Politiques pour service role
sql = """
CREATE POLICY whiteboard_renders_select_service_role 
ON app.whiteboard_renders FOR SELECT 
USING (auth.role() = 'service_role')
"""
result = execute_sql(sql)
print(f"SELECT service_role: {result}")

sql = """
CREATE POLICY whiteboard_renders_insert_service_role 
ON app.whiteboard_renders FOR INSERT 
WITH CHECK (auth.role() = 'service_role')
"""
result = execute_sql(sql)
print(f"INSERT service_role: {result}")

sql = """
CREATE POLICY whiteboard_renders_update_service_role 
ON app.whiteboard_renders FOR UPDATE 
USING (auth.role() = 'service_role')
"""
result = execute_sql(sql)
print(f"UPDATE service_role: {result}")

sql = """
CREATE POLICY whiteboard_renders_delete_service_role 
ON app.whiteboard_renders FOR DELETE 
USING (auth.role() = 'service_role')
"""
result = execute_sql(sql)
print(f"DELETE service_role: {result}")

print("\n=== CRÉATION RLS TERMINÉE ===\n")
