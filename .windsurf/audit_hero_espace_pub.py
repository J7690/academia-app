import pathlib
import sys
import requests

# Reuse validated Supabase configuration from auto_supabase_import
winds = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(winds))
import auto_supabase_import as a  # type: ignore

URL = f"{a.SUPABASE_URL}/rest/v1/rpc/admin_execute_sql"
HEADERS = a.RPC_HEADERS


def call_sql(title: str, sql: str) -> None:
    sql = sql.strip()
    print("\n===", title, "===")
    print(sql)
    r = requests.post(URL, headers=HEADERS, json={"p_sql": sql}, timeout=30)
    print("status", r.status_code)
    try:
        print("json:", r.json())
    except Exception:
        print("text:", r.text)


def main() -> None:
    slug = "universite-arbilo"

    # 1) University by slug
    sql_univ = f"""
    select id, slug, name, is_active
    from app.universities
    where slug = '{slug}'
    """
    call_sql("university_by_slug", sql_univ)

    # 2) Global hero playlist for landing & student home
    sql_playlist = """
    select slot, media_type, base_image_url, base_video_url, is_active, sort_order, title
    from app.hero_playlist
    where slot in ('landing_hero_main', 'student_home_hero_main')
    order by slot, sort_order
    """
    call_sql("hero_playlist_main_slots", sql_playlist)

    # 3) University site banners for the given slug
    sql_banners = f"""
    select b.id, b.university_id, b.position, b.title, b.subtitle, b.media_id, b.is_active
    from app.university_site_banners b
    join app.universities u on u.id = b.university_id
    where u.slug = '{slug}'
    order by b.position, b.created_at
    """
    call_sql("university_site_banners", sql_banners)

    # 4) University media for the given slug
    sql_media = f"""
    select m.id, m.university_id, m.media_type, m.storage_path, m.is_active
    from app.university_media m
    join app.universities u on u.id = m.university_id
    where u.slug = '{slug}'
    order by m.created_at
    limit 50
    """
    call_sql("university_media", sql_media)

    # 5) Public mini-site RPC output
    sql_public_site = f"select app_public_university_site('{slug}') as site"
    call_sql("app_public_university_site", sql_public_site)


if __name__ == "__main__":
    main()
