# BOBODO VOCAL - PHASE 7 : CAPACITÉ ET SCALABILITÉ

**Date** : 10 juin 2026  
**Statut** : ✅ TERMINÉ

---

## RESSOURCES SERVEUR RECOMMANDÉES

### Configuration Kamatera (Service Vocal dédié)

**Spécifications minimales** :
- vCPU : 2 vCPU
- RAM : 4 GB
- Stockage : 20 GB SSD
- Bande passante : 100 Mbps
- OS : Ubuntu 22.04 LTS

**Coût estimé** : $39/mois (Kamatera)

---

## CONSOMMATION PAR UTILISATEUR

### STT (Faster-Whisper - modèle small)

- CPU : 0.5-1 vCPU (pendant transcription)
- RAM : 1-2 GB (modèle chargé)
- Durée : 1-2s par message
- Type : Burst (intermittent)

### TTS (Piper - modèle medium)

- CPU : 0.5-1 vCPU (pendant synthèse)
- RAM : 0.5-1 GB (modèle chargé)
- Durée : 1-2s par réponse
- Type : Burst (intermittent)

### WebSocket (connexion)

- CPU : 0.1 vCPU (maintenance connexion)
- RAM : 50 MB (par connexion)
- Durée : continue (pendant conversation)
- Type : Sustained

---

## CAPACITÉ ESTIMÉE

### Scénario 1 : Utilisation légère

**Hypothèses** :
- 10 utilisateurs simultanés
- 1 message/min par utilisateur
- Durée moyenne conversation : 5 min

**Charge CPU** :
- STT : 10 × 0.5 vCPU × (2s/60s) = 0.17 vCPU moyen
- TTS : 10 × 0.5 vCPU × (2s/60s) = 0.17 vCPU moyen
- WebSocket : 10 × 0.1 vCPU = 1 vCPU moyen
- **Total** : ~1.34 vCPU moyen

**Charge RAM** :
- STT : 2 GB (modèle partagé)
- TTS : 1 GB (modèle partagé)
- WebSocket : 10 × 50 MB = 500 MB
- **Total** : ~3.5 GB

**Conclusion** : ✅ 2 vCPU, 4 GB RAM suffisant

---

### Scénario 2 : Utilisation modérée

**Hypothèses** :
- 25 utilisateurs simultanés
- 2 messages/min par utilisateur
- Durée moyenne conversation : 10 min

**Charge CPU** :
- STT : 25 × 0.5 vCPU × (4s/60s) = 0.83 vCPU moyen
- TTS : 25 × 0.5 vCPU × (4s/60s) = 0.83 vCPU moyen
- WebSocket : 25 × 0.1 vCPU = 2.5 vCPU moyen
- **Total** : ~4.16 vCPU moyen

**Charge RAM** :
- STT : 2 GB (modèle partagé)
- TTS : 1 GB (modèle partagé)
- WebSocket : 25 × 50 MB = 1.25 GB
- **Total** : ~4.25 GB

**Conclusion** : ⚠️ 2 vCPU insuffisant, 4 GB RAM limite

**Recommandation** : Upgrade à 4 vCPU, 8 GB RAM (~$59/mois)

---

### Scénario 3 : Utilisation intensive

**Hypothèses** :
- 50 utilisateurs simultanés
- 3 messages/min par utilisateur
- Durée moyenne conversation : 15 min

**Charge CPU** :
- STT : 50 × 0.5 vCPU × (6s/60s) = 2.5 vCPU moyen
- TTS : 50 × 0.5 vCPU × (6s/60s) = 2.5 vCPU moyen
- WebSocket : 50 × 0.1 vCPU = 5 vCPU moyen
- **Total** : ~10 vCPU moyen

**Charge RAM** :
- STT : 2 GB (modèle partagé)
- TTS : 1 GB (modèle partagé)
- WebSocket : 50 × 50 MB = 2.5 GB
- **Total** : ~5.5 GB

**Conclusion** : ❌ 2 vCPU, 4 GB RAM insuffisant

**Recommandation** : Upgrade à 8 vCPU, 16 GB RAM (~$99/mois)

---

## LIMITES ET GOUVERNANCE D'ÉCHELLE

### Limite 1 : CPU

**Seuil alerte** : 80% utilisation CPU
- Action : Monitoring + logs
- Seuil critique : 90%
- Action : Throttling nouvelles connexions

**Seuil critique** : 95% utilisation CPU
- Action : Rejet nouvelles connexions
- Message : "Bobodo Vocal est surchargé, réessaie plus tard"

### Limite 2 : RAM

