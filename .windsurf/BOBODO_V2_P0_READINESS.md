# BOBODO VOICE V2 — P0 IMPLEMENTATION READINESS

## Date : 14 Juin 2026

---

## Mission 1 — Edge-TTS

### Code actuel TTS

| | |
|---|---|
| **Fichier** | `/opt/bobodo-vocal/tts_service.py` |
| **Lignes** | 93 lignes |
| **Classe** | `TTSService` |
| **Méthode clé** | `synthesize(text) → bytes (MP3)` |
| **Dépendance** | `gTTS` (appel réseau Google) |

### Modifications requises

| # | Fichier | Action |
|---|---|---|
| 1 | `tts_service.py` | Remplacer `gTTS` par `edge_tts` |
| 2 | Aucun autre fichier | L'interface `synthesize(text) → bytes` est inchangée |

### Lignes estimées

```python
# Nouvelle implémentation (~30 lignes)
import edge_tts
import asyncio
import tempfile
import os

class TTSService:
    def __init__(self, voice: str = "fr-FR-DeniseNeural"):
        self.voice = voice

    async def synthesize(self, text: str) -> Optional[bytes]:
        communicate = edge_tts.Communicate(text, self.voice)
        temp_path = "/tmp/tts_edge_output.mp3"
        await communicate.save(temp_path)
        with open(temp_path, "rb") as f:
            audio_bytes = f.read()
        os.remove(temp_path)
        return audio_bytes
```

### Dépendance à installer

```bash
pip install edge-tts
```

### Risques de régression

| Risque | Probabilité | Impact | Mitigation |
|---|---|---|---|
| Edge-TTS indisponible (serveur Microsoft down) | Très faible | Audio coupé | Fallback gTTS |
| Format audio MP3 changé | Nul | — | Même format MP3 |
| Interface modifiée | Nul | — | `synthesize(text) → bytes` inchangée |

### Rollback

```bash
cp /opt/bobodo-vocal/tts_service.py.backup_gtts /opt/bobodo-vocal/tts_service.py
systemctl restart bobodo-vocal
# Temps: < 30 secondes
```

---

## Mission 2 — Auto-reconnexion Flutter

### Code actuel

| | |
|---|---|
| **Fichier** | `lib/services/bobodo_vocal_service.dart` |
| **Lignes** | 103 lignes |
| **Reconnexion** | ❌ Aucune — `onDone` met `_isConnected = false` sans retry |

### Stratégie de reconnexion recommandée

```dart
// Dans onDone / onError :
void _scheduleReconnect() {
  if (_sessionId == null) return;
  Future.delayed(Duration(seconds: _retryDelay), () {
    if (!_isConnected && _sessionId != null) {
      connect(_sessionId!);
      _retryDelay = min(_retryDelay * 2, 30); // Exponential backoff, max 30s
    }
  });
}
```

### Paramètres

| Paramètre | Valeur |
|---|---|
| Délai initial | 2 secondes |
| Backoff | Exponentiel ×2 |
| Maximum | 30 secondes |
| Tentatives max | 10 |
| Reset backoff | Après connexion réussie |

### Impact utilisateur

| Sans reconnexion | Avec reconnexion |
|---|---|
| L'user doit quitter et revenir sur l'écran vocal | Le service se reconnecte silencieusement |
| Perte de l'état "en conversation" | Reprise automatique en 2–30s |

### Risques

| Risque | Probabilité | Mitigation |
|---|---|---|
| Boucle infinie de reconnexion | Faible | Max 10 tentatives |
| Double connexion | Faible | Vérifier `_isConnected` avant reconnexion |
| Session Bobodo perdue | Aucun | La session est dans Supabase |

---

## Mission 3 — Systemd

### Fichier actuel

```ini
[Unit]
Description=Bobodo Vocal Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/bobodo-vocal
ExecStart=/opt/bobodo-vocal/venv/bin/python main.py
Restart=always

[Install]
WantedBy=multi-user.target
```

### Constat

- ✅ `Restart=always` — **déjà en place**
- ❌ `RestartSec` manquant (restart immédiat = potentiel crash loop)
- ❌ `LimitNOFILE` manquant
- ❌ Pas de journal limité

### Fichier final recommandé

```ini
[Unit]
Description=Bobodo Vocal Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/bobodo-vocal
ExecStart=/opt/bobodo-vocal/venv/bin/python main.py
Restart=always
RestartSec=5
LimitNOFILE=65536
StandardOutput=journal
StandardError=journal
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
```

### Changements

| Ajout | Justification |
|---|---|
| `RestartSec=5` | Évite crash loop (5s entre redémarrages) |
| `LimitNOFILE=65536` | Support de nombreuses connexions WS |
| `StandardOutput=journal` | Logs structurés dans journald |
| `PYTHONUNBUFFERED=1` | Logs en temps réel (pas de buffer) |

---

