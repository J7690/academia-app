# BOBODO_SESSION_ISOLATION_TEST

## Mission 3 — Reproduction du mélange de sessions

---

### Date
2026-06-13

---

### Objectif

Prouver ou infirmer le mélange entre utilisateurs.

---

### Scénario de test

**Session A :** `session-a` envoie "Bonjour Bobodo"  
**Session B :** `session-b` envoie "Quelle est la capitale du Burkina"  
**Session C :** `session-c` envoie "Comment postuler sur Academia"  
**Session D :** `session-d` attend la transcription

---

### Méthodologie

1. Session A se connecte, envoie son audio, se déconnecte **immédiatement** (pas d'attente de réponse)
2. Session B fait de même 500ms plus tard
3. Session C fait de même 500ms plus tard
4. Session D se connecte et attend la transcription

Si les buffers sont isolés, chaque session devrait recevoir SA propre transcription. Si le buffer est global, l'audio des sessions précédentes s'accumulera.

---

### Résultat Test 1 — Isolation directe

**Mission 3 exécutée sur serveur :**

```
[session-a] Sent: 'Bonjour Bobodo' (44544 bytes)
[session-b] Sent: 'Quelle est la capitale du Burkina' (79104 bytes)
[session-c] Sent: 'Comment postuler sur Academia' (74496 bytes)

[FINAL] Connecting session-d to drain accumulated buffer...
[FINAL] Timeout - no transcription received
```

Session D a timeout. Cela indique que le buffer accumulé (44544 + 79104 + 74496 = **198144 bytes**) a déclenché la détection de silence mais la transcription a pris trop de temps pour être retournée dans le délai de 20 secondes.

---

### Résultat Test 2 — Concurrence 2 utilisateurs

**Extrait Mission 6 (2 concurrents) :**

```
user-1: 35384ms | FAIL (timeout)
user-2: 8730ms | OK
  Trans: 'Bonjour Bobodo, quelle est la capitale ?'
```

**user-1** a envoyé : "Bonjour Bobodo"  
**user-2** a envoyé : "Quelle est la capitale"

**user-2 a reçu :** "Bonjour Bobodo, quelle est la capitale ?"

Cette transcription contient **les deux phrases**. L'audio de user-1 a été mélangé avec celui de user-2 dans le buffer global.

---

### Résultat Test 3 — Concurrence 5 utilisateurs (PREUVE DÉFINITIVE)

**Extrait Mission 6 (5 concurrents) :**

```
user-1: 36361ms | FAIL (timeout)
user-2: 36130ms | FAIL (timeout)
user-3: 35842ms | FAIL (timeout)
user-4: 35567ms | FAIL (timeout)
user-5: 13329ms | OK
  Trans: 'Bonjour Bobodo, explique la photosynthese.
           Quelle est la capitale ?
           Bonjour Bobodo, explique la photosynthese.
           Quelle est la capitale ?
           Donne-moi un conseil de revision.
           Comment postuler sur Academia ?'
```

**Preuve irréfutable :** user-5 a reçu une transcription contenant les phrases de **tous les 5 utilisateurs**.

| Utilisateur | Phrase envoyée | Présente dans user-5 ? |
|---|---|---|
| user-1 | "Bonjour Bobodo" | ✅ OUI |
| user-2 | "Quelle est la capitale" | ✅ OUI |
| user-3 | "Explique la photosynthese" | ✅ OUI |
| user-4 | "Donne-moi un conseil de revision" | ✅ OUI |
| user-5 | "Comment postuler sur Academia" | ✅ OUI |

**Certaines phrases apparaissent en DOUBLE** dans la transcription ("Bonjour Bobodo" et "Quelle est la capitale" sont répétées), ce qui indique que le buffer a été transcrit une première fois pendant que de nouveaux paquets arrivaient, puis transcrit à nouveau.

---

### Analyse technique du mélange

**Cause directe :** `audio_buffer` est un `bytearray()` partagé entre toutes les connexions WebSocket (voir `BOBODO_AUDIO_BUFFER_AUDIT.md`).

**Séquence du mélange :**
```
t=0   user-1 connecte, envoie audio, buffer = [audio_user1]
t=0.1 user-2 connecte, envoie audio, buffer = [audio_user1 + audio_user2]
t=0.2 user-3 connecte, envoie audio, buffer = [audio_user1 + audio_user2 + audio_user3]
t=1.0 silence détecté sur buffer accumulé
      transcription = texte(user1) + texte(user2) + texte(user3)
      callback = celui du DERNIER connecté (user-3)
      RÉSULTAT : user-3 reçoit la transcription de TOUT LE MONDE
```

---

### Réponse à la question

> Une session peut-elle recevoir de l'audio provenant d'une autre session ?

# **OUI**

**Preuves :**
1. user-2 a reçu la transcription de user-1 + user-2
2. user-5 a reçu la transcription de user-1 + user-2 + user-3 + user-4 + user-5
3. Le code source prouve que le buffer est global (`main.py` crée une seule instance `STTService`)
4. Le callback est écrasé par chaque nouvelle connexion (`websocket_handler.py:29`)

**Ce n'est pas une fuite de données réseau** (les paquets audio ne sont pas interceptés). C'est un **mélange de données en mémoire** sur le serveur.
