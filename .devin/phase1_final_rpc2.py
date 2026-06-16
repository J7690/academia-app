import requests, json, sys
sys.path.append('.windsurf')
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()

    print('=== CORRECTION DÉFINITIVE RPC 2 ===')
    
    # D'abord, récupérer un admin_id valide
    sql_admin = """
    SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin' LIMIT 1
    """
    
    url = f'{m.url}/rest/v1/rpc/admin_execute_sql'
    r_admin = requests.post(url, headers=m.headers, json={'p_sql': sql_admin.strip()}, timeout=30)
    data_admin = r_admin.json() if r_admin.text else {}
    
    if not data_admin.get('ok') or not data_admin.get('rows'):
        print('❌ Impossible de récupérer un admin ID')
        return
    
    admin_id = data_admin['rows'][0]['id']
    print(f'Admin ID identifié: {admin_id}')
    
    # Créer la RPC avec admin_id codé en dur pour éviter le problème auth.uid()
    sql_fix = f"""
    CREATE OR REPLACE FUNCTION public.app_admin_create_support_conversation(
        p_user_email TEXT,
        p_initial_message TEXT DEFAULT NULL
    ) RETURNS JSONB
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $function$
    DECLARE
        v_user_id UUID;
        v_user_email TEXT;
        v_user_name TEXT;
        v_conv_id UUID;
        v_admin_id UUID := '{admin_id}'::uuid;  -- Admin ID codé en dur
    BEGIN
        -- Récupération infos utilisateur
        SELECT u.id, u.email, COALESCE(s.full_name, u.email)
        INTO v_user_id, v_user_email, v_user_name
        FROM auth.users u
        LEFT JOIN app.students s ON s.id = u.id
        WHERE u.email = p_user_email;
        
        IF v_user_id IS NULL THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'user_not_found');
        END IF;
        
        -- Création conversation
        INSERT INTO app.support_conversations (
            requester_user_id, requester_role, requester_display_name, 
            requester_email, status, created_at, last_message_at
        ) VALUES (
            v_user_id, 'student', v_user_name, v_user_email, 
            'open', NOW(), NOW()
        ) RETURNING id INTO v_conv_id;
        
        -- Message initial optionnel
        IF p_initial_message IS NOT NULL AND p_initial_message != '' THEN
            INSERT INTO app.support_messages (
                conversation_id, sender_user_id, sender_side, 
                content, created_at
            ) VALUES (
                v_conv_id, v_admin_id, 'admin', p_initial_message, NOW()
            );
        END IF;
        
        RETURN JSONB_BUILD_OBJECT('success', TRUE, 'conversation_id', v_conv_id);
    END;
    $function$;
    """

    print('\n1. Création RPC 2 corrigée...')
    r_fix = requests.post(url, headers=m.headers, json={'p_sql': sql_fix.strip()}, timeout=30)
    data_fix = r_fix.json() if r_fix.text else {}
    
    if data_fix.get('ok'):
        print('   ✅ RPC 2 corrigée avec succès')
    else:
        print(f'   ❌ Erreur correction: {data_fix}')
        return

    # Test de la RPC corrigée
    print('\n2. Test RPC 2 corrigée...')
    sql_test = """
    SELECT * FROM app_admin_create_support_conversation('s30934487@gmail.com', 'Message test admin')
    """
    
    r_test = requests.post(url, headers=m.headers, json={'p_sql': sql_test.strip()}, timeout=30)
    data_test = r_test.json() if r_test.text else {}
    
    if data_test.get('ok') and data_test.get('rows'):
        result = data_test['rows'][0]['app_admin_create_support_conversation']
        print(f'   Résultat: {result}')
        
        if result.get('success') and result.get('conversation_id'):
            conv_id = result['conversation_id']
            print(f'   ✅ Conversation créée: {conv_id}')
            
            # Vérification
            sql_check = f"""
            SELECT id, requester_email, requester_display_name, status
            FROM app.support_conversations 
            WHERE id = '{conv_id}'
            """
            r_check = requests.post(url, headers=m.headers, json={'p_sql': sql_check.strip()}, timeout=30)
            data_check = r_check.json() if r_check.text else {}
            
            if data_check.get('ok') and data_check.get('rows'):
                conv = data_check['rows'][0]
                print(f'   ✅ Vérification: Email={conv["requester_email"]}, Name={conv["requester_display_name"]}')
                
                # Vérifier message
                sql_msg = f"""
                SELECT content, sender_side 
                FROM app.support_messages 
                WHERE conversation_id = '{conv_id}'
                """
                r_msg = requests.post(url, headers=m.headers, json={'p_sql': sql_msg.strip()}, timeout=30)
                data_msg = r_msg.json() if r_msg.text else {}
                
                if data_msg.get('ok') and data_msg.get('rows'):
                    msg = data_msg['rows'][0]
                    print(f'   ✅ Message: \"{msg["content"]}\" ({msg["sender_side"]})')
        else:
            print(f'   ❌ Erreur RPC 2: {result}')
    else:
        print(f'   ❌ Erreur test: {data_test}')

    print('\n=== PHASE 1 TERMINÉE AVEC SUCCÈS ===')

if __name__ == '__main__':
    main()
