#!/usr/bin/env python3
"""
Test intégral Bobodo — vérifie que tous les mécanismes fonctionnent.
Audit en base de données : cache, messages, knowledge, RPCs exposées.
"""
from __future__ import annotations
import requests, json
from supabase_auto_manager import SupabaseAutoManager


def q(m, sql):
    r = requests.post(f"{m.url}/rest/v1/rpc/execute_sql",
        headers=m.headers, json={"sql_query": sql}, timeout=30)
    data = r.json()
    return data if isinstance(data, list) else ([data] if data else [])


def section(t):
    print(f"\n{'='*60}\n  {t}\n{'='*60}")


def check(label, ok):
    print(f"  {'✅' if ok else '❌'} {label}")
    return ok


def main():
    m = SupabaseAutoManager()
    results = {"pass": 0, "fail": 0}

    def test(label, ok):
        if ok:
            results["pass"] += 1
        else:
            results["fail"] += 1
        print(f"  {'✅' if ok else '❌'} {label}")

    print("\n🧪 TEST INTÉGRAL BOBODO")
    print("="*60)

    # ── 1. Knowledge base ────────────────────────────────────────────
    section("1. KNOWLEDGE BASE (RAG)")
    kb = q(m,
        "SELECT COUNT(*) AS total, "
        "COUNT(CASE WHEN embedding IS NOT NULL THEN 1 END) AS with_emb, "
        "COUNT(CASE WHEN is_active THEN 1 END) AS active "
        "FROM app.bobodo_knowledge")
    if kb:
        r = kb[0]
        test("Fiches actives > 0", int(r.get("active", 0)) > 0)
        test("100% embeddings", int(r.get("active", 0)) == int(r.get("with_emb", 0)))
        test("Pas de doublons (≤15 fiches actives)", int(r.get("active", 0)) <= 15)
        print(f"     → {r.get('active')} fiches actives, {r.get('with_emb')} embeddings")

    cats = q(m,
        "SELECT DISTINCT category FROM app.bobodo_knowledge WHERE is_active=TRUE ORDER BY category")
    cat_names = [c.get("category") for c in cats]
    test("Catégorie 'nexiom' présente", "nexiom" in cat_names)
    test("Catégorie 'academia' présente", "academia" in cat_names)
    test("Catégorie 'process' présente", "process" in cat_names)

    # ── 2. RPCs Bobodo exposées ──────────────────────────────────────
    section("2. RPCs BOBODO")
    rpcs_required = [
        "app_search_bobodo_knowledge",
        "app_search_bobodo_knowledge_vector",
        "app_append_bobodo_message",
        "app_has_bobodo_assistant_message",
        "app_get_bobodo_student_first_name",
        "app_search_bobodo_answer_cache",
        "app_bobodo_cache_hit",
        "app_insert_bobodo_answer_cache",
    ]
    for rpc in rpcs_required:
        exists = q(m,
            f"SELECT 1 AS n FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
            f"WHERE (n.nspname='app' OR n.nspname='public') AND p.proname='{rpc}'")
        test(f"RPC {rpc}", bool(exists and exists[0]))

    # ── 3. Cache sémantique ──────────────────────────────────────────
    section("3. CACHE SÉMANTIQUE")
    cache_table = q(m,
        "SELECT COUNT(*) AS n FROM information_schema.tables "
        "WHERE table_schema='app' AND table_name='bobodo_answer_cache'")
    test("Table bobodo_answer_cache existe", bool(cache_table and int(cache_table[0].get("n", 0)) > 0))

    cache_idx = q(m,
        "SELECT COUNT(*) AS n FROM pg_indexes "
        "WHERE schemaname='app' AND tablename='bobodo_answer_cache' "
        "AND indexname='idx_bobodo_answer_cache_embedding'")
    test("Index vectoriel ivfflat présent", bool(cache_idx and int(cache_idx[0].get("n", 0)) > 0))

    cache_entries = q(m,
        "SELECT COUNT(*) AS n FROM app.bobodo_answer_cache")
    n_cache = int(cache_entries[0].get("n", 0)) if cache_entries else 0
    print(f"     → {n_cache} entrées dans le cache actuellement")

    # ── 4. Messages récents ──────────────────────────────────────────
    section("4. MESSAGES RÉCENTS (production)")
    recent = q(m,
        "SELECT sender, content, created_at "
        "FROM app.bobodo_messages "
        "ORDER BY created_at DESC LIMIT 6")
    for msg in recent:
        sender = msg.get("sender", "?")
        content = str(msg.get("content", ""))[:70]
        ts = str(msg.get("created_at", ""))[:19]
        print(f"  [{ts}] {sender:10s} {content}")

    # ── 5. Vérification anti-salutation répétée ──────────────────────
    section("5. TEST SALUTATION NON RÉPÉTÉE")
    sessions_with_multi = q(m,
        "SELECT session_id, COUNT(*) AS msg_count "
        "FROM app.bobodo_messages WHERE sender='assistant' "
        "GROUP BY session_id HAVING COUNT(*) >= 2 "
        "ORDER BY MAX(created_at) DESC LIMIT 3")

    for sess in sessions_with_multi:
        sid = sess.get("session_id")
        msgs = q(m,
            f"SELECT content, created_at "
            f"FROM app.bobodo_messages "
            f"WHERE session_id='{sid}' AND sender='assistant' "
            f"ORDER BY created_at ASC")
        # Le 1er message peut avoir "Bonjour", les suivants NON
        greeting_count = 0
        for i, msg in enumerate(msgs):
            c = str(msg.get("content", "")).strip()
            starts_with_greeting = (
                c.lower().startswith("bonjour") or
                c.lower().startswith("bonsoir") or
                c.lower().startswith("salut")
            )
            if starts_with_greeting:
                greeting_count += 1
        expected = 1  # seul le premier devrait avoir un greeting
        ok = greeting_count <= expected
        test(f"Session {str(sid)[:8]}... ({len(msgs)} msgs): "
             f"{'1 greeting' if greeting_count<=1 else f'{greeting_count} greetings ⚠️'}",
             ok)

    # ── 6. Architecture 3 niveaux ────────────────────────────────────
    section("6. ARCHITECTURE 3 NIVEAUX")
    # Vérifier qu'aucun message ne contient "Source web" pour des catégories interdites
    web_in_forbidden = q(m,
        "SELECT bm.content, bdn.category "
        "FROM app.bobodo_messages bm "
        "JOIN app.bobodo_detected_needs bdn ON bdn.session_id = bm.session_id "
        "WHERE bm.sender='assistant' "
        "AND bm.content ILIKE '%source web%' "
        "AND bdn.category IN ('HORS_SCOPE','AUTRE_UNIVERSITE_OU_ENTREPRISE','PARTENAIRE_UNIVERSITE_DETAILLEE') "
        "LIMIT 5")
    test("Pas de 'Source web' dans catégories interdites", len(web_in_forbidden) == 0)

    # Vérifier que les catégories détectées sont cohérentes
    cat_stats = q(m,
        "SELECT category, COUNT(*) AS n "
        "FROM app.bobodo_detected_needs "
        "GROUP BY category ORDER BY n DESC")
    print("  Catégories détectées en production:")
    for c in cat_stats:
        print(f"     {c.get('category','?'):35s} x{c.get('n','?')}")

    # ── 7. Edge Function déployée ────────────────────────────────────
    section("7. EDGE FUNCTION BOBODO-CHAT")
    # Tester que l'endpoint est accessible (sans JWT = 401, mais prouve qu'il existe)
    try:
        url = f"{m.url}/functions/v1/bobodo-chat"
        r = requests.options(url, timeout=10)
        test("Edge Function accessible (CORS)", r.status_code == 200)
    except Exception:
        test("Edge Function accessible", False)

    try:
        r2 = requests.post(url, json={}, timeout=10)
        # On s'attend à 401 (pas de JWT) = l'endpoint existe et fonctionne
        test("Edge Function répond (401 sans JWT = normal)", r2.status_code == 401)
    except Exception:
        test("Edge Function répond", False)

    # ── VERDICT ──────────────────────────────────────────────────────
    section("VERDICT FINAL")
    total = results["pass"] + results["fail"]
    print(f"\n  {results['pass']}/{total} tests passés")
    if results["fail"] == 0:
        print("  🎉 BOBODO 100% OPÉRATIONNEL")
    else:
        print(f"  ⚠️  {results['fail']} test(s) échoué(s)")

    print("\n✅ Test intégral terminé.\n")


if __name__ == "__main__":
    main()
