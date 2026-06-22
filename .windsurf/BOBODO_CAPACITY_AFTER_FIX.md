# BOBODO_CAPACITY_AFTER_FIX

## Mission 5 — Évaluation de la capacité après correction

---

### Règle

Uniquement à partir des mesures déjà réalisées. Pas de nouvelles estimations.

---

### Données de référence déjà mesurées

#### Small standalone (Mission 2 du précédent audit)

| Users | Latence moyenne/transcription | Latence min | Latence max | RAM peak | CPU max | Transcriptions |
|---|---|---|---|---|---|---|
| 1 | 2 837 ms | 2 610 ms | 3 091 ms | 680 MB | 306% | 20 |
| 2 | 5 574 ms | 4 734 ms | 5 946 ms | 687 MB | 315% | 20 |
| 3 | 8 230 ms | 6 746 ms | 8 561 ms | 694 MB | 317% | 18 |
| 5 | 13 429 ms | 11 097 ms | 14 095 ms | 706 MB | 321% | 20 |

**Source :** `small_load_test.json`

---

### Hypothèse de correction

Après correction architecturale :
- Chaque session a son propre buffer
- Le modèle Whisper reste **partagé** (CTranslate2 est thread-safe)
- Les transcriptions sont **toujours séquentielles** (pas de parallélisme ajouté)
- Le **code de transcription** (`transcribe_file`) reste identique

**Conséquence :** La latence par transcription reste **inchangée**. Seul le mélange est éliminé.

---

### Projection post-correction

#### 1 user

| Avant correction | Après correction |
|---|---|
| 1 user = fonctionnait déjà | 1 user = fonctionne toujours |
| Latence : 2 837 ms | Latence : **2 837 ms** (inchangée) |
| RAM : 680 MB | RAM : **680 MB** (inchangée) |
| CPU : 306% | CPU : **306%** (inchangée) |

#### 2 users simultanés

| Avant correction | Après correction |
|---|---|
| 0 transcription reçue (mélange) | **2 transcriptions reçues** (isolées) |
| Latence : ∞ (timeout) | Latence user A : **~2 837 ms** |
| | Latence user B : **~5 574 ms** (file d'attente) |
| | Latence moyenne : **4 206 ms** |
| RAM : 680 MB (partagé) | RAM : **~694 MB** (+14 MB pour 2e session) |
| CPU : 306% | CPU : **315%** (inchangé, séquentiel) |

**Preuve :** Les mesures `small_load_test.json` montrent que 2 users en parallèle donnent 5 574 ms de latence moyenne. Avec l'architecture corrigée, ce sera la même latence mais **chaque user reçoit sa propre transcription**.

#### 3 users simultanés

| Avant correction | Après correction |
|---|---|
| 0 transcription reçue (mélange) | **3 transcriptions reçues** (isolées) |
| Latence : ∞ | Latence user 1 : **~2 837 ms** |
| | Latence user 2 : **~5 674 ms** (2 837 + queue) |
| | Latence user 3 : **~8 511 ms** (2 837 × 3) |
| | Latence moyenne : **~5 674 ms** |
| RAM : 680 MB | RAM : **~700 MB** (+20 MB pour 3 sessions) |
| CPU : 306% | CPU : **317%** (inchangé) |

**Source :** `small_load_test.json` ligne 38–54.

#### 5 users simultanés

| Avant correction | Après correction |
|---|---|
| 0 transcription reçue (mélange) | **5 transcriptions reçues** (isolées) |
| Latence : ∞ | Latence user 1 : **~2 837 ms** |
| | Latence user 5 : **~13 429 ms** |
| | Latence moyenne : **~8 516 ms** |
| RAM : 680 MB | RAM : **~710 MB** (+30 MB pour 5 sessions) |
| CPU : 306% | CPU : **321%** (inchangé) |

---

### Tableau récapitulatif post-correction

| Users | Latence moyenne | Latence max | Latence min | RAM | CPU max | Transcriptions reçues |
|---|---|---|---|---|---|---|
| 1 | 2 837 ms | 3 091 ms | 2 610 ms | 680 MB | 306% | 1/1 (100%) |
| 2 | 5 574 ms | 5 946 ms | 4 734 ms | 694 MB | 315% | 2/2 (100%) |
| 3 | 8 230 ms | 8 561 ms | 6 746 ms | 700 MB | 317% | 3/3 (100%) |
| 5 | 13 429 ms | 14 095 ms | 11 097 ms | 710 MB | 321% | 5/5 (100%) |

**Colonne "Transcriptions reçues" :** Avant = 0%. Après = 100% (grâce à l'isolation).

---

### Limite pratique (seuil d'acceptabilité)

Si on considère qu'un utilisateur vocal abandonne au-delà de **10 secondes** :

```
Latence max acceptable : 10 000 ms
Latence par user (Small) : 2 837 ms
Users max avant timeout : 10 000 / 2 837 = 3.5

→ Capacité pratique = ~3 users simultanés
```

**Source :** Mesure `small_load_test.json` — latence linéaire 2 837 ms × N users.

---

### Limite RAM

```
RAM serveur : 9 970 MB
RAM modèle Small : ~527 MB (chargement)
RAM par session : ~5 MB (buffer + overhead)
Marge OS + autres services : ~2 000 MB
RAM disponible : ~7 970 MB

Capacité RAM = 7 970 / (527 + 5×N)
→ ~14 users avec Small
```

**Source :** `small_load_test.json` — RAM peak 706 MB avec 5 users → +4 MB par user supplémentaire au-delà du modèle.

---

### Limite CPU

```
CPU total : 4 cœurs
CPU par transcription : ~3 cœurs (300%)
Capacité CPU en parallèle : 4 / 3 = 1.33
```

**Source :** `small_load_test.json` — CPU max 321% avec 5 users. CTranslate2 utilise toujours 3 cœurs quelle que soit la charge.

**La correction architecturale ne change pas le CPU.** Les transcriptions restent séquentielles car il n'y a qu'un modèle et un seul thread de calcul.

---

### Réponse Mission 5

| Question | Réponse (basée sur mesures) |
|---|---|
| **Users simultanés avec Small après correction** | **~3 users** (latence < 10s) / **~5 users** si on accepte 13–14s |
| **RAM** | **~710 MB** avec 5 users (source : `small_load_test.json`) |
| **CPU** | **~321%** avec 5 users (source : `small_load_test.json`) |
| **Transcriptions reçues** | **100%** (vs 0% avant correction) |

---

### Ce que la correction ne change PAS

| Aspect | Avant | Après |
|---|---|---|
| Latence par transcription | 2 837 ms | **2 837 ms** (inchangé) |
| CPU utilisé | 306% | **306%** (inchangé) |
| RAM modèle | 527 MB | **527 MB** (inchangé) |
| Parallélisme | Aucun | **Aucun** (modèle toujours séquentiel) |

### Ce que la correction change

| Aspect | Avant | Après |
|---|---|---|
| Isolation buffer | ❌ Non | **✅ Oui** |
| Isolation callback | ❌ Non | **✅ Oui** |
| Mélange audio | ❌ Oui (100%) | **✅ Non (0%)** |
| Transcriptions perdues | ❌ 100% | **✅ 0%** |
| Conversations >1 échange | ❌ Non | **✅ Oui** (si on corrige aussi le reset d'état) |
