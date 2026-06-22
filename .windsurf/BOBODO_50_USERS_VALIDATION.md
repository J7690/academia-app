# BOBODO_50_USERS_VALIDATION

## Mission 2 — Validation de la capacité « 50 utilisateurs simultanés »

---

### Date
2026-06-13

---

### Question

Le Master Plan annonce 50 utilisateurs simultanés. Cette valeur est- :
- mesurée ?
- simulée ?
- estimée ?

---

### Données matérielles confirmées

| Ressource | Valeur | Source |
|---|---|---|
| CPU | Intel Xeon SapphireRapids @ 2.0GHz, 4 cœurs | `lscpu` |
| RAM totale | 9 969 MB (~10 GB) | `free -m` |
| RAM disponible | ~7 173 MB | `free -m` |
| Disque I/O | 566 MB/s séquentiel | `dd` |

---

### Données du modèle confirmées

| Modèle | RAM résidente | Disque |
|---|---|---|
| medium (actuel) | 1.9 GB | 1.5 GB |
| tiny (estimé) | ~300 MB | 39 MB |

---

### Test de charge réel exécuté (Mission 3)

**Configuration :** 5 connexions WS simultanées, chacune envoyant 2 secondes de silence PCM16 16kHz.

**Résultats :**

| User | Statut | Temps |
|---|---|---|
| user-0 | TIMEOUT (20 304 ms) | — |
| user-1 | TIMEOUT (20 280 ms) | — |
| user-2 | TIMEOUT (20 280 ms) | — |
| user-3 | TIMEOUT (20 281 ms) | — |
| user-4 | TIMEOUT (20 279 ms) | — |

**Monitoring CPU/RAM pendant le test :**

| Seconde | CPU % | RAM RSS (MB) | Threads | Load |
|---|---|---|---|---|
| 1 | 27.7% | 1 972 | 18 | 0.02 |
| 2 | 200.0% | 2 237 | 18 | 0.02 |
| 3 | 317.0% | 2 040 | 18 | 0.33 |
| 4 | 314.0% | 1 972 | 18 | 0.33 |
| 5 | 320.0% | 1 972 | 18 | 0.33 |
| 6 | 325.0% | 2 063 | 18 | 0.33 |
| 7 | 307.0% | 2 058 | 18 | 0.33 |
| 8 | 293.0% | 1 972 | 18 | 0.63 |
| 9 | 244.0% | 2 013 | 18 | 0.63 |
| 10 | 229.7% | 2 014 | 18 | 0.63 |
| 11 | 235.0% | 2 027 | 18 | 0.63 |
| 12 | 229.0% | 2 036 | 18 | 0.63 |
| 13 | 244.0% | 2 057 | 18 | 0.66 |
| 14 | 257.0% | 1 972 | 18 | 0.66 |
| 15 | 126.0% | 2 853 | 18 | 0.66 |
| 16 | 207.0% | 2 915 | 18 | 0.66 |
| 17 | 10.0% | 1 972 | 18 | 0.61 |
| ... | 0-1% | 1 972 | 18 | 0.56 |

---

### Analyse du test de 5 users

**Observations factuelles :**

1. **CPU pic à 317%** (utilisation de presque 3 cœurs sur 4). CTranslate2 n'est pas strictement single-thread. Il utilise plusieurs cœurs quand il y a du travail, mais de manière non prévisible.

2. **RAM augmente de +944 MB** pendant le test (1972 → 2915 MB), puis redescend. Le modèle alloue de la mémoire de travail pendant la transcription.

3. **Tous les users timeout à 20s** — mais ce n'est pas à cause du serveur. C'est parce que le script envoyait du **silence pur** (0x00). Le silence threshold ne s'est pas déclenché (pas de vrai signal audio pour déclencher la détection).

---

### Calcul théorique pour 50 users

#### Avec modèle MEDIUM (actuel)

