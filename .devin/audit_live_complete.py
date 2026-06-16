"""
AUDIT COMPLET LIVE STREAMING — Requêtes SQL réelles via RPC execute_sql
Objectif: Cartographier exactement ce qui existe dans Supabase pour le live,
pas deviner, mais VOIR.
"""
import requests
import json

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}

results = {}

def sql(query, label=""):
    """Execute SQL via RPC and return results"""
    if label:
        print(f"\n{'='*60}")
        print(f"  {label}")
        print(f"{'='*60}")
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/execute_sql",
        headers=HEADERS,
        json={"sql_query": query}
    )
    if r.status_code == 200:
        data = r.json()
        if isinstance(data, list):
            for row in data[:30]:
                print(f"  {row}")
            if len(data) > 30:
                print(f"  ... et {len(data)-30} de plus")
            return data
        elif isinstance(data, str):
            print(f"  {data[:500]}")
            return data
        else:
            print(f"  {str(data)[:500]}")
            return data
    else:
        print(f"  ❌ HTTP {r.status_code}: {r.text[:300]}")
        return None

# =========================================================================
# SECTION 1: TABLES liées au LIVE
# =========================================================================
print("\n" + "#"*70)
print("# SECTION 1: TOUTES LES TABLES CONTENANT 'live' OU 'session'")
print("#"*70)

results['tables_live'] = sql("""
SELECT table_schema, table_name
FROM information_schema.tables
WHERE (table_name LIKE '%live%' OR table_name LIKE '%session%')
  AND table_type = 'BASE TABLE'
ORDER BY table_schema, table_name
""", "Tables contenant 'live' ou 'session'")

# =========================================================================
# SECTION 2: Structure de CHAQUE table live
# =========================================================================
print("\n" + "#"*70)
print("# SECTION 2: STRUCTURE DE CHAQUE TABLE LIVE")
print("#"*70)

live_tables = results.get('tables_live', [])
if isinstance(live_tables, list):
    for t in live_tables:
        schema = t.get('table_schema', 'public')
        name = t.get('table_name', '')
        results[f'struct_{schema}_{name}'] = sql(f"""
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = '{schema}' AND table_name = '{name}'
ORDER BY ordinal_position
""", f"Structure de {schema}.{name}")

# =========================================================================
# SECTION 3: DONNÉES dans les tables live (count + échantillons)
# =========================================================================
print("\n" + "#"*70)
print("# SECTION 3: DONNÉES DANS LES TABLES LIVE")
print("#"*70)

if isinstance(live_tables, list):
    for t in live_tables:
        schema = t.get('table_schema', 'public')
        name = t.get('table_name', '')
        results[f'count_{schema}_{name}'] = sql(f"""
SELECT COUNT(*) as total FROM {schema}.{name}
""", f"Nombre de lignes dans {schema}.{name}")

        # Show recent rows if any
        sql(f"""
SELECT * FROM {schema}.{name} ORDER BY created_at DESC LIMIT 3
""", f"3 dernières entrées de {schema}.{name}")

# =========================================================================
# SECTION 4: TOUTES LES FONCTIONS/RPCs liées au live
# =========================================================================
print("\n" + "#"*70)
print("# SECTION 4: FONCTIONS/RPCs LIÉES AU LIVE")
print("#"*70)

results['rpcs_live'] = sql("""
SELECT routine_schema, routine_name, data_type as return_type
FROM information_schema.routines
WHERE (routine_name LIKE '%live%' OR routine_name LIKE '%session%' OR routine_name LIKE '%game%start%' OR routine_name LIKE '%game%end%')
  AND routine_type = 'FUNCTION'
ORDER BY routine_schema, routine_name
""", "RPCs contenant 'live', 'session', 'game_start', 'game_end'")

# =========================================================================
# SECTION 5: Détails des RPCs critiques (paramètres)
# =========================================================================
print("\n" + "#"*70)
print("# SECTION 5: PARAMÈTRES DES RPCs CRITIQUES")
print("#"*70)

critical_rpcs = [
    'challenge_game_start_live',
    'challenge_game_end_live',
    'app_prep_student_join_live_session',
    'app_register_online_course_live_session_participant',
    'app_ci_start_online_course_live_session',
    'app_ci_upsert_online_course_live_session',
]

