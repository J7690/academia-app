#!/usr/bin/env python3
"""Compute embeddings for app.bobodo_knowledge (Bobodo RAG vectoriel).

Ce script respecte les procédures .windsurf :
- lecture via auto_supabase_import.read sur app.bobodo_knowledge ;
- mise à jour via la RPC admin_execute_sql (service_role) exposée par Supabase.

Objectif : remplir la colonne embedding (vector) pour chaque fiche active
utilisée par Bobodo, afin de permettre une recherche vectorielle robuste.

IMPORTANT :
- Il faut d’abord avoir appliqué le script SQL
  .windsurf/sql_changes/20260116_bobodo_vector_rag.sql
- Il faut configurer un fournisseur d’embeddings (OpenAI, ou autre) via
  une variable d’environnement (par exemple OPENAI_API_KEY) ou adapter
  la fonction _embed_text ci-dessous.
"""

from __future__ import annotations

import os
import json
from pathlib import Path
from typing import Any, Dict, List

import requests

import auto_supabase_import as sup
import seed_bobodo_knowledge as seed  # pour call_admin_execute_sql


# === Configuration Embeddings (OpenRouter) ===

# Clé API OpenRouter (la même que celle utilisée par bobodo-chat côté Edge Function,
# mais ici lue depuis l’environnement local ou le fichier .env du backend).
# On accepte à la fois les noms "OPENROUTER_API_KEY" (convention générique)
# et "CLE_API_OPENROUTER" (nom utilisé dans les secrets Supabase).
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY") or os.getenv("CLE_API_OPENROUTER")

# Modèle d’embedding sur OpenRouter. Par défaut, on utilise
# "openai/text-embedding-3-small" qui offre un bon rapport qualité/coût.
# On accepte aussi le nom "OPENROUTER_MODEL" utilisé côté Supabase.
OPENROUTER_EMBEDDING_MODEL = (
    os.getenv("OPENROUTER_EMBEDDING_MODEL")
    or os.getenv("OPENROUTER_MODEL")
    or "openai/text-embedding-3-small"
)


def _load_from_dotenv_if_needed() -> None:
    """Complète OPENROUTER_API_KEY / OPENROUTER_EMBEDDING_MODEL à partir de
    academia_bobodo_backend/.env si elles ne sont pas définies dans l’environnement.

    Aucune valeur sensible n’est affichée, on les lit simplement côté script.
    """

    global OPENROUTER_API_KEY, OPENROUTER_EMBEDDING_MODEL

    if OPENROUTER_API_KEY and OPENROUTER_EMBEDDING_MODEL:
        return

    # Remonter au dossier racine du projet puis aller dans academia_bobodo_backend/.env
    root = Path(__file__).resolve().parents[1]
    env_path = root / "academia_bobodo_backend" / ".env"
    if not env_path.exists():
        return

    try:
        content = env_path.read_text(encoding="utf-8")
    except Exception:
        return

    for line in content.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")

        # Priorité à une éventuelle variable d’environnement déjà définie.
        if key in {"OPENROUTER_API_KEY", "CLE_API_OPENROUTER"} and not OPENROUTER_API_KEY:
            OPENROUTER_API_KEY = value
        elif key in {"OPENROUTER_EMBEDDING_MODEL", "OPENROUTER_MODEL"} and not os.getenv("OPENROUTER_EMBEDDING_MODEL"):
            # Ne pas écraser une valeur d’environnement explicite.
            OPENROUTER_EMBEDDING_MODEL = value or OPENROUTER_EMBEDDING_MODEL


# Charger éventuellement les valeurs manquantes depuis .env
_load_from_dotenv_if_needed()


def _embed_text(text: str) -> List[float]:
    """Retourne un embedding pour le texte donné via OpenRouter.

    - Nécessite OPENROUTER_API_KEY dans l’environnement.
    - Utilise le endpoint /api/v1/embeddings d’OpenRouter.
    """

    if not OPENROUTER_API_KEY:
        raise RuntimeError("OPENROUTER_API_KEY manquante pour le calcul des embeddings.")

    text = (text or "").strip()
    if not text:
        return []

    url = "https://openrouter.ai/api/v1/embeddings"
    headers = {
        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
        "Content-Type": "application/json",
        # En option, on peut ajouter HTTP-Referer et X-Title pour OpenRouter
    }
    payload = {
        "model": OPENROUTER_EMBEDDING_MODEL,
        "input": text,
    }

    resp = requests.post(url, headers=headers, json=payload, timeout=30)

    # Diagnostic amélioré en cas d’erreur HTTP
    if resp.status_code != 200:
        short_body = resp.text[:400]
        raise RuntimeError(
            f"OpenRouter embeddings HTTP {resp.status_code} pour le modèle '{OPENROUTER_EMBEDDING_MODEL}': {short_body}"
        )

    data = resp.json()

    if not isinstance(data, dict) or "data" not in data:
        raise RuntimeError(f"Réponse embeddings inattendue (OpenRouter): {data!r}")

    arr = data["data"]
    if not isinstance(arr, list) or not arr:
        raise RuntimeError(f"Aucun embedding retourné (OpenRouter): {data!r}")

    first = arr[0]
    vec = first.get("embedding")
    if not isinstance(vec, list):
        raise RuntimeError(f"Embedding manquant ou invalide (OpenRouter): {first!r}")

    # On suppose une liste de floats.
    return [float(x) for x in vec]


