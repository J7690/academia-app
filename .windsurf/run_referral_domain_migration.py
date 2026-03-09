#!/usr/bin/env python3
"""Applique la migration de domaine pour les liens commerciaux dans app.commercial_profiles.

- Aligne les ref_link sur https://amazing-boba-9a75a7.netlify.app
- Utilise SupabaseAutoManager et la RPC execute_sql côté Supabase.
"""

import json
from supabase_auto_manager import SupabaseAutoManager


def main() -> None:
    manager = SupabaseAutoManager()

    # 1) Créer (ou mettre à jour) une fonction côté Supabase qui effectue le UPDATE
    create_fn_sql = """
    CREATE OR REPLACE FUNCTION app_referral_force_update_links()
    RETURNS JSONB
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $$
    DECLARE
      v_updated_count INTEGER := 0;
    BEGIN
      UPDATE app.commercial_profiles
      SET ref_link = 'https://amazing-boba-9a75a7.netlify.app/?ref=' || ref_code
      WHERE ref_code IS NOT NULL
        AND TRIM(ref_code) <> ''
        AND ref_link LIKE 'https://dulcet-snickerdoodle-915a6b.netlify.app/%';

      GET DIAGNOSTICS v_updated_count = ROW_COUNT;

      RETURN JSONB_BUILD_OBJECT(
        'updated_count', v_updated_count
      );
    END;
    $$;
    """

    print("Creating helper function app_referral_force_update_links() via execute_sql...")
    create_result = manager.execute_sql_auto(create_fn_sql)
    print(json.dumps(create_result, indent=2, default=str))

    # 2) Appeler la fonction via un SELECT simple (qui sera enveloppé par execute_sql côté serveur)
    call_fn_sql = """
    SELECT app_referral_force_update_links() AS payload;
    """

    print("Calling app_referral_force_update_links() to update existing ref_link values...")
    call_result = manager.execute_sql_auto(call_fn_sql)
    print(json.dumps(call_result, indent=2, default=str))


if __name__ == "__main__":
    main()
