import pathlib
import sys
import requests

# S'appuie sur la config validée dans auto_supabase_import
winds = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(winds))
import auto_supabase_import as a  # type: ignore

URL = f"{a.SUPABASE_URL}/rest/v1/rpc/admin_execute_sql"
HEADERS = a.RPC_HEADERS


def call_sql(sql: str) -> None:
    sql = sql.strip()
    print("\n=== admin_execute_sql ===")
    print(sql)
    r = requests.post(URL, headers=HEADERS, json={"p_sql": sql}, timeout=20)
    print("status", r.status_code)
    try:
      print("json:", r.json())
    except Exception:
      print("text:", r.text)


def main() -> None:
    # 1) Lire la définition réelle de la fonction en base
    sql_def = """
    select
      n.nspname,
      p.proname,
      pg_get_functiondef(p.oid) as definition
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where p.proname = 'app_public_university_site'
    """

    # 2) Appeler la RPC directement côté SQL
    sql_call = "select app_public_university_site('universite-arbilo') as site"

    for sql in (sql_def, sql_call):
        call_sql(sql)


if __name__ == "__main__":
    main()
