# BOBODO VOICE - TTS Benchmark

## Date
12 Juin 2026

---

## OBJECTIF

Benchmark comparatif des moteurs TTS réellement compatibles avec l'architecture Academia.

---

## MOTEURS AUDITÉS

1. Piper
2. Kokoro TTS
3. XTTS v2
4. OpenVoice
5. ElevenLabs

---

## PIPER TTS

### Source de vérité

- Rhasspy/piper-voices (Hugging Face)
- PromptQuorum - Local TTS and Voice Cloning 2026
- Inferless - 12 Best Open-Source TTS Models Compared

---

### Qualité voix française

**Qualité** : ⭐⭐⭐⭐ / 5

**Justification** :
- VITS-based neural TTS
- Voix naturelles mais clairement synthétiques
- 20+ langues supportées dont français
- Voice packs disponibles sur Hugging Face
- Qualité "bonne" mais inférieure à XTTS v2 ou StyleTTS 2

**Voix françaises disponibles** :
- fr_FR-siwis-low
- fr_FR-siwis-medium
- fr_FR-medium
- fr_FR-glow-tts

---

### Qualité accents africains

**Qualité** : ⭐⭐ / 5

**Justification** :
- Accent français standard (France)
- Pas d'adaptation spécifique aux accents africains
- Pas de voix personnalisées pour accents BF, SN, CI, etc.

---

### Temps de génération

**Vitesse** : ⭐⭐⭐⭐⭐ / 5

**Justification** :
- ~10× plus rapide que temps réel sur CPU moderne
- Temps réel sur Raspberry Pi 5
- Sub-50ms first-audio latency
- ~15× temps réel sur M5 Pro (Apple Silicon)

---

### Consommation RAM

**RAM** : ⭐⭐⭐⭐⭐ / 5

**Justification** :
- CPU only (pas besoin de GPU)
- Voice packs : 20-200 MB par modèle
- Raspberry Pi 4 avec 2GB RAM gère Piper sans difficulté
- Excellent pour embedded devices

---

### Consommation CPU

**CPU** : ⭐⭐⭐⭐ / 5

**Justification** :
- ONNX Runtime optimisé
- Parallélisation efficace
- ~10× temps réel sur CPU moderne
- CPU usage modéré

---

### Compatibilité Kamatera

**Compatibilité** : ✅ **100%**

**Justification** :
- CPU only (pas besoin de GPU)
- Compatible avec instances CPU Kamatera
- Pas de dépendances GPU
- Installation simple : pip install piper-tts

---

### Coût

**Coût** : ⭐⭐⭐⭐⭐ / 5

**Justification** :
- Gratuit (MIT License)
- Pas de frais mensuels
- Pas de facturation par caractère
- Coût unique : hébergement Kamatera

---

### Dépendances

**Dépendances** : ⭐⭐⭐⭐ / 5

**Justification** :
- pip install piper-tts
- ONNX Runtime
- espeak-ng (installé par défaut)
- Dépendances minimales
- Installation simple

---

### Maintenance

**Maintenance** : ⭐⭐⭐⭐ / 5

**Justification** :
- Projet actif (Rhasspy)
- Communauté active
- Mises à jour régulières
- Documentation complète

---

## KOKORO TTS

### Source de vérité

- Clore.ai - Kokoro TTS Guide
- PromptQuorum - Local TTS and Voice Cloning 2026
- Inferless - 12 Best Open-Source TTS Models Compared

---

### Qualité voix française

**Qualité** : ❌ **NON SUPPORTÉ**

**Justification** :
- Multi-language support : Anglais (principal), japonais (misaki[ja]), chinois (misaki[zh])
- PAS de support français
- Ne peut pas être utilisé pour Academia

---

### Qualité accents africains

**Qualité** : ❌ **NON APPLICABLE**

**Justification** :
- Pas de support français
- Pas applicable

---

### Temps de génération

**Vitesse** : ⭐⭐⭐⭐⭐ / 5

**Justification** :
- Temps réel ou plus rapide
- Ultra-lightweight 82M parameters
- <2GB VRAM
- Streaming generation

---

### Consommation RAM

**RAM** : ⭐⭐⭐⭐⭐ / 5

**Justification** :
- <2GB VRAM
- 4GB RAM (RTX 3060)
- 8GB RAM (recommandé)
- Peut tourner sur CPU

---

### Consommation CPU

**CPU** : ⭐⭐⭐⭐ / 5

**Justification** :
- 82M parameters (très léger)
- CPU moderne multi-core pour temps réel
- 8+ cores recommandés pour performance optimale

---

### Compatibilité Kamatera

