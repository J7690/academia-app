-- TV PRO – Étape 5 : Gestion des assets overlay (images/vidéos)
-- À appliquer via: python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/change_20251211_tv_pro_assets.sql

-- 1) Table meta optionnelle pour tracer les assets TV PRO stockés dans Supabase Storage.
--    Cette table ne modifie pas le fonctionnement existant : les URLs publiques
--    continuent d'être stockées dans app.hero_overlays_tv.config->>'source_url'.

create table if not exists app.hero_tv_assets (
  id uuid primary key default gen_random_uuid(),
  playlist_item_id uuid not null references app.hero_playlist(id) on delete cascade,
  overlay_id uuid references app.hero_overlays_tv(id) on delete set null,
  bucket text not null,
  object_path text not null,
  public_url text not null,
  kind text,
  created_at timestamptz not null default now()
);

comment on table app.hero_tv_assets is 'Meta table pour tracer les assets TV PRO (images, vidéos) stockés dans Supabase Storage.';
comment on column app.hero_tv_assets.bucket is 'Nom du bucket Supabase Storage (par ex. hero-tv-assets).';
comment on column app.hero_tv_assets.object_path is 'Chemin interne de l''objet dans le bucket.';
comment on column app.hero_tv_assets.public_url is 'URL publique finale stockée dans config.source_url.';

create index if not exists hero_tv_assets_playlist_item_id_idx on app.hero_tv_assets(playlist_item_id);
create index if not exists hero_tv_assets_overlay_id_idx on app.hero_tv_assets(overlay_id);

-- 2) Aucune modification des buckets existants (landing-media, challenge-media, ...).
--    Les clients (Flutter / backend) sont libres d'utiliser un bucket dédié
--    (par ex. "hero-tv-assets") pour les fichiers overlay, et d'enregistrer
--    simplement l'URL publique dans hero_overlays_tv.config->>'source_url'.
