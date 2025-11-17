#!/usr/bin/env python3
"""Crée l'université réelle "Université d'Arbilo" + programmes
et la lie au compte Supabase université existant.

Contraintes :
- L'ID de l'université = l'ID du compte Supabase (auth.users.id)
  pour l'email TARGET_EMAIL.
- Les programmes sont créés s'ils n'existent pas déjà.
- user_metadata est mis à jour avec role="university" et
  university_id = user_id.

Techniquement :
- Utilise l'API admin Supabase pour récupérer/màj l'utilisateur.
- Utilise la RPC admin_execute_sql pour insérer dans app.universities
  et app.programs (accès direct au schéma app, sans PostgREST direct).
"""

from __future__ import annotations

from typing import Any, Dict, Optional

import requests

from auto_supabase_import import SUPABASE_URL, SUPABASE_SERVICE_KEY

TARGET_EMAIL = "hilbertwedraogo@gmail.com"

ADMIN_HEADERS = {
    "apikey": SUPABASE_SERVICE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
    "Content-Type": "application/json",
}


# ---------- Helpers Auth Admin ----------

def find_user_by_email(email: str) -> Optional[Dict[str, Any]]:
    """Retourne le user Supabase (admin API) correspondant à l'email."""
    url = f"{SUPABASE_URL}/auth/v1/admin/users"
    try:
        resp = requests.get(url, headers=ADMIN_HEADERS, params={"email": email}, timeout=15)
    except Exception as exc:
        print(f"[ERROR] Erreur réseau lors de la recherche utilisateur: {exc}")
        return None

    if resp.status_code != 200:
        print(f"[ERROR] HTTP {resp.status_code} lors de la recherche utilisateur: {resp.text[:400]}")
        return None

    data = resp.json()

    # Certains environnements renvoient une liste brute d'utilisateurs
    if isinstance(data, list):
        if not data:
            print("[ERROR] Aucun utilisateur trouvé pour cet email.")
            return None

        # On cherche d'abord une correspondance exacte sur l'email
        for user in data:
            if isinstance(user, dict) and user.get("email") == email:
                return user

        # Fallback: on garde le comportement historique (premier élément)
        if len(data) > 1:
            print("[WARN] Plusieurs utilisateurs trouvés, aucune correspondance exacte sur l'email, utilisation du premier.")
        return data[0]

    # D'autres environnements renvoient un objet avec une clé "users"
    if isinstance(data, dict):
        users = data.get("users")
        if isinstance(users, list):
            if not users:
                print("[ERROR] Aucun utilisateur trouvé pour cet email (liste vide).")
                return None

            for user in users:
                if isinstance(user, dict) and user.get("email") == email:
                    return user

            if len(users) > 1:
                print("[WARN] Plusieurs utilisateurs trouvés (clé 'users'), aucune correspondance exacte sur l'email, utilisation du premier.")
            return users[0]

    return data or None


def update_user_metadata(user_id: str, new_metadata: Dict[str, Any]) -> bool:
    """Met à jour user_metadata pour l'utilisateur donné via l'API admin."""
    url = f"{SUPABASE_URL}/auth/v1/admin/users/{user_id}"
    payload = {"user_metadata": new_metadata}
    try:
        resp = requests.patch(url, headers=ADMIN_HEADERS, json=payload, timeout=15)
    except Exception as exc:
        print(f"[ERROR] Erreur réseau lors de la mise à jour metadata: {exc}")
        return False

    if resp.status_code not in (200, 201):
        print(f"[ERROR] HTTP {resp.status_code} lors de la mise à jour metadata: {resp.text[:400]}")
        return False

    print("[OK] Métadonnées utilisateur mises à jour.")
    return True


# ---------- Helpers admin_execute_sql ----------

def call_admin_execute_sql(sql: str) -> bool:
    """Appelle la RPC admin_execute_sql avec une requête SQL arbitraire."""
    url = f"{SUPABASE_URL}/rest/v1/rpc/admin_execute_sql"
    try:
        resp = requests.post(url, headers=ADMIN_HEADERS, json={"p_sql": sql}, timeout=30)
    except Exception as exc:
        print(f"[ERROR] Erreur réseau admin_execute_sql: {exc}")
        return False

    if resp.status_code != 200:
        print(f"[ERROR] HTTP {resp.status_code} admin_execute_sql: {resp.text[:400]}")
        return False

    # Réponse JSON optionnelle, on logge juste les erreurs éventuelles
    try:
        data = resp.json()
    except Exception:
        return True

    if isinstance(data, dict) and not data.get("ok", True):
        print("[WARN] admin_execute_sql a renvoyé une erreur logique:")
        print(str(data)[:400])
        return False

    return True


