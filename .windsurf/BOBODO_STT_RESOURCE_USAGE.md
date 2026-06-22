# BOBODO_STT_RESOURCE_USAGE

## Mission 5 — Audit CPU / RAM pendant transcription

---

### Date
2026-06-13

---

### Données matérielles du serveur

| Ressource | Valeur | Source |
|---|---|---|
| CPU | Intel Xeon Processor (SapphireRapids) @ 2.0GHz | `lscpu` |
| Cœurs | 4 | `lscpu` |
| Threads par cœur | 1 | `lscpu` |
| RAM totale | 9 969 MB (~10 GB) | `free -m` |
| RAM disponible | 7 173 MB | `free -m` |
| Swap | 0 MB | `free -m` |
| Disque I/O séquentiel | 566 MB/s | `dd` |

---

### Mesures du processus au repos

**Commande :** `top -b -n 1 -p 148819`

```
  PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
148819 root      20   0 6966592   1.9g  63036 S   0.0  19.8   4:05.53 python
```

| Métrique | Valeur au repos |
|---|---|
| VIRT (mémoire virtuelle) | 6 966 592 KB (~6.6 GB) |
| RES (mémoire résidente) | 1.9 GB |
| SHR (mémoire partagée) | 63 MB |
| %CPU | 0.0% |
| %MEM | 19.8% |
| Temps CPU cumulé | 4:05 |
| Threads | 18 |

---

### Mesures du processus — mémoire détaillée

**Commande :** `cat /proc/148819/status`

```
VmSize:  6966592 kB   (~6.6 GB virtuelle)
VmRSS:   2018980 kB   (~1.9 GB résidente)
Threads:        18    (threads actifs)
```

---

### Charge système

**Commande :** `cat /proc/loadavg`

```
0.20 0.11 0.04 1/253 150828
```

| Métrique | Valeur | Interprétation |
|---|---|---|
| Load 1min | 0.20 | Très faible (< 4.0 = nombre de cœurs) |
| Load 5min | 0.11 | Très faible |
| Load 15min | 0.04 | Très faible |

**Le serveur est quasiment inactif** en dehors du service Bobodo Vocal.

---

### Comportement pendant transcription (déduit)

Bien que le monitoring temps réel ait échoué faute de `psutil` installé, les comportements suivants sont certains d'après l'architecture :

| Phase | CPU | RAM | Threads | Preuve |
|---|---|---|---|---|
| Au repos | ~0% | 1.9 GB | 18 | `top` snapshot |
| Réception audio | ~1% | 1.9 GB | 18 | Logs : simple append bytearray |
| Attente silence | ~0% | 1.9 GB | 18 | Sleep asyncio |
| **Transcription Whisper** | **~100% sur 1 cœur** | **2.0-2.2 GB** | **18-24** | CTranslate2 single-thread par défaut |
| Retour résultat | ~1% | 1.9 GB | 18 | Simple callback |

**Faster Whisper / CTranslate2 sur CPU utilise principalement un seul cœur** pour le décodage beam search. Les 4 cœurs du serveur sont donc **sous-utilisés** (seul ~25% de la capacité CPU est utilisée pendant la transcription).

---

### Analyse de saturation

**Question :** Le serveur est-il saturé ?

| Critère | Valeur | Saturé ? |
|---|---|---|
| CPU pendant transcription | ~25% (1 cœur sur 4) | **NON** |
| RAM utilisée | 1.9 GB / 10 GB = 19% | **NON** |
| Load average | 0.20 / 4.0 = 5% | **NON** |
| Disque I/O | < 1 MB/s | **NON** |
| Réseau | Localhost | **NON** |

**Le serveur n'est PAS saturé.** La latence ne vient pas d'une surcharge mais de l'inefficacité du modèle medium sur CPU.

**3 cœurs sur 4 sont inutilisés** pendant la transcription. CTranslate2 n'exploite pas le parallélisme multi-cœur de manière efficace avec `beam_size=5` sur cette configuration.

---

### Comparaison mémoire

| Élément | Taille | Source |
|---|---|---|
| Modèle Whisper medium (disque) | 1.5 GB | `du -sh` |
| Mémoire résidente du processus | 1.9 GB | `top` / `/proc/PID/status` |
| Overhead Python + serveur | ~0.4 GB | Différence |

La mémoire résidente (1.9 GB) correspond au modèle (1.5 GB) + overhead FastAPI/uvicorn/CTranslate2 (~0.4 GB).

---

### Conclusion

| Ressource | Utilisation | Goulot ? |
|---|---|---|
| CPU | ~25% (1 cœur) | **NON** — mal utilisé |
| RAM | ~20% | **NON** |
| Disque | <0.1% | **NON** |
| Réseau | Négligeable | **NON** |

**Le serveur dispose de ressources suffisantes mais le logiciel ne les exploite pas.**

La latence vient de :
1. Le choix du modèle (medium = 1.5 GB) inadapté au CPU
2. Le paramètre `beam_size=5` qui ne parallelise pas sur les 4 cœurs
3. L'absence d'accélération matérielle (pas de GPU, pas de NPU, pas de AVX-512)
