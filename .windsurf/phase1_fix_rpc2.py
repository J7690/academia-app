import requests, json, sys
sys.path.append('.windsurf')
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()

    print('=== DIAGNOSTIC ERREUR RPC 2 ===')
    
    # Vérifier la session admin actuelle
    sql_session = """
    SELECT auth.uid() as current_admin_id, raw_user_meta_data->>'role' as role
    FROM auth.users 
    WHERE id = auth.uid()
    """
    
    url = f'{m.url}/rest/v1/rpc/admin_execute_sql'
    r_session = requests.post(url, headers=m.headers, json={'p_sql': sql_session.strip()}, timeout=30)
    data_session = r_session.json() if r_session.text else {}
    
    print('\n1. Session admin actuelle:')
    if data_session.get('ok') and data_session.get('rows'):
        session = data_session['rows'][0]
        print(f'   Admin ID: {session["current_admin_id"]}')
        print(f'   Role: {session["role"]}')
        admin_id = session["current_admin_id"]
    else:
        print(f'   ❌ Erreur session: {data_session}')
        return

    # Test avec admin_id explicite
    print('\n2. Test RPC 2 avec admin_id explicite...')
    
    sql_fix = """
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
        v_admin_id UUID;
    BEGIN
        -- Récupérer admin_id explicitement
        SELECT id INTO v_admin_id 
        FROM auth.users 
        WHERE raw_user_meta_data->>'role' = 'admin' 
        LIMIT 1;
        
        IF v_admin_id IS NULL THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'admin_not_found');
        END IF;
        
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

    r_fix = requests.post(url, headers=m.headers, json={'p_sql': sql_fix.strip()}, timeout=30)
    data_fix = r_fix.json() if r_fix.text else {}
    
    if data_fix.get('ok'):
        print('   ✅ RPC 2 corrigée avec succès')
    else:
        print(f'   ❌ Erreur correction: {data_fix}')
        return

    # Test de la RPC corrigée
    sql_test = """
    SELECT * FROM app_admin_create_support_conversation('s30934487@gmail.com', 'Message test admin')
    """
    
    r_test = requests.post(url, headers=m.headers, json={'p_sql': sql_test.strip()}, timeout=30)
    data_test = r_test.json() if r_test.text else {}
    
    if data_test.get('ok') and data_test.get('rows'):
        result = data_test['rows'][0]['app_admin_create_support_conversation']
        print(f'   Résultat test: {result}')
        
        if result.get('success'):
            print('   ✅ RPC 2 fonctionne correctement')
        else:
            print(f'   ❌ Erreur RPC 2: {result}')
    else:
        print(f'   ❌ Erreur test: {data_test}')

    print('\n=== DIAGNOSTIC TERMINÉ ===')

if __name__ == '__main__':
    main()
