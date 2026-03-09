#!/usr/bin/env python3
"""
Deploy notification triggers via direct PostgreSQL connection.
Tries multiple connection methods.
"""
import sys
import os

PROJECT_REF = "thevdfcwlcqzdoybfvgs"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

SQL_FILE = os.path.join(os.path.dirname(__file__), "phase1_aggressive_notifications.sql")

def try_connection(host, port, user, password, dbname, use_ssl=True):
    """Try to connect and execute SQL."""
    import psycopg2
    ssl_mode = "require" if use_ssl else "disable"
    print(f"  Trying {user}@{host}:{port}/{dbname} (ssl={ssl_mode})...")
    try:
        conn = psycopg2.connect(
            host=host, port=port, database=dbname,
            user=user, password=password,
            sslmode=ssl_mode, connect_timeout=10
        )
        conn.autocommit = True
        cur = conn.cursor()
        
        with open(SQL_FILE, 'r', encoding='utf-8') as f:
            sql_content = f.read()
        
        print("  Connected! Executing SQL...")
        cur.execute(sql_content)
        
        # Try to fetch results from the final SELECT
        try:
            rows = cur.fetchall()
            cols = [desc[0] for desc in cur.description] if cur.description else []
            print(f"  Results ({len(rows)} rows):")
            for row in rows:
                print(f"    {dict(zip(cols, row))}")
        except Exception:
            print("  (No result set)")
        
        cur.close()
        conn.close()
        return True
    except Exception as e:
        print(f"  Failed: {e}")
        return False

def main():
    print("=" * 60)
    print("  DEPLOYING NOTIFICATION TRIGGERS VIA DIRECT CONNECTION")
    print("=" * 60)
    
    import psycopg2
    
    # Connection options to try:
    # 1) Direct connection to db host
    # 2) Pooler connection (transaction mode)
    # 3) Pooler connection (session mode)
    
    attempts = [
        # Direct DB connection
        {
            "host": f"db.{PROJECT_REF}.supabase.co",
            "port": 5432,
            "user": "postgres",
            "password": SERVICE_KEY,
            "dbname": "postgres",
        },
        # Supavisor pooler - transaction mode (port 6543)
        {
            "host": f"aws-0-eu-central-1.pooler.supabase.com",
            "port": 6543,
            "user": f"postgres.{PROJECT_REF}",
            "password": SERVICE_KEY,
            "dbname": "postgres",
        },
        # Supavisor pooler - session mode (port 5432)
        {
            "host": f"aws-0-eu-central-1.pooler.supabase.com",
            "port": 5432,
            "user": f"postgres.{PROJECT_REF}",
            "password": SERVICE_KEY,
            "dbname": "postgres",
        },
        # Try us-east-1 region
        {
            "host": f"aws-0-us-east-1.pooler.supabase.com",
            "port": 6543,
            "user": f"postgres.{PROJECT_REF}",
            "password": SERVICE_KEY,
            "dbname": "postgres",
        },
        {
            "host": f"aws-0-us-east-1.pooler.supabase.com",
            "port": 5432,
            "user": f"postgres.{PROJECT_REF}",
            "password": SERVICE_KEY,
            "dbname": "postgres",
        },
        # Try us-west-1
        {
            "host": f"aws-0-us-west-1.pooler.supabase.com",
            "port": 6543,
            "user": f"postgres.{PROJECT_REF}",
            "password": SERVICE_KEY,
            "dbname": "postgres",
        },
    ]
    
    for i, params in enumerate(attempts, 1):
        print(f"\n[Attempt {i}/{len(attempts)}]")
        if try_connection(**params):
            print(f"\n{'='*60}")
            print("  ✅ ALL TRIGGERS DEPLOYED SUCCESSFULLY!")
            print(f"{'='*60}")
            return True
    
    print(f"\n{'='*60}")
    print("  ❌ All connection attempts failed.")
    print("  The service_role key cannot be used as a DB password.")
    print("  You need to execute the SQL manually in Supabase SQL Editor.")
    print(f"  File: {SQL_FILE}")
    print(f"{'='*60}")
    return False

if __name__ == "__main__":
    main()
