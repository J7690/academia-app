import requests
import json

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

# Ajouter 1000 crédits à l'utilisateur de test
sql = """
INSERT INTO app.student_credits (student_id, balance, total_purchased, total_consumed, total_gifted, last_weekly_bonus)
VALUES ('f4b8f128-d0db-48f4-bf03-0e91fe3204c2', 1000, 0, 0, 1000, NOW())
ON CONFLICT (student_id) DO UPDATE SET
  balance = 1000,
  total_gifted = 1000;
"""

print("Ajout de 1000 crédits à l'utilisateur de test...")
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print("STATUS:", resp.status_code)
print("BODY:", resp.text)
