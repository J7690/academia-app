#!/usr/bin/env python3
"""Indexer les 147 questions existantes comme chunks RAG avec embeddings."""
from __future__ import annotations
import os, requests, time
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
        headers=m.headers, json={"ddl_query": sql}, timeout=60)
    return r.status_code == 200

def embed_text(text: str) -> list | None:
    if not OPENROUTER_API_KEY: return None
    try:
        r = requests.post("https://openrouter.ai/api/v1/embeddings",
            headers={"Authorization": f"Bearer {OPENROUTER_API_KEY}", "Content-Type": "application/json"},
            json={"model": EMBEDDING_MODEL, "input": text.strip()[:2000]}, timeout=30)
        if r.status_code != 200: return None
        return r.json().get("data", [{}])[0].get("embedding")
    except: return None

def main():
    m = SupabaseAutoManager()
    print("\n📚 INDEXATION RAG — Chunks Prépa Concours\n")

    # Récupérer les sujets créés (colonne = title)
    subjects = q(m,
        "SELECT id, title FROM app.prep_subjects WHERE is_active=TRUE ORDER BY title")
    print(f"  {len(subjects)} sujets trouvés\n")

    subject_map = {}  # title → id
    for s in subjects:
        subject_map[s.get("title", "")] = s.get("id")
        print(f"  📘 {s.get('title','?'):30s} → {str(s.get('id',''))[:8]}")

    # Récupérer toutes les questions groupées par subject
    all_q = q(m,
        "SELECT pq.id, pq.question, pq.content, pq.difficulty, pq.concours_type, "
        "pq.subject, ps.title AS subject_title, pq.subject_id "
        "FROM app.prep_questions pq "
        "LEFT JOIN app.prep_subjects ps ON ps.id = pq.subject_id "
        "WHERE pq.is_published=TRUE "
        "ORDER BY pq.subject, pq.difficulty")

    print(f"\n  {len(all_q)} questions à indexer\n")

    # Grouper par subject_title
    groups: dict[str, list] = {}
    for row in all_q:
        key = row.get("subject_title") or row.get("subject") or "Divers"
        groups.setdefault(key, []).append(row)

    # Vider les anciens chunks
    existing = q(m, "SELECT COUNT(*) AS n FROM app.prep_chunks")
    n_existing = existing[0].get("n", 0) if existing else 0
    if n_existing > 0:
        ddl(m, "DELETE FROM app.prep_chunks WHERE source='existing_questions'")
        print(f"  🗑️  {n_existing} anciens chunks supprimés\n")

    # Créer les chunks (lots de 5 questions par chunk)
    total_chunks = 0
    total_with_emb = 0
    batch_size = 5

    for subject_name, questions in groups.items():
        sid = subject_map.get(subject_name)

        for i in range(0, len(questions), batch_size):
            batch = questions[i:i+batch_size]

            lines = [f"Matière: {subject_name}"]
            concours = batch[0].get("concours_type") or "TOUS"
            for qn in batch:
                diff = qn.get("difficulty", "?")
                qt = qn.get("question", "")
                lines.append(f"\n[Difficulté {diff}] {qt}")

            chunk_content = "\n".join(lines)
            if len(chunk_content) < 20: continue

            escaped = chunk_content.replace("'", "''")
            escaped_concours = concours.replace("'", "''") if concours else "TOUS"

            # Embedding
            vec = embed_text(chunk_content)
            if vec:
                vec_str = "[" + ",".join(str(round(v, 8)) for v in vec) + "]"
                sid_clause = f"'{sid}'" if sid else "NULL"
                ok = ddl(m,
                    f"INSERT INTO app.prep_chunks (subject_id, content, concours_type, source, embedding) "
                    f"VALUES ({sid_clause}, '{escaped}', '{escaped_concours}', "
                    f"'existing_questions', '{vec_str}'::vector)")
                if ok:
                    total_chunks += 1
                    total_with_emb += 1
                    print(f"  ✅ [{subject_name[:20]}] chunk {i//batch_size+1} ({len(batch)}q) + embedding")
                else:
                    print(f"  ❌ [{subject_name[:20]}] chunk {i//batch_size+1} — DDL failed")
            else:
                sid_clause = f"'{sid}'" if sid else "NULL"
                ok = ddl(m,
                    f"INSERT INTO app.prep_chunks (subject_id, content, concours_type, source) "
                    f"VALUES ({sid_clause}, '{escaped}', '{escaped_concours}', 'existing_questions')")
                if ok:
                    total_chunks += 1
                    print(f"  ⚠️  [{subject_name[:20]}] chunk {i//batch_size+1} ({len(batch)}q) sans embedding")

            time.sleep(0.3)

    print(f"\n  RÉSULTAT: {total_chunks} chunks créés, {total_with_emb} avec embedding")

    # Vérification
    final = q(m, "SELECT COUNT(*) AS n FROM app.prep_chunks")
    final_emb = q(m, "SELECT COUNT(*) AS n FROM app.prep_chunks WHERE embedding IS NOT NULL")
    print(f"  En base: {final[0].get('n','?') if final else '?'} chunks, "
          f"{final_emb[0].get('n','?') if final_emb else '?'} avec embedding")

    print("\n✅ Indexation terminée.\n")

if __name__ == "__main__":
    main()
