import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS)

# Get a real student_id
stdin, stdout, stderr = ssh.exec_command("""
source /opt/bobodo-vocal/.env 2>/dev/null
export $(grep -v '^#' /opt/bobodo-vocal/.env | xargs)

echo "=== Students ==="
curl -s "${SUPABASE_URL}/rest/v1/students?select=id,full_name&limit=3" \
  -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}"
""")
out = stdout.read().decode()
print(out[:3000])

# The table is in schema app, check
stdin, stdout, stderr = ssh.exec_command("""
source /opt/bobodo-vocal/.env 2>/dev/null
export $(grep -v '^#' /opt/bobodo-vocal/.env | xargs)

echo ""
echo "=== bobodo_sessions (schema app) ==="
curl -s "${SUPABASE_URL}/rest/v1/bobodo_sessions?select=id,student_id,title&limit=3&order=created_at.desc" \
  -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Accept-Profile: app"
""")
out2 = stdout.read().decode()
print(out2[:3000])

# Check schema for bobodo_sessions
stdin, stdout, stderr = ssh.exec_command("""
source /opt/bobodo-vocal/.env 2>/dev/null
export $(grep -v '^#' /opt/bobodo-vocal/.env | xargs)

echo ""
echo "=== RPC app_create_bobodo_session with student_id ==="
curl -s -X POST "${SUPABASE_URL}/rest/v1/rpc/app_create_bobodo_session" \
  -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"p_title":"Vocal Test"}'
""")
out3 = stdout.read().decode()
print(out3[:3000])

ssh.close()
