# BOBODO_WS_REAL_TEST

## Mission 3 — Test avec vrai client WebSocket


### Script de test écrit sur /tmp/test_ws.py

**Exit code:** 0
**STDOUT:**
```

--- Testing localhost_ws: ws://localhost:8000/ws ---
CONNECTED to ws://localhost:8000/ws
Sent session_id
Sent ping
Received: {"type": "pong"}
Result localhost_ws: SUCCESS

--- Testing localhost_ws_query: ws://localhost:8000/ws?session_id=test ---
CONNECTED to ws://localhost:8000/ws?session_id=test
Sent session_id
Sent ping
Received: {"type": "pong"}
Result localhost_ws_query: SUCCESS

--- Testing 127_ws: ws://127.0.0.1:8000/ws ---
CONNECTED to ws://127.0.0.1:8000/ws
Sent session_id
Sent ping
Received: {"type": "pong"}
Result 127_ws: SUCCESS

--- Testing public_ws: ws://185.167.97.144:8000/ws ---
CONNECTED to ws://185.167.97.144:8000/ws
Sent session_id
Sent ping
Received: {"type": "pong"}
Result public_ws: SUCCESS

```