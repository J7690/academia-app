#!/usr/bin/env python3
"""P0-1 + P0-1b : Corrige les RPCs communautés et DM.

Corrections :
1. app_student_list_community_posts : ajoute author_display_name + author_email
   via JOIN auth.users + app.students (utilise full_name, pas first_name/last_name)
2. app_student_list_direct_messages : corrige first_name||last_name → full_name
3. app_student_list_community_members : corrige first_name||last_name → full_name
4. app_student_list_dm_conversations : corrige first_name||last_name → full_name

Déploie via execute_sql (RPC admin).
"""

from __future__ import annotations

import json
import sys

import requests
from supabase_auto_manager import SupabaseAutoManager


def run_admin_sql(manager: SupabaseAutoManager, label: str, sql: str) -> bool:
    """Exécute du DDL via admin_execute_sql (supporte CREATE OR REPLACE)."""
    url = f"{manager.url}/rest/v1/rpc/admin_execute_sql"
    print(f"\n{'='*60}")
    print(f"DEPLOYING: {label}")
    print(f"{'='*60}")
    try:
        resp = requests.post(url, headers=manager.headers, json={"p_sql": sql}, timeout=30)
        if resp.status_code == 200:
            body = resp.json() if resp.text else {}
            if isinstance(body, dict) and body.get("ok") is False:
                print(f"  ❌ ERREUR SQL: {json.dumps(body, ensure_ascii=False)[:500]}")
                return False
            print(f"  ✅ OK (HTTP {resp.status_code})")
            return True
        else:
            print(f"  ❌ HTTP {resp.status_code}: {resp.text[:400]}")
            return False
    except Exception as e:
        print(f"  ❌ Exception: {e}")
        return False


# ── 1. app_student_list_community_posts : ajouter author_display_name + author_email ──

SQL_FIX_LIST_COMMUNITY_POSTS = """
CREATE OR REPLACE FUNCTION public.app_student_list_community_posts(
    p_community_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_member BOOLEAN;
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN '[]'::JSONB;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM app.community_memberships m
        WHERE m.community_id = p_community_id
          AND m.user_id = v_user_id
          AND m.is_active = TRUE
    ) INTO v_is_member;

    IF NOT v_is_member THEN
        RETURN '[]'::JSONB;
    END IF;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', p.id,
                'community_id', p.community_id,
                'author_id', p.author_id,
                'author_display_name', COALESCE(st.full_name, u.email),
                'author_email', u.email,
                'content', p.content,
                'type', p.type,
                'media_url', p.media_url,
                'reply_to_post_id', p.reply_to_post_id,
                'is_pinned', p.is_pinned,
                'is_deleted', p.is_deleted,
                'edited_at', p.edited_at,
                'created_at', p.created_at,
                'updated_at', p.updated_at,
                'reactions', (
                    SELECT COALESCE(
                        JSONB_AGG(
                            JSONB_BUILD_OBJECT(
                                'emoji', r.emoji,
                                'count', r.reaction_count,
                                'reacted_by_me', r.reacted_by_me
                            )
                        ),
                        '[]'::JSONB
                    )
                    FROM (
                        SELECT
                            r.emoji,
                            COUNT(*) AS reaction_count,
                            BOOL_OR(r.user_id = v_user_id) AS reacted_by_me
                        FROM app.community_post_reactions r
                        WHERE r.post_id = p.id
                        GROUP BY r.emoji
                    ) r
                )
            )
            ORDER BY p.created_at ASC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.community_posts p
    LEFT JOIN auth.users u ON u.id = p.author_id
    LEFT JOIN app.students st ON st.id = p.author_id
    WHERE p.community_id = p_community_id
      AND p.is_deleted = FALSE;

    RETURN v_result;
END;
$function$;
"""

# ── 2. app_student_list_direct_messages : corriger first_name||last_name → full_name ──

SQL_FIX_LIST_DIRECT_MESSAGES = """
CREATE OR REPLACE FUNCTION public.app_student_list_direct_messages(
  p_conversation_id UUID,
  p_limit INTEGER DEFAULT 50,
  p_before TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  v_conv RECORD;
  v_result JSONB;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT id, user_a, user_b INTO v_conv
    FROM app.direct_conversations
   WHERE id = p_conversation_id;

  IF v_conv IS NULL OR (v_uid != v_conv.user_a AND v_uid != v_conv.user_b) THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_participant');
  END IF;

  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at ASC), '[]'::jsonb)
  INTO v_result
  FROM (
    SELECT dm.id, dm.sender_id, dm.content, dm.type, dm.media_url,
           dm.reply_to_message_id, dm.is_deleted, dm.edited_at, dm.created_at,
           COALESCE(s.full_name, u.email) AS sender_display_name
      FROM app.direct_messages dm
      LEFT JOIN auth.users u ON u.id = dm.sender_id
      LEFT JOIN app.students s ON s.id = dm.sender_id
     WHERE dm.conversation_id = p_conversation_id
       AND dm.is_deleted = false
       AND (p_before IS NULL OR dm.created_at < p_before)
     ORDER BY dm.created_at DESC
     LIMIT LEAST(p_limit, 100)
  ) t;

  RETURN jsonb_build_object('success', true, 'messages', v_result);
END;
$function$;
"""

# ── 3. app_student_list_community_members : corriger first_name||last_name → full_name ──

