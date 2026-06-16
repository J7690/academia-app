# BOBODO_STT_REMEDIATION_MASTER_PLAN

## Plan de remédiation complet — Bobodo Voice

**Date :** 2026-06-13

**Résumé :** 6 blocages établis par les audits. Ce document propose le plan technique complet, chiffré et priorisé.

| Rang | Blocage | Gravité | Correctif principal | Gain estimé |
|---|---|---|---|---|
| 1 | Architecture single-user | CRITIQUE | Refonte multi-session | 50-100 users |
| 2 | Latence STT 10s | CRITIQUE | Modèle + paramètres | 5-15x plus rapide |
| 3 | Buffer non sécurisé | MAJEUR | Cleanup + limites | Stabilité |
| 4 | Bug paramètre modèle | MAJEUR | Correction main.py:56 | Active tiny |
| 5 | Silence threshold 1000ms | MINEUR | Réduction à 300ms | -700ms |
| 6 | Sous-utilisation CPU | MINEUR | Thread pool | 2-3x parallèle |

---

## Mission 1 — Analyse d'impact du correctif multi-utilisateur

### 1.1 `audio_buffer` global partagé
- **Fichier :** `stt_service.py` / **Ligne :** 30
- **Code :** `self.audio_buffer = bytearray()`
- **Risque :** Toutes les connexions écrivent dans le même buffer. Audio de A mélangé avec B.
- **Preuve :** 5 users → transcription des 5 phrases mélangées.
- **Correctif :** `self.sessions: dict[str, SessionState]` où `SessionState.audio_buffer` est isolé par `session_id`.

### 1.2 Callback de transcription unique et écrasable
- **Fichier :** `websocket_handler.py` / **Ligne :** 29
- **Code :** `self.stt_service.set_transcription_callback(self._on_transcription_complete)`
- **Risque :** Chaque nouvelle connexion écrase le callback précédent. Seul le dernier connecté reçoit les résultats.
- **Preuve :** 4/5 users timeout à 35s car callback écrasé.
- **Correctif :** Callback stocké dans `SessionState`, pas dans `STTService`.

### 1.3 Instance STTService unique au processus
- **Fichier :** `main.py` / **Ligne :** 56
- **Code :** `stt_service = STTService()` (variable globale)
- **Risque :** Une seule instance gère tous les users. Pas de séparation des contextes.
- **Correctif :** Conserver une instance unique mais refactorer l'intérieur pour gérer plusieurs sessions. Le modèle Whisper (1.5 GB) reste partagé car thread-safe en lecture seule.

### 1.4 Pas de nettoyage à la déconnexion
- **Fichier :** `websocket_handler.py` / **Ligne :** 52
- **Code :** `except WebSocketDisconnect: logger.info("WebSocket connection closed")` — aucun cleanup
- **Risque :** L'audio reste coincé dans le buffer. Prochaine connexion reçoit l'audio résiduel.
- **Preuve :** Test 1 : 104 448 bytes résiduels + 76 032 nouveaux = 180 480 bytes accumulés.
- **Correctif :** Ajouter `self.stt_service.destroy_session(self.session_id)` dans un bloc `finally`.

### 1.5 Pas de limite de taille sur le buffer
- **Fichier :** `stt_service.py` / **Ligne :** ~166 (`self.audio_buffer.extend(audio_bytes)`)
- **Risque :** Un utilisateur malveillant peut saturer la RAM en envoyant de l'audio infini.
- **Correctif :** `MAX_BUFFER_SIZE = 5 * 1024 * 1024` (5 MB). Rejeter si dépassé.

### 1.6 Transcription séquentielle bloquante
- **Fichier :** `stt_service.py` / **Ligne :** 235-240
- **Code :** `segments, info = self.model.transcribe(...)` appelé dans la boucle asyncio principale
- **Risque :** `model.transcribe()` est synchrone et CPU-intensif (9s). La boucle asyncio est bloquée. Aucun autre user ne peut envoyer d'audio.
- **Preuve :** 3 users simultanés = 100% timeout.
- **Correctif :** Exécuter dans `ThreadPoolExecutor(max_workers=4)` (un worker par cœur).

