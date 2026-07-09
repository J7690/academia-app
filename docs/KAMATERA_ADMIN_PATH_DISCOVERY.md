# KAMATERA ADMIN PATH DISCOVERY

**Version** : 1.0  
**Date** : 23 Juin 2026  
**Phase** : C.3B.1 – Kamatera Access Path Audit  
**Mode** : AUDIT

---

## OBJECTIF

Identifier le chemin officiel utilisé par Academia pour administrer Kamatera.

---

## ÉTAPE 1 – EXPLORATION .WINDSURF

### Scripts SSH/Paramiko identifiés

**87 scripts** utilisent paramiko/SSH :

- `deploy_kamatera.py` – Déploiement Bobodo Voice
- `check_kamatera.py` – Vérification services Kamatera
- `check_kamatera_services.py` – Vérification services détaillée
- `phase_c3b_kamatera_audit.py` – Audit Kamatera pour Renderer
- `phase_c3b_install_and_deploy.py` – Installation dépendances + déploiement
- `phase_c3b1_redeploy_worker.py` – Redéploiement worker
- `phase_c3b1_worker_startup_check.py` – Vérification démarrage worker
- `deploy_compress_service.py` – Déploiement service compression
- `deploy_systemd.py` – Création services systemd
- `deploy_monitoring.py` – Déploiement monitoring
- Et 78 autres scripts similaires

### Scripts admin_execute_sql identifiés

**105 scripts** utilisent la RPC `admin_execute_sql` pour les opérations Supabase :

- `diagnostic_admin_execute_sql.py` – Diagnostic RPC
- `phase_c3_check_infrastructure.py` – Vérification infrastructure
- `phase_c3a_insert_storyboard.py` – Insertion storyboard
- `phase_c3a_monitor.py` – Surveillance traitement
- `phase_b5_create_rpcs.py` – Création RPCs
- `phase_b5_create_tables.py` – Création tables
- Et 99 autres scripts similaires

---

## ÉTAPE 2 – SCRIPTS D'ADMINISTRATION KAMATERA

### Scripts qui interrogent Supabase

**Via admin_execute_sql RPC** :
- Tous les scripts de création/modification de tables
- Tous les scripts de création/modification de RPCs
- Tous les scripts de validation de données

**Via API REST directe** :
- Scripts de test de RPCs
- Scripts de validation de flux

### Scripts qui exécutent des commandes serveur

**Via paramiko SSH** :
- `deploy_kamatera.py` – Exécute apt, pip, systemctl
- `check_kamatera.py` – Exécute systemctl, netstat, df, free
- `phase_c3b_kamatera_audit.py` – Exécute python3, pip3, which
- `phase_c3b_install_and_deploy.py` – Exécute pip3, mkdir
- `deploy_systemd.py` – Exécute systemctl daemon-reload

### Scripts qui déploient des services

**Via paramiko SSH + SFTP** :
- `deploy_kamatera.py` – Upload fichiers, création service systemd
- `deploy_compress_service.py` – Upload service compression
- `deploy_systemd.py` – Création services systemd
- `phase_c3b_install_and_deploy.py` – Upload fichiers whiteboard_*.py

### Scripts qui exécutent Docker

**Via paramiko SSH** :
- `check_kamatera.py` – Exécute docker ps, docker --version
- `phase_c0_kamatera_capacity.py` – Exécute docker ps

### Scripts qui exécutent FFmpeg

**Via paramiko SSH** :
- `check_kamatera.py` – Exécute ffmpeg -version
- `phase_c3b_kamatera_audit.py` – Exécute which ffmpeg

---

## ÉTAPE 3 – SECRETS KAMATERA

### Emplacement des secrets

**Stockés en dur dans les scripts .windsurf** :

```python
# Dans deploy_kamatera.py et autres scripts
KAMATERA_IP = "185.167.97.144"
KAMATERA_USER = "root"
KAMATERA_PASSWORD = "Nexiomgroup@Academia0"
ACCESS_KEY = "a91330958142da0f32fdc6b9f7e16476"
SECRET_KEY = "354e008099f0dbb3e667f550965d8e95"
SERVER_ID = "f6d2656b-0f80-4df1-ac62-53b26d6d921b"
```

### Secrets Supabase

**Stockés en dur dans les scripts .windsurf** :

