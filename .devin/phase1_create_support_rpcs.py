import requests, json, sys
sys.path.append('.windsurf')
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()

    print('=== PHASE 1 - CRÉATION RPCs SUPPORT ADMIN ===')
    
    # RPC 1: Vérification conversation existante
    rpc1_sql = """
    CREATE OR REPLACE FUNCTION public.app_admin_check_support_conversation(
        p_user_email TEXT
    ) RETURNS JSONB
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $function$
    DECLARE
        v_user_id UUID;
        v_conv_id UUID;
    BEGIN
        -- Mapping email → user_id via auth.users (validé dans l'audit)
        SELECT id INTO v_user_id 
        FROM auth.users 
        WHERE email = p_user_email;
        
        IF v_user_id IS NULL THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'user_not_found');
        END IF;
        
        -- Vérification conversation existante via requester_user_id (validé)
        SELECT id INTO v_conv_id
        FROM app.support_conversations 
        WHERE requester_user_id = v_user_id;
        
        RETURN JSONB_BUILD_OBJECT('success', TRUE, 'conversation_id', v_conv_id);
    END;
    $function$;
    """

    print('\n1. Création RPC app_admin_check_support_conversation...')
    url = f'{m.url}/rest/v1/rpc/admin_execute_sql'
    r1 = requests.post(url, headers=m.headers, json={'p_sql': rpc1_sql.strip()}, timeout=30)
    data1 = r1.json() if r1.text else {}
    
    if data1.get('ok'):
        print('   ✅ RPC 1 créée avec succès')
    else:
        print(f'   ❌ Erreur RPC 1: {data1}')
        return

    # RPC 2: Création conversation admin
    rpc2_sql = """
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
        v_admin_id UUID := auth.uid();
    BEGIN
        -- Récupération infos utilisateur (validé dans l'audit)
        SELECT u.id, u.email, COALESCE(s.full_name, u.email)
        INTO v_user_id, v_user_email, v_user_name
        FROM auth.users u
        LEFT JOIN app.students s ON s.id = u.id
        WHERE u.email = p_user_email;
        
        IF v_user_id IS NULL THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'user_not_found');
        END IF;
        
        -- Création conversation avec structure validée
        INSERT INTO app.support_conversations (
            requester_user_id, requester_role, requester_display_name, 
            requester_email, status, created_at, last_message_at
        ) VALUES (
            v_user_id, 'student', v_user_name, v_user_email, 
            'open', NOW(), NOW()
        ) RETURNING id INTO v_conv_id;
        
        -- Message initial optionnel avec structure validée
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

    print('\n2. Création RPC app_admin_create_support_conversation...')
    r2 = requests.post(url, headers=m.headers, json={'p_sql': rpc2_sql.strip()}, timeout=30)
    data2 = r2.json() if r2.text else {}
    
    if data2.get('ok'):
        print('   ✅ RPC 2 créée avec succès')
    else:
        print(f'   ❌ Erreur RPC 2: {data2}')
        return

    print('\n=== PHASE 1 TERMINÉE AVEC SUCCÈS ===')

if __name__ == '__main__':
    main()
