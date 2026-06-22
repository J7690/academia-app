# BOBODO_STT_AUDIT_MASTER

## Audit complet de la latence STT — Rapport final

---

### Date
2026-06-13

---

### Objectif

Identifier précisément pourquoi le moteur STT consomme **~10.1 secondes** alors que Bobodo (LLM) + TTS consomment **~2.9 secondes**.

---

### Résumé exécutif

**Verdict :** La latence STT est dominée à **90%** par l'inférence du modèle Faster Whisper "medium" sur CPU. Les 10% restants sont un seuil de silence artificiel fixé à 1 seconde.

**Le réseau et le disque sont négligeables (<0.1%).**

**Problème critique supplémentaire :** Le buffer audio global persiste entre connexions WebSocket, provoquant des transcriptions erronées et des timeouts.

---

### Architecture mesurée

```
[Flutter] ──WS──► [Kamatera] 
                    ├── Buffer audio (RAM, global)
                    ├── Attente silence 1000ms
                    ├── Écriture WAV temp (/tmp)
                    ├── Faster Whisper medium (CPU)
                    └── Retour transcription (WS)
```

---

### Données brutes

| Test | Audio (s) | PCM (bytes) | STT (ms) | Whisper (ms) | Silence (ms) | Résultat |
|---|---|---|---|---|---|---|
| short (1.39s) | 1.39 | 44 544 | — | — | — | ❌ Timeout |
| medium (2.95s) | 2.95 | 94 464 | 10 064 | ~8 952 | 1 001 | ✅ (buffer accumulé) |
| long (4.99s) | 4.99 | 159 744 | 10 142 | ~9 128 | 1 001 | ✅ |

---

### Décomposition des 10.1 secondes

```
10 142 ms TOTAL
├── 9 128 ms (90.0%) │  Inférence Whisper medium sur CPU
│                      │  Code: model.transcribe(audio_path, beam_size=5)
│                      │  Modèle: 1.5 GB, CPU Xeon 4 cœurs @ 2.0GHz
│
├── 1 001 ms (9.9%)  │  Seuil de silence artificiel
│                      │  Code: silence_threshold_ms = 1000
│                      │  Log: "STT_SILENCE_CANCELLED New audio received (999ms < 1000ms)"
│
└──   13 ms (0.1%)   │  Réseau + WS + fichiers temporaires
                       │  Disque: 566 MB/s, pas un goulot
```

---

### Preuves collectées

| # | Preuve | Source |
|---|---|---|
| 1 | Timestamp transcribe_start → transcribe_end = 9.128s | `journalctl -u bobodo-vocal` |
| 2 | Modèle chargé une seule fois | PID 148819, RSS 1.7 GB, un seul log `[STT_MODEL_READY]` |
| 3 | Seuil de silence = 1000ms | `stt_service.py:33` |
| 4 | Audio écrit sur disque | `stt_service.py:127-132` (tempfile) |
| 5 | Buffer global persistant | `stt_service.py:30` (bytearray jamais reset entre sessions) |
| 6 | Transcriptions mélangées | Trial 2 : "Bonjour Bobodo... Quelle est la capitale..." |
| 7 | Disk I/O 566 MB/s | `dd if=/dev/zero of=/tmp/test_write` |
| 8 | CPU 4 cœurs Xeon 2.0GHz | `lscpu` |

---

### Livrables produits

| Mission | Fichier | Contenu |
|---|---|---|
| 1 | `BOBODO_STT_LATENCY_BREAKDOWN.md` | Décomposition des 10.1s par étape |
| 2 | `BOBODO_STT_CONVERSATIONS_MEASURED.md` | 5 conversations réelles avec métriques audio |
| 3 | `BOBODO_STT_INTERNAL_TIMING.md` | Timing interne de stt_service.py |
| 4 | `BOBODO_STT_MODEL_RELOAD.md` | Preuve que le modèle n'est pas rechargé |
| 5 | `BOBODO_STT_MEMORY_VS_DISK.md` | Analyse mémoire vs disque |
| 6 | `BOBODO_STT_CAUSES_RANKING.md` | Classement des causes avec pourcentages |

---

### Conclusion

Les **8.4-10.1 secondes** de latence STT s'expliquent par :

1. **Inférence CPU lente** (90%) : Faster Whisper medium sur Xeon 4 cœurs = ~1.8x temps réel
2. **Silence threshold** (10%) : 1 seconde artificielle ajoutée systématiquement

**Le disque n'est pas en cause.**
**Le réseau n'est pas en cause.**
**Le modèle n'est pas rechargé à chaque requête.**

---

### Recommandations (hors scope de l'audit mais déduites des preuves)

| Priorité | Action | Gain estimé | Risque |
|---|---|---|---|
| P1 | Réduire `beam_size` de 5 à 1 | -60 à -70% latence | Légère perte de précision |
| P1 | Réinitialiser `audio_buffer` à chaque nouvelle connexion WS | Fiabilité | Aucun |
| P2 | Réduire `silence_threshold_ms` de 1000 à 300-500 | -500 à -700ms | Faux déclenchements possibles |
| P2 | Passer à `tiny` ou `base` au lieu de `medium` | -80% latence | Perte de précision significative |
| P3 | Streaming STT (transcription partielle) | Latence perçue ~200ms | Refonte architecturale majeure |
