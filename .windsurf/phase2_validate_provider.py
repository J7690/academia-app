import requests, json, sys
sys.path.append('.windsurf')
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()

    print('=== VALIDATION EXTENSION PROVIDER ===')
    
    # Vérifier que les méthodes RPC sont bien appelables
    print('\n1. Test RPC checkSupportConversationExists...')
    
    sql1 = """
    SELECT * FROM app_admin_check_support_conversation('nexiomgroup@gmail.com')
    """
    
    url = f'{m.url}/rest/v1/rpc/admin_execute_sql'
    r1 = requests.post(url, headers=m.headers, json={'p_sql': sql1.strip()}, timeout=30)
    data1 = r1.json() if r1.text else {}
    
    if data1.get('ok') and data1.get('rows'):
        result = data1['rows'][0]['app_admin_check_support_conversation']
        print(f'   ✅ RPC 1 accessible: {result}')
    else:
        print(f'   ❌ RPC 1 inaccessible: {data1}')
        return

    print('\n2. Test RPC createSupportConversation...')
    
    sql2 = """
    SELECT * FROM app_admin_create_support_conversation('test-validation@academia.com', 'Test validation provider')
    """
    
    r2 = requests.post(url, headers=m.headers, json={'p_sql': sql2.strip()}, timeout=30)
    data2 = r2.json() if r2.text else {}
    
    if data2.get('ok') and data2.get('rows'):
        result = data2['rows'][0]['app_admin_create_support_conversation']
        print(f'   ✅ RPC 2 accessible: {result}')
        
        # Nettoyer le test
        if result.get('success') and result.get('conversation_id'):
            conv_id = result['conversation_id']
            sql_clean = f"""
            DELETE FROM app.support_messages WHERE conversation_id = '{conv_id}';
            DELETE FROM app.support_conversations WHERE id = '{conv_id}';
            """
            requests.post(url, headers=m.headers, json={'p_sql': sql_clean.strip()}, timeout=30)
            print('   ✅ Test nettoyé')
    else:
        print(f'   ❌ RPC 2 inaccessible: {data2}')

    print('\n3. Vérification structure AdminUsersOverviewProvider...')
    
    # Vérifier que le provider utilise bien la RPC app_admin_list_users_overview
    sql3 = """
    SELECT pg_get_functiondef(p.oid) as source
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.proname = 'app_admin_list_users_overview'
    """
    
    r3 = requests.post(url, headers=m.headers, json={'p_sql': sql3.strip()}, timeout=30)
    data3 = r3.json() if r3.text else {}
    
    if data3.get('ok') and data3.get('rows'):
        source = data3['rows'][0]['source']
        if 'app_admin_list_users_overview()' in source:
            print('   ✅ Provider utilise la bonne RPC')
        else:
            print('   ❌ Provider utilise une autre RPC')
    else:
        print(f'   ❌ RPC provider non trouvée: {data3}')

    print('\n=== VALIDATION PROVIDER TERMINÉE ===')

if __name__ == '__main__':
    main()
