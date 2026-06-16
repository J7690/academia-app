#!/usr/bin/env python3
"""
Test utilisateur sacrifiable - parcours suppression de compte
"""
import requests, json, uuid

url='https://thevdfcwlcqzdoybfvgs.supabase.co'
key='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
headers={'apikey':key,'Authorization':f'Bearer {key}','Content-Type':'application/json'}

results=[]
TEST_EMAIL=f"test.sacrifice.{uuid.uuid4().hex[:8]}@academia.app"
TEST_PASS="TestPass123!"

def log(label, data):
    print(f"\n>>> {label}")
    print(json.dumps(data, indent=2)[:800])
    results.append({"step": label, "data": data})

# 1. Create user via admin API
print(f"Creating test user: {TEST_EMAIL}")
r=requests.post(
    f'{url}/auth/v1/admin/users',
    headers=headers,
    json={
        "email": TEST_EMAIL,
        "password": TEST_PASS,
        "email_confirm": True,
        "user_metadata": {"role": "student"}
    },
    timeout=30
)
create_data=r.json()
log("CREATE USER (admin)", {"status_code": r.status_code, "body": create_data})
user_id=create_data.get('id')
if not user_id:
    print("FAILED to create user")
    with open('test_sacrifice_results.json','w',encoding='utf-8') as f:
        json.dump(results, f, indent=2)
    exit(1)

# 2. Sign in
print("Signing in...")
r=requests.post(
    f'{url}/auth/v1/token?grant_type=password',
    headers={'apikey':key,'Content-Type':'application/json'},
    json={"email": TEST_EMAIL, "password": TEST_PASS},
    timeout=30
)
login_data=r.json()
log("SIGN IN", {"status_code": r.status_code, "has_access_token": 'access_token' in login_data})
access_token=login_data.get('access_token')
if not access_token:
    print("FAILED to sign in")
    with open('test_sacrifice_results.json','w',encoding='utf-8') as f:
        json.dump(results, f, indent=2)
    exit(1)

# 3. Call RPC app_student_request_account_deletion
print("Calling RPC app_student_request_account_deletion...")
rpc_headers={'apikey':key,'Authorization':f'Bearer {access_token}','Content-Type':'application/json'}
r=requests.post(
    f'{url}/rest/v1/rpc/app_student_request_account_deletion',
    headers=rpc_headers,
    json={},
    timeout=30
)
# Parse response (may be JSON or text)
try:
    rpc_data=r.json()
except:
    rpc_data={"raw": r.text, "status_code": r.status_code}
log("RPC app_student_request_account_deletion", {"status_code": r.status_code, "body": rpc_data})

# 4. Verify state via admin SQL
print("Verifying post-deletion state...")
def rpc_sql(sql):
    rr=requests.post(f'{url}/rest/v1/rpc/admin_execute_sql',headers=headers,json={'p_sql':sql},timeout=30)
    return rr.json()

res=rpc_sql(f"SELECT is_deleted, is_suspended, deleted_at, deletion_requested_at, purge_due_at, deletion_method FROM app.user_admin_status WHERE user_id = '{user_id}'")
log("POST user_admin_status", res)

res=rpc_sql(f"SELECT banned_until FROM auth.users WHERE id = '{user_id}'")
log("POST auth.users banned", res)

res=rpc_sql(f"SELECT COUNT(*) as sessions FROM auth.sessions WHERE user_id = '{user_id}'")
log("POST auth.sessions count", res)

# 5. Verify that historical accounts are untouched
res=rpc_sql("SELECT deletion_method, COUNT(*) as cnt FROM app.user_admin_status WHERE is_deleted = TRUE GROUP BY deletion_method ORDER BY cnt DESC")
log("HISTORICAL accounts deletion_method", res)

# 6. Verify cron eligibility (should still be 0)
res=rpc_sql("SELECT COUNT(*) as eligible FROM app.user_admin_status WHERE is_deleted=TRUE AND purge_due_at IS NOT NULL AND purge_due_at <= NOW() AND deletion_method = 'self_service'")
log("CRON eligibility (should be 0)", res)

# 7. Test re-login (should fail because banned)
print("Testing re-login (should fail)...")
r=requests.post(
    f'{url}/auth/v1/token?grant_type=password',
    headers={'apikey':key,'Content-Type':'application/json'},
    json={"email": TEST_EMAIL, "password": TEST_PASS},
    timeout=30
)
relogin_data=r.json()
log("RE-LOGIN attempt", {"status_code": r.status_code, "body": relogin_data})

with open('test_sacrifice_results.json','w',encoding='utf-8') as f:
    json.dump(results, f, indent=2, ensure_ascii=False)
print("\nResults saved to test_sacrifice_results.json")
