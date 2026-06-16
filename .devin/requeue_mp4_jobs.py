#!/usr/bin/env python3
"""Re-queue generate_mp4 jobs for video assets still in 'uploaded' status."""
import requests

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Accept": "application/json",
    "Content-Type": "application/json",
    "Accept-Profile": "app",
    "Content-Profile": "app",
    "Prefer": "return=representation",
}


def main():
    # 1. Get video_assets that are still in 'uploaded' status
    r = requests.get(
        f"{SUPABASE_URL}/rest/v1/video_assets",
        headers=HEADERS,
        params={
            "status": "eq.uploaded",
            "order": "created_at.desc",
            "limit": "10",
            "select": "id,created_at,status",
        },
        timeout=15,
    )
    assets = r.json() if r.status_code < 400 else []
    print(f"Video assets with status=uploaded: {len(assets)}")
    for a in assets:
        aid = a["id"]
        print(f"  {aid} ({a.get('created_at', '?')[:10]})")

    # 2. For each, create a generate_mp4 job
    created = 0
    for a in assets:
        asset_id = a["id"]
        # Check if already queued
        r2 = requests.get(
            f"{SUPABASE_URL}/rest/v1/video_processing_jobs",
            headers=HEADERS,
            params={
                "video_asset_id": f"eq.{asset_id}",
                "job_type": "eq.generate_mp4",
                "status": "eq.queued",
                "select": "id",
                "limit": "1",
            },
            timeout=15,
        )
        existing = r2.json() if r2.status_code < 400 else []
        if existing:
            print(f"  {asset_id}: already has queued generate_mp4 job")
            continue

        # Create new job
        r3 = requests.post(
            f"{SUPABASE_URL}/rest/v1/video_processing_jobs",
            headers=HEADERS,
            json={
                "video_asset_id": asset_id,
                "job_type": "generate_mp4",
                "status": "queued",
            },
            timeout=15,
        )
        if r3.status_code < 400:
            print(f"  {asset_id}: generate_mp4 job CREATED")
            created += 1
        else:
            print(f"  {asset_id}: FAILED ({r3.status_code}: {r3.text[:100]})")

    print(f"\nTotal jobs created: {created}")
    print("The worker should pick these up within seconds.")


if __name__ == "__main__":
    main()
