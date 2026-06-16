# BOBODO VOCAL - ESTIMATION COÛTS

**Date** : 10 juin 2026  
**Version** : 1.0  
**Statut** : ✅ FINAL

---

## RÉSUMÉ EXÉCUTIF

**Coût total mensuel estimé** : $39 - $117/mois (selon scalabilité)

**Coût initial (setup)** : $0 (développement interne)

**Coût annuel estimé** : $468 - $1,404/an

---

## COÛTS D'INFRASTRUCTURE

### Kamatera (Service Vocal dédié)

**Phase 1 : Lancement (0-3 mois)**
- Configuration : 2 vCPU, 4 GB RAM, 20 GB SSD
- Coût : $39/mois
- Capacité : 10-15 utilisateurs simultanés

**Phase 2 : Croissance (3-6 mois)**
- Configuration : 4 vCPU, 8 GB RAM, 20 GB SSD
- Coût : $59/mois
- Capacité : 25-30 utilisateurs simultanés

**Phase 3 : Expansion (6-12 mois)**
- Option A : 8 vCPU, 16 GB RAM, 20 GB SSD
  - Coût : $99/mois
  - Capacité : 50+ utilisateurs simultanés
- Option B : Load balancing 2× (2 vCPU, 4 GB)
  - Coût : $78/mois (2 × $39)
  - Capacité : 20-30 utilisateurs simultanés

**Recommandation** : Option B (load balancing)
- Redondance
- Flexibilité
- Coût similaire

---

### LiveKit (existant)

**Coût** : $0 (déjà déployé)
- Utilisé pour Live Sessions uniquement
- Pas d'impact sur Bobodo Vocal

---

### Supabase (existant)

**Coût** : $0 (plan Pro déjà utilisé)
- Edge Function bobodo-chat : réutilisation existante
- Base de données : réutilisation existante
- Storage : réutilisation existante

**Aucun coût supplémentaire** pour Bobodo Vocal

---

## COÛTS DE DÉVELOPPEMENT

### Développement interne

**Temps estimé** : 2-3 semaines
- Phase 1 : Préparation serveur (2 jours)
- Phase 2 : Développement service (5 jours)
- Phase 3 : Développement Flutter (5 jours)
- Phase 4 : Tests (3 jours)
- Phase 5 : Déploiement (2 jours)
- Phase 6 : Lancement (1 jour)

**Coût** : $0 (développement interne)

---

### Outils et logiciels

**Open-source (gratuit)** :
- Faster-Whisper : Gratuit
- Piper : Gratuit
- FastAPI : Gratuit
- Uvicorn : Gratuit
- Python : Gratuit

**Coût** : $0

---

## COÛTS OPÉRATIONNELS

### Maintenance

**Mise à jour système** : 0.5h/mois
- Mise à jour OS : 0.25h
- Mise à jour packages : 0.25h

**Mise à jour modèles** : 1h/trimestre
- Faster-Whisper : 0.5h
- Piper : 0.5h

**Monitoring** : 1h/semaine
- Vérification logs : 0.5h
- Analyse métriques : 0.5h

**Coût** : $0 (maintenance interne)

---

### Support

**Incidents** : Variable
- Temps de résolution estimé : 2-4h/incident
- Fréquence estimée : 1-2 incidents/mois

**Coût** : $0 (support interne)

---

## COÛTS DE SCALABILITÉ

### Vertical Scaling

| Configuration | Coût mensuel | Capacité |
|--------------|---------------|----------|
| 2 vCPU, 4 GB | $39 | 10-15 utilisateurs |
| 4 vCPU, 8 GB | $59 | 25-30 utilisateurs |
| 8 vCPU, 16 GB | $99 | 50+ utilisateurs |

### Horizontal Scaling

| Configuration | Coût mensuel | Capacité |
|--------------|---------------|----------|
| 1× serveur (2 vCPU, 4 GB) | $39 | 10-15 utilisateurs |
| 2× serveurs (2 vCPU, 4 GB) | $78 | 20-30 utilisateurs |
| 3× serveurs (2 vCPU, 4 GB) | $117 | 30-45 utilisateurs |

---

## COÛTS D'ALTERNATIVES

### Option A : LiveKit (réutilisation)

**Coût** : $0
- Avantage : Pas de nouveau serveur
- Inconvénient : Surcharge LiveKit existant
- Risque : Élevé

**Non recommandé**

---

### Option B : STT/TTS Cloud (Google, Amazon, ElevenLabs)

**Google Cloud TTS (Standard)** :
- Coût : $4/1M caractères
- Estimation : 100k caractères/jour = $12/mois
- STT : Google Speech-to-Text ($0.006/15s)
- Estimation : 1000 requêtes/jour = $18/mois
- **Total** : ~$30/mois

**Amazon Polly (Standard)** :
- Coût : $4/1M caractères
- Estimation : 100k caractères/jour = $12/mois
- STT : Amazon Transcribe ($0.004/15s)
- Estimation : 1000 requêtes/jour = $12/mois
- **Total** : ~$24/mois

