"""
FIX permissions via Supabase Management API (SQL endpoint)
This API allows running DDL/GRANT statements that the RPC can't handle.
"""
import requests
import json

# Supabase Management API
MGMT_API = "https://api.supabase.com"
PROJECT_REF = "thevdfcwlcqzdoybfvgs"
# Try using the service role key as bearer, or we need the management API key
# Let's check what auth works

SUPABASE_URL = f"https://{PROJECT_REF}.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
DB_PASSWORD = "Azert0Yuiop"

HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}

# Approach: Use direct PostgreSQL connection via psycopg2
try:
    import psycopg2
    print("Using psycopg2 for direct DB connection...")
    
    conn = psycopg2.connect(
        host=f"db.{PROJECT_REF}.supabase.co",
        port=5432,
        dbname="postgres",
        user="postgres",
        password=DB_PASSWORD,
        sslmode="require",
    )
    conn.autocommit = True
    cur = conn.cursor()
    
    grants = [
        "GRANT USAGE ON SCHEMA app TO service_role",
        "GRANT USAGE ON SCHEMA app TO authenticated",
        "GRANT ALL ON ALL TABLES IN SCHEMA app TO service_role",
        "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA app TO authenticated",
        "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA app TO service_role",
        "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA app TO authenticated",
        # Specifically for the live tables
        "GRANT ALL ON app.challenge_game_live_sessions TO service_role",
        "GRANT ALL ON app.prep_live_sessions TO service_role",
        "GRANT ALL ON app.prep_live_participants TO service_role",
        "GRANT ALL ON app.online_course_live_sessions TO service_role",
        "GRANT ALL ON app.online_course_live_session_participants TO service_role",
        "GRANT SELECT, INSERT, UPDATE ON app.challenge_game_live_sessions TO authenticated",
        "GRANT SELECT, INSERT, UPDATE ON app.prep_live_sessions TO authenticated",
        "GRANT SELECT, INSERT, UPDATE ON app.prep_live_participants TO authenticated",
        "GRANT SELECT, INSERT, UPDATE ON app.online_course_live_sessions TO authenticated",
        "GRANT SELECT, INSERT, UPDATE ON app.online_course_live_session_participants TO authenticated",
    ]
    
    for g in grants:
        try:
            cur.execute(g)
            print(f"  ✅ {g}")
        except Exception as e:
            print(f"  ⚠ {g} → {e}")
    
    cur.close()
    conn.close()
    print("\n  Grants applied via direct connection.")

except ImportError:
    print("psycopg2 not available, trying alternative...")
    
    # Alternative: use sqlalchemy or pg8000
    try:
        import pg8000
        print("Using pg8000 for direct DB connection...")
        
        conn = pg8000.connect(
            host=f"db.{PROJECT_REF}.supabase.co",
            port=5432,
            database="postgres",
            user="postgres",
            password=DB_PASSWORD,
            ssl_context=True,
        )
        conn.autocommit = True
        cur = conn.cursor()
        
        grants = [
            "GRANT USAGE ON SCHEMA app TO service_role",
            "GRANT USAGE ON SCHEMA app TO authenticated",
            "GRANT ALL ON ALL TABLES IN SCHEMA app TO service_role",
            "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA app TO authenticated",
            "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA app TO service_role",
            "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA app TO authenticated",
        ]
        
        for g in grants:
            try:
                cur.execute(g)
                print(f"  ✅ {g}")
            except Exception as e:
                print(f"  ⚠ {g} → {e}")
        
        cur.close()
        conn.close()
        
    except ImportError:
        print("Neither psycopg2 nor pg8000 available.")
        print("Installing psycopg2-binary...")
        import subprocess
        subprocess.run(["pip", "install", "psycopg2-binary"], capture_output=True)
        
        import psycopg2
        conn = psycopg2.connect(
            host=f"db.{PROJECT_REF}.supabase.co",
            port=5432,
            dbname="postgres",
            user="postgres",
            password=DB_PASSWORD,
            sslmode="require",
        )
        conn.autocommit = True
        cur = conn.cursor()
        
        grants = [
            "GRANT USAGE ON SCHEMA app TO service_role",
            "GRANT USAGE ON SCHEMA app TO authenticated",
            "GRANT ALL ON ALL TABLES IN SCHEMA app TO service_role",
            "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA app TO authenticated",
            "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA app TO service_role",
            "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA app TO authenticated",
        ]
        
        for g in grants:
            try:
                cur.execute(g)
                print(f"  ✅ {g}")
            except Exception as e:
                print(f"  ⚠ {g} → {e}")
        
        cur.close()
        conn.close()

# Verify
print("\n" + "=" * 60)
print("VERIFYING ACCESS AFTER FIX...")
print("=" * 60)

live_tables = [
    'challenge_game_live_sessions',
    'online_course_live_sessions',
    'online_course_live_session_participants',
    'prep_live_sessions',
    'prep_live_participants',
]

for table in live_tables:
    r = requests.get(
        f"{SUPABASE_URL}/rest/v1/{table}?select=id&limit=1",
        headers={**HEADERS, "Accept-Profile": "app"},
    )
    status = "✅" if r.status_code == 200 else "❌"
    print(f"  {status} app.{table}: HTTP {r.status_code} — {r.text[:100]}")

print("\n🏁 Done.")
