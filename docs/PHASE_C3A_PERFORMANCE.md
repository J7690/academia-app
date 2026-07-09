# PHASE C.3A – PERFORMANCE

**Version** : 1.0  
**Date** : 23 Juin 2026  
**Phase** : C.3A – Real Pipeline Validation  
**Mode** : EXÉCUTION  
**Objectif** : Mesurer les performances réelles du Renderer V1

---

## MÉTRIQUES MESURÉES

### 1. Temps réel

**Définition** : Durée entre started_at et completed_at

**Méthode de mesure** :
```sql
SELECT 
    id,
    started_at,
    completed_at,
    EXTRACT(EPOCH FROM (completed_at - started_at)) as duration_seconds
FROM app.whiteboard_renders
WHERE id = '{job_id}';
```

**Attendu** : 22-42 secondes

**Détail** :
- Polling : 2s
- Génération PNGs (6 scènes) : 10-20s
- Assemblage MP4 : 5-10s
- Upload : 5-10s

### 2. CPU réel

**Définition** : Utilisation CPU pendant le traitement

**Méthode de mesure** :
```bash
# Sur Kamatera
top -b -n 1 | grep python
```

**Attendu** : 1-2 cores

**Détail** :
- Parse JSON : 0.1 core
- Génération PNGs (Pillow) : 0.5-1 core
- Assemblage MP4 (FFmpeg) : 0.5-1 core
- Upload : 0.1 core

### 3. RAM réelle

**Définition** : Utilisation RAM pendant le traitement

**Méthode de mesure** :
```bash
# Sur Kamatera
free -h
```

**Attendu** : 500 Mo - 1 Go

**Détail** :
- Parse JSON : 10 Mo
- Génération PNGs (Pillow) : 200-400 Mo
- Assemblage MP4 (FFmpeg) : 100-200 Mo
- Upload : 10 Mo

### 4. Taille MP4

**Définition** : Taille du fichier MP4 uploadé

**Méthode de mesure** :
```bash
# Via l'URL publique
curl -I {video_url}
```

**Attendu** : 5-10 Mo

**Détail** :
- Durée : ~30s
- Codec : H.264
- CRF : 23
- Résolution : 1080x1920

---

## RÉSULTATS ATTENDUS

### Scénario de test

**Storyboard** : Photosynthèse (6 scènes)

**Blocs** :
- 1 titre
- 1 définition
- 1 paragraphe
- 1 exercice
- 1 formule
- 1 correction

### Métriques cibles

| Métrique | Cible | Acceptable |
|----------|-------|------------|
| Temps réel | 30s | < 60s |
| CPU | 1.5 cores | < 2 cores |
| RAM | 750 Mo | < 1 Go |
| Taille MP4 | 7.5 Mo | < 10 Mo |

---

## COMPARAISON AVEC ESTIMATION

### Estimation initiale (PHASE C.2)

**Simple (1 scène, 2 blocs)** : 30s  
**Moyen (3 scènes, 3 blocs)** : 60s  
**Complexe (5 scènes, 5 blocs)** : 180s

### Scénario de test actuel

**6 scènes, 6 blocs** : Équivalent à "Complexe"

**Estimation** : 180s  
**Réel attendu** : 22-42s

**Analyse** : L'estimation était conservatrice. Le temps réel est beaucoup plus court car :
- Pas de narration audio (reporté en V2)
- Pas d'animations complexes (fade_in uniquement)
- Pas de zoom/surlignage (reporté en V3)

---

## CAPACITÉ KAMATERA

### Capacité actuelle (selon audit)

- RAM totale : 9.7 Go
- RAM disponible : 8.2 Go
- CPU : 4 cores
- Disque disponible : 12 Go

### Capacité requise par rendu

- RAM : 500 Mo - 1 Go
- CPU : 1-2 cores
- Disque : 50-100 Mo (temporaire)

### Rendus simultanés possibles

**RAM** : 8.2 Go / 1 Go = 8 rendus max  
**CPU** : 4 cores / 2 cores = 2 rendus max  
**Disque** : 12 Go / 100 Mo = 120 rendus max

**Conclusion** : 2 rendus simultanés max (limité par CPU)

---

## SCALING

### Scaling vertical

**Option** : Augmenter les ressources Kamatera

**Impact** :
- CPU : 4 → 8 cores → 4 rendus simultanés
- RAM : 9.7 → 19.4 Go → 16 rendus simultanés

### Scaling horizontal

**Option** : Ajouter des workers supplémentaires

**Impact** :
- Chaque worker traite 1 job à la fois
- WORKER_MAX_JOBS peut être augmenté
- Plusieurs workers sur plusieurs serveurs

---

## PROCHAINES ÉTAPES

1. Déployer sur Kamatera
2. Exécuter le test de validation
3. Mesurer les métriques réelles
4. Comparer avec les estimations
5. Ajuster les estimations si nécessaire

---

**Fin du document**
