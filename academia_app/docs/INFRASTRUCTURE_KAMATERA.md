# Infrastructure Kamatera — Academia Learning Engine

## Serveur LiveKit

| Paramètre | Valeur |
|-----------|--------|
| IP | 185.167.97.144 |
| WebSocket | ws://185.167.97.144:7880 |
| HTTP API | http://185.167.97.144:7880 |
| Redis | 127.0.0.1:6379 (local) |
| Nginx | http://185.167.97.144 |
| API Key | `APIKeylrmgQYJgiEZa` |
| Installé le | 2026-06-07 |

## Architecture réseau

```
┌─────────────────────────────────────────────────────────────┐
│ Flutter App (Mobile/Web/Desktop)                            │
└──────────┬──────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────┐     ┌────────────────────────────────┐
│ Supabase Cloud       │     │ Kamatera VPS (LiveKit)         │
│ ─ Auth               │     │ ─ LiveKit Server :7880         │
│ ─ PostgreSQL         │     │ ─ Redis :6379                  │
│ ─ Edge Functions     │◄───►│ ─ Nginx :80                    │
│ ─ Storage            │     │ ─ Egress (recording → S3)      │
│ ─ Realtime           │     └────────────────────────────────┘
└──────────────────────┘

Flow connexion :
1. Client → Supabase Edge Function `livekit-token` → JWT
2. Client → LiveKit ws://185.167.97.144:7880 avec JWT
3. LiveKit Egress → Supabase Storage (replay_url)
```

## Secrets Supabase requis

```bash
supabase secrets set LIVEKIT_API_KEY=APIKeylrmgQYJgiEZa
supabase secrets set LIVEKIT_API_SECRET=uXu7tiObNgaLkYA3VydinjsKRzPJjL8SNWC9pRx8
supabase secrets set LIVEKIT_URL=ws://185.167.97.144:7880
supabase secrets set OPENROUTER_API_KEY=<your_key>
```

## Edge Functions à déployer

```bash
supabase functions deploy livekit-token
supabase functions deploy livekit-recording
supabase functions deploy academia-ai-assistant
```

## Monitoring

- LiveKit Dashboard : http://185.167.97.144:7880
- Nginx status : http://185.167.97.144/status
- pg_cron jobs : 
  - `purge_deleted_accounts` (quotidien 3h)
  - `expire_subscriptions` (quotidien 2h)
  - `reset_stale_processing_payments` (30min)
  - `prep-feed-actuality` (quotidien 5h)
  - `app_learning_presence_cleanup` (à configurer, recommandé toutes les 5min)

## Capacité estimée

- **LiveKit** : ~50 participants simultanés par room, ~10 rooms simultanées
- **Recording** : egress composites, stockage Supabase Storage
- **Bande passante** : 100 Mbps (Kamatera standard)

## Procédure de maintenance

1. SSH : `ssh root@185.167.97.144`
2. LiveKit logs : `journalctl -u livekit-server -f`
3. Restart : `systemctl restart livekit-server`
4. Redis flush (si nécessaire) : `redis-cli FLUSHALL`