### 1.7 Silence threshold global non configurable
- **Fichier :** `stt_service.py` / **Ligne :** 33
- **Code :** `self.silence_threshold_ms = 1000`
- **Risque :** Ajoute 1s de latence artificielle par requête.
- **Preuve :** 1001 ms = 10% de la latence totale.
- **Correctif :** Réduire à 300 ms. Rendre configurable via `.env`.

---

## Mission 2 — Architecture cible multi-session

### 2.1 Diagramme logique

```
Processus Python
├── SessionManager (dict)
│   sessions = {
│     "sess-A": SessionState(buffer, callback, websocket, lock),
│     "sess-B": SessionState(...),
│     ...
│   }
│
├── ThreadPoolExecutor (4 workers)
│   worker-1: transcribe(sess-A)
│   worker-2: transcribe(sess-B)
│   ...
│
└── Model Whisper (medium/tiny) — PARTAGÉ, thread-safe
```

### 2.2 Cycle de vie d'une session

```
[WS CONNECT] → SessionState créé dans SessionManager
[AUDIO]      → buffer.extend(audio) + reset silence timer
[SILENCE]    → Soumet au ThreadPoolExecutor
[TRANSCRIBE] → model.transcribe() dans worker
[CALLBACK]   → Résultat envoyé à LA BONNE session
[DISCONNECT] → cleanup_session() : buffer.clear(), remove from dict
```

### 2.3 Structure des objets mémoire

```python
@dataclass
class SessionState:
    session_id: str
    audio_buffer: bytearray
    websocket: WebSocket
    last_audio_time: float
    transcription_callback: Callable
    lock: asyncio.Lock
    is_transcribing: bool

class STTService:
    def __init__(self, ...):
        self.sessions: dict[str, SessionState] = {}
        self.executor = ThreadPoolExecutor(max_workers=4)
        self.model = WhisperModel(...)  # Partagé
```

### 2.4 Objectifs de charge

| Objectif | Sessions simultanées | Justification |
|---|---|---|
| **Minimal** | 50 | 4 workers × activité sporadique = ~50 sessions actives |
| **Recommandé** | 100 | Avec tiny model (moins RAM) et queue async = 100 sessions viables |

---

## Mission 3 — Réduction de la latence STT

### 3.1 Décomposition actuelle (audio 4.99s)

| Étape | Durée | % | Source |
|---|---|---|---|
| Réception WS + buffer | ~5 ms | <0.1% | Logs |
| Attente silence (1000ms) | **1001 ms** | **9.9%** | `BOBODO_STT_LATENCY_BREAKDOWN.md` |
| Création WAV temporaire | ~2 ms | <0.1% | Logs |
| `model.transcribe()` | **9128 ms** | **89.9%** | Logs |
| Cleanup + callback | ~1 ms | <0.1% | Logs |
| **Total** | **10 142 ms** | **100%** | — |

### 3.2 Sources de latence et gains

| Source | Actuel | Cause | Gain | Correctif |
|---|---|---|---|---|
| **A. Overhead CTranslate2** | ~6 500 ms | Modèle medium 32 couches | **5-10x** avec **tiny** | Passer à Whisper Tiny |
| **B. Beam search** | ~1 800 ms | `beam_size=5` | **3-5x** avec `beam_size=1` | Greedy decoding |
| **C. Silence threshold** | 1001 ms | `silence_threshold_ms=1000` | **-700 ms** | Passer à 300 ms |
| **D. Fichier temporaire** | ~2 ms | `NamedTemporaryFile` sur disque | **-50 ms** (négligeable) | `io.BytesIO` |
| **E. Conversion audio** | ~50-100 ms | ffmpeg / re-encodage | **-50 ms** | PCM16 16kHz direct |