SQL_FIX_LIST_COMMUNITY_MEMBERS = """
CREATE OR REPLACE FUNCTION public.app_student_list_community_members(
  p_community_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  v_is_member BOOLEAN;
  v_result JSONB;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM app.community_memberships
     WHERE community_id = p_community_id
       AND user_id = v_uid
       AND is_active = true
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_member');
  END IF;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'user_id', m.user_id,
      'role', m.role,
      'joined_at', m.joined_at,
      'is_banned', m.is_banned,
      'display_name', COALESCE(s.full_name, u.email),
      'email', u.email
    ) ORDER BY m.role DESC, m.joined_at ASC
  ), '[]'::jsonb)
  INTO v_result
  FROM app.community_memberships m
  LEFT JOIN auth.users u ON u.id = m.user_id
  LEFT JOIN app.students s ON s.id = m.user_id
  WHERE m.community_id = p_community_id
    AND m.is_active = true
    AND m.is_banned = false;

  RETURN jsonb_build_object('success', true, 'members', v_result);
END;
$function$;
"""

# ── 4. app_student_list_dm_conversations : corriger first_name||last_name → full_name ──

SQL_FIX_LIST_DM_CONVERSATIONS = """
CREATE OR REPLACE FUNCTION public.app_student_list_dm_conversations()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  v_result JSONB;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.last_message_at DESC NULLS LAST), '[]'::jsonb)
  INTO v_result
  FROM (
    SELECT c.id AS conversation_id,
           c.last_message_at,
           c.created_at,
           CASE WHEN c.user_a = v_uid THEN c.user_b ELSE c.user_a END AS other_user_id,
           COALESCE(s.full_name, u.email) AS other_display_name,
           u.email AS other_email,
           (SELECT dm.content FROM app.direct_messages dm
             WHERE dm.conversation_id = c.id AND dm.is_deleted = false
             ORDER BY dm.created_at DESC LIMIT 1) AS last_message_content,
           (SELECT dm.sender_id FROM app.direct_messages dm
             WHERE dm.conversation_id = c.id AND dm.is_deleted = false
             ORDER BY dm.created_at DESC LIMIT 1) AS last_message_sender_id,
           COALESCE(
             (SELECT COUNT(*) FROM app.direct_messages dm
               WHERE dm.conversation_id = c.id
                 AND dm.is_deleted = false
                 AND dm.sender_id != v_uid
                 AND dm.created_at > COALESCE(
                   (SELECT rs.last_read_at FROM app.direct_message_read_states rs
                     WHERE rs.conversation_id = c.id AND rs.user_id = v_uid),
                   '1970-01-01'::timestamptz
                 )
             ), 0
           )::int AS unread_count
      FROM app.direct_conversations c
      LEFT JOIN auth.users u ON u.id = (CASE WHEN c.user_a = v_uid THEN c.user_b ELSE c.user_a END)
      LEFT JOIN app.students s ON s.id = (CASE WHEN c.user_a = v_uid THEN c.user_b ELSE c.user_a END)
     WHERE c.user_a = v_uid OR c.user_b = v_uid
  ) t;

  RETURN jsonb_build_object('success', true, 'conversations', v_result);
END;
$function$;
"""


def main() -> int:
    manager = SupabaseAutoManager()

    fixes = [
        ("1. app_student_list_community_posts (ajouter author_display_name/email)", SQL_FIX_LIST_COMMUNITY_POSTS),
        ("2. app_student_list_direct_messages (full_name au lieu de first_name||last_name)", SQL_FIX_LIST_DIRECT_MESSAGES),
        ("3. app_student_list_community_members (full_name au lieu de first_name||last_name)", SQL_FIX_LIST_COMMUNITY_MEMBERS),
        ("4. app_student_list_dm_conversations (full_name au lieu de first_name||last_name)", SQL_FIX_LIST_DM_CONVERSATIONS),
    ]

    all_ok = True
    for label, sql in fixes:
        if not run_admin_sql(manager, label, sql):
            all_ok = False

    # ── Vérification post-déploiement ──
    print(f"\n{'='*60}")
    print("VÉRIFICATION POST-DÉPLOIEMENT")
    print(f"{'='*60}")

    checks = [
        ("app_student_list_community_posts", ["author_display_name", "author_email", "full_name"], ["first_name"]),
        ("app_student_list_direct_messages", ["full_name"], ["first_name"]),
        ("app_student_list_community_members", ["full_name"], ["first_name"]),
        ("app_student_list_dm_conversations", ["full_name"], ["first_name"]),
    ]

    for func_name, must_have, must_not_have in checks:
        print(f"\n--- {func_name} ---")
        r = manager.execute_sql_auto(f"""
        SELECT pg_catalog.pg_get_functiondef(p.oid) AS source
        FROM pg_catalog.pg_proc p
        JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
        WHERE p.proname = '{func_name}'
        """)
        if r.get("success") and r.get("data"):
            source = r["data"][0].get("source", "")
            for kw in must_have:
                present = kw in source
                print(f"  {kw}: {'✅' if present else '❌'}")
                if not present:
                    all_ok = False
            for kw in must_not_have:
                present = kw in source
                print(f"  {kw} (doit être absent): {'❌ ENCORE PRÉSENT' if present else '✅ absent'}")
                if present:
                    all_ok = False
        else:
            print(f"  ⚠️ Impossible de vérifier")

    print(f"\n{'='*60}")
    if all_ok:
        print("✅ TOUTES LES CORRECTIONS DÉPLOYÉES ET VÉRIFIÉES")
    else:
        print("⚠️ CERTAINES CORRECTIONS ONT ÉCHOUÉ OU NE SONT PAS VÉRIFIÉES")
    print(f"{'='*60}")

    return 0 if all_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
