import os
import sys
import httpx
from dotenv import load_dotenv
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / "academia_bobodo_backend" / ".env", override=True)

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY")

if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
    print("ERROR: SUPABASE_URL ou SUPABASE_SERVICE_KEY manquant")
    sys.exit(1)

headers = {
    "apikey": SUPABASE_SERVICE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
    "Accept": "application/json",
    "Accept-Profile": "app",
    "Content-Profile": "app",
}

async def check_table(table_name):
    url = f"{SUPABASE_URL}/rest/v1/{table_name}?limit=1"
    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.get(url, headers=headers)
    return resp.status_code

async def get_table_info(table_name):
    url = f"{SUPABASE_URL}/rest/v1/{table_name}?select=*&limit=1"
    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.get(url, headers=headers)
    if resp.status_code == 200:
        try:
            data = resp.json()
            if isinstance(data, list) and data:
                return list(data[0].keys())
        except:
            pass
    return None

async def main():
    tables = ["video_assets", "video_sources", "video_renditions", "video_processing_jobs"]
    
    print("=== Vérification des tables vidéo dans Supabase ===\n")
    
    for table in tables:
        status = await check_table(table)
        if status == 200:
            columns = await get_table_info(table)
            print(f"✅ {table}: EXISTS (status {status})")
            if columns:
                print(f"   Colonnes: {', '.join(columns)}")
        elif status == 404:
            print(f"❌ {table}: NOT FOUND (status {status})")
        else:
            print(f"⚠️  {table}: ERROR (status {status})")
        print()

if __name__ == "__main__":
    import asyncio
    asyncio.run(main())
