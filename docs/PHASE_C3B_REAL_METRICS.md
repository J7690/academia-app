# PHASE C.3B – REAL METRICS

**Version** : 1.0  
**Date** : 23 Juin 2026  
**Phase** : C.3B – First Real Video  
**Mode** : EXÉCUTION RÉELLE  
**Objectif** : Enregistrer les métriques réelles du premier MP4 Smart Whiteboard

---

## INFORMATIONS DE TEST

**Date** : À remplir après exécution  
**Job ID** : À remplir après exécution  
**Sujet** : Photosynthèse  
**Scènes** : 6  
**Blocs** : 6 (1 titre, 1 définition, 1 paragraphe, 1 exercice, 1 formule, 1 correction)

---

## MÉTRIQUES TEMPS

### Temps total

**Début** : {started_at}  
**Fin** : {completed_at}  
**Durée totale** : {duration_seconds} secondes

### Détail par étape

| Étape | Durée estimée | Durée réelle |
|-------|--------------|--------------|
| Polling | 2s | {polling_time}s |
| Génération PNGs | 10-20s | {png_generation_time}s |
| Assemblage MP4 | 5-10s | {ffmpeg_time}s |
| Upload | 5-10s | {upload_time}s |
| **Total** | 22-42s | {total_time}s |

---

## MÉTRIQUES RESSOURCES

### CPU

**Utilisation moyenne** : {cpu_usage}%  
**Utilisation max** : {cpu_max}%  
**Cores utilisés** : {cores}

### RAM

**Utilisation moyenne** : {ram_usage} Mo  
**Utilisation max** : {ram_max} Mo  
**Pic** : {ram_peak} Mo

### Disque

**Espace temporaire utilisé** : {disk_usage} Mo  
**Espace libéré après traitement** : {disk_freed} Mo

---

## MÉTRIQUES FICHIER

### MP4

**Taille** : {mp4_size} Mo  
**Durée** : {mp4_duration} secondes  
**Résolution** : {mp4_resolution}  
**Codec** : {mp4_codec}  
**Bitrate** : {mp4_bitrate} kbps

### PNGs

**Nombre** : {png_count}  
**Taille totale** : {png_total_size} Mo  
**Taille moyenne** : {png_avg_size} Mo

---

## LOGS

### Logs Worker

```
{worker_logs}
```

### Logs FFmpeg

```
{ffmpeg_logs}
```

---

## PREUVES

### URL MP4

```
{video_url}
```

### Statut final

```
{status}
```

### SQL Output

```sql
SELECT id, status, video_url, duration_ms, error_message, started_at, completed_at 
FROM app.whiteboard_renders 
WHERE id = '{job_id}';
```

**Résultat** :
```
{sql_output}
```

---

## COMPARAISON AVEC ESTIMATIONS

### Temps

| Métrique | Estimation | Réel | Écart |
|----------|-----------|------|-------|
| Temps total | 22-42s | {real_time}s | {diff_time}s |

### Ressources

| Métrique | Estimation | Réel | Écart |
|----------|-----------|------|-------|
| CPU | 1-2 cores | {real_cpu} cores | {diff_cpu} |
| RAM | 500-1000 Mo | {real_ram} Mo | {diff_ram} Mo |

### Fichier

| Métrique | Estimation | Réel | Écart |
|----------|-----------|------|-------|
| Taille MP4 | 5-10 Mo | {real_size} Mo | {diff_size} Mo |

---

## CONCLUSION

**Succès** : ✅ / ❌

**Observations** :
- {observation_1}
- {observation_2}
- {observation_3}

**Recommandations** :
- {recommendation_1}
- {recommendation_2}
- {recommendation_3}

---

## À REMPLIR APRÈS EXÉCUTION

Ce document doit être rempli avec les métriques réelles après l'exécution de la validation sur Kamatera.

---

**Fin du document**
