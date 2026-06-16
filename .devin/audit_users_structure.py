import requests, json, sys
sys.path.append('.windsurf')
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()

    # Audit de la structure app.students
    sql = """
    SELECT column_name, data_type, is_nullable, column_default 
    FROM information_schema.columns 
    WHERE table_schema = 'app' AND table_name = 'students' 
    ORDER BY ordinal_position
    """

    url = f'{m.url}/rest/v1/rpc/admin_execute_sql'
    r = requests.post(url, headers=m.headers, json={'p_sql': sql.strip()}, timeout=30)
    data = r.json() if r.text else {}
    print('=== STRUCTURE app.students ===')
    if data.get('ok') and data.get('rows'):
        for row in data['rows']:
            print(f'  {row["column_name"]}: {row["data_type"]} ({row["is_nullable"]})')
    else:
        print(f'Erreur: {data}')

    # Audit de la RPC app_admin_list_users_overview
    sql2 = """
    SELECT pg_get_functiondef(p.oid) as source
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.proname = 'app_admin_list_users_overview'
    """

    r2 = requests.post(url, headers=m.headers, json={'p_sql': sql2.strip()}, timeout=30)
    data2 = r2.json() if r2.text else {}
    print('\n=== RPC app_admin_list_users_overview SOURCE ===')
    if data2.get('ok') and data2.get('rows'):
        source = data2['rows'][0]['source']
        print(source[:500] + '...' if len(source) > 500 else source)
    else:
        print(f'Erreur: {data2}')

if __name__ == '__main__':
    main()
