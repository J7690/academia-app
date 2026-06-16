#!/usr/bin/env python3
"""Audit mécanismes apprentissage et cache réponses Bobodo."""
from __future__ import annotations
import requests
from supabase_auto_manager import SupabaseAutoManager

def q(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/execute_sql"
    try:
        r = requests.post(url, headers=m.headers, json={"sql_query": sql}, timeout=30)
        if r.status_code != 200: print(f"  [HTTP {r.status_code}] {label}: {r.text[:200]}"); return []
        data = r.json()
        if isinstance(data, list): return data
        if isinstance(data, dict) and "error" in data: print(f"  [SQL ERR] {label}: {data['error']}"); return []
        return [data] if data else []
    except Exception as e: print(f"  [EXC] {label}: {e}"); return []

def section(t): print(f"\n{'='*60}\n  {t}\n{'='*60}")

def main():
    m = SupabaseAutoManager()
    print("\n🔬 AUDIT APPRENTISSAGE & CACHE BOBODO")

    section("1. Tables de cache / apprentissage existantes")
    cache_tables = q(m, "cache tables",
        "SELECT table_name FROM information_schema.tables "
        "WHERE table_schema='app' AND ("
        "  table_name ILIKE '%cache%' OR table_name ILIKE '%learn%' "
        "  OR table_name ILIKE '%answer%' OR table_name ILIKE '%qa%' "
        "  OR table_name ILIKE '%faq%' OR table_name ILIKE '%response%' "
        "  OR table_name ILIKE '%bobodo%' "
        ") ORDER BY table_name")
    for t in cache_tables:
        rows = q(m, f"count {t['table_name']}",
            f"SELECT COUNT(*) AS n FROM app.{t['table_name']}")
        n = rows[0].get('n','?') if rows else '?'
        print(f"  ✅ app.{t['table_name']:40s}  {n} lignes")

    section("2. Structure de bobodo_detected_needs")
    cols = q(m, "needs cols",
        "SELECT column_name, udt_name FROM information_schema.columns "
        "WHERE table_schema='app' AND table_name='bobodo_detected_needs' "
        "ORDER BY ordinal_position")
    for c in cols:
        print(f"  {c.get('column_name'):30s}  {c.get('udt_name')}")

    section("3. Contenu bobodo_detected_needs (questions posées)")
    needs = q(m, "needs sample",
        "SELECT question_text, category, created_at "
        "FROM app.bobodo_detected_needs "
        "ORDER BY created_at DESC LIMIT 20")
    for n in needs:
        print(f"  [{str(n.get('created_at',''))[:10]}] {str(n.get('category','?')):30s}  {str(n.get('question_text',''))[:55]}")

    section("4. bobodo_messages — statistiques")
    stats = q(m, "messages stats",
        "SELECT sender, COUNT(*) AS nb, "
        "COUNT(DISTINCT session_id) AS sessions "
        "FROM app.bobodo_messages GROUP BY sender")
    for s in stats:
        print(f"  {s.get('sender'):12s}  msgs={s.get('nb'):5}  sessions={s.get('sessions')}")

    section("5. Questions les plus fréquentes (regroupées)")
    freq = q(m, "frequent questions",
        "SELECT question_text, COUNT(*) AS nb "
        "FROM app.bobodo_detected_needs "
        "GROUP BY question_text HAVING COUNT(*) > 1 "
        "ORDER BY nb DESC LIMIT 15")
    if not freq:
        print("  (aucune question posée plus d'une fois détectée)")
    for f in freq:
        print(f"  x{f.get('nb'):2}  {str(f.get('question_text',''))[:70]}")

    section("6. Toutes sessions distinctes")
    sessions = q(m, "sessions",
        "SELECT COUNT(DISTINCT session_id) AS total_sessions, "
        "MIN(created_at) AS first_at, MAX(created_at) AS last_at "
        "FROM app.bobodo_messages")
    if sessions:
        s = sessions[0]
        print(f"  Sessions totales : {s.get('total_sessions')}")
        print(f"  Première session : {str(s.get('first_at',''))[:19]}")
        print(f"  Dernière session : {str(s.get('last_at',''))[:19]}")

    section("7. Vérification colonnes bobodo_knowledge (embedding présent?)")
    kb = q(m, "knowledge embedding check",
        "SELECT id, category, title, "
        "CASE WHEN embedding IS NOT NULL THEN 'oui' ELSE 'NON' END AS has_emb "
        "FROM app.bobodo_knowledge WHERE is_active=TRUE "
        "ORDER BY has_emb, category")
    no_emb = [r for r in kb if r.get('has_emb') == 'NON']
    print(f"  Total fiches actives    : {len(kb)}")
    print(f"  Sans embedding          : {len(no_emb)}")
    for r in no_emb:
        print(f"  ❌ [{r.get('category'):15s}] {r.get('title','')[:50]}")

    section("VERDICT")
    print("""
  MÉCANISME D'APPRENTISSAGE ACTUEL :
  ──────────────────────────────────
  ❌ Bobodo N'apprend PAS automatiquement.
     Le modèle LLM (OpenRouter) est pré-entraîné et figé.
     Seul le RAG (base bobodo_knowledge) enrichit les réponses,
     mais il faut MANUELLEMENT ajouter des fiches pour que
     Bobodo "sache" plus de choses.

  MÉCANISME DE CACHE ACTUEL :
  ────────────────────────────
  ❌ Aucun cache de réponses n'existe.
     Chaque question → appel OpenRouter → crédits consommés.

  CE QU'ON PEUT IMPLÉMENTER :
  ────────────────────────────
  ✅ A) Cache sémantique (app.bobodo_answer_cache)
        - Stocker question + embedding + réponse
        - Avant chaque appel OpenRouter, chercher par similarité vectorielle
        - Si score > 0.92 : retourner réponse en cache (0 crédit consommé)
        - TTL configurable (ex: 30 jours)

  ✅ B) Auto-enrichissement de la knowledge base
        - Quand une question est bien répondue (pas NO_ANSWER_SENTINEL),
          l'ajouter automatiquement à bobodo_knowledge si elle n'y est pas
        - Bobodo apprend des questions fréquentes

  ✅ C) Détection des questions fréquentes sans réponse
        - Analyser bobodo_detected_needs pour les catégories HORS_SCOPE
          répétées → alerter l'admin pour enrichir la knowledge base
    """)

    print("✅ Audit terminé.\n")

if __name__ == "__main__":
    main()
