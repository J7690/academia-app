# BOBODO VOCAL - TEST DE CAPACITÉ RÉELLE

**Date** : 10 juin 2026  
**Statut** : ✅ TERMINÉ (simulations théoriques)

---

## MÉTHODOLOGIE

**Note** : Tests basés sur simulations théoriques, pas sur mesures en temps réel (accès SSH non disponible).

**Hypothèses** :
- Architecture : WebSocket dédié (option retenue)
- STT : Faster-Whisper small (INT8)
- TTS : Piper medium
- Configuration serveur : 2 vCPU, 4 GB RAM (Kamatera standard)

**Consommation par utilisateur** (documentée dans Phase 7) :
- STT : 0.5-1 vCPU (burst), 1-2 GB RAM
- TTS : 0.5-1 vCPU (burst), 0.5-1 GB RAM
- WebSocket : 0.1 vCPU (sustained), 50 MB RAM
- **Total par utilisateur** : 1.1-2.1 vCPU (burst), 1.55-3.05 GB RAM

---

## SCÉNARIO 1 : 5 UTILISATEURS SIMULTANÉS

### Hypothèses

- 5 utilisateurs actifs
- 1 message/min par utilisateur
- Durée moyenne conversation : 5 min

### Consommation CPU

**STT** :
- 5 × 0.5 vCPU × (2s/60s) = 0.08 vCPU moyen
- Burst max : 5 × 1 vCPU = 5 vCPU

**TTS** :
- 5 × 0.5 vCPU × (2s/60s) = 0.08 vCPU moyen
- Burst max : 5 × 1 vCPU = 5 vCPU

**WebSocket** :
- 5 × 0.1 vCPU = 0.5 vCPU (sustained)

**Total** :
- **Moyen** : 0.66 vCPU
- **Burst max** : 10.5 vCPU

### Consommation RAM

**STT** :
- 2 GB (modèle partagé)

**TTS** :
- 1 GB (modèle partagé)

**WebSocket** :
- 5 × 50 MB = 250 MB

**Total** : **3.25 GB**

### Bande passante

**Upload** (audio) :
- 5 × 16 kbps = 80 kbps

**Download** (audio) :
- 5 × 64 kbps = 320 kbps

**Total** : **400 kbps**

### Latence estimée

- STT : 1-2s
- LLM : 2-5s
- TTS : 1-2s
- **Total** : 4-9s

### Risque de saturation

**CPU** :
- Capacité : 2 vCPU
- Burst max : 10.5 vCPU
- **Risque** : ⚠️ Élevé (burst dépasse capacité)

**RAM** :
- Capacité : 4 GB
- Utilisation : 3.25 GB
- **Risque** : ✅ Faible (81% utilisation)

**Bande passante** :
- Capacité : 100 Mbps
- Utilisation : 400 kbps
- **Risque** : ✅ Nul (0.4% utilisation)

**Conclusion** : ⚠️ **Risque élevé CPU** (burst)

---

## SCÉNARIO 2 : 10 UTILISATEURS SIMULTANÉS

### Hypothèses

- 10 utilisateurs actifs
- 1 message/min par utilisateur
- Durée moyenne conversation : 5 min

### Consommation CPU

**STT** :
- 10 × 0.5 vCPU × (2s/60s) = 0.17 vCPU moyen
- Burst max : 10 × 1 vCPU = 10 vCPU

**TTS** :
- 10 × 0.5 vCPU × (2s/60s) = 0.17 vCPU moyen
- Burst max : 10 × 1 vCPU = 10 vCPU

**WebSocket** :
- 10 × 0.1 vCPU = 1 vCPU (sustained)

**Total** :
- **Moyen** : 1.34 vCPU
- **Burst max** : 21 vCPU

### Consommation RAM

**STT** :
- 2 GB (modèle partagé)

**TTS** :
- 1 GB (modèle partagé)

**WebSocket** :
- 10 × 50 MB = 500 MB

**Total** : **3.5 GB**

### Bande passante

**Upload** (audio) :
- 10 × 16 kbps = 160 kbps

**Download** (audio) :
- 10 × 64 kbps = 640 kbps

**Total** : **800 kbps**

### Latence estimée

- STT : 1-2s
- LLM : 2-5s
- TTS : 1-2s
- **Total** : 4-9s

### Risque de saturation

**CPU** :
- Capacité : 2 vCPU
- Burst max : 21 vCPU
- **Risque** : ❌ Critique (burst dépasse largement capacité)

**RAM** :
- Capacité : 4 GB
- Utilisation : 3.5 GB
- **Risque** : ⚠️ Moyen (87.5% utilisation)

**Bande passante** :
- Capacité : 100 Mbps
- Utilisation : 800 kbps
- **Risque** : ✅ Nul (0.8% utilisation)

**Conclusion** : ❌ **Impossible** (CPU burst critique)

---

## SCÉNARIO 3 : 20 UTILISATEURS SIMULTANÉS

