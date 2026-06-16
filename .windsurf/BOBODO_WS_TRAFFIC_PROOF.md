# BOBODO_WS_TRAFFIC_PROOF

## Mission 4 — Test audio + capture logs


### Test d'envoi audio exécuté
**Exit code:** 0
**STDOUT:**
```
Connecting to ws://localhost:8000/ws
CONNECTED
Sent session_id
Sent fake audio (3200 bytes)
Timeout waiting for msg 0
Closing...

```

### Logs journalctl du service (30 dernières lignes)
**STDOUT:**
```
Jun 12 21:19:21 academia00 python[125021]: 2026-06-12 21:19:21,548 - websocket_handler - INFO - WebSocket connection established
Jun 12 21:19:21 academia00 python[125021]: INFO:     connection open
Jun 12 21:19:21 academia00 python[125021]: 2026-06-12 21:19:21,550 - websocket_handler - INFO - Session ID set: test-session-123
Jun 12 21:19:21 academia00 python[125021]: 2026-06-12 21:19:21,551 - websocket_handler - INFO - WebSocket connection closed
Jun 12 21:19:21 academia00 python[125021]: INFO:     connection closed
Jun 12 21:19:21 academia00 python[125021]: 2026-06-12 21:19:21,606 - stt_service - INFO - [STT_CALLBACK] Transcription callback registered
Jun 12 21:19:21 academia00 python[125021]: INFO:     ('127.0.0.1', 54368) - "WebSocket /ws" [accepted]
Jun 12 21:19:21 academia00 python[125021]: 2026-06-12 21:19:21,607 - websocket_handler - INFO - WebSocket connection established
Jun 12 21:19:21 academia00 python[125021]: INFO:     connection open
Jun 12 21:19:21 academia00 python[125021]: 2026-06-12 21:19:21,608 - websocket_handler - INFO - Session ID set: test-session-123
Jun 12 21:19:21 academia00 python[125021]: 2026-06-12 21:19:21,609 - websocket_handler - INFO - WebSocket connection closed
Jun 12 21:19:21 academia00 python[125021]: INFO:     connection closed
Jun 12 21:19:21 academia00 python[125021]: 2026-06-12 21:19:21,664 - stt_service - INFO - [STT_CALLBACK] Transcription callback registered
Jun 12 21:19:21 academia00 python[125021]: INFO:     ('185.167.97.144', 56834) - "WebSocket /ws" [accepted]
Jun 12 21:19:21 academia00 python[125021]: 2026-06-12 21:19:21,664 - websocket_handler - INFO - WebSocket connection established
Jun 12 21:19:21 academia00 python[125021]: INFO:     connection open
Jun 12 21:19:21 academia00 python[125021]: 2026-06-12 21:19:21,666 - websocket_handler - INFO - Session ID set: test-session-123
Jun 12 21:19:21 academia00 python[125021]: 2026-06-12 21:19:21,666 - websocket_handler - INFO - WebSocket connection closed
Jun 12 21:19:21 academia00 python[125021]: INFO:     connection closed
Jun 12 21:21:08 academia00 python[125021]: 2026-06-12 21:21:08,820 - stt_service - INFO - [STT_CALLBACK] Transcription callback registered
Jun 12 21:21:08 academia00 python[125021]: INFO:     ('127.0.0.1', 59220) - "WebSocket /ws" [accepted]
Jun 12 21:21:08 academia00 python[125021]: 2026-06-12 21:21:08,820 - websocket_handler - INFO - WebSocket connection established
Jun 12 21:21:08 academia00 python[125021]: INFO:     connection open
Jun 12 21:21:08 academia00 python[125021]: 2026-06-12 21:21:08,822 - websocket_handler - INFO - Session ID set: audit-test-12345
Jun 12 21:21:08 academia00 python[125021]: 2026-06-12 21:21:08,822 - websocket_handler - INFO - [WS_AUDIO_RECEIVED] Audio decoded: 3200 bytes
Jun 12 21:21:08 academia00 python[125021]: 2026-06-12 21:21:08,822 - stt_service - INFO - [STT_AUDIO_RECEIVED] Audio received: 3200 bytes
Jun 12 21:21:08 academia00 python[125021]: 2026-06-12 21:21:08,822 - stt_service - INFO - [STT_BUFFER] Buffer size: 3200 bytes, Duration: 0.10s
Jun 12 21:21:09 academia00 python[125021]: 2026-06-12 21:21:09,822 - stt_service - INFO - [STT_SILENCE_CANCELLED] New audio received (1000ms < 1000ms)
Jun 12 21:21:11 academia00 python[125021]: 2026-06-12 21:21:11,826 - websocket_handler - INFO - WebSocket connection closed
Jun 12 21:21:11 academia00 python[125021]: INFO:     connection closed

```

### Logs filtrés sur 'audit-test-12345'
**STDOUT:**
```
Jun 12 21:21:08 academia00 python[125021]: 2026-06-12 21:21:08,822 - websocket_handler - INFO - Session ID set: audit-test-12345

```