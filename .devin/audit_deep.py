import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

def sql(query):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql",
        headers={"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"},
        json={"p_sql": query})
    j = r.json()
    if isinstance(j, dict) and j.get('ok'):
        return j.get('rows', [])
    return j

# 1. ALL application_payments (any status)
print("=== 1. ALL application_payments (last 15) ===")
rows = sql("""
  SELECT ap.id, ap.application_id, ap.amount_due, ap.status, ap.payment_reason, ap.created_at::text,
         a.program_id, a.student_id
  FROM app.application_payments ap
  LEFT JOIN app.applications a ON a.id = ap.application_id
  ORDER BY ap.created_at DESC
  LIMIT 15
""")
for r in rows:
    print(f"  pay={r['id'][:8]}... app={str(r.get('application_id','?'))[:8]} amount={r['amount_due']} status={r['status']} reason={r['payment_reason']} prog={str(r.get('program_id','?'))[:8]}")

# 2. ALL applications
print("\n=== 2. ALL applications (last 15) ===")
rows2 = sql("""
  SELECT a.id, a.status, a.student_id, a.program_id,
         p.title as prog_title, p.brokerage_fee, u.name as univ_name,
         (SELECT COUNT(*) FROM app.application_payments ap WHERE ap.application_id = a.id) as pay_count
  FROM app.applications a
  JOIN app.programs p ON p.id = a.program_id
  LEFT JOIN app.universities u ON u.id = p.university_id
  ORDER BY a.created_at DESC
  LIMIT 15
""")
for r in rows2:
    print(f"  app={r['id'][:8]}... status={r['status']:15s} prog={str(r['prog_title'])[:25]:25s} brokerage={r['brokerage_fee']:>6} univ={str(r.get('univ_name','?'))[:20]} pays={r['pay_count']}")

# 3. The payment that shows 25000 for Agro
print("\n=== 3. Payments with amount_due=25000 ===")
rows3 = sql("""
  SELECT ap.id, ap.application_id, ap.amount_due, ap.status, ap.payment_reason,
         a.program_id, p.title, p.brokerage_fee
  FROM app.application_payments ap
  LEFT JOIN app.applications a ON a.id = ap.application_id
  LEFT JOIN app.programs p ON p.id = a.program_id
  WHERE ap.amount_due = 25000
""")
for r in rows3:
    print(f"  pay={r['id']} status={r['status']} prog={r.get('title','?')} brokerage={r.get('brokerage_fee','?')}")

# 4. The Agro program at Test university - which application?
print("\n=== 4. Applications for Agro program ===")
rows4 = sql("""
  SELECT a.id, a.status, a.student_id, p.title, p.brokerage_fee, p.id as prog_id,
         u.name as univ,
         (SELECT ap.id FROM app.application_payments ap WHERE ap.application_id = a.id ORDER BY ap.created_at DESC LIMIT 1) as last_pay_id,
         (SELECT ap.amount_due FROM app.application_payments ap WHERE ap.application_id = a.id ORDER BY ap.created_at DESC LIMIT 1) as last_pay_amount,
         (SELECT ap.status FROM app.application_payments ap WHERE ap.application_id = a.id ORDER BY ap.created_at DESC LIMIT 1) as last_pay_status
  FROM app.applications a
  JOIN app.programs p ON p.id = a.program_id
  LEFT JOIN app.universities u ON u.id = p.university_id
  WHERE p.title ILIKE '%agro%'
""")
for r in rows4:
    print(f"  app={r['id'][:8]}... status={r['status']} prog={r['title']} brokerage={r['brokerage_fee']} univ={r.get('univ','?')}")
    print(f"    last_pay={str(r.get('last_pay_id','none'))[:8]} amount={r.get('last_pay_amount','?')} pay_status={r.get('last_pay_status','?')}")

# 5. Schema: what columns does app.applications have?
print("\n=== 5. COLUMNS app.applications ===")
cols = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='applications' ORDER BY ordinal_position")
for c in cols:
    print(f"  {c['column_name']:30s} {c['data_type']}")

# 6. Schema: what columns does app.application_payments have?
print("\n=== 6. COLUMNS app.application_payments ===")
cols2 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='application_payments' ORDER BY ordinal_position")
for c in cols2:
    print(f"  {c['column_name']:30s} {c['data_type']}")
