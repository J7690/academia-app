import requests, json, time
URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"}

def exec_sql(sql):
    return requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": sql}).json()

user_id = "208cfab4-2c31-4f31-ab01-c6baa8ecbbc2"
session_id = "a728d457-f60c-4f1e-9edb-6c7e4bcaef8d"

print("=== Vérification nettoyage Amssetou Yanogo ===")

# Check sessions
r = exec_sql(f"SELECT COUNT(*) as n FROM app.bobodo_sessions WHERE student_id = '{user_id}';")
print(f"  Sessions restantes: {r}")

r = exec_sql(f"SELECT COUNT(*) as n FROM app.bobodo_messages WHERE session_id = '{session_id}';")
print(f"  Messages restants: {r}")

r = exec_sql(f"SELECT COUNT(*) as n FROM app.bobodo_detected_needs WHERE session_id = '{session_id}';")
print(f"  Besoins restants: {r}")

r = exec_sql(f"SELECT COUNT(*) as n FROM app.bobodo_feedback WHERE session_id = '{session_id}';")
print(f"  Feedback restant: {r}")

print("\n=== FIN ===")
