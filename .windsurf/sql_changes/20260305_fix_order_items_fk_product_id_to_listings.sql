-- Fix schema mismatch:
-- Flutter cart + listings use marketplace_listings.id as the purchasable item ID.
-- But app.marketplace_order_items.product_id currently FK references app.marketplace_products(id),
-- causing checkout to fail when inserting listing ids.
--
-- This patch repoints the FK to app.marketplace_listings(id) while keeping the column name product_id
-- (to avoid breaking existing code that expects product_id in order_items).

ALTER TABLE app.marketplace_order_items
  DROP CONSTRAINT IF EXISTS marketplace_order_items_product_id_fkey;

ALTER TABLE app.marketplace_order_items
  ADD CONSTRAINT marketplace_order_items_product_id_fkey
  FOREIGN KEY (product_id)
  REFERENCES app.marketplace_listings(id)
  ON DELETE RESTRICT;
