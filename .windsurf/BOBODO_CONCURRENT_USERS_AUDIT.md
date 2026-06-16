# BOBODO_CONCURRENT_USERS_AUDIT

## Mission 6 — Audit concurrence multi-utilisateurs

---

### Date
2026-06-13

---

### Méthodologie

Tests exécutés directement sur le serveur Kamatera. Chaque utilisateur :
1. Se connecte au WebSocket `ws://localhost:8000/ws`
2. Envoie son `session_id`
3. Envoie son audio (gTTS converti en PCM16 16kHz)
4. Attend la transcription (timeout 35s)

Les tests sont lancés **simultanément** via `asyncio.gather()`.

---

### Test 1 — 2 utilisateurs simultanés

**Phrases envoyées :**
- user-1 : "Bonjour Bobodo"
- user-2 : "Quelle est la capitale"

**Résultats :**

```
user-1: 35384ms | FAIL (timeout après 35s)
user-2: 8730ms | OK
  Trans: 'Bonjour Bobodo, quelle est la capitale ?'
```

**Analyse :**
- user-1 a timeout (attendu 35s sans réponse)
- user-2 a reçu une transcription en 8.7s
- **La transcription contient les 2 phrases** (user-1 + user-2)
- user-2 a reçu l'audio de user-1 dans SA transcription

**Conclusion Test 1 :** ❌ Pas d'isolation. user-2 reçoit les données de user-1.

---

### Test 2 — 3 utilisateurs simultanés

**Phrases envoyées :**
- user-1 : "Bonjour Bobodo"
- user-2 : "Quelle est la capitale"
- user-3 : "Explique la photosynthese"

**Résultats :**

```
user-1: 35715ms | FAIL (timeout)
user-2: 35461ms | FAIL (timeout)
user-3: 35178ms | FAIL (timeout)
```

**Analyse :**
- **TOUS les utilisateurs ont timeout** après ~35 secondes
- Aucun n'a reçu de transcription
- Le silence threshold (1000ms) ne s'est pas déclenché correctement car les audio arrivaient en parallèle
- Ou le callback n'a pas été appelé car écrasé

**Conclusion Test 2 :** ❌ Système complètement inopérant avec 3 utilisateurs simultanés.

---

### Test 3 — 5 utilisateurs simultanés

**Phrases envoyées :**
- user-1 : "Bonjour Bobodo"
- user-2 : "Quelle est la capitale"
- user-3 : "Explique la photosynthese"
- user-4 : "Donne-moi un conseil de revision"
- user-5 : "Comment postuler sur Academia"

**Résultats :**

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

**Analyse :**
- 4 utilisateurs sur 5 ont **timeout** (~36s)
- **user-5 est le seul à recevoir une réponse** (13.3s)
- **La transcription contient les 5 phrases** — preuve absolue de mélange
- Certaines phrases apparaissent **en double** (user-1 et user-2 répétés)
- user-5 était probablement le **dernier à se connecter** et a donc écrasé le callback des autres

**Conclusion Test 3 :** ❌❌❌ Système catastrophiquement défaillant. 80% de timeout, 100% de mélange.

---

### Synthèse des résultats

| Utilisateurs | Timeout | Réponse OK | Mélange détecté | Verdict |
|---|---|---|---|---|
| 1 (référence) | 0% | 100% | Non | ✅ OK |
| 2 | 50% | 50% | **OUI** (100% des OK) | ❌ ÉCHEC |
| 3 | 100% | 0% | Oui (implicite) | ❌❌ ÉCHEC TOTAL |
| 5 | 80% | 20% | **OUI** (100% des OK) | ❌❌❌ CATASTROPHE |

---

### Explication technique du comportement

**Avec 1 utilisateur :**
```
WS1 connecte → stt_service.set_callback(callback_A)
WS1 envoie audio → buffer = [audio_A]
silence → transcription_A → callback_A → WS1 reçoit transcription_A
```

**Avec 2 utilisateurs simultanés :**
```
WS1 connecte → stt_service.set_callback(callback_A)
WS2 connecte → stt_service.set_callback(callback_B)  ← ÉCRASE callback_A
WS1 envoie audio → buffer = [audio_A]
WS2 envoie audio → buffer = [audio_A + audio_B]
silence → transcription(A+B) → callback_B → WS2 reçoit "A+B"
WS1 attend en vain → timeout (son callback a été écrasé)
```

**Avec 5 utilisateurs simultanés :**
```
WS1..WS5 se connectent en rafale
callback est écrasé 5 fois → seul WS5 a un callback actif
buffer accumule audio_A + audio_B + audio_C + audio_D + audio_E
silence → transcription(A+B+C+D+E) → callback_E → WS5 reçoit TOUT
WS1..WS4 attendent en vain → timeout
```

---

### Conclusion

**Bobodo Voice ne supporte PAS la concurrence multi-utilisateurs.**

Les causes sont architecturales et irréparables sans modification majeure :

1. **Buffer audio global** (`audio_buffer` partagé entre toutes les WS)
2. **Callback unique** (écrasé par chaque nouvelle connexion)
3. **Transcription séquentielle** (le modèle ne peut traiter qu'un audio à la fois)
4. **Timeout brutal** (35s sans réponse pour les utilisateurs non-connectés en dernier)

**Le système est conçu pour un utilisateur unique.**
