REVOKE EXECUTE ON FUNCTION public.app_student_get_marketplace_order_detail(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.app_merchant_get_marketplace_order_detail(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_student_get_marketplace_order_detail(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_merchant_get_marketplace_order_detail(uuid) TO authenticated;
