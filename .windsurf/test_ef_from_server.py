import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

SCRIPT = '''
import httpx
import asyncio

async def test():
    url = "https://thevdfcwlcqzdoybfvgs.supabase.co/functions/v1/bobodo-chat"
    headers = {
        "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
        "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
        "Content-Type": "application/json"
    }
    payload = {
        "session_id": "a5eea5b6-7477-4035-b332-444d94de3125",
        "message": "Bonjour"
    }
    
    async with httpx.AsyncClient(timeout=45.0) as client:
        try:
            resp = await client.post(url, headers=headers, json=payload)
            print(f"STATUS: {resp.status_code}")
            print(f"BODY: {resp.text[:1000]}")
            if resp.status_code == 200:
                data = resp.json()
                print(f"REPLY: {data.get('reply', 'N/A')[:500]}")
        except Exception as e:
            print(f"ERROR: {e}")

asyncio.run(test())
'''

def main():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS)
    
    stdin, stdout, stderr = ssh.exec_command("cat > /tmp/test_ef.py << 'EOF'\n" + SCRIPT + "\nEOF")
    stdout.channel.recv_exit_status()
    
    stdin, stdout, stderr = ssh.exec_command("cd /opt/bobodo-vocal && source venv/bin/activate && python /tmp/test_ef.py")
    for line in iter(stdout.readline, ""):
        print(line, end="")
    
    err = stderr.read().decode('utf-8')
    if err:
        print("STDERR:", err)
    
    ssh.close()

if __name__ == "__main__":
    main()
