"""
Reset UMET Burkina university account:

1. Find UMET Burkina university in app.universities
2. Find its admin user (role='university')
3. Hard delete the admin user via GoTrue Admin API + clean FK tables
4. Delete all university-related data in app.*
5. Recreate the UMET Burkina university row
6. Recreate the admin auth user with the same email and new password

This script is intended to be run manually from the project root:

    python reset_umet_burkina_account.py

Use with caution: it performs destructive operations on the database.
"""

import sys
import json
import urllib.request
import urllib.error

sys.path.insert(0, '.windsurf')
from supabase_auto_manager import SupabaseAutoManager

mgr = SupabaseAutoManager()
SUPABASE_URL = mgr.url
SERVICE_KEY = mgr.service_key

TARGET_UNIVERSITY_NAME = 'UMET Burkina'
NEW_PASSWORD = 'Umet@Burkina1'


def gotrue_request(method, path, body=None):
    """Helper to call GoTrue Admin API."""
    url = f"{SUPABASE_URL}/auth/v1/admin{path}"
    headers = {
        'Content-Type': 'application/json',
        'Authorization': f'Bearer {SERVICE_KEY}',
        'apikey': SERVICE_KEY,
    }
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            text = resp.read().decode()
            if not text:
                # Some GoTrue admin endpoints may return 204 No Content
                return None
            return json.loads(text)
    except urllib.error.HTTPError as e:
        err = e.read().decode()
        print(f"  GoTrue {method} {path} => {e.code}: {err}")
        return None


def sql(query: str):
    """Helper to run SQL via SupabaseAutoManager."""
    result = mgr.execute_sql_auto(query)
    return result


# =====================================================================
# STEP 1: Find UMET Burkina university row
# =====================================================================
print("\n=== STEP 1: Find UMET Burkina university row ===")
q_uni = (
    "SELECT id, name, slug, contact_email, is_active "
    "FROM app.universities "
    "WHERE lower(name) LIKE '%umet%' "
    "AND lower(name) LIKE '%burkina%' "
    "ORDER BY is_active DESC"
)
r_uni = sql(q_uni)
uni_rows = r_uni.get('data', []) if r_uni and r_uni.get('success') else []

if not uni_rows:
    print("  No university found matching UMET Burkina pattern.")
    sys.exit(1)

uni = uni_rows[0]
university_id = uni['id']
print(f"  Using university id={university_id}, name={uni.get('name')}, slug={uni.get('slug')}")

admin_email = None
old_user_id = None

# =====================================================================
# STEP 2: Find admin user for this university
# =====================================================================
print("\n=== STEP 2: Find admin user for this university ===")
q_user = (
    "SELECT id, email, raw_user_meta_data->>'role' AS role "
    "FROM auth.users "
    f"WHERE raw_user_meta_data->>'university_id' = '{university_id}' "
    "AND raw_user_meta_data->>'role' = 'university'"
)
r_user = sql(q_user)
user_rows = r_user.get('data', []) if r_user and r_user.get('success') else []

if user_rows:
    u = user_rows[0]
    old_user_id = u['id']
    admin_email = u['email']
    print(f"  Found admin user id={old_user_id}, email={admin_email}")
else:
    print("  No auth user with role='university' linked to this university.")
    # Fallback: use contact_email if available
    admin_email = uni.get('contact_email')
    if admin_email:
        print(f"  Falling back to contact_email as admin email: {admin_email}")
    else:
        print("  ERROR: No admin email found; aborting.")
        sys.exit(1)

# =====================================================================
# STEP 3: Hard delete admin user (GoTrue) + clean FK tables
# =====================================================================
if old_user_id:
    print("\n=== STEP 3: Hard delete admin user (GoTrue) + clean FK tables ===")
    sql(f"DELETE FROM app.admin_user_action_logs WHERE target_user = '{old_user_id}' OR performed_by = '{old_user_id}'")
    print("  app.admin_user_action_logs cleaned")
    sql(f"DELETE FROM app.user_admin_status WHERE user_id = '{old_user_id}'")
    print("  app.user_admin_status cleaned")
    sql(f"DELETE FROM app.admin_deleted_users_archive WHERE user_id = '{old_user_id}'")
    print("  app.admin_deleted_users_archive cleaned")

    resp = gotrue_request('DELETE', f"/users/{old_user_id}")
    if resp is not None:
        print("  GoTrue hard delete OK")
    else:
        print("  GoTrue hard delete returned no body (check logs if needed)")
