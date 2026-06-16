#!/usr/bin/env python3
"""Generate initial batch of sujets blancs (mock exams) for different concours types."""
import json, requests, time
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()

url = f"{m.url}/functions/v1/prep-compose-exam-blanc"
headers = {
    "Authorization": f"Bearer {m.service_key}",
    "apikey": m.service_key,
    "Content-Type": "application/json",
}

# Generate one exam per major concours type
concours_types = [
    ("TOUS", "Sujet blanc — Concours Général #1"),
    ("ENAREF", "Sujet blanc — ENAREF #1"),
    ("ADMIN_CIVIL", "Sujet blanc — Administrateur Civil #1"),
]

for ct, title in concours_types:
    print(f"\n🔄 Generating: {title}...")
    start = time.time()
    try:
        resp = requests.post(url, headers=headers, json={
            "concours_type": ct,
            "title": title,
        }, timeout=300)  # 5 min timeout (LLM can be slow)
        
        elapsed = time.time() - start
        print(f"  Status: {resp.status_code} ({elapsed:.1f}s)")
        
        data = resp.json()
        if data.get("success"):
            print(f"  ✅ {data.get('total_questions')} questions generated")
            for s in data.get("sections_summary", []):
                print(f"     • {s['subject']}: {s['questions']} questions")
        else:
            print(f"  ❌ Error: {data.get('error', data.get('message', 'unknown'))}")
    except Exception as e:
        elapsed = time.time() - start
        print(f"  ❌ Exception ({elapsed:.1f}s): {e}")

print("\n✅ Done generating initial sujets blancs.")
