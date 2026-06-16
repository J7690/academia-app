#!/usr/bin/env python3
"""Option 2 (ISTAPEM): hard-delete inactive media rows + delete storage objects via Storage API.

Why: Direct DELETE on storage.objects is blocked by Supabase; must use Storage HTTP API.

Steps (real audits, no guessing):
1) Snapshot inactive app.university_media rows for ISTAPEM (ids + storage_path)
2) Hard-delete those inactive rows from app.university_media
3) Compute which snapshot storage_path are still referenced by ANY remaining ISTAPEM university_media row
4) For paths no longer referenced, DELETE the storage object via /storage/v1/object

Safe guards:
- Never delete storage object if referenced by any remaining ISTAPEM media row.
- Only touches paths that were referenced by ISTAPEM inactive rows.
"""

from __future__ import annotations

import json
import sys
import urllib.parse
from typing import Any, Dict, List, Set, Tuple

import requests

from supabase_auto_manager import SupabaseAutoManager


def _admin_execute_sql(m: SupabaseAutoManager, sql: str) -> Dict[str, Any]:
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=60)
    if resp.status_code != 200:
        return {"ok": False, "error": f"HTTP {resp.status_code}: {resp.text[:400]}"}
    try:
        payload = resp.json()
    except Exception:
        return {"ok": False, "error": f"Non-JSON response: {resp.text[:400]}"}
    if not isinstance(payload, dict):
        return {"ok": False, "error": f"Unexpected payload type: {type(payload)}"}
    return payload


def _rows(payload: Dict[str, Any]) -> List[Dict[str, Any]]:
    rows = payload.get("rows") or []
    out: List[Dict[str, Any]] = []
    for r in rows:
        if isinstance(r, dict):
            out.append(r)
    return out


def _delete_storage_object(m: SupabaseAutoManager, bucket: str, path: str) -> Tuple[bool, str]:
    # Supabase Storage: DELETE /storage/v1/object/{bucket}/{path}
    encoded_path = urllib.parse.quote(path, safe="")
    url = f"{m.url}/storage/v1/object/{bucket}/{encoded_path}"
    resp = requests.delete(url, headers={
        "apikey": m.service_key,
        "Authorization": f"Bearer {m.service_key}",
    }, timeout=60)

    if resp.status_code in (200, 204):
        return True, f"HTTP {resp.status_code}"
    return False, f"HTTP {resp.status_code}: {resp.text[:200]}"


def main() -> int:
    m = SupabaseAutoManager()

    # 0) university id
    uni_res = _admin_execute_sql(
        m,
        """
        SELECT id, slug, name
        FROM app.universities
        WHERE slug='istapem'
        LIMIT 1
        """,
    )
    if not uni_res.get("ok"):
        print("[ERROR] cannot load ISTAPEM university:", uni_res.get("error"))
        return 1
    uni_rows = _rows(uni_res)
    if not uni_rows:
        print("[ERROR] ISTAPEM university not found")
        return 1
    university_id = str(uni_rows[0].get("id"))
    print("[INFO] ISTAPEM university_id=", university_id)

    # 1) Snapshot inactive rows
    snap_res = _admin_execute_sql(
        m,
        """
        SELECT id, NULLIF(TRIM(COALESCE(storage_path, '')), '') AS storage_path
        FROM app.university_media
        WHERE university_id = (SELECT id FROM app.universities WHERE slug='istapem' LIMIT 1)
          AND is_active IS FALSE
        ORDER BY updated_at DESC NULLS LAST, created_at DESC
        """,
    )
    if not snap_res.get("ok"):
        print("[ERROR] snapshot inactive media failed:", snap_res.get("error"))
        return 1
    snap_rows = _rows(snap_res)

    inactive_ids: List[str] = []
    inactive_paths: Set[str] = set()
    for r in snap_rows:
        mid = str(r.get("id") or "").strip()
        sp = str(r.get("storage_path") or "").strip()
        if mid:
            inactive_ids.append(mid)
        if sp:
            inactive_paths.add(sp)

    print(f"[INFO] inactive rows snapshot: {len(inactive_ids)} rows")
    print(f"[INFO] inactive distinct storage_path: {len(inactive_paths)}")

    if not inactive_ids:
        print("[INFO] no inactive rows to delete. Done.")
        return 0

    # 2) Hard-delete inactive rows
    del_res = _admin_execute_sql(
        m,
        """
        DELETE FROM app.university_media
        WHERE university_id = (SELECT id FROM app.universities WHERE slug='istapem' LIMIT 1)
          AND is_active IS FALSE
        """,
    )
    if not del_res.get("ok"):
        print("[ERROR] hard-delete inactive rows failed:", del_res.get("error"))
        return 1
    print("[INFO] DB delete done:")
    print(json.dumps(del_res, indent=2, ensure_ascii=False)[:600])

    # 3) Remaining references (any row) for ISTAPEM
    if inactive_paths:
        # Build a safe IN list
        in_list = ",".join(["'" + p.replace("'", "''") + "'" for p in sorted(inactive_paths)])
        refs_sql = f"""
        SELECT DISTINCT NULLIF(TRIM(COALESCE(storage_path, '')), '') AS storage_path
        FROM app.university_media
        WHERE university_id = (SELECT id FROM app.universities WHERE slug='istapem' LIMIT 1)
          AND NULLIF(TRIM(COALESCE(storage_path, '')), '') IN ({in_list})
        """.strip()
        refs_res = _admin_execute_sql(m, refs_sql)
        if not refs_res.get("ok"):
            print("[ERROR] cannot compute remaining references:", refs_res.get("error"))
            return 1
        refs_rows = _rows(refs_res)
        still_referenced: Set[str] = set(
            str(r.get("storage_path") or "").strip() for r in refs_rows if str(r.get("storage_path") or "").strip()
        )
    else:
        still_referenced = set()

    to_delete = sorted([p for p in inactive_paths if p and p not in still_referenced])
    print(f"[INFO] storage objects safe to delete: {len(to_delete)}")

    deleted_ok = 0
    deleted_fail = 0
    for path in to_delete:
        ok, info = _delete_storage_object(m, "university-media", path)
        if ok:
            deleted_ok += 1
        else:
            deleted_fail += 1
        print(f"[STORAGE] delete {path} => {'OK' if ok else 'FAIL'} ({info})")

    print("[SUMMARY] db_inactive_rows_deleted=", len(inactive_ids))
    print("[SUMMARY] storage_deleted_ok=", deleted_ok)
    print("[SUMMARY] storage_deleted_fail=", deleted_fail)

    return 0 if deleted_fail == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
