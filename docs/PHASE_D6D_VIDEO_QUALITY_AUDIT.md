# PHASE D.6D – VIDEO QUALITY AUDIT

**Date** : 24 Juin 2026  
**Phase** : D.6D – Product Integration and Real User Validation  
**Composant** : Smart Whiteboard Video Quality Audit

---

## OBJECTIF

Auditer la qualité vidéo des rendus Smart Whiteboard pour valider :
- La résolution vidéo
- Le débit binaire (bitrate)
- La fluidité (framerate)
- La synchronisation audio/vidéo
- La qualité visuelle (netteté, lisibilité du texte)
- La durée du rendu

---

## 1. MÉTHODOLOGIE D'AUDIT

### 1.1 Sélection des vidéos

Utiliser les 20 vidéos générées lors de l'audit pédagogique (PHASE D.6C) :
- 5 vidéos Mode A
- 5 vidéos Mode B
- 5 vidéos Mode C
- 5 vidéos Mode D

### 1.2 Critères d'évaluation

Chaque vidéo est évaluée sur 7 critères :

#### 1.2.1 Critères techniques

1. **Résolution** : Dimensions de la vidéo (largeur × hauteur)
   - Cible : 1920×1080 (Full HD)
   - Minimum acceptable : 1280×720 (HD)

2. **Débit binaire (bitrate)** : Débit de données en Mbps
   - Cible : 5-10 Mbps
   - Minimum acceptable : 3 Mbps

3. **Framerate** : Nombre d'images par seconde (fps)
   - Cible : 30 fps
   - Minimum acceptable : 24 fps

4. **Durée du rendu** : Temps de traitement sur Kamatera
   - Cible : < 5 minutes par vidéo
   - Maximum acceptable : 10 minutes

#### 1.2.2 Critères visuels

5. **Netteeté** : Clarté des contours et du texte
   - Note de 1 à 5 (1 = flou, 5 = très net)

6. **Lisibilité du texte** : Capacité à lire le texte affiché
   - Note de 1 à 5 (1 = illisible, 5 = parfaitement lisible)

7. **Fluidité de l'animation** : Absence de saccades ou de lags
   - Note de 1 à 5 (1 = très saccadé, 5 = très fluide)

#### 1.2.3 Critère audio (si narration)

8. **Synchronisation audio/vidéo** : Alignement temporel
   - Note de 1 à 5 (1 = désynchronisé, 5 = parfaitement synchronisé)

### 1.3 Outils d'analyse

- **ffprobe** : Pour extraire les métadonnées vidéo (résolution, bitrate, framerate, durée)
- **ffmpeg** : Pour vérifier l'intégrité du fichier
- **Observation visuelle** : Pour évaluer la netteté, lisibilité et fluidité
- **Lecture vidéo** : Pour vérifier la synchronisation audio/vidéo

---

## 2. PROCÉDURE D'AUDIT

### 2.1 Extraction des métadonnées

Pour chaque vidéo, exécuter :

```bash
ffprobe -v quiet -print_format json -show_format -show_streams <video_url>
```

Extraire :
- `width` : Largeur en pixels
- `height` : Hauteur en pixels
- `bit_rate` : Débit binaire en bps
- `r_frame_rate` : Framerate
- `duration` : Durée en secondes
- `codec_name` : Codec vidéo (ex: h264)

### 2.2 Évaluation visuelle

Pour chaque vidéo :
1. Télécharger le fichier MP4
2. Lire la vidéo sur un écran Full HD
3. Évaluer la netteté (1-5)
4. Évaluer la lisibilité du texte (1-5)
5. Évaluer la fluidité de l'animation (1-5)
6. Si narration : évaluer la synchronisation audio/vidéo (1-5)

### 2.3 Mesure du temps de rendu

Pour chaque vidéo :
1. Noter l'heure de création du job de rendu
2. Noter l'heure de fin du rendu (statut "done")
3. Calculer la durée : `temps_fin - temps_debut`

---

## 3. RÉSULTATS ATTENDUS

### 3.1 Tableau de métadonnées techniques

| Vidéo | Mode | Résolution | Bitrate (Mbps) | Framerate (fps) | Codec | Durée (s) | Temps rendu (min) |
|-------|------|------------|----------------|-----------------|-------|-----------|-------------------|
| 1 | A | ? | ? | ? | ? | ? | ? |
| 2 | A | ? | ? | ? | ? | ? | ? |
| ... | ... | ... | ... | ... | ... | ... | ... |
| 20 | D | ? | ? | ? | ? | ? | ? |

### 3.2 Tableau d'évaluation visuelle

