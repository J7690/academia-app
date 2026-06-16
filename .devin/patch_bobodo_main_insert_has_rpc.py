from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
main_path = BASE_DIR / "academia_bobodo_backend" / "main.py"

old_block = '''async def get_student_first_name(session_id: str) -> Optional[str]:
    """Récupère le prénom de l'étudiant lié à une session Bobodo via une RPC Supabase.

    Utilise la fonction app_get_bobodo_student_first_name (schéma app).
    """
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        return None

    try:
        data = await call_supabase_rpc(
            "app_get_bobodo_student_first_name",
            {"p_session_id": session_id},
        )
    except HTTPException:
        return None

    # Pour une fonction TEXT simple, Supabase renvoie généralement une chaîne JSON
    if isinstance(data, str):
        first = data.strip()
        return first or None

    if isinstance(data, dict) and isinstance(data.get("result"), str):
        first = data["result"].strip()
        return first or None

    return None
'''

new_func = '''\n\nasync def has_bobodo_assistant_message(session_id: str) -> bool:\n    """\n    Indique s'il existe déjà au moins un message de l'assistant Bobodo\n    pour une session donnée, via la RPC app_has_bobodo_assistant_message.\n    """\n    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:\n        return False\n\n    try:\n        data = await call_supabase_rpc(\n            "app_has_bobodo_assistant_message",\n            {"p_session_id": session_id},\n        )\n    except HTTPException:\n        return False\n\n    # Supabase peut renvoyer un booléen brut ou un dict avec un champ result\n    if isinstance(data, bool):\n        return data\n    if isinstance(data, dict) and isinstance(data.get("result"), bool):\n        return data["result"]\n\n    return False\n'''


def main() -> int:
    text = main_path.read_text(encoding="utf-8")

    if "async def has_bobodo_assistant_message(" in text:
        print("has_bobodo_assistant_message already present in main.py")
        return 0

    if old_block not in text:
        print("Anchor block for get_student_first_name not found in main.py")
        return 1

    new_text = text.replace(old_block, old_block + new_func)
    main_path.write_text(new_text, encoding="utf-8")
    print("Patched main.py with has_bobodo_assistant_message")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
