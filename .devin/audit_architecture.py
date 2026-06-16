import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
h = {"Authorization": f"Bearer {SK}", "apikey": SK, "Accept-Profile": "app", "Content-Type": "application/json"}

def get(path):
    r = requests.get(f"{URL}/rest/v1/{path}", headers=h)
    return r.json()

# ── 1. UNIVERSITES complètes ──
print("=" * 80)
print("AUDIT ARCHITECTURE: UNIVERSITES -> PROGRAMMES -> CANDIDATURES -> PAIEMENTS")
print("=" * 80)

univs = get("universities?select=id,name,is_active&order=name")
print(f"\n### 1. UNIVERSITES ({len(univs)} total) ###")
active_u = [u for u in univs if u['is_active']]
inactive_u = [u for u in univs if not u['is_active']]
print(f"  Actives: {len(active_u)}, Inactives: {len(inactive_u)}")
for u in univs:
    print(f"  [{('ON' if u['is_active'] else '--'):2s}] {u['name'][:45]:45s} id={u['id'][:8]}...")

# ── 2. PROGRAMMES complets avec université ──
progs = get("programs?select=id,title,university_id,brokerage_fee,tuition_fees,is_active,degree_level,mode&order=title")
print(f"\n### 2. PROGRAMMES ({len(progs)} total) ###")
active_p = [p for p in progs if p['is_active']]
print(f"  Actifs: {len(active_p)}, Inactifs: {len(progs)-len(active_p)}")
print(f"  Avec brokerage_fee > 0: {len([p for p in progs if (p.get('brokerage_fee') or 0) > 0])}")
print(f"  Sans brokerage_fee: {len([p for p in progs if not p.get('brokerage_fee') or p['brokerage_fee'] == 0])}")

# Group by university
univ_map = {u['id']: u['name'] for u in univs}
by_univ = {}
for p in progs:
    uid = p['university_id']
    uname = univ_map.get(uid, f"INCONNU({str(uid)[:8]})")
    by_univ.setdefault(uname, []).append(p)

for uname, uprogs in sorted(by_univ.items()):
    print(f"\n  [{uname}] ({len(uprogs)} programmes)")
    for p in uprogs:
        bf = p.get('brokerage_fee') or 0
        tf = p.get('tuition_fees') or 0
        status = "ON" if p['is_active'] else "--"
        dl = p.get('degree_level') or ''
        print(f"    [{status:2s}] {p['title'][:40]:40s} {dl[:15]:15s} courtage={bf:>8} scolarite={tf:>10}")

# ── 3. DOUBLONS: même titre dans des universités différentes ──
print(f"\n### 3. DOUBLONS PROGRAMMES (même titre, universités différentes) ###")
from collections import defaultdict
title_map = defaultdict(list)
for p in progs:
    title_map[p['title'].strip().lower()].append(p)

dupes = {t: ps for t, ps in title_map.items() if len(ps) > 1}
if dupes:
    for title, ps in sorted(dupes.items()):
        univ_ids = set(p['university_id'] for p in ps)
        if len(univ_ids) > 1:
            print(f"  INTER-UNIV: '{ps[0]['title']}' x{len(ps)}")
            for p in ps:
                print(f"    → {univ_map.get(p['university_id'],'?')[:30]} brokerage={p.get('brokerage_fee',0)} id={p['id'][:8]}")
        else:
            univ_name = univ_map.get(ps[0]['university_id'], '?')
            fees = set((p.get('brokerage_fee',0), p.get('tuition_fees',0), p.get('degree_level','')) for p in ps)
            if len(fees) > 1:
                print(f"  INTRA-UNIV (fees diff): '{ps[0]['title']}' x{len(ps)} dans {univ_name}")
                for p in ps:
                    print(f"    → level={p.get('degree_level','')} brokerage={p.get('brokerage_fee',0)} scolarite={p.get('tuition_fees',0)} id={p['id'][:8]}")
            else:
                print(f"  INTRA-UNIV (identiques): '{ps[0]['title']}' x{len(ps)} dans {univ_name}")
else:
    print("  Aucun doublon détecté")

# ── 4. CANDIDATURES ──
apps = get("applications?select=id,student_id,program_id,status,created_at&order=created_at.desc")
print(f"\n### 4. CANDIDATURES ({len(apps)} total) ###")
statuses = defaultdict(int)
for a in apps:
    statuses[a['status']] += 1
for s, c in sorted(statuses.items()):
    print(f"  {s}: {c}")

# ── 5. PAIEMENTS application_fee ──
pays = get("application_payments?select=id,application_id,amount_due,amount_paid,status,payment_reason,created_at&payment_reason=eq.application_fee&order=created_at.desc")
print(f"\n### 5. PAIEMENTS application_fee ({len(pays)} total) ###")
pay_statuses = defaultdict(int)
for p in pays:
    pay_statuses[p['status']] += 1
for s, c in sorted(pay_statuses.items()):
    print(f"  {s}: {c}")

# Cross-ref: paiements avec programme
print("\n  Détail:")
prog_map = {p['id']: p for p in progs}
app_map = {a['id']: a for a in apps}
for p in pays:
    app = app_map.get(p.get('application_id'))
    prog = prog_map.get(app['program_id']) if app else None
    pname = prog['title'][:30] if prog else '?'
    bf = prog.get('brokerage_fee', 0) if prog else '?'
    match = "✓" if prog and float(p['amount_due']) == float(prog.get('brokerage_fee', 0) or 0) else "✗ MISMATCH"
    print(f"    pay={p['id'][:8]}... amount={p['amount_due']:>8} status={p['status']:20s} prog={pname} brokerage={bf} {match}")

# ── 6. RPCs liés aux programmes ──
print(f"\n### 6. RPCs PROGRAMMES/PAIEMENTS ###")
import requests as req
def sql(query):
    r = req.post(f"{URL}/rest/v1/rpc/admin_execute_sql",
        headers={"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"},
        json={"p_sql": query})
    j = r.json()
    if isinstance(j, dict) and j.get('ok'):
        return j.get('rows', [])
    return j

rpcs = sql("SELECT proname FROM pg_proc WHERE proname LIKE 'app_%program%' OR proname LIKE 'app_%brokerage%' OR proname LIKE 'app_create_application%' OR proname LIKE 'app_confirm_ligdicash%' ORDER BY proname")
if isinstance(rpcs, list):
    for r in rpcs:
        print(f"  {r.get('proname','?')}")
