from pathlib import Path

from supabase_auto_manager import SupabaseAutoManager


def main() -> None:
  manager = SupabaseAutoManager()
  sql_path = Path(__file__).parent / "sql_changes" / "20260216_admin_deleted_users_archive.sql"
  sql = sql_path.read_text(encoding="utf-8")
  result = manager.execute_sql_auto(sql)
  print(result)


if __name__ == "__main__":
  main()
