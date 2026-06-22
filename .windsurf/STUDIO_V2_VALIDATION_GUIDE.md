# STUDIO_V2_PRODUCTION_VALIDATION - GUIDE

## PRÉREQUIS

1. **Variables d'environnement**
   ```bash
   export SUPABASE_URL="https://thevdfcwlcqzdoybfvgs.supabase.co"
   export SUPABASE_SERVICE_ROLE_KEY="votre_clé"
   ```

2. **Dépendances Python**
   ```bash
   pip install supabase
   ```

## PROCÉDURE

### ÉTAPE 1: Créer et uploader les vidéos depuis Flutter

**Vidéo 1 - 15 secondes**
1. Ouvrir l'app Flutter
2. Enregistrer une vidéo de 15 secondes
3. Cliquer "Publier"
4. Copier le `video_asset_id` depuis les logs Flutter (ou depuis la DB)
5. Noter l'heure de début d'upload

**Vidéo 2 - 30 secondes**
1. Répéter avec une vidéo de 30 secondes
2. Copier le `video_asset_id`
3. Noter l'heure de début d'upload

**Vidéo 3 - 60 secondes**
1. Répéter avec une vidéo de 60 secondes
2. Copier le `video_asset_id`
3. Noter l'heure de début d'upload

### ÉTAPE 2: Lancer la validation pour chaque vidéo

```bash
cd .windsurf
python studio_v2_validation.py <video_asset_id_15s>
python studio_v2_validation.py <video_asset_id_30s>
python studio_v2_validation.py <video_asset_id_60s>
```

### ÉTAPE 3: Capturer les logs Worker

Pendant l'upload et le traitement, capturer les logs du Worker Kamatera:

```bash
# Sur le serveur Kamatera
ssh user@kamatera-server
tail -f /path/to/videoasset_worker.log > worker_logs_<timestamp>.txt
```

Ou si le Worker utilise systemd journal:

```bash
journalctl -u videoasset-worker -f > worker_logs_<timestamp>.txt
```

### ÉTAPE 4: Vérifier le feed Flutter

Après que les vidéos sont prêtes (status='ready'), vérifier dans l'app Flutter:
1. Ouvrir le feed
2. Vérifier que les vidéos apparaissent
3. Cliquer sur une vidéo pour vérifier le playback
4. Vérifier dans les logs Flutter que l'URL utilisée est mp4_main

## PREUVES À FOURNIR

Pour chaque vidéo, fournir:

1. **Preuves SQL** - Sortie du script `studio_v2_validation.py`
2. **Preuves logs** - Logs Worker capturés
3. **Preuves Storage** - URLs publiques des renditions
4. **Preuves Flutter** - Logs Flutter montrant l'upload et le playback

## SCRIPT D'AIDE POUR EXTRAIRE LES PREUVES

```bash
# Extraire les video_asset_id récents
python -c "
from supabase import create_client
import os
from datetime import datetime, timedelta

client = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_ROLE_KEY'))
since = (datetime.now() - timedelta(hours=1)).isoformat()
result = client.table('video_assets').select('id, created_at, status').gte('created_at', since).order('created_at', desc=True).execute()
for asset in result.data:
    print(f\"{asset['created_at']} | {asset['id']} | {asset['status']}\")
"
```
