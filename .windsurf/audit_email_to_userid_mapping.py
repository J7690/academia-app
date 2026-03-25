import requests, json, sys
sys.path.append('.windsurf')
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()

    print('=== AUDIT AUTH.USERS POUR DÉTECTION EMAIL → USER_ID ===')
    
    # Vérifier comment retrouver user_id depuis email
    sql = """
    SELECT 
        au.id,
        au.email,
        au.raw_user_meta_data->>'role' as role,
        s.id as student_id,
        s.full_name
    FROM auth.users au
    LEFT JOIN app.students s ON s.id = au.id
    WHERE au.email IN ('pawendtaorejoel@gmail.com', 'nexiomgroup@gmail.com')
    ORDER BY au.email
    """
    
    url = f'{m.url}/rest/v1/rpc/admin_execute_sql'
    r = requests.post(url, headers=m.headers, json={'p_sql': sql.strip()}, timeout=30)
    data = r.json() if r.text else {}
    
    print('\n1. MAPPING EMAIL → USER_ID:')
    if data.get('ok') and data.get('rows'):
        for row in data['rows']:
            print(f'   Email: {row["email"]}')
            print(f'   User ID: {row["id"]}')
            print(f'   Role: {row["role"]}')
            print(f'   Student ID: {row["student_id"]}')
            print(f'   Full Name: {row["full_name"]}')
            print('   ---')
    else:
        print(f'   Erreur: {data}')

    # Vérifier les conversations existantes pour ces utilisateurs
    sql2 = """
    SELECT 
        sc.id,
        sc.requester_user_id,
        sc.requester_email,
        sc.requester_display_name,
        sc.status,
        COUNT(sm.id) as message_count
    FROM app.support_conversations sc
    LEFT JOIN app.support_messages sm ON sm.conversation_id = sc.id
    WHERE sc.requester_email IN ('pawendtaorejoel@gmail.com', 'nexiomgroup@gmail.com')
    GROUP BY sc.id, sc.requester_user_id, sc.requester_email, sc.requester_display_name, sc.status
    ORDER BY sc.created_at DESC
    """
    
    r2 = requests.post(url, headers=m.headers, json={'p_sql': sql2.strip()}, timeout=30)
    data2 = r2.json() if r2.text else {}
    
    print('\n2. CONVERSATIONS EXISTANTES:')
    if data2.get('ok') and data2.get('rows'):
        for row in data2['rows']:
            print(f'   Email: {row["requester_email"]}')
            print(f'   Conversation ID: {row["id"]}')
            print(f'   User ID: {row["requester_user_id"]}')
            print(f'   Status: {row["status"]}')
            print(f'   Messages: {row["message_count"]}')
            print('   ---')
    else:
        print('   Aucune conversation existante pour ces emails')

if __name__ == '__main__':
    main()
