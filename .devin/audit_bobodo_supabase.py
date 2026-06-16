#!/usr/bin/env python3
"""
Audit complet du module Bobodo dans Supabase.
Utilise execute_sql (SupabaseAutoManager) pour retourner les données réelles.
Usage: python audit_bobodo_supabase.py
"""
from __future__ import annotations

import json
import requests
from supabase_auto_manager import SupabaseAutoManager


def run_query(manager: SupabaseAutoManager, label: str, sql: str) -> list:
    """Exécute un SELECT via execute_sql et retourne les résultats."""
    url = f"{manager.url}/rest/v1/rpc/execute_sql"
    try:
        resp = requests.post(url, headers=manager.headers, json={"sql_query": sql}, timeout=30)
        if resp.status_code != 200:
            print(f"  [HTTP {resp.status_code}] {label}")
            print(f"  {resp.text[:300]}")
            return []
        data = resp.json()
        # execute_sql retourne une liste de dicts ou None
        if isinstance(data, list):
            return data
        if data is None:
            return []
        # parfois encapsulé dans {"error": ...}
        if isinstance(data, dict) and "error" in data:
            print(f"  [SQL ERROR] {label}: {data['error']}")
            return []
        return [data]
    except Exception as e:
        print(f"  [EXCEPTION] {label}: {e}")
        return []


def section(title: str):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")


