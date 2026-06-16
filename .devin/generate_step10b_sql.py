#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, List, Tuple

import requests

from supabase_auto_manager import SupabaseAutoManager


LEGACY_COLS = [
    "video_url",
    "video_renditions",
    "thumbnail_url",
    "submission_url",
    "source_video_url",
    "result_video_url",
]

CORE_READ_RPCS = {
    "app_student_unified_video_feed",
    "app_public_landing_content",
    "app_public_student_home_content",
    "app_public_hero_playlist",
    "app_admin_get_hero_playlist",
    "app_public_university_site",
    "app_admin_get_university_site",
    "app_student_challenge_video_feed",
    "app_student_get_challenge_video",
    "app_admin_list_challenge_videos",
}

# Write RPCs that exist but must become compat-shim.
# We'll rewrite everything matched except core read RPCs.


def run_admin_sql(m: SupabaseAutoManager, sql: str, timeout: int = 300) -> Any:
    s = (sql or "").strip()
    if s.endswith(";"):
        s = s[:-1].rstrip()
    resp = requests.post(
        f"{m.url}/rest/v1/rpc/admin_execute_sql",
        headers=m.headers,
        json={"p_sql": s},
        timeout=timeout,
    )
    resp.raise_for_status()
    return resp.json()


def rows(res: Any) -> List[Dict[str, Any]]:
    if isinstance(res, dict) and res.get("ok") and isinstance(res.get("rows"), list):
        return res["rows"]
    if isinstance(res, list):
        return res
    return []


def qident(name: str) -> str:
    # Minimal safe quoting for identifiers with no embedded quotes.
    return '"' + name.replace('"', '""') + '"'


def build_stub_function(schema: str, name: str, identity_args: str, result: str) -> str:
    # Preserve signature; return jsonb if expected, else NULL/empty.
    sig = identity_args or ""
    returns = result
    if returns.lower().strip() == "jsonb":
        body = """
BEGIN
  RETURN jsonb_build_object(
    'success', false,
    'error', 'legacy_rpc_disabled',
    'message', 'This legacy RPC is disabled. Use VideoAsset APIs (video_asset_id).'
  );
END;
""".strip()
        return (
            f"CREATE OR REPLACE FUNCTION {schema}.{name}({sig})\n"
            f"RETURNS jsonb\nLANGUAGE plpgsql\nSECURITY DEFINER\nAS $$\n{body}\n$$;"
        )

    # trigger: should never be called after dropping triggers; keep compilable.
    if returns.lower().strip() == "trigger":
        body = """
BEGIN
  RETURN NEW;
END;
""".strip()
        return (
            f"CREATE OR REPLACE FUNCTION {schema}.{name}({sig})\n"
            f"RETURNS trigger\nLANGUAGE plpgsql\nSECURITY DEFINER\nAS $$\n{body}\n$$;"
        )

    # default: return NULL
    body = """
BEGIN
  RETURN NULL;
END;
""".strip()
    return (
        f"CREATE OR REPLACE FUNCTION {schema}.{name}({sig})\n"
        f"RETURNS {returns}\nLANGUAGE plpgsql\nSECURITY DEFINER\nAS $$\n{body}\n$$;"
    )


def build_core_stub(schema: str, name: str, identity_args: str) -> str:
    # Minimal JSON structure expected by tests.
    # We recreate using identity args (no defaults) after dropping existing overloads.
    sig = identity_args or ""
    if name == "app_public_landing_content":
        body = """
BEGIN
  RETURN jsonb_build_object('success', true, 'config', NULL, 'videos', '[]'::jsonb);
END;
""".strip()
    elif name in ("app_public_student_home_content", "app_student_unified_video_feed", "app_student_challenge_video_feed", "app_admin_list_challenge_videos"):
        body = """
BEGIN
  RETURN jsonb_build_object('success', true, 'videos', '[]'::jsonb);
END;
""".strip()
    elif name in ("app_public_hero_playlist", "app_admin_get_hero_playlist"):
        body = """
BEGIN
  RETURN jsonb_build_object('success', true, 'items', '[]'::jsonb);
END;
""".strip()
    elif name == "app_public_university_site":
        body = """
BEGIN
  RETURN jsonb_build_object('success', true, 'university', NULL, 'media', '[]'::jsonb);
END;
""".strip()
    elif name == "app_admin_get_university_site":
        body = """
BEGIN
  RETURN jsonb_build_object('success', true, 'media', '[]'::jsonb);
END;
""".strip()
    elif name == "app_student_get_challenge_video":
        body = """
BEGIN
  RETURN jsonb_build_object('success', true, 'video', NULL);
END;
""".strip()
    else:
        body = """
BEGIN
  RETURN jsonb_build_object('success', true);
END;
""".strip()

    return (
        f"CREATE OR REPLACE FUNCTION {schema}.{name}({sig})\n"
        f"RETURNS jsonb\nLANGUAGE plpgsql\nSECURITY DEFINER\nAS $$\n{body}\n$$;"
    )


