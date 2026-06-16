import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

def rpc(name, params={}):
    r = requests.post(f"{URL}/rest/v1/rpc/{name}",
        headers={"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"},
        json=params)
    return r.json()

def sql(query):
    r = rpc("admin_execute_sql", {"p_sql": query})
    if isinstance(r, dict) and r.get('ok'):
        return r.get('rows', [])
    return r

# ── 1. Le paiement existant 25000 pour Agro ──
print("=== 1. PAIEMENTS application_fee pour l'application Agro ===")
rows = sql("""
  SELECT ap.id, ap.application_id, ap.amount_due, ap.status, ap.payment_reason,
         a.program_id, p.title as program_title, p.brokerage_fee
  FROM app.application_payments ap
  JOIN app.applications a ON a.id = ap.application_id
  JOIN app.programs p ON p.id = a.program_id
  WHERE p.title ILIKE '%agro%' OR p.title ILIKE '%licence%'
  ORDER BY ap.created_at DESC
  LIMIT 10
""")
for r in rows:
    print(f"  pay={r['id'][:8]}... amount_due={r['amount_due']} status={r['status']} program={r['program_title'][:30]} brokerage={r['brokerage_fee']}")

# ── 2. Tous les programmes avec brokerage_fee ──
print("\n=== 2. PROGRAMMES avec brokerage_fee ===")
rows2 = sql("""
  SELECT p.id, p.title, p.university_id, u.name as univ_name,
         p.tuition_fees, p.brokerage_fee, p.is_active
  FROM app.programs p
  LEFT JOIN app.universities u ON u.id = p.university_id
  ORDER BY p.title
""")
for r in rows2:
    print(f"  [{('ON' if r['is_active'] else 'OFF'):3s}] {r['title'][:40]:40s} univ={str(r.get('univ_name','?'))[:25]:25s} tuition={r['tuition_fees']:>10} brokerage={r['brokerage_fee']:>8}")

# ── 3. Programmes dupliqués (même titre dans différentes universités) ──
print("\n=== 3. PROGRAMMES DUPLIQUES (même titre, universités différentes) ===")
rows3 = sql("""
  SELECT p.title, COUNT(*) as cnt, COUNT(DISTINCT p.university_id) as univ_cnt,
         ARRAY_AGG(DISTINCT u.name) as univs,
         ARRAY_AGG(DISTINCT p.brokerage_fee) as fees
  FROM app.programs p
  LEFT JOIN app.universities u ON u.id = p.university_id
  GROUP BY p.title
  HAVING COUNT(*) > 1
  ORDER BY cnt DESC
""")
if rows3:
    for r in rows3:
        print(f"  '{r['title']}' x{r['cnt']} universites: {r['univs']} fees: {r['fees']}")
else:
    print("  Aucun doublon détecté")

# ── 4. Schema universités ──
print("\n=== 4. UNIVERSITES ===")
rows4 = sql("SELECT id, name, is_active FROM app.universities ORDER BY name")
for r in rows4:
    print(f"  [{('ON' if r['is_active'] else 'OFF'):3s}] {r['name'][:50]} id={r['id'][:8]}...")

# ── 5. Schema applications → programmes → universités ──
print("\n=== 5. APPLICATIONS avec programme et université ===")
rows5 = sql("""
  SELECT a.id as app_id, a.status, p.title as prog, u.name as univ,
         p.brokerage_fee,
         (SELECT COUNT(*) FROM app.application_payments ap WHERE ap.application_id = a.id) as payment_count,
         (SELECT ap.amount_due FROM app.application_payments ap WHERE ap.application_id = a.id ORDER BY ap.created_at DESC LIMIT 1) as last_amount_due
  FROM app.applications a
  JOIN app.programs p ON p.id = a.program_id
  LEFT JOIN app.universities u ON u.id = p.university_id
  ORDER BY a.created_at DESC
  LIMIT 10
""")
for r in rows5:
    print(f"  app={r['app_id'][:8]}... status={r['status']:15s} prog={str(r['prog'])[:25]:25s} univ={str(r.get('univ','?'))[:20]:20s} brokerage={r['brokerage_fee']:>8} payments={r['payment_count']} last_due={r['last_amount_due']}")

# ── 6. Vérifier quel programme est "Agro" ──
print("\n=== 6. PROGRAMME AGRO specifique ===")
rows6 = sql("SELECT id, title, brokerage_fee, tuition_fees, university_id, is_active FROM app.programs WHERE title ILIKE '%agro%'")
for r in rows6:
    print(f"  id={r['id']} title={r['title']} brokerage={r['brokerage_fee']} tuition={r['tuition_fees']} active={r['is_active']}")
