#!/usr/bin/env python3
"""
Fix doublons + embeddings manquants dans bobodo_knowledge.
1. Identifier les doublons (même titre) → garder celui avec embedding, supprimer l'autre
2. Régénérer les embeddings manquants via OpenRouter
3. Vérifier l'état final
"""
from __future__ import annotations
import json, os, requests, time
from pathlib import Path
from dotenv import load_dotenv
from supabase_auto_manager import SupabaseAutoManager

load_dotenv(Path(__file__).parent / ".env", override=True)
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY", "")
EMBEDDING_MODEL = os.getenv("OPENROUTER_EMBEDDING_MODEL", "openai/text-embedding-3-small")


def q(m, sql):
    r = requests.post(f"{m.url}/rest/v1/rpc/execute_sql",
        headers=m.headers, json={"sql_query": sql}, timeout=30)
    data = r.json()
    return data if isinstance(data, list) else []


def ddl(m, sql):
    r = requests.post(f"{m.url}/rest/v1/rpc/execute_ddl",
        headers=m.headers, json={"ddl_query": sql}, timeout=30)
    return r.status_code == 200


def section(t):
    print(f"\n{'='*60}\n  {t}\n{'='*60}")


def embed_text(text: str) -> str | None:
    """Appel OpenRouter embeddings → retourne le vecteur en string '[0.1,0.2,...]'."""
    if not OPENROUTER_API_KEY:
        print("  ⚠️  OPENROUTER_API_KEY absente — impossible de générer les embeddings")
        return None
    try:
        r = requests.post("https://openrouter.ai/api/v1/embeddings",
            headers={
                "Authorization": f"Bearer {OPENROUTER_API_KEY}",
                "Content-Type": "application/json",
            },
            json={"model": EMBEDDING_MODEL, "input": text.strip()[:2000]},
            timeout=30)
        if r.status_code != 200:
            print(f"  ❌ Embedding API error {r.status_code}: {r.text[:200]}")
            return None
        data = r.json()
        arr = data.get("data", [])
        if not arr: return None
        vec = arr[0].get("embedding")
        if not vec or not isinstance(vec, list): return None
        inner = ",".join(str(round(v, 8)) for v in vec)
        return f"[{inner}]"
    except Exception as e:
        print(f"  ❌ Embedding exception: {e}")
        return None


def main():
    m = SupabaseAutoManager()
    print("\n🔧 FIX DOUBLONS + EMBEDDINGS KNOWLEDGE BASE BOBODO")

    # ── 1. Identifier les doublons ──────────────────────────────────
    section("1. IDENTIFICATION DES DOUBLONS")
    all_rows = q(m,
        "SELECT id, title, category, "
        "CASE WHEN embedding IS NOT NULL THEN 'oui' ELSE 'non' END AS has_emb, "
        "LENGTH(content) AS content_len "
        "FROM app.bobodo_knowledge WHERE is_active=TRUE "
        "ORDER BY title, has_emb DESC")

    # Grouper par titre
    groups: dict[str, list] = {}
    for r in all_rows:
        t = r.get("title", "")
        groups.setdefault(t, []).append(r)

    duplicates_to_delete = []
    for title, rows in groups.items():
        if len(rows) > 1:
            # Garder celui avec embedding (premier car trié has_emb DESC)
            keep = rows[0]
            for dup in rows[1:]:
                duplicates_to_delete.append(dup)
                print(f"  🗑️  Doublon [{dup['category']}] {title[:45]} → supprimer {dup['id']}")
            print(f"  ✅ Garder [{keep['category']}] {title[:45]} (emb={keep['has_emb']}) → {keep['id']}")

    if not duplicates_to_delete:
        print("  ✅ Aucun doublon trouvé")
    else:
        print(f"\n  Total à supprimer : {len(duplicates_to_delete)} doublons")

    # ── 2. Supprimer les doublons ───────────────────────────────────
    if duplicates_to_delete:
        section("2. SUPPRESSION DES DOUBLONS")
        ids_str = ",".join(f"'{d['id']}'" for d in duplicates_to_delete)
        ok = ddl(m, f"DELETE FROM app.bobodo_knowledge WHERE id IN ({ids_str})")
        if ok:
            print(f"  ✅ {len(duplicates_to_delete)} doublons supprimés")
        else:
            # Fallback: désactiver au lieu de supprimer
            ok2 = ddl(m, f"UPDATE app.bobodo_knowledge SET is_active=FALSE WHERE id IN ({ids_str})")
            if ok2:
                print(f"  ✅ {len(duplicates_to_delete)} doublons désactivés (is_active=FALSE)")
            else:
                print(f"  ❌ Impossible de supprimer/désactiver les doublons")

    # ── 3. Régénérer les embeddings manquants ───────────────────────
    section("3. EMBEDDINGS MANQUANTS")
    missing = q(m,
        "SELECT id, title, content, category "
        "FROM app.bobodo_knowledge "
        "WHERE is_active=TRUE AND embedding IS NULL "
        "ORDER BY category, title")

    if not missing:
        print("  ✅ Toutes les fiches ont un embedding")
    else:
        print(f"  {len(missing)} fiche(s) sans embedding à traiter\n")

        for row in missing:
            rid = row["id"]
            title = row.get("title", "?")
            content = row.get("content", "")
            text_for_embedding = f"{title}\n{content}".strip()

            if not text_for_embedding:
                print(f"  ⚠️  Fiche {rid} vide — skip")
                continue

            print(f"  🔄 [{row.get('category','')}] {title[:50]}...", end=" ")
            vec = embed_text(text_for_embedding)
            if not vec:
                print("❌ échec")
                continue

            # Mettre à jour via DDL
            # Échapper les apostrophes
            vec_escaped = vec.replace("'", "''")
            ok = ddl(m,
                f"UPDATE app.bobodo_knowledge SET embedding = '{vec_escaped}'::vector "
                f"WHERE id = '{rid}'")
            if ok:
                print("✅")
            else:
                print("❌ DDL update failed")

            time.sleep(0.3)  # rate limiting

    # ── 4. Vérification finale ──────────────────────────────────────
    section("4. ÉTAT FINAL")
    final = q(m,
        "SELECT category, COUNT(*) AS total, "
        "COUNT(CASE WHEN embedding IS NOT NULL THEN 1 END) AS with_emb "
        "FROM app.bobodo_knowledge WHERE is_active=TRUE "
        "GROUP BY category ORDER BY category")
    total_all = 0
    total_emb = 0
    for r in final:
        t = r.get("total", 0)
        e = r.get("with_emb", 0)
        total_all += t
        total_emb += e
        status = "✅" if t == e else "⚠️"
        print(f"  {status} {r.get('category','?'):20s}  {t} fiches  {e} embeddings")
    print(f"\n  TOTAL: {total_all} fiches, {total_emb} embeddings ({total_emb*100//max(total_all,1)}%)")

    if total_all == total_emb:
        print("  ✅ 100% des fiches ont un embedding — RAG pleinement opérationnel")
    else:
        print(f"  ⚠️  {total_all - total_emb} fiches sans embedding restantes")

    print("\n✅ Fix terminé.\n")


if __name__ == "__main__":
    main()