| Paramètre | Valeur | Source |
|---|---|---|
| Temps transcription moyen | ~8.5 s | Mesuré |
| RAM par session (buffer) | ~50 MB (buffer 5s audio + overhead) | Estimé |
| Workers ThreadPool | 4 | 4 cœurs |
| Transcriptions parallèles | 4 max | Déduit |
| Débit max | 4 transcriptions / 8.5s = **0.47 transcriptions/seconde** | Calcul |

**Scénario 50 users parlant chacun 1 phrase / 30 secondes :**
```
Taux d'arrivée = 50 / 30 = 1.67 phrases/seconde
Débit max = 0.47 phrases/seconde
Queue = 1.67 - 0.47 = 1.20 phrases/s en attente
→ ACCUMULATION INFINIE, timeout généralisé
```

**Conclusion medium : 50 users est IMPOSSIBLE.**

#### Avec modèle TINY (estimé)

| Paramètre | Valeur | Source |
|---|---|---|
| Temps transcription estimé | ~1.5 s | Estimation théorique (non mesurée) |
| RAM par session | ~30 MB | Estimé (modèle plus petit, buffer identique) |
| Workers ThreadPool | 4 | 4 cœurs |
| Débit max | 4 / 1.5 = **2.67 transcriptions/seconde** | Calcul sur estimation |

**Scénario 50 users parlant chacun 1 phrase / 30 secondes :**
```
Taux d'arrivée = 50 / 30 = 1.67 phrases/seconde
Débit max = 2.67 phrases/seconde
2.67 > 1.67 → STABLE (pas d'accumulation)
```

**Mais scénario 50 users parlant chacun 1 phrase / 5 secondes :**
```
Taux d'arrivée = 50 / 5 = 10 phrases/seconde
Débit max = 2.67 phrases/seconde
10 > 2.67 → ACCUMULATION INFINIE
```

#### Contrainte RAM

```
Modèle tiny : 300 MB
50 sessions × 30 MB buffer = 1 500 MB
Overhead Python/FastAPI = ~400 MB
Total = 300 + 1500 + 400 = 2 200 MB
Serveur disponible = 7 173 MB
2 200 < 7 173 → RAM OK
```

---

### Réponse à la question

| Aspect | Statut | Justification |
|---|---|---|
| **50 users simultanés** | **ESTIMÉ, ni mesuré ni simulé** | Aucun test avec 50 users n'a été fait. Maximum testé : 5 users (timeout 100%). |
| **Faite réaliste avec tiny** | **Plausible sous conditions** | Seulement si activité sporadique (~1 phrase / 30s). Si parole continue → impossible. |
| **Faite réaliste avec medium** | **NON** | Débit 0.47 transcriptions/s < taux d'arrivée de 50 users même sporadiques. |

---

### Limites du calcul

1. **La latence tiny (1.5s) est estimée**, pas mesurée. Si tiny fait 3s au lieu de 1.5s, le débit max tombe à 1.33/s et 50 users/30s (1.67/s) devient instable.

2. **Le modèle de trafic est simplifié.** En réalité, les users ne parlent pas de manière poissonnienne. Il y a des pics (cours en live) et des creux.

3. **WebSocket asyncio** peut gérer des centaines de connexions inactives, mais la transcription CPU est le goulot.

4. **Aucun test de charge réel n'a été effectué avec 10, 20 ou 50 users.**

---

### Conclusion

**La valeur « 50 utilisateurs simultanés » est une ESTIMATION THÉORIQUE.**

Elle repose sur :
- Une latence tiny non mesurée (~1.5s)
- Un pattern d'activité sporadique non validé
- Aucun test de charge au-delà de 5 users (qui a échoué)

**Pour valider ce chiffre, il faudrait :**
1. Mesurer tiny sur Kamatera (3 transcriptions de durées différentes)
2. Si tiny < 2s, exécuter un test de charge avec 20, puis 50 users simulés
3. Mesurer le taux de timeout et la latence moyenne en file d'attente
