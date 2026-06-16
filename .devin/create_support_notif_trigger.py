"""Créer le trigger + function pour notifier TOUS les admins quand un utilisateur envoie un message support."""
import requests, json, time

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"}

def exec_sql(sql):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": sql})
    return r.json()

# 1. Create the trigger function
print("=== 1. Création de la fonction trigger ===")
r = exec_sql("""
CREATE OR REPLACE FUNCTION public.app_notify_admin_support_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn$
DECLARE
    v_admin RECORD;
    v_requester_name TEXT;
    v_conversation_id UUID;
BEGIN
    -- Ne notifier que les messages côté utilisateur (pas les réponses admin)
    IF NEW.sender_side = 'admin' THEN
        RETURN NEW;
    END IF;

    v_conversation_id := NEW.conversation_id;

    -- Récupérer le nom de l'utilisateur
    SELECT COALESCE(requester_display_name, requester_email, 'Utilisateur')
    INTO v_requester_name
    FROM app.support_conversations
    WHERE id = v_conversation_id;

    -- Notifier TOUS les admins
    FOR v_admin IN
        SELECT id FROM auth.users
        WHERE raw_user_meta_data->>'role' = 'admin'
    LOOP
        PERFORM app_queue_notification_event(
            v_admin.id,
            'admin_support',
            'new_message',
            JSONB_BUILD_OBJECT(
                'conversation_id', v_conversation_id,
                'message_id', NEW.id,
                'requester_name', v_requester_name,
                'content_preview', LEFT(NEW.content, 100),
                'sender_side', NEW.sender_side
            )
        );
    END LOOP;

    RETURN NEW;
END;
$fn$
""")
print(f"  Résultat: {json.dumps(r, default=str)}")

# 2. Create the trigger on support_messages
print("\n=== 2. Création du trigger ===")
r = exec_sql("""
DROP TRIGGER IF EXISTS trg_notify_admin_support_message ON app.support_messages
""")
print(f"  Drop existing: {r}")

r = exec_sql("""
CREATE TRIGGER trg_notify_admin_support_message
    AFTER INSERT ON app.support_messages
    FOR EACH ROW
    EXECUTE FUNCTION public.app_notify_admin_support_message()
""")
print(f"  Create trigger: {r}")

# 3. Also create a trigger for NEW conversations (first contact)
print("\n=== 3. Trigger pour nouvelles conversations ===")
r = exec_sql("""
CREATE OR REPLACE FUNCTION public.app_notify_admin_new_support_conversation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn$
DECLARE
    v_admin RECORD;
BEGIN
    -- Notifier TOUS les admins d'une nouvelle conversation support
    FOR v_admin IN
        SELECT id FROM auth.users
        WHERE raw_user_meta_data->>'role' = 'admin'
    LOOP
        PERFORM app_queue_notification_event(
            v_admin.id,
            'admin_support',
            'new_conversation',
            JSONB_BUILD_OBJECT(
                'conversation_id', NEW.id,
                'requester_name', COALESCE(NEW.requester_display_name, NEW.requester_email, 'Utilisateur'),
                'requester_role', NEW.requester_role
            )
        );
    END LOOP;

    RETURN NEW;
END;
$fn$
""")
print(f"  Function: {r}")

r = exec_sql("DROP TRIGGER IF EXISTS trg_notify_admin_new_support_conversation ON app.support_conversations")
print(f"  Drop existing: {r}")

r = exec_sql("""
CREATE TRIGGER trg_notify_admin_new_support_conversation
    AFTER INSERT ON app.support_conversations
    FOR EACH ROW
    EXECUTE FUNCTION public.app_notify_admin_new_support_conversation()
""")
print(f"  Create trigger: {r}")

# 4. Verify triggers exist
print("\n=== 4. Vérification ===")
time.sleep(1)

def run_fn(body):
    fname = f"_tmp_sv_{int(time.time()*1000) % 999999999}"
    exec_sql(f"""CREATE OR REPLACE FUNCTION public.{fname}() RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $fn$
    DECLARE v JSONB; BEGIN {body} RETURN v; END; $fn$;""")
    time.sleep(2)
    exec_sql("NOTIFY pgrst, 'reload schema'")
    time.sleep(2)
    r = requests.post(f"{URL}/rest/v1/rpc/{fname}", headers=H, json={})
    result = r.json()
    exec_sql(f"DROP FUNCTION IF EXISTS public.{fname}()")
    return result

r = run_fn("""
  SELECT jsonb_agg(jsonb_build_object('table', c.relname, 'trigger', t.tgname, 'func', p.proname))
  INTO v
  FROM pg_trigger t
  JOIN pg_class c ON t.tgrelid = c.oid
  JOIN pg_namespace n ON c.relnamespace = n.oid
  JOIN pg_proc p ON t.tgfoid = p.oid
  WHERE n.nspname = 'app'
    AND c.relname IN ('support_messages', 'support_conversations')
    AND p.proname LIKE '%notify_admin%';
""")
print(f"  Triggers actifs: {json.dumps(r, default=str, ensure_ascii=False)}")

print("\n=== FIN ===")