def _update_embedding(row_id: str, embedding: List[float]) -> bool:
    """Met à jour la colonne embedding pour une fiche app.bobodo_knowledge.

    Utilise admin_execute_sql via seed.call_admin_execute_sql, en construisant
    une requête SQL sécurisée.
    """

    # Construire la représentation texte du vecteur pour pgvector: '[0.1,0.2,...]'
    inner = ",".join(f"{x:.8f}" for x in embedding)
    vec_text = f"[{inner}]"

    # On caste depuis TEXT dans la fonction app_search_bobodo_knowledge_vector,
    # mais ici on peut directement utiliser la syntaxe vector.
    sql = f"""
UPDATE app.bobodo_knowledge
SET embedding = '{vec_text}'::vector
WHERE id = '{row_id}';
""".strip()

    return seed.call_admin_execute_sql(sql)


def main() -> int:
    # 1) Lire les connaissances existantes via admin_execute_sql
    # REST direct sur app.bobodo_knowledge renvoie 404 (schéma app), on passe donc par
    # la fonction admin_execute_sql qui retourne les rows sous forme JSONB.

    url = f"{sup.SUPABASE_URL}/rest/v1/rpc/admin_execute_sql"  # type: ignore[attr-defined]
    headers: Dict[str, Any] = {
        "apikey": sup.SUPABASE_SERVICE_KEY,  # type: ignore[attr-defined]
        "Authorization": f"Bearer {sup.SUPABASE_SERVICE_KEY}",  # type: ignore[attr-defined]
        "Content-Type": "application/json",
        "Accept": "application/json",
    }

    # IMPORTANT: pas de point-virgule final, sinon admin_execute_sql(v5) provoque
    # un "syntax error at or near ';'" pour les SELECT.
    select_sql = """
    SELECT id, title, content, embedding
    FROM app.bobodo_knowledge
    ORDER BY created_at
    """.strip()

    try:
        resp = requests.post(url, headers=headers, json={"p_sql": select_sql}, timeout=30)
    except Exception as exc:  # pragma: no cover
        print("[ERROR] Exception admin_execute_sql (SELECT):", exc)
        return 1

    if resp.status_code != 200:
        print("[ERROR] HTTP", resp.status_code, "admin_execute_sql (SELECT)")
        print(resp.text[:400])
        return 1

    try:
        payload: Any = resp.json()
    except Exception as exc:
        print("[ERROR] Réponse JSON invalide pour admin_execute_sql:", exc)
        print(resp.text[:400])
        return 1

    if not isinstance(payload, dict) or not payload.get("ok"):
        print("[ERROR] admin_execute_sql a renvoyé une erreur logique:", str(payload)[:400])
        return 1

    rows = payload.get("rows") or []
    if not isinstance(rows, list):
        print("[ERROR] Format inattendu pour rows dans admin_execute_sql:", type(rows))
        return 1

    print(f"[INFO] {len(rows)} lignes trouvées dans app.bobodo_knowledge")

    updated = 0
    skipped = 0
    failed = 0

    for row in rows:
        if not isinstance(row, dict):
            continue
        row_id = str(row.get("id") or "").strip()
        if not row_id:
            continue

        # Si une embedding existe déjà, on la laisse telle quelle.
        if row.get("embedding") is not None:
            skipped += 1
            continue

        title = str(row.get("title") or "").strip()
        content = str(row.get("content") or "").strip()
        text = (title + "\n\n" + content).strip()
        if not text:
            skipped += 1
            continue

        print(f"[INFO] Embedding pour id={row_id} title={title[:50]!r}...")
        try:
            vec = _embed_text(text)
            if not vec:
                print("[WARN] Embedding vide, ligne ignorée:", row_id)
                skipped += 1
                continue
        except Exception as exc:
            print(f"[ERROR] Échec embedding pour {row_id}: {exc}")
            failed += 1
            continue

        ok = _update_embedding(row_id, vec)
        if not ok:
            print("[ERROR] Échec update embedding via admin_execute_sql pour", row_id)
            failed += 1
            continue

        updated += 1

    print(f"[SUMMARY] embeddings mis à jour: {updated}, ignorés: {skipped}, erreurs: {failed}")

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
