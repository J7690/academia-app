#!/usr/bin/env python3
from __future__ import annotations
import requests
from supabase_auto_manager import SupabaseAutoManager

def q(m, sql):
    r = requests.post(f"{m.url}/rest/v1/rpc/execute_sql",
        headers=m.headers, json={"sql_query": sql}, timeout=30)
    data = r.json()
    return data if isinstance(data, list) else []

m = SupabaseAutoManager()

# Dimension des vecteurs existants
dim = q(m,
    "SELECT vector_dims(embedding) AS dim FROM app.bobodo_knowledge "
    "WHERE embedding IS NOT NULL LIMIT 1")
print("Dimension embedding:", dim)

# Type exact de la colonne
col_type = q(m,
    "SELECT udt_name, character_maximum_length "
    "FROM information_schema.columns "
    "WHERE table_schema='app' AND table_name='bobodo_knowledge' "
    "AND column_name='embedding'")
print("Type colonne:", col_type)

# Vérifie si l'extension vector est installée
ext = q(m,
    "SELECT extname, extversion FROM pg_extension WHERE extname='vector'")
print("Extension pgvector:", ext)