for rpc_name in critical_rpcs:
    sql(f"""
SELECT p.parameter_name, p.data_type, p.parameter_mode
FROM information_schema.parameters p
JOIN information_schema.routines r ON r.specific_name = p.specific_name AND r.specific_schema = p.specific_schema
WHERE r.routine_name = '{rpc_name}'
ORDER BY p.ordinal_position
""", f"Paramètres de {rpc_name}")

# =========================================================================
# SECTION 6: Code source des RPCs game live
# =========================================================================
print("\n" + "#"*70)
print("# SECTION 6: CODE SOURCE DES RPCs GAME LIVE CRITIQUES")
print("#"*70)

for rpc_name in ['challenge_game_start_live', 'challenge_game_end_live']:
    sql(f"""
SELECT routine_schema, routine_name, 
       pg_get_functiondef(p.oid) as source_code
FROM information_schema.routines r
JOIN pg_proc p ON p.proname = r.routine_name
WHERE r.routine_name = '{rpc_name}'
LIMIT 1
""", f"Code source de {rpc_name}")

# =========================================================================
# SECTION 7: TABLES challenge_game_* (toutes)
# =========================================================================
print("\n" + "#"*70)
print("# SECTION 7: TOUTES LES TABLES challenge_game*")
print("#"*70)

results['tables_game'] = sql("""
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_name LIKE '%challenge_game%'
  AND table_type = 'BASE TABLE'
ORDER BY table_schema, table_name
""", "Tables challenge_game*")

# =========================================================================
# SECTION 8: EDGE FUNCTIONS déployées
# =========================================================================
print("\n" + "#"*70)
print("# SECTION 8: VÉRIFICATION CONNECTIVITÉ EDGE FUNCTIONS")
print("#"*70)

edge_functions = ['livekit-token', 'livekit-recording']
for fn_name in edge_functions:
    print(f"\n  Testing {fn_name}...")
    try:
        r = requests.post(
            f"{SUPABASE_URL}/functions/v1/{fn_name}",
            headers={"Content-Type": "application/json"},
            json={},
            timeout=10
        )
        print(f"  HTTP {r.status_code}: {r.text[:200]}")
    except Exception as e:
        print(f"  ❌ Error: {e}")

# =========================================================================
# SECTION 9: KAMATERA LIVEKIT SERVER CONNECTIVITY
# =========================================================================
print("\n" + "#"*70)
print("# SECTION 9: LIVEKIT SERVER CONNECTIVITY")
print("#"*70)

LIVEKIT_IP = "185.167.96.214"
try:
    r = requests.get(f"http://{LIVEKIT_IP}:7880", timeout=10)
    print(f"  LiveKit HTTP: {r.status_code} — {r.text[:50]}")
except Exception as e:
    print(f"  ❌ LiveKit unreachable: {e}")

# =========================================================================
# SECTION 10: SUPABASE SECRETS CHECK
# =========================================================================
print("\n" + "#"*70)
print("# SECTION 10: TEST EDGE FUNCTION AVEC AUTH")
print("#"*70)

# Test with a fake session UUID to verify the full chain works
# (should return 404 "session introuvable" if secrets are configured)
print("  Testing livekit-token with service role key (expect 'Token invalide' or 'session introuvable')...")
try:
    r = requests.post(
        f"{SUPABASE_URL}/functions/v1/livekit-token",
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {SERVICE_KEY}",
            "apikey": SERVICE_KEY,
        },
        json={"session_id": "00000000-0000-0000-0000-000000000001"},
        timeout=15
    )
    print(f"  HTTP {r.status_code}: {r.text[:300]}")
    if "non configuré" in r.text.lower():
        print("  ❌ LIVEKIT SECRETS NOT CONFIGURED!")
    elif "invalide" in r.text.lower() or "introuvable" in r.text.lower():
        print("  ✅ Edge Function works (secrets are configured)")
except Exception as e:
    print(f"  ❌ Error: {e}")

print("\n\n" + "="*70)
print("  AUDIT TERMINÉ — RÉSUMÉ")
print("="*70)
print(f"  Tables live trouvées: {len(results.get('tables_live', []))}")
print(f"  RPCs live trouvées: {len(results.get('rpcs_live', []))}")
print(f"  Tables game trouvées: {len(results.get('tables_game', []))}")

# Save full results to JSON
with open("audit_live_results.json", "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False, default=str)
print(f"\n  Résultats sauvegardés dans audit_live_results.json")
