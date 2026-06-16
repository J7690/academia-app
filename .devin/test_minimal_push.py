#!/usr/bin/env python3
"""Send MINIMAL FCM push to test if advanced fields cause silent drop on Android 10."""
import json, time, requests, jwt

SA = {
    "project_id": "academia-e2c41",
    "client_email": "firebase-adminsdk-fbsvc@academia-e2c41.iam.gserviceaccount.com",
    "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDGZpajtvuc2WRL\nk8VufyesySYq/a30mzLdPg/rbpfTfZI6pd1f4LclTFN52ipKhnNTmOc9bnoo6WXc\nseyCjfGCPYzysIXSs2IOI/ky3Xw4W0fnRlGMbMcn7XwkmcJ9zlXI9ulVyTDPIJ7B\nCGeHPqPa+PQ5yuzeU2WBTRo2li0aWLlEnXXj6gCSmBuiRQmO6We0hOVVKLCrFhIJ\nf+l85/Y2zOVRijGdP2xLPeVnM8ZlTQ2cNaH48oiyZroN7EzS9Eo3UFpXkSBNI6lL\nOuNdoLb26Sx8a3avWa0oNSnagHHJt5hUshnKTOlLyCbNfYN98Fby+hc3VOJKs8I9\nMNg0iN1ZAgMBAAECggEADVAF7J9TG8+0fKPCPCtZEK2Am6LhAMhHLfRDojMOCflj\njf7iL1RHRb/s3ADJFK4X3/SjE4qttMAQfzILIil/GpOhuQkiOaSiwDsmtgSJmMh7\nNygPQcJszJ+RVG1i0Qk+1VjICGMTHNrd/Crhs3//A6rvzE7y/OoQpg/z4dTK2vkZ\n0zsuO+/ILITxa5S/8foNHQWuasyOSE3Dwccaal+6FyDCTddH+2K1W87qRn+w8jtK\nzAEjt3HbPCMK7Jpd+zy2TGhDJumFyGoTMnygNb80Kt+VQeDV3n+9gjmAkGKZZPWj\nreWhPPaA8zdvizOdGj/FRQ3kcOWfFu+JPcXVUcWu/wKBgQDriUCv1Ima24UK65mc\nujpYlq+xARrSczaPfOptE149EwiX2J5Fj8Bz7PmgvXjPwr6ahIzPikYZbhUntbZd\n2UPbm1YwYMuIZChZGu0XFqA4yPmZyGnzIVdiBPyDocDY4acNQCq+UOle03aQ7bLG\nn8r510codEqI+xxMNITVwQhPpwKBgQDXo2CloKagjYgFxItChkTA3xbQ7XO100Zm\nuE+7uOfb2CAVFd0sxylK8fEh6eoIimIleYW8EqkikbL9oEr5KCmaszsDCYHC/iat\nRUz4s+XdU8LMVpDLomgrS8vjF4b/AxMJ10w7c1l5i7X9sUTiTtQJUWv/gsvxezdl\nbLW54VMK/wKBgG7Gq8TGmj1Z91Wufx3GPIDDxjfihCHsjAGqR3sre8wPsp/wAmhG\n9sXO84zU8AgO2KRFqRBHQTbenlaB0RaMg6y6fyvbqn4oVQ2ra0zLmGl8pF/ecW4n\nBTkVjUm/frrCTlYeErxVw5yUqhP5p3ZhWw5sYIw3PYL1T1bL8Jmz4tvLAoGBAIxw\n6JIWlk88vllbT4ONJRwkb5y0+cZzCof+BFfzrnY9RW/WJI10TM1106FN0lGrpw5X\nHiWGVceg8t1CV3H8mVQa5RUuTOftVM1GtEHKEKxcUCN7QaSOap/AJtMJUK+nle+z\n2/9gOebyeh33JTDrPCexctAfpKnqoQKakaS1PruLAoGAYvDR1CtFtS7ENYYwMLbq\nSkVYalMunHSQy1jkiUe48JYjcfa/D+lUD2C3NO/YPikLEh1YJYrKbFHB/Ce51eec\nlCwFJU+NTybtQO9M33bqu3g73K89+aXR7LN9zWnau1V04zLyiqdpFxgMClynueDx\nP1YvEYxnsFkebj/SJZ3hSoM=\n-----END PRIVATE KEY-----\n",
    "token_uri": "https://oauth2.googleapis.com/token",
}

def get_token():
    now = int(time.time())
    payload = {"iss": SA["client_email"], "sub": SA["client_email"],
               "aud": SA["token_uri"], "iat": now, "exp": now + 3600,
               "scope": "https://www.googleapis.com/auth/firebase.messaging"}
    token = jwt.encode(payload, SA["private_key"], algorithm="RS256")
    r = requests.post(SA["token_uri"], data={
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion": token}, timeout=15)
    return r.json().get("access_token")

access_token = get_token()
url = f"https://fcm.googleapis.com/v1/projects/{SA['project_id']}/messages:send"
# Most recent LD7 token
fcm_token = "dhiNV3tWRZK1vj00hSO89O:APA91bGr2I5yY4bw1LjrZ8rwi8K4y4tlfSj-01tFQS5nig3L1LRzRKwhrV0eLi2d4rn-v0xnDCTeCHDrLv62oj2w2JVn2oARIcKN1H1VUIZ63Fb-N9F2F7M"

# TEST 1: BARE MINIMUM — just notification title/body, no android config
print("=" * 60)
print("TEST 1: BARE MINIMUM (no android config)")
r = requests.post(url, headers={"Authorization": f"Bearer {access_token}", "Content-Type": "application/json"},
    json={"message": {"token": fcm_token, "notification": {"title": "TEST 1 - Minimal", "body": "Si tu vois ceci, le push marche!"}}},
    timeout=15)
print(f"  HTTP {r.status_code} — {r.text[:200]}")

# TEST 2: With channel_id only
print("\nTEST 2: With channel_id only")
r = requests.post(url, headers={"Authorization": f"Bearer {access_token}", "Content-Type": "application/json"},
    json={"message": {"token": fcm_token, "notification": {"title": "TEST 2 - Channel", "body": "Avec channel academia_default"},
          "android": {"notification": {"channel_id": "academia_default"}}}},
    timeout=15)
print(f"  HTTP {r.status_code} — {r.text[:200]}")

# TEST 3: With HIGH priority + channel
print("\nTEST 3: HIGH priority + channel")
r = requests.post(url, headers={"Authorization": f"Bearer {access_token}", "Content-Type": "application/json"},
    json={"message": {"token": fcm_token, "notification": {"title": "TEST 3 - Priority HIGH", "body": "Avec priority HIGH"},
          "android": {"priority": "HIGH", "notification": {"channel_id": "academia_default"}}}},
    timeout=15)
print(f"  HTTP {r.status_code} — {r.text[:200]}")

# TEST 4: DATA-ONLY message (no notification, just data)
print("\nTEST 4: DATA-ONLY (no notification payload)")
r = requests.post(url, headers={"Authorization": f"Bearer {access_token}", "Content-Type": "application/json"},
    json={"message": {"token": fcm_token, "data": {"title": "TEST 4 - Data only", "body": "Message data-only", "type": "test"},
          "android": {"priority": "HIGH"}}},
    timeout=15)
print(f"  HTTP {r.status_code} — {r.text[:200]}")

print("\n" + "=" * 60)
print("4 tests envoyés. Vérifie le TECNO LD7 MAINTENANT.")
print("Dis-moi QUEL numéro de test tu vois (1, 2, 3, 4, ou aucun).")
