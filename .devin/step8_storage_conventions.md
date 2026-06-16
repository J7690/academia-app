# Étape 8 — Conventions Storage VideoAsset

## Bucket
- `video-assets` (public)

## Arborescence
- **Sources raw (upload intent existant)**
  - `raw/<video_asset_id>/<uuid>`
- **Renditions (worker Étape 8)**
  - `renditions/<video_asset_id>/mp4_720p.mp4`
  - `renditions/<video_asset_id>/poster.jpg`
  - `renditions/<video_asset_id>/thumb.jpg`

## Canonical URLs
- Public URL pattern:
  - `<SUPABASE_URL>/storage/v1/object/public/<bucket>/<path>`

## DB mapping
- `app.video_sources`:
  - `storage_bucket`, `storage_path`
- `app.video_renditions`:
  - `storage_bucket`, `storage_path`, `public_url_hint`, `status='ready'`
