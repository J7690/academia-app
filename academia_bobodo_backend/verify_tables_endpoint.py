import os
import httpx
from fastapi import HTTPException

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY")

@app.get("/verify/tables")
async def verify_tables():
    """Vérifie l'existence des tables vidéo dans Supabase."""
    
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        raise HTTPException(status_code=500, detail="SUPABASE_URL ou SUPABASE_SERVICE_KEY manquant")
    
    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Accept": "application/json",
        "Accept-Profile": "app",
        "Content-Profile": "app",
    }
    
    tables = ["video_assets", "video_sources", "video_renditions", "video_processing_jobs"]
    results = {}
    
    for table in tables:
        url = f"{SUPABASE_URL}/rest/v1/{table}?limit=1"
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.get(url, headers=headers)
        
        if resp.status_code == 200:
            try:
                data = resp.json()
                if isinstance(data, list) and data:
                    columns = list(data[0].keys())
                    results[table] = {"status": "exists", "columns": columns}
                else:
                    results[table] = {"status": "exists", "columns": []}
            except:
                results[table] = {"status": "exists", "columns": []}
        elif resp.status_code == 404:
            results[table] = {"status": "not_found"}
        else:
            results[table] = {"status": "error", "code": resp.status_code}
    
    return results
