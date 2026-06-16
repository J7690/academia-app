#!/usr/bin/env python3
"""
Configure le Send SMS Hook Supabase Auth automatiquement.
1. Crée la fonction PostgreSQL send_sms_hook (via pg_net -> Edge Function)
2. Tente d'activer le hook dans auth.hooks via SQL
"""

import requests
import json

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
}
PROJECT_REF = "thevdfcwlcqzdoybfvgs"
EDGE_FUNCTION_URL = f"https://{PROJECT_REF}.supabase.co/functions/v1/send-phone-otp"


def rpc_sql(sql, label=""):
    """Exécute du SQL via execute_sql RPC."""
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/execute_sql",
        headers=HEADERS,
        json={"sql_query": sql},
        timeout=30,
    )
    ok = r.status_code == 200
    try:
        body = r.json()
    except Exception:
        body = r.text[:300]
    status = "OK" if ok else "ERR"
    print(f"  {status} [{label}]: {'' if ok else body}")
    return ok, body


def rpc_ddl(sql, label=""):
    """Exécute du DDL via execute_ddl RPC."""
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/execute_ddl",
        headers=HEADERS,
        json={"ddl_query": sql},
        timeout=30,
    )
    ok = r.status_code == 200
    try:
        body = r.json()
    except Exception:
        body = r.text[:300]
    status = "OK" if ok else "ERR"
    print(f"  {status} [{label}]: {'' if ok else body}")
    return ok, body


print("=" * 60)
print("CONFIGURE SMS HOOK - ACADEMIA")
print("=" * 60)

# ──────────────────────────────────────────────────────────────
# ETAPE 1: Vérifier pg_net est disponible
# ──────────────────────────────────────────────────────────────
print("\n[1] Vérification extension pg_net...")
ok, body = rpc_sql(
    "SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_net'",
    "check_pg_net",
)
has_pgnet = ok and isinstance(body, list) and len(body) > 0
print(f"    pg_net disponible: {has_pgnet}")
if has_pgnet:
    print(f"    version: {body[0].get('extversion', 'N/A')}")

# ──────────────────────────────────────────────────────────────
# ETAPE 2: Créer la fonction PostgreSQL send_sms_hook
# ──────────────────────────────────────────────────────────────
print("\n[2] Création fonction send_sms_hook...")

pg_net_body = f"""
CREATE OR REPLACE FUNCTION public.send_sms_hook(event jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  request_id bigint;
BEGIN
  SELECT net.http_post(
    url     := '{EDGE_FUNCTION_URL}',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer {SERVICE_ROLE_KEY}'
    ),
    body    := event
  ) INTO request_id;

  -- La requête pg_net est asynchrone ; le hook retourne immédiatement.
  -- L'OTP sera envoyé par Twilio en arrière-plan.
  RETURN;
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_sms_hook(jsonb)
  TO supabase_auth_admin;
REVOKE EXECUTE ON FUNCTION public.send_sms_hook(jsonb)
  FROM authenticated, anon, public;
"""

ok1, _ = rpc_ddl(pg_net_body, "create send_sms_hook")

# ──────────────────────────────────────────────────────────────
# ETAPE 3: Vérifier que la fonction existe
# ──────────────────────────────────────────────────────────────
print("\n[3] Vérification fonction créée...")
ok2, body2 = rpc_sql(
    """
    SELECT proname, pronamespace::regnamespace::text as schema
    FROM pg_proc
    WHERE proname = 'send_sms_hook'
      AND pronamespace::regnamespace::text = 'public'
    """,
    "verify_function",
)
if ok2 and isinstance(body2, list) and len(body2) > 0:
    print(f"    OK Fonction trouvee: {body2[0]}")
else:
    print(f"    WARN Fonction non trouvee: {body2}")

# ──────────────────────────────────────────────────────────────
# ETAPE 4: Tenter de configurer le hook via auth.hooks table
# ──────────────────────────────────────────────────────────────
print("\n[4] Tentative configuration auth.hooks via SQL...")

# Vérifier si la table auth.hooks existe
ok3, body3 = rpc_sql(
    "SELECT to_regclass('auth.hooks') IS NOT NULL as exists",
    "check_auth_hooks_table",
)
has_hooks_table = False
if ok3 and isinstance(body3, list) and len(body3) > 0:
    has_hooks_table = body3[0].get("exists", False)
print(f"    Table auth.hooks existe: {has_hooks_table}")

if has_hooks_table:
    # Tenter d'insérer/mettre à jour la config du hook
    ok4, body4 = rpc_sql(
        """
        SELECT column_name FROM information_schema.columns
        WHERE table_schema = 'auth' AND table_name = 'hooks'
        ORDER BY ordinal_position
        """,
        "describe_auth_hooks",
    )
    print(f"    Colonnes auth.hooks: {body4}")

# ──────────────────────────────────────────────────────────────
# ETAPE 5: Vérifier schéma supabase_functions
# ──────────────────────────────────────────────────────────────
print("\n[5] Vérification supabase_functions schema...")
ok5, body5 = rpc_sql(
    """
    SELECT table_name FROM information_schema.tables
    WHERE table_schema = 'supabase_functions'
    """,
    "list_supabase_functions_tables",
)
print(f"    Tables: {body5}")

# ──────────────────────────────────────────────────────────────
# RAPPORT FINAL
# ──────────────────────────────────────────────────────────────
print("\n" + "=" * 60)
print("RAPPORT FINAL")
print("=" * 60)

if ok1:
    print("[OK] Fonction send_sms_hook creee dans public")
    print("   URI pour le hook: pg-functions://postgres/public/send_sms_hook")
else:
    print("[ERR] Echec creation send_sms_hook")

print("\n[INFO] ACTION MANUELLE RESTANTE (si hook non configure auto):")
print("   Dashboard → Auth → Hooks → Add Hook → Send SMS")
print("   Type: Postgres")
print("   Schema: public")
print("   Function: send_sms_hook")
print("   → Cliquer 'Créer un crochet'")
print("=" * 60)
