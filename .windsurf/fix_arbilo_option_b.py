#!/usr/bin/env python3
"""Correction du modèle Arbilo pour l'option B (id université = id du compte université).

- Désactive l'ancienne université Arbilo (id hérité 6745...) et ses programmes.
- Crée/met à jour l'université Arbilo avec id = user_id(hilbertwedraogo@gmail.com)
  en réutilisant seed_university_and_programs.
- Aligne les métadonnées du compte université (role/university_id).

Respecte les procédures .windsurf en réutilisant auto_supabase_import
et les helpers existants de seed_and_link_university_arbilo.
"""

from __future__ import annotations

from typing import Any, Dict, Optional

from auto_supabase_import import SUPABASE_URL, SUPABASE_SERVICE_KEY
from seed_and_link_university_arbilo import (
    find_user_by_email,
    update_user_metadata,
    call_admin_execute_sql,
    seed_university_and_programs,
)


TARGET_EMAIL = "hilbertwedraogo@gmail.com"
# Ancien id utilisé pour Arbilo (hérité de l'id étudiant nexiomgroup)
LEGACY_UNI_ID = "6745c7ad-732b-47d0-b5b8-06d6dcf286ff"


def main() -> int:
    print(f"[INFO] Correction Arbilo option B pour le compte université: {TARGET_EMAIL}")
    user = find_user_by_email(TARGET_EMAIL)
    if not user:
        print("[ERROR] Impossible de trouver le compte université.")
        return 1

    user_id = user.get("id")
    if not user_id:
        print("[ERROR] Utilisateur sans id, impossible de continuer.")
        return 1

    # 1) Renommer / désactiver l'ancienne université Arbilo (legacy)
    sql_legacy_uni = f"""
    UPDATE app.universities
    SET slug = 'universite-arbilo-legacy',
        is_active = FALSE
    WHERE id = '{LEGACY_UNI_ID}'::uuid;
    """.strip()

    if not call_admin_execute_sql(sql_legacy_uni):
        print("[ERROR] Impossible de désactiver l'ancienne université Arbilo.")
        return 1

    sql_legacy_programs = f"""
    UPDATE app.programs
    SET is_active = FALSE
    WHERE university_id = '{LEGACY_UNI_ID}'::uuid;
    """.strip()

    if not call_admin_execute_sql(sql_legacy_programs):
        print("[ERROR] Impossible de désactiver les anciens programmes Arbilo.")
        return 1

    # 2) Créer / mettre à jour l'université Arbilo + programmes
    #    avec id = user_id (option B)
    print(f"[INFO] Application du modèle option B (université id = {user_id})")
    if not seed_university_and_programs(user_id):
        print("[ERROR] seed_university_and_programs a échoué.")
        return 1

    # 3) Mettre à jour les métadonnées du compte université
    meta = user.get("user_metadata") or user.get("user_meta_data") or {}
    if not isinstance(meta, dict):
        meta = {}

    meta["role"] = "university"
    meta["university_id"] = user_id

    print(
        f"[INFO] Mise à jour des métadonnées du user {user_id} "
        f"(role=university, university_id={user_id})"
    )
    if not update_user_metadata(user_id, meta):
        print("[WARN] Échec via l'API admin, tentative via admin_execute_sql.")
        sql_meta = f"""
        UPDATE auth.users
        SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{{}}'::jsonb)
                                || '{{"role":"university","university_id":"{user_id}"}}'::jsonb
        WHERE email = '{TARGET_EMAIL}';
        """.strip()
        if not call_admin_execute_sql(sql_meta):
            print(
                "[ERROR] Impossible de mettre à jour raw_user_meta_data via admin_execute_sql."
            )
            return 1

    print("[SUCCESS] Modèle Arbilo option B appliqué avec succès.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
