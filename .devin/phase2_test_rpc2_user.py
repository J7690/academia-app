import requests, json, sys
sys.path.append('.windsurf')
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()

    print('=== TEST CRÉATION UTILISATEUR POUR RPC 2 ===')
    
    # Créer un utilisateur de test pour valider RPC 2
    print('\n1. Création utilisateur test@academia.com...')
    
    sql_create_user = """
    -- Créer un utilisateur test
    INSERT INTO auth.users (
        id, 
        email, 
        email_confirmed_at, 
        created_at, 
        updated_at,
        raw_user_meta_data
    ) VALUES (
        gen_random_uuid(),
        'test@academia.com',
        NOW(),
        NOW(),
        NOW(),
        '{"role": "student"}'
    ) RETURNING id
    """
    
    url = f'{m.url}/rest/v1/rpc/admin_execute_sql'
    r_create = requests.post(url, headers=m.headers, json={'p_sql': sql_create_user.strip()}, timeout=30)
    data_create = r_create.json() if r_create.text else {}
    
    if not data_create.get('ok') or not data_create.get('rows'):
        print('   ❌ Impossible de créer utilisateur test')
        print(f'   Erreur: {data_create}')
        return
    
    user_id = data_create['rows'][0]['id']
    print(f'   ✅ Utilisateur test créé: {user_id}')
    
    # Créer l'entrée students correspondante
    sql_create_student = f"""
    INSERT INTO app.students (
        id, 
        full_name, 
        created_at, 
        updated_at
    ) VALUES (
        '{user_id}',
        'Test User',
        NOW(),
        NOW()
    )
    """
    
    r_student = requests.post(url, headers=m.headers, json={'p_sql': sql_create_student.strip()}, timeout=30)
    data_student = r_student.json() if r_student.text else {}
    
    if data_student.get('ok'):
        print('   ✅ Entrée students créée')
    else:
        print(f'   ❌ Erreur création students: {data_student}')
    
    # Maintenant tester RPC 2 avec cet utilisateur
    print('\n2. Test RPC 2 avec utilisateur test@academia.com...')
    
    sql_test = """
    SELECT * FROM app_admin_create_support_conversation('test@academia.com', 'Test depuis provider')
    """
    
    r_test = requests.post(url, headers=m.headers, json={'p_sql': sql_test.strip()}, timeout=30)
    data_test = r_test.json() if r_test.text else {}
    
    if data_test.get('ok') and data_test.get('rows'):
        result = data_test['rows'][0]['app_admin_create_support_conversation']
        print(f'   ✅ RPC 2 fonctionne: {result}')
        
        if result.get('success') and result.get('conversation_id'):
            conv_id = result['conversation_id']
            print(f'   ✅ Conversation créée: {conv_id}')
            
            # Nettoyer
            sql_clean = f"""
            DELETE FROM app.support_messages WHERE conversation_id = '{conv_id}';
            DELETE FROM app.support_conversations WHERE id = '{conv_id}';
            DELETE FROM app.students WHERE id = '{user_id}';
            DELETE FROM auth.users WHERE id = '{user_id}';
            """
            requests.post(url, headers=m.headers, json={'p_sql': sql_clean.strip()}, timeout=30)
            print('   ✅ Test nettoyé')
    else:
        print(f'   ❌ RPC 2 échoue: {data_test}')
    
    print('\n=== TEST RPC 2 TERMINÉ ===')

if __name__ == '__main__':
    main()
