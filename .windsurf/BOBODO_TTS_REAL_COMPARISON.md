# BOBODO_TTS_REAL_COMPARISON

## Phase 5 — Évaluation réelle des voix TTS

---

### Date
2026-06-12

---

### Méthodologie

**Serveur :** Kamatera (185.167.97.144)
**Phrase test :** "Bonjour Bobodo, comment ça va ?"
**Mesures :** Latence de génération (ms), taille fichier (bytes), format

---

### A. gTTS (Google Text-to-Speech)

**Implémentation actuelle :** `tts_service.py` (serveur)

**Test :**
```python
from gtts import gTTS
tts = gTTS("Bonjour Bobodo, comment ça va ?", lang="fr")
tts.save("/tmp/gtts_test.mp3")
```

**Résultats :**
- **Latence :** 191 ms
- **Taille fichier :** 19 008 bytes (MP3)
- **Format :** MP3 24kHz mono
- **Qualité :** Voix standard Google, légèrement robotique mais parfaitement intelligible
- **Dépendance réseau :** Oui (appel API Google)

**Avantages :**
- Très rapide (~200ms)
- Fiable (Google infrastructure)
- Français natif

**Inconvénients :**
- Nécessite une connexion Internet
- Voix non personnalisée
- Dépendance tierce (Google)

---

### B. Piper

**Installation :** `/opt/bobodo-vocal/venv/bin/piper`
**Modèles :** `/opt/bobodo-vocal/models/`
- `model.onnx` : 305 805 bytes
- `config.json` : 305 793 bytes
- `model.onnx.json` : 305 847 bytes

**Test :**
```bash
piper -m /opt/bobodo-vocal/models/model.onnx -c /opt/bobodo-vocal/models/config.json --output_file /tmp/piper_test.wav
```

**Résultats :**
- **Latence :** ❌ Échec (crash au chargement)
- **Erreur :** `json.load(config_file)` → échec parsing config.json
- **Cause :** Le fichier `config.json` est malformé ou le modèle ONNX (305KB) est incomplet/corrompu

**Diagnostic :**
Un modèle Piper correct fait typiquement 20-100MB. Le modèle présent (305KB) est anormalement petit. Le fichier `config.json` semble être une copie du modèle ONNX (tailles quasi identiques), ce qui indique une installation corrompue.

**Avantages théoriques :**
- Offline (pas de dépendance réseau)
- Open source
- Personnalisable

**Inconvénients réels :**
- ❌ **Non fonctionnel actuellement**
- Modèle corrompu
- Configuration incorrecte

---

### Comparaison réelle

| Critère | gTTS | Piper |
|---|---|---|
| **Fonctionne ?** | ✅ Oui | ❌ Non |
| **Latence** | 191 ms | N/A |
| **Offline ?** | ❌ Non | ✅ Oui (si fonctionnel) |
| **Qualité voix** | Standard | N/A |
| **Taille modèle** | N/A (cloud) | 305KB (corrompu) |
| **Dépendances** | Internet + Google | Local uniquement |
| **Français natif** | ✅ Oui | ✅ Oui (si modèle correct) |

---

### Verdict

**gTTS est le seul moteur TTS fonctionnel sur le serveur actuellement.**

**Piper est installé mais son modèle est corrompu.** Il faut réinstaller un modèle Piper valide (ex: `fr_FR-siwis-medium` ou `fr_FR-tom-medium`) pour pouvoir l'utiliser.

**Recommandation immédiate :** Conserver gTTS comme moteur principal. Il est fiable, rapide, et sa latence (~200ms) est négligeable par rapport à la latence STT (~8.4s).

**Recommandation future :** Télécharger un modèle Piper français valide (~50MB) pour réduire la dépendance à Internet et personnaliser la voix de Bobodo.