| Vidéo | Mode | Netteeté (1-5) | Lisibilité (1-5) | Fluidité (1-5) | Sync A/V (1-5) | Moyenne visuelle |
|-------|------|----------------|------------------|----------------|----------------|------------------|
| 1 | A | ? | ? | ? | ? | ? |
| 2 | A | ? | ? | ? | ? | ? |
| ... | ... | ... | ... | ... | ... | ... |
| 20 | D | ? | ? | ? | ? | ? |

### 3.3 Moyennes par mode

| Mode | Résolution | Bitrate | Framerate | Temps rendu | Netteeté | Lisibilité | Fluidité | Sync A/V |
|------|------------|---------|-----------|-------------|----------|-------------|----------|----------|
| A | ? | ? | ? | ? | ? | ? | ? | ? |
| B | ? | ? | ? | ? | ? | ? | ? | ? |
| C | ? | ? | ? | ? | ? | ? | ? | ? |
| D | ? | ? | ? | ? | ? | ? | ? | ? |

---

## 4. CRITÈRES DE VALIDATION

### 4.1 Seuils techniques

- **Résolution ≥ 1280×720** : HD minimum
- **Résolution ≥ 1920×1080** : Full HD cible
- **Bitrate ≥ 3 Mbps** : Minimum acceptable
- **Bitrate ≥ 5 Mbps** : Cible
- **Framerate ≥ 24 fps** : Minimum acceptable
- **Framerate ≥ 30 fps** : Cible
- **Temps de rendu ≤ 10 min** : Maximum acceptable
- **Temps de rendu ≤ 5 min** : Cible

### 4.2 Seuils visuels

- **Netteeté ≥ 3.5/5** : Texte lisible
- **Netteeté ≥ 4.0/5** : Excellent
- **Lisibilité ≥ 3.5/5** : Texte compréhensible
- **Lisibilité ≥ 4.0/5** : Excellent
- **Fluidité ≥ 3.5/5** : Animation fluide
- **Fluidité ≥ 4.0/5** : Excellent
- **Sync A/V ≥ 3.5/5** : Synchronisation acceptable
- **Sync A/V ≥ 4.0/5** : Excellent

### 4.3 Décision GO/NO-GO

- **GO** : Si tous les seuils minimums sont satisfaits
- **NO-GO** : Si un ou plusieurs seuils minimums ne sont pas satisfaits

---

## 5. ACTIONS CORRECTIVES

### 5.1 Si résolution < 1280×720

- Augmenter la résolution de sortie dans le worker Kamatera
- Vérifier les paramètres de rendu FFmpeg
- S'assurer que le renderer supporte la résolution HD

### 5.2 Si bitrate < 3 Mbps

- Augmenter le bitrate de sortie dans FFmpeg
- Utiliser un codec plus efficace (H.265/HEVC)
- Optimiser les paramètres de compression

### 5.3 Si framerate < 24 fps

- Augmenter le framerate de sortie
- Vérifier les paramètres d'animation du renderer
- Optimiser le pipeline de rendu

### 5.4 Si temps de rendu > 10 min

- Optimiser le worker Kamatera (CPU/GPU)
- Paralléliser les tâches de rendu
- Réduire la complexité des animations
- Utiliser un renderer plus performant

### 5.5 Si netteté < 3.5/5

- Augmenter la résolution de sortie
- Améliorer les paramètres d'anticrénelage
- Optimiser les polices et le texte
- Vérifier les paramètres de mise au point

### 5.6 Si lisibilité < 3.5/5

- Augmenter la taille du texte
- Améliorer le contraste texte/fond
- Utiliser des polices plus lisibles
- Optimiser le positionnement du texte

### 5.7 Si fluidité < 3.5/5

- Augmenter le framerate
- Optimiser les animations
- Réduire la complexité des transitions
- Améliorer le pipeline de rendu

### 5.8 Si sync A/V < 3.5/5

- Synchroniser les pistes audio et vidéo
- Vérifier les timestamps
- Optimiser le pipeline de narration
- Utiliser un meilleur moteur TTS

---

## 6. SCRIPT D'AUDIT AUTOMATISÉ

### 6.1 Script Python

Créer un script Python pour automatiser l'extraction des métadonnées :

