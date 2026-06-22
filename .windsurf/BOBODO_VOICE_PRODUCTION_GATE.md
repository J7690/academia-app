# BOBODO_VOICE_PRODUCTION_GATE

## Mission 7 — Audit de préparation production

---

### Date
2026-06-13

---

### Règle

Répondre uniquement par :
- **READY** — le critère est satisfait
- **NOT READY** — le critère n'est pas satisfait

Interdiction d'utiliser des termes vagues.

---

### 1. Isolation des sessions

**Verdict : NOT READY**

**Justification :**
- `audio_buffer` est un `bytearray()` global au processus (`stt_service.py:30`)
- Toutes les connexions WebSocket partagent le même buffer (`main.py:91-95`)
- Preuve : user-5 a reçu la transcription de 5 utilisateurs mélangés (`BOBODO_SESSION_ISOLATION_TEST.md`)
- Le callback est écrasé par chaque nouvelle connexion (`websocket_handler.py:29`)

**Conséquence :** Un étudiant reçoit les conversations des autres étudiants.

---

### 2. Sécurité mémoire

**Verdict : NOT READY**

**Justification :**
- Le buffer audio n'est jamais explicitement nettoyé en cas de déconnexion (`websocket_handler.py:52`)
- Le buffer peut accumuler de l'audio indéfiniment si aucun silence n'est détecté
- Aucune limite de taille sur `audio_buffer`
- Un utilisateur malveillant pourrait inonder le buffer avec des données audio infinies

**Conséquence :** Risque d'attaque par déni de service (fuite mémoire / buffer overflow).

---

### 3. Stabilité WebSocket

**Verdict : NOT READY**

**Justification :**
- 80% de timeout avec 5 utilisateurs simultanés (`BOBODO_CONCURRENT_USERS_AUDIT.md`)
- 100% de timeout avec 3 utilisateurs simultanés
- Les connexions concurrentes s'entremêlent et bloquent mutuellement
- Aucune gestion de file d'attente pour les transcriptions
- Aucun mécanisme de heartbeat ou ping/pong actif

**Conséquence :** Les utilisateurs perdent leurs connexions sans explication.

---

### 4. Latence

**Verdict : NOT READY**

**Justification :**
- STT : ~10.1 secondes pour 5 secondes d'audio (`BOBODO_STT_LATENCY_BREAKDOWN.md`)
- Total pipeline (STT + Bobodo + TTS) : ~15-18 secondes
- ChatGPT Voice latence : < 1 seconde (end-to-end)
- Le seuil de silence ajoute 1 seconde artificielle
- Le modèle medium sur CPU est inadapté à l'usage interactif

**Conséquence :** L'expérience utilisateur est inacceptable. 10+ secondes d'attente entre la parole et la réponse.

---

### 5. Multi-utilisateurs

**Verdict : NOT READY**

**Justification :**
- Architecture single-user (une instance STTService, un buffer, un callback)
- 100% de mélange détecté dans les tests concurrents
- 80% de timeout avec 5 utilisateurs
- Le serveur ne peut traiter qu'une transcription à la fois

**Conséquence :** Le système ne fonctionne que si UN SEUL utilisateur parle à la fois.

---

### 6. Reconnexion réseau

**Verdict : NOT READY**

**Justification :**
- Aucune persistance du `session_id` côté serveur entre reconnections
- Si une connexion est interrompue, l'audio reste coincé dans le buffer global
- Aucun mécanisme de reprise de session
- Le buffer accumulé est retranscrit à la prochaine connexion

**Conséquence :** Une perte de réseau mène à une transcription erronée à la reconnexion.

---

### 7. Conversation continue

**Verdict : NOT READY**

**Justification :**
- Le cycle listen → transcribe → Bobodo → TTS → play existe en Flutter (`BOBODO_CONVERSATION_CONTINUOUS.md`)
- Mais le serveur est **bloquant** pendant la transcription (~10s)
- Pendant ces 10s, aucun nouvel audio ne peut être reçu (buffer accumule)
- Le cycle théorique ne fonctionne pas en pratique car le serveur ne peut pas gérer le flux continu
- Le callback unique empêche toute conversation multi-tours fiable

**Conséquence :** La conversation continue est théoriquement implémentée mais pratiquement inopérante.

---

### Tableau récapitulatif

| Critère | Verdict | Preuve |
|---|---|---|
| Isolation des sessions | **NOT READY** | `BOBODO_SESSION_ISOLATION_TEST.md` |
| Sécurité mémoire | **NOT READY** | `BOBODO_AUDIO_BUFFER_AUDIT.md` |
| Stabilité WebSocket | **NOT READY** | `BOBODO_CONCURRENT_USERS_AUDIT.md` |
| Latence | **NOT READY** | `BOBODO_STT_LATENCY_BREAKDOWN.md` |
| Multi-utilisateurs | **NOT READY** | `BOBODO_CONCURRENT_USERS_AUDIT.md` |
| Reconnexion réseau | **NOT READY** | `BOBODO_AUDIO_BUFFER_AUDIT.md` |
| Conversation continue | **NOT READY** | `BOBODO_STT_LATENCY_BREAKDOWN.md` + `BOBODO_CONCURRENT_USERS_AUDIT.md` |

---

### Conclusion

**0 / 7 critères READY**

**Bobodo Voice n'est PAS prêt pour la production.**

Les problèmes ne sont pas des optimisations mineures mais des **défauts architecturaux fondamentaux** :
- Le serveur est conçu pour un utilisateur unique
- Le buffer audio est global et non isolé
- Le modèle STT est trop lent pour l'interactivité
- Aucun mécanisme de concurrence n'est implémenté
