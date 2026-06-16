-- Inspection helpers (read-only)

-- Columns
SELECT table_name, column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'app'
  AND table_name IN (
    'merchant_profiles',
    'opportunity_inquiries',
    'opportunity_inquiry_messages',
    'opportunities'
  )
ORDER BY table_name, ordinal_position;

-- Foreign keys
SELECT
  tc.table_name,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name,
  tc.constraint_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'app'
  AND tc.table_name IN ('opportunity_inquiries', 'opportunity_inquiry_messages', 'opportunities')
ORDER BY tc.table_name, tc.constraint_name;
