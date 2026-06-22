# BOBODO PIPER VS OPENVOICE - Final Comparison

## Date
12 Juin 2026

---

## OBJECTIF

Comparer Piper et OpenVoice dans le contexte réel Academia.

---

## CONTEXTE RÉEL ACADEMIA

### Infrastructure Kamatera

**Instance actuelle** : CPU only (pas de GPU)

**Justification** :
- Serveur Kamatera actuel : 185.167.97.144
- Instance CPU (pas de GPU)
- Coût CPU : inférieur à GPU

**Conclusion** : Kamatera actuel = CPU only

---

### Architecture réelle

**Serveur vocal** : Python + WebSocket

**Composants** :
- STT : Faster Whisper Small (CPU)
- TTS : gTTS (actuel) → à remplacer
- WebSocket : ws://185.167.97.144:8000/ws

**Justification** :
- Architecture existante CPU only
- Pas de GPU dans l'architecture actuelle

**Conclusion** : Architecture = CPU only

---

### Contraintes réelles Academia

**Contrainte 1** : Coût minimal

**Justification** :
- Academia est une startup
- Budget limité
- Coût GPU plus élevé que CPU

**Conclusion** : Coût minimal = priorité

---

**Contrainte 2** : Latence < 3 secondes

**Justification** :
- Conversation vocale en temps réel
- Expérience utilisateur acceptable
- Comparable à ChatGPT Voice

**Conclusion** : Latence < 3s = requis

---

**Contrainte 3** : Voix identifiable

**Justification** :
- Bobodo doit avoir une identité vocale
- Reconnaissance possible après plusieurs conversations

**Conclusion** : Voix identifiable = souhaitable mais pas bloquant pour V1

---

## COMPARAISON RÉALISTE

### Critère 1 : Coût

**Piper** :
- Coût : Gratuit (MIT License)
- Hébergement : CPU Kamatera (coût minimal)
- Total : Coût minimal

**OpenVoice** :
- Coût : Gratuit (MIT License)
- Hébergement : GPU Kamatera (coût élevé)
- Total : Coût élevé

**Conclusion** : ✅ **PIPER GAGNE** (coût minimal)

---

### Critère 2 : Latence

**Piper** :
- Latence CPU : Sub-50ms first-audio latency
- Latence totale : < 1s
- Conclusion : ✅ < 3s requis

**OpenVoice** :
- Latence CPU : 30-120 secondes
- Latence GPU : 2-5 secondes
- Conclusion : ❌ CPU inacceptable, ⚠️ GPU marginale

**Conclusion** : ✅ **PIPER GAGNE** (latence excellente)

---

### Critère 3 : Maintenance

**Piper** :
- Projet actif (Rhasspy)
- Communauté active
- Mises à jour régulières
- Documentation complète
- Conclusion : ✅ Maintenance excellente

**OpenVoice** :
- Projet actif (MIT + MyShell)
- Communauté active
- Mises à jour régulières
- Documentation complète
- Conclusion : ✅ Maintenance excellente

**Conclusion** : ⚠️ **ÉGALITÉ** (maintenance excellente pour les deux)

---

### Critère 4 : Charge serveur

**Piper** :
- CPU only
- RAM : 2GB+ (voice pack 20-200MB)
- CPU usage : modéré (~10× temps réel)
- Conclusion : ✅ Charge serveur minimale

**OpenVoice** :
- GPU requis (RTX 3060, 8GB VRAM)
- RAM : 8-16GB
- CPU usage : élevé (si CPU only)
- Conclusion : ❌ Charge serveur élevée

**Conclusion** : ✅ **PIPER GAGNE** (charge serveur minimale)

---

### Critère 5 : Expérience utilisateur

**Piper** :
- Latence : < 1s (excellente)
- Qualité : Bonne mais clairement synthétique
- Voix : Générique (pas identifiable)
- Conclusion : ⚠️ Expérience acceptable mais voix non distinctive

**OpenVoice** :
- Latence CPU : 30-120s (inacceptable)
- Latence GPU : 2-5s (marginale)
- Qualité : Bonne, clonage vocal possible
- Voix : Identifiable (clonage possible)
- Conclusion : ❌ Expérience inacceptable sur CPU, marginale sur GPU