def seed_university_and_programs(user_id: str) -> bool:
    """Crée/MAJ l'université Arbilo + programmes avec id = user_id."""

    uid_literal = f"'{user_id}'::uuid"

    # 1) Université d'Arbilo (id = user_id)
    sql_university = f"""
    INSERT INTO app.universities (id, name, slug, country, city, website_url, description, is_active)
    VALUES ({uid_literal}, 'Université d''Arbilo', 'universite-arbilo', 'Burkina Faso', 'Ouagadougou',
            'https://universite-arbilo.example',
            'Université partenaire réelle utilisée pour les tests de la plateforme Academia.',
            TRUE)
    ON CONFLICT (id) DO UPDATE
      SET name = EXCLUDED.name,
          slug = EXCLUDED.slug,
          country = EXCLUDED.country,
          city = EXCLUDED.city,
          website_url = EXCLUDED.website_url,
          description = EXCLUDED.description,
          is_active = EXCLUDED.is_active;
    """.strip()

    if not call_admin_execute_sql(sql_university):
        print("[ERROR] Impossible de créer/mettre à jour l'université d'Arbilo.")
        return False

    # 2) Programmes - insertion conditionnelle par titre
    inserts = [
        f"""
        INSERT INTO app.programs (
            university_id, title, description, degree_level, mode,
            duration_months, tuition_fees, highlighted, is_active
        )
        SELECT {uid_literal},
               'Licence Informatique et Systèmes d''Information',
               'Formation de 3 ans en développement logiciel, bases de données et réseaux.',
               'Licence',
               'présentiel',
               36,
               2200,
               TRUE,
               TRUE
        WHERE NOT EXISTS (
            SELECT 1 FROM app.programs p
            WHERE p.university_id = {uid_literal}
              AND p.title = 'Licence Informatique et Systèmes d''Information'
        );
        """.strip(),
        f"""
        INSERT INTO app.programs (
            university_id, title, description, degree_level, mode,
            duration_months, tuition_fees, highlighted, is_active
        )
        SELECT {uid_literal},
               'Licence Sciences Économiques et Gestion',
               'Parcours en économie, finance d''entreprise et management.',
               'Licence',
               'hybride',
               36,
               2100,
               FALSE,
               TRUE
        WHERE NOT EXISTS (
            SELECT 1 FROM app.programs p
            WHERE p.university_id = {uid_literal}
              AND p.title = 'Licence Sciences Économiques et Gestion'
        );
        """.strip(),
        f"""
        INSERT INTO app.programs (
            university_id, title, description, degree_level, mode,
            duration_months, tuition_fees, highlighted, is_active
        )
        SELECT {uid_literal},
               'Master Intelligence Artificielle et Data Science',
               'Programme de 2 ans orienté IA, machine learning et analyse de données.',
               'Master',
               'présentiel',
               24,
               4800,
               TRUE,
               TRUE
        WHERE NOT EXISTS (
            SELECT 1 FROM app.programs p
            WHERE p.university_id = {uid_literal}
              AND p.title = 'Master Intelligence Artificielle et Data Science'
        );
        """.strip(),
    ]

    for sql in inserts:
        if not call_admin_execute_sql(sql):
            print("[ERROR] Impossible de créer/mettre à jour un programme Arbilo.")
            return False

    print("[OK] Université d'Arbilo et programmes créés/mis à jour avec id utilisateur.")
    return True


def main() -> int:
    print(f"[INFO] Recherche du compte université: {TARGET_EMAIL}")
    user = find_user_by_email(TARGET_EMAIL)
    if not user:
        return 1

    user_id = user.get("id")
    if not user_id:
        print("[ERROR] Utilisateur sans id, impossible de continuer.")
        return 1

    print(f"[INFO] Utilisation de user_id comme university.id: {user_id}")
    if not seed_university_and_programs(user_id):
        return 1

    # Mettre à jour les métadonnées utilisateur pour refléter le lien université
    meta = user.get("user_metadata") or user.get("user_meta_data") or {}
    if not isinstance(meta, dict):
        meta = {}

    meta["role"] = "university"
    meta["university_id"] = user_id

    print(f"[INFO] Mise à jour des métadonnées du user {user_id} (role=university, university_id={user_id})")
    if not update_user_metadata(user_id, meta):
        print("[WARN] Échec via l'API admin, tentative de mise à jour via admin_execute_sql.")
        sql_meta = f"""
        UPDATE auth.users
        SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{{}}'::jsonb)
                                || '{{"role":"university","university_id":"{user_id}"}}'::jsonb
        WHERE email = '{TARGET_EMAIL}';
        """.strip()
        if not call_admin_execute_sql(sql_meta):
            print("[ERROR] Impossible de mettre à jour raw_user_meta_data via admin_execute_sql.")
            return 1

    print("[SUCCESS] Université d'Arbilo créée/mise à jour et liée au compte université existant.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
