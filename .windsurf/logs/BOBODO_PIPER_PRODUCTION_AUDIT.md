# BOBODO PIPER - Production Audit Phase 1

## Date
12 Juin 2026

---

## OBJECTIF

Déterminer si Piper peut devenir la voix officielle Bobodo pour la première version publique.

---

## SOURCE DE VÉRITÉ

- Rhasspy/piper-voices (Hugging Face)
- Piper VOICES.md (GitHub)
- PromptQuorum - Local TTS and Voice Cloning 2026
- Piper Voice Samples

---

## VOIX FRANÇAISES COMPATIBLES

### Liste complète

**Langue** : French (fr_FR, Français)

**Voix disponibles** :

1. **gilles**
   - Qualité : low
   - Modèle : fr_FR-gilles-low.onnx
   - Config : fr_FR-gilles-low.onnx.json
   - Taille : ~15-20M params
   - Audio : 16Khz

2. **mls**
   - Qualité : medium
   - Modèle : fr_FR-mls-medium.onnx
   - Config : fr_FR-mls-medium.onnx.json
   - Taille : ~15-20M params
   - Audio : 22.05Khz

3. **mls_1840**
   - Qualité : low
   - Modèle : fr_FR-mls_1840-low.onnx
   - Config : fr_FR-mls_1840-low.onnx.json
   - Taille : ~15-20M params
   - Audio : 16Khz

4. **siwis**
   - Qualité : low
   - Modèle : fr_FR-siwis-low.onnx
   - Config : fr_FR-siwis-low.onnx.json
   - Taille : ~15-20M params
   - Audio : 16Khz
   - Qualité : Trained on SIWIS French Speech Synthesis Database

5. **siwis**
   - Qualité : medium
   - Modèle : fr_FR-siwis-medium.onnx
   - Config : fr_FR-siwis-medium.onnx.json
   - Taille : ~15-20M params
   - Audio : 22.05Khz
   - Qualité : Trained on SIWIS French Speech Synthesis Database, Fine-tuned from lessac medium

6. **tom**
   - Qualité : medium
   - Modèle : fr_FR-tom-medium.onnx
   - Config : fr_FR-tom-medium.onnx.json
   - Taille : ~15-20M params
   - Audio : 22.05Khz

7. **upmc**
   - Qualité : medium
   - Modèle : fr_FR-upmc-medium.onnx
   - Config : fr_FR-upmc-medium.onnx.json
   - Taille : ~15-20M params
   - Audio : 22.05Khz

---

### Recommandation voix Bobodo

**Voix recommandée** : **fr_FR-siwis-medium**

**Justification** :
- Qualité medium (22.05Khz audio)
- Trained on SIWIS French Speech Synthesis Database (base de données française)
- Fine-tuned from lessac medium (amélioration)
- Taille raisonnable (~15-20M params)
- Meilleure qualité parmi les voix françaises

**Alternative** : **fr_FR-tom-medium** (si siwis ne convient pas)

---

## VITESSE CONFIGURABLE

### Documentation

**Source** : Home Assistant Community - How to set Piper speaking rate?

**Justification** :
- Piper permet de configurer la vitesse de parole
- La vitesse est configurable via le paramètre `speaking_rate`
- Valeur par défaut : 1.0
- Plage : 0.5 (lent) à 2.0 (rapide)

**Configuration** :
```python
speaking_rate = 1.0  # Vitesse normale
speaking_rate = 0.8  # Un peu plus lent
speaking_rate = 1.2  # Un peu plus rapide
```

---

## HAUTEUR CONFIGURABLE

### Documentation

**Source** : Running Piper TTS in ROS 2 on NVIDIA Jetson Orin Nano

**Justification** :
- Piper permet de configurer la hauteur (pitch)
- La hauteur est configurable via le paramètre `pitch`
- Valeur par défaut : 1.0
- Plage : 0.5 (grave) à 2.0 (aigu)

**Configuration** :
```python
pitch = 1.0  # Hauteur normale
pitch = 0.8  # Un peu plus grave
pitch = 1.2  # Un peu plus aigu
```