### 3.3 Latences estimées après correction

| Scénario | Modèle | beam_size | Silence | Latence STT estimée | vs actuel |
|---|---|---|---|---|---|
| **Actuel** | medium | 5 | 1000 ms | **10 142 ms** | 1x |
| Phase 1 | medium | 1 | 300 ms | **~8 000 ms** | 1.27x |
| Phase 2 | tiny | 1 | 300 ms | **~1 500 ms** | **6.8x** |
| Phase 3 | tiny + GPU | 1 | 300 ms | **~300 ms** | **34x** |
| **Optimal** | tiny + GPU + stream | 1 | 200 ms | **~200-400 ms** | **25-50x** |

**Note :** La latence totale end-to-end inclut aussi Bobodo LLM (~1.5-3s) + TTS (~0.5-2s). Cible : < 3s total.

---

## Mission 4 — Evaluation des modèles STT

### 4.1 Modèles locaux (Faster Whisper)

| Modèle | Taille disque | RAM | Temps CPU (1s audio) | Temps CPU (5s audio) | WER fr (est.) | Qualité |
|---|---|---|---|---|---|---|
| **tiny** | 39 MB | ~300 MB | ~150-300 ms | ~500-800 ms | ~18% | Acceptable dialogue |
| **base** | 74 MB | ~500 MB | ~300-600 ms | ~1.2-2.0 s | ~14% | Bon |
| **small** | 244 MB | ~1.0 GB | ~1.0-1.5 s | ~3.0-4.5 s | ~10% | Très bon |
| **medium** | 1.5 GB | ~1.9 GB | ~6.5-7.5 s | ~8.0-9.5 s | ~8% | Excellent |

### 4.2 Distil-Whisper

| Modèle | Taille | RAM | Temps CPU (5s) | WER fr | Verdict |
|---|---|---|---|---|---|
| distil-small-en | 756 MB | ~1.2 GB | ~2.0-3.0 s | ~10% | Optimisé anglais, fr moins testé |
| distil-medium-en | 1.5 GB | ~1.8 GB | ~3.0-4.5 s | ~9% | Idem |

**Verdict :** Non recommandé pour Academia (principalement anglais, gain limité vs tiny).

### 4.3 Alternatives cloud (API)

| Service | Latence | Coût | Précision fr | Facilité | Notes |
|---|---|---|---|---|---|
| **Deepgram Nova-2** | ~150-300 ms | $0.0043/min | Excellent | Très facile | Leader, streaming |
| **AssemblyAI** | ~200-400 ms | $0.0037/min | Très bon | Très facile | Bonne doc |
| **Google Cloud Speech** | ~300-600 ms | $0.024/min | Excellent | Facile | Coût élevé |
| **OpenAI Whisper API** | ~500-1500 ms | $0.006/min | Excellent | Très facile | Pas de streaming |
| **Azure Speech** | ~200-400 ms | $0.016/min | Excellent | Facile | Intégration MS |

**Coût estimé Academia (1000 users × 10 min/jour = 10 000 min/jour) :**
- Deepgram : 10 000 × $0.0043 = **$43/jour = ~$1 300/mois**
- AssemblyAI : 10 000 × $0.0037 = **$37/jour = ~$1 100/mois**

### 4.4 Conclusions par echelle

| Echelle | Recommandation | Justification |
|---|---|---|
| **Aujourd'hui** (0-50 users) | **Whisper Tiny local** | 0 cout, ~1.5s latence, qualite acceptable. Pas de dependance externe. |
| **10 000 users** | **Deepgram Nova-2** | <300ms, scaling infini, ~$1 300/mois. Migration API mais gain UX majeur. |
| **100 000 users** | **Deepgram + cache** | Meme infrastructure, ~$13 000/mois. Cache phrases courantes pour -20-30%. |

---

## Mission 5 — Benchmark type ChatGPT Voice

### 5.1 Cible produit : ChatGPT Voice

