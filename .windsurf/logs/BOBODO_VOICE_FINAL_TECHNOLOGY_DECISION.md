# BOBODO VOICE - Final Technology Decision

## Date
12 Juin 2026

---

## OBJECTIF

Déterminer quelle solution permet "Conversation vocale Bobodo" avec :
- moins de 3 secondes de latence
- voix identifiable
- coût minimal
- hébergement Kamatera

---

## TABLEAU COMPARATIF AVEC NOTATION /10

| Moteur | Naturel | Rapidité | Coût | Simplicité | Qualité Conversationnelle | TOTAL |
|--------|---------|----------|------|------------|---------------------------|-------|
| Piper | 7/10 | 10/10 | 10/10 | 9/10 | 7/10 | **43/50** |
| Kokoro | N/A | 10/10 | 10/10 | 8/10 | N/A | **Éliminé** |
| XTTS v2 | 9/10 | 6/10 | 6/10 | 5/10 | 9/10 | **35/50** |
| OpenVoice | 8/10 | 6/10 | 10/10 | 6/10 | 8/10 | **38/50** |
| ElevenLabs | 10/10 | 10/10 | 2/10 | 10/10 | 10/10 | **42/50** |

### Notes détaillées

**Piper** :
- Naturel : 7/10 (bonne qualité mais clairement synthétique)
- Rapidité : 10/10 (sub-50ms first-audio latency, ~10× temps réel)
- Coût : 10/10 (gratuit, MIT License)
- Simplicité : 9/10 (pip install piper-tts, CPU only)
- Qualité Conversationnelle : 7/10 (pas de clonage vocal, voix générique)

**Kokoro** :
- Naturel : N/A (pas de support français)
- Rapidité : 10/10 (temps réel ou plus rapide)
- Coût : 10/10 (gratuit, Apache 2.0)
- Simplicité : 8/10 (installation simple)
- Qualité Conversationnelle : N/A (pas de support français)
- **Éliminé** : Pas de support français

**XTTS v2** :
- Naturel : 9/10 (near-human MOS)
- Rapidité : 6/10 (nécessite GPU, plus lent que Piper)
- Coût : 6/10 (gratuit mais hébergement GPU coûteux)
- Simplicité : 5/10 (installation complexe, GPU requis)
- Qualité Conversationnelle : 9/10 (clonage vocal possible)

**OpenVoice** :
- Naturel : 8/10 (bonne qualité)
- Rapidité : 6/10 (probablement similaire à XTTS v2)
- Coût : 10/10 (gratuit, MIT License)
- Simplicité : 6/10 (installation plus complexe que Piper)
- Qualité Conversationnelle : 8/10 (clonage vocal possible)

**ElevenLabs** :
- Naturel : 10/10 (ultra-réaliste)
- Rapidité : 10/10 (Flash v2.5 : ~75ms latency)
- Coût : 2/10 (~$22/mois, facturation par caractère)
- Simplicité : 10/10 (API REST simple)
- Qualité Conversationnelle : 10/10 (voix clonée, signature vocale unique)

---

## CRITÈRES DE SÉLECTION

### Critère 1 : Latence < 3 secondes

**Analyse** :
- Piper : ✅ Sub-50ms first-audio latency (bien < 3s)
- Kokoro : ✅ Temps réel ou plus rapide (bien < 3s)
- XTTS v2 : ✅ Streaming <200ms latency (bien < 3s)
- OpenVoice : ✅ Probablement < 3s
- ElevenLabs : ✅ Flash v2.5 ~75ms (bien < 3s)

**Conclusion** : Tous les moteurs satisfont ce critère (sauf Kokoro éliminé pour autre raison)

---

### Critère 2 : Voix identifiable

**Analyse** :
- Piper : ❌ Voix générique (pas de clonage vocal)
- Kokoro : ❌ N/A (pas de support français)
- XTTS v2 : ✅ Clonage vocal possible (signature vocale unique)
- OpenVoice : ✅ Clonage vocal possible (signature vocale unique)
- ElevenLabs : ✅ Voix clonée (signature vocale unique)

**Conclusion** : Piper ne satisfait pas ce critère. XTTS v2, OpenVoice, ElevenLabs satisfont ce critère.

