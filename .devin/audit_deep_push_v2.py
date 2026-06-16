#!/usr/bin/env python3
"""AUDIT DEEP V2 — Test FCM delivery directement token par token avec réponse complète."""
import json, time, requests, jwt, calendar
from datetime import datetime, timedelta
from supabase_auto_manager import SupabaseAutoManager
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend

# FCM Service Account (hardcoded in Edge Function)
SA = {
    "project_id": "academia-e2c41",
    "client_email": "firebase-adminsdk-fbsvc@academia-e2c41.iam.gserviceaccount.com",
    "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDGZpajtvuc2WRL\nk8VufyesySYq/a30mzLdPg/rbpfTfZI6pd1f4LclTFN52ipKhnNTmOc9bnoo6WXc\nseyCjfGCPYzysIXSs2IOI/ky3Xw4W0fnRlGMbMcn7XwkmcJ9zlXI9ulVyTDPIJ7B\nCGeHPqPa+PQ5yuzeU2WBTRo2li0aWLlEnXXj6gCSmBuiRQmO6We0hOVVKLCrFhIJ\nf+l85/Y2zOVRijGdP2xLPeVnM8ZlTQ2cNaH48oiyZroN7EzS9Eo3UFpXkSBNI6lL\nOuNdoLb26Sx8a3avWa0oNSnagHHJt5hUshnKTOlLyCbNfYN98Fby+hc3VOJKs8I9\nMNg0iN1ZAgMBAAECggEADVAF7J9TG8+0fKPCPCtZEK2Am6LhAMhHLfRDojMOCflj\njf7iL1RHRb/s3ADJFK4X3/SjE4qttMAQfzILIil/GpOhuQkiOaSiwDsmtgSJmMh7\nNygPQcJszJ+RVG1i0Qk+1VjICGMTHNrd/Crhs3//A6rvzE7y/OoQpg/z4dTK2vkZ\n0zsuO+/ILITxa5S/8foNHQWuasyOSE3Dwccaal+6FyDCTddH+2K1W87qRn+w8jtK\nzAEjt3HbPCMK7Jpd+zy2TGhDJumFyGoTMnygNb80Kt+VQeDV3n+9gjmAkGKZZPWj\nreWhPPaA8zdvizOdGj/FRQ3kcOWfFu+JPcXVUcWu/wKBgQDriUCv1Ima24UK65mc\nujpYlq+xARrSczaPfOptE149EwiX2J5Fj8Bz7PmgvXjPwr6ahIzPikYZbhUntbZd\n2UPbm1YwYMuIZChZGu0XFqA4yPmZyGnzIVdiBPyDocDY4acNQCq+UOle03aQ7bLG\nn8r510codEqI+xxMNITVwQhPpwKBgQDXo2CloKagjYgFxItChkTA3xbQ7XO100Zm\nuE+7uOfb2CAVFd0sxylK8fEh6eoIimIleYW8EqkikbL9oEr5KCmaszsDCYHC/iat\nRUz4s+XdU8LMVpDLomgrS8vjF4b/AxMJ10w7c1l5i7X9sUTiTtQJUWv/gsvxezdl\nbLW54VMK/wKBgG7Gq8TGmj1Z91Wufx3GPIDDxjfihCHsjAGqR3sre8wPsp/wAmhG\n9sXO84zU8AgO2KRFqRBHQTbenlaB0RaMg6y6fyvbqn4oVQ2ra0zLmGl8pF/ecW4n\nBTkVjUm/frrCTlYeErxVw5yUqhP5p3ZhWw5sYIw3PYL1T1bL8Jmz4tvLAoGBAIxw\n6JIWlk88vllbT4ONJRwkb5y0+cZzCof+BFfzrnY9RW/WJI10TM1106FN0lGrpw5X\nHiWGVceg8t1CV3H8mVQa5RUuTOftVM1GtEHKEKxcUCN7QaSOap/AJtMJUK+nle+z\n2/9gOebyeh33JTDrPCexctAfpKnqoQKakaS1PruLAoGAYvDR1CtFtS7ENYYwMLbq\nSkVYalMunHSQy1jkiUe48JYjcfa/D+lUD2C3NO/YPikLEh1YJYrKbFHB/Ce51eec\nlCwFJU+NTybtQO9M33bqu3g73K89+aXR7LN9zWnau1V04zLyiqdpFxgMClynueDx\nP1YvEYxnsFkebj/SJZ3hSoM=\n-----END PRIVATE KEY-----\n",
    "token_uri": "https://oauth2.googleapis.com/token",
}

