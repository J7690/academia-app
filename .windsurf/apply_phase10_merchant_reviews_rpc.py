#!/usr/bin/env python3
"""Phase 10 — Create app_merchant_list_my_reviews RPC."""
import sys
import requests
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()

sql = """
CREATE OR REPLACE FUNCTION public.app_merchant_list_my_reviews(
  p_limit INT DEFAULT 30,
  p_offset INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_reviews JSONB;
  v_total INT;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT COUNT(*) INTO v_total
  FROM app.marketplace_reviews r
  JOIN app.marketplace_listings l ON l.id = r.listing_id
  JOIN app.marketplace_merchants mm ON mm.id = l.merchant_id
  WHERE mm.owner_user_id = v_user AND r.is_active = true;

  SELECT COALESCE(jsonb_agg(t), '[]'::jsonb) INTO v_reviews
  FROM (
    SELECT r.id, r.listing_id, r.rating, r.title AS review_title, r.content,
           r.is_verified_purchase, r.seller_reply, r.seller_replied_at,
           r.created_at,
           l.title AS listing_title,
           s.full_name AS buyer_name, s.avatar_url AS buyer_avatar
    FROM app.marketplace_reviews r
    JOIN app.marketplace_listings l ON l.id = r.listing_id
    JOIN app.marketplace_merchants mm ON mm.id = l.merchant_id
    LEFT JOIN app.students s ON s.id = r.buyer_id
    WHERE mm.owner_user_id = v_user AND r.is_active = true
    ORDER BY r.created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) t;

  RETURN jsonb_build_object(
    'success', true,
    'reviews', v_reviews,
    'total', v_total,
    'has_more', (p_offset + p_limit) < v_total
  );
END;
$$;
"""

resp = requests.post(
    m.url + "/rest/v1/rpc/admin_execute_sql",
    headers=m.headers,
    json={"p_sql": sql.strip()},
    timeout=30,
)
data = resp.json()
if isinstance(data, dict) and data.get("ok") is not False:
    sys.stdout.write("OK — app_merchant_list_my_reviews created\n")
else:
    err = data.get("error", str(data)[:200]) if isinstance(data, dict) else str(data)[:200]
    sys.stdout.write("ERROR: %s\n" % err)