**ElevenLabs** :
- Coût : $22/mois (Creator plan)
- 100k caractères/mois
- **Total** : $22/mois

**Inconvénients** :
- Dépendance internet
- Confidentialité (données envoyées à tiers)
- Coût récurrent élevé

**Non recommandé**

---

## COÛTS TOTAUX

### Scénario 1 : Lancement (Phase 1)

**Infrastructure** : $39/mois
- Kamatera : $39/mois
- Supabase : $0
- LiveKit : $0

**Développement** : $0
- Interne

**Opérationnel** : $0
- Maintenance interne

**Total mensuel** : **$39/mois**

**Total annuel** : **$468/an**

---

### Scénario 2 : Croissance (Phase 2)

**Infrastructure** : $59/mois
- Kamatera (upgrade) : $59/mois
- Supabase : $0
- LiveKit : $0

**Développement** : $0
- Interne

**Opérationnel** : $0
- Maintenance interne

**Total mensuel** : **$59/mois**

**Total annuel** : **$708/an**

---

### Scénario 3 : Expansion (Phase 3 - Option A)

**Infrastructure** : $99/mois
- Kamatera (upgrade) : $99/mois
- Supabase : $0
- LiveKit : $0

**Développement** : $0
- Interne

**Opérationnel** : $0
- Maintenance interne

**Total mensuel** : **$99/mois**

**Total annuel** : **$1,188/an**

---

### Scénario 4 : Expansion (Phase 3 - Option B - Recommandé)

**Infrastructure** : $78/mois
- Kamatera (2× serveurs) : $78/mois
- Supabase : $0
- LiveKit : $0

**Développement** : $0
- Interne

**Opérationnel** : $0
- Maintenance interne

**Total mensuel** : **$78/mois**

**Total annuel** : **$936/an**

---

## COÛTS HIDDEN

### Bande passante

**Kamatera** : Inclus dans prix serveur
- 100 Mbps inclus
- Suffisant pour 50+ utilisateurs

### Stockage

**Kamatera** : Inclus dans prix serveur
- 20 GB SSD inclus
- Suffisant (audio non stocké)

### SSL/TLS

**Let's Encrypt** : Gratuit
- Certificat SSL gratuit
- Renouvellement automatique

---

## COÛTS D'OPPORTUNITÉ

### Temps de développement

**Interne** : 2-3 semaines
- Coût : $0 (salaire déjà payé)

**Externalisé** : $5,000 - $10,000
- Freelance : $5,000
- Agence : $10,000

**Recommandation** : Développement interne

---

### Temps de maintenance

**Interne** : 2-4h/semaine
- Coût : $0 (salaire déjà payé)

**Externalisé** : $500/mois
- DevOps : $500/mois

**Recommandation** : Maintenance interne

---

## ANALYSE ROI

### Investissement initial

**Coût** : $0 (développement interne)

### Coût mensuel

**Phase 1** : $39/mois
**Phase 2** : $59/mois
**Phase 3** : $78/mois (recommandé)

### Bénéfices attendus

- **Engagement utilisateur** : +20-30%
- **Rétention** : +15-20%
- **Satisfaction** : +25-35%
- **Différenciation** : Avantage concurrentiel

### ROI estimé

**Hypothèse** : 1,000 utilisateurs actifs
- Engagement +25% = +250 utilisateurs
- Valeur par utilisateur : $5/mois (estimation)
- Revenu additionnel : $1,250/mois
- Coût : $78/mois
- **ROI** : 1,500% ($1,172 profit/mois)

---

## RÉSUMÉ FINANCIER

### Coûts mensuels

| Phase | Infrastructure | Total |
|-------|---------------|-------|
| Phase 1 (lancement) | $39 | $39 |
| Phase 2 (croissance) | $59 | $59 |
| Phase 3 (expansion) | $78 | $78 |

### Coûts annuels

| Phase | Infrastructure | Total |
|-------|---------------|-------|
| Phase 1 (lancement) | $468 | $468 |
| Phase 2 (croissance) | $708 | $708 |
| Phase 3 (expansion) | $936 | $936 |

### Coûts totaux (12 mois)

**Scénario progressif** :
- Mois 1-3 : $39/mois = $117
- Mois 4-6 : $59/mois = $177
- Mois 7-12 : $78/mois = $468
- **Total** : **$762/an**

---

## RECOMMANDATION FINANCIÈRE

**Approche progressive** :
1. **Lancement** : $39/mois (2 vCPU, 4 GB)
2. **Croissance** : $59/mois (4 vCPU, 8 GB)
3. **Expansion** : $78/mois (2× serveurs load balancing)

**Justification** :
- Coût minimal au lancement
- Scalabilité progressive
- ROI élevé (1,500% estimé)
- Risque financier faible

---

## CONCLUSION

**Coût total** : $39 - $78/mois (selon phase)

**Investissement initial** : $0 (développement interne)

**ROI estimé** : 1,500% (basé sur engagement utilisateur)

**Recommandation** : ✅ Déploiement autorisé

**Justification** :
- Coût abordable
- ROI élevé
- Risque faible
- Avantage concurrentiel

---

**DOCUMENT TERMINÉ**
