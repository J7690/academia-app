# BOBODO VOICE — STATUT PILOTE PRODUCTION

## Date : 14 Juin 2026

---

## Pipeline complet validé ✅

```
User (audio) → WebSocket → STTSession (isolé) → Whisper Medium → Transcription
                                                                       ↓
User (audio) ← WebSocket ← TTS (gTTS) ← Bobodo Edge Function ← BobodoClient v3
```

---

## Tests de validation

### Single user — Pipeline complet

| Étape | Résultat | Latence |
|---|---|---|
| Transcription | ✅ `'Bonjour Bobodo'` | 9.6s |
| Réponse Bobodo | ✅ `'Salut ! 👋'` | +3.3s |
| Audio TTS reçu | ✅ | 12.9s total |

### Multi-session — 3 users simultanés

| User | Transcription | Audio response | Latence |
|---|---|---|---|
| 0 | ✅ `'Bonjour Bobodo'` | ✅ | 9.2s / 29.8s |
| 1 | ✅ `'Je veux parler à Bobodo.'` | ✅ | 25.1s / 29.6s |
| 2 | ✅ `'Bobodo, explique-moi...'` | ✅ | 25.1s / 31.4s |

**Contamination : AUCUNE (3 transcriptions uniques)**

### Conversation 5+ minutes

| Métrique | Valeur |
|---|---|
| Durée | 321s (5 min 21s) |
| Échanges audio envoyés | 4 |
| Transcriptions reçues | **4/4 (100%)** |
| Réponses audio reçues | **4/4 (100%)** |
| Erreurs | **0** |
| Déconnexions | **0** |
| RAM service | 1.8 GB (peak 2.1 GB) |

---

## Architecture déployée

| Fichier serveur | Version | Fonction |
|---|---|---|
| `stt_service.py` | v2 | STTSession isolé par connexion |
| `websocket_handler.py` | v2 | create_session/destroy_session dans finally |
| `bobodo_client.py` | v3 | Edge Function via Supabase (sessions réelles) |
| `main.py` | original | Inchangé |
| `tts_service.py` | original | Inchangé (gTTS) |

---

## Latence pipeline complet (Medium)

| Étape | Durée |
|---|---|
| Silence detection | 1.0s |
| Transcription Whisper Medium | ~8s |
| Edge Function (RAG + OpenRouter) | ~3–4s |
| TTS (gTTS) | ~1s |
| **Total bout-en-bout** | **~13s** |

Avec 3 users : dernier user attend ~25s (séquentiel STT) + ~5s (Edge Function + TTS) = ~30s.

---

## Capacité mesurée

| Users | Latence totale (pipeline complet) | Fonctionnel |
|---|---|---|
| 1 | ~13s | ✅ |
| 2 | ~20s | ✅ |
| 3 | ~31s | ✅ (mais dernier user attend) |

---

## Éléments restants pour production

| Priorité | Action | Impact |
|---|---|---|
| 1 | Migrer Medium → Small | Latence STT ÷ 2.7 (8s → 2.8s) |
| 2 | Association user réel (pas student_id fixe) | Auth Flutter → WS → Bobodo |
| 3 | Test depuis réseau externe (pas localhost) | Valider latence réseau |
| 4 | Monitoring (RAM, sessions actives) | Stabilité long terme |

---

## Verdict

### **GO PILOTE**

Le pipeline Bobodo Voice est **fonctionnel de bout en bout** :
- Multi-session isolé
- Conversations stables
- Zéro contamination
- Zéro déconnexion
- Réponses IA + audio reçues

**Prêt pour un pilote avec utilisateurs réels (1–3 simultanés).**