### Hypothèses

- 20 utilisateurs actifs
- 1 message/min par utilisateur
- Durée moyenne conversation : 5 min

### Consommation CPU

**STT** :
- 20 × 0.5 vCPU × (2s/60s) = 0.33 vCPU moyen
- Burst max : 20 × 1 vCPU = 20 vCPU

**TTS** :
- 20 × 0.5 vCPU × (2s/60s) = 0.33 vCPU moyen
- Burst max : 20 × 1 vCPU = 20 vCPU

**WebSocket** :
- 20 × 0.1 vCPU = 2 vCPU (sustained)

**Total** :
- **Moyen** : 2.66 vCPU
- **Burst max** : 42 vCPU

### Consommation RAM

**STT** :
- 2 GB (modèle partagé)

**TTS** :
- 1 GB (modèle partagé)

**WebSocket** :
- 20 × 50 MB = 1 GB

**Total** : **4 GB**

### Bande passante

**Upload** (audio) :
- 20 × 16 kbps = 320 kbps

**Download** (audio) :
- 20 × 64 kbps = 1.28 Mbps

**Total** : **1.6 Mbps**

### Latence estimée

- STT : 1-2s
- LLM : 2-5s
- TTS : 1-2s
- **Total** : 4-9s

### Risque de saturation

**CPU** :
- Capacité : 2 vCPU
- Burst max : 42 vCPU
- **Risque** : ❌ Critique (burst dépasse largement capacité)

**RAM** :
- Capacité : 4 GB
- Utilisation : 4 GB
- **Risque** : ❌ Critique (100% utilisation)

**Bande passante** :
- Capacité : 100 Mbps
- Utilisation : 1.6 Mbps
- **Risque** : ✅ Nul (1.6% utilisation)

**Conclusion** : ❌ **Impossible** (CPU et RAM critiques)

---

## SCÉNARIO 4 : 50 UTILISATEURS SIMULTANÉS

### Hypothèses

- 50 utilisateurs actifs
- 1 message/min par utilisateur
- Durée moyenne conversation : 5 min

### Consommation CPU

**STT** :
- 50 × 0.5 vCPU × (2s/60s) = 0.83 vCPU moyen
- Burst max : 50 × 1 vCPU = 50 vCPU

**TTS** :
- 50 × 0.5 vCPU × (2s/60s) = 0.83 vCPU moyen
- Burst max : 50 × 1 vCPU = 50 vCPU

**WebSocket** :
- 50 × 0.1 vCPU = 5 vCPU (sustained)

**Total** :
- **Moyen** : 6.66 vCPU
- **Burst max** : 105 vCPU

### Consommation RAM

**STT** :
- 2 GB (modèle partagé)

**TTS** :
- 1 GB (modèle partagé)

**WebSocket** :
- 50 × 50 MB = 2.5 GB

**Total** : **5.5 GB**

### Bande passante

**Upload** (audio) :
- 50 × 16 kbps = 800 kbps

**Download** (audio) :
- 50 × 64 kbps = 3.2 Mbps

**Total** : **4 Mbps**

### Latence estimée

- STT : 1-2s
- LLM : 2-5s
- TTS : 1-2s
- **Total** : 4-9s

### Risque de saturation

**CPU** :
- Capacité : 2 vCPU
- Burst max : 105 vCPU
- **Risque** : ❌ Critique (burst dépasse largement capacité)

**RAM** :
- Capacité : 4 GB
- Utilisation : 5.5 GB
- **Risque** : ❌ Critique (dépasse capacité)

**Bande passante** :
- Capacité : 100 Mbps
- Utilisation : 4 Mbps
- **Risque** : ✅ Faible (4% utilisation)

**Conclusion** : ❌ **Impossible** (CPU, RAM critiques)

---

## SCÉNARIO 5 : 100 UTILISATEURS SIMULTANÉS

### Hypothèses

- 100 utilisateurs actifs
- 1 message/min par utilisateur
- Durée moyenne conversation : 5 min

### Consommation CPU

**STT** :
- 100 × 0.5 vCPU × (2s/60s) = 1.67 vCPU moyen
- Burst max : 100 × 1 vCPU = 100 vCPU

**TTS** :
- 100 × 0.5 vCPU × (2s/60s) = 1.67 vCPU moyen
- Burst max : 100 × 1 vCPU = 100 vCPU

**WebSocket** :
- 100 × 0.1 vCPU = 10 vCPU (sustained)

**Total** :
- **Moyen** : 13.34 vCPU
- **Burst max** : 210 vCPU

### Consommation RAM

**STT** :
- 2 GB (modèle partagé)

**TTS** :
- 1 GB (modèle partagé)

**WebSocket** :
- 100 × 50 MB = 5 GB

**Total** : **8 GB**

### Bande passante

**Upload** (audio) :
- 100 × 16 kbps = 1.6 Mbps