def main():
    manager = SupabaseAutoManager()

    print("\n🔍 AUDIT BOBODO — Base Supabase Live")
    print("="*60)

    # ── 1. Existence et nombre de lignes des tables ─────────────────
    section("1. TABLES BOBODO — existence et lignes")
    tables = [
        "bobodo_sessions",
        "bobodo_messages",
        "bobodo_knowledge",
        "bobodo_unanswered_questions",
        "bobodo_detected_needs",
        "bobodo_feedback",
    ]
    for t in tables:
        rows = run_query(manager, f"count {t}",
            f"SELECT COUNT(*) AS nb FROM app.{t}")
        nb = rows[0]["nb"] if rows else "?"
        exists_rows = run_query(manager, f"exists {t}",
            f"SELECT EXISTS (SELECT 1 FROM information_schema.tables "
            f"WHERE table_schema='app' AND table_name='{t}') AS exists")
        exists = exists_rows[0]["exists"] if exists_rows else "?"
        status = "✅" if exists else "❌"
        print(f"  {status} app.{t} — {nb} lignes")

    # ── 2. Colonne embedding sur bobodo_knowledge ───────────────────
    section("2. COLONNE EMBEDDING sur bobodo_knowledge")
    cols = run_query(manager, "embedding col",
        "SELECT column_name, udt_name, data_type "
        "FROM information_schema.columns "
        "WHERE table_schema='app' AND table_name='bobodo_knowledge' "
        "ORDER BY ordinal_position")
    for c in cols:
        flag = "🔢" if c.get("column_name") == "embedding" else "  "
        print(f"  {flag} {c.get('column_name'):25s} {c.get('udt_name','')}")
    has_embedding = any(c.get("column_name") == "embedding" for c in cols)
    print(f"\n  Embedding vectoriel: {'✅ présent' if has_embedding else '❌ MANQUANT'}")

    # ── 3. RPCs Bobodo disponibles ──────────────────────────────────
    section("3. RPCs BOBODO existantes dans public")
    rpcs = run_query(manager, "rpcs",
        "SELECT routine_name, data_type AS return_type "
        "FROM information_schema.routines "
        "WHERE routine_schema='public' AND routine_name LIKE '%bobodo%' "
        "ORDER BY routine_name")
    if not rpcs:
        print("  ❌ Aucune RPC bobodo trouvée dans public")
    for r in rpcs:
        print(f"  ✅ {r.get('routine_name'):50s} → {r.get('return_type','')}")

    expected_rpcs = [
        "app_append_bobodo_message",
        "app_list_bobodo_messages",
        "app_search_bobodo_knowledge",
        "app_search_bobodo_knowledge_vector",
        "app_get_or_create_bobodo_session",
        "app_has_bobodo_assistant_message",
        "app_get_bobodo_student_first_name",
        "app_log_bobodo_detected_need",
        "app_add_bobodo_feedback",
        "app_admin_list_bobodo_sessions",
        "app_admin_list_bobodo_messages",
    ]
    found_names = {r.get("routine_name") for r in rpcs}
    print("\n  Vérification RPCs critiques:")
    for rpc in expected_rpcs:
        flag = "✅" if rpc in found_names else "❌ MANQUANT"
        print(f"  {flag} {rpc}")

    # ── 4. Statistiques messages ────────────────────────────────────
    section("4. STATISTIQUES MESSAGES (répartition par sender)")
    stats = run_query(manager, "msg stats",
        "SELECT sender, COUNT(*) AS nb, MAX(created_at) AS last_at "
        "FROM app.bobodo_messages "
        "GROUP BY sender ORDER BY nb DESC")
    if not stats:
        print("  Aucun message trouvé")
    for s in stats:
        print(f"  sender={s.get('sender'):12s}  nb={s.get('nb'):6}  last={s.get('last_at','?')[:19]}")

    # ── 5. Sessions ─────────────────────────────────────────────────
    section("5. SESSIONS — statistiques")
    sess = run_query(manager, "sessions",
        "SELECT COUNT(DISTINCT s.id) AS total_sessions, "
        "COUNT(DISTINCT CASE WHEN m.sender='assistant' THEN s.id END) AS with_ai_reply, "
        "COUNT(DISTINCT CASE WHEN m.sender='student' THEN s.id END) AS with_student, "
        "MAX(m.created_at) AS last_activity "
        "FROM app.bobodo_sessions s "
        "LEFT JOIN app.bobodo_messages m ON m.session_id = s.id")
    if sess:
        s = sess[0]
        print(f"  Sessions totales       : {s.get('total_sessions')}")
        print(f"  Avec réponse IA        : {s.get('with_ai_reply')}")
        print(f"  Avec message étudiant  : {s.get('with_student')}")
        print(f"  Dernière activité      : {str(s.get('last_activity','?'))[:19]}")

    # ── 6. Base de connaissances ────────────────────────────────────
    section("6. BOBODO_KNOWLEDGE — catégories et embeddings")
    know = run_query(manager, "knowledge",
        "SELECT category, COUNT(*) AS nb, "
        "COUNT(CASE WHEN embedding IS NOT NULL THEN 1 END) AS with_emb, "
        "COUNT(CASE WHEN embedding IS NULL THEN 1 END) AS without_emb "
        "FROM app.bobodo_knowledge WHERE is_active=TRUE "
        "GROUP BY category ORDER BY nb DESC")
    if not know:
        print("  ❌ Base de connaissances vide !")
    for k in know:
        emb_pct = int(k.get("with_emb",0)*100/max(k.get("nb",1),1))
        print(f"  {k.get('category'):30s}  entrées={k.get('nb'):4}  "
              f"avec_embedding={k.get('with_emb'):3} ({emb_pct}%)")

    total_know = run_query(manager, "total knowledge",
        "SELECT COUNT(*) AS total FROM app.bobodo_knowledge WHERE is_active=TRUE")
    total_emb = run_query(manager, "total embedding",
        "SELECT COUNT(*) AS total FROM app.bobodo_knowledge "
        "WHERE is_active=TRUE AND embedding IS NOT NULL")
    if total_know and total_emb:
        t = total_know[0].get("total",0)
        e = total_emb[0].get("total",0)
        print(f"\n  TOTAL: {t} entrées actives, {e} avec embedding ({int(e*100/max(t,1))}%)")
        if e < t:
            print(f"  ⚠️  {t-e} entrées SANS embedding — RAG vectoriel dégradé !")

    # ── 7. Questions non répondues ──────────────────────────────────
    section("7. QUESTIONS NON RÉPONDUES")
    uq = run_query(manager, "unanswered",
        "SELECT category, status, COUNT(*) AS nb "
        "FROM app.bobodo_unanswered_questions "
        "GROUP BY category, status ORDER BY nb DESC")
    if not uq:
        print("  (vide)")
    for u in uq:
        print(f"  {u.get('category'):30s}  status={u.get('status'):12}  nb={u.get('nb')}")

    # ── 8. Besoins détectés ─────────────────────────────────────────
    section("8. BESOINS DÉTECTÉS (classification)")
    needs = run_query(manager, "detected needs",
        "SELECT category, COUNT(*) AS nb, MAX(created_at) AS last_at "
        "FROM app.bobodo_detected_needs "
        "GROUP BY category ORDER BY nb DESC")
    if not needs:
        print("  (aucun besoin détecté)")
    for n in needs:
        print(f"  {n.get('category'):35s}  nb={n.get('nb'):5}  last={str(n.get('last_at','?'))[:19]}")

    # ── 9. Feedback ─────────────────────────────────────────────────
    section("9. FEEDBACK (up/down)")
    fb = run_query(manager, "feedback",
        "SELECT rating, COUNT(*) AS nb FROM app.bobodo_feedback GROUP BY rating")
    if not fb:
        print("  (aucun feedback)")
    for f in fb:
        print(f"  {f.get('rating'):6}  → {f.get('nb')} votes")

    # ── 10. Exemples de questions HORS_SCOPE récentes ───────────────
    section("10. EXEMPLES DE QUESTIONS RÉCENTES CLASSÉES HORS_SCOPE")
    hors = run_query(manager, "hors scope",
        "SELECT question_text, created_at FROM app.bobodo_detected_needs "
        "WHERE category='HORS_SCOPE' ORDER BY created_at DESC LIMIT 10")
    if not hors:
        # aussi dans unanswered
        hors = run_query(manager, "hors scope unanswered",
            "SELECT question_text, created_at FROM app.bobodo_unanswered_questions "
            "WHERE category='HORS_SCOPE' ORDER BY created_at DESC LIMIT 10")
    if not hors:
        print("  (aucun HORS_SCOPE dans les logs)")
    for h in hors:
        q = str(h.get("question_text",""))[:80]
        print(f"  [{str(h.get('created_at',''))[:10]}] {q}")

    # ── 11. Exemples de messages récents avec sentinel ───────────────
    section("11. MESSAGES CONTENANT LE SENTINEL __BOBODO_NO_ANSWER__")
    sentinel = run_query(manager, "sentinel",
        "SELECT m.content, m.created_at FROM app.bobodo_messages m "
        "WHERE m.sender='assistant' "
        "AND m.content LIKE '%__BOBODO_NO_ANSWER__%' "
        "ORDER BY m.created_at DESC LIMIT 5")
    if not sentinel:
        print("  ✅ Aucun sentinel trouvé en base (ou aucun message enregistré)")
    else:
        print(f"  ⚠️  {len(sentinel)} message(s) contenant le sentinel !")
        for s in sentinel:
            print(f"  [{str(s.get('created_at',''))[:19]}] {str(s.get('content',''))[:80]}")

    # ── 12. Longueur moyenne des conversations ──────────────────────
    section("12. LONGUEUR MOYENNE DES CONVERSATIONS")
    avg = run_query(manager, "avg conv",
        "SELECT AVG(msg_count) AS avg_messages, MAX(msg_count) AS max_messages, "
        "MIN(msg_count) AS min_messages "
        "FROM (SELECT session_id, COUNT(*) AS msg_count "
        "FROM app.bobodo_messages GROUP BY session_id) sub")
    if avg and avg[0].get("avg_messages"):
        a = avg[0]
        print(f"  Moyenne messages/session : {float(a.get('avg_messages',0)):.1f}")
        print(f"  Maximum                  : {a.get('max_messages')}")
        print(f"  Minimum                  : {a.get('min_messages')}")

    # ── SYNTHÈSE ────────────────────────────────────────────────────
    section("SYNTHÈSE — Points d'action")
    print("""
  PROBLÈMES CONFIRMÉS À CORRIGER :

  [P1] 🔴 Sentinel __BOBODO_NO_ANSWER__ jamais filtré avant retour
       → Fix: intercepter dans generateAnswerForCategory avant de retourner

  [P2] 🔴 Filtre sécurité trop large (armes, sexe, drogue…)
       → Fix: remplacer includes() par regex de phrases précises

  [P3] 🟠 Historique limité 8 messages + RAG sans contexte conv
       → Fix: passer à 14 msg + enrichir query RAG avec historique

  [P4] 🟠 Override règles keyword écrase classification IA
       → Fix: supprimer le forçage NEXIOM si l'IA a classé autrement

  [P5] 🟡 max_tokens=350 → réponses tronquées
       → Fix: 600 tokens standard, 300 pour small talk

  [P6] 🟡 Détection suivi "oui/non" trop limitée
       → Fix: élargir + détecter messages < 20 chars avec historique

  [P7] 🟡 HORS_SCOPE → pas de tentative de réponse utile
       → Fix: pour HORS_SCOPE, essayer quand même de répondre
              avec système prompt "assistant général"
    """)

    print("✅ Audit terminé.\n")


if __name__ == "__main__":
    main()
