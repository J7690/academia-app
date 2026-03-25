import requests, json, sys
sys.path.append('.windsurf')
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()

    print('=== AUDIT STRUCTURE FLUTTER UTILISATEURS ===')
    
    # 1. Source complète de app_admin_list_users_overview
    sql = """
    SELECT pg_get_functiondef(p.oid) as source
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.proname = 'app_admin_list_users_overview'
    """
    
    url = f'{m.url}/rest/v1/rpc/admin_execute_sql'
    r = requests.post(url, headers=m.headers, json={'p_sql': sql.strip()}, timeout=30)
    data = r.json() if r.text else {}
    
    print('\n1. SOURCE COMPLET app_admin_list_users_overview:')
    if data.get('ok') and data.get('rows'):
        source = data['rows'][0]['source']
        print(source[:800] + '...' if len(source) > 800 else source)
    else:
        print(f'   Erreur: {data}')

    # 2. Test de la RPC pour voir la structure exacte des données retournées
    sql2 = """
    SELECT * FROM app_admin_list_users_overview() LIMIT 2
    """
    
    r2 = requests.post(url, headers=m.headers, json={'p_sql': sql2.strip()}, timeout=30)
    data2 = r2.json() if r2.text else {}
    
    print('\n2. STRUCTURE DONNÉES RETOURNÉES (échantillon):')
    if data2.get('ok') and data2.get('rows'):
        for i, row in enumerate(data2['rows']):
            print(f'   Utilisateur {i+1}:')
            for key, value in row.items():
                if isinstance(value, str) and len(value) > 50:
                    print(f'     {key}: {value[:50]}...')
                else:
                    print(f'     {key}: {value}')
            print('   ---')
    else:
        print(f'   Erreur: {data2}')

if __name__ == '__main__':
    main()