| Phase | ChatGPT Voice | Bobodo actuel | Ecart |
|---|---|---|---|
| Activation (bouton) | < 100 ms | ~200 ms | 2x |
| Ecoute utilisateur | Immédiate | Immédiate | 1x |
| Fin parole → STT | ~200-400 ms | **~10 000 ms** | **25-50x** |
| STT → LLM (Bobodo) | ~500-1000 ms | ~1 500-3 000 ms | 2-3x |
| LLM → TTS | ~200-500 ms | ~500-1 500 ms | 2-3x |
| TTS → Lecture | ~100 ms | ~200 ms | 2x |
| **Total end-to-end** | **< 2 s** | **~15-18 s** | **8-9x** |

### 5.2 Ecarts apres correctifs

| Phase | Apres Phase 1+2 (tiny, multi-session) | Ecart restant vs ChatGPT |
|---|---|---|
| STT | ~1 500 ms | ~4x |
| LLM | ~1 500-3 000 ms (inchangé) | ~2-3x |
| TTS | ~500-1 500 ms (inchangé) | ~2-3x |
| **Total** | **~4-6 s** | **~2-3x** |

### 5.3 Ecarts restants

Meme apres tous les correctifs locaux, **2-3x d'ecart** persistent. Causes :

1. **LLM Bobodo** : OpenRouter via Supabase Edge Function (~1.5-3s). ChatGPT utilise modèle interne ultra-optimise (~200-500ms).
2. **TTS** : gTTS necessite appel HTTP externe. ChatGPT utilise TTS interne en streaming.
3. **Architecture** : Pipeline sequentiel (STT → LLM → TTS). ChatGPT utilise streaming parallele.

**Pour atteindre la parite ChatGPT Voice :**
- Migrer STT vers Deepgram ou equivalent (gain 4x)
- Optimiser pipeline en streaming (LLM recoit texte STT au fur et a mesure)
- Utiliser TTS en streaming (Piper fonctionnel ou API TTS streaming)

---

## Mission 6 — Plan d'implémentation

### 6.1 Phase 1 — Blocants absolus (avant tout test utilisateur)

| # | Correction | Priorite | Difficulte | Risque | Temps estime | Dependances | Gain |
|---|---|---|---|---|---|---|---|
| 1.1 | **Isolation multi-session** : `SessionState` + `SessionManager` | P0 | Moyenne | Haut (refactor) | 2-3 jours | Aucune | Permet multi-user |
| 1.2 | **Cleanup session** : `finally: destroy_session()` | P0 | Faible | Faible | 2-4 heures | #1.1 | Stabilite |
| 1.3 | **Limite buffer** : `MAX_BUFFER_SIZE = 5 MB` | P0 | Faible | Faible | 30 min | #1.1 | Securite |
| 1.4 | **Thread pool transcription** : `ThreadPoolExecutor(4)` | P0 | Moyenne | Moyen | 1 jour | #1.1 | Parallelisme |
| 1.5 | **Reduction silence** : 1000ms → 300ms | P0 | Faible | Faible | 15 min | Aucune | -700 ms |
| 1.6 | **Correction bug modele** : `main.py:56` passe Settings | P0 | Faible | Faible | 30 min | Aucune | Active tiny |

**Duree Phase 1 estimee :** 4-5 jours

### 6.2 Phase 2 — Pre-production (avant beta ouverte)

