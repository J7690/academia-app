-- RPC ADMIN pour gérer la timeline TV (overlays) et les rendus TV

-- 1. Liste complète de la timeline d’un élément de playlist
create or replace function app.app_admin_tv_get_timeline(
  p_playlist_item_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = app, public
as $$
declare
  v_overlays jsonb;
begin
  -- sécurité minimale : vérifier que l’élément existe
  if not exists (
    select 1 from app.hero_playlist hp
    where hp.id = p_playlist_item_id
  ) then
    return jsonb_build_object(
      'success', false,
      'error', 'PLAYLIST_ITEM_NOT_FOUND'
    );
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', ho.id,
        'overlay_type', ho.overlay_type,
        'config', ho.config,
        'start_at_seconds', ho.start_at_seconds,
        'end_at_seconds', ho.end_at_seconds,
        'sort_order', ho.sort_order,
        'created_at', ho.created_at,
        'updated_at', ho.updated_at
      )
      order by ho.start_at_seconds, ho.sort_order, ho.created_at
    ),
    '[]'::jsonb
  )
  into v_overlays
  from app.hero_overlays_tv ho
  where ho.playlist_item_id = p_playlist_item_id;

  return jsonb_build_object(
    'success', true,
    'overlays', v_overlays
  );
end;
$$;


-- 2. Création / mise à jour d’un overlay TV
create or replace function app.app_admin_tv_upsert_overlay(
  p_id uuid,
  p_playlist_item_id uuid,
  p_overlay_type text,
  p_config jsonb,
  p_start_at_seconds numeric(8,3),
  p_end_at_seconds   numeric(8,3),
  p_sort_order integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = app, public
as $$
declare
  v_id uuid;
begin
  if p_overlay_type not in ('text', 'image', 'banner', 'ticker', 'shape') then
    return jsonb_build_object(
      'success', false,
      'error', 'INVALID_OVERLAY_TYPE'
    );
  end if;

  if p_end_at_seconds < p_start_at_seconds then
    return jsonb_build_object(
      'success', false,
      'error', 'INVALID_TIMELINE_RANGE'
    );
  end if;

  if not exists (
    select 1 from app.hero_playlist hp
    where hp.id = p_playlist_item_id
  ) then
    return jsonb_build_object(
      'success', false,
      'error', 'PLAYLIST_ITEM_NOT_FOUND'
    );
  end if;

  if p_id is null then
    insert into app.hero_overlays_tv (
      playlist_item_id,
      overlay_type,
      config,
      start_at_seconds,
      end_at_seconds,
      sort_order
    )
    values (
      p_playlist_item_id,
      p_overlay_type,
      coalesce(p_config, '{}'::jsonb),
      p_start_at_seconds,
      p_end_at_seconds,
      coalesce(p_sort_order, 0)
    )
    returning id into v_id;
  else
    update app.hero_overlays_tv
    set
      overlay_type     = p_overlay_type,
      config           = coalesce(p_config, '{}'::jsonb),
      start_at_seconds = p_start_at_seconds,
      end_at_seconds   = p_end_at_seconds,
      sort_order       = coalesce(p_sort_order, 0)
    where id = p_id
    returning id into v_id;

    if v_id is null then
      return jsonb_build_object(
        'success', false,
        'error', 'OVERLAY_NOT_FOUND'
      );
    end if;
  end if;

  return jsonb_build_object(
    'success', true,
    'id', v_id
  );
end;
$$;


-- 3. Suppression d’un overlay TV
create or replace function app.app_admin_tv_delete_overlay(
  p_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = app, public
as $$
begin
  if not exists (
    select 1 from app.hero_overlays_tv ho
    where ho.id = p_id
  ) then
    return jsonb_build_object(
      'success', false,
      'error', 'OVERLAY_NOT_FOUND'
    );
  end if;

  delete from app.hero_overlays_tv
  where id = p_id;

  return jsonb_build_object(
    'success', true
  );
end;
$$;


-- 4. Créer un job de rendu TV pour un élément de playlist
create or replace function app.app_admin_tv_request_render(
  p_playlist_item_id uuid,
  p_meta jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = app, public
as $$
declare
  v_id uuid;
begin
  if not exists (
    select 1 from app.hero_playlist hp
    where hp.id = p_playlist_item_id
  ) then
    return jsonb_build_object(
      'success', false,
      'error', 'PLAYLIST_ITEM_NOT_FOUND'
    );
  end if;

  insert into app.hero_renders_tv (
    playlist_item_id,
    status,
    meta
  )
  values (
    p_playlist_item_id,
    'pending',
    coalesce(p_meta, '{}'::jsonb)
  )
  returning id into v_id;

  return jsonb_build_object(
    'success', true,
    'render_id', v_id
  );
end;
$$;
