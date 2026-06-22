import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS)

# Check if bobodo_sessions table has any sessions
stdin, stdout, stderr = ssh.exec_command("""
source /opt/bobodo-vocal/.env 2>/dev/null
export $(grep -v '^#' /opt/bobodo-vocal/.env | xargs)

# List existing bobodo sessions
curl -s "${SUPABASE_URL}/rest/v1/bobodo_sessions?select=id,student_id,created_at&limit=5&order=created_at.desc" \
  -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" | python3 -m json.tool 2>/dev/null || echo "PARSE FAILED"
""")
out = stdout.read().decode()
print("=== Existing Bobodo Sessions ===")
print(out[:3000])

# Try to create a session and then send a message
stdin, stdout, stderr = ssh.exec_command("""
source /opt/bobodo-vocal/.env 2>/dev/null
export $(grep -v '^#' /opt/bobodo-vocal/.env | xargs)

# Create a session via RPC
echo ""
echo "=== Create session via RPC ==="
curl -s -X POST "${SUPABASE_URL}/rest/v1/rpc/app_create_bobodo_session" \
  -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"p_title":"Vocal Test Session"}'
""")
out2 = stdout.read().decode()
print(out2[:3000])

ssh.close()
