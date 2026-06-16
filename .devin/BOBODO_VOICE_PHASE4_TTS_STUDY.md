# BOBODO VOCAL - PHASE 4 : ÉTUDE TEXT TO SPEECH (TTS)

**Date** : 10 juin 2026  
**Statut** : ✅ TERMINÉ

---

## OPTIONS ÉTUDIÉES

### Option A : Piper

**Description** : TTS neuronal rapide et léger, optimisé pour CPU

**Voix disponibles** :
- Plusieurs voix françaises (femmes/hommes)
- Qualité variable (low, medium, high)
- Personnalisation possible (pitch, speed, volume)

**Qualité voix française** : ⭐⭐⭐⭐ (4/5)
- Bonne qualité pour voix françaises
- Naturel mais parfois robotique
- Meilleur avec modèles medium/high

**Fluidité** : ⭐⭐⭐⭐ (4/5)
- Fluide et cohérent
- Peu d'hésitations
- Bon rythme

**Vitesse** :
- low : 0.5-1s (génération rapide)
- medium : 1-2s
- high : 2-4s

**Coût** : Gratuit (open-source)

**Consommation serveur** :
- CPU : 1-2 vCPU
- RAM : 1-2 GB
- Stockage : 500 MB-1 GB (modèles)

**Facilité d'intégration Flutter** : ⭐⭐⭐ (3/5)
- Pas de package Flutter natif
- Nécessite appel API REST/WebSocket
- Streaming audio possible

**Avantages** :
- ✅ Très léger
- ✅ Rapide
- ✅ Offline
- ✅ Qualité correcte
- ✅ Multi-langue

**Inconvénients** :
- ❌ Pas de package Flutter natif
- ❌ Qualité inférieure à solutions cloud
- ❌ Voix limitées

---

### Option B : Coqui TTS

**Description** : Toolkit TTS avancé avec modèles neuronaux

**Modèles disponibles** :
- XTTS v2 (multi-langue, cloning voix)
- VITS (neuronal rapide)
- Tacotron 2 (classique)

**Qualité voix française** : ⭐⭐⭐⭐⭐ (5/5)
- Exceptionnelle avec XTTS v2
- Très naturel
- Expressif

**Fluidité** : ⭐⭐⭐⭐⭐ (5/5)
- Très fluide
- Expressions émotionnelles
- Prosodie naturelle

**Vitesse** :
- VITS : 0.5-1s (rapide)
- XTTS v2 : 2-5s (plus lent)
- Tacotron 2 : 3-8s (lent)

**Coût** : Gratuit (open-source)

**Consommation serveur** :
- CPU : 2-4 vCPU (VITS), 4-8 vCPU (XTTS)
- RAM : 2-4 GB (VITS), 8-16 GB (XTTS)
- Stockage : 1-2 GB (modèles)

**Facilité d'intégration Flutter** : ⭐⭐⭐ (3/5)
- Pas de package Flutter natif
- Nécessite appel API REST/WebSocket
- Streaming audio possible

**Avantages** :
- ✅ Qualité exceptionnelle
- ✅ Cloning voix possible
- ✅ Multi-langue
- ✅ Expressif

**Inconvénients** :
- ❌ Lourd (XTTS)
- ❌ Lent (XTTS)
- ❌ Pas de package Flutter natif
- ❌ Complexité déploiement

---

### Option C : Google Cloud TTS

**Description** : Service cloud TTS de Google

**Voix disponibles** :
- Plusieurs voix françaises (standard, WaveNet, Neural2)
- Qualité variable

**Qualité voix française** : ⭐⭐⭐⭐⭐ (5/5)
- Exceptionnelle avec Neural2
- Très naturel
- Expressif

**Fluidité** : ⭐⭐⭐⭐⭐ (5/5)
- Parfaitement fluide
- Expressions émotionnelles
- Prosodie naturelle

**Vitesse** :
- 0.5-2s (dépend réseau)

**Coût** :
- Standard : $4/1M caractères
- WaveNet : $16/1M caractères
- Neural2 : $32/1M caractères

**Consommation serveur** :
- Négligeable (traitement cloud)

**Facilité d'intégration Flutter** : ⭐⭐⭐⭐⭐ (5/5)
- Package Flutter disponible
- Documentation complète
- Streaming audio

**Avantages** :
- ✅ Qualité exceptionnelle
- ✅ Facile à intégrer
- ✅ Streaming
- ✅ Évolutif

**Inconvénients** :
- ❌ Coût élevé
- ❌ Dépendance internet
- ❌ Confidentialité (texte envoyé à Google)

---

### Option D : Amazon Polly

**Description** : Service cloud TTS d'Amazon

**Voix disponibles** :
- Plusieurs voix françaises (standard, Neural)
- Qualité variable

**Qualité voix française** : ⭐⭐⭐⭐⭐ (5/5)
- Exceptionnelle avec Neural
- Très naturel
- Expressif

**Fluidité** : ⭐⭐⭐⭐⭐ (5/5)
- Parfaitement fluide
- Expressions émotionnelles
- Prosodie naturelle