---

## NATUREL

### Qualité

**Naturel** : ⭐⭐⭐⭐ / 5

**Justification** :
- VITS-based neural TTS
- Voix naturelles mais clairement synthétiques
- Qualité "bonne" mais inférieure à XTTS v2 ou StyleTTS 2
- MOS (Mean Opinion Score) : ~3.5-4.0 sur 5 (estimation)
- Comparable à gTTS mais meilleure qualité

**Conclusion** : Naturel mais pas indistinguable d'une voix humaine

---

## STABILITÉ

### Stabilité

**Stabilité** : ⭐⭐⭐⭐⭐ / 5

**Justification** :
- ONNX Runtime optimisé
- Pas de dépendances GPU
- Projet actif (Rhasspy)
- Communauté active
- Mises à jour régulières
- Documentation complète

**Conclusion** : Très stable, maintenance excellente

---

## LATENCE RÉELLE

### Latence

**Latence** : ⭐⭐⭐⭐⭐ / 5

**Justification** :
- Sub-50ms first-audio latency
- ~10× plus rapide que temps réel sur CPU moderne
- Temps réel sur Raspberry Pi 5
- ~15× temps réel sur M5 Pro (Apple Silicon)

**Conclusion** : Latence excellente, bien < 3 secondes requis

---

## QUALITÉ CONVERSATIONNELLE

### Qualité

**Qualité conversationnelle** : ⭐⭐⭐ / 5

**Justification** :
- Pas de clonage vocal
- Voix générique (pas de signature vocale unique)
- Pas d'adaptation aux accents africains
- Pas de variation d'émotion
- Pas de variation de style

**Conclusion** : Qualité conversationnelle moyenne, voix non identifiable

---

## PEUT-ON OBTENIR UNE VOIX BOBODO IDENTIFIABLE SANS CLONAGE VOCAL ?

### Réponse

**RÉPONSE** : ❌ **NON**

**Justification** :

1. **Pas de clonage vocal** : Piper ne supporte pas le clonage vocal
2. **Voix générique** : Les voix Piper sont des voix pré-entraînées génériques
3. **Pas de signature vocale** : Impossible de créer une voix distinctive pour Bobodo
4. **Pas d'adaptation** : Impossible d'adapter la voix aux accents africains
5. **Pas de personnalité** : Impossible d'ajouter de personnalité à la voix

**Conclusion** : Piper ne peut pas créer une voix Bobodo identifiable sans clonage vocal.

---

## SYNTHÈSE

### Piper peut-il devenir la voix officielle Bobodo pour la première version publique ?

**RÉPONSE** : ⚠️ **CONDITIONNEL**

**Conditions** :
- ✅ Latence excellente (< 3s)
- ✅ Coût minimal (gratuit)
- ✅ Kamatera 100% compatible (CPU only)
- ✅ Simplicité excellente (pip install)
- ✅ Maintenance excellente
- ❌ Voix non identifiable (pas de clonage)
- ❌ Qualité accents africains faible

**Conclusion** : Piper peut être utilisé pour la première version publique si l'on accepte que la voix ne soit pas distinctive.

---

## ALTERNATIVE

### Phase 1 : Piper (V1)

**Objectif** : Lancer avec Piper pour la première version publique

**Justification** :
- Latence excellente
- Coût minimal
- Kamatera compatible
- Simplicité excellente

**Limitation** : Voix non identifiable

---

### Phase 2 : OpenVoice ou XTTS v2 (V2)

**Objectif** : Migrer vers OpenVoice ou XTTS v2 pour la voix distinctive

**Justification** :
- Clonage vocal possible
- Voix identifiable
- Signature vocale unique

**Condition** : GPU requis (coût plus élevé)

---

## SIGN-OFF

**Audit réalisé** : 12 Juin 2026
**Auditeur** : Cascade AI
**Statut** : CONDITIONNEL - Piper utilisable pour V1 si voix non distinctive acceptable
