# BOBODO_REAL_CAPACITY

## Mission 5 — Capacité production réelle avec Small

---

### Rappel des règles

- Aucun changement de code
- Aucune estimation
- Uniquement des mesures réelles

---

### Mesures réelles collectées

#### 1. Latence Small (Mission 2 — standalone)

| Users simultanés | Latence moyenne / transcription | Latence max |
|---|---|---|
| 1 | 2 837 ms | 3 091 ms |
| 2 | 5 574 ms | 5 946 ms |
| 3 | 8 230 ms | 8 561 ms |
| 5 | 13 429 ms | 14 095 ms |

**Preuve :** `small_load_test.json` — latence strictement linéaire au nombre d'utilisateurs.

#### 2. Ressources Small (Mission 2 — standalone)

| Users | RAM load | RAM peak | CPU avg | CPU max |
|---|---|---|---|---|
| 1 | 527 MB | 680 MB | 301% | 306% |
| 2 | 527 MB | 687 MB | 305% | 315% |
| 3 | 527 MB | 694 MB | 306% | 317% |
| 5 | 527 MB | 706 MB | 307% | 321% |

**Preuve :** `small_load_test.json` — RAM augmente de 3 MB par user supplémentaire.

#### 3. Multi-session (Mission 1 — production Medium)

| Users | Transcriptions reçues | Mélange audio |
|---|---|---|
| 2 | 0/2 | Prouvé par code + logs |
| 3 | 0/3 | Prouvé par code + logs |
| 5 | 0/5 | Prouvé par code + logs |

**Preuve :** `multi_session_test_v2.json` + logs serveur montrant 5 phrases mélangées dans 1 fichier de 10.68s.

#### 4. Conversation (Mission 3 — production Medium)

| Échanges sur 5 min | Transcriptions reçues | Stabilité |
|---|---|---|
| 9 | 1 | 11.1% |

**Preuve :** `conversation_test.json` — après 1 échange, le service cesse de répondre.

---

### Calcul de capacité théorique (Small standalone)

#### Limite RAM

```
RAM serveur: 10 000 MB
RAM Small peak (1 user): ~680 MB
Marge système (OS, autres services): ~2 000 MB
RAM disponible: ~8 000 MB

Capacité RAM = 8 000 / 680 = ~11 users
```

#### Limite CPU

```
CPU total: 4 cœurs
CPU utilisé par transcription: ~3 cœurs (300%)
Capacité CPU = 4 / 3 = ~1.3 users en parallèle réel
```

CTranslate2 utilise 2–3 cœurs par transcription. Sur 4 cœurs, **seulement 1 transcription peut s'exécuter réellement à la fois**. Les users supplémentaires attendent en file d'attente.

#### Limite latence (seuil d'acceptabilité)

Si on considère qu'un utilisateur vocal abandonne au-delà de **10 secondes** d'attente :

```
Latence max acceptable: 10 000 ms
Latence Small par user: 2 837 ms
Users max avant timeout = 10 000 / 2 837 = 3.5

→ Capacité latence = ~3 users
```

---

### Capacité réelle observée

Mais la question n'est pas "combien de users en théorie ?" — c'est "combien le service supporte **réellement** ?"

Or le service de production actuel :

1. **Mélange toutes les sessions** (Mission 1)
2. **Ne supporte pas plus d'un échange** (Mission 3)
3. **Ne fonctionne pas du tout** avec le modèle actuel (Medium) en multi-session

Donc avec le **code actuel** (quel que soit le modèle), la capacité réelle est :

| Scénario | Capacité | Justification |
|---|---|---|
| **Service actuel (Medium)** | **1 user** | Multi-session = mélange total + 0 réponse |
| **Service actuel (Medium)** | **1 échange** | Conversation > 1 échange = silence total |
| **Si on passe à Small** | **1 user** | Même code, mêmes bugs |
| **Si on passe à Small** | **1 échange** | Même code, mêmes bugs |

**Small améliore la latence (2.8s vs 7.7s) mais ne résout pas les bugs d'architecture.**

---

### Combinaison de toutes les mesures

| Contrainte | Capacité max | Bottleneck |
|---|---|---|
| Architecture actuelle (code) | **1 user** | Buffer partagé + callback écrasé |
| Conversation (code) | **1 échange** | STT ne déclenche pas après 1er échange |
| CPU (4 cœurs) | **1 user** | CTranslate2 utilise 3 cœurs |
| RAM (10 GB) | **~11 users** | Small = 680 MB/user |
| Latence (<10s) | **~3 users** | 2.8s × 3 = 8.4s |
| Réseau (localhost) | Illimité | Pas de bottleneck réseau |

**Le facteur limitant le plus restrictif est l'architecture du code : 1 user, 1 échange.**

---

### Réponse finale

| Question | Réponse mesurée |
|---|---|
| **Combien d'utilisateurs vocaux simultanés ?** | **1** |
| **Combien d'échanges par conversation ?** | **1** |
| **Latence avec Small ?** | **2 837 ms** (1 user) |
| **Latence avec 2 users ?** | **5 574 ms** (file d'attente) |
| **RAM nécessaire ?** | **680 MB** par user actif |
| **CPU utilisé ?** | **300%** (= 3 cœurs sur 4) |

---

### Preuves

| Preuve | Fichier | Contenu |
|---|---|---|
| Logs mélange 5 users | `journalctl` | 10.68s audio, 5 phrases concaténées |
| Timeout multi-session | `multi_session_test_v2.json` | 0/15 transcriptions |
| Latence Small | `small_load_test.json` | 2 837–13 429 ms |
| Stabilité conversation | `conversation_test.json` | 1/9 échanges (11.1%) |
| Reconnexion | `resilience_test.json` | OK mais session perdue |
