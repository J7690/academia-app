#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Audit complet pour la machine de scoring actualités concours.
Vérifie: questions passées, catégories, notifications, préférences étudiant.
"""
import json
import sys
import pathlib
import requests

sys.stdout.reconfigure(encoding='utf-8')

from supabase_auto_manager import SupabaseAutoManager
m = SupabaseAutoManager()

def sql(q):
    r = requests.post(
        f"{m.url}/rest/v1/rpc/admin_execute_sql",
        headers=m.headers,
        json={"p_sql": q.strip()},
        timeout=60
    ).json()
    return r

results = {}

# ═══════════════════════════════════════════════════════════════
# 1. QUESTIONS PASSÉES — structure et contenu
# ═══════════════════════════════════════════════════════════════
print("=== 1. PREP_QUESTIONS — Structure ===")
r1 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='prep_questions' ORDER BY ordinal_position")
results["prep_questions_columns"] = r1
if r1.get("rows"):
    for row in r1["rows"]:
        print(f"  {row['column_name']} ({row['data_type']})")

print("\n=== 2. PREP_QUESTIONS — Comptage par sujet ===")
r2 = sql("SELECT subject, count(*)::text AS n FROM app.prep_questions GROUP BY subject ORDER BY count(*) DESC LIMIT 20")
results["questions_by_subject"] = r2
if r2.get("rows"):
    for row in r2["rows"]:
        print(f"  {row.get('subject','NULL')}: {row['n']}")
else:
    print(f"  ERR: {r2.get('error','?')[:200]}")

print("\n=== 3. PREP_QUESTIONS — Comptage total ===")
r3 = sql("SELECT count(*)::text AS n FROM app.prep_questions")
results["questions_total"] = r3.get("rows", [{}])[0].get("n", "ERR") if r3.get("rows") else "ERR"
print(f"  Total: {results['questions_total']}")

print("\n=== 4. PREP_QUESTIONS — Exemples (5 dernières) ===")
r4 = sql("SELECT LEFT(content, 150) AS preview, subject, tags, concours_type, difficulty FROM app.prep_questions ORDER BY created_at DESC LIMIT 5")
results["questions_recent"] = r4
if r4.get("rows"):
    for row in r4["rows"]:
        print(f"  [{row.get('subject','?')}] [{row.get('concours_type','?')}] {row.get('preview','')[:100]}")
        if row.get("tags"):
            print(f"    tags: {row['tags']}")

print("\n=== 5. PREP_QUESTIONS — Tags uniques ===")
r5 = sql("SELECT DISTINCT unnest(tags) AS tag FROM app.prep_questions ORDER BY tag LIMIT 30")
results["unique_tags"] = r5
if r5.get("rows"):
    tags = [row.get("tag","") for row in r5["rows"]]
    print(f"  {', '.join(tags)}")
else:
    print(f"  ERR: {r5.get('error','?')[:200]}")

print("\n=== 6. PREP_QUESTIONS — concours_type distincts ===")
r6 = sql("SELECT concours_type, count(*)::text AS n FROM app.prep_questions GROUP BY concours_type ORDER BY count(*) DESC")
results["questions_by_concours"] = r6
if r6.get("rows"):
    for row in r6["rows"]:
        print(f"  {row.get('concours_type','NULL')}: {row['n']}")

# ═══════════════════════════════════════════════════════════════
# 7. TABLES PREP — sujets/matières
# ═══════════════════════════════════════════════════════════════
print("\n=== 7. PREP_SUBJECTS ===")
r7 = sql("SELECT id, title, slug FROM app.prep_subjects ORDER BY title LIMIT 25")
results["prep_subjects"] = r7
if r7.get("rows"):
    for row in r7["rows"]:
        print(f"  {row['slug']} — {row['title']}")
else:
    print(f"  ERR: {r7.get('error','?')[:200]}")

# ═══════════════════════════════════════════════════════════════
# 8. NOTIFICATIONS — tables existantes
# ═══════════════════════════════════════════════════════════════
print("\n=== 8. NOTIFICATION_EVENTS — Structure ===")
r8 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='notification_events' ORDER BY ordinal_position")
results["notification_events_cols"] = r8
if r8.get("rows"):
    for row in r8["rows"]:
        print(f"  {row['column_name']} ({row['data_type']})")

print("\n=== 9. NOTIFICATION_EVENTS — event_type distincts ===")
r9 = sql("SELECT event_type, count(*)::text AS n FROM app.notification_events GROUP BY event_type ORDER BY count(*) DESC LIMIT 15")
results["notification_types"] = r9
if r9.get("rows"):
    for row in r9["rows"]:
        print(f"  {row.get('event_type','?')}: {row['n']}")

# ═══════════════════════════════════════════════════════════════
# 10. USER_DEVICE_TOKENS
# ═══════════════════════════════════════════════════════════════
print("\n=== 10. USER_DEVICE_TOKENS ===")
r10 = sql("SELECT count(*)::text AS n FROM app.user_device_tokens WHERE is_active = true")
results["active_device_tokens"] = r10.get("rows", [{}])[0].get("n", "ERR") if r10.get("rows") else "ERR"
print(f"  Tokens FCM actifs: {results['active_device_tokens']}")

# ═══════════════════════════════════════════════════════════════
# 11. PRÉFÉRENCES ÉTUDIANT — tables existantes ?
# ═══════════════════════════════════════════════════════════════
print("\n=== 11. TABLES PRÉFÉRENCES ===")
r11 = sql("SELECT tablename FROM pg_tables WHERE schemaname='app' AND (tablename LIKE '%pref%' OR tablename LIKE '%setting%' OR tablename LIKE '%notification_pref%' OR tablename LIKE '%opt%') ORDER BY tablename")
results["preference_tables"] = r11
if r11.get("rows"):
    for row in r11["rows"]:
        print(f"  {row['tablename']}")
else:
    print("  AUCUNE TABLE DE PRÉFÉRENCES TROUVÉE")

print("\n=== 12. USER_NOTIFICATION_STATE ===")
r12 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='user_notification_state' ORDER BY ordinal_position")
results["user_notification_state_cols"] = r12
if r12.get("rows"):
    for row in r12["rows"]:
        print(f"  {row['column_name']} ({row['data_type']})")

# ═══════════════════════════════════════════════════════════════
# 13. PREP_DOC_CHUNKS — chunk_types existants
# ═══════════════════════════════════════════════════════════════
print("\n=== 13. PREP_DOC_CHUNKS — chunk_type distincts ===")
r13 = sql("SELECT chunk_type, count(*)::text AS n FROM app.prep_doc_chunks GROUP BY chunk_type ORDER BY count(*) DESC")
results["chunk_types"] = r13
if r13.get("rows"):
    for row in r13["rows"]:
        print(f"  {row.get('chunk_type','NULL')}: {row['n']}")

# ═══════════════════════════════════════════════════════════════
# 14. PREP_NEWS_ARTICLES — articles avec metadata
# ═══════════════════════════════════════════════════════════════
print("\n=== 14. PREP_NEWS_ARTICLES — colonnes ===")
r14 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='prep_news_articles' ORDER BY ordinal_position")
results["news_articles_cols"] = r14
if r14.get("rows"):
    for row in r14["rows"]:
        print(f"  {row['column_name']} ({row['data_type']})")

# ═══════════════════════════════════════════════════════════════
# 15. PREP_TOPIC_PREDICTIONS — système de prédiction existant ?
# ═══════════════════════════════════════════════════════════════
print("\n=== 15. PREP_TOPIC_PREDICTIONS ===")
r15 = sql("SELECT count(*)::text AS n FROM app.prep_topic_predictions")
results["topic_predictions_count"] = r15
if r15.get("rows"):
    print(f"  Prédictions existantes: {r15['rows'][0].get('n','?')}")
else:
    print(f"  ERR: {r15.get('error','?')[:200]}")

r15b = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='prep_topic_predictions' ORDER BY ordinal_position")
results["topic_predictions_cols"] = r15b
if r15b.get("rows"):
    for row in r15b["rows"]:
        print(f"  {row['column_name']} ({row['data_type']})")

# ═══════════════════════════════════════════════════════════════
# 16. PREP_TOPICS — thèmes existants
# ═══════════════════════════════════════════════════════════════
print("\n=== 16. PREP_TOPICS ===")
r16 = sql("SELECT count(*)::text AS n FROM app.prep_topics")
results["topics_count"] = r16
if r16.get("rows"):
    print(f"  Topics: {r16['rows'][0].get('n','?')}")
r16b = sql("SELECT id, name, subject_id, frequency_score FROM app.prep_topics ORDER BY frequency_score DESC NULLS LAST LIMIT 10")
results["topics_top"] = r16b
if r16b.get("rows"):
    for row in r16b["rows"]:
        print(f"  [{row.get('frequency_score','?')}] {row.get('name','?')}")

# ═══════════════════════════════════════════════════════════════
# 17. Edge Function prep-analyze-trends
# ═══════════════════════════════════════════════════════════════
print("\n=== 17. EDGE FUNCTIONS liées ===")
r17 = sql("SELECT proname FROM pg_proc WHERE proname LIKE '%trend%' OR proname LIKE '%predict%' ORDER BY proname")
results["trend_rpcs"] = r17
if r17.get("rows"):
    for row in r17["rows"]:
        print(f"  {row['proname']}")
else:
    print("  Aucune RPC trend/predict trouvée")

# ═══════════════════════════════════════════════════════════════
# 18. RPCs notification existantes
# ═══════════════════════════════════════════════════════════════
print("\n=== 18. RPCs NOTIFICATION ===")
r18 = sql("SELECT proname FROM pg_proc WHERE proname LIKE '%notif%' AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname='public') ORDER BY proname")
results["notification_rpcs"] = r18
if r18.get("rows"):
    for row in r18["rows"]:
        print(f"  {row['proname']}")

# ═══════════════════════════════════════════════════════════════
# 19. Fonction app_queue_notification_event
# ═══════════════════════════════════════════════════════════════
print("\n=== 19. app_queue_notification_event signature ===")
r19 = sql("SELECT pg_get_functiondef(oid) AS def FROM pg_proc WHERE proname='app_queue_notification_event' LIMIT 1")
results["queue_notif_fn"] = r19
if r19.get("rows"):
    defn = r19["rows"][0].get("def","")[:500]
    print(f"  {defn}")

# Save
out = pathlib.Path("logs/audit_concours_scoring_machine.json")
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(results, ensure_ascii=False, indent=2, default=str), encoding="utf-8")
print(f"\n[OK] Log: {out}")
