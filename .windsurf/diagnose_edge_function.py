import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS)

# Test with verbose response from edge function
stdin, stdout, stderr = ssh.exec_command("""
source /opt/bobodo-vocal/.env 2>/dev/null
export $(grep -v '^#' /opt/bobodo-vocal/.env | xargs)
# Test 1: without session_id (to see what the function expects)
echo "=== Test sans session_id ==="
curl -s -X POST "${SUPABASE_URL}/functions/v1/bobodo-chat" \
  -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"message":"Bonjour"}' \
  --max-time 30

echo ""
echo "=== Test avec user_id fictif ==="
curl -s -X POST "${SUPABASE_URL}/functions/v1/bobodo-chat" \
  -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"session_id":"test-curl-001","message":"Bonjour","user_id":"00000000-0000-0000-0000-000000000001"}' \
  --max-time 30

echo ""
echo "=== Test payload alternatif ==="
curl -s -X POST "${SUPABASE_URL}/functions/v1/bobodo-chat" \
  -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"conversation_id":"test-curl-001","content":"Bonjour","role":"user"}' \
  --max-time 30
""")
out = stdout.read().decode()
print(out[:5000])

ssh.close()
