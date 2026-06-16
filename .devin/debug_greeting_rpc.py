#!/usr/bin/env python3
"""Debug: vérifier pourquoi le greeting se répète (app_has_bobodo_assistant_message)."""
from __future__ import annotations
import requests
from supabase_auto_manager import SupabaseAutoManager

def q(m, sql):
    r = requests.post(f"{m.url}/rest/v1/rpc/execute_sql",
        headers=m.headers, json={"sql_query": sql}, timeout=30)
    return r.json() if isinstance(r.json(), list) else [r.json()] if r.json() else []

m = SupabaseAutoManager()
print("\n🔍 DEBUG GREETING RPC\n")

# 1. Lire le corps de app_has_bobodo_assistant_message
body = q(m,
    "SELECT prosrc FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
    "WHERE n.nspname='app' AND p.proname='app_has_bobodo_assistant_message'")
if body:
    print("═══ Corps de app_has_bobodo_assistant_message ═══")
    print(body[0].get("prosrc", "?"))
    print()

# 2. Tester manuellement sur la session problématique
sessions = q(m,
    "SELECT DISTINCT session_id FROM app.bobodo_messages "
    "WHERE sender='assistant' ORDER BY session_id LIMIT 3")

for s in sessions[:1]:
    sid = s.get("session_id")
    print(f"Session: {sid}")

    # Compter les messages assistant
    count = q(m,
        f"SELECT COUNT(*) AS n FROM app.bobodo_messages "
        f"WHERE session_id='{sid}' AND sender='assistant'")
    print(f"  Messages assistant: {count[0].get('n','?')}")

    # Appeler la RPC directement
    url = f"{m.url}/rest/v1/rpc/app_has_bobodo_assistant_message"
    r = requests.post(url, headers=m.headers,
        json={"p_session_id": sid}, timeout=10)
    print(f"  RPC directe HTTP {r.status_code}: {r.text[:200]}")

# 3. Vérifier le type de retour de la RPC
ret_type = q(m,
    "SELECT p.prorettype::regtype AS return_type "
    "FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
    "WHERE n.nspname='app' AND p.proname='app_has_bobodo_assistant_message'")
print(f"\n  Return type: {ret_type}")

# 4. Vérifier si la session récente (09:28-09:30) a le problème
recent_sess = q(m,
    "SELECT session_id FROM app.bobodo_messages "
    "WHERE created_at > '2026-03-25 09:20:00' "
    "GROUP BY session_id "
    "ORDER BY MAX(created_at) DESC LIMIT 1")
if recent_sess:
    sid = recent_sess[0]["session_id"]
    print(f"\n═══ Session récente: {sid} ═══")
    msgs = q(m,
        f"SELECT sender, LEFT(content, 80) AS content_preview, created_at "
        f"FROM app.bobodo_messages "
        f"WHERE session_id='{sid}' ORDER BY created_at ASC")
    for msg in msgs:
        prefix = "🟦" if msg["sender"] == "student" else "🟩"
        print(f"  {prefix} [{str(msg['created_at'])[:19]}] {msg['content_preview']}")

    # Tester la RPC
    r = requests.post(f"{m.url}/rest/v1/rpc/app_has_bobodo_assistant_message",
        headers=m.headers, json={"p_session_id": sid}, timeout=10)
    print(f"\n  RPC résultat: {r.text}")
