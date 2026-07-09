"""
Script pour Phase B.4B – Storage Policies Creation
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

print("=== CRÉATION POLITIQUES STORAGE whiteboard-narrations ===\n")

# Politique SELECT pour propriétaire (basée sur project_id dans le nom du fichier)
sql = """
CREATE POLICY whiteboard_narrations_select_owner 
ON storage.objects FOR SELECT 
USING (
  bucket_id = 'whiteboard-narrations' 
  AND auth.uid()::text = (storage.foldername(name))[1]::text
)
"""
result = execute_sql(sql)
print(f"SELECT owner: {result}")

# Politique INSERT pour propriétaire
sql = """
CREATE POLICY whiteboard_narrations_insert_owner 
ON storage.objects FOR INSERT 
WITH CHECK (
  bucket_id = 'whiteboard-narrations' 
  AND auth.uid()::text = (storage.foldername(name))[1]::text
)
"""
result = execute_sql(sql)
print(f"INSERT owner: {result}")

# Politique UPDATE pour propriétaire
sql = """
CREATE POLICY whiteboard_narrations_update_owner 
ON storage.objects FOR UPDATE 
USING (
  bucket_id = 'whiteboard-narrations' 
  AND auth.uid()::text = (storage.foldername(name))[1]::text
)
"""
result = execute_sql(sql)
print(f"UPDATE owner: {result}")

# Politique DELETE pour propriétaire
sql = """
CREATE POLICY whiteboard_narrations_delete_owner 
ON storage.objects FOR DELETE 
USING (
  bucket_id = 'whiteboard-narrations' 
  AND auth.uid()::text = (storage.foldername(name))[1]::text
)
"""
result = execute_sql(sql)
print(f"DELETE owner: {result}")

# Politiques pour admin
sql = """
CREATE POLICY whiteboard_narrations_select_admin 
ON storage.objects FOR SELECT 
USING (
  bucket_id = 'whiteboard-narrations' 
  AND auth.jwt() ->> 'role' = 'admin'
)
"""
result = execute_sql(sql)
print(f"SELECT admin: {result}")

sql = """
CREATE POLICY whiteboard_narrations_insert_admin 
ON storage.objects FOR INSERT 
WITH CHECK (
  bucket_id = 'whiteboard-narrations' 
  AND auth.jwt() ->> 'role' = 'admin'
)
"""
result = execute_sql(sql)
print(f"INSERT admin: {result}")

sql = """
CREATE POLICY whiteboard_narrations_update_admin 
ON storage.objects FOR UPDATE 
USING (
  bucket_id = 'whiteboard-narrations' 
  AND auth.jwt() ->> 'role' = 'admin'
)
"""
result = execute_sql(sql)
print(f"UPDATE admin: {result}")

sql = """
CREATE POLICY whiteboard_narrations_delete_admin 
ON storage.objects FOR DELETE 
USING (
  bucket_id = 'whiteboard-narrations' 
  AND auth.jwt() ->> 'role' = 'admin'
)
"""
result = execute_sql(sql)
print(f"DELETE admin: {result}")

# Politiques pour service role
sql = """
CREATE POLICY whiteboard_narrations_select_service_role 
ON storage.objects FOR SELECT 
USING (
  bucket_id = 'whiteboard-narrations' 
  AND auth.role() = 'service_role'
)
"""
result = execute_sql(sql)
print(f"SELECT service_role: {result}")

sql = """
CREATE POLICY whiteboard_narrations_insert_service_role 
ON storage.objects FOR INSERT 
WITH CHECK (
  bucket_id = 'whiteboard-narrations' 
  AND auth.role() = 'service_role'
)
"""
result = execute_sql(sql)
print(f"INSERT service_role: {result}")

sql = """
CREATE POLICY whiteboard_narrations_update_service_role 
ON storage.objects FOR UPDATE 
USING (
  bucket_id = 'whiteboard-narrations' 
  AND auth.role() = 'service_role'
)
"""
result = execute_sql(sql)
print(f"UPDATE service_role: {result}")

sql = """
CREATE POLICY whiteboard_narrations_delete_service_role 
ON storage.objects FOR DELETE 
USING (
  bucket_id = 'whiteboard-narrations' 
  AND auth.role() = 'service_role'
)
"""
result = execute_sql(sql)
print(f"DELETE service_role: {result}")

print("\n=== CRÉATION POLITIQUES STORAGE whiteboard-renders ===\n")

# Politique SELECT pour propriétaire
sql = """
CREATE POLICY whiteboard_renders_select_owner 
ON storage.objects FOR SELECT 
USING (
  bucket_id = 'whiteboard-renders' 
  AND auth.uid()::text = (storage.foldername(name))[1]::text
)
"""
result = execute_sql(sql)
print(f"SELECT owner: {result}")

# Politique INSERT pour propriétaire
sql = """
CREATE POLICY whiteboard_renders_insert_owner 
ON storage.objects FOR INSERT 
WITH CHECK (
  bucket_id = 'whiteboard-renders' 
  AND auth.uid()::text = (storage.foldername(name))[1]::text
)
"""
result = execute_sql(sql)
print(f"INSERT owner: {result}")

# Politique UPDATE pour propriétaire
sql = """
CREATE POLICY whiteboard_renders_update_owner 
ON storage.objects FOR UPDATE 
USING (
  bucket_id = 'whiteboard-renders' 
  AND auth.uid()::text = (storage.foldername(name))[1]::text
)
"""
result = execute_sql(sql)
print(f"UPDATE owner: {result}")

# Politique DELETE pour propriétaire
sql = """
CREATE POLICY whiteboard_renders_delete_owner 
ON storage.objects FOR DELETE 
USING (
  bucket_id = 'whiteboard-renders' 
  AND auth.uid()::text = (storage.foldername(name))[1]::text
)
"""
result = execute_sql(sql)
print(f"DELETE owner: {result}")

# Politiques pour admin
sql = """
CREATE POLICY whiteboard_renders_select_admin 
ON storage.objects FOR SELECT 
USING (
  bucket_id = 'whiteboard-renders' 
  AND auth.jwt() ->> 'role' = 'admin'
)
"""
result = execute_sql(sql)
print(f"SELECT admin: {result}")

sql = """
CREATE POLICY whiteboard_renders_insert_admin 
ON storage.objects FOR INSERT 
WITH CHECK (
  bucket_id = 'whiteboard-renders' 
  AND auth.jwt() ->> 'role' = 'admin'
)
"""
result = execute_sql(sql)
print(f"INSERT admin: {result}")

sql = """
CREATE POLICY whiteboard_renders_update_admin 
ON storage.objects FOR UPDATE 
USING (
  bucket_id = 'whiteboard-renders' 
  AND auth.jwt() ->> 'role' = 'admin'
)
"""
result = execute_sql(sql)
print(f"UPDATE admin: {result}")

sql = """
CREATE POLICY whiteboard_renders_delete_admin 
ON storage.objects FOR DELETE 
USING (
  bucket_id = 'whiteboard-renders' 
  AND auth.jwt() ->> 'role' = 'admin'
)
"""
result = execute_sql(sql)
print(f"DELETE admin: {result}")

# Politiques pour service role
sql = """
CREATE POLICY whiteboard_renders_select_service_role 
ON storage.objects FOR SELECT 
USING (
  bucket_id = 'whiteboard-renders' 
  AND auth.role() = 'service_role'
)
"""
result = execute_sql(sql)
print(f"SELECT service_role: {result}")

sql = """
CREATE POLICY whiteboard_renders_insert_service_role 
ON storage.objects FOR INSERT 
WITH CHECK (
  bucket_id = 'whiteboard-renders' 
  AND auth.role() = 'service_role'
)
"""
result = execute_sql(sql)
print(f"INSERT service_role: {result}")

sql = """
CREATE POLICY whiteboard_renders_update_service_role 
ON storage.objects FOR UPDATE 
USING (
  bucket_id = 'whiteboard-renders' 
  AND auth.role() = 'service_role'
)
"""
result = execute_sql(sql)
print(f"UPDATE service_role: {result}")

sql = """
CREATE POLICY whiteboard_renders_delete_service_role 
ON storage.objects FOR DELETE 
USING (
  bucket_id = 'whiteboard-renders' 
  AND auth.role() = 'service_role'
)
"""
result = execute_sql(sql)
print(f"DELETE service_role: {result}")

print("\n=== CRÉATION POLITIQUES TERMINÉE ===\n")