**Vitesse** :
- 0.5-2s (dépend réseau)

**Coût** :
- Standard : $4/1M caractères
- Neural : $16/1M caractères

**Consommation serveur** :
- Négligeable (traitement cloud)

**Facilité d'intégration Flutter** : ⭐⭐⭐⭐ (4/5)
- SDK AWS disponible
- Documentation complète
- Streaming audio

**Avantages** :
- ✅ Qualité exceptionnelle
- ✅ Facile à intégrer
- ✅ Streaming
- ✅ Évolutif

**Inconvénients** :
- ❌ Coût élevé
- ❌ Dépendance internet
- ❌ Confidentialité (texte envoyé à Amazon)

---

### Option E : ElevenLabs

**Description** : Service cloud TTS avec IA avancée

**Voix disponibles** :
- Voix ultra-réalistes
- Cloning voix
- Émotions

**Qualité voix française** : ⭐⭐⭐⭐⭐ (5/5)
- La meilleure qualité du marché
- Ultra-réaliste
- Expressif

**Fluidité** : ⭐⭐⭐⭐⭐ (5/5)
- Parfaitement fluide
- Expressions émotionnelles avancées
- Prosodie naturelle

**Vitesse** :
- 1-3s (dépend réseau)

**Coût** :
- Starter : $5/mois (30k caractères)
- Creator : $22/mois (100k caractères)
- Pro : $99/mois (500k caractères)

**Consommation serveur** :
- Négligeable (traitement cloud)

**Facilité d'intégration Flutter** : ⭐⭐⭐⭐ (4/5)
- API REST disponible
- Documentation complète
- Streaming audio

**Avantages** :
- ✅ Qualité exceptionnelle
- ✅ Cloning voix
- ✅ Émotions
- ✅ Ultra-réaliste

**Inconvénients** :
- ❌ Coût très élevé
- ❌ Dépendance internet
- ❌ Confidentialité (texte envoyé à ElevenLabs)

---

## COMPARAISON SYNTHÉTIQUE

| Critère | Piper | Coqui TTS | Google Cloud TTS | Amazon Polly | ElevenLabs |
|---------|-------|-----------|------------------|--------------|------------|
| Qualité voix française | 4/5 | 5/5 | 5/5 | 5/5 | 5/5 |
| Fluidité | 4/5 | 5/5 | 5/5 | 5/5 | 5/5 |
| Vitesse | 1-2s | 2-5s | 0.5-2s | 0.5-2s | 1-3s |
| CPU | 1-2 vCPU | 2-8 vCPU | N/A | N/A | N/A |
| RAM | 1-2 GB | 2-16 GB | N/A | N/A | N/A |
| Coût | Gratuit | Gratuit | $4-32/1M | $4-16/1M | $5-99/mois |
| Offline | ✅ | ✅ | ❌ | ❌ | ❌ |
| Confidentialité | ✅ | ✅ | ❌ | ❌ | ❌ |
| Intégration Flutter | 3/5 | 3/5 | 5/5 | 4/5 | 4/5 |

---

## RECOMMANDATION

**Piper (modèle medium)**

**Justification** :
1. **Qualité** : 4/5 (suffisant pour assistant IA)
2. **Performance** : Rapide (1-2s)
3. **Ressources** : 1-2 vCPU, 1-2 GB RAM (compatible Kamatera)
4. **Coût** : Gratuit
5. **Confidentialité** : Offline (texte non envoyé à tiers)
6. **Déploiement** : Simple (pip install)
7. **Flutter** : Intégration via API REST/WebSocket

**Configuration recommandée** :
- Modèle : `medium` (équilibre qualité/vitesse)
- Voix : `fr-french-medium` (voix française standard)
- Vitesse : 1.0x (normale)
- Pitch : 1.0x (normal)

**Commande installation** :
```bash
pip install piper-tts
```

**Code exemple** :
```python
from piper import PiperVoice

voice = PiperVoice.load("fr-french-medium", "cpu")
audio = voice.synthesize("Bonjour, comment puis-je vous aider ?")
```

**Intégration Flutter** :
- API REST pour génération audio
- WebSocket pour streaming
- Flutter : `flutter_sound` ou `just_audio` pour playback

---

## ALTERNATIVE SI QUALITÉ REQUISE

**Coqui TTS (VITS)**

- CPU : 2-4 vCPU
- RAM : 2-4 GB
- Temps : 0.5-1s
- Qualité : 5/5 (exceptionnelle)

**Justification** : Si la qualité vocale est critique et que les ressources le permettent, VITS offre une qualité exceptionnelle avec une bonne performance.

---

## ALTERNATIVE SI COÛT ACCEPTABLE

**Google Cloud TTS (Standard)**

- Coût : $4/1M caractères
- Temps : 0.5-2s
- Qualité : 5/5
- Intégration : 5/5 (package Flutter)

**Justification** : Si le coût n'est pas un problème et que l'intégration Flutter facile est prioritaire, Google Cloud TTS offre la meilleure qualité avec une intégration simple.

---

**RAPPORT PHASE 4 TERMINÉ**
