import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
h = {"Authorization": f"Bearer {SK}", "apikey": SK, "Accept-Profile": "app", "Content-Type": "application/json"}

# Direct REST API queries (bypasses RPC)
print("=== 1. APPLICATIONS (REST) ===")
r1 = requests.get(f"{URL}/rest/v1/applications?select=id,student_id,program_id,status,created_at&order=created_at.desc&limit=10", headers=h)
apps = r1.json()
for a in apps:
    print(f"  app={a['id'][:8]}... status={a['status']:15s} prog={a['program_id'][:8]}... student={a['student_id'][:8]}...")

print("\n=== 2. APPLICATION_PAYMENTS (REST) ===")
r2 = requests.get(f"{URL}/rest/v1/application_payments?select=id,application_id,amount_due,status,payment_reason,created_at&order=created_at.desc&limit=15", headers=h)
pays = r2.json()
for p in pays:
    print(f"  pay={p['id'][:8]}... app={str(p.get('application_id','?'))[:8]} amount={p['amount_due']} status={p['status']} reason={p['payment_reason']}")

print("\n=== 3. PROGRAMS (REST) ===")
r3 = requests.get(f"{URL}/rest/v1/programs?select=id,title,university_id,brokerage_fee,tuition_fees,is_active&order=title&limit=30", headers=h)
progs = r3.json()
for p in progs:
    print(f"  [{('ON' if p['is_active'] else 'OFF'):3s}] {p['title'][:40]:40s} brokerage={p['brokerage_fee']:>8} tuition={str(p['tuition_fees']):>10} univ={str(p['university_id'])[:8]}...")

# Cross-reference: find the Agro application payment
print("\n=== 4. CROSS-REF: Agro application + payment ===")
agro_progs = [p for p in progs if 'agro' in p['title'].lower()]
for ap in agro_progs:
    print(f"  Program: {ap['title']} id={ap['id'][:8]}... brokerage={ap['brokerage_fee']}")
    matching_apps = [a for a in apps if a['program_id'] == ap['id']]
    for a in matching_apps:
        print(f"    Application: {a['id'][:8]}... status={a['status']}")
        matching_pays = [p for p in pays if p.get('application_id') == a['id']]
        for mp in matching_pays:
            print(f"      Payment: {mp['id'][:8]}... amount={mp['amount_due']} status={mp['status']}")

# Find the 25000 payment
print("\n=== 5. Payment with 25000 ===")
r5 = requests.get(f"{URL}/rest/v1/application_payments?amount_due=eq.25000&select=id,application_id,amount_due,status,payment_reason", headers=h)
for p in r5.json():
    print(f"  pay={p['id']} app={p.get('application_id','?')} amount={p['amount_due']} status={p['status']}")
    # Find matching application
    matching = [a for a in apps if a['id'] == p.get('application_id')]
    for a in matching:
        print(f"    app prog={a['program_id']}")
        matching_prog = [pr for pr in progs if pr['id'] == a['program_id']]
        for pr in matching_prog:
            print(f"    prog={pr['title']} brokerage={pr['brokerage_fee']}")
