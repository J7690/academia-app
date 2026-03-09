
import psycopg2
from psycopg2.extras import RealDictCursor

# Configuration de connexion directe
connection_params = {
    "host": "db.thevdfcwlcqzdoybfvgs.supabase.co",
    "port": 5432,
    "database": "postgres",
    "user": "postgres",
    "password": "Azert0Yuiop@",
    "sslmode": "require"
}

try:
    # Connexion directe
    conn = psycopg2.connect(**connection_params)
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    
    # Exécuter du SQL directement
    cursor.execute("SELECT version()")
    result = cursor.fetchone()
    print(f"✅ Connexion directe: {result['version']}")
    
    # Lister les tables
    cursor.execute("""
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public'
        ORDER BY table_name
    """)
    tables = cursor.fetchall()
    print(f"✅ Tables: {[t['table_name'] for t in tables]}")
    
    cursor.close()
    conn.close()
    
except Exception as e:
    print(f"❌ Erreur connexion directe: {e}")
