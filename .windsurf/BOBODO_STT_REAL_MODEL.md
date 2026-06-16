# BOBODO_STT_REAL_MODEL

## Mission 1 — Vérification du modèle STT réellement utilisé

---

### Date
2026-06-13

---

### Question

Quel modèle Faster Whisper est actuellement chargé ?

- tiny ?
- base ?
- small ?
- medium ?
- autre ?

---

### Preuve 1 : Code exact de chargement du modèle

**Fichier :** `/opt/bobodo-vocal/stt_service.py`, ligne 24

```python
def __init__(self, model_size: str = "medium", device: str = "cpu", compute_type: str = "int8"):
    self.model_size = model_size
    self.device = device
    self.compute_type = compute_type
    self.model = None
    # ...
    self._load_model()
```

**Valeur par défaut :** `model_size="medium"`

---

### Preuve 2 : Appel du constructeur dans main.py

**Fichier :** `/opt/bobodo-vocal/main.py`, ligne 56

```python
stt_service = STTService()
```

**Aucun argument n'est passé.** Le constructeur utilise donc sa valeur par défaut `"medium"`.

---

### Preuve 3 : Classe Settings (non utilisée pour le modèle STT)

**Fichier :** `/opt/bobodo-vocal/main.py`, ligne 18-24

```python
class Settings(BaseSettings):
    # ...
    whisper_model: str = "tiny"     # <- DÉFAUT "tiny"
    whisper_device: str = "cpu"
    whisper_quantization: str = "int8"
```

**La valeur `"tiny"` de Settings N'EST PAS transmise au STTService.** Le paramètre existe dans la configuration mais n'est jamais utilisé.

---

### Preuve 4 : Fichier .env

**Fichier :** `/opt/bobodo-vocal/.env`

```
WHISPER_MODEL=medium
WHISPER_DEVICE=cpu
WHISPER_QUANTIZATION=int8
```

Même si `.env` dit `medium`, le code ignore cette valeur et utilise le hardcoded default `"medium"`.

---

### Preuve 5 : Logs de démarrage

**Commande :** `journalctl -u bobodo-vocal --no-pager`

```
Jun 13 07:22:09 academia00 python[148819]:
  [STT_MODEL_READY] Faster Whisper model medium loaded successfully
```

**Un seul message** `[STT_MODEL_READY]` pour le PID 148819 (démarré à 07:22). Le modèle chargé est explicitement nommé **"medium"**.

---

### Preuve 6 : Fichiers modèle sur disque

**Commande :**
```bash
du -sh /root/.cache/huggingface/hub/models--Systran--faster-whisper-medium
```

**Résultat :** `1.5G`

Le répertoire de cache contient un modèle de **1.5 GB**, ce qui correspond à la taille du modèle Faster Whisper **medium** (et non tiny = 39 MB, base = 74 MB, small = 244 MB).

**Fichiers :**
```
-rw-r--r-- 1 root root 450K  ...  CACHEDIR.TAG
-rw-r--r-- 1 root root 2.2M  ...  config.json
-rw-r--r-- 1 root root 1.5G   ...  model.bin
-rw-r--r-- 1 root root 2.3K  ...  tokenizer.json
```

---

### Conclusion

| Source | Valeur déclarée | Valeur réelle | Utilisée ? |
|---|---|---|---|
| `stt_service.py` default | `medium` | `medium` | ✅ OUI |
| `main.py` Settings default | `tiny` | `tiny` | ❌ NON |
| `.env` WHISPER_MODEL | `medium` | `medium` | ❌ NON (pas lu) |
| Logs journalctl | — | `medium` | ✅ Confirmé |
| Fichiers disque | — | 1.5 GB | ✅ Confirmé |

**RÉPONSE : Le modèle réellement utilisé est `medium`.**

**Conséquence :** Si l'intention était d'utiliser `tiny` (plus rapide, 39 MB), le système utilise actuellement `medium` (1.5 GB) à cause d'un **bug de passage de paramètre** dans `main.py` ligne 56.

---

### Diagramme du flux de paramètres

```
.env WHISPER_MODEL=medium ─┐
                            ├──► Settings.whisper_model="tiny" (défaut) ──► JAMAIS UTILISÉ
                            │
stt_service.py:24         └──► STTService.__init__(model_size="medium") ──► UTILISÉ
           model_size="medium" (défaut)
```
