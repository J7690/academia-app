# BOBODO_PROTOCOL_OPTIONS

## Mission 3 — Comparaison des deux stratégies

---

### OPTION A : Flutter envoie `session_id` séparément

**Description :** Après connexion WS, Flutter envoie un message dédié :
```json
{"type": "session_id", "session_id": "abc-123"}
```
Puis envoie les messages audio sans `session_id`.

**Modifications nécessaires :**
- **Flutter** : Ajouter `sendSessionId()` après `connect()`
- **Serveur** : Aucune modification

| Critère | Évaluation |
|---|---|
| **Robustesse** | ⭐⭐⭐⭐⭐ Le session_id est explicitement configuré côté serveur |
| **Simplicité** | ⭐⭐⭐⭐ Un message supplémentaire, logique claire |
| **Compatibilité future** | ⭐⭐⭐⭐⭐ Permet de changer de session sans reconnecter |
| **Mode conversation** | ⭐⭐⭐⭐⭐ Session_id fixé une fois, réutilisé pour tous les tours |
| **Reconnexion réseau** | ⭐⭐⭐⭐⭐ Après reconnexion WS, renvoyer `session_id` suffit |
| **Maintenance** | ⭐⭐⭐⭐ Protocole explicite, facile à documenter |

---

### OPTION B : Serveur lit `session_id` dans chaque message audio

**Description :** Le serveur extrait `session_id` du payload audio à chaque réception :
```json
{"type": "audio", "session_id": "abc-123", "audio": "..."}
```

**Modifications nécessaires :**
- **Serveur** : Modifier `handle_audio()` pour lire et stocker `session_id`
- **Flutter** : Aucune modification

| Critère | Évaluation |
|---|---|
| **Robustesse** | ⭐⭐⭐⭐ Le session_id est répété, redondant si réseau instable |
| **Simplicité** | ⭐⭐⭐⭐⭐ Aucune modification Flutter |
| **Compatibilité future** | ⭐⭐⭐ Permet de changer de session à chaque message |
| **Mode conversation** | ⭐⭐⭐⭐ Session_id présent à chaque tour |
| **Reconnexion réseau** | ⭐⭐⭐⚠️ Buffer STT est global, pas par session |
| **Maintenance** | ⭐⭐⭐ Logique implicite, moins claire |

---

### ⚠️ Risque critique identifié sur Option B

**Le STTService utilise un buffer global (`self.audio_buffer`) partagé entre TOUS les clients WebSocket.**

```python
# stt_service.py:349
self.audio_buffer = bytearray()  # Buffer to accumulate audio chunks
```

**Conséquence :** Si 2 utilisateurs se connectent simultanément, leurs audio se mélangent dans le même buffer.

**Pour la conversation continue :** Le buffer global est vidé après chaque transcription. Un changement de `session_id` dans un message audio ne résout pas le problème d'audio entremêlé.

---

### Tableau comparatif complet

| | **OPTION A** | **OPTION B** |
|---|---|---|
| **Lignes de code à modifier** | ~10 (Flutter) | ~5 (Serveur) |
| **Lignes de code à tester** | ~20 | ~15 |
| **Complexité** | Moyenne | Faible |
| **Alignement avec code existant** | Correspond à `handle_session_id()` déjà présent | Nécessite de modifier `handle_audio()` |
| **Support multi-utilisateur** | ⚠️ Nécessite buffer STT par session | ⚠️ Nécessite buffer STT par session |
| **Support reconnexion** | ✅ Renver `session_id` après reconnect | ⚠️ Buffer STT global perdu |
| **Clarté du protocole** | ✅ Explicite | ⚠️ Implicite |
| **Durée d'implémentation** | ~30 min | ~15 min |

---

### Verdict intermédiaire

**Option A est techniquement supérieure** pour :
- Protocole explicite et maintenable
- Gestion des reconnections
- Conversation continue

**Option B est plus rapide à implémenter** mais :
- Masque le problème du buffer STT global
- Crée une dépendance implicite session_id ↔ audio
