# PHASE C.3 – VALIDATION

**Version** : 1.0  
**Date** : 23 Juin 2026  
**Phase** : C.3 – Renderer Core Implementation  
**Mode** : VALIDATION  
**Objectif** : Valider le flux complet du Renderer V1

---

## CRITÈRE DE RÉUSSITE

Un Storyboard stocké dans Supabase produit réellement :
- Un MP4 valide
- Stocké dans whiteboard-renders
- Visible dans la table whiteboard_renders
- Avec statut done

---

## ÉTAPES DE VALIDATION

### Étape 1 : Insérer un Storyboard de test

**Action** : Insérer un job de test dans whiteboard_renders

**SQL** :
```sql
INSERT INTO app.whiteboard_renders (
    id,
    project_id,
    status,
    storyboard_json,
    created_at,
    updated_at
) VALUES (
    gen_random_uuid(),
    gen_random_uuid(),
    'queued',
    '{
        "id": "storyboard_001",
        "title": "La photosynthèse",
        "theme": {
            "name": "scientific",
            "background": "#0a192f",
            "text_color": "#ffffff",
            "accent_color": "#69f0ae"
        },
        "audio": {
            "type": "user_recording",
            "script": "La photosynthèse est le processus par lequel les plantes convertissent la lumière en énergie.",
            "timestamps": []
        },
        "metadata": {},
        "scenes": [
            {
                "id": "scene_001",
                "duration_ms": 5000,
                "blocks": [
                    {
                        "id": "block_001",
                        "type": "title",
                        "content": "La photosynthèse",
                        "animation": {
                            "type": "fade_in",
                            "duration": 0.5,
                            "delay": 0.0
                        },
                        "metadata": {},
                        "highlight": false,
                        "zoom": false,
                        "handwriting": false
                    },
                    {
                        "id": "block_002",
                        "type": "paragraph",
                        "content": "La photosynthèse est le processus par lequel les plantes convertissent la lumière en énergie.",
                        "animation": {
                            "type": "fade_in",
                            "duration": 0.5,
                            "delay": 0.5
                        },
                        "metadata": {},
                        "highlight": false,
                        "zoom": false,
                        "handwriting": false
                    }
                ]
            }
        ]
    }'::jsonb,
    NOW(),
    NOW()
);
```

**Vérification** :
```sql
SELECT id, status, created_at FROM app.whiteboard_renders ORDER BY created_at DESC LIMIT 1;
```

### Étape 2 : Démarrer le Worker

**Action** : Démarrer whiteboard_render_worker.py

**Commande** :
```bash
cd academia_bobodo_backend
python whiteboard_render_worker.py
```

**Configuration** :
- WORKER_LOOP=1
- WORKER_INTERVAL_SECONDS=2
- WORKER_MAX_JOBS=1

### Étape 3 : Observer le traitement

**Action** : Observer les logs du Worker

**Logs attendus** :
```
[whiteboard_render_worker] Found 1 queued job(s)
[whiteboard_render_worker] Processing job {job_id}
[whiteboard_render_worker] Generating PNGs for job {job_id}
[whiteboard_render_worker] Assembling MP4 for job {job_id}
[whiteboard_render_worker] Uploading MP4 for job {job_id}
[whiteboard_render_worker] Job {job_id} completed successfully
```

### Étape 4 : Vérifier le statut du job

**Action** : Vérifier que le job est passé à done

**SQL** :
```sql
SELECT id, status, video_url, duration_ms, error_message, started_at, completed_at 
FROM app.whiteboard_renders 
ORDER BY created_at DESC 
LIMIT 1;
```

**Résultat attendu** :
- status = done
- video_url = URL publique du MP4
- duration_ms = 5000 (1 scène × 5 secondes)
- error_message = NULL
- started_at = timestamp
- completed_at = timestamp

### Étape 5 : Vérifier le MP4 dans Storage

**Action** : Vérifier que le MP4 existe dans whiteboard-renders

**URL** : {video_url} depuis la table

**Vérification** :
- Le MP4 doit être téléchargeable
- Le MP4 doit être lisible
- Le MP4 doit avoir une durée d'environ 5 secondes

### Étape 6 : Vérifier le contenu du MP4

**Action** : Ouvrir le MP4 et vérifier le contenu

**Attendu** :
- Format vertical (1080x1920)
- Fond bleu nuit (thème scientific)
- Titre "La photosynthèse" (centré, blanc)
- Paragraphe (blanc, justifié)
- Animation fade_in

---

## VALIDATION AUTOMATISÉE

### Script de validation

**Fichier** : `.windsurf/phase_c3_validate.py`

**Fonctionnalités** :
- Insérer un Storyboard de test
- Attendre le traitement du Worker
- Vérifier le statut du job
- Vérifier le MP4 dans Storage
- Rapport de validation

---

## RAPPORT DE VALIDATION

### Succès

**Critères** :
- ✅ Storyboard inséré
- ✅ Worker détecte le job
- ✅ PNGs générés
- ✅ MP4 assemblé
- ✅ MP4 uploadé
- ✅ Statut = done
- ✅ video_url renseigné
- ✅ MP4 téléchargeable
- ✅ MP4 lisible
- ✅ Contenu correct

### Échec

**Critères** :
- ❌ Worker ne détecte pas le job
- ❌ Erreur lors de la génération PNGs
- ❌ Erreur lors de l'assemblage MP4
- ❌ Erreur lors de l'upload
- ❌ Statut = failed
- ❌ video_url vide
- ❌ MP4 non téléchargeable
- ❌ MP4 illisible
- ❌ Contenu incorrect

---

## PROBLÈMES COURANTS

### Problème 1 : Worker ne détecte pas le job

**Cause** : status != queued

**Solution** : Vérifier que le status est bien 'queued'

### Problème 2 : Erreur Pillow

**Cause** : Pillow non installé

**Solution** : `pip install Pillow`

### Problème 3 : Erreur FFmpeg

**Cause** : FFmpeg non installé

**Solution** : Installer FFmpeg sur Kamatera

### Problème 4 : Erreur Upload

**Cause** : Bucket whiteboard-renders inexistant

**Solution** : Créer le bucket

### Problème 5 : MP4 illisible

**Cause** : FFmpeg encoding error

**Solution** : Vérifier la commande FFmpeg

---

## CONCLUSION

**Validation réussie** : Le Renderer V1 fonctionne correctement

**Validation échouée** : Corriger les problèmes et réessayer

---

**Fin du document**
