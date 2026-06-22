# BOBODO_MINIMAL_REMEDIATION_PLAN

## Mission 5 — Roadmap minimale (maximum de gain, minimum de changements)

---

### Date
2026-06-13

---

### Question

Quel est le **plus petit ensemble de modifications** permettant :
1. Isolation des sessions
2. Correction du buffer global
3. Réduction majeure de la latence

**Sans ajouter de nouvelles fonctionnalités.**

---

### Analyse des gains vs complexité

| Patch | Complexité | Gain | Ratio gain/complexité |
|---|---|---|---|
| Isolation multi-session (1.1) | Haute | Bloquant → Fonctionnel | Infini (0→1) |
| Cleanup (1.2) | Faible | Stabilité | Haut |
| Thread pool (1.4) | Moyenne | 1→4 users simultanés | Moyen |
| Bug modèle (1.6) | Faible | Active tiny | Très haut |
| Passage tiny (2.1) | Faible | 6-8x plus rapide | Très haut |
| Silence 300ms (1.5) | Faible | -700 ms | Haut |
| beam_size=1 (2.2) | Faible | 3-5x plus rapide | Très haut |

---

### Roadmap minimale identifiée

**4 patches seulement** suffisent pour résoudre les 3 objectifs :

#### Étape 1 : Correction bug modèle (1.6) — 30 minutes

**Quoi :** `main.py` passe les paramètres `.env` à `STTService()`.

**Pourquoi minimal :** 2 lignes de code. Active le contrôle du modèle sans toucher à l'architecture.

```python
# main.py:56 (AVANT)
stt_service = STTService()

# main.py:56 (APRÈS)
stt_service = STTService(
    model_size=settings.whisper_model,
    device=settings.whisper_device,
    compute_type=settings.whisper_quantization
)
```

**Gain :** Permet de changer de modèle via `.env` sans modifier le code.

---

#### Étape 2 : Passage modèle medium → tiny (2.1) — 5 minutes

**Quoi :** Modifier `.env` :

```
WHISPER_MODEL=tiny
```

**Redémarrer le service.**

**Pourquoi minimal :** Aucun changement de code (si Étape 1 faite). Juste une variable d'environnement.

**Gain :** **~6-8x plus rapide** (estimation théorique : 8.3s → 1.5s).

**Risque :** Perte de précision. Si inacceptable, retour à `base` ou `small` via `.env`.

---

#### Étape 3 : Isolation multi-session (1.1) — 2-3 jours

**Quoi :** Remplacer le `audio_buffer` global par un `dict` de `SessionState`.

**Pourquoi minimal (mais obligatoire) :** C'est le seul patch qui demande un refactor significatif. Mais sans lui, le multi-user reste impossible.

**Code minimal (concept) :**

```python
@dataclass
class SessionState:
    session_id: str
    audio_buffer: bytearray
    last_audio_time: float
    callback: Callable
    lock: asyncio.Lock

class STTService:
    def __init__(self):
        self.sessions: dict[str, SessionState] = {}
        self.model = WhisperModel(...)  # Partagé

    def get_or_create_session(self, session_id, callback):
        if session_id not in self.sessions:
            self.sessions[session_id] = SessionState(session_id, bytearray(), 0, callback, asyncio.Lock())
        return self.sessions[session_id]

    async def transcribe(self, session_id, audio_bytes):
        session = self.sessions.get(session_id)
        if not session:
            return
        async with session.lock:
            session.audio_buffer.extend(audio_bytes)
            session.last_audio_time = time.time()
```

**Gain :** 0% mélange, base du multi-user.

---

#### Étape 4 : Cleanup + Limite buffer (1.2 + 1.3) — 2 heures

**Quoi :** `destroy_session()` + `MAX_BUFFER_SIZE`.

**Pourquoi minimal :** Extensions naturelles de l'Étape 3. Sans cleanup, la fuite mémoire tue le serveur.

```python
# websocket_handler.py
async def handle(self):
    await self.websocket.accept()
    try:
        self.stt_service.get_or_create_session(self.session_id, ...)
        ...
    finally:
        self.stt_service.destroy_session(self.session_id)

# stt_service.py
MAX_BUFFER_SIZE = 5 * 1024 * 1024

async def transcribe(self, session_id, audio_bytes):
    session = self.sessions.get(session_id)
    if len(session.audio_buffer) + len(audio_bytes) > MAX_BUFFER_SIZE:
        session.audio_buffer.clear()
        raise BufferOverflow("Audio buffer exceeded 5MB")
    ...
```

**Gain :** Stabilité mémoire, sécurité DoS.

---

### Ce qui est EXCLU de la roadmap minimale

| Patch exclu | Pourquoi exclu |
|---|---|
| Thread pool (1.4) | Complexité moyenne, dépend de CTranslate2 thread-safe. Gain limité si tiny déjà rapide (< 2s). |
| beam_size=1 (2.2) | Gain théorique 3-5x, mais risque qualité. À tester séparément après tiny. |
| Silence 300ms (1.5) | Gain -700ms, mais risque de découpe précoce. Pas bloquant. |
| Heartbeat (2.4) | Stabilité WS, mais pas lié aux 3 objectifs (isolation/buffer/latence). |
| BytesIO (2.3) | Gain négligeable (-50ms sur 8000ms). |

---

### Comparaison : Master Plan vs Minimal

| Aspect | Master Plan (10 jours) | Plan minimal (3-4 jours) |
|---|---|---|
| Patches | 10+ | 4 |
| Latence STT | ~1.5s (tiny + beam_size=1 + silence 300ms) | ~1.5s-2s (tiny seul) |
| Isolation | ✅ | ✅ |
| Multi-user | 50 users (estimé) | 10-20 users (estimé, sans thread pool) |
| Cleanup | ✅ | ✅ |
| Monitoring | Dashboard + alertes | Logs seuls |

**Écart :** Le plan minimal résout les 3 objectifs avec 60% moins de travail. Il perd le thread pool (parallélisme limité) et les optimisations marginales.

---

### Séquence d'exécution minimale

```
Jour 1  : Étape 1 (bug modèle) + Étape 2 (tiny) = test immédiat
Jour 2-3: Étape 3 (isolation multi-session)
Jour 4  : Étape 4 (cleanup + limite) + tests 5 users
```

**Total : 3-4 jours.**

---

### Validation du plan minimal

| Critère | Test | Seuil |
|---|---|---|
| Isolation | 5 users, phrases différentes | 0% mélange |
| Buffer corrigé | Déconnexion/reconnexion | 0% audio résiduel |
| Latence | 10 transcriptions | < 3s (tiny) |
| Stabilité | 10 min 5 users connectés | 0% crash |

Si ces 4 tests passent → le plan minimal est validé.