| # | Correction | Priorite | Difficulte | Risque | Temps estime | Dependances | Gain |
|---|---|---|---|---|---|---|---|
| 2.1 | **Passage modele medium → tiny** | P1 | Faible | Moyen (qualite) | 1-2 heures | #1.6 | 6-8x plus rapide |
| 2.2 | **Reduction beam_size** : 5 → 1 | P1 | Faible | Faible | 15 min | Aucune | 3-5x plus rapide |
| 2.3 | **Traitement en memoire** : `io.BytesIO` au lieu de fichier temp | P1 | Moyenne | Faible | 2-4 heures | Aucune | -50 ms |
| 2.4 | **Heartbeat WebSocket** : ping/pong toutes les 30s | P1 | Faible | Faible | 1-2 heures | Aucune | Stabilite WS |
| 2.5 | **Tests charge** : 50 users simultanes | P1 | Moyenne | Faible | 1-2 jours | Phase 1+2 | Validation |
| 2.6 | **Monitoring** : metriques latence, erreurs, sessions actives | P1 | Moyenne | Faible | 1 jour | Aucune | Observabilite |

**Duree Phase 2 estimee :** 3-4 jours

### 6.3 Phase 3 — Optimisations futures

| # | Correction | Priorite | Difficulte | Risque | Temps estime | Dependances |
|---|---|---|---|---|---|---|
| 3.1 | **GPU locale** : Ajouter GPU sur serveur Kamatera | P2 | Moyenne | Moyen (cout) | 1-2 jours | Phase 1+2 |
| 3.2 | **API cloud STT** : Deepgram ou AssemblyAI | P2 | Moyenne | Moyen (cout recurrent) | 2-3 jours | Phase 1+2 |
| 3.3 | **Pipeline streaming** : STT stream → LLM stream → TTS stream | P2 | Elevee | Haut | 1-2 semaines | Phase 1+2+3.2 |
| 3.4 | **Cache transcription** : phrases courantes | P2 | Faible | Faible | 4-8 heures | Phase 1 |
| 3.5 | **Autoscaling** : Docker + load balancer | P2 | Elevee | Haut | 1-2 semaines | Phase 1+2 |

### 6.4 Roadmap visuelle

```
Jour 1-2    Jour 3-4    Jour 5       Jour 6-7    Jour 8-9    Jour 10
|-----------|-----------|------------|-----------|-----------|--------|
[Phase 1]   [Phase 1]   [Phase 1/2]  [Phase 2]   [Phase 2]   [Tests]
SessionMgr  ThreadPool  Silence+Bug  Tiny+Beam  Heartbeat   Charge50
Cleanup     BufferLim   Modele       BytesIO    Monitoring  Validation
```

**Date cible production-ready (Phase 1+2) :** ~10 jours de developpement apres demarrage.

---

## Mission 7 — Patches techniques

### 7.1 Fichier `stt_service.py` — Refonte complete

**Classe a ajouter :**

```python
@dataclass
class SessionState:
    session_id: str
    audio_buffer: bytearray
    websocket: WebSocket
    last_audio_time: float = 0.0
    transcription_callback: Optional[Callable] = None
    lock: asyncio.Lock = field(default_factory=asyncio.Lock)
    is_transcribing: bool = False
    max_buffer_size: int = 5 * 1024 * 1024  # 5 MB
```

**Modifications STTService :**

| Ligne(s) actuelle(s) | Action | Nouveau code |
|---|---|---|
| 24-36 `__init__` | Modifier | Ajouter `self.sessions: dict[str, SessionState] = {}` et `self.executor = ThreadPoolExecutor(max_workers=4)` |
| 30 `self.audio_buffer = bytearray()` | Supprimer | Deplace dans `SessionState` |
| 33 `self.silence_threshold_ms = 1000` | Modifier | `self.silence_threshold_ms = int(os.getenv("SILENCE_THRESHOLD_MS", "300"))` |
| ~148-187 `transcribe(audio_bytes)` | Refactor | `transcribe(session_id, audio_bytes)` : recupere ou cree `SessionState`, etend le buffer sous `lock` |
| ~189-213 `_wait_for_silence` | Refactor | Parcourir `self.sessions` et verifier `last_audio_time` par session |
| ~101-146 `_detect_silence` | Refactor | Prendre `session_id` en parametre, lire `session.audio_buffer` |
| 127-132 `tempfile.NamedTemporaryFile` | Optionnel | Remplacer par `io.BytesIO(wav_data)` si Whisper l'accepte |
| 235-240 `model.transcribe(...)` | Refactor | Executer dans `self.executor.submit(...)` |
| 143 callback | Refactor | Appeler `session.transcription_callback(result)` |

