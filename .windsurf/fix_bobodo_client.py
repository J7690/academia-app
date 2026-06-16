import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

def main():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS)
    
    # Read file
    stdin, stdout, stderr = ssh.exec_command('cat /opt/bobodo-vocal/bobodo_client.py')
    content = stdout.read().decode('utf-8')
    
    # Fix: add apikey header
    old = '''            headers = {
                "Authorization": f"Bearer {self.service_role_key}",
                "Content-Type": "application/json"
            }'''
    new = '''            headers = {
                "apikey": self.service_role_key,
                "Authorization": f"Bearer {self.service_role_key}",
                "Content-Type": "application/json"
            }'''
    
    if old in content:
        content = content.replace(old, new)
        # Write back using a heredoc
        cmd = "cat > /opt/bobodo-vocal/bobodo_client.py << 'EOF'\n" + content + "\nEOF"
        stdin2, stdout2, stderr2 = ssh.exec_command(cmd)
        stdout2.channel.recv_exit_status()
        print("Fixed bobodo_client.py")
    else:
        print("Pattern not found. Content around headers:")
        idx = content.find("headers = {")
        if idx != -1:
            print(content[idx:idx+500])
        else:
            print("headers not found at all")
    
    ssh.close()

if __name__ == "__main__":
    main()
