# BOBODO_PROTOCOL_FUTURE_COMPATIBILITY

## Mission 5 — Compatibilité avec le mode conversation continue

---

### Objectif final rappelé

- Conversation vocale **permanente**
- Micro **réactivé automatiquement** après réponse TTS
- Mémoire Bobodo **conservée** entre les tours
- **Interruptions** possibles (barge-in)
- **Reprise** possible après coupure réseau

---

### Analyse Option A (message `session_id` dédié)

#### Conversation continue
```
Tour 1: WS connect → send session_id → send audio → receive transcription → receive audio_response
Tour 2: [micro réactivé] → send audio → receive transcription → receive audio_response
Tour N: [idem]
```
**✅ Compatible :** La connexion WS persiste, le session_id est configuré une seule fois.

#### Interruptions (barge-in)
```
Utilisateur parle pendant que Bobodo répond (TTS en cours)
→ Client envoie nouvel audio
→ Serveur doit : arrêter TTS, transcribe nouvel audio, nouvelle réponse
```
**⚠️ Nécessite :** `handle_audio()` doit annuler la réponse TTS en cours.
**Note :** `stt_service.py` utilise déjà `self.silence_task.cancel()` pour le buffer.

#### Reconnexion réseau
```
Connexion WS perdue → Flutter reconnecte WS → Flutter renvoie session_id
→ Conversation reprend
```
**✅ Compatible :** Le session_id est renvoyé après reconnexion.

#### Multi-session
```
Changer de session = envoyer nouveau message `{"type":"session_id","session_id":"NEW"}`
```
**✅ Compatible :** Pas besoin de reconnecter le WS.

---

### Analyse Option B (session_id dans chaque message audio)

#### Conversation continue
```
Tour 1: WS connect → send audio+session_id → receive transcription → receive audio_response
Tour 2: send audio+session_id → receive transcription → receive audio_response
```
**✅ Compatible :** Le session_id est présent à chaque message.

#### Interruptions (barge-in)
```
Nouvel audio arrivant avec session_id
→ Serveur lit session_id → appelle Bobodo
```
**⚠️ Problème :** Si 2 messages audio consécutifs arrivent très vite, le buffer STT global accumule les 2 sans distinction de session.

#### Reconnexion réseau
```
Connexion WS perdue → STT buffer global vidé/perturbé
→ Flutter reconnecte → audio buffer accumulé depuis la reconnexion
```
**❌ Risque :** Le buffer STT est global et n'est pas lié à la connexion WS. Après reconnexion, l'audio du "tour précédent" peut être perdu ou mélangé.

#### Multi-session
```
Changer de session = envoyer audio avec nouveau session_id
```
**⚠️ Confusion :** Le serveur change `self.session_id` à chaque message. Si un callback STT d'un message précédent arrive après le changement, il utilise le mauvais session_id.

---

### Problème critique du buffer STT global

**`stt_service.py:349`**
```python
self.audio_buffer = bytearray()  # SINGLE global buffer
```

**Scénario de bug (Option B) :**
```
[User A] send audio (session_id=A) → buffer=[audioA]
[User B] send audio (session_id=B) → buffer=[audioA, audioB]  ← MIXED!
[Silence detected] → transcribe(audioA+audioB) → garbled text
```

**Ce problème existe dans les 2 options** mais est plus évident avec Option B car on pourrait croire que `session_id` dans chaque message résout le problème — ce qui n'est pas le cas.

---

### Verdict futur

| Exigence | Option A | Option B |
|---|---|---|
| Conversation continue | ✅ | ✅ |
| Micro réactivé auto | ✅ | ✅ |
| Mémoire conservée | ✅ | ✅ |
| Interruptions | ⚠️ (serveur) | ⚠️ (serveur) |
| Reconnexion réseau | ✅ | ❌ |
| Multi-session | ✅ | ⚠️ |
| Multi-utilisateur | ❌ (buffer global) | ❌ (buffer global) |

**Les deux options nécessitent de corriger le buffer STT global** pour supporter le multi-utilisateur.

**Option A est supérieure pour la reconnexion réseau** car le session_id est envoyé explicitement après reconnexion, tandis qu'avec Option B le buffer STT global est perturbé.
