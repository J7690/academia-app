# PHASE C.3F – REAL PIPELINE VALIDATION

**Date** : 23 Juin 2026  
**Phase** : C.3F – Real Pipeline Validation  
**Mode** : VALIDATION RÉELLE  
**Objectif** : Valider que le pipeline Smart Whiteboard fonctionne réellement de bout en bout

---

## DIRECTIVE

**AUCUNE MODIFICATION**  
**AUCUNE CRÉATION DE RPCs V1**  
**AUCUNE MODIFICATION DU WORKER**

---

## ÉTAPE 1 – AUDIT WORKER

### Worker local

**Fichier** : `academia_bobodo_backend/whiteboard_render_worker.py`

**Version** : Phase C.3

**Dépendances** :
- `httpx` : Communication HTTP avec Supabase
- `python-dotenv` : Configuration environnement
- `whiteboard_png_renderer` : Génération PNG
- `whiteboard_ffmpeg_assembler` : Assemblage MP4
- `whiteboard_upload_renderer` : Upload Storage

**RPCs utilisées** :
- `public.whiteboard_fetch_queued_jobs` : Récupération jobs queued
- `public.whiteboard_mark_processing` : Marquage processing
- `public.whiteboard_mark_done` : Marquage done
- `public.whiteboard_mark_failed` : Marquage failed

**Configuration** :
- `SUPABASE_URL` : URL Supabase
- `SUPABASE_SERVICE_KEY` : Clé service
- `WHITEBOARD_BUCKET` : `whiteboard-renders`
- `WHITEBOARD_TABLE` : `whiteboard_renders`
- `WORKER_LOOP` : Mode boucle ou exécution unique
- `WORKER_INTERVAL_SECONDS` : Intervalle boucle (défaut: 2s)
- `WORKER_MAX_JOBS` : Jobs max par itération (défaut: 1)

---

### Worker déployé sur Kamatera

**Statut** : ❌ **NON DÉPLOYÉ**

**Preuve** :
- Aucune preuve de déploiement dans les mémoires
- Aucun script de déploiement exécuté
- Aucun accès Kamatera disponible

**Conclusion** : Le worker n'est pas déployé sur Kamatera. Impossible de valider le pipeline réel sans déploiement.

---

## ÉTAPE 2 – VÉRIFICATION DÉPENDANCES

### Dépendances Python requises

| Dépendance | Version locale | Statut Kamatera |
|------------|----------------|-----------------|
| `httpx` | ✅ Présente | ❌ Non vérifiable (worker non déployé) |
| `python-dotenv` | ✅ Présente | ❌ Non vérifiable (worker non déployé) |
| `Pillow` | ✅ Présente (via whiteboard_png_renderer) | ❌ Non vérifiable (worker non déployé) |
| `FFmpeg` | ✅ Présent (via whiteboard_ffmpeg_assembler) | ❌ Non vérifiable (worker non déployé) |

**Conclusion** : Impossible de vérifier les dépendances sur Kamatera sans accès.

---

## ÉTAPE 3 – CRÉATION STORYBOARD RÉEL

### Storyboard minimal

**Structure** :
```json
{
  "version": "1.0",
  "created_at": "2026-06-23T18:00:00Z",
  "created_by": "c63e9c1e-92d9-43f3-ab41-066ec3dc788b",
  "subject": "Test Pipeline",
  "renderer": "scientific",
  "theme": "scientific",
  "narration_mode": "none",
  "export_settings": {
    "format": "mp4",
    "resolution": {
      "width": 1080,
      "height": 1920
    },
    "frame_rate": 30,
    "video_codec": "h264",
    "audio_codec": "aac"
  },
  "scenes": [
    {
      "id": "scene-1",
      "order": 0,
      "title": "Titre Test",
      "duration_ms": 5000,
      "blocks": [
        {
          "id": "block-1",
          "type": "title",
          "content": "Test Pipeline Smart Whiteboard",
          "order": 0,
          "visible": true,
          "style": {
            "font_size": 48,
            "font_weight": "bold",
            "color": "#000000"
          }
        }
      ]
    },
    {
      "id": "scene-2",
      "order": 1,
      "title": "Paragraphe Test",
      "duration_ms": 5000,
      "blocks": [
        {
          "id": "block-2",
          "type": "paragraph",
          "content": "Ceci est un test de validation du pipeline Smart Whiteboard.",
          "order": 0,
          "visible": true,
          "style": {
            "font_size": 24,
            "color": "#333333"
          }
        }
      ]
    },
    {
      "id": "scene-3",
      "order": 2,
      "title": "Définition Test",
      "duration_ms": 5000,
      "blocks": [
        {
          "id": "block-3",
          "type": "definition",
          "term": "Smart Whiteboard",
          "definition": "Système de génération vidéo à partir de storyboards pédagogiques.",
          "example": "Ce test valide le pipeline complet.",
          "order": 0,
          "visible": true,
          "style": {
            "term_color": "#0000FF",
            "definition_color": "#333333",
            "example_color": "#666666"
          }
        }
      ]
    }
  ]
}
```

