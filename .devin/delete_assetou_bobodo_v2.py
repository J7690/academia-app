"""Suppression exceptionnelle des conversations Bobodo d'Assetou Yanogo — V2."""
import requests, json, time

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"}

def exec_sql(sql):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": sql})
    return r.json()

# 1. Trouver Assetou Yanogo
print("=== ÉTAPE 1: Identifier Assetou Yanogo ===")
r = exec_sql("""
  SELECT id, email, raw_user_meta_data->>'full_name' as name, raw_user_meta_data->>'role' as role
  FROM auth.users
  WHERE LOWER(COALESCE(raw_user_meta_data->>'full_name', '')) LIKE '%yanogo%'
     OR LOWER(COALESCE(raw_user_meta_data->>'full_name', '')) LIKE '%assetou%'
     OR LOWER(COALESCE(raw_user_meta_data->>'full_name', '')) LIKE '%asetou%'
     OR LOWER(COALESCE(raw_user_meta_data->>'display_name', '')) LIKE '%yanogo%'
     OR LOWER(COALESCE(raw_user_meta_data->>'display_name', '')) LIKE '%assetou%'
     OR LOWER(email) LIKE '%yanogo%'
     OR LOWER(email) LIKE '%assetou%';
""")
print(f"  Résultat: {json.dumps(r, default=str, ensure_ascii=False)[:500]}")

# If not found, list last bobodo sessions
if not r or (isinstance(r, dict) and 'error' in r) or (isinstance(r, list) and len(r) == 0):
    print("\n  Pas trouvée directement. Dernières sessions Bobodo:")
    r2 = exec_sql("""
      SELECT s.id as session_id, s.student_id, s.title, s.created_at,
             COALESCE(u.raw_user_meta_data->>'full_name', u.raw_user_meta_data->>'display_name', u.email) as student_name
      FROM app.bobodo_sessions s
      JOIN auth.users u ON u.id = s.student_id
      ORDER BY s.created_at DESC
      LIMIT 15;
    """)
    print(f"  {json.dumps(r2, default=str, ensure_ascii=False)[:800]}")
    
    if isinstance(r2, list):
        # Find unique students
        students = {}
        for row in r2:
            sid = row.get('student_id', '')
            name = row.get('student_name', '')
            if sid not in students:
                students[sid] = name
        print("\n  Utilisateurs avec sessions Bobodo:")
        for sid, name in students.items():
            print(f"    {name} (id={sid})")
