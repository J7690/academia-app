# BOBODO VOCAL - AUDIT RÉEL KAMATERA

**Date** : 10 juin 2026  
**Statut** : ⚠️ PARTIEL (accès SSH non disponible)

---

## OBJECTIF

Récupérer les caractéristiques exactes du serveur Kamatera pour valider la capacité à héberger le service vocal.

---

## TENTATIVE D'ACCÈS SSH

### Configuration testée

**IP** : 185.167.97.144 (LiveKit principal)  
**IP** : 185.220.204.214 (LiveKit serveur)  
**Utilisateur** : root  
**Mot de passe** : Ouedraogogilbert@Wendenkoote0

### Résultat

**Statut** : ❌ Échec authentication

**Erreur** : Authentication failed

**Conclusion** : Accès SSH non disponible avec les identifiants actuels

---

## DONNÉES DOCUMENTÉES

### Source : INFRASTRUCTURE_KAMATERA.md

**IP LiveKit** : 185.167.97.144

**Services** :
- WebSocket : ws://185.167.97.144:7880
- HTTP API : http://185.167.97.144:7880
- Redis : 127.0.0.1:6379 (local)
- Nginx : http://185.167.97.144

**Ports** :
- 22/TCP (SSH)
- 80/TCP
- 443/TCP+UDP
- 7880/TCP (API)
- 7881/TCP (WebRTC TCP)
- 50000-60000/UDP (WebRTC media)

**API Keys** :
- API Key : APIKeylrmgQYJgiEZa
- API Secret : uXu7tiObNgaLkYA3VydinjsKRzPJjL8SNWC9pRx8

**Installé le** : 2026-06-07

**Capacité estimée** :
- ~50 participants/room
- ~10 rooms
- Bande passante : 100 Mbps

---

### Source : livekit_credentials.json

**IP** : 185.220.204.214

**Specs estimées** :
- 2 vCPU
- 4 GB RAM
- 20 GB SSD
- Ubuntu 22.04

**Coût** : $39/mois

---

## DONNÉES NON DISPONIBLES

### Mesures en temps réel

| Paramètre | Valeur attendue | Valeur réelle | Statut |
|-----------|----------------|---------------|--------|
| vCPU | 2 vCPU | ❌ Non disponible | ? |
| RAM | 4 GB | ❌ Non disponible | ? |
| Disque | 20 GB SSD | ❌ Non disponible | ? |
| OS | Ubuntu 22.04 | ❌ Non disponible | ? |
| Charge CPU | Faible | ❌ Non disponible | ? |
| Charge RAM | Faible | ❌ Non disponible | ? |
| Espace disque utilisé | ? | ❌ Non disponible | ? |
| Conteneurs Docker | livekit-server, redis, nginx | ❌ Non disponible | ? |
| Ports ouverts | 22, 80, 443, 7880, 7881, 50000-60000 | ❌ Non disponible | ? |
| Certificats SSL | ? | ❌ Non disponible | ? |

---

## RESSOURCES POUR FASTER WHISPER MEDIUM

### Estimation basée sur l'offre Kamatera standard

**Configuration actuelle estimée** :
- vCPU : 2 vCPU
- RAM : 4 GB RAM
- Disque : 20 GB SSD

**Ressources requises pour Faster Whisper Medium** :
- CPU : 1-2 vCPU (burst)
- RAM : 1.5-2.0 GB (modèle chargé)
- Disque : 1.5 GB (modèle)

**Capacité estimée** :
- Sans optimisation : 2-3 utilisateurs simultanés
- Avec optimisation (modèle partagé) : 5-10 utilisateurs simultanés

---

## RESSOURCES POUR PIPER TTS

### Estimation basée sur l'offre Kamatera standard

**Ressources requises pour Piper Medium** :
- CPU : 0.5-1 vCPU (burst)
- RAM : 0.5-1 GB
- Disque : 500-800 MB

---

## RESSOURCES TOTALES REQUISES

### Service vocal complet (STT + TTS + WebSocket)

**CPU** : 1.5-3 vCPU (burst)

**RAM** : 2-3 GB

**Disque** : 2-3 GB

**Capacité estimée** :
- Configuration actuelle (2 vCPU, 4 GB) : 2-3 utilisateurs simultanés
- Configuration upgrade (4 vCPU, 8 GB) : 5-10 utilisateurs simultanés

---

## RECOMMANDATIONS

### Recommandation 1 : Obtenir accès SSH

**Action** :
- Vérifier les identifiants SSH actuels
- Ou configurer clé SSH
- Ou utiliser dashboard Kamatera

**Bénéfice** :
- Mesures en temps réel possibles
- Validation des hypothèses
- Audit complet

---

### Recommandation 2 : Upgrade serveur

**Action** :
- Upgrader à 4 vCPU, 8 GB RAM
- Coût : $59/mois

**Justification** :
- Capacité suffisante pour 5-10 utilisateurs simultanés
- Marge de sécurité
- Scalabilité future

---

### Recommandation 3 : Poursuivre avec hypothèses conservatrices

**Action** :
- Utiliser estimation Kamatera standard (2 vCPU, 4 GB RAM)
- Supposer charge faible (LiveKit récent)
- Planifier upgrade si nécessaire

**Justification** :
- Permet de progresser
- Risque maîtrisé
- Upgrade possible si nécessaire

---

## CONCLUSION

### Audit réel

**Statut** : ⚠️ **PARTIEL**

**Raisons** :
- Accès SSH non disponible
- Spécifications serveur basées sur estimation
- Mesures en temps réel impossibles

**Valeurs disponibles** :
- IP, ports, services : ✅ Documentés
- vCPU, RAM, disque : ⚠️ Estimés (2 vCPU, 4 GB, 20 GB)
- Charge actuelle : ❌ Non disponibles
- Conteneurs Docker : ⚠️ Estimés

---

### Impact sur le déploiement

**Risque** : Moyen

**Justification** :
- Les hypothèses sont basées sur l'offre Kamatera standard
- Le serveur LiveKit est récent (juin 2026)
- La charge est probablement faible
- L'upgrade est possible si nécessaire

**Mitigation** :
- Obtenir accès SSH avant déploiement
- Valider les hypothèses
- Planifier upgrade si nécessaire

---

**RAPPORT TERMINÉ (PARTIEL)**
