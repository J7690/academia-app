# BOBODO VOCAL - PHASE 1 : AUDIT INFRASTRUCTURE KAMATERA

**Date** : 10 juin 2026  
**Statut** : ✅ TERMINÉ (basé sur documentation existante)

---

## INFORMATIONS DISPONIBLES

Source : `academia_app/docs/INFRASTRUCTURE_KAMATERA.md`

### Serveur LiveKit Kamatera

| Paramètre | Valeur |
|-----------|--------|
| IP | 185.167.97.144 |
| WebSocket | ws://185.167.97.144:7880 |
| HTTP API | http://185.167.97.144:7880 |
| Redis | 127.0.0.1:6379 (local) |
| Nginx | http://185.167.97.144 |
| API Key | `APIKeylrmgQYJgiEZa` |
| Installé le | 2026-06-07 |

### Capacité estimée

- **LiveKit** : ~50 participants simultanés par room, ~10 rooms simultanées
- **Recording** : egress composites, stockage Supabase Storage
- **Bande passante** : 100 Mbps (Kamatera standard)

### Services déployés

- LiveKit Server :7880
- Redis :6379
- Nginx :80
- Egress (recording → S3)

---

## DONNÉES MANQUANTES

Les informations suivantes ne sont pas disponibles dans la documentation :

- **vCPU** : Non spécifié
- **RAM** : Non spécifiée
- **Stockage** : Non spécifié
- **Système d'exploitation** : Non spécifié
- **Charge actuelle** : Non spécifiée
- **Consommation moyenne** : Non spécifiée
- **Présence de Docker** : Non spécifiée

---

## RECOMMANDATIONS

Pour obtenir les informations manquantes :

1. **SSH direct** : `ssh root@185.167.97.144`
2. **Dashboard Kamatera** : Consulter le panel de gestion
3. **Commandes système** :
   - `lscpu` pour vCPU
   - `free -h` pour RAM
   - `df -h` pour stockage
   - `uname -a` pour OS
   - `docker ps` pour Docker
   - `htop` pour charge actuelle

---

## ANALYSE POUR BOBODO VOCAL

### Capacité actuelle

Le serveur LiveKit existant est dimensionné pour :
- **Live sessions** : ~50 participants/room, ~10 rooms
- **Bande passante** : 100 Mbps

### Impact du vocal Bobodo

Le vocal Bobodo nécessitera :
- **STT (Speech-to-Text)** : Traitement audio en temps réel
- **TTS (Text-to-Speech)** : Génération audio en temps réel
- **Latence** : < 500ms pour une expérience fluide

### Estimation de charge

Si Whisper/Faster-Whisper est déployé sur le même serveur :
- **CPU** : +2-4 vCPU requis (selon modèle)
- **RAM** : +4-8 GB requis (selon modèle)
- **Bande passante** : +10-20 Mbps (audio bidirectionnel)

### Recommandation architecture

**Option A** : Utiliser le serveur LiveKit existant
- ✅ Réduit les coûts
- ❌ Risque de surcharge
- ❌ Latence potentielle

**Option B** : Serveur dédié pour vocal
- ✅ Isolation des charges
- ✅ Meilleure performance
- ❌ Coût supplémentaire

---

## CONCLUSION

L'infrastructure Kamatera actuelle (LiveKit) est insuffisamment documentée pour évaluer sa capacité à supporter Bobodo Vocal.

**Action requise** : Obtenir les spécifications détaillées du serveur via SSH ou Dashboard Kamatera avant de continuer l'audit.

---

**RAPPORT PHASE 1 TERMINÉ**