**Methodes a ajouter :**

```python
def get_or_create_session(self, session_id: str, websocket: WebSocket, callback: Callable) -> SessionState:
    if session_id not in self.sessions:
        self.sessions[session_id] = SessionState(session_id=session_id, ...)
    return self.sessions[session_id]

def destroy_session(self, session_id: str):
    if session_id in self.sessions:
        del self.sessions[session_id]

def _run_transcription(self, session_id: str, audio_bytes: bytes):
    session = self.sessions.get(session_id)
    if not session:
        return
    # Appel synchrone dans le worker thread
    segments, info = self.model.transcribe(io.BytesIO(audio_bytes), language="fr", beam_size=1)
    text = " ".join([s.text for s in segments])
    # Retour vers asyncio loop principale
    asyncio.run_coroutine_threadsafe(
        self._send_result(session_id, text), self.loop
    )

async def _send_result(self, session_id: str, text: str):
    session = self.sessions.get(session_id)
    if session and session.transcription_callback:
        await session.transcription_callback(text)
```

### 7.2 Fichier `websocket_handler.py`

| Ligne actuelle | Action | Nouveau code |
|---|---|---|
| 29 `self.stt_service.set_transcription_callback(...)` | Supprimer | Le callback est passe lors de la creation de session |
| ~45-58 `handle()` | Modifier | Ajouter `finally: self.stt_service.destroy_session(self.session_id)` |
| ~session_id handling | Modifier | `self.stt_service.get_or_create_session(self.session_id, self.websocket, self._on_transcription_complete)` |

```python
async def handle(self):
    await self.websocket.accept()
    try:
        self.stt_service.get_or_create_session(
            self.session_id,
            self.websocket,
            self._on_transcription_complete
        )
        while True:
            data = await self.websocket.receive_text()
            message = json.loads(data)
            if message["type"] == "audio":
                audio_bytes = base64.b64decode(message["audio"])
                await self.stt_service.transcribe(self.session_id, audio_bytes)
    except WebSocketDisconnect:
        logger.info("WebSocket connection closed")
    finally:
        self.stt_service.destroy_session(self.session_id)
```

### 7.3 Fichier `main.py`

| Ligne actuelle | Action | Nouveau code |
|---|---|---|
| 56 `stt_service = STTService()` | Modifier | `stt_service = STTService(model_size=settings.whisper_model, device=settings.whisper_device, compute_type=settings.whisper_quantization)` |
| 91-95 `websocket_endpoint` | Conserver | Aucun changement necessaire (le refactor est interne) |

### 7.4 Fichier `.env`

**Ajouter :**

```
WHISPER_MODEL=tiny
WHISPER_DEVICE=cpu
WHISPER_QUANTIZATION=int8
SILENCE_THRESHOLD_MS=300
MAX_BUFFER_SIZE_MB=5
```

### 7.5 Fichier `requirements.txt`

Verifier que `faster-whisper` supporte `io.BytesIO`. Si oui, aucun changement. Sinon, ajouter `soundfile` pour lecture buffer memoire.

---

## Mission 8 — Validation Production

### 8.1 Checklist complete

| Critere | Methode de test | Seuil minimal | Seuil recommande |
|---|---|---|---|
| **Isolation sessions** | 5 users envoient phrases differentes simultanement. Verifier que chaque user recoit SA transcription. | 0% melange | 0% melange |
| **Securite memoire** | Envoyer 10 MB d'audio. Verifier rejet. | Buffer rejete | Buffer rejete + alerte |
| **Stabilite WS** | 50 users connectes pendant 10 min. | < 5% deconnexion | < 1% deconnexion |
| **Latence STT** | Mesurer temps audio → transcription (50 essais). | < 3 000 ms | < 1 500 ms |
| **Latence totale** | Mesurer temps bouton → reponse audio (50 essais). | < 8 000 ms | < 5 000 ms |
| **Montee en charge** | 50 users simultanes, chacun envoie 5 phrases. | 80% succes | 95% succes |
| **Reprise apres erreur** | Deconnecter WS pendant transcription. Reconnecter. | Transcription propre | Aucune fuite buffer |
| **Monitoring** | Dashboard temps reel sessions/latence/erreurs. | Disponible | Disponible + alertes |