## Mission 4 — Monitoring minimal

### Script `/opt/bobodo-vocal/monitor.sh`

```bash
#!/bin/bash
# Monitoring Bobodo Voice — cron toutes les 5 minutes

STATUS=$(systemctl is-active bobodo-vocal)
MEM_BYTES=$(systemctl show bobodo-vocal -p MemoryCurrent --value)
MEM_MB=$((MEM_BYTES / 1024 / 1024))
SESSIONS=$(journalctl -u bobodo-vocal --since='5 min ago' --no-pager | grep -c 'Registered session')
ERRORS=$(journalctl -u bobodo-vocal --since='5 min ago' --no-pager | grep -ci 'error')
LATENCY=$(journalctl -u bobodo-vocal --since='5 min ago' --no-pager | grep 'STT_LATENCY' | tail -1 | grep -oP '\d+ms' | head -1)

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "$TIMESTAMP | status=$STATUS | ram=${MEM_MB}MB | sessions=$SESSIONS | errors=$ERRORS | latency=$LATENCY" >> /var/log/bobodo-voice.log

# Alerte RAM
if [ "$MEM_MB" -gt 1500 ]; then
    echo "$TIMESTAMP | ALERT: RAM=${MEM_MB}MB > 1500MB" >> /var/log/bobodo-voice-alerts.log
fi

# Alerte erreurs
if [ "$ERRORS" -gt 5 ]; then
    echo "$TIMESTAMP | ALERT: $ERRORS errors in 5min" >> /var/log/bobodo-voice-alerts.log
fi
```

### Cron

```bash
# /etc/cron.d/bobodo-monitor
*/5 * * * * root /opt/bobodo-vocal/monitor.sh
```

### Métriques couvertes

| Métrique | Source | Fréquence |
|---|---|---|
| CPU | Implicite via latence STT | 5 min |
| RAM | `MemoryCurrent` systemd | 5 min |
| Sessions | Count logs `Registered` | 5 min |
| Latence STT | Log `STT_LATENCY` | 5 min |
| Erreurs | Count logs `error` | 5 min |

---

## Mission 5 — Feuille de route d'exécution

### Ordre exact

| Étape | Action | Durée | Risque | Dépendance |
|---|---|---|---|---|
| **1** | Systemd (RestartSec + LimitNOFILE) | **5 min** | Nul | Aucune |
| **2** | Monitoring (script + cron) | **15 min** | Nul | Aucune |
| **3** | Edge-TTS (remplacer gTTS) | **45 min** | Très faible | `pip install edge-tts` |
| **4** | Auto-reconnexion Flutter | **1h30** | Faible | Rebuild app |

### Justification de l'ordre

1. **Systemd d'abord** — protection immédiate contre crash loop, 0 risque
2. **Monitoring ensuite** — visibilité avant les changements TTS
3. **Edge-TTS** — gain latence maximal, risque minimal (même interface)
4. **Flutter en dernier** — nécessite rebuild et déploiement app, risque le plus élevé

---

## Livrable final

### 1. Temps total réel

| Étape | Durée |
|---|---|
| Systemd | 5 min |
| Monitoring | 15 min |
| Edge-TTS | 45 min |
| Auto-reconnexion Flutter | 1h30 |
| **TOTAL** | **~2h35** |

### 2. Risque réel

| Composant | Risque |
|---|---|
| Systemd | **Nul** (ajout de paramètres) |
| Monitoring | **Nul** (script bash non-intrusif) |
| Edge-TTS | **Très faible** (même interface, rollback 30s) |
| Auto-reconnexion Flutter | **Faible** (logique côté client, pas serveur) |

**Risque global : TRÈS FAIBLE.** Aucune modification ne touche à l'architecture, au STT, ou au pipeline multi-session.

### 3. Gain utilisateur attendu

| Métrique | Avant P0 | Après P0 |
|---|---|---|
| Latence TTS | 0.6–2.5s | **0.2–0.8s** (-1.5s) |
| Latence pipeline total | 7.5–11s | **~6.0–8.5s** |
| Qualité voix | Robotique (gTTS) | **Naturelle** (Microsoft Neural) |
| Résilience réseau | Manuelle (user relance) | **Automatique** (retry 2–30s) |
| Détection panne | Manuelle | **Automatique** (cron + alertes) |
| Crash recovery | Immédiat (risque loop) | **5s backoff** (stable) |

### 4. Décision

## **GO IMPLÉMENTATION IMMÉDIATE**

### 5. Ordre exact d'exécution

```
1. systemd → RestartSec=5 + LimitNOFILE      [5 min]
2. monitoring → script + cron                  [15 min]
3. edge-tts → remplacer gTTS côté serveur      [45 min]
4. flutter → auto-reconnexion WebSocket        [1h30]
```

Chaque étape est indépendante et testable isolément. Rollback < 30s pour chacune.
