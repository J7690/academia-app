# BOBODO_VOICE_REALITY_CHECK_FINAL

## Livrable final — Blocages empêchant Bobodo Voice d'atteindre ChatGPT Voice

---

### Date
2026-06-13

---

### Question

> "Quels sont les blocages réels empêchant aujourd'hui Bobodo Voice d'atteindre un niveau propre de ChatGPT Voice ?"

---

### Référence : ChatGPT Voice

ChatGPT Voice offre :
- Activation vocale : < 500 ms
- Latence STT : ~200-500 ms
- Latence LLM : ~500-1000 ms
- Latence TTS : ~200-500 ms
- **Total end-to-end : < 2 secondes**
- Multi-utilisateurs : Oui (millions)
- Isolation sessions : Complète
- Interruptions : Supportées
- Reconnexion : Transparente

---

## Blocages par ordre de gravité

---

### 🔴 CRITIQUE — 1. Architecture single-user (mélange des sessions)

**Gravité :** Le système est physiquement incapable de servir plus d'un utilisateur à la fois.

**Preuve :**
- 5 utilisateurs simultanés : 80% timeout, 100% de mélange (`BOBODO_CONCURRENT_USERS_AUDIT.md`)
- user-5 a reçu : "Bonjour Bobodo, explique la photosynthese. Quelle est la capitale ? Bonjour Bobodo, explique la photosynthese. Quelle est la capitale ? Donne-moi un conseil de revision. Comment postuler sur Academia ?"
- Ce sont les phrases de **5 utilisateurs différents** dans UNE SEULE transcription

**Cause racine :**
- `main.py` crée UNE SEULE instance `STTService()` (`main.py:56`)
- Toutes les connexions WebSocket partagent le même `stt_service` (`main.py:91-95`)
- Le `audio_buffer` est un `bytearray()` global (`stt_service.py:30`)
- Le callback de transcription est écrasé par chaque nouvelle connexion (`websocket_handler.py:29`)

**Impact :**
- Fuite de données entre étudiants (données personnelles vocales)
- 80% de timeout en charge
- Transcriptions totalement erronées en concurrence
- **Impossible à corriger par un simple patch** — nécessite une refonte architecturale complète (STTService par session)

---

### 🔴 CRITIQUE — 2. Latence STT incompatible avec l'interactivité

**Gravité :** 10 secondes de latence rend l'expérience inutilisable.

**Preuve :**
- Audio 1.39s → transcription 7789 ms (5.6x temps réel)
- Audio 2.95s → transcription 7542 ms (2.56x temps réel)
- Audio 4.99s → transcription 8320 ms (1.67x temps réel)
- **Seuil de silence ajoute 1000 ms artificiellement** (`stt_service.py:33`)
- **Total mesuré via WS : 10 142 ms** (`BOBODO_STT_LATENCY_BREAKDOWN.md`)

**Cause racine :**
- Modèle **medium** (1.5 GB) sur **CPU** 4 cœurs Xeon 2.0GHz (`BOBODO_STT_REAL_MODEL.md`)
- Paramètre `beam_size=5` coûteux en inférence CPU
- Pas d'accélération matérielle (pas de GPU, pas de NPU)
- Overhead fixe CTranslate2 de ~6.5 secondes (`BOBODO_TRANSCRIBE_PROFILING.md`)

**Comparaison :**
| Système | Latence STT | Ratio temps réel |
|---|---|---|
| Bobodo Voice (medium/CPU) | **~9000 ms** | **1.7-5.6x** |
| ChatGPT Voice | **~300 ms** | **~0.06x** |

ChatGPT Voice est **30x plus rapide** que Bobodo Voice.

**Impact :**
- L'étudiant attend 10 secondes avant que Bobodo ne comprenne sa phrase
- Impossible de maintenir une conversation fluide
- L'étudiant parle, attend, s'impatiente, parle à nouveau → chaos

---

### 🟠 MAJEUR — 3. Buffer audio non sécurisé (survie aux déconnexions)

**Gravité :** Risque de fuite mémoire et de corruption de données.

**Preuve :**
- Le `audio_buffer` n'est jamais nettoyé lors d'une déconnexion WebSocket (`websocket_handler.py:52`)
- Si un étudiant se déconnecte avant la détection de silence, son audio reste dans le buffer
- La prochaine connexion reçoit l'audio accumulé
- Aucune limite de taille sur le `bytearray()`

**Impact :**
- Transcriptions erronées après reconnexion
- Risque d'attaque par saturation mémoire (envoi audio infini)
- Comportement non déterministe après perte réseau

---

### 🟠 MAJEUR — 4. Paramètre modèle ignoré (bug de configuration)

**Gravité :** Le système utilise un modèle 40x plus lourd que celui configuré.