```python
#!/usr/bin/env python3
"""
Script d'audit vidéo automatique pour Smart Whiteboard
"""

import json
import subprocess
import httpx
from typing import Dict, Any

def get_video_metadata(video_url: str) -> Dict[str, Any]:
    """Extrait les métadonnées vidéo via ffprobe"""
    cmd = [
        "ffprobe",
        "-v", "quiet",
        "-print_format", "json",
        "-show_format",
        "-show_streams",
        video_url
    ]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    data = json.loads(result.stdout)
    
    # Extraire les métadonnées pertinentes
    video_stream = None
    audio_stream = None
    
    for stream in data.get("streams", []):
        if stream.get("codec_type") == "video":
            video_stream = stream
        elif stream.get("codec_type") == "audio":
            audio_stream = stream
    
    return {
        "width": video_stream.get("width") if video_stream else None,
        "height": video_stream.get("height") if video_stream else None,
        "bitrate": int(data.get("format", {}).get("bit_rate", 0)) / 1_000_000,  # Mbps
        "framerate": eval(video_stream.get("r_frame_rate", "0/1")) if video_stream else 0,
        "duration": float(data.get("format", {}).get("duration", 0)),
        "codec": video_stream.get("codec_name") if video_stream else None,
        "has_audio": audio_stream is not None,
    }

def audit_video(video_url: str) -> Dict[str, Any]:
    """Audite une vidéo complète"""
    metadata = get_video_metadata(video_url)
    
    # Évaluer les critères techniques
    resolution_ok = metadata["width"] >= 1280 and metadata["height"] >= 720
    bitrate_ok = metadata["bitrate"] >= 3
    framerate_ok = metadata["framerate"] >= 24
    
    return {
        "metadata": metadata,
        "criteria": {
            "resolution_ok": resolution_ok,
            "bitrate_ok": bitrate_ok,
            "framerate_ok": framerate_ok,
        },
        "overall": resolution_ok and bitrate_ok and framerate_ok,
    }

if __name__ == "__main__":
    # Exemple d'utilisation
    video_url = "https://example.com/video.mp4"
    result = audit_video(video_url)
    print(json.dumps(result, indent=2))
```

### 6.2 Script Bash

Créer un script Bash pour traiter toutes les vidéos en lot :

```bash
#!/bin/bash
# Script d'audit vidéo en lot

VIDEO_URLS=(
    "https://storage.example.com/video1.mp4"
    "https://storage.example.com/video2.mp4"
    # ... ajouter toutes les URLs
)

for url in "${VIDEO_URLS[@]}"; do
    echo "Auditing: $url"
    python3 audit_video.py "$url"
done
```

---

## 7. RAPPORT D'AUDIT

### 7.1 Structure du rapport

1. **Résumé exécutif**
   - Objectif de l'audit
   - Méthodologie
   - Résultats clés
   - Recommandations

2. **Détail technique**
   - Tableau des métadonnées
   - Analyse par mode
   - Comparaison avec les cibles

3. **Évaluation visuelle**
   - Tableau des notes visuelles
   - Analyse par mode
   - Problèmes identifiés

4. **Performance de rendu**
   - Temps de rendu par vidéo
   - Moyenne par mode
   - Analyse des goulots d'étranglement

5. **Problèmes récurrents**
   - Liste des problèmes techniques
   - Liste des problèmes visuels
   - Fréquence d'apparition

6. **Recommandations**
   - Actions prioritaires
   - Actions secondaires
   - Améliorations futures

7. **Conclusion**
   - Décision GO/NO-GO
   - Conditions de validation
   - Prochaines étapes

### 7.2 Livrables

- `docs/PHASE_D6D_VIDEO_QUALITY_AUDIT_REPORT.md` : Rapport complet
- `.windsurf/video_audit_results.json` : Résultats bruts
- `.windsurf/video_audit_metadata.json` : Métadonnées techniques

---

## 8. INSTRUCTIONS D'EXÉCUTION

### 8.1 Prérequis

- 20 vidéos générées (via PHASE D.6C)
- Accès aux URLs MP4 (Supabase Storage)
- ffprobe et ffmpeg installés
- Python 3 installé
- Script d'audit vidéo disponible

### 8.2 Exécution

1. Récupérer les URLs des 20 vidéos (via Supabase)
2. Exécuter le script d'audit automatique
3. Compléter l'évaluation visuelle manuelle
4. Compiler les résultats
5. Rédiger le rapport d'audit

### 8.3 Durée estimée

- Extraction des métadonnées : 30 minutes
- Évaluation visuelle : 2-3 heures
- Compilation et rapport : 1-2 heures
- **Total** : 3.5-5.5 heures

---

## 9. CONCLUSION

L'audit vidéo permettra de valider la qualité technique et visuelle des rendus Smart Whiteboard. Les résultats seront utilisés pour :

- Valider la résolution et le bitrate
- Mesurer la performance de rendu
- Identifier les problèmes visuels
- Optimiser le pipeline de rendu
- Décider du GO/NO-GO pour la bêta utilisateurs

---

**Fin de PHASE_D6D_VIDEO_QUALITY_AUDIT.md**
