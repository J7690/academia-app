SELECT u.id, u.email, u.created_at, u.last_sign_in_at,
       (SELECT COUNT(*) FROM app.user_device_tokens t WHERE t.user_id = u.id) AS device_tokens,
       (SELECT COUNT(*) FROM app.user_device_tokens t WHERE t.user_id = u.id AND t.is_active = TRUE) AS active_tokens,
       (SELECT COUNT(*) FROM app.notification_events n WHERE n.user_id = u.id) AS notification_events,
       (SELECT COUNT(*) FROM app.notification_events n WHERE n.user_id = u.id AND n.processed_at IS NULL) AS pending_events
FROM auth.users u WHERE u.email = 'gourmaserre@gmail.com'
