#!/usr/bin/env python3
"""Phase 1 Audit Supabase: vérifier l'état des tables prep_* et données existantes avant adaptation BF."""
import json, requests
from pathlib import Path

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SK, "Authorization": f"Bearer {SK}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                       json={"p_sql": " ".join(q.split())}, timeout=30)
    body = r.json()
    if isinstance(body, dict) and body.get("ok"):
        return body.get("rows", [])
    return body

results = {}
print("=" * 60)
print("PHASE 1 AUDIT — Supabase avant adaptation BF")
print("=" * 60)

# 1. Données existantes dans prep_subjects
print("\n[1] prep_subjects (données existantes):")
r1 = sql("SELECT id, slug, title, description, is_active FROM app.prep_subjects ORDER BY sort_order")
print(json.dumps(r1, indent=2, ensure_ascii=False))
results["prep_subjects"] = r1

# 2. Données dans prep_badges (copiées depuis td_badges)
print("\n[2] prep_badges (données existantes):")
r2 = sql("SELECT id, code, title, emoji, xp_reward, condition_type, condition_value FROM app.prep_badges")
print(json.dumps(r2, indent=2, ensure_ascii=False))
results["prep_badges"] = r2

# 3. Données dans prep_ai_config
print("\n[3] prep_ai_config (données existantes):")
r3 = sql("SELECT config_key, config_value FROM app.prep_ai_config")
print(json.dumps(r3, indent=2, ensure_ascii=False))
results["prep_ai_config"] = r3

# 4. Données dans prep_questions (combien)
print("\n[4] prep_questions count:")
r4 = sql("SELECT COUNT(*) AS cnt FROM app.prep_questions")
print(json.dumps(r4, indent=2, ensure_ascii=False))
results["prep_questions_count"] = r4

# 5. Vérifier les colonnes de prep_questions (pour savoir si concours_type existe)
print("\n[5] prep_questions columns:")
r5 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = 'app' AND table_name = 'prep_questions' ORDER BY ordinal_position")
print(json.dumps(r5, indent=2, ensure_ascii=False))
results["prep_questions_columns"] = r5

# 6. Vérifier prep_question_banks
print("\n[6] prep_question_banks count + columns:")
r6a = sql("SELECT COUNT(*) AS cnt FROM app.prep_question_banks")
r6b = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = 'app' AND table_name = 'prep_question_banks' ORDER BY ordinal_position")
print(f"  Count: {r6a}")
print(f"  Columns: {json.dumps(r6b, indent=2, ensure_ascii=False)}")
results["prep_question_banks_count"] = r6a
results["prep_question_banks_columns"] = r6b

# 7. Vérifier le prompt système dans prep_ai_config
print("\n[7] System prompt actuel:")
r7 = sql("SELECT config_value FROM app.prep_ai_config WHERE config_key = 'system_prompt'")
print(json.dumps(r7, indent=2, ensure_ascii=False))
results["system_prompt"] = r7

# Save
out = Path(__file__).parent / "logs" / "audit_phase1_bf_adaptation.json"
out.parent.mkdir(exist_ok=True)
with open(out, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False)
print(f"\n✅ Sauvegardé: {out}")
