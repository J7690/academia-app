-- Audit: identify listings/cart merchant owner user_ids missing in app.marketplace_merchants

-- 1) Columns nullability for app.marketplace_merchants
SELECT
  c.column_name,
  c.data_type,
  c.is_nullable,
  c.column_default
FROM information_schema.columns c
WHERE c.table_schema = 'app'
  AND c.table_name = 'marketplace_merchants'
ORDER BY c.ordinal_position;

-- 2) Constraints (PK/UNIQUE/FK/CHECK) for app.marketplace_merchants
SELECT
  con.conname AS constraint_name,
  con.contype AS constraint_type,
  pg_get_constraintdef(con.oid) AS definition
FROM pg_constraint con
JOIN pg_class rel ON rel.oid = con.conrelid
JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
WHERE nsp.nspname = 'app'
  AND rel.relname = 'marketplace_merchants'
ORDER BY con.conname;

-- 3) Merchant owner user_ids referenced by listings but missing in marketplace_merchants
SELECT
  l.merchant_id AS merchant_owner_user_id,
  COUNT(*) AS listings_count,
  MAX(l.created_at) AS latest_listing_at
FROM app.marketplace_listings l
LEFT JOIN app.marketplace_merchants m
  ON m.owner_user_id = l.merchant_id
WHERE l.merchant_id IS NOT NULL
  AND m.id IS NULL
GROUP BY l.merchant_id
ORDER BY latest_listing_at DESC
LIMIT 50;

-- 4) Merchant owner user_ids referenced by the current user's cart but missing in marketplace_merchants
-- (uses auth.uid() so run as authenticated context may differ; still useful under SECURITY DEFINER contexts)
SELECT
  l.merchant_id AS merchant_owner_user_id,
  COUNT(*) AS cart_items_count
FROM app.marketplace_carts c
JOIN app.marketplace_cart_items i ON i.cart_id = c.id
JOIN app.marketplace_listings l ON l.id = i.listing_id
LEFT JOIN app.marketplace_merchants m ON m.owner_user_id = l.merchant_id
WHERE c.user_id = auth.uid()
  AND c.status = 'open'
  AND m.id IS NULL
GROUP BY l.merchant_id
LIMIT 50;

-- 5) Merchant profile info for missing merchants (if merchant_profiles uses user_id)
SELECT
  mp.user_id,
  mp.display_name,
  mp.is_active,
  mp.is_verified
FROM app.merchant_profiles mp
WHERE mp.user_id IN (
  SELECT l.merchant_id
  FROM app.marketplace_listings l
  LEFT JOIN app.marketplace_merchants m ON m.owner_user_id = l.merchant_id
  WHERE l.merchant_id IS NOT NULL
    AND m.id IS NULL
  GROUP BY l.merchant_id
)
ORDER BY mp.display_name;
