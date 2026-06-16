import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS)

# Check .env for supabase_url and keys
stdin, stdout, stderr = ssh.exec_command("cat /opt/bobodo-vocal/.env | grep -iE 'supabase|openrouter' | head -10")
env = stdout.read().decode()
print("=== .env (supabase/openrouter) ===")
print(env)

# Check Bobodo error in recent logs
stdin, stdout, stderr = ssh.exec_command("journalctl -u bobodo-vocal --since='30 minutes ago' | grep -i 'bobodo' | tail -20")
logs = stdout.read().decode()
print("=== Bobodo logs ===")
print(logs[:5000])

# Quick test: curl the edge function directly
stdin, stdout, stderr = ssh.exec_command("""
source /opt/bobodo-vocal/.env 2>/dev/null
export $(grep -v '^#' /opt/bobodo-vocal/.env | xargs)
echo "URL: ${SUPABASE_URL}/functions/v1/bobodo-chat"
curl -s -w "\\nHTTP_CODE:%{http_code}" -X POST "${SUPABASE_URL}/functions/v1/bobodo-chat" \
  -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"session_id":"test-curl-001","message":"Bonjour"}' \
  --max-time 30
""")
curl_out = stdout.read().decode()
curl_err = stderr.read().decode()
print("\n=== Curl test ===")
print(curl_out[:3000])
if curl_err:
    print("STDERR:", curl_err[:500])

ssh.close()
print("\nDone.")
