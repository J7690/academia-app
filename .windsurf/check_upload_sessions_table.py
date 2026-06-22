import requests
import json

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=" * 80)
print("VÉRIFICATION DE L'ÉTAT ACTUEL DES TABLES SUPABASE")
print("=" * 80)

# 1. Vérifier si la table upload_sessions existe
sql1 = "SELECT tablename FROM pg_tables WHERE schemaname = 'app' AND tablename = 'upload_sessions'"
resp1 = requests.post(url, headers=headers, json={"p_sql": sql1}, timeout=30)
print("\n1. Vérification de la table upload_sessions:")
print("   STATUS:", resp1.status_code)
print("   BODY:", resp1.text[:500])

# 2. Si la table existe, vérifier sa structure
if resp1.status_code == 200 and resp1.text.strip() and "upload_sessions" in resp1.text:
    print("\n   ⚠️  La table upload_sessions existe déjà!")
    
    # Vérifier les colonnes
    sql2 = """
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema = 'app' AND table_name = 'upload_sessions'
    ORDER BY ordinal_position
    """
    resp2 = requests.post(url, headers=headers, json={"p_sql": sql2}, timeout=30)
    print("\n2. Structure actuelle de la table upload_sessions:")
    print("   STATUS:", resp2.status_code)
    print("   BODY:", resp2.text[:1000])
    
    # Vérifier les indexes
    sql3 = """
    SELECT indexname, indexdef
    FROM pg_indexes
    WHERE schemaname = 'app' AND tablename = 'upload_sessions'
    """
    resp3 = requests.post(url, headers=headers, json={"p_sql": sql3}, timeout=30)
    print("\n3. Indexes actuels sur upload_sessions:")
    print("   STATUS:", resp3.status_code)
    print("   BODY:", resp3.text[:1000])
    
    # Vérifier les RLS policies
    sql4 = """
    SELECT policyname, permissive, roles, cmd, qual
    FROM pg_policies
    WHERE schemaname = 'app' AND tablename = 'upload_sessions'
    """
    resp4 = requests.post(url, headers=headers, json={"p_sql": sql4}, timeout=30)
    print("\n4. RLS policies actuelles sur upload_sessions:")
    print("   STATUS:", resp4.status_code)
    print("   BODY:", resp4.text[:1000])
else:
    print("\n   ✓ La table upload_sessions n'existe pas encore")

# 5. Vérifier si la fonction cleanup_expired_upload_sessions existe
sql5 = "SELECT proname FROM pg_proc WHERE proname = 'cleanup_expired_upload_sessions'"
resp5 = requests.post(url, headers=headers, json={"p_sql": sql5}, timeout=30)
print("\n5. Vérification de la fonction cleanup_expired_upload_sessions:")
print("   STATUS:", resp5.status_code)
print("   BODY:", resp5.text[:500])

# 6. Vérifier si le trigger existe
sql6 = """
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE trigger_schema = 'app' AND trigger_name = 'trigger_cleanup_expired_upload_sessions'
"""
resp6 = requests.post(url, headers=headers, json={"p_sql": sql6}, timeout=30)
print("\n6. Vérification du trigger trigger_cleanup_expired_upload_sessions:")
print("   STATUS:", resp6.status_code)
print("   BODY:", resp6.text[:500])

print("\n" + "=" * 80)
print("FIN DE LA VÉRIFICATION")
print("=" * 80)