**Seuil alerte** : 80% utilisation RAM
- Action : Monitoring + logs
- Seuil critique : 90%
- Action : Fermeture connexions inactives

**Seuil critique** : 95% utilisation RAM
- Action : Rejet nouvelles connexions
- Message : "Bobodo Vocal est surchargé, réessaie plus tard"

### Limite 3 : Connexions simultanées

**Limite maximale** : 50 connexions (configuration 2 vCPU, 4 GB RAM)
- Raison : Charge WebSocket + STT/TTS
- Action : Queue FIFO
- Timeout : 30s

**Upgrade** :
- 4 vCPU, 8 GB RAM : 100 connexions
- 8 vCPU, 16 GB RAM : 200 connexions

### Limite 4 : Bande passante

**Consommation par utilisateur** :
- Upload audio : 16 kbps (WAV 16kHz mono)
- Download audio : 64 kbps (MP3 128kbps)
- **Total** : 80 kbps par utilisateur

**Capacité 100 Mbps** :
- 100 Mbps / 80 kbps = 1250 utilisateurs théoriques
- **Limite pratique** : 100 utilisateurs (CPU/RAM limitant)

---

## SCALABILITÉ

### Horizontal Scaling (Load Balancing)

**Architecture** :
```
Load Balancer (Nginx)
  ├─ Serveur Vocal 1 (2 vCPU, 4 GB)
  ├─ Serveur Vocal 2 (2 vCPU, 4 GB)
  └─ Serveur Vocal 3 (2 vCPU, 4 GB)
```

**Avantages** :
- ✅ Scalabilité linéaire
- ✅ Redondance (failover)
- ✅ Maintenance sans interruption

**Inconvénients** :
- ❌ Coût multiplié
- ❌ Complexité déploiement
- ❌ Gestion état partagé

**Coût** : 3 × $39 = $117/mois

---

### Vertical Scaling (Upgrade)

**Upgrade progressif** :
- 2 vCPU, 4 GB → 4 vCPU, 8 GB : +$20/mois
- 4 vCPU, 8 GB → 8 vCPU, 16 GB : +$40/mois
- 8 vCPU, 16 GB → 16 vCPU, 32 GB : +$80/mois

**Avantages** :
- ✅ Simple (un serveur)
- ✅ Pas de complexité load balancing
- ✅ Coût progressif

**Inconvénients** :
- ❌ Limite maximale (16 vCPU)
- ❌ Single point of failure
- ❌ Maintenance interruption

---

### Auto-scaling (Kamatera)

**Configuration** :
- Seuil CPU > 80% : +1 serveur
- Seuil CPU < 30% : -1 serveur
- Délai : 5 min

**Avantages** :
- ✅ Adaptation automatique
- ✅ Coût optimisé
- ✅ Pas de surdimensionnement

**Inconvénients** :
- ❌ Complexité configuration
- ❌ Délai scaling (5 min)
- ❌ Coût fluctuant

---

## RECOMMANDATION SCALABILITÉ

### Phase 1 : Lancement (0-3 mois)

**Configuration** : 2 vCPU, 4 GB RAM
- Capacité : 10-15 utilisateurs simultanés
- Coût : $39/mois
- Monitoring : CPU, RAM, connexions

### Phase 2 : Croissance (3-6 mois)

**Si utilisation > 80%** :
- Upgrade à 4 vCPU, 8 GB RAM
- Capacité : 25-30 utilisateurs simultanés
- Coût : $59/mois

### Phase 3 : Expansion (6-12 mois)

**Si utilisation > 80%** :
- Option A : Upgrade à 8 vCPU, 16 GB RAM ($99/mois)
- Option B : Load balancing 2× (2 vCPU, 4 GB) ($78/mois)

**Recommandation** : Option B (load balancing)
- Redondance
- Flexibilité
- Coût similaire

---

## MONITORING

### Métriques à surveiller

**CPU** :
- Utilisation moyenne (%)
- Utilisation pic (%)
- Load average

**RAM** :
- Utilisation (%)
- Disponible (GB)
- Swap utilisé

**Connexions** :
- Nombre actif
- Nombre total
- Durée moyenne

**Latence** :
- STT (ms)
- LLM (ms)
- TTS (ms)
- Total (ms)

**Erreurs** :
- STT échoué (%)
- LLM échoué (%)
- TTS échoué (%)
- WebSocket déconnecté (%)

### Outils

**Prometheus + Grafana** :
- Métriques temps réel
- Alertes automatiques
- Dashboards personnalisés

**Logs** :
- Journalisation structurée
- Rotation automatique
- Exportation cloud (optionnel)

---

**RAPPORT PHASE 7 TERMINÉ**