else:
    print("\n=== STEP 3: No existing admin user linked by university_id to hard delete ===")

# =====================================================================
# STEP 3B: Ensure no other auth.users with same admin email
# =====================================================================
print("\n=== STEP 3B: Ensure no other auth.users exist with this admin email ===")
if admin_email:
    q_by_email = (
        "SELECT id, email FROM auth.users "
        f"WHERE email = '{admin_email}'"
    )
    r_by_email = sql(q_by_email)
    email_rows = r_by_email.get('data', []) if r_by_email and r_by_email.get('success') else []

    for row in email_rows:
        extra_user_id = row['id']
        if extra_user_id == old_user_id:
            continue
        print(f"  Found extra user with same email, id={extra_user_id} — hard deleting it")
        sql(f"DELETE FROM app.admin_user_action_logs WHERE target_user = '{extra_user_id}' OR performed_by = '{extra_user_id}'")
        sql(f"DELETE FROM app.user_admin_status WHERE user_id = '{extra_user_id}'")
        sql(f"DELETE FROM app.admin_deleted_users_archive WHERE user_id = '{extra_user_id}'")
        resp2 = gotrue_request('DELETE', f"/users/{extra_user_id}")
        if resp2 is not None:
            print("    GoTrue hard delete OK for extra user")
        else:
            print("    GoTrue hard delete returned no body for extra user (check logs if needed)")
else:
    print("  No admin_email defined yet, skipping STEP 3B.")

# =====================================================================
# STEP 4: Delete university-related data for UMET Burkina
# =====================================================================
print("\n=== STEP 4: Delete university-related data for UMET Burkina ===")

child_tables = [
    'university_site_config',
    'university_site_banners',
    'university_site_blocks',
    'university_events',
    'university_news',
    'university_staff',
    'university_media',
]

for table in child_tables:
    sql(f"DELETE FROM app.{table} WHERE university_id = '{university_id}'")
    print(f"  app.{table} cleaned")

sql(
    "DELETE FROM app.courses "
    "WHERE program_id IN (SELECT id FROM app.programs WHERE university_id = '{university_id}')".format(university_id=university_id)
)
print("  app.courses cleaned")

sql(f"DELETE FROM app.programs WHERE university_id = '{university_id}'")
print("  app.programs cleaned")

sql(f"DELETE FROM app.universities WHERE id = '{university_id}'")
print("  app.universities row deleted")

# =====================================================================
# STEP 5: Create fresh UMET Burkina university row
# =====================================================================
print("\n=== STEP 5: Create fresh UMET Burkina university row ===")
contact_email_value = admin_email or ''

sql(
    "INSERT INTO app.universities (name, slug, contact_email, is_active) "
    f"VALUES ('{TARGET_UNIVERSITY_NAME}', 'umet-burkina', '{contact_email_value}', true)"
)

r_new_uni = sql(
    "SELECT id FROM app.universities "
    "WHERE slug = 'umet-burkina' AND is_active = true"
)
new_rows = r_new_uni.get('data', []) if r_new_uni and r_new_uni.get('success') else []

if not new_rows:
    print("ERROR: Could not create/find new UMET Burkina university row.")
    sys.exit(1)

new_university_id = new_rows[0]['id']
print(f"  New UMET Burkina university id={new_university_id}")

# =====================================================================
# STEP 6: Create new admin auth user with same email
# =====================================================================
print("\n=== STEP 6: Create new admin auth user with same email ===")

if not admin_email:
    print("ERROR: admin_email is empty, cannot create auth user.")
    sys.exit(1)

user_resp = gotrue_request('POST', '/users', {
    'email': admin_email,
    'password': NEW_PASSWORD,
    'email_confirm': True,
    'user_metadata': {
        'role': 'university',
        'university_id': new_university_id,
        'full_name': TARGET_UNIVERSITY_NAME,
    },
})

if not user_resp or not user_resp.get('id'):
    print("ERROR: Could not create new admin auth user.")
    sys.exit(1)

new_user_id = user_resp['id']
print(f"  Created new admin user id={new_user_id}")

print("\n" + "=" * 60)
print("DONE! Compte UMET Burkina recréé avec succès.")
print("=" * 60)
print(f"  Email:          {admin_email}")
print(f"  Password:       {NEW_PASSWORD}")
print("  Role:           university")
print(f"  University ID:  {new_university_id}")
print(f"  User ID:        {new_user_id}")
