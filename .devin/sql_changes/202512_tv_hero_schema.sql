-- Schéma Studio Télé pour les héros (landing + accueil étudiant)
-- Schéma : app

-- 1. Table des overlays TV (calques : texte, image, bandeau, ticker, etc.)
create table if not exists app.hero_overlays_tv (
  id uuid primary key default gen_random_uuid(),
  playlist_item_id uuid not null references app.hero_playlist(id) on delete cascade,

  -- type de calque : texte, image, bandeau, ticker, etc.
  overlay_type text not null check (overlay_type in (
    'text',
    'image',
    'banner',
    'ticker',
    'shape'
  )),

  -- configuration JSON : dépend du type (texte, position, couleurs, image_url, etc.)
  config jsonb not null default '{}'::jsonb,

  -- timeline (en secondes depuis le début de la vidéo)
  start_at_seconds numeric(8,3) not null default 0,
  end_at_seconds   numeric(8,3) not null default 0,

  -- ordre d’empilement dans le même intervalle
  sort_order integer not null default 0,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_hero_overlays_tv_playlist
  on app.hero_overlays_tv(playlist_item_id);

create index if not exists idx_hero_overlays_tv_timeline
  on app.hero_overlays_tv(playlist_item_id, start_at_seconds, end_at_seconds);


-- 2. Table des rendus TV (historique des exports vidéo type télé)
create table if not exists app.hero_renders_tv (
  id uuid primary key default gen_random_uuid(),

  playlist_item_id uuid not null references app.hero_playlist(id) on delete cascade,

  -- statut du job de rendu
  status text not null check (status in ('pending', 'processing', 'success', 'failed')),

  -- URL finale de la vidéo TV rendue (mp4 H.264)
  render_url text,
  -- miniature générée pour ce rendu
  thumbnail_url text,

  -- infos techniques (logs, paramètres utilisés)
  meta jsonb not null default '{}'::jsonb,

  -- erreur éventuelle en cas d’échec
  error_message text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  started_at timestamptz,
  finished_at timestamptz
);

create index if not exists idx_hero_renders_tv_playlist
  on app.hero_renders_tv(playlist_item_id);

create index if not exists idx_hero_renders_tv_status
  on app.hero_renders_tv(status);


-- 3. Trigger pour mettre à jour updated_at sur hero_overlays_tv
create or replace function app.tg_hero_overlays_tv_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_hero_overlays_tv_set_updated_at
  on app.hero_overlays_tv;

create trigger trg_hero_overlays_tv_set_updated_at
before update on app.hero_overlays_tv
for each row
execute function app.tg_hero_overlays_tv_set_updated_at();


-- 4. Trigger pour mettre à jour updated_at sur hero_renders_tv
create or replace function app.tg_hero_renders_tv_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_hero_renders_tv_set_updated_at
  on app.hero_renders_tv;

create trigger trg_hero_renders_tv_set_updated_at
before update on app.hero_renders_tv
for each row
execute function app.tg_hero_renders_tv_set_updated_at();