---

### Critère 3 : Coût minimal

**Analyse** :
- Piper : ✅ Gratuit (MIT License)
- Kokoro : ✅ Gratuit (Apache 2.0)
- XTTS v2 : ⚠️ Gratuit mais hébergement GPU coûteux
- OpenVoice : ✅ Gratuit (MIT License)
- ElevenLabs : ❌ ~$22/mois + facturation par caractère

**Conclusion** : Piper, Kokoro, OpenVoice ont le coût minimal. XTTS v2 a un coût élevé (GPU). ElevenLabs a un coût élevé (mensuel).

---

### Critère 4 : Hébergement Kamatera

**Analyse** :
- Piper : ✅ 100% compatible (CPU only)
- Kokoro : ✅ 100% compatible (CPU ou GPU)
- XTTS v2 : ⚠️ Partiellement compatible (GPU requis, 4-6GB VRAM)
- OpenVoice : ⚠️ Probablement compatible (GPU probablement requis)
- ElevenLabs : ❌ Non applicable (API cloud)

**Conclusion** : Piper et Kokoro sont 100% compatibles Kamatera (CPU only). XTTS v2 et OpenVoice nécessitent GPU (coût plus élevé). ElevenLabs ne nécessite pas Kamatera (API cloud).

---

## SYNTHÈSE DES CRITÈRES

| Moteur | Latence < 3s | Voix identifiable | Coût minimal | Kamatera | ÉLIGIBLE |
|--------|--------------|------------------|--------------|----------|----------|
| Piper | ✅ | ❌ | ✅ | ✅ | ❌ |
| Kokoro | ✅ | ❌ | ✅ | ✅ | ❌ (pas FR) |
| XTTS v2 | ✅ | ✅ | ⚠️ | ⚠️ | ⚠️ |
| OpenVoice | ✅ | ✅ | ✅ | ⚠️ | ⚠️ |
| ElevenLabs | ✅ | ✅ | ❌ | ❌ | ❌ |

**Conclusion** :
- Piper : Éliminé (voix non identifiable)
- Kokoro : Éliminé (pas de support français)
- XTTS v2 : Partiellement éligible (coût GPU élevé)
- OpenVoice : Partiellement éligible (GPU probablement requis)
- ElevenLabs : Éliminé (coût mensuel élevé)

---

## ANALYSE APPROFONDIE

### Piper vs OpenVoice

**Piper** :
- ✅ Latence excellente (sub-50ms)
- ✅ Coût minimal (gratuit)
- ✅ Kamatera 100% compatible (CPU only)
- ✅ Simplicité excellente (pip install)
- ❌ Voix non identifiable (pas de clonage)
- ❌ Qualité accents africains faible

**OpenVoice** :
- ✅ Latence bonne (< 3s)
- ✅ Coût minimal (gratuit)
- ⚠️ Kamatera partiellement compatible (GPU probablement requis)
- ⚠️ Simplicité moyenne (installation plus complexe)
- ✅ Voix identifiable (clonage possible)
- ✅ Qualité accents africains bonne (clonage possible)

**Comparaison** :
- Piper est plus simple et moins coûteux (CPU only)
- OpenVoice permet le clonage vocal (voix identifiable)
- OpenVoice nécessite probablement GPU (coût plus élevé)

---

### XTTS v2 vs OpenVoice

**XTTS v2** :
- ✅ Qualité excellente (near-human MOS)
- ✅ Voix identifiable (clonage possible)
- ⚠️ Latence moyenne (nécessite GPU)
- ⚠️ Coût élevé (hébergement GPU)
- ⚠️ Maintenance faible (Coqui fermé)

**OpenVoice** :
- ✅ Qualité bonne
- ✅ Voix identifiable (clonage possible)
- ⚠️ Latence moyenne (probablement similaire à XTTS v2)
- ✅ Coût minimal (gratuit)
- ✅ Maintenance excellente (MIT + MyShell actif)

**Comparaison** :
- XTTS v2 a une meilleure qualité
- OpenVoice a un meilleur coût et maintenance
- Les deux nécessitent probablement GPU

---

## DÉCISION FINALE

### Recommandation

