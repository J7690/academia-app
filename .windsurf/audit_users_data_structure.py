import requests, json, sys
sys.path.append('.windsurf')
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()

    print('=== AUDIT STRUCTURE EXACTE DES DONNÉES UTILISATEURS ===')
    
    # Récupérer un admin user_id pour le test
    sql_admin = """
    SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin' LIMIT 1
    """
    
    url = f'{m.url}/rest/v1/rpc/admin_execute_sql'
    r_admin = requests.post(url, headers=m.headers, json={'p_sql': sql_admin.strip()}, timeout=30)
    data_admin = r_admin.json() if r_admin.text else {}
    
    if not data_admin.get('ok') or not data_admin.get('rows'):
        print('Impossible de récupérer un admin ID pour le test')
        return
    
    admin_id = data_admin['rows'][0]['id']
    print(f'Admin ID utilisé pour le test: {admin_id}')
    
    # Simuler l'appel avec auth.uid() via une requête directe
    sql = """
    WITH admin_session AS (
        SELECT '%s'::uuid as uid
    )
    SELECT 
        u.id,
        u.email,
        u.raw_user_meta_data->>'role' as role,
        s.full_name,
        s.avatar_url,
        s.created_at as student_created_at
    FROM auth.users u
    LEFT JOIN app.students s ON s.id = u.id
    WHERE u.raw_user_meta_data->>'role' IN ('student', 'instructor', 'university', 'commercial', 'merchant')
    ORDER BY u.created_at DESC
    LIMIT 3
    """ % admin_id
    
    r = requests.post(url, headers=m.headers, json={'p_sql': sql.strip()}, timeout=30)
    data = r.json() if r.text else {}
    
    print('\n1. STRUCTURE COMPLÈTE DES DONNÉES UTILISATEURS:')
    if data.get('ok') and data.get('rows'):
        for i, row in enumerate(data['rows']):
            print(f'   Utilisateur {i+1}:')
            for key, value in row.items():
                print(f'     {key}: {value}')
            print('   ---')
    else:
        print(f'   Erreur: {data}')

if __name__ == '__main__':
    main()
