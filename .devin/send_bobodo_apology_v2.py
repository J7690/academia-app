"""Envoyer message d'excuses de Bobodo à Assetou Yanogo — V2."""
import requests, json, time

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"}

def exec_sql(sql):
    return requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": sql}).json()

def run_fn(body):
    fname = f"_tmp_ap2_{int(time.time()*1000) % 999999999}"
    exec_sql(f"""CREATE OR REPLACE FUNCTION public.{fname}() RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $fn$
    DECLARE v JSONB; v_id UUID; BEGIN {body} RETURN v; END; $fn$;""")
    time.sleep(2)
    exec_sql("NOTIFY pgrst, 'reload schema'")
    time.sleep(2)
    r = requests.post(f"{URL}/rest/v1/rpc/{fname}", headers=H, json={})
    result = r.json()
    exec_sql(f"DROP FUNCTION IF EXISTS public.{fname}()")
    return result

USER_ID = "208cfab4-2c31-4f31-ab01-c6baa8ecbbc2"

APOLOGY = (
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

# Step 1: Create session + insert message in one function
print("=== Envoi du message d'excuses ===")
r = run_fn(f"""
  INSERT INTO app.bobodo_sessions (student_id, title)
  VALUES ('{USER_ID}', 'Message important de Bobodo')
  RETURNING id INTO v_id;

  INSERT INTO app.bobodo_messages (session_id, sender, content, safety_flag)
  VALUES (v_id, 'assistant', '{APOLOGY}', 'safe');

  v := jsonb_build_object('session_id', v_id, 'ok', true);
""")
print(f"  Résultat: {json.dumps(r, default=str, ensure_ascii=False)}")

if isinstance(r, dict) and r.get('ok') == True:
    sid = r.get('session_id', '')
    print(f"\n  ✅ Session créée: {sid}")
    print(f"  ✅ Message d'excuses inséré")
    print(f"  📩 Notification automatique via trigger app_notify_bobodo_message")
    print(f"\n  Assetou Yanogo verra ce message dans son chat Bobodo.")
else:
    print(f"\n  ❌ Erreur: {r}")

print("\n=== FIN ===")