**Preuve :**
- `.env` dit `WHISPER_MODEL=medium`
- `Settings` default dit `whisper_model="tiny"`
- `main.py` appelle `STTService()` **sans argument**
- `stt_service.py` default est `model_size="medium"`
- **Résultat : medium est utilisé**, tiny n'est jamais instancié
- Modèle medium = 1.5 GB ; tiny = 39 MB ; ratio **40x**

**Impact :**
- Même si l'intention était d'utiliser tiny (rapide), le système charge medium (lent)
- Ce bug de passage de paramètre rend toute configuration via .env inefficace

---

### 🟡 MINEUR — 5. Seuil de silence fixe et non configurable

**Gravité :** Ajoute 1 seconde de latence artificielle à chaque requête.

**Preuve :**
- `silence_threshold_ms = 1000` (`stt_service.py:33`)
- C'est un délai fixe ajouté après le dernier paquet audio
- Non configurable via .env
- ChatGPT Voice utilise un VAD (Voice Activity Detection) adaptatif qui détecte la fin de parole en ~100-200 ms

**Impact :**
- +1 seconde systématique sur chaque tour de conversation
- 10% de la latence totale vient de ce paramètre artificiel

---

### 🟡 MINEUR — 6. Utilisation sous-optimale des ressources CPU

**Gravité :** 3 cœurs sur 4 sont inutilisés pendant la transcription.

**Preuve :**
- Serveur : 4 cœurs Xeon 2.0GHz (`lscpu`)
- CTranslate2 utilise principalement **1 cœur** pour le décodage
- Load average : 0.20 (très faible)
- Le processus consomme ~25% CPU pendant la transcription (1 cœur sur 4)

**Impact :**
- La latence pourrait être divisée par ~2-3 si tous les cœurs étaient utilisés
- Mais cela ne résoudrait pas le problème fondamental (modèle trop lourd pour CPU)

---

## Synthèse des blocages

| Rang | Blocage | Gravité | Preuve | Correctif estimé |
|---|---|---|---|---|
| 1 | **Architecture single-user** (buffer/callback global) | CRITIQUE | `BOBODO_SESSION_ISOLATION_TEST.md` | Refonte complète du serveur |
| 2 | **Latence STT 10s** (modèle medium/CPU) | CRITIQUE | `BOBODO_STT_LATENCY_BREAKDOWN.md` | Migration GPU ou API externe |
| 3 | **Buffer non sécurisé** (survie aux déconnexions) | MAJEUR | `BOBODO_AUDIO_BUFFER_AUDIT.md` | Ajout cleanup + limites |
| 4 | **Bug paramètre modèle** (medium au lieu de tiny) | MAJEUR | `BOBODO_STT_REAL_MODEL.md` | Correction main.py ligne 56 |
| 5 | **Silence threshold 1000ms** | MINEUR | `BOBODO_STT_LATENCY_BREAKDOWN.md` | Réduction à 200-300ms |
| 6 | **Sous-utilisation CPU** | MINEUR | `BOBODO_STT_RESOURCE_USAGE.md` | Configuration CTranslate2 |

---

## Conclusion

**Bobodo Voice est bloqué par 2 problèmes CRITIQUES qui empêchent tout usage en production :**

1. **L'architecture ne supporte qu'un utilisateur.** Le buffer audio et le callback sont globaux. Toute tentative de conversation par plus d'une personne simultanément produit des transcriptions mélangées et des timeouts massifs.

2. **La latence STT est 30x supérieure à ChatGPT Voice.** 10 secondes pour transcrire 5 secondes de parole est inacceptable pour une conversation vocale. Cela vient du choix du modèle medium sur CPU sans accélération matérielle.

**Ces 2 problèmes sont architecturaux.** Ils ne peuvent pas être résolus par un simple patch ou une optimisation. Ils nécessitent :
- Une refonte du serveur pour isoler les sessions (buffer + callback par session)
- Un changement de stratégie STT (API cloud comme Deepgram/AssemblyAI, ou GPU local)

**Les problèmes MAJEURS et MINEURS sont des bugs corrigibles** mais ne résoudront pas les blocages critiques.

---

## Livrables de l'audit complet

| # | Fichier | Mission |
|---|---|---|
| 1 | `BOBODO_STT_REAL_MODEL.md` | Modèle réellement utilisé |
| 2 | `BOBODO_AUDIO_BUFFER_AUDIT.md` | Audit complet du buffer |
| 3 | `BOBODO_SESSION_ISOLATION_TEST.md` | Reproduction du mélange |
| 4 | `BOBODO_TRANSCRIBE_PROFILING.md` | Profilage model.transcribe() |
| 5 | `BOBODO_STT_RESOURCE_USAGE.md` | CPU/RAM pendant transcription |
| 6 | `BOBODO_CONCURRENT_USERS_AUDIT.md` | Concurrence multi-utilisateurs |
| 7 | `BOBODO_VOICE_PRODUCTION_GATE.md` | Préparation production |
| **F** | **`BOBODO_VOICE_REALITY_CHECK_FINAL.md`** | **Synthèse finale** |
