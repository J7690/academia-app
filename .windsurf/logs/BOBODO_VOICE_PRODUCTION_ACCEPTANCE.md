# BOBODO VOICE - Production Acceptance Report

## Date
12 Juin 2026

---

## MISSION 1 – Preuve Moteur TTS Actif

### Résultat
**[TTS_ENGINE] : gTTS (Google Text-to-Speech)**

### Preuve
Le modèle Piper n'a pas pu être téléchargé (404 sur HuggingFace). Le code `tts_service.py` contient un fallback vers gTTS qui est actuellement actif.

**Logs serveur** :
```
[TTS_MODEL_ERROR] Piper not installed. Falling back to gTTS.
[TTS_MODEL_ERROR] Install with: pip install piper-tts
[TTS_FALLBACK] Using gTTS fallback
[TTS_GTTS] Using gTTS fallback
[TTS_GTTS] gTTS synthesis completed
```

### Conclusion
- Moteur TTS actif : **gTTS**
- Piper : **NON disponible** (échec téléchargement)

---

## MISSION 2 – Preuve Modèle STT Actif

### Résultat
**[STT_MODEL_ACTIVE] : Faster Whisper Small**

### Configuration
- Nom du modèle : `small`
- Taille : ~461 MB
- Device : `cpu`
- Compute type : `int8`
- Paramètres : `beam_size=5`, `vad_filter=False`

### Preuve
Fichier `stt_service.py` modifié :
```python
def __init__(self, model_size: str = "small", device: str = "cpu", compute_type: str = "int8"):
```

Logs attendus :
```
[STT_SERVICE_INIT] STT service initialized with Faster Whisper small
[STT_SERVICE_INIT] Silence threshold: 500ms
```

### Conclusion
- Modèle STT actif : **Faster Whisper Small**
- Silence threshold : **500ms** (optimisé)

---

## MISSION 3 – Benchmark Réel

### Statut
**NON RÉALISÉ** - Pas d'appareil disponible pour test

### Plan de Test
- Phrase courte : "Bonjour Bobodo"
- Phrase moyenne : "Comment postuler à l'université ?"
- Phrase longue : 20 secondes de parole

### Mesures Attendues
- Temps transcription : 1-2s (Small)
- Temps réponse : 1-3s (Bobodo Edge Function)
- Temps synthèse : 2-4s (gTTS)
- Temps lecture : Variable

### Conclusion
Benchmark à réaliser sur appareil réel.

---

## MISSION 4 – Validation Mode Vocal Complet

### Statut
**PARTIELLEMENT VALIDÉ** - Code implémenté, non testé

### Flux Implémenté
1. ✅ Utilisateur parle
2. ✅ Stop
3. ✅ Transcription
4. ✅ Correction éventuelle
5. ✅ Envoi
6. ✅ Réponse Bobodo
7. ✅ Lecture audio (avec auto TTS)

### Contrôles UX
- ✅ Bouton "Stop" pendant lecture
- ✅ Bouton "Replay" après lecture
- ✅ Bouton "Volume" toggle auto TTS

### Conclusion
Code implémenté, validation fonctionnelle requise sur appareil.

---

## MISSION 5 – Téléchargement Piper

### Résultat
**ÉCHEC** - 404 sur HuggingFace

### Tentatives
1. wget (échoué)
2. curl (échoué, fichiers HTML vides)
3. curl avec User-Agent (échoué)
4. GitHub mirror (échoué, fichiers HTML vides)
5. Python requests (404 sur tous les modèles)

### Modèles Testés
- fr_FR-siwis-low (v1.0.0, main)
- fr_FR-siwis-medium (v1.0.0)
- fr_FR-medium (v1.0.0, main)
- fr_FR-glow-tts (v1.0.0)

### Conclusion
Piper TTS **NON disponible** sur le serveur. Fallback gTTS actif.

---

## MISSION 6 – Acceptation Finale

### Moteur STT Réellement Utilisé
**Faster Whisper Small** ✅

### Moteur TTS Réellement Utilisé
**gTTS (Google Text-to-Speech)** ⚠️

### Latence Réelle
**Estimée** (non mesurée sur appareil) :
- STT : 1-2s
- Silence Detection : 0.5s
- TTS : 2-4s
- Total traitement : 3.5-6.5s

### Qualité Observée
- STT : Bonne (Small)
- TTS : Moyenne (gTTS)

### Problèmes Restants
1. ❌ Piper TTS non disponible (404 HuggingFace)
2. ❌ Benchmark non réalisé (pas d'appareil)
3. ❌ Validation fonctionnelle non testée
4. ⚠️ Préférence utilisateur non persistée (variable locale)

---

## STATUT FINAL

**NOT READY FOR PRODUCTION**

### Justification
1. **Piper TTS non disponible** : La solution TTS recommandée (Piper) n'a pas pu être téléchargée. Le fallback gTTS est actif mais ne répond pas à l'exigence de qualité et de latence optimisée.

2. **Validation fonctionnelle manquante** : Le code est implémenté mais non testé sur appareil réel. Aucune mesure de latence réelle n'a été effectuée.

3. **Benchmark absent** : Les mesures de performance sont estimées, non mesurées.

### Actions Requises
1. **Résoudre téléchargement Piper** :
   - Investiger les modèles disponibles sur HuggingFace
   - Ou utiliser une alternative (Coqui TTS, ElevenLabs, Azure TTS)
   - Ou accepter gTTS comme solution temporaire

2. **Validation sur appareil** :
   - Tester le flux vocal complet
   - Mesurer latence réelle
   - Valider qualité transcription

3. **Persistance préférence** :
   - Stocker `bobodo_auto_tts_enabled` dans Supabase
   - Ajouter table user_settings si nécessaire

---

## Sign-off

**Validation réalisée** : 12 Juin 2026
**Validateur** : Cascade AI
**Statut** : NOT READY FOR PRODUCTION
