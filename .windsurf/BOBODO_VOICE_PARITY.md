# BOBODO_VOICE_PARITY

## Phase 6 — Validation parité ChatGPT Voice

---

### Date
2026-06-12

---

### Tableau comparatif

| Critère | ChatGPT Voice | Bobodo Voice (après corrections) | Écart |
|---|---|---|---|
| **Activation** | Appui long sur micro ou tap | Bouton micro + toggle mode conversation | ✅ Équivalent |
| **Écoute** | Streaming temps réel | STT local + envoi WS audio | ⚠️ Équivalent fonctionnellement |
| **Réponse** | Streaming audio temps réel | Buffer audio complet + lecture | ❌ Latence TTS acceptable (~3s) |
| **Interruption (barge-in)** | Parler pendant réponse = coupure immédiate | `_onTranscriptionReceived` → `_stopAudioPlayback` | ✅ Implémenté |
| **Reprise** | Reconnexion transparente | ❌ Pas de reconnexion auto WS | ❌ Gap majeur |
| **Mémoire** | Contexte conversation persistant | `session_id` + `BobodoProvider` + Edge Function | ✅ Équivalent |
| **Fluidité** | ~1-2s total | ~11-12s total | ❌ **Gap critique** |

---

### Analyse détaillée

#### 1. Activation
- **ChatGPT :** Appui long sur le bouton micro ou simple tap selon la version.
- **Bobodo :** Bouton micro dans l'UI + toggle `_isConversationMode`.
- **Verdict :** ✅ Équivalent. L'activation est intuitive et documentée.

#### 2. Écoute
- **ChatGPT :** Streaming audio vers serveur OpenAI. Whisper temps réel.
- **Bobodo :** STT local Flutter (`speech_to_text`) → texte envoyé → ou audio PCM16 envoyé au serveur via WS.
- **Verdict :** ⚠️ Équivalent fonctionnellement. Le STT local est plus rapide pour l'UX immédiate, mais l'envoi audio au serveur est redondant (double STT).

#### 3. Réponse
- **ChatGPT :** LLM stream + TTS stream en parallèle. Audio joué au fur et à mesure.
- **Bobodo :** Attente complète du LLM + génération TTS complète → envoi audio_response.
- **Verdict :** ❌ Streaming impossible avec l'architecture actuelle (Edge Function + gTTS buffer).

#### 4. Interruption (barge-in)
- **ChatGPT :** Détection automatique de parole pendant TTS → coupure immédiate.
- **Bobodo :** `_isSpeaking` + `_stopAudioPlayback()` + nouvelle requête.
- **Verdict :** ✅ Implémenté et fonctionnel.

#### 5. Reprise
- **ChatGPT :** WebSocket géré par l'app, reconnexion transparente.
- **Bobodo :** `onDone` détecte la fermeture WS mais ne reconnecte pas.
- **Verdict :** ❌ Non implémenté. Gap majeur pour mobile.

#### 6. Mémoire
- **ChatGPT :** Contexte thread persistant côté serveur OpenAI.
- **Bobodo :** `session_id` lié à `bobodo_sessions` + historique messages en base.
- **Verdict :** ✅ Équivalent. La mémoire est persistante et cross-device.

#### 7. Fluidité
- **ChatGPT :** ~1-2 secondes entre fin de parole et début de réponse.
- **Bobodo :** ~11-12 secondes (8.4s STT + 2.9s Bobodo+TTS).
- **Verdict :** ❌ **Gap critique.** La latence STT (~8.4s) rend l'expérience non fluide.

---

### Score parité

| Domaine | Score (/10) | Commentaire |
|---|---|---|
| Activation | 8/10 | Bouton visible, mode conversation clair |
| Écoute | 7/10 | STT local rapide, envoi audio redondant |
| Réponse | 5/10 | Pas de streaming, attente complète |
| Interruption | 8/10 | Barge-in fonctionnel |
| Reprise | 2/10 | Pas de reconnexion auto |
| Mémoire | 9/10 | Session_id + historique en base |
| Fluidité | 3/10 | Latence STT critique (~8.4s) |

**Total : 42/70 (60%)**

---

### Verdict

✅ **Bobodo Voice est fonctionnel de bout en bout.**

❌ **La parité ChatGPT Voice n'est pas atteinte.** Les 2 gaps critiques sont :
1. **Latence STT (~8.4s)** : Nécessite une refonte du buffer STT (streaming ou réduction silence).
2. **Reconnexion réseau** : Nécessite un mécanisme de reconnect auto dans `BobodoVocalService`.

**Recommandation :** Le chantier peut être considéré comme terminé pour un MVP conversation vocal, mais une optimisation de la latence STT est indispensable pour une expérience utilisateur comparable à ChatGPT Voice.
