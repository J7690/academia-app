# BOBODO — PLAN D'EXÉCUTION MIGRATION MEDIUM → SMALL

## Date : 14 Juin 2026

---

## Mission 1 — Modifications exactes

### Fichier unique à modifier

| Fichier | Chemin serveur |
|---|---|
| `.env` | `/opt/bobodo-vocal/.env` |

### Ligne à modifier

```
# AVANT
WHISPER_MODEL=medium

# APRÈS
WHISPER_MODEL=small
```

### Vérification du code qui lit cette variable

```python
# @/opt/bobodo-vocal/main.py:29
whisper_model: str = "tiny"   # default dans Settings, écrasé par .env
```

```python
# @/opt/bobodo-vocal/stt_service.py (v2 déployé):143
def __init__(self, model_size: str = "medium", device: str = "cpu", compute_type: str = "int8"):
```

Le `STTService` est instancié dans `main.py:67` avec `STTService()` — il utilise le default `"medium"`.

**Problème :** Le `.env` définit `WHISPER_MODEL=medium` mais le `STTService.__init__` a `model_size: str = "medium"` en dur. Il faut vérifier si `settings.whisper_model` est passé au constructeur.

### Vérification du passage de paramètre

```python
# @/opt/bobodo-vocal/main.py:67
stt_service = STTService()
```

**Le modèle n'est PAS passé depuis settings.** `STTService()` utilise le default `"medium"`.

### Modifications nécessaires

| # | Fichier | Ligne | Action |
|---|---|---|---|
| 1 | `/opt/bobodo-vocal/.env` | `WHISPER_MODEL=` | Changer `medium` → `small` |
| 2 | `/opt/bobodo-vocal/main.py` | 67 | Changer `STTService()` → `STTService(model_size=settings.whisper_model)` |

**C'est tout.** Aucune autre modification.

### Variables d'environnement concernées

| Variable | Valeur actuelle | Nouvelle valeur |
|---|---|---|
| `WHISPER_MODEL` | `medium` | `small` |

### Paramètres Faster Whisper concernés

| Paramètre | Valeur actuelle | Nouvelle valeur |
|---|---|---|
| `model_size` | `"medium"` | `"small"` |
| `device` | `"cpu"` | `"cpu"` (inchangé) |
| `compute_type` | `"int8"` | `"int8"` (inchangé) |
| `beam_size` | `5` | `5` (inchangé) |
| `language` | `"fr"` | `"fr"` (inchangé) |

---

## Mission 2 — Risques de régression

| # | Composant | Risque | Impact | Probabilité | Validation |
|---|---|---|---|---|---|
| 1 | **STT** | WER augmenté (44.1% vs 5% sur expressions isolées) | Modéré | 100% (attendu) | Test transcription 5 phrases |
| 2 | **STT** | Modèle Small ne se charge pas | Critique | Très faible | Log `[STT_MODEL_READY]` au démarrage |
| 3 | **WebSocket** | Aucun changement de code WS | Nul | 0% | Test ping/pong |
| 4 | **Multi-session** | Aucun changement — `STTSession` reste identique | Nul | 0% | Test 2 users simultanés |
| 5 | **Mémoire** | RAM réduite (1.1 GB vs 2.8 GB) | **Positif** | 100% | `systemctl status` — Memory |
| 6 | **Conversation continue** | Le changement de modèle n'affecte pas la boucle de silence/transcription | Nul | 0% | Conversation 3 échanges |
| 7 | **BobodoClient** | Aucun changement | Nul | 0% | Réponse Edge Function reçue |
| 8 | **Edge Function** | Aucun changement | Nul | 0% | Reply non-null |
| 9 | **TTS** | Aucun changement | Nul | 0% | audio_response reçu |
| 10 | **Latence** | Réduite de ~7.3s à ~2.8s | **Positif** | 100% | Mesure T_transcription |

### Risque réel unique

**Le seul risque réel est la qualité de transcription (WER plus élevé).** Mais :
- Les termes critiques (Academia, Burkina Faso, orientation, bourses) sont correctement transcrits par Small (prouvé par benchmark)
- "Bobodo" est partiellement reconnu → corrigeable par dictionnaire
- Toute l'architecture (WebSocket, multi-session, Bobodo, TTS) est **indépendante du modèle**

---

## Mission 3 — Protocole de validation post-migration

### Séquence de tests (exécuter dans l'ordre)

| # | Test | Critère de succès | Durée | Script existant |
|---|---|---|---|---|
| 1 | Service démarre | `systemctl is-active` = `active` | 10s | Manuel |
| 2 | Logs modèle | `[STT_MODEL_READY] Model loaded` + vérifier "small" | 10s | `journalctl` |
| 3 | RAM vérification | Memory < 1.5 GB (vs 2.1 GB avant) | 10s | `systemctl status` |
| 4 | **1 user — pipeline complet** | Transcription + audio_response reçus | 30s | `test_single_v3.py` |
| 5 | **2 users simultanés** | 2 transcriptions uniques + 2 audio_response | 60s | `test_multi_session_v4.py` |
| 6 | **3 users simultanés** | 3 transcriptions uniques + 3 audio_response | 90s | `test_multi_session_v4.py` |
| 7 | **Conversation continue** | ≥3 échanges consécutifs avec transcription + réponse | 120s | `test_conversation_v2.py` |
| 8 | **Reconnexion réseau** | Reconnexion OK + transcription après reconnexion | 30s | `test_resilience.py` |
| 9 | **Latence** | T_transcription < 4s (vs 8s avec Medium) | 30s | `latency_audit.py` |
| 10 | **Contamination** | 0 mélange sur test 3 users | 90s | Inclus dans test #6 |

