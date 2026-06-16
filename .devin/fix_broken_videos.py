#!/usr/bin/env python3
"""Phase 5: Fix broken videos by soft-deleting entries that reference deleted storage."""
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

# Broken asset IDs from audit
BROKEN_ASSET_IDS = [
    "f4726e05-a95e-45d5-afe5-1fc89ddef47c",
    "3d39950a-50ba-4052-bca6-0b9e45fa51bf",
    "2997ce54-358f-4e56-9455-e021a39c16b5",
    "f54570b0-b887-407d-98c2-a531f93a8339",
    "a3190864-55c4-4ddd-8775-391944a754d6",
    "1229c4ae-b94c-45c3-b331-779b0b93f712",
    "81e7dfa4-52ce-4b2e-948b-bdd937d3cc75",
    "b90e441a-8282-4adb-8c92-52753562901d",
    "a7425b8e-fb1d-4ff0-afe7-d497ca24a7c1",
    "3df9bf69-f152-4d0a-b8f5-69a789aa1af6",
    "fa693b7d-9e52-4c4e-94a1-56ce85d64f32",
    "fd4dce15-7d07-40c2-a95d-bb5aee69be79",
    "1147b10e-40d7-437a-ac74-cbe16f5a6377",
    "2f931fc0-1f62-474e-813e-309f7406f16f",
    "2cc69227-6e7e-4a34-82a3-1f028f213eff",
    "19555198-2cf2-4628-a052-9badbf76aa86",
    "2406a326-2800-4c44-b8a6-8119e6d4a9e3",
    "a7126a04-5e3b-4404-bea1-be518f8b5604",
    "bc886fa8-6f87-46ff-a3c3-217227826a12",
    "a0752c43-c35d-4b86-8e5d-d2c13bf010cc",
    "f7bbf866-f129-40e3-b47f-2968f0a4d0b7",
]


def main():
    print(f"Fixing {len(BROKEN_ASSET_IDS)} broken video assets...")
    
    fixed_cp = 0
    fixed_fv = 0
    fixed_assets = 0

    for asset_id in BROKEN_ASSET_IDS:
        # 1. Soft-delete challenge_participations referencing this asset
        r1 = requests.patch(
            f"{SUPABASE_URL}/rest/v1/challenge_participations",
            headers=HEADERS,
            params={"video_asset_id": f"eq.{asset_id}", "is_deleted": "eq.false"},
            json={"is_deleted": True, "deleted_at": "now()"},
            timeout=10,
        )
        if r1.status_code < 400:
            items = r1.json() if r1.text else []
            if items:
                fixed_cp += len(items)
                print(f"  {asset_id[:12]}... soft-deleted {len(items)} challenge_participation(s)")

        # 2. Soft-delete free_videos referencing this asset
        r2 = requests.patch(
            f"{SUPABASE_URL}/rest/v1/free_videos",
            headers=HEADERS,
            params={"video_asset_id": f"eq.{asset_id}", "is_deleted": "eq.false"},
            json={"is_deleted": True, "deleted_at": "now()"},
            timeout=10,
        )
        if r2.status_code < 400:
            items = r2.json() if r2.text else []
            if items:
                fixed_fv += len(items)
                print(f"  {asset_id[:12]}... soft-deleted {len(items)} free_video(s)")

        # 3. Mark the video_asset as 'error'
        r3 = requests.patch(
            f"{SUPABASE_URL}/rest/v1/video_assets",
            headers=HEADERS,
            params={"id": f"eq.{asset_id}"},
            json={"status": "error"},
            timeout=10,
        )
        if r3.status_code < 400:
            fixed_assets += 1

    print(f"\n=== SUMMARY ===")
    print(f"  Assets marked error: {fixed_assets}")
    print(f"  Challenge participations soft-deleted: {fixed_cp}")
    print(f"  Free videos soft-deleted: {fixed_fv}")
    print(f"\nThese videos will no longer appear in the feed.")


if __name__ == "__main__":
    main()
