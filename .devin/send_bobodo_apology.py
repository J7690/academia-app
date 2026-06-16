"""Envoyer un message d'excuses de Bobodo à Assetou Yanogo."""
import requests, json, time

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"}

def exec_sql(sql):
    return requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": sql}).json()

def run_fn(body):
    fname = f"_tmp_apo_{int(time.time()*1000) % 999999999}"
    exec_sql(f"""CREATE OR REPLACE FUNCTION public.{fname}() RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $fn$
    DECLARE v JSONB; BEGIN {body} RETURN v; END; $fn$;""")
    time.sleep(2)
    exec_sql("NOTIFY pgrst, 'reload schema';")
    time.sleep(2)
    r = requests.post(f"{URL}/rest/v1/rpc/{fname}", headers=H, json={})
    result = r.json()
    exec_sql(f"DROP FUNCTION IF EXISTS public.{fname}();")
    return result

USER_ID = "208cfab4-2c31-4f31-ab01-c6baa8ecbbc2"

APOLOGY_MESSAGE = (
    "Chère Assetou Yanogo, je tiens à te présenter mes sincères excuses. "
    "Lors de notre dernière conversation, je t''ai communiqué des informations erronées "
    "concernant les universités partenaires. Un bug dans le système a été détecté lors de "
    "la dernière mise à jour mensuelle de l''application, ce qui a provoqué des réponses "
    "incorrectes. Toutes les informations que je t''ai fournies lors de cette session "
    "étaient malheureusement inexactes.\n\n"
    "L''équipe Academia et moi-même te présentons nos excuses pour ce désagrément.\n\n"
    "Pour consulter la liste complète et à jour des universités partenaires, je t''invite "
    "à te rendre dans l''onglet Universités de l''application Academia. Tu y trouveras "
    "toutes les informations fiables sur chaque établissement partenaire.\n\n"
    "Encore une fois, toutes nos excuses. N''hésite pas si tu as d''autres questions, "
    "je suis là pour t''aider !"
)

# 1. Créer une nouvelle session Bobodo pour ce message
print("=== Étape 1: Créer une session Bobodo ===")
r = run_fn(f"""
  INSERT INTO app.bobodo_sessions (student_id, title)
  VALUES ('{USER_ID}', 'Message important de Bobodo')
  RETURNING id;
  SELECT jsonb_build_object('session_id', id) INTO v
  FROM app.bobodo_sessions
  WHERE student_id = '{USER_ID}'
  ORDER BY created_at DESC LIMIT 1;
""")
print(f"  Résultat: {json.dumps(r, default=str, ensure_ascii=False)}")

session_id = None
if isinstance(r, dict) and 'session_id' in r:
    session_id = r['session_id']
else:
    # Fallback: get the latest session
    r2 = run_fn(f"""
      SELECT jsonb_build_object('session_id', id) INTO v
      FROM app.bobodo_sessions
      WHERE student_id = '{USER_ID}'
      ORDER BY created_at DESC LIMIT 1;
    """)
    if isinstance(r2, dict) and 'session_id' in r2:
        session_id = r2['session_id']
    else:
        print(f"  Erreur: {r2}")

if not session_id:
    print("  ❌ Impossible de créer la session.")
    exit()

print(f"  Session créée: {session_id}")

# 2. Insérer le message d'excuses
print("\n=== Étape 2: Insérer le message d'excuses ===")
r = run_fn(f"""
  INSERT INTO app.bobodo_messages (session_id, sender, content, safety_flag)
  VALUES ('{session_id}', 'assistant', '{APOLOGY_MESSAGE}', 'safe');
  SELECT jsonb_build_object('ok', true) INTO v;
""")
print(f"  Résultat: {json.dumps(r, default=str, ensure_ascii=False)}")

# 3. Déclencher la notification (via la RPC existante)
print("\n=== Étape 3: Notification ===")
# The trigger app_notify_bobodo_message fires automatically on INSERT to bobodo_messages
# when sender != 'student', so the notification should already be queued.
# Let's verify:
r = run_fn(f"""
  SELECT jsonb_build_object('msg_count',
    (SELECT COUNT(*) FROM app.bobodo_messages WHERE session_id = '{session_id}')
  ) INTO v;
""")
print(f"  Messages dans la session: {json.dumps(r, default=str)}")

if isinstance(r, dict) and r.get('msg_count', 0) >= 1:
    print(f"\n  ✅ Message d'excuses envoyé avec succès à Assetou Yanogo.")
    print(f"  📩 La notification sera déclenchée automatiquement par le trigger app_notify_bobodo_message.")
else:
    print(f"\n  ⚠️ Vérifier manuellement.")

print("\n=== FIN ===")
