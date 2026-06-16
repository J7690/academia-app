# BOBODO VOCAL - DÉCISION DE DÉPLOIEMENT

**Date** : 10 juin 2026  
**Source** : Données réelles Kamatera + SSH

---

## RÉPONSES AUX 5 QUESTIONS

### 1. Quel serveur héberge actuellement LiveKit ?

**Réponse** : Serveur **Academia00**

**Détails** :
- **ID** : f6d2656b-0f80-4df1-ac62-53b26d6d921b
- **Nom** : Academia00
- **IP** : 185.167.97.144
- **Datacenter** : EU (Amsterdam)
- **Statut** : ON (power: on)

**Preuve** : API Kamatera cloudcli - réponse 200 avec détails serveur

---

### 2. Ce serveur est-il accessible ?

**Réponse** : ✅ **OUI**

**Méthode d'accès** :
- **SSH** : ✅ Fonctionne
- **User** : root
- **Mot de passe** : Nexiomgroup@Academia0
- **Port** : 22

**Preuve** : Diagnostic SSH paramiko - connexion réussie, exécution commande réussie

---

### 3. Peut-il accueillir Bobodo Vocal ?

**Réponse** : ✅ **OUI**

**Ressources actuelles** :
- **CPU** : 4 vCPU (4B)
- **RAM** : 10 GB (10240 MB)
- **Disque** : 30 GB SSD
- **Utilisation actuelle** :
  - RAM : 871 MB used / 8.9 GB available
  - Disque : 5.2 GB used / 23 GB available (19%)

**Services actuels** :
- LiveKit Server (Docker container)

**Preuve** : SSH commands - free -h, df -h, docker ps

---

### 4. Les ressources actuelles sont-elles suffisantes ?

**Réponse** : ✅ **OUI**

**Ressources requises pour Bobodo Vocal** :
- **CPU** : 1-2 vCPU (burst)
- **RAM** : 2-3 GB (modèles chargés)
- **Disque** : 2-3 GB (modèles)

**Ressources disponibles** :
- **CPU** : 4 vCPU ✅ (suffisant)
- **RAM** : 8.9 GB disponible ✅ (suffisant)
- **Disque** : 23 GB disponible ✅ (suffisant)

**Capacité estimée** :
- Configuration actuelle : 5-10 utilisateurs simultanés
- Marge de sécurité : ✅ Importante

---

### 5. Quel est le plan exact de déploiement ?

**Réponse** : Déploiement sur le serveur **Academia00** (185.167.97.144)

**Plan détaillé** :

#### Étape 1 : Transfert des fichiers
```bash
scp -r .windsurf/bobodo-vocal/ root@185.167.97.144:/opt/bobodo-vocal/
```

#### Étape 2 : Installation des dépendances
```bash
ssh root@185.167.97.144
cd /opt/bobodo-vocal
bash deploy_kamatera.sh
```

#### Étape 3 : Téléchargement des modèles
- Faster Whisper Medium (~1.5 GB)
- Piper French (~500 MB)

#### Étape 4 : Lancement Docker
```bash
docker-compose up -d
```

#### Étape 5 : Health check
```bash
curl http://localhost:8000/health
```

#### Étape 6 : Configuration Nginx (optionnel)
- Reverse proxy pour le port 8000
- SSL (optionnel)

#### Étape 7 : Tests
- Test STT
- Test TTS
- Test dialogue complet

---

## CARTOGRAPHIE FINALE

```
┌─────────────────────────────────────────────────────────────┐
│ Kamatera VPS - Academia00 (185.167.97.144)                  │
│ ─────────────────────────────────────────────────────────   │
│ Specs: 4 vCPU, 10 GB RAM, 30 GB SSD                         │
│ ─────────────────────────────────────────────────────────   │
│ ✅ LiveKit Server (Docker)                                  │
│ ✅ Bobodo Vocal (Docker) - À déployer                       │
│ ─────────────────────────────────────────────────────────   │
│ Ports: 22 (SSH), 7880 (LiveKit), 8000 (Bobodo Vocal)       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ Supabase Cloud                                               │
│ ─────────────────────────────────────────────────────────   │
│ ✅ bobodo-chat Edge Function                                │
│ ✅ livekit-token Edge Function                              │
│ ✅ Secrets: LIVEKIT_*, OPENROUTER_*                          │
└─────────────────────────────────────────────────────────────┘
```

---

## RÉSUMÉ

### Serveur LiveKit
- **Nom** : Academia00
- **IP** : 185.167.97.144
- **ID** : f6d2656b-0f80-4df1-ac62-53b26d6d921b

### Accessibilité
- **SSH** : ✅ Fonctionne (root / Nexiomgroup@Academia0)
- **API** : ✅ Fonctionne (cloudcli)

### Ressources
- **CPU** : 4 vCPU ✅
- **RAM** : 10 GB (8.9 GB disponible) ✅
- **Disque** : 30 GB (23 GB disponible) ✅

### Plan de déploiement
- **Emplacement** : Serveur Academia00 (co-localisation avec LiveKit)
- **Méthode** : Docker
- **Accès** : SSH
- **Ressources** : Suffisantes

---

## DÉCISION FINALE

**GO pour déploiement** sur le serveur **Academia00** (185.167.97.144)

**Justification** :
- Serveur accessible via SSH
- Ressources suffisantes
- Co-localisation avec LiveKit
- Aucun nouveau serveur requis

---

**RAPPORT TERMINÉ - PRÊT POUR DÉPLOIEMENT**
