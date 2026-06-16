import requests, json, sys
sys.path.append('.windsurf')
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()

    print('=== AUDIT DÉTAILLÉ STRUCTURE SUPPORT ===')
    
    # 1. Structure exacte de support_conversations
    sql1 = """
    SELECT column_name, data_type, is_nullable, column_default 
    FROM information_schema.columns 
    WHERE table_schema = 'app' AND table_name = 'support_conversations' 
    ORDER BY ordinal_position
    """
    
    url = f'{m.url}/rest/v1/rpc/admin_execute_sql'
    r1 = requests.post(url, headers=m.headers, json={'p_sql': sql1.strip()}, timeout=30)
    data1 = r1.json() if r1.text else {}
    
    print('\n1. STRUCTURE support_conversations:')
    if data1.get('ok') and data1.get('rows'):
        for row in data1['rows']:
            print(f'   {row["column_name"]}: {row["data_type"]} ({row["is_nullable"]})')
    else:
        print(f'   Erreur: {data1}')

    # 2. Structure exacte de support_messages
    sql2 = """
    SELECT column_name, data_type, is_nullable, column_default 
    FROM information_schema.columns 
    WHERE table_schema = 'app' AND table_name = 'support_messages' 
    ORDER BY ordinal_position
    """
    
    r2 = requests.post(url, headers=m.headers, json={'p_sql': sql2.strip()}, timeout=30)
    data2 = r2.json() if r2.text else {}
    
    print('\n2. STRUCTURE support_messages:')
    if data2.get('ok') and data2.get('rows'):
        for row in data2['rows']:
            print(f'   {row["column_name"]}: {row["data_type"]} ({row["is_nullable"]})')
    else:
        print(f'   Erreur: {data2}')

    # 3. Source de app_get_or_create_support_conversation
    sql3 = """
    SELECT pg_get_functiondef(p.oid) as source
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.proname = 'app_get_or_create_support_conversation'
    """
    
    r3 = requests.post(url, headers=m.headers, json={'p_sql': sql3.strip()}, timeout=30)
    data3 = r3.json() if r3.text else {}
    
    print('\n3. SOURCE app_get_or_create_support_conversation:')
    if data3.get('ok') and data3.get('rows'):
        source = data3['rows'][0]['source']
        print(f'   {source[:300]}...' if len(source) > 300 else source)
    else:
        print(f'   Erreur: {data3}')

    # 4. Lien entre auth.users et app.students
    sql4 = """
    SELECT 
        au.id as user_id, 
        au.email, 
        au.raw_user_meta_data,
        s.id as student_id,
        s.full_name,
        s.avatar_url
    FROM auth.users au
    LEFT JOIN app.students s ON s.id = au.id
    WHERE au.raw_user_meta_data->>'role' = 'student'
    LIMIT 3
    """
    
    r4 = requests.post(url, headers=m.headers, json={'p_sql': sql4.strip()}, timeout=30)
    data4 = r4.json() if r4.text else {}
    
    print('\n4. LIEN auth.users ↔ app.students (échantillon):')
    if data4.get('ok') and data4.get('rows'):
        for row in data4['rows']:
            print(f'   User: {row["user_id"]} → Student: {row["student_id"]}')
            print(f'   Email: {row["email"]}')
            print(f'   Name: {row["full_name"] or "NULL"}')
            print('   ---')
    else:
        print(f'   Erreur: {data4}')

if __name__ == '__main__':
    main()