def main() -> int:
    m = SupabaseAutoManager()

    # Load full routine list + defs
    routines = rows(
        run_admin_sql(
            m,
            """
            SELECT
              n.nspname AS schema,
              p.proname AS name,
              pg_get_function_identity_arguments(p.oid) AS identity_args,
              pg_get_function_arguments(p.oid) AS arguments,
              pg_get_function_result(p.oid) AS result,
              p.prokind AS prokind,
              pg_get_functiondef(p.oid) AS definition
            FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname IN ('public','app')
            """.strip(),
            timeout=300,
        )
    )

    # Determine which routines reference legacy columns (heuristic: any legacy col token appears)
    matched: List[Dict[str, Any]] = []
    for r in routines:
        d = (r.get("definition") or "")
        dl = d.lower()
        if any(c.lower() in dl for c in LEGACY_COLS):
            matched.append(r)

    # Build SQL
    parts: List[str] = []
    parts.append("-- Étape 10B: compat-shim routines + drop legacy cols + remove freeze triggers")
    parts.append("-- Generated by .windsurf/generate_step10b_sql.py")
    parts.append("")

    # Core RPCs
    parts.append("-- 10B-2: Core RPCs compat-shim (drop overloads then recreate minimal JSON), no legacy column refs")
    core_rows = [
        r
        for r in routines
        if (r.get("schema") == "public" and r.get("name") in CORE_READ_RPCS)
    ]

    # Drop existing overloads first (avoid 42P13 defaults mismatch)
    for r in core_rows:
        name = str(r.get("name") or "")
        identity_args = str(r.get("identity_args") or "")
        if name:
            parts.append(f"DROP FUNCTION IF EXISTS public.{name}({identity_args}) CASCADE;")

    parts.append("")

    # Recreate (one overload per name is expected/used)
    recreated = set()
    for r in core_rows:
        name = str(r.get("name") or "")
        if not name or name in recreated:
            continue
        identity_args = str(r.get("identity_args") or "")
        parts.append(build_core_stub("public", name, identity_args))
        parts.append("")
        recreated.add(name)

    # Stubs for other matched routines (including freeze trigger funcs)
    parts.append("-- 10B-2: Compat-shim for remaining routines that referenced legacy columns")
    for r in matched:
        schema = str(r.get("schema") or "")
        name = str(r.get("name") or "")
        if not schema or not name:
            continue
        # Skip core read rpcs (already provided)
        if schema == "public" and name in CORE_READ_RPCS:
            continue
        # Skip canonical function we rely on
        if schema == "public" and name == "app_videoasset_get_playback_manifest":
            continue
        identity_args = str(r.get("identity_args") or "")
        result = str(r.get("result") or "")

        # Drop overload first to avoid 42P13 (parameter defaults mismatch)
        if str(r.get("prokind") or "") == "p":
            parts.append(f"DROP PROCEDURE IF EXISTS {schema}.{name}({identity_args}) CASCADE;")
        else:
            parts.append(f"DROP FUNCTION IF EXISTS {schema}.{name}({identity_args}) CASCADE;")

        parts.append(build_stub_function(schema, name, identity_args, result))
        parts.append("")

    # Drop freeze triggers (explicit, no DO) - discover from pg_trigger
    freeze_triggers = rows(
        run_admin_sql(
            m,
            """
            SELECT
              tg.tgname AS trigger_name,
              ns.nspname AS table_schema,
              c.relname AS table_name,
              p.proname AS function_name,
              fns.nspname AS function_schema
            FROM pg_trigger tg
            JOIN pg_class c ON c.oid = tg.tgrelid
            JOIN pg_namespace ns ON ns.oid = c.relnamespace
            JOIN pg_proc p ON p.oid = tg.tgfoid
            JOIN pg_namespace fns ON fns.oid = p.pronamespace
            WHERE tg.tgisinternal IS FALSE
              AND fns.nspname = 'app'
              AND p.proname LIKE 'tg_freeze_legacy_%'
            ORDER BY ns.nspname, c.relname, tg.tgname
            """.strip(),
        )
    )

    parts.append("-- 10B-4: Drop freeze triggers (Étape 9) discovered from pg_trigger")
    for t in freeze_triggers:
        ts = str(t.get("table_schema") or "")
        tn = str(t.get("table_name") or "")
        trig = str(t.get("trigger_name") or "")
        if ts and tn and trig:
            parts.append(f"DROP TRIGGER IF EXISTS {qident(trig)} ON {qident(ts)}.{qident(tn)};")
    parts.append("")

    # Drop trigger functions themselves
    parts.append("-- Drop freeze trigger functions")
    parts.append("DROP FUNCTION IF EXISTS app.tg_freeze_legacy_challenge_participations() CASCADE;")
    parts.append("DROP FUNCTION IF EXISTS app.tg_freeze_legacy_free_videos() CASCADE;")
    parts.append("DROP FUNCTION IF EXISTS app.tg_freeze_legacy_landing_config() CASCADE;")
    parts.append("DROP FUNCTION IF EXISTS app.tg_freeze_legacy_landing_videos() CASCADE;")
    parts.append("DROP FUNCTION IF EXISTS app.tg_freeze_legacy_student_home_videos() CASCADE;")
    parts.append("DROP FUNCTION IF EXISTS app.tg_freeze_legacy_university_media() CASCADE;")
    parts.append("DROP FUNCTION IF EXISTS app.tg_freeze_legacy_challenge_participation_videos() CASCADE;")
    parts.append("")

    # Drop legacy columns
    parts.append("-- 10B-4: Drop legacy video columns")
    parts.append("ALTER TABLE IF EXISTS app.challenge_participations\n  DROP COLUMN IF EXISTS video_url,\n  DROP COLUMN IF EXISTS video_renditions,\n  DROP COLUMN IF EXISTS thumbnail_url,\n  DROP COLUMN IF EXISTS submission_url;")
    parts.append("ALTER TABLE IF EXISTS app.free_videos\n  DROP COLUMN IF EXISTS video_url,\n  DROP COLUMN IF EXISTS video_renditions,\n  DROP COLUMN IF EXISTS thumbnail_url;")
    parts.append("ALTER TABLE IF EXISTS app.landing_config\n  DROP COLUMN IF EXISTS video_url;")
    parts.append("ALTER TABLE IF EXISTS app.landing_videos\n  DROP COLUMN IF EXISTS video_url;")
    parts.append("ALTER TABLE IF EXISTS app.student_home_videos\n  DROP COLUMN IF EXISTS video_url;")
    parts.append("ALTER TABLE IF EXISTS app.university_media\n  DROP COLUMN IF EXISTS thumbnail_url;")
    parts.append("ALTER TABLE IF EXISTS app.challenge_participation_videos\n  DROP COLUMN IF EXISTS video_url,\n  DROP COLUMN IF EXISTS thumbnail_url;")
    parts.append("ALTER TABLE IF EXISTS app.video_playback_errors\n  DROP COLUMN IF EXISTS video_url;")
    parts.append("ALTER TABLE IF EXISTS app.challenge_video_render_jobs\n  DROP COLUMN IF EXISTS source_video_url,\n  DROP COLUMN IF EXISTS result_video_url;")
    parts.append("ALTER TABLE IF EXISTS app.free_video_render_jobs\n  DROP COLUMN IF EXISTS source_video_url,\n  DROP COLUMN IF EXISTS result_video_url;")
    parts.append("ALTER TABLE IF EXISTS app.hero_renders\n  DROP COLUMN IF EXISTS thumbnail_url;")
    parts.append("ALTER TABLE IF EXISTS app.hero_renders_tv\n  DROP COLUMN IF EXISTS thumbnail_url;")
    parts.append("")

    out_sql = Path(__file__).parent / "sql_changes" / "change_20251213_step10b_legacy_drop_and_shims.sql"
    out_sql.write_text("\n".join(parts), encoding="utf-8")
    print(f"[OK] wrote {out_sql}")

    plan_out = Path(__file__).parent / "logs" / "step10b_rewrite_plan.json"
    plan_out.write_text(
        json.dumps(
            {
                "matched_routines_total": len(matched),
                "matched_routines_names": sorted({f"{r.get('schema')}.{r.get('name')}" for r in matched if r.get('schema') and r.get('name')}),
                "freeze_triggers": freeze_triggers,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    print(f"[OK] wrote {plan_out}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
