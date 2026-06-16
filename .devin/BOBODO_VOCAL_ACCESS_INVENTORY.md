# BOBODO VOCAL - INVENTAIRE DES ACCÈS KAMATERA

**Date** : 10 juin 2026  
**Mission** : Recherche des accès existants

---

## 1. ACCÈS SSH

### Identifiants trouvés

**Source** : `.windsurf/install_livekit_remote.py` (lignes 14-16)

```python
SERVER_IP = "185.220.204.214"
SERVER_USER = "root"
SERVER_PASS = "Ouedraogogilbert@Wendenkoote0"
```

**Statut** : ❌ Authentication failed lors des tests

**Note** : Ces identifiants sont utilisés pour l'installation LiveKit mais ne fonctionnent pas actuellement

---

## 2. ACCÈS API KAMATERA

### Identifiants trouvés

**Source** : `.windsurf/kamatera_get_server.py` (lignes 8-10)

```python
API_URL = "https://console.kamatera.com/service"
CLIENT_ID = "54ae6bec54550d349e6181c51e2b925c"
SECRET = "cdf8f98e556dfe28243aa243104801a7"
HEADERS = {"AuthClientId": CLIENT_ID, "AuthSecret": SECRET}
```

**Statut** : ✅ Disponible (non testé récemment)

**Note** : Ces identifiants permettent d'accéder à l'API Kamatera pour gérer les serveurs

---

## 3. INFORMATIONS SERVEUR LIVEKIT

### Serveur principal

**Source** : `.windsurf/livekit_credentials.json`

```json
{
  "server_ip": "185.167.97.144",
  "server_id": "f6d2656b-0f80-4df1-ac62-53b26d6d921b",
  "server_name": "academia-livekit-new",
  "livekit_api_key": "APIKeylrmgQYJgiEZa",
  "livekit_api_secret": "uXu7tiObNgaLkYA3VydinjsKRzPJjL8SNWC9pRx8",
  "livekit_url": "ws://185.167.97.144:7880",
  "livekit_ws_url": "ws://185.167.97.144:7880",
  "livekit_http": "http://185.167.97.144:7880",
  "redis": "127.0.0.1:6379 (local only)",
  "nginx": "http://185.167.97.144",
  "installed_at": "2026-06-07T11:55:38"
}
```

**Statut** : ✅ Disponible

---

### Serveur secondaire

**Source** : Mémoire système

- **IP** : 185.220.204.214
- **Specs** : 2 vCPU, 4GB RAM, 20GB SSD, Ubuntu 22.04
- **SSH** : root / Ouedraogogilbert@Wendenkoote0

**Statut** : ❌ Authentication failed

---

## 4. ACCÈS LIVEKIT

### API Keys

**Source** : `.windsurf/livekit_credentials.json`

- **API Key** : APIKeylrmgQYJgiEZa
- **API Secret** : uXu7tiObNgaLkYA3VydinjsKRzPJjL8SNWC9pRx8

**Endpoints** :
- WebSocket : ws://185.167.97.144:7880
- HTTP API : http://185.167.97.144:7880

**Statut** : ✅ Disponible

---

## 5. ACCÈS SUPABASE

### Secrets requis

**Source** : `academia_app/docs/INFRASTRUCTURE_KAMATERA.md`

```bash
LIVEKIT_API_KEY=APIKeylrmgQYJgiEZa
LIVEKIT_API_SECRET=uXu7tiObNgaLkYA3VydinjsKRzPJjL8SNWC9pRx8
LIVEKIT_URL=ws://185.167.97.144:7880
OPENROUTER_API_KEY=<your_key>
```

**Statut** : ⚠️ OPENROUTER_API_KEY non disponible dans le fichier

---

## 6. CLÉS SSH

### Recherche

**Résultat** : ❌ Aucune clé SSH trouvée dans `.windsurf/`

**Note** : Seul l'accès par mot de passe est documenté

---

## 7. ACCÈS DASHBOARD KAMATERA

### Recherche

**Résultat** : ❌ Aucun accès dashboard documenté

**Note** : L'accès API est disponible mais pas l'accès web

---

## 8. RÉSUMÉ DES ACCÈS DISPONIBLES

| Type | Identifiants | Statut | Utilisation |
|------|-------------|--------|-------------|
| SSH (185.220.204.214) | root / Ouedraogogilbert@Wendenkoote0 | ❌ Échec | Installation LiveKit |
| SSH (185.167.97.144) | Non documenté | ❌ Non disponible | - |
| API Kamatera | CLIENT_ID / SECRET | ✅ Disponible | Gestion serveurs |
| LiveKit API | APIKey / Secret | ✅ Disponible | LiveKit operations |
| Dashboard Kamatera | Non documenté | ❌ Non disponible | - |
| Clé SSH | Non trouvée | ❌ Non disponible | - |

---

## 9. RECOMMANDATIONS

### Option 1 : Réinitialiser mot de passe SSH

**Action** :
- Utiliser l'API Kamatera pour réinitialiser le mot de passe root
- Tester la connexion SSH

**Avantages** : Permet d'accéder au serveur pour déploiement

---

### Option 2 : Utiliser API Kamatera

**Action** :
- Utiliser CLIENT_ID / SECRET pour créer un nouveau serveur
- Déployer le service vocal sur le nouveau serveur

**Avantages** : Évite les problèmes d'accès SSH

---

### Option 3 : Contacter support Kamatera

**Action** :
- Demander assistance pour réinitialiser l'accès SSH
- Obtenir de nouveaux identifiants

**Avantages** : Support officiel

---

## 10. PROCHAINE ÉTAPE

**Action requise** : Choisir l'option pour obtenir l'accès serveur

**Raison** : Sans accès serveur, impossible de déployer le service vocal

---

**RAPPORT TERMINÉ**