**Conclusion** : ✅ **PIPER GAGNE** (expérience acceptable sur CPU)

---

### Critère 6 : Risque opérationnel

**Piper** :
- Dépendances : minimales (pip install piper-tts)
- Installation : simple
- GPU : non requis
- Conclusion : ✅ Risque opérationnel minimal

**OpenVoice** :
- Dépendances : PyTorch, CUDA (si GPU)
- Installation : complexe
- GPU : requis
- Conclusion : ❌ Risque opérationnel élevé

**Conclusion** : ✅ **PIPER GAGNE** (risque opérationnel minimal)

---

## SYNTHÈSE

| Critère | Piper | OpenVoice | Gagnant |
|---------|-------|-----------|---------|
| Coût | Gratuit (CPU) | Gratuit (GPU) | ✅ Piper |
| Latence | < 1s | 30-120s (CPU) / 2-5s (GPU) | ✅ Piper |
| Maintenance | Excellente | Excellente | ⚠️ Égalité |
| Charge serveur | Minimale | Élevée | ✅ Piper |
| Expérience utilisateur | Acceptable | Inacceptable (CPU) / Marginale (GPU) | ✅ Piper |
| Risque opérationnel | Minimal | Élevé | ✅ Piper |

**Score** : Piper 5/6, OpenVoice 0/6

---

## DÉCISION FINALE

### Recommandation

**PIPER**

**Justification technique fondée exclusivement sur** :

1. **Kamatera réel** : Instance CPU only (pas de GPU)
   - Piper : 100% compatible (CPU only)
   - OpenVoice : Non compatible (GPU requis)

2. **Architecture réelle** : CPU only (pas de GPU)
   - Piper : 100% compatible (CPU only)
   - OpenVoice : Non compatible (GPU requis)

3. **Contraintes réelles Academia** :
   - Coût minimal : Piper (CPU) < OpenVoice (GPU)
   - Latence < 3s : Piper (< 1s) > OpenVoice (30-120s CPU / 2-5s GPU)
   - Maintenance : Égalité (excellente pour les deux)
   - Charge serveur : Piper (minimale) < OpenVoice (élevée)
   - Expérience utilisateur : Piper (acceptable) > OpenVoice (inacceptable CPU)
   - Risque opérationnel : Piper (minimal) < OpenVoice (élevé)

**Conclusion** : Piper est la seule solution compatible avec l'infrastructure Academia actuelle.

---

## PLAN D'IMPLÉMENTATION

### Phase 1 : Piper (V1 - Immédiat)

**Actions** :
1. Installer Piper sur Kamatera (instance CPU)
2. Télécharger la voix fr_FR-siwis-medium
3. Intégrer Piper dans tts_service.py
4. Tester le flux vocal complet
5. Mesurer la latence réelle
6. Déployer en production

**Livrable** : Piper implémenté et validé

**Durée** : 2-3 jours

---

### Phase 2 : Voix distinctive (V2 - Futur)

**Actions** :
1. Évaluer le besoin de voix distinctive
2. Si nécessaire, migrer vers OpenVoice ou XTTS v2
3. Upgrader Kamatera vers instance GPU
4. Tester le clonage vocal
5. Déployer en production

**Livrable** : Voix distinctive implémentée

**Durée** : 5-7 jours

**Condition** : Budget GPU disponible

---

## CONCLUSION

### Recommandation finale

**PIPER**

**Justification** :
- 100% compatible avec Kamatera actuel (CPU only)
- Latence excellente (< 1s)
- Coût minimal
- Charge serveur minimale
- Expérience utilisateur acceptable
- Risque opérationnel minimal

**Limitation** : Voix non identifiable (pas de clonage)

**Mitigation** : Accepter pour V1, migrer vers OpenVoice ou XTTS v2 pour V2 si nécessaire

---

## SIGN-OFF

**Comparaison réalisée** : 12 Juin 2026
**Comparateur** : Cascade AI
**Recommandation** : PIPER
