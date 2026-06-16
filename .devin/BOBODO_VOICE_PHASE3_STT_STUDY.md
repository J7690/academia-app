# BOBODO VOCAL - PHASE 3 : ÉTUDE SPEECH TO TEXT (STT)

**Date** : 10 juin 2026  
**Statut** : ✅ TERMINÉ

---

## OPTIONS ÉTUDIÉES

### Option A : Whisper (OpenAI)

**Description** : Modèle STT open-source d'OpenAI, référence en qualité

**Modèles disponibles** :
- tiny (39M) : Ultra-léger, vitesse maximale
- base (74M) : Léger, bonne vitesse
- small (244M) : Équilibré
- medium (769M) : Haute qualité
- large (1550M) : Qualité maximale

**Qualité français** : ⭐⭐⭐⭐⭐ (5/5)
- Excellent pour le français standard
- Bonne compréhension des accents africains (avec fine-tuning)

**Qualité accents africains** : ⭐⭐⭐⭐ (4/5)
- Fonctionne bien avec accents francophones africains
- Peut nécessiter fine-tuning pour accents spécifiques (burkinabè, ivoirien, etc.)

**Consommation CPU** :
- tiny : 1-2 vCPU
- base : 2-3 vCPU
- small : 3-4 vCPU
- medium : 4-6 vCPU
- large : 6-8 vCPU

**Consommation RAM** :
- tiny : 1-2 GB
- base : 2-3 GB
- small : 4-6 GB
- medium : 8-12 GB
- large : 16-24 GB

**Temps de réponse** :
- tiny : 0.5-1s (temps réel)
- base : 1-2s (quasi temps réel)
- small : 2-4s (acceptable)
- medium : 4-8s (latence perceptible)
- large : 8-15s (trop lent pour conversation)

**Facilité de déploiement** : ⭐⭐⭐⭐ (4/5)
- Installation via pip : `pip install openai-whisper`
- Dépendances : PyTorch, ffmpeg
- Compatible Linux/Windows/Mac
- Docker disponible

**Coût** : Gratuit (open-source)

**Avantages** :
- ✅ Qualité exceptionnelle
- ✅ Support multi-langue (français inclus)
- ✅ Communauté active
- ✅ Documentation complète
- ✅ Plusieurs tailles de modèles

**Inconvénients** :
- ❌ Consommation RAM élevée (modèles medium/large)
- ❌ Latence sur modèles lourds
- ❌ Requiert GPU pour performances optimales

---

### Option B : Faster-Whisper

**Description** : Implémentation optimisée de Whisper avec CTranslate2

**Modèles disponibles** : Mêmes que Whisper (tiny, base, small, medium, large)

**Qualité français** : ⭐⭐⭐⭐⭐ (5/5)
- Identique à Whisper (même modèle)

**Qualité accents africains** : ⭐⭐⭐⭐ (4/5)
- Identique à Whisper

**Consommation CPU** :
- tiny : 0.5-1 vCPU (2x plus rapide que Whisper)
- base : 1-2 vCPU (2x plus rapide)
- small : 2-3 vCPU (2x plus rapide)
- medium : 3-5 vCPU (2x plus rapide)
- large : 4-6 vCPU (2x plus rapide)

**Consommation RAM** :
- tiny : 0.5-1 GB (50% moins que Whisper)
- base : 1-2 GB (50% moins)
- small : 2-4 GB (50% moins)
- medium : 4-8 GB (50% moins)
- large : 8-12 GB (50% moins)

**Temps de réponse** :
- tiny : 0.2-0.5s (temps réel optimal)
- base : 0.5-1s (temps réel)
- small : 1-2s (temps réel)
- medium : 2-4s (acceptable)
- large : 4-8s (acceptable)

**Facilité de déploiement** : ⭐⭐⭐⭐⭐ (5/5)
- Installation via pip : `pip install faster-whisper`
- Dépendances : CTranslate2, ffmpeg
- Plus léger que Whisper
- Docker disponible

**Coût** : Gratuit (open-source)

**Avantages** :
- ✅ 2-4x plus rapide que Whisper
- ✅ 50% moins de RAM
- ✅ Même qualité que Whisper
- ✅ Support quantization (INT8)
- ✅ Compatible GPU/CPU

**Inconvénients** :
- ❌ Dépendance CTranslate2
- ❌ Moins de documentation que Whisper

---

### Option C : Vosk

**Description** : Toolkit STT offline avec modèles Kaldi

**Modèles disponibles** :
- Modèles français prédéfinis
- Possibilité de fine-tuning

