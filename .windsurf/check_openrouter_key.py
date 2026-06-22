import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS)

# Show actual key being used (first/last 10 chars)
stdin, stdout, stderr = ssh.exec_command("""
source /opt/bobodo-vocal/.env 2>/dev/null
export $(grep -v '^#' /opt/bobodo-vocal/.env | xargs)
echo "Key length: ${#OPENROUTER_API_KEY}"
echo "Key prefix: ${OPENROUTER_API_KEY:0:20}"
echo "Key suffix: ${OPENROUTER_API_KEY: -10}"
echo "Model: $OPENROUTER_MODEL"

# Test the key directly
echo ""
echo "=== Direct OpenRouter test ==="
curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer ${OPENROUTER_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"model":"google/gemini-2.5-flash","messages":[{"role":"user","content":"Say hi in French"}],"max_tokens":20}' \
  --max-time 15
""")
out = stdout.read().decode()
print(out[:3000])

ssh.close()
