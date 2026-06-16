#!/usr/bin/env python3
"""
Audit architecture 3-niveaux Bobodo.
Interroge Supabase via execute_sql (SupabaseAutoManager) pour cartographier
le mécanisme de recherche (local / web / IA) et détecter les incohérences.
Usage: python audit_bobodo_architecture.py
"""
from __future__ import annotations
import json, requests
from supabase_auto_manager import SupabaseAutoManager


def q(manager: SupabaseAutoManager, label: str, sql: str) -> list:
    url = f"{manager.url}/rest/v1/rpc/execute_sql"
    try:
        r = requests.post(url, headers=manager.headers, json={"sql_query": sql}, timeout=30)
        if r.status_code != 200:
            print(f"  [HTTP {r.status_code}] {label}: {r.text[:200]}")
            return []
        data = r.json()
        if isinstance(data, list):   return data
        if isinstance(data, dict) and "error" in data:
            print(f"  [SQL ERR] {label}: {data['error']}")
            return []
        return [data] if data else []
    except Exception as e:
        print(f"  [EXC] {label}: {e}")
        return []


def section(t): print(f"\n{'='*62}\n  {t}\n{'='*62}")


def main():
    m = SupabaseAutoManager()
    print("\n🔎 AUDIT ARCHITECTURE 3-NIVEAUX BOBODO")
    print("="*62)

    # ── 1. SECRETS Edge Function configurés ─────────────────────────
    section("1. EDGE FUNCTION SECRETS (via pg_settings)")
    # Supabase stocke les secrets dans vault.secrets ou dans les env de l'EF
    # On peut vérifier lesquels sont présents via la table vault
    vault = q(m, "vault secrets",
        "SELECT name, created_at FROM vault.secrets "
        "WHERE name ILIKE '%openrouter%' OR name ILIKE '%websearch%' "
        "OR name ILIKE '%perplexity%' OR name ILIKE '%bobodo%' "
        "ORDER BY name")
    if not vault:
        print("  (vault inaccessible ou aucun secret Bobodo trouvé)")
    for v in vault:
        print(f"  🔑 {v.get('name')}")

    # ── 2. TABLE bobodo_config (si elle existe) ─────────────────────
    section("2. TABLE DE CONFIGURATION BOBODO")
    conf_exists = q(m, "config table",
        "SELECT EXISTS (SELECT 1 FROM information_schema.tables "
        "WHERE table_schema='app' AND table_name='bobodo_config') AS exists")
    has_conf = conf_exists[0].get("exists", False) if conf_exists else False
    print(f"  app.bobodo_config existe : {'✅' if has_conf else '❌ NON'}")

    if has_conf:
        conf_rows = q(m, "config rows",
            "SELECT key, value FROM app.bobodo_config ORDER BY key")
        for r in conf_rows:
            print(f"  {r.get('key'):35s} = {r.get('value')}")

    # ── 3. TABLE bobodo_search_settings (si elle existe) ────────────
    section("3. TABLE SEARCH SETTINGS")
    search_tables = q(m, "search settings tables",
        "SELECT table_name FROM information_schema.tables "
        "WHERE table_schema='app' AND table_name ILIKE '%bobodo%search%' "
        "OR (table_schema='app' AND table_name ILIKE '%search%setting%')")
    if not search_tables:
        print("  ❌ Aucune table de paramétrage de recherche trouvée")
    for t in search_tables:
        print(f"  ✅ {t.get('table_name')}")

    # ── 4. TOUTES les tables Bobodo ──────────────────────────────────
    section("4. INVENTAIRE TABLES BOBODO")
    tables = q(m, "all bobodo tables",
        "SELECT table_name FROM information_schema.tables "
        "WHERE table_schema='app' AND table_name LIKE 'bobodo%' "
        "ORDER BY table_name")
    for t in tables:
        rows = q(m, f"count {t.get('table_name')}",
            f"SELECT COUNT(*) AS n FROM app.{t.get('table_name')}")
        n = rows[0].get("n","?") if rows else "?"
        print(f"  app.{t.get('table_name'):40s}  {n} lignes")

    # ── 5. COLONNES de bobodo_knowledge ─────────────────────────────
    section("5. COLONNES app.bobodo_knowledge")
    cols = q(m, "knowledge cols",
        "SELECT column_name, udt_name, is_nullable "
        "FROM information_schema.columns "
        "WHERE table_schema='app' AND table_name='bobodo_knowledge' "
        "ORDER BY ordinal_position")
    for c in cols:
        print(f"  {c.get('column_name'):30s}  {c.get('udt_name'):15s}  nullable={c.get('is_nullable')}")

    # ── 6. CATÉGORIES autorisées en base de connaissances ───────────
    section("6. CATÉGORIES knowledge (contenu local)")
    cats = q(m, "categories",
        "SELECT category, COUNT(*) AS n, "
        "COUNT(CASE WHEN embedding IS NOT NULL THEN 1 END) AS with_emb "
        "FROM app.bobodo_knowledge WHERE is_active=TRUE "
        "GROUP BY category ORDER BY n DESC")
    if not cats:
        print("  ❌ Base de connaissances vide")
    for c in cats:
        print(f"  {c.get('category'):35s}  entrées={c.get('n'):3}  embedding={c.get('with_emb')}")

    # ── 7. CATÉGORIES détectées dans les messages ────────────────────
    section("7. CATÉGORIES DÉTECTÉES EN PRODUCTION (bobodo_detected_needs)")
    needs = q(m, "detected needs",
        "SELECT category, COUNT(*) AS nb, "
        "MAX(created_at) AS last_at "
        "FROM app.bobodo_detected_needs "
        "GROUP BY category ORDER BY nb DESC")
    print(f"  {'CATÉGORIE':38s}  {'NB':>5}  DERNIER")
    for n in needs:
        print(f"  {str(n.get('category','?')):38s}  {str(n.get('nb','?')):>5}  {str(n.get('last_at','?'))[:19]}")

    # ── 8. QUESTIONS HORS_SCOPE (pour calibrer le filtre) ───────────
    section("8. QUESTIONS CLASSÉES HORS_SCOPE (échantillon 15 dernières)")
    hors = q(m, "hors scope",
        "SELECT question_text, created_at "
        "FROM app.bobodo_unanswered_questions "
        "WHERE category='HORS_SCOPE' "
        "ORDER BY created_at DESC LIMIT 15")
    if not hors:
        hors = q(m, "hors scope needs",
            "SELECT question_text, created_at "
            "FROM app.bobodo_detected_needs "
            "WHERE category='HORS_SCOPE' "
            "ORDER BY created_at DESC LIMIT 15")
    if not hors:
        print("  (aucune question HORS_SCOPE loguée)")
    for h in hors:
        print(f"  [{str(h.get('created_at',''))[:10]}] {str(h.get('question_text',''))[:70]}")

    # ── 9. MESSAGES contenant une URL externe (trace web search) ────
    section("9. MESSAGES IA CONTENANT UNE URL (trace recherche web)")
    urls = q(m, "messages with url",
        "SELECT content, created_at FROM app.bobodo_messages "
        "WHERE sender='assistant' "
        "AND (content LIKE '%http://%' OR content LIKE '%https://%') "
        "ORDER BY created_at DESC LIMIT 5")
    if not urls:
        print("  ✅ Aucun message avec URL externe trouvé (web search non déclenché)")
    for u in urls:
        print(f"  [{str(u.get('created_at',''))[:19]}] {str(u.get('content',''))[:80]}")

    # ── 10. MESSAGES avec "Source web" (trace Perplexity V2) ─────────
    section("10. MESSAGES CONTENANT 'Source web' (Perplexity V2)")
    perp = q(m, "perplexity trace",
        "SELECT content, created_at FROM app.bobodo_messages "
        "WHERE sender='assistant' "
        "AND content ILIKE '%source web%' "
        "ORDER BY created_at DESC LIMIT 5")
    if not perp:
        print("  ✅ Aucun message avec 'Source web' trouvé")
    else:
        print(f"  ⚠️  {len(perp)} message(s) avec 'Source web'")
        for p in perp:
            print(f"  [{str(p.get('created_at',''))[:19]}] {str(p.get('content',''))[:80]}")

    # ── 11. RPCs qui gèrent la recherche / filtrage ──────────────────
    section("11. RPCs DE RECHERCHE ET FILTRAGE")
    rpcs = q(m, "search rpcs",
        "SELECT routine_name, data_type "
        "FROM information_schema.routines "
        "WHERE routine_schema='public' "
        "AND (routine_name ILIKE '%bobodo%search%' "
        "OR routine_name ILIKE '%bobodo%knowledge%' "
        "OR routine_name ILIKE '%bobodo%filter%' "
        "OR routine_name ILIKE '%bobodo%config%') "
        "ORDER BY routine_name")
    if not rpcs:
        print("  (aucune RPC de configuration/filtrage spécifique)")
    for r in rpcs:
        print(f"  ✅ {r.get('routine_name'):50s}  → {r.get('data_type')}")

    # ── 12. CONTENU des fiches knowledge (titres + catégories) ──────
    section("12. FICHES KNOWLEDGE — titres et catégories")
    fiches = q(m, "knowledge titles",
        "SELECT id, category, title, is_active, "
        "CASE WHEN embedding IS NOT NULL THEN '✅' ELSE '❌' END AS has_emb "
        "FROM app.bobodo_knowledge "
        "ORDER BY category, title")
    for f in fiches:
        active = "✅" if f.get("is_active") else "❌"
        print(f"  [{active}] {str(f.get('category','?')):22s}  "
              f"{f.get('has_emb','')}emb  {str(f.get('title',''))[:50]}")

    # ── VERDICT ──────────────────────────────────────────────────────
    section("VERDICT — Points à analyser")
    print("""
  ARCHITECTURE ORIGINALE (Python backend main.py):
  ─────────────────────────────────────────────────
  Niveau 1 : Base locale → app_search_bobodo_knowledge (RPC Supabase)
  Niveau 2 : Web Search  → perform_web_search() via WEBSEARCH_API_KEY +
                           WEBSEARCH_ENGINE (Google/SerpAPI)
             GARDIEN: désactivé si WEBSEARCH_API_KEY ou WEBSEARCH_ENGINE absent
             GARDIEN: retourne [] si query vide
             NOTE: generate_answer_for_category() NON TROUVÉE dans main.py
                   (possiblement jamais implémentée ou dans un autre fichier)
  Niveau 3 : OpenRouter  → call_openrouter() avec knowledge + web results

  ARCHITECTURE V2 EDGE FUNCTION (mon implémentation):
  ─────────────────────────────────────────────────
  Niveau 1 : Base locale (vector + text search + expansion sémantique)
  Niveau 2 : Perplexity sonar-small-online via OpenRouter API
             GARDIEN actuel: désactivé pour NEXIOM_ACADEMIA_INTERNE + SMALL_TALK
             ⚠️  MANQUE: pas de gardien sur AUTRE_UNIVERSITE_OU_ENTREPRISE
             ⚠️  MANQUE: pas de gardien sur HORS_SCOPE général
             ⚠️  MANQUE: l'original utilisait une clé dédiée WEBSEARCH_API_KEY
                         (pas de dépense OpenRouter pour le web search)
  Niveau 3 : OpenRouter chat completion avec le résultat web comme contexte
    """)

    print("✅ Audit terminé.\n")


if __name__ == "__main__":
    main()