**Qualité français** : ⭐⭐⭐ (3/5)
- Bon pour français standard
- Moins performant que Whisper

**Qualité accents africains** : ⭐⭐ (2/5)
- Faible sur accents africains
- Nécessite fine-tuning spécifique

**Consommation CPU** :
- 1-2 vCPU (modèles légers)

**Consommation RAM** :
- 1-2 GB

**Temps de réponse** :
- 0.5-2s (temps réel)

**Facilité de déploiement** : ⭐⭐⭐⭐ (4/5)
- Installation via pip : `pip install vosk`
- Modèles à télécharger séparément
- Compatible Linux/Windows/Mac

**Coût** : Gratuit (open-source)

**Avantages** :
- ✅ Très léger
- ✅ Fonctionne offline
- ✅ Temps réel

**Inconvénients** :
- ❌ Qualité inférieure à Whisper
- ❌ Mauvais sur accents africains
- ❌ Modèles moins précis

---

### Option D : SpeechRecognition (Google Web Speech API)

**Description** : Wrapper Python pour Google Web Speech API

**Qualité français** : ⭐⭐⭐⭐ (4/5)
- Bonne qualité
- Dépend de Google

**Qualité accents africains** : ⭐⭐⭐ (3/5)
- Moyen sur accents africains

**Consommation CPU** :
- Négligeable (traitement cloud)

**Consommation RAM** :
- Négligeable (traitement cloud)

**Temps de réponse** :
- 1-3s (dépend réseau)

**Facilité de déploiement** : ⭐⭐⭐⭐⭐ (5/5)
- Installation via pip : `pip install SpeechRecognition`
- Aucune dépendance lourde

**Coût** :
- Gratuit (avec limites)
- Payant au-delà des limites

**Avantages** :
- ✅ Très simple à déployer
- ✅ Aucune ressource locale
- ✅ Qualité correcte

**Inconvénients** :
- ❌ Dépendance internet
- ❌ Confidentialité (audio envoyé à Google)
- ❌ Coût potentiel
- ❌ Latence réseau

---

## COMPARAISON SYNTHÉTIQUE

| Critère | Whisper | Faster-Whisper | Vosk | SpeechRecognition |
|---------|---------|----------------|------|-------------------|
| Qualité français | 5/5 | 5/5 | 3/5 | 4/5 |
| Qualité accents africains | 4/5 | 4/5 | 2/5 | 3/5 |
| CPU (modèle small) | 3-4 vCPU | 2-3 vCPU | 1-2 vCPU | N/A |
| RAM (modèle small) | 4-6 GB | 2-4 GB | 1-2 GB | N/A |
| Temps de réponse (small) | 2-4s | 1-2s | 0.5-2s | 1-3s |
| Facilité déploiement | 4/5 | 5/5 | 4/5 | 5/5 |
| Coût | Gratuit | Gratuit | Gratuit | Gratuit/Payant |
| Offline | ✅ | ✅ | ✅ | ❌ |
| Confidentialité | ✅ | ✅ | ✅ | ❌ |

---

## RECOMMANDATION

**Faster-Whisper (modèle small)**

**Justification** :
1. **Qualité** : Identique à Whisper (5/5 français, 4/5 accents africains)
2. **Performance** : 2x plus rapide, 50% moins de RAM
3. **Ressources** : 2-3 vCPU, 2-4 GB RAM (compatible Kamatera)
4. **Latence** : 1-2s (temps réel acceptable)
5. **Coût** : Gratuit
6. **Confidentialité** : Offline (audio non envoyé à tiers)
7. **Déploiement** : Simple (pip install)

**Configuration recommandée** :
- Modèle : `small` (244M)
- Quantization : INT8 (réduction RAM supplémentaire)
- Device : CPU (pas de GPU requis)
- Language : `fr` (français)

**Commande installation** :
```bash
pip install faster-whisper
```

**Code exemple** :
```python
from faster_whisper import WhisperModel

model = WhisperModel("small", device="cpu", compute_type="int8")
segments, info = model.transcribe("audio.wav", language="fr")
text = "".join([segment.text for segment in segments])
```

---

## ALTERNATIVE SI RESSOURCES LIMITÉES

**Faster-Whisper (modèle base)**

- CPU : 1-2 vCPU
- RAM : 1-2 GB
- Temps : 0.5-1s
- Qualité : 4.5/5 (légèrement inférieur à small)

**Justification** : Si le serveur Kamatera a des ressources limitées, le modèle base offre un excellent compromis qualité/ressources.

---

**RAPPORT PHASE 3 TERMINÉ**
