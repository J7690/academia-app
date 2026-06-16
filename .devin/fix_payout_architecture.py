import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

def sql(query):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql",
        headers={"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"},
        json={"p_sql": query})
    j = r.json()
    print(f"  -> {j}")
    return j

print("=" * 70)
print("PHASE 1: Desactiver revenue_split_rules university")
print("=" * 70)

# 1. Desactiver les rules university
print("\n### 1a. Desactiver beneficiary_type='university' ###")
sql("UPDATE app.revenue_split_rules SET is_active = FALSE WHERE beneficiary_type = 'university'")

# 2. Redistribuer les % university vers platform
# registration_fee: university avait 70%, platform 15%, commercial 15% -> platform devient 85%
print("\n### 1b. Redistribuer registration_fee: university 70% -> platform ###")
sql("""
  UPDATE app.revenue_split_rules 
  SET percentage = 0.85, updated_at = NOW()
  WHERE payment_reason = 'registration_fee' AND beneficiary_type = 'platform' AND is_active = TRUE
""")

# tuition_deposit: university avait 80%, platform 10%, commercial 10% -> platform becomes 90%
print("\n### 1c. Redistribuer tuition_deposit: university 80% -> platform ###")
sql("""
  UPDATE app.revenue_split_rules 
  SET percentage = 0.90, updated_at = NOW()
  WHERE payment_reason = 'tuition_deposit' AND beneficiary_type = 'platform' AND is_active = TRUE
""")

# 3. Ajouter regle application_fee -> 100% platform (courtage)
print("\n### 1d. Ajouter application_fee -> platform 100% ###")
sql("""
  INSERT INTO app.revenue_split_rules (payment_reason, beneficiary_type, percentage, is_active, description, priority)
  VALUES ('application_fee', 'platform', 1.0, TRUE, 'Courtage 100% plateforme', 1)
  ON CONFLICT DO NOTHING
""")

# 4. Verifier les totaux
print("\n### 1e. Verification totaux ###")
rows = sql("""
  SELECT payment_reason, 
         ROUND(SUM(percentage), 4) AS total_pct,
         STRING_AGG(beneficiary_type || '=' || (percentage*100)::TEXT || '%', ', ' ORDER BY beneficiary_type) AS detail,
         BOOL_AND(is_active) AS all_active
  FROM app.revenue_split_rules 
  WHERE is_active = TRUE
  GROUP BY payment_reason
  ORDER BY payment_reason
""")
if isinstance(rows, dict) and rows.get('ok') and rows.get('rows'):
    for r in rows['rows']:
        valid = "OK" if abs(float(r['total_pct']) - 1.0) < 0.001 else "INVALID"
        print(f"  {r['payment_reason']:25s} total={r['total_pct']} [{valid}] -> {r['detail']}")

print("\n" + "=" * 70)
print("PHASE 2: Desactiver RPC app_university_request_payout")
print("=" * 70)

sql("""
CREATE OR REPLACE FUNCTION public.app_university_request_payout(p_phone text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $fn$
BEGIN
  RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'feature_disabled', 'message', 'Les universites ne recoivent pas de flux financier via la plateforme.');
END;
$fn$;
""")

# Also disable app_university_get_balance
sql("""
CREATE OR REPLACE FUNCTION public.app_university_get_balance()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $fn$
BEGIN
  RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'feature_disabled');
END;
$fn$;
""")

print("\n" + "=" * 70)
print("PHASE 3: Ajouter colonne ligdicash_account aux tables acteurs")
print("=" * 70)

# Les payout sont LigdiCash->LigdiCash, donc on a besoin du numero LigdiCash du beneficiaire
# Le numero mobile money = le numero LigdiCash (meme numero)
# On garde beneficiary_phone dans payout_queue tel quel

print("\nLe numero mobile money = le numero du portefeuille LigdiCash")
print("top_up_wallet=1 -> transfert vers portefeuille LigdiCash du beneficiaire")
print("Pas besoin de colonne supplementaire, le phone suffit.")

print("\nDone!")