def get_fcm_access_token():
    """Get OAuth2 access token for FCM v1 API."""
    now = int(time.time())
    payload = {
        "iss": SA["client_email"],
        "sub": SA["client_email"],
        "aud": SA["token_uri"],
        "iat": now,
        "exp": now + 3600,
        "scope": "https://www.googleapis.com/auth/firebase.messaging",
    }
    token = jwt.encode(payload, SA["private_key"], algorithm="RS256")
    r = requests.post(SA["token_uri"], data={
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion": token,
    }, timeout=15)
    if r.status_code != 200:
        print(f"❌ OAuth token error: {r.status_code} {r.text[:300]}")
        return None
    return r.json().get("access_token")

def send_fcm_direct(access_token, fcm_token, title, body):
    """Send a push notification directly via FCM v1 API and return FULL response."""
    url = f"https://fcm.googleapis.com/v1/projects/{SA['project_id']}/messages:send"
    payload = {
        "message": {
            "token": fcm_token,
            "notification": {"title": title, "body": body},
            "android": {
                "priority": "HIGH",
                "notification": {
                    "channel_id": "academia_default",
                    "sound": "default",
                    "default_vibrate_timings": True,
                    "default_light_settings": True,
                    "visibility": "PUBLIC",
                    "notification_priority": "PRIORITY_MAX",
                },
            },
        }
    }
    r = requests.post(url, headers={
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
    }, json=payload, timeout=15)
    return r.status_code, r.json() if r.text else {}

def q(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=30)
    d = r.json() if r.text else {}
    rows = d.get('rows', []) if isinstance(d, dict) else []
    print(f"\n{'✅' if d.get('ok') else '❌'} {label}")
    for row in (rows or [])[:10]:
        print(f"  {json.dumps(row, ensure_ascii=False, default=str)[:400]}")
    if not rows: print("  (0 rows)")
    return rows

m = SupabaseAutoManager()
print("=" * 70)
print("AUDIT DEEP V2 — TEST FCM DIRECT TOKEN PAR TOKEN")
print("=" * 70)

# 1. Get ALL active android tokens for user 6745c7ad (nexiomgroup — TECNO KG7h user)
user_id = "6745c7ad-732b-47d0-b5b8-06d6dcf286ff"
rows = q(m, f"ALL active Android tokens for user {user_id[:8]}", f"""
SELECT id, fcm_token, platform, is_active, updated_at, created_at
FROM app.user_device_tokens
WHERE user_id = '{user_id}' AND platform = 'android' AND is_active = true
ORDER BY updated_at DESC
""")

if not rows:
    print("❌ NO active Android tokens for this user!")
    exit(1)

# 2. Get FCM access token
print(f"\n{'='*70}")
print("2. Getting FCM OAuth2 access token...")
access_token = get_fcm_access_token()
if not access_token:
    print("❌ Cannot get FCM access token!")
    exit(1)
print(f"✅ FCM access token obtained ({len(access_token)} chars)")

# 3. Send push to EACH token individually and show FULL response
print(f"\n{'='*70}")
print(f"3. Sending push to EACH token individually...")
for i, row in enumerate(rows):
    token = row['fcm_token']
    token_id = row['id']
    updated = row['updated_at']
    print(f"\n--- Token {i+1}/{len(rows)} ---")
    print(f"  ID: {token_id}")
    print(f"  Token: {token[:40]}...")
    print(f"  Updated: {updated}")
    
    status, resp = send_fcm_direct(
        access_token, token,
        "🔔 Test DIRECT Academia",
        "Si tu vois ceci, les notifications marchent!"
    )
    print(f"  FCM Response: HTTP {status}")
    print(f"  Body: {json.dumps(resp, indent=2)[:500]}")
    
    if status == 200:
        print(f"  ✅ PUSH ACCEPTED by FCM — should arrive on device")
    elif status == 404:
        print(f"  ❌ TOKEN INVALID/UNREGISTERED — deactivating...")
        q(m, f"Deactivate token {token_id}", f"""
        UPDATE app.user_device_tokens SET is_active = false WHERE id = '{token_id}'
        """)
    else:
        print(f"  ⚠️ FCM error {status}")

# 4. Check Firebase Cloud Messaging API status
print(f"\n{'='*70}")
print("4. Checking if FCM API is reachable...")
# Try sending a dry-run / validate-only message
dry_url = f"https://fcm.googleapis.com/v1/projects/{SA['project_id']}/messages:send"
dry_payload = {
    "validate_only": True,
    "message": {
        "token": rows[0]['fcm_token'],
        "notification": {"title": "dry-run", "body": "test"},
    }
}
dr = requests.post(dry_url, headers={
    "Authorization": f"Bearer {access_token}",
    "Content-Type": "application/json",
}, json=dry_payload, timeout=15)
print(f"  Validate-only: HTTP {dr.status_code}")
print(f"  Response: {dr.text[:300]}")

print(f"\n{'='*70}")
print("AUDIT DEEP V2 TERMINÉ")
print(f"{'='*70}")