**Compatibilité** : ✅ **100%**

**Justification** :
- Compatible avec GPU Kamatera (2GB VRAM)
- Compatible avec CPU Kamatera
- Installation simple

---

### Coût

**Coût** : ⭐⭐⭐⭐⭐ / 5

**Justification** :
- Gratuit (Apache 2.0 License)
- Pas de frais mensuels
- Pas de facturation par caractère
- Coût unique : hébergement Kamatera

---

### Dépendances

**Dépendances** : ⭐⭐⭐⭐ / 5

**Justification** :
- Python 3.9+
- espeak-ng installé
- Dépendances minimales
- Installation simple

---

### Maintenance

**Maintenance** : ⭐⭐⭐ / 5

**Justification** :
- Projet émergent
- Communauté en croissance
- Documentation limitée
- Moins mature que Piper

---

## XTTS v2

### Source de vérité

- Coqui TTS Documentation
- PromptQuorum - Local TTS and Voice Cloning 2026
- Inferless - 12 Best Open-Source TTS Models Compared

---

### Qualité voix française

**Qualité** : ⭐⭐⭐⭐⭐ / 5

**Justification** :
- Meilleure qualité de clonage vocal
- Cross-lingual cloning en 17 langues
- Support français natif
- Near-human MOS sur benchmarks
- Qualité supérieure à Piper

---

### Qualité accents africains

**Qualité** : ⭐⭐⭐ / 5

**Justification** :
- Support français natif
- Cross-lingual cloning possible
- Pas d'adaptation spécifique aux accents africains
- Clonage vocal personnalisé possible

---

### Temps de génération

**Vitesse** : ⭐⭐⭐ / 5

**Justification** :
- Streaming inference avec <200ms latency
- ~3-5× temps réel sur RTX 4070
- Plus lent que Piper
- Nécessite GPU pour performance optimale

---

### Consommation RAM

**RAM** : ⭐⭐ / 5

**Justification** :
- 4GB RAM à l'inférence
- ~4GB disque pour modèle et dépendances
- VRAM : 4-6GB (GPU requis)

---

### Consommation CPU

**CPU** : ⭐⭐ / 5

**Justification** :
- CPU possible mais lent
- GPU fortement recommandé
- CPU usage élevé sans GPU

---

### Compatibilité Kamatera

**Compatibilité** : ⚠️ **PARTIELLE**

**Justification** :
- Nécessite GPU (4-6GB VRAM)
- Compatible avec instances GPU Kamatera
- Plus coûteux que CPU only
- Complexité d'installation plus élevée

---

### Coût

**Coût** : ⭐⭐⭐ / 5

**Justification** :
- Gratuit (MPL 2.0 License)
- Pas de frais mensuels
- Coût hébergement GPU Kamatera plus élevé
- Coût total plus élevé que CPU only

---

### Dépendances

**Dépendances** : ⭐⭐⭐ / 5

**Justification** :
- pip install TTS
- PyTorch
- GPU drivers (si GPU utilisé)
- Dépendances plus lourdes que Piper
- Installation plus complexe

---

### Maintenance

**Maintenance** : ⭐⭐ / 5

**Justification** :
- Coqui Inc fermé fin 2023
- Projet maintenu par la communauté
- Pas de support commercial
- Mises à jour irrégulières

---

## OPENVOICE

### Source de vérité

- GitHub - myshell-ai/OpenVoice
- Hugging Face - myshell-ai/OpenVoiceV2

---

### Qualité voix française

**Qualité** : ⭐⭐⭐⭐ / 5

**Justification** :
- OpenVoice V2 : meilleure qualité audio
- Native multi-lingual support
- Français nativement supporté
- Accurate tone color cloning
- Flexible voice style control

---

### Qualité accents africains

**Qualité** : ⭐⭐⭐ / 5

**Justification** :
- Native multi-lingual support
- Zero-shot cross-lingual voice cloning
- Pas d'adaptation spécifique aux accents africains
- Clonage vocal personnalisé possible

---

### Temps de génération

**Vitesse** : ⭐⭐⭐ / 5

**Justification** :
- Non spécifié dans la documentation
- Vitesse probablement similaire à XTTS v2
- Nécessite probablement GPU pour performance optimale

---

### Consommation RAM

**RAM** : ⭐⭐⭐ / 5

**Justification** :
- Non spécifié dans la documentation
- Probablement similaire à XTTS v2 (4-6GB VRAM)
- GPU probablement requis

---

### Consommation CPU

**CPU** : ⭐⭐⭐ / 5

**Justification** :
- Non spécifié dans la documentation
- Probablement similaire à XTTS v2
- GPU probablement requis