### 8.2 Tests automatises a implementer

```python
# test_isolation.py
async def test_session_isolation():
    results = await asyncio.gather(
        send_and_expect("sess-a", "Bonjour", "Bonjour"),
        send_and_expect("sess-b", "Capitale", "Capitale"),
        send_and_expect("sess-c", "Photosynthese", "Photosynthese"),
    )
    assert all(r.melange == False for r in results)

# test_load.py
async def test_50_users():
    tasks = [simulate_user(f"user-{i}") for i in range(50)]
    results = await asyncio.gather(*tasks)
    success_rate = sum(1 for r in results if r.ok) / len(results)
    assert success_rate >= 0.80  # minimal
```

### 8.3 Seuils de decision GO/NO-GO

| Gate | Condition | Decision |
|---|---|---|
| **GO Phase 1** | Isolation + cleanup + thread pool fonctionnels avec 5 users | Continuer Phase 2 |
| **GO Phase 2** | Latence STT < 3s avec tiny + 50 users simultanes sans melange | Ouvrir beta |
| **GO Production** | Latence totale < 5s + 95% succes + 0% melange + monitoring OK | Production |

---

## Conclusion

### Resumé des 6 blocages et de leurs remediations

| Rang | Blocage | Remediation | Temps | Impact |
|---|---|---|---|---|
| 1 | Architecture single-user | Refonte multi-session avec `SessionManager` | 2-3 jours | Permet 50-100 users simultanes |
| 2 | Latence STT 10s | Passage tiny + beam_size=1 + silence 300ms | 1 jour | **6.8x plus rapide** (~1.5s) |
| 3 | Buffer non securise | Cleanup + limite 5 MB + TTL | 4-8 heures | Stabilite + securite |
| 4 | Bug parametre modele | Correction `main.py:56` + `.env` | 30 min | Active la configuration |
| 5 | Silence threshold 1000ms | Variable d'environnement 300ms | 15 min | -700 ms par requete |
| 6 | Sous-utilisation CPU | `ThreadPoolExecutor(4)` | 1 jour | Parallelisme multi-user |

### Decision precise : quoi corriger, dans quel ordre

1. **Commencer immediatement** par l'isolation multi-session (Mission 1 + Mission 2). C'est le blocage absolu. Sans cela, tout le reste est inutile.
2. **En parallele** : corriger le bug de parametre modele et reduire le silence threshold (15 minutes chacun, gains immediats).
3. **Ensuite** : ajouter le thread pool et le cleanup automatique (1-2 jours).
4. **Puis** : passer a tiny + beam_size=1 (1 jour, gain majeur de latence).
5. **Enfin** : tests charge 50 users + monitoring (2-3 jours).

### Quand Bobodo Voice sera READY FOR PRODUCTION

**Avec Phase 1 + Phase 2 (~10 jours) :**
- Latence STT : ~1.5 secondes (vs 10s actuel)
- Utilisateurs simultanes : 50 (vs 1 actuel)
- Melange : 0% (vs 100% actuel)
- Latence totale : ~4-6 secondes (vs 15-18s actuel)

**Ce n'est pas encore ChatGPT Voice (< 2s), mais c'est une experience vocale fluide et utilisable en production pour Academia.**

**Pour atteindre ChatGPT Voice, il faudra Phase 3 (API cloud + streaming), ce qui represente 2-4 semaines supplementaires et un cout recurrent.**
