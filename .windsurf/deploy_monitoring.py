import paramiko
import time

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS)

# Create monitoring script
monitor_script = r"""#!/bin/bash
# Bobodo Voice Monitoring — /opt/bobodo-vocal/monitor.sh
# Exécuté toutes les 5 minutes via cron

STATUS=$(systemctl is-active bobodo-vocal)
MEM_BYTES=$(systemctl show bobodo-vocal -p MemoryCurrent --value 2>/dev/null || echo 0)
MEM_MB=$((MEM_BYTES / 1024 / 1024))
UPTIME=$(systemctl show bobodo-vocal -p ActiveEnterTimestamp --value 2>/dev/null)

# Métriques des 5 dernières minutes
SESSIONS=$(journalctl -u bobodo-vocal --since='5 min ago' --no-pager 2>/dev/null | grep -c 'Registered session')
DESTROYED=$(journalctl -u bobodo-vocal --since='5 min ago' --no-pager 2>/dev/null | grep -c 'Removed session')
ERRORS=$(journalctl -u bobodo-vocal --since='5 min ago' --no-pager 2>/dev/null | grep -ci 'error')
LATENCY=$(journalctl -u bobodo-vocal --since='5 min ago' --no-pager 2>/dev/null | grep 'STT_LATENCY' | grep -oP '\d+' | tail -1)
CPU_LOAD=$(cat /proc/loadavg | awk '{print $1}')

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_LINE="$TIMESTAMP | status=$STATUS | ram=${MEM_MB}MB | cpu_load=$CPU_LOAD | sessions_new=$SESSIONS | sessions_closed=$DESTROYED | errors=$ERRORS | stt_latency=${LATENCY:-N/A}ms"

echo "$LOG_LINE" >> /var/log/bobodo-voice.log

# Alertes
if [ "$MEM_MB" -gt 1500 ] 2>/dev/null; then
    echo "$TIMESTAMP | ALERT: RAM=${MEM_MB}MB > 1500MB" >> /var/log/bobodo-voice-alerts.log
fi

if [ "$ERRORS" -gt 5 ] 2>/dev/null; then
    echo "$TIMESTAMP | ALERT: $ERRORS errors in 5min" >> /var/log/bobodo-voice-alerts.log
fi

if [ "$STATUS" != "active" ]; then
    echo "$TIMESTAMP | ALERT: Service DOWN — attempting restart" >> /var/log/bobodo-voice-alerts.log
    systemctl restart bobodo-vocal
fi
"""

# Upload script
print("Creating monitor.sh...")
stdin, stdout, stderr = ssh.exec_command(f"cat > /opt/bobodo-vocal/monitor.sh << 'SCRIPT_EOF'\n{monitor_script}\nSCRIPT_EOF")
stdout.channel.recv_exit_status()

ssh.exec_command("chmod +x /opt/bobodo-vocal/monitor.sh")

# Create cron job
print("Setting up cron (every 5 min)...")
stdin, stdout, stderr = ssh.exec_command("echo '*/5 * * * * root /opt/bobodo-vocal/monitor.sh' > /etc/cron.d/bobodo-monitor")
stdout.channel.recv_exit_status()
ssh.exec_command("chmod 644 /etc/cron.d/bobodo-monitor")

# Create log files
ssh.exec_command("touch /var/log/bobodo-voice.log /var/log/bobodo-voice-alerts.log")

# Test the script
print("Running monitor.sh for first time...")
stdin, stdout, stderr = ssh.exec_command("/opt/bobodo-vocal/monitor.sh")
stdout.channel.recv_exit_status()

# Show result
stdin, stdout, stderr = ssh.exec_command("cat /var/log/bobodo-voice.log")
log_content = stdout.read().decode()
print(f"\n=== Log output ===\n{log_content}")

# Check CPU cost of script
print("\n=== Script execution time ===")
stdin, stdout, stderr = ssh.exec_command("time /opt/bobodo-vocal/monitor.sh 2>&1")
time_out = stdout.read().decode()
print(time_out[:500])

ssh.close()
print("\nÉTAPE 2 TERMINÉE.")