### Critères d'échec (rollback immédiat)

| Critère | Seuil | Action |
|---|---|---|
| Service ne démarre pas | Échec démarrage | Rollback |
| 0 transcription reçue | Test #4 échoue | Rollback |
| Mélange détecté | Test #6 = contamination | Rollback |
| WebSocket disconnect | Déconnexion spontanée | Rollback |
| RAM > 3 GB | Fuite mémoire | Rollback |

---

## Mission 4 — Plan de rollback

### Procédure exacte (< 5 minutes)

```bash
# Étape 1 — Restaurer .env (10 secondes)
sed -i 's/WHISPER_MODEL=small/WHISPER_MODEL=medium/' /opt/bobodo-vocal/.env

# Étape 2 — Restaurer main.py si modifié (10 secondes)
cp /opt/bobodo-vocal/main.py.backup /opt/bobodo-vocal/main.py

# Étape 3 — Redémarrer le service (10 secondes)
systemctl restart bobodo-vocal

# Étape 4 — Vérifier (10 secondes)
systemctl is-active bobodo-vocal
journalctl -u bobodo-vocal --since='30 seconds ago' | grep MODEL_READY
```

### Fichiers concernés par le rollback

| Fichier | Backup | Restauration |
|---|---|---|
| `/opt/bobodo-vocal/.env` | Ligne `WHISPER_MODEL=medium` | `sed` commande |
| `/opt/bobodo-vocal/main.py` | `main.py.backup` (créé avant migration) | `cp` |

### Durée totale rollback : **< 1 minute**

### Pré-requis rollback

Avant la migration, créer les backups :
```bash
cp /opt/bobodo-vocal/.env /opt/bobodo-vocal/.env.backup_medium
cp /opt/bobodo-vocal/main.py /opt/bobodo-vocal/main.py.backup
```

---

## Mission 5 — Métriques de succès

### Critères obligatoires (tous doivent être validés)

| # | Métrique | Seuil minimum | Méthode de mesure |
|---|---|---|---|
| 1 | **Stabilité service** | Active sans crash pendant 5 min | `systemctl is-active` |
| 2 | **Contamination** | = 0 | Test 3 users → 3 transcriptions uniques |
| 3 | **Erreurs WebSocket** | = 0 | Logs `journalctl` — aucun "WebSocket error" |
| 4 | **Conversation continue** | = 100% (≥3/3 échanges) | Test conversation |
| 5 | **Latence moyenne** | < 7 secondes pipeline complet | Mesure T0→audio_response |
| 6 | **Latence STT seule** | < 4 secondes | Mesure T0→transcription |
| 7 | **RAM** | < 1.5 GB | `systemctl status` |
| 8 | **Transcription fonctionne** | ≥1 transcription correcte | Test single user |
| 9 | **Audio response reçue** | ≥1 audio_response | Test single user |
| 10 | **Reconnexion** | Fonctionne après coupure | Test resilience |

### Comparaison attendue AVANT/APRÈS

| Métrique | Medium (AVANT) | Small (APRÈS attendu) | Source |
|---|---|---|---|
| Latence STT | 7.28s | **~2.8s** | `small_load_test.json` |
| Latence pipeline | 12.7s | **~6.5s** | Calcul : 2.8 + 2.9 + 0.9 |
| RAM | 2.1 GB | **~1.1 GB** | `BOBODO_STT_MODEL_COMPARISON.md` |
| Multi-session | ✅ | ✅ (inchangé) | Même code |
| Conversation | ✅ | ✅ (inchangé) | Même code |

---

## Livrable final

### **GO MIGRATION SMALL**

### Justification

| Critère | Évaluation |
|---|---|
| **Risque technique** | Quasi-nul — seul le modèle change, pas l'architecture |
| **Rollback** | < 1 minute — backup + sed + restart |
| **Gain latence** | -4.4s mesuré (7.3s → 2.8s STT) |
| **Gain RAM** | -1.7 GB (2.8 GB → 1.1 GB) |
| **Perte qualité** | Acceptable — termes critiques OK, dictionnaire post-transcription prévu |
| **Impact multi-session** | Aucun — code identique |
| **Impact pipeline** | Aucun — BobodoClient, Edge Function, TTS inchangés |
| **Scripts de test** | Existants et réutilisables |
| **Données de référence** | Complètes (5 benchmarks, latence mesurée, load test fait) |

**La migration est une opération de 2 modifications (`.env` + `main.py`), validable en 5 minutes, rollback en 1 minute. Le gain est de -4.4s de latence et -1.7 GB de RAM. Le seul risque (qualité WER) est documenté et acceptable.**