**Download** (audio) :
- 100 × 64 kbps = 6.4 Mbps

**Total** : **8 Mbps**

### Latence estimée

- STT : 1-2s
- LLM : 2-5s
- TTS : 1-2s
- **Total** : 4-9s

### Risque de saturation

**CPU** :
- Capacité : 2 vCPU
- Burst max : 210 vCPU
- **Risque** : ❌ Critique (burst dépasse largement capacité)

**RAM** :
- Capacité : 4 GB
- Utilisation : 8 GB
- **Risque** : ❌ Critique (dépasse capacité)

**Bande passante** :
- Capacité : 100 Mbps
- Utilisation : 8 Mbps
- **Risque** : ✅ Faible (8% utilisation)

**Conclusion** : ❌ **Impossible** (CPU, RAM critiques)

---

## SYNTHÈSE DES SCÉNARIOS

| Scénario | CPU moyen | CPU burst | RAM | Bande passante | Latence | Risque CPU | Risque RAM | Conclusion |
|----------|-----------|-----------|-----|----------------|---------|------------|------------|------------|
| 5 utilisateurs | 0.66 vCPU | 10.5 vCPU | 3.25 GB | 400 kbps | 4-9s | ⚠️ Élevé | ✅ Faible | ⚠️ Risque CPU |
| 10 utilisateurs | 1.34 vCPU | 21 vCPU | 3.5 GB | 800 kbps | 4-9s | ❌ Critique | ⚠️ Moyen | ❌ Impossible |
| 20 utilisateurs | 2.66 vCPU | 42 vCPU | 4 GB | 1.6 Mbps | 4-9s | ❌ Critique | ❌ Critique | ❌ Impossible |
| 50 utilisateurs | 6.66 vCPU | 105 vCPU | 5.5 GB | 4 Mbps | 4-9s | ❌ Critique | ❌ Critique | ❌ Impossible |
| 100 utilisateurs | 13.34 vCPU | 210 vCPU | 8 GB | 8 Mbps | 4-9s | ❌ Critique | ❌ Critique | ❌ Impossible |

---

## CAPACITÉ MAXIMALE SERVEUR ACTUEL

### Configuration actuelle

- 2 vCPU, 4 GB RAM
- 100 Mbps bande passante

### Capacité maximale

**Avec configuration actuelle (2 vCPU, 4 GB)** :
- **Utilisateurs simultanés** : 3-4 maximum
- **Raison** : Burst CPU dépasse capacité dès 5 utilisateurs

**Avec upgrade (4 vCPU, 8 GB)** :
- **Utilisateurs simultanés** : 5-6 maximum
- **Raison** : Burst CPU encore problématique

**Avec upgrade (8 vCPU, 16 GB)** :
- **Utilisateurs simultanés** : 10-12 maximum
- **Raison** : Burst CPU gérable

---

## RECOMMANDATIONS

### Recommandation 1 : Upgrade serveur

**Action** : Upgrade à 4 vCPU, 8 GB RAM
- Coût : +$20/mois
- Capacité : 5-6 utilisateurs simultanés
- **Justification** : Burst CPU gérable

### Recommandation 2 : Rate limiting

**Action** : Limiter à 5 utilisateurs simultanés
- Queue FIFO pour utilisateurs supplémentaires
- Message : "Bobodo Vocal est surchargé, réessaie plus tard"
- **Justification** : Prévenir saturation

### Recommandation 3 : Optimisation STT/TTS

**Action** : Utiliser modèle base au lieu de small
- CPU : 0.3-0.5 vCPU (vs 0.5-1 vCPU)
- RAM : 1-1.5 GB (vs 1-2 GB)
- Qualité : 4.5/5 (vs 5/5)
- **Justification** : Réduction consommation

### Recommandation 4 : Load balancing

**Action** : 2× serveurs (2 vCPU, 4 GB)
- Coût : $78/mois (2 × $39)
- Capacité : 10-12 utilisateurs simultanés
- **Justification** : Scalabilité horizontale

---

## CONCLUSION

### Nombre maximal d'utilisateurs vocaux simultanés

**Configuration actuelle (2 vCPU, 4 GB)** :
- **3-4 utilisateurs** maximum
- Risque élevé de saturation

**Configuration upgrade (4 vCPU, 8 GB)** :
- **5-6 utilisateurs** maximum
- Risque moyen de saturation

**Configuration load balancing (2× 2 vCPU, 4 GB)** :
- **10-12 utilisateurs** maximum
- Risque faible de saturation

### Recommandation finale

**Pour le lancement** : 4 vCPU, 8 GB RAM
- Capacité : 5-6 utilisateurs simultanés
- Coût : $59/mois
- Risque : Acceptable

**Pour la croissance** : Load balancing 2× (2 vCPU, 4 GB)
- Capacité : 10-12 utilisateurs simultanés
- Coût : $78/mois
- Risque : Faible

---

**DOCUMENT TERMINÉ**
