#!/usr/bin/env python3
"""Phase 5: Audit broken videos (HTTP 400) and identify root cause."""
import requests

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Accept": "application/json",
    "Accept-Profile": "app",
}


def main():
    # Get all video_sources
    r = requests.get(
        f"{SUPABASE_URL}/rest/v1/video_sources",
        headers=HEADERS,
        params={
            "order": "created_at.desc",
            "limit": "30",
            "select": "id,video_asset_id,storage_bucket,storage_path,created_at",
        },
        timeout=15,
    )
    sources = r.json() if r.status_code < 400 else []
    print(f"Total video_sources: {len(sources)}")

    ok_count = 0
    broken = []

    for s in sources:
        bucket = s.get("storage_bucket", "")
        path = s.get("storage_path", "")
        asset_id = s.get("video_asset_id", "")
        
        if not bucket or not path:
            print(f"  {asset_id[:12]}... MISSING bucket/path")
            broken.append({"asset_id": asset_id, "reason": "missing_bucket_or_path", "source": s})
            continue

        url = f"{SUPABASE_URL}/storage/v1/object/public/{bucket}/{path}"
        try:
            hr = requests.head(url, timeout=10, allow_redirects=True)
            if hr.status_code >= 400:
                print(f"  {asset_id[:12]}... HTTP {hr.status_code}  bucket={bucket} path={path[:50]}")
                broken.append({
                    "asset_id": asset_id,
                    "reason": f"http_{hr.status_code}",
                    "bucket": bucket,
                    "path": path,
                    "url": url,
                    "source": s,
                })
            else:
                ok_count += 1
        except Exception as e:
            print(f"  {asset_id[:12]}... ERROR: {e}")
            broken.append({"asset_id": asset_id, "reason": str(e), "source": s})

    print(f"\nSummary: {ok_count} OK, {len(broken)} BROKEN")

    if broken:
        print("\n--- BROKEN DETAILS ---")
        for b in broken:
            print(f"\n  Asset: {b['asset_id']}")
            print(f"  Reason: {b['reason']}")
            if "path" in b:
                print(f"  Path: {b['path']}")
            if "url" in b:
                # Try to understand why - check if it's a path format issue
                path = b.get("path", "")
                if ":" in path or "\\" in path:
                    print(f"  DIAGNOSIS: Windows-style path in storage_path!")
                elif not path.startswith("raw/") and not path.startswith("renditions/"):
                    print(f"  DIAGNOSIS: Path doesn't follow expected raw/ or renditions/ prefix")
                else:
                    print(f"  DIAGNOSIS: File may have been deleted from storage")

    # Check what video_assets reference these broken sources
    if broken:
        print("\n\n--- IMPACT ON FEED ---")
        broken_ids = [b["asset_id"] for b in broken if b["asset_id"]]
        # Check if these assets appear in challenge_participations or free_videos
        for aid in broken_ids[:5]:
            # Check challenge_participations
            r2 = requests.get(
                f"{SUPABASE_URL}/rest/v1/challenge_participations",
                headers=HEADERS,
                params={
                    "video_asset_id": f"eq.{aid}",
                    "select": "id,user_id,is_deleted",
                    "limit": "1",
                },
                timeout=10,
            )
            cp = r2.json() if r2.status_code < 400 else []
            if cp:
                deleted = cp[0].get("is_deleted", False)
                print(f"  {aid[:12]}... in challenge_participations (is_deleted={deleted})")
            else:
                # Check free_videos
                r3 = requests.get(
                    f"{SUPABASE_URL}/rest/v1/free_videos",
                    headers=HEADERS,
                    params={
                        "video_asset_id": f"eq.{aid}",
                        "select": "id,is_deleted",
                        "limit": "1",
                    },
                    timeout=10,
                )
                fv = r3.json() if r3.status_code < 400 else []
                if fv:
                    deleted = fv[0].get("is_deleted", False)
                    print(f"  {aid[:12]}... in free_videos (is_deleted={deleted})")
                else:
                    print(f"  {aid[:12]}... NOT in feed (orphan asset)")


if __name__ == "__main__":
    main()
