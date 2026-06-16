import requests, json, sys
sys.path.append('.windsurf')
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()

    print('=== VALIDATION RPCs CRÉÉES ===')
    
    # Test RPC 1 avec un email connu
    test_email = 'nexiomgroup@gmail.com'  # Email identifié dans l'audit
    
    print(f'\n1. Test RPC app_admin_check_support_conversation avec {test_email}...')
    
    sql1 = """
    SELECT * FROM app_admin_check_support_conversation('nexiomgroup@gmail.com')
    """
    
    url = f'{m.url}/rest/v1/rpc/admin_execute_sql'
    r1 = requests.post(url, headers=m.headers, json={'p_sql': sql1.strip()}, timeout=30)
    data1 = r1.json() if r1.text else {}
    
    if data1.get('ok') and data1.get('rows'):
        result = data1['rows'][0]['app_admin_check_support_conversation']
        print(f'   Résultat: {result}')
        
        # Vérifier si conversation_id correspond à l'audit
        if result.get('success') and result.get('conversation_id'):
            conv_id = result['conversation_id']
            print(f'   ✅ Conversation existante trouvée: {conv_id}')
            
            # Vérifier que cette conversation existe bien
            sql_check = f"""
            SELECT id, requester_email, status 
            FROM app.support_conversations 
            WHERE id = '{conv_id}'
            """
            r_check = requests.post(url, headers=m.headers, json={'p_sql': sql_check.strip()}, timeout=30)
            data_check = r_check.json() if r_check.text else {}
            
            if data_check.get('ok') and data_check.get('rows'):
                conv = data_check['rows'][0]
                print(f'   ✅ Vérification: Email={conv["requester_email"]}, Status={conv["status"]}')
        else:
            print('   ✅ Aucune conversation existante (normal)')
    else:
        print(f'   ❌ Erreur: {data1}')

    # Test RPC 2 avec un email sans conversation
    test_email2 = 's30934487@gmail.com'  # Email identifié dans l'audit sans conversation
    
    print(f'\n2. Test RPC app_admin_create_support_conversation avec {test_email2}...')
    
    sql2 = """
    SELECT * FROM app_admin_create_support_conversation('s30934487@gmail.com', 'Message de test admin')
    """
    
    r2 = requests.post(url, headers=m.headers, json={'p_sql': sql2.strip()}, timeout=30)
    data2 = r2.json() if r2.text else {}
    
    if data2.get('ok') and data2.get('rows'):
        result = data2['rows'][0]['app_admin_create_support_conversation']
        print(f'   Résultat: {result}')
        
        if result.get('success') and result.get('conversation_id'):
            conv_id = result['conversation_id']
            print(f'   ✅ Nouvelle conversation créée: {conv_id}')
            
            # Vérifier la création
            sql_check2 = f"""
            SELECT id, requester_email, requester_display_name, status
            FROM app.support_conversations 
            WHERE id = '{conv_id}'
            """
            r_check2 = requests.post(url, headers=m.headers, json={'p_sql': sql_check2.strip()}, timeout=30)
            data_check2 = r_check2.json() if r_check2.text else {}
            
            if data_check2.get('ok') and data_check2.get('rows'):
                conv = data_check2['rows'][0]
                print(f'   ✅ Vérification: Email={conv["requester_email"]}, Name={conv["requester_display_name"]}, Status={conv["status"]}')
                
                # Vérifier le message initial
                sql_msg = f"""
                SELECT content, sender_side 
                FROM app.support_messages 
                WHERE conversation_id = '{conv_id}'
                """
                r_msg = requests.post(url, headers=m.headers, json={'p_sql': sql_msg.strip()}, timeout=30)
                data_msg = r_msg.json() if r_msg.text else {}
                
                if data_msg.get('ok') and data_msg.get('rows'):
                    msg = data_msg['rows'][0]
                    print(f'   ✅ Message initial: \"{msg["content"]}\" ({msg["sender_side"]})')
        else:
            print(f'   ❌ Erreur création: {result}')
    else:
        print(f'   ❌ Erreur: {data2}')

    print('\n=== VALIDATION TERMINÉE ===')

if __name__ == '__main__':
    main()
