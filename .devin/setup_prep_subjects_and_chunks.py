#!/usr/bin/env python3
"""
Setup Prépa Concours: créer les sujets, lier les questions, indexer en chunks RAG.
Utilise execute_ddl pour les DDL et execute_sql pour les SELECT.
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
        headers=m.headers, json={"ddl_query": sql}, timeout=60)
    return r.status_code == 200

def section(t): print(f"\n{'='*60}\n  {t}\n{'='*60}")

def embed_text(text: str) -> list[float] | None:
    if not OPENROUTER_API_KEY: return None
    try:
        r = requests.post("https://openrouter.ai/api/v1/embeddings",
            headers={"Authorization": f"Bearer {OPENROUTER_API_KEY}", "Content-Type": "application/json"},
            json={"model": EMBEDDING_MODEL, "input": text.strip()[:2000]}, timeout=30)
        if r.status_code != 200: return None
        data = r.json()
        arr = data.get("data", [])
        if not arr: return None
        return arr[0].get("embedding")
    except: return None


def main():
    m = SupabaseAutoManager()
    print("\n🎓 SETUP PRÉPA CONCOURS — Sujets + Chunks RAG\n")

    # ── 1. Analyser les matières existantes dans les 147 questions ────
    section("1. ANALYSE DES MATIÈRES EXISTANTES")
    subjects_in_questions = q(m,
        "SELECT DISTINCT subject, concours_type, COUNT(*) AS n "
        "FROM app.prep_questions "
        "WHERE is_published=TRUE "
        "GROUP BY subject, concours_type "
        "ORDER BY n DESC")
    
    for s in subjects_in_questions:
        print(f"  {s.get('subject','?'):30s}  {str(s.get('concours_type','?')):15s}  {s.get('n')} questions")

    # ── 2. Vérifier structure prep_subjects ───────────────────────────
    section("2. STRUCTURE prep_subjects")
    cols = q(m,
        "SELECT column_name, udt_name, is_nullable "
        "FROM information_schema.columns "
        "WHERE table_schema='app' AND table_name='prep_subjects' "
        "ORDER BY ordinal_position")
    for c in cols:
        print(f"  {c.get('column_name'):25s}  {c.get('udt_name'):15s}")

    # ── 3. Créer les sujets à partir des matières existantes ─────────
    section("3. CRÉATION DES SUJETS")
    
    # Mapping matières → sujets avec slug
    subject_mapping = {}
    for s in subjects_in_questions:
        subj_name = s.get("subject", "")
        if not subj_name: continue
        slug = subj_name.lower().replace(" ", "_").replace("é", "e").replace("è", "e").replace("ê", "e")
        slug = slug.replace("à", "a").replace("ô", "o").replace("î", "i").replace("û", "u")
        slug = slug[:50]
        concours = s.get("concours_type") or "fonction_publique"
        subject_mapping[subj_name] = {"slug": slug, "concours": concours}

    created_subjects = {}
    for name, info in subject_mapping.items():
        escaped_name = name.replace("'", "''")
        escaped_slug = info["slug"].replace("'", "''")
        escaped_concours = info["concours"].replace("'", "''")
        
        # Vérifier si existe déjà
        existing = q(m, f"SELECT id FROM app.prep_subjects WHERE name='{escaped_name}'")
        if existing:
            sid = existing[0].get("id")
            print(f"  ✅ Existe déjà: {name} → {str(sid)[:8]}")
            created_subjects[name] = sid
            continue

        ok = ddl(m,
            f"INSERT INTO app.prep_subjects (name, slug, concours_type, is_active) "
            f"VALUES ('{escaped_name}', '{escaped_slug}', '{escaped_concours}', TRUE)")
        if ok:
            new = q(m, f"SELECT id FROM app.prep_subjects WHERE name='{escaped_name}'")
            if new:
                sid = new[0].get("id")
                created_subjects[name] = sid
                print(f"  ✅ Créé: {name} → {str(sid)[:8]}")
            else:
                print(f"  ⚠️  Inséré mais non trouvé: {name}")
        else:
            print(f"  ❌ Échec insertion: {name}")

    # ── 4. Lier les questions aux sujets ──────────────────────────────
    section("4. LIAISON QUESTIONS → SUJETS")
    linked = 0
    for name, sid in created_subjects.items():
        escaped_name = name.replace("'", "''")
        ok = ddl(m,
            f"UPDATE app.prep_questions SET subject_id='{sid}' "
            f"WHERE subject='{escaped_name}' AND (subject_id IS NULL OR subject_id!='{sid}')")
        if ok:
            count = q(m, f"SELECT COUNT(*) AS n FROM app.prep_questions WHERE subject_id='{sid}'")
            n = count[0].get("n", 0) if count else 0
            print(f"  ✅ {name}: {n} questions liées")
            linked += n
    print(f"\n  Total: {linked} questions liées à des sujets")

    # ── 5. Vérifier structure prep_chunks ─────────────────────────────
    section("5. STRUCTURE prep_chunks")
    chunk_cols = q(m,
        "SELECT column_name, udt_name "
        "FROM information_schema.columns "
        "WHERE table_schema='app' AND table_name='prep_chunks' "
        "ORDER BY ordinal_position")
    if not chunk_cols:
        print("  ❌ Table prep_chunks n'existe pas — création nécessaire")
        # Créer la table si elle n'existe pas
        ddl(m, """
            CREATE TABLE IF NOT EXISTS app.prep_chunks (
                id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                subject_id uuid REFERENCES app.prep_subjects(id),
                bank_id uuid,
                content text NOT NULL,
                concours_type text,
                year text,
                source text DEFAULT 'existing_questions',
                embedding vector(1536),
                created_at timestamptz DEFAULT now()
            )
        """)
        chunk_cols = q(m,
            "SELECT column_name, udt_name "
            "FROM information_schema.columns "
            "WHERE table_schema='app' AND table_name='prep_chunks' "
            "ORDER BY ordinal_position")
    
    for c in chunk_cols:
        print(f"  {c.get('column_name'):25s}  {c.get('udt_name')}")

    # ── 6. Indexer les questions existantes comme chunks RAG ──────────
    section("6. INDEXATION RAG — Questions → Chunks")
    
    # Regrouper les questions par sujet pour créer des chunks cohérents
    for name, sid in created_subjects.items():
        escaped_name = name.replace("'", "''")
        questions = q(m,
            f"SELECT id, question, content, difficulty, concours_type "
            f"FROM app.prep_questions "
            f"WHERE subject='{escaped_name}' AND is_published=TRUE "
            f"ORDER BY difficulty, id")
        
        if not questions:
            continue

        # Grouper par lots de 5 questions pour créer des chunks
        batch_size = 5
        for i in range(0, len(questions), batch_size):
            batch = questions[i:i+batch_size]
            
            # Construire le contenu du chunk
            chunk_lines = [f"Matière: {name}"]
            for qn in batch:
                diff = qn.get("difficulty", "?")
                qt = qn.get("question", "")
                ct = qn.get("content", "")
                chunk_lines.append(f"\n[Difficulté {diff}] {qt}")
                if ct and ct != qt:
                    chunk_lines.append(ct[:300])
            
            chunk_content = "\n".join(chunk_lines)
            if len(chunk_content) < 20:
                continue

            concours = batch[0].get("concours_type") or "fonction_publique"
            escaped_content = chunk_content.replace("'", "''")
            escaped_concours = concours.replace("'", "''") if concours else "NULL"

            # Vérifier si ce chunk existe déjà (par contenu)
            # On utilise un hash simple : les premiers 100 chars du contenu
            check_prefix = escaped_content[:100].replace("'", "''")
            existing_chunk = q(m,
                f"SELECT id FROM app.prep_chunks "
                f"WHERE content LIKE '{check_prefix}%' LIMIT 1")
            
            if existing_chunk:
                continue  # Déjà indexé

            # Générer l'embedding
            vec = embed_text(chunk_content)
            if vec:
                vec_str = "[" + ",".join(str(round(v, 8)) for v in vec) + "]"
                vec_escaped = vec_str.replace("'", "''")
                ok = ddl(m,
                    f"INSERT INTO app.prep_chunks (subject_id, content, concours_type, source, embedding) "
                    f"VALUES ('{sid}', '{escaped_content}', "
                    f"'{escaped_concours}', 'existing_questions', "
                    f"'{vec_escaped}'::vector)")
            else:
                ok = ddl(m,
                    f"INSERT INTO app.prep_chunks (subject_id, content, concours_type, source) "
                    f"VALUES ('{sid}', '{escaped_content}', "
                    f"'{escaped_concours}', 'existing_questions')")
            
            if ok:
                print(f"  ✅ Chunk [{name}] {i//batch_size + 1}: {len(batch)} questions indexées")
            else:
                print(f"  ❌ Chunk [{name}] {i//batch_size + 1}: échec insertion")

            time.sleep(0.3)  # rate limiting embeddings

    # ── 7. Vérification finale ────────────────────────────────────────
    section("7. VÉRIFICATION FINALE")
    
    subj_count = q(m, "SELECT COUNT(*) AS n FROM app.prep_subjects WHERE is_active=TRUE")
    chunk_count = q(m, "SELECT COUNT(*) AS n FROM app.prep_chunks")
    chunk_emb = q(m, "SELECT COUNT(*) AS n FROM app.prep_chunks WHERE embedding IS NOT NULL")
    q_linked = q(m, "SELECT COUNT(*) AS n FROM app.prep_questions WHERE subject_id IS NOT NULL")

    print(f"  Sujets actifs           : {subj_count[0].get('n','?') if subj_count else '?'}")
    print(f"  Questions liées         : {q_linked[0].get('n','?') if q_linked else '?'}")
    print(f"  Chunks RAG              : {chunk_count[0].get('n','?') if chunk_count else '?'}")
    print(f"  Chunks avec embedding   : {chunk_emb[0].get('n','?') if chunk_emb else '?'}")

    # Vérifier Edge Function
    try:
        r = requests.post(f"{m.url}/functions/v1/prep-generate-questions",
            json={}, timeout=10)
        ef_ok = r.status_code == 401  # 401 = existe mais pas de JWT
        print(f"  Edge Function deployed  : {'✅' if ef_ok else '❌'}")
    except:
        print(f"  Edge Function deployed  : ❌")

    print("\n✅ Setup terminé.\n")


if __name__ == "__main__":
    main()