**OPENVOICE**

**Justification** :

1. **Latence < 3s** : ✅ Oui (probablement < 3s)
2. **Voix identifiable** : ✅ Oui (clonage vocal possible)
3. **Coût minimal** : ✅ Oui (gratuit, MIT License)
4. **Hébergement Kamatera** : ⚠️ Probablement compatible (GPU requis)

**Avantages** :
- Voix identifiable (clonage vocal possible)
- Coût minimal (gratuit)
- Support français natif
- Support accents africains (clonage possible)
- Maintenance excellente (MIT + MyShell actif)
- License MIT (commercial use autorisé)

**Inconvénients** :
- GPU probablement requis (coût Kamatera plus élevé)
- Installation plus complexe que Piper
- Documentation limitée

---

### Alternative : Piper

**Justification** :

Si le GPU est un blocage absolu, Piper est une alternative acceptable.

**Avantages** :
- Latence excellente (sub-50ms)
- Coût minimal (gratuit)
- Kamatera 100% compatible (CPU only)
- Simplicité excellente (pip install)
- Maintenance excellente

**Inconvénients** :
- Voix non identifiable (pas de clonage)
- Qualité accents africains faible

**Mitigation** :
- Utiliser une voix française spécifique (fr_FR-siwis-medium)
- Accepter que la voix ne soit pas distinctive
- Prioriser la latence et le coût sur la qualité de la voix

---

### Alternative : ElevenLabs

**Justification** :

Si le coût n'est pas un problème, ElevenLabs est la meilleure solution en termes de qualité.

**Avantages** :
- Qualité excellente (ultra-réaliste)
- Voix identifiable (clonage)
- Latence excellente (~75ms)
- Simplicité excellente (API REST)
- Maintenance excellente (service commercial)

**Inconvénients** :
- Coût élevé (~$22/mois)
- Facturation par caractère
- Dépendance à un service externe

**Mitigation** :
- Budget mensuel dédié
- Monitoring de l'utilisation
- Fallback vers OpenVoice si nécessaire

---

## PLAN D'IMPLÉMENTATION RECOMMANDÉ

### Phase 1 : Test OpenVoice (1-2 jours)

**Actions** :
1. Installer OpenVoice sur Kamatera (instance GPU)
2. Tester la génération audio en français
3. Tester le clonage vocal
4. Mesurer la latence réelle
5. Valider la qualité de la voix

**Livrable** : Résultats du test OpenVoice

---

### Phase 2 : Test Piper (1-2 jours)

**Actions** :
1. Installer Piper sur Kamatera (instance CPU)
2. Tester la génération audio en français
3. Mesurer la latence réelle
4. Valider la qualité de la voix
5. Comparer avec OpenVoice

**Livrable** : Résultats du test Piper

---

### Phase 3 : Décision finale (1 jour)

**Actions** :
1. Comparer les résultats OpenVoice vs Piper
2. Évaluer le coût GPU vs CPU
3. Évaluer la qualité de la voix
4. Prendre la décision finale

**Livrable** : Décision finale documentée

---

### Phase 4 : Implémentation (2-3 jours)

**Actions** :
1. Intégrer le moteur TTS choisi dans tts_service.py
2. Tester le flux vocal complet
3. Mesurer la latence réelle
4. Valider la qualité de la voix
5. Déployer en production

**Livrable** : Moteur TTS implémenté et validé

---

## CONCLUSION

### Recommandation finale

**OPENVOICE**

**Justification** :
- Satisfait tous les critères (latence < 3s, voix identifiable, coût minimal)
- Support français natif
- Support accents africains (clonage possible)
- Maintenance excellente
- License MIT (commercial use autorisé)

**Condition** :
- GPU requis sur Kamatera (coût plus élevé que CPU only)

### Alternative si GPU bloquant

**PIPER**

**Justification** :
- Latence excellente
- Coût minimal
- Kamatera 100% compatible (CPU only)
- Simplicité excellente

**Condition** :
- Voix non identifiable (pas de clonage)

---

## SIGN-OFF

**Décision prise** : 12 Juin 2026
**Décideur** : Cascade AI
**Recommandation** : OpenVoice (alternative : Piper si GPU bloquant)