---

## ÉTAPE 4 – CRÉATION RENDERJOB RÉEL

### Pré-requis

**LOT 1** : ✅ Terminé (CHECK status corrigé, export_settings ajouté, started_at ajouté)

**RPCs C.3B.1** : ✅ Présentes (public.whiteboard_fetch_queued_jobs, whiteboard_mark_processing, whiteboard_mark_done, whiteboard_mark_failed)

### Création du RenderJob

**Script** : À créer

**Action** :
1. Créer un project avec le Storyboard minimal
2. Créer un render job avec `status='queued'`

---

## ÉTAPE 5 – LANCEMENT WORKER ACTUEL

### Mode local

**Commande** :
```bash
cd academia_bobodo_backend
python whiteboard_render_worker.py
```

**Configuration** :
- `WORKER_LOOP=0` : Exécution unique
- `WORKER_MAX_JOBS=1` : 1 job max

---

### Mode Kamatera

**Statut** : ❌ **NON DÉPLOYÉ**

**Conclusion** : Impossible de lancer le worker sur Kamatera sans déploiement.

---

## ÉTAPE 6 – OBSERVATION TRANSITIONS

### Transitions attendues

```
queued
  ↓
processing
  ↓
done
```

ou

```
queued
  ↓
processing
  ↓
failed
```

### Transitions observables

**Statut** : ❌ **NON OBSERVABLE** (worker non déployé)

---

## ÉTAPE 7 – VÉRIFICATION PIPELINE COMPLET

### Éléments à vérifier

| Élément | Statut | Observation |
|---------|--------|-------------|
| PNG générés | ❌ Non vérifiable | Worker non déployé |
| FFmpeg exécuté | ❌ Non vérifiable | Worker non déployé |
| MP4 généré | ❌ Non vérifiable | Worker non déployé |
| Upload Storage | ❌ Non vérifiable | Worker non déployé |
| URL finale | ❌ Non vérifiable | Worker non déployé |

---

## ÉTAPE 8 – MÉTRIQUES RÉELLES

| Métrique | Valeur attendue | Valeur réelle |
|----------|----------------|--------------|
| Temps total | ~30s (3 scènes × 5s + traitement) | ❌ Non mesurable |
| CPU | Variable | ❌ Non mesurable |
| RAM | Variable | ❌ Non mesurable |
| Taille MP4 | ~1-5 MB | ❌ Non mesurable |

---

## ÉTAPE 9 – PREMIER BLOCAGE RÉEL

### Blocage identifié

**Blocage principal** : **WORKER NON DÉPLOYÉ SUR KAMATERA**

**Impact** :
- Impossible de valider le pipeline réel
- Impossible de générer des PNGs
- Impossible d'exécuter FFmpeg
- Impossible de générer des MP4
- Impossible d'uploader vers Storage

**Cause** :
- Aucun déploiement du worker sur Kamatera
- Aucun accès Kamatera disponible
- Aucun script de déploiement exécuté

**Solution requise** :
1. Déployer le worker sur Kamatera
2. Configurer les variables d'environnement
3. Installer les dépendances (Pillow, FFmpeg)
4. Lancer le worker en mode boucle

---

## CONCLUSION

### Résumé

**Pipeline réel** : ❌ **NON VALIDABLE**

**Raison** : Worker non déployé sur Kamatera

**Premier blocage** : Déploiement worker Kamatera

### État actuel

| Composant | Statut |
|-----------|--------|
| LOT 1 (Schema) | ✅ Conforme |
| RPCs C.3B.1 | ✅ Présentes |
| Worker local | ✅ Disponible |
| Worker Kamatera | ❌ Non déployé |
| Pipeline réel | ❌ Non testable |

### Recommandation

**Avant de valider le pipeline réel, déployer le worker sur Kamatera.**

**Alternatives** :
1. Exécuter le worker en local (requiert accès local aux dépendances)
2. Simuler le pipeline localement
3. Attendre le déploiement Kamatera

---

**Fin du Real Pipeline Validation**