```python
# Dans phase_c3a_insert_storyboard.py et autres scripts
SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SUPABASE_SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

### Edge Functions Supabase

**Aucun secret Kamatera stocké dans les Edge Functions**  
Les Edge Functions utilisent uniquement des secrets Supabase (OPENROUTER_API_KEY, etc.)

### Vault Supabase

**Non utilisé pour Kamatera**  
Aucune référence à Vault dans les scripts .windsurf

### Tables d'administration

**Aucune table de secrets Kamatera**  
Les tables app.* contiennent uniquement des données applicatives

---

## ÉTAPE 4 – CARTOGRAPHIE COMPLÈTE

```
Flutter
↓
Supabase (REST API + RPCs)
↓
Scripts .windsurf (admin_execute_sql)
↓
Supabase Database (tables, RPCs)
↓
Scripts .windsurf (paramiko SSH)
↓
Kamatera (SSH direct)
```

**Note** : Il n'y a PAS de lien direct Supabase → Kamatera. L'administration Kamatera se fait uniquement via SSH direct depuis les scripts .windsurf.

---

## ÉTAPE 5 – MÉCANISME D'ADMINISTRATION KAMATERA

### Le projet dispose-t-il d'un mécanisme Supabase → Kamatera ?

**Réponse : NON**

**Preuves** :
1. Aucune Edge Function n'exécute de commandes SSH
2. Aucune RPC n'exécute de commandes SSH
3. Aucune table ne stocke des secrets Kamatera
4. Aucun mécanisme de webhook Supabase → Kamatera

### Mécanisme actuel

**SSH direct via paramiko depuis scripts .windsurf**

**Scripts principaux** :
- `deploy_kamatera.py` – Déploiement complet
- `check_kamatera.py` – Vérification services
- `phase_c3b_install_and_deploy.py` – Installation + déploiement

**Limitations** :
- Credentials hardcodés dans les scripts
- Aucune intégration avec Supabase
- Aucune orchestration via Edge Functions
- Aucune gestion centralisée des secrets

---

## ÉTAPE 6 – MÉCANISME POUR EXÉCUTER LE RENDERER WHITEBOARD

### Options disponibles

**Option 1 : SSH direct via paramiko (mécanisme actuel)**

- Démarrer worker : `ssh root@185.167.97.144 "cd /opt/whiteboard-worker && python3 whiteboard_render_worker.py &"`
- Arrêter worker : `ssh root@185.167.97.144 "pkill -f whiteboard_render_worker"`
- Déployer fichier : `sftp.put(local_file, remote_file)`
- Exécuter commande Python : `ssh root@185.167.97.144 "python3 script.py"`
- Exécuter FFmpeg : `ssh root@185.167.97.144 "ffmpeg ..."`

**Option 2 : Service systemd (recommandé pour production)**

- Créer service systemd `/etc/systemd/system/whiteboard-worker.service`
- Démarrer : `systemctl start whiteboard-worker`
- Arrêter : `systemctl stop whiteboard-worker`
- Redémarrer : `systemctl restart whiteboard-worker`
- Logs : `journalctl -u whiteboard-worker -f`

**Option 3 : Docker (non utilisé actuellement)**

- Créer conteneur Docker pour le worker
- Gestion via docker-compose
- Isolation des dépendances

### Mécanisme recommandé pour Renderer Whiteboard

**SSH direct via paramiko + Service systemd**

**Raisons** :
1. Déjà utilisé par le projet (pattern existant)
2. Simple à implémenter
3. Permet la surveillance des logs
4. Permet le redémarrage automatique

**Étapes** :
1. Déployer les fichiers via SFTP (déjà fait)
2. Créer service systemd (à faire)
3. Démarrer le service via SSH (à faire)
4. Surveiller via RPC Supabase (déjà possible)

---

## CONCLUSION

### Où se trouvent les secrets Kamatera ?

**En dur dans les scripts .windsurf** (IP, user, password, access key, secret key, server ID)

### Comment Academia les utilise ?

**Via paramiko SSH direct depuis les scripts .windsurf**

### Quels scripts .windsurf permettent déjà d'administrer Kamatera ?

**87 scripts utilisent paramiko SSH**, notamment :
- `deploy_kamatera.py`
- `check_kamatera.py`
- `phase_c3b_install_and_deploy.py`

### Quel mécanisme doit être utilisé pour exécuter le Renderer Whiteboard ?

**SSH direct via paramiko + Service systemd**

**Justification** :
- Pattern existant dans le projet
- Aucun mécanisme Supabase → Kamatera disponible
- Service systemd pour la robustesse en production

---

**Fin du document**