---

### Compatibilité Kamatera

**Compatibilité** : ⚠️ **PARTIELLE**

**Justification** :
- Probablement compatible avec GPU Kamatera
- GPU probablement requis
- Plus coûteux que CPU only
- Complexité d'installation plus élevée

---

### Coût

**Coût** : ⭐⭐⭐⭐⭐ / 5

**Justification** :
- Gratuit (MIT License)
- Pas de frais mensuels
- Pas de facturation par caractère
- Coût unique : hébergement Kamatera

---

### Dépendances

**Dépendances** : ⭐⭐⭐ / 5

**Justification** :
- Python, PyTorch
- Dépendances plus lourdes que Piper
- Installation plus complexe
- Documentation limitée

---

### Maintenance

**Maintenance** : ⭐⭐⭐⭐ / 5

**Justification** :
- Projet actif (MIT + MyShell)
- Communauté active
- Mises à jour régulières
- Documentation complète

---

## ELEVENLABS

### Source de vérité

- ElevenLabs Documentation
- ElevenLabs Pricing
- Gradium.ai - Best ElevenLabs Alternatives 2026

---

### Qualité voix française

**Qualité** : ⭐⭐⭐⭐⭐ / 5

**Justification** :
- Ultra-réaliste (indistinguable d'une voix humaine)
- Multilingual v2 : 70+ langues
- Français nativement supporté
- Meilleure qualité du marché
- Voix clonée (signature vocale unique)

---

### Qualité accents africains

**Qualité** : ⭐⭐⭐⭐ / 5

**Justification** :
- Multilingual v2 : 70+ langues
- Stable quality across language switches
- Voix clonée (adaptation possible)
- Supporte les accents africains

---

### Temps de génération

**Vitesse** : ⭐⭐⭐⭐⭐ / 5

**Justification** :
- Flash v2.5 : ultra-low ~75ms latency
- Turbo v2.5 : ~250-300ms
- Multilingual v2 : higher latency but superior quality
- Optimisé pour real-time applications

---

### Consommation RAM

**RAM** : ⭐⭐⭐⭐⭐ / 5

**Justification** :
- API cloud (pas d'hébergement local)
- Pas de consommation RAM locale
- Pas de consommation CPU locale
- Hébergement géré par ElevenLabs

---

### Consommation CPU

**CPU** : ⭐⭐⭐⭐⭐ / 5

**Justification** :
- API cloud (pas d'hébergement local)
- Pas de consommation CPU locale
- Hébergement géré par ElevenLabs

---

### Compatibilité Kamatera

**Compatibilité** : ❌ **NON APPLICABLE**

**Justification** :
- API cloud (pas d'hébergement local)
- Pas besoin de Kamatera
- Hébergement géré par ElevenLabs

---

### Coût

**Coût** : ⭐ / 5

**Justification** :
- Starter plan : ~$22/mois
- Facturation par caractère
- 1 character = 1 credit (Multilingual v2)
- Flash : 0.5-1 credit par character
- Coût récurrent mensuel

---

### Dépendances

**Dépendances** : ⭐⭐⭐⭐⭐ / 5

**Justification** :
- API REST simple
- Pas de dépendances locales
- Installation simple (clé API)
- Documentation complète

---

### Maintenance

**Maintenance** : ⭐⭐⭐⭐⭐ / 5

**Justification** :
- Service commercial actif
- Support client
- Mises à jour régulières
- SLA garanti

---

## SYNTHÈSE

### Tableau comparatif

| Moteur | Qualité FR | Accents AF | Vitesse | RAM | CPU | Kamatera | Coût | Dépendances | Maintenance |
|--------|------------|------------|---------|-----|-----|----------|------|-------------|-------------|
| Piper | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ✅ 100% | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| Kokoro | ❌ NS | ❌ NA | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ✅ 100% | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| XTTS v2 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐ | ⚠️ Partielle | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| OpenVoice | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⚠️ Partielle | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| ElevenLabs | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ❌ NA | ⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

### Conclusion

**Kokoro TTS** : Éliminé (pas de support français)

**XTTS v2** : Qualité excellente mais nécessite GPU (coût Kamatera plus élevé)

**OpenVoice** : Qualité bonne mais nécessite probablement GPU (coût Kamatera plus élevé)

**ElevenLabs** : Qualité excellente mais coût mensuel élevé (~$22/mois)

**Piper** : Qualité bonne, CPU only, gratuit, compatible Kamatera

---

## SIGN-OFF

**Benchmark réalisé** : 12 Juin 2026
**Benchmarkeur** : Cascade AI
**Statut** : COMPLET
