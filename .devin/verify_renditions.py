#!/usr/bin/env python3
"""Verify multi-resolution renditions were created."""
import requests
from collections import defaultdict

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Accept": "application/json",
    "Accept-Profile": "app",
}


def main():
    # 1. Check renditions
    r = requests.get(
        f"{SUPABASE_URL}/rest/v1/video_renditions",
        headers=HEADERS,
        params={
            "order": "created_at.desc",
            "limit": "50",
            "select": "id,video_asset_id,rendition_key,width,height,storage_path,created_at",
        },
        timeout=15,
    )
    rends = r.json() if r.status_code < 400 else []
    print(f"Total renditions (latest 50): {len(rends)}")

    # Group by asset
    by_asset = defaultdict(list)
    for rr in rends:
        by_asset[rr["video_asset_id"]].append(rr["rendition_key"])

    print("\nRenditions par asset:")
    for aid, keys in list(by_asset.items())[:15]:
        print(f"  {aid[:12]}...: {', '.join(sorted(keys))}")

    # Count mp4_* renditions
    mp4_keys = [rr for rr in rends if rr["rendition_key"].startswith("mp4_")]
    print(f"\nRenditions MP4 multi-resolution total: {len(mp4_keys)}")
    for rr in mp4_keys[:16]:
        w = rr.get("width") or "?"
        path = rr.get("storage_path", "")[:70]
        print(f"  {rr['video_asset_id'][:12]}... {rr['rendition_key']:12} w={w}  path={path}")

    # 2. Check video_assets status
    r2 = requests.get(
        f"{SUPABASE_URL}/rest/v1/video_assets",
        headers=HEADERS,
        params={
            "order": "created_at.desc",
            "limit": "10",
            "select": "id,status,created_at",
        },
        timeout=15,
    )
    assets = r2.json() if r2.status_code < 400 else []
    print("\n\nVideo assets (latest 10):")
    for a in assets:
        print(f"  {a['id'][:12]}... status={a['status']:10} ({a.get('created_at', '?')[:10]})")

    # 3. Job status summary
    print("\n\nJob status (generate_mp4):")
    for status in ["queued", "running", "done", "failed"]:
        r3 = requests.get(
            f"{SUPABASE_URL}/rest/v1/video_processing_jobs",
            headers={**HEADERS, "Prefer": "count=exact"},
            params={
                "job_type": "eq.generate_mp4",
                "status": f"eq.{status}",
                "select": "id",
                "limit": "0",
            },
            timeout=15,
        )
        ct = r3.headers.get("content-range", "?")
        print(f"  {status}: {ct}")


if __name__ == "__main__":
    main()
