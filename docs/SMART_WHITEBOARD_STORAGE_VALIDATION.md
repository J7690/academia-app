# SMART WHITEBOARD IA V1 – STORAGE VALIDATION

**Version** : 1.0  
**Date** : 23 Juin 2026  
**Mode** : LECTURE SEULE  
**Objectif** : Validation de l'architecture de stockage

---

## DIRECTIVE TECHNIQUE PERMANENTE

Toute vérification concernant Supabase, Tables, Buckets, RPC, Edge Functions, Stockage doit obligatoirement être réalisée via les RPC Python administrateurs présents dans `.windsurf`.

Aucune hypothèse autorisée.

---

## PARTIE 1 – WHITEBOARD_PROJECTS

### 1.1 Colonnes proposées

| Colonne | Type | Obligatoire | Description |
|---------|------|-------------|-------------|
| id | UUID | ✅ | Identifiant unique du projet |
| student_id | UUID | ✅ | Identifiant de l'étudiant propriétaire |
| subject | TEXT | ✅ | Sujet du projet |
| status | TEXT | ✅ | Statut du projet (draft, completed) |
| created_at | TIMESTAMPTZ | ✅ | Date de création |
| updated_at | TIMESTAMPTZ | ✅ | Date de dernière modification |
| renderer_id | TEXT | ✅ | ID du renderer (scientific, notebook) |
| theme_id | TEXT | ✅ | ID du thème (scientific, notebook) |
| narration_mode | TEXT | ✅ | Mode de narration (none, tts, user_recording) |
| storyboard_json | JSONB | ✅ | Storyboard JSON complet |

### 1.2 Types

| Colonne | Type Supabase | Justification |
|---------|---------------|---------------|
| id | UUID | Identifiant unique, indexation native |
| student_id | UUID | Référence vers students.id |
| subject | TEXT | Sujet libre, pas besoin de longueur fixe |
| status | TEXT | Enum simple (draft, completed) |
| created_at | TIMESTAMPTZ | Date avec timezone |
| updated_at | TIMESTAMPTZ | Date avec timezone |
| renderer_id | TEXT | Enum simple (scientific, notebook) |
| theme_id | TEXT | Enum simple (scientific, notebook) |
| narration_mode | TEXT | Enum simple (none, tts, user_recording) |
| storyboard_json | JSONB | Stockage flexible du Storyboard |

### 1.3 Index

| Index | Colonnes | Type | Justification |
|-------|----------|------|---------------|
| idx_whiteboard_projects_id | id | B-tree | Recherche par ID |
| idx_whiteboard_projects_student_id | student_id | B-tree | Liste des projets d'un étudiant |
| idx_whiteboard_projects_status | status | B-tree | Filtrage par statut |
| idx_whiteboard_projects_created_at | created_at | B-tree | Tri par date |
| idx_whiteboard_projects_storyboard_json | storyboard_json | GIN | Recherche dans le Storyboard |

### 1.4 Contraintes

| Contrainte | Colonnes | Type | Justification |
|-----------|----------|------|---------------|
| pk_whiteboard_projects | id | PRIMARY KEY | Identifiant unique |
| fk_whiteboard_projects_student_id | student_id | FOREIGN KEY | Référence vers students |
| chk_whiteboard_projects_status | status | CHECK | Valeurs autorisées (draft, completed) |
- chk_whiteboard_projects_renderer_id | renderer_id | CHECK | Valeurs autorisées (scientific, notebook) |
- chk_whiteboard_projects_theme_id | theme_id | CHECK | Valeurs autorisées (scientific, notebook) |
- chk_whiteboard_projects_narration_mode | narration_mode | CHECK | Valeurs autorisées (none, tts, user_recording) |

### 1.5 Stockage du Storyboard

**Question** : Le storyboard doit-il être stocké en JSONB ou en tables relationnelles ?

**Réponse** : **JSONB**

**Justification** :

1. **Flexibilité** : Le Storyboard est une structure hiérarchique (Storyboard → Scenes → Blocks) qui se prête mal au stockage relationnel
2. **Évolutivité** : JSONB permet d'ajouter de nouveaux champs sans migration
3. **Performance** : JSONB avec index GIN permet des recherches efficaces
4. **Simplicité** : Un seul champ au lieu de plusieurs tables (whiteboard_scenes, whiteboard_blocks)
5. **Taille** : Un Storyboard typique V1 fait ~5-10 Ko, bien dans les limites de JSONB
6. **Fréquence** : Le Storyboard est lu en entier lors de l'édition, pas besoin de requêtes granulaires

**Alternative rejetée** : Tables relationnelles (whiteboard_scenes, whiteboard_blocks)
- Complexité excessive pour V1
- Requêtes JOIN multiples
- Migration lourde pour ajouter des champs

---

## PARTIE 2 – STORYBOARD

### 2.1 Taille estimée

| Élément | Taille estimée | Justification |
|---------|----------------|---------------|
| Version | 10 octets | "1.0" |
| Created_at | 25 octets | ISO8601 |
- Created_by | 36 octets | UUID |
- Subject | 50 octets | Sujet typique |
- Renderer | 10 octets | "scientific" |
- Theme | 10 octets | "scientific" |
- Narration_mode | 15 octets | "user_recording" |
- Export_settings | 50 octets | JSON simple |
- Scenes (10 scènes) | 5 Ko | 10 scènes × 500 octets |
- **Total** | **~5.2 Ko** | Storyboard typique V1 |

**Scénario maximal** :
- 50 scènes
- 200 blocs
- Taille estimée : ~20 Ko

**Conclusion** : Taille négligeable pour JSONB (limite Supabase : 1 Go par document)

### 2.2 Fréquence de lecture

| Opération | Fréquence | Justification |
|-----------|-----------|---------------|
| Lecture complète (édition) | 1-5 fois par projet | Éditeur, prévisualisation |
- Lecture partielle (rendu) | 1 fois par projet | Kamatera |
- Lecture partielle (liste) | 1 fois par liste | Liste des projets |
- Écriture (création) | 1 fois par projet | Création initiale |
- Écriture (mise à jour) | 5-20 fois par projet | Éditions successives |

**Conclusion** : Fréquence modérée, JSONB adapté

### 2.3 Fréquence d'écriture

| Opération | Fréquence | Justification |
|-----------|-----------|---------------|
| Création | 1 fois par projet | Création initiale |
- Mise à jour | 5-20 fois par projet | Éditions successives |
- Suppression | 1 fois par projet | Suppression finale |

**Conclusion** : Fréquence faible, JSONB adapté

### 2.4 Recommandation

**Stockage JSONB** ✅

**Justification** :
- Taille négligeable (~5-20 Ko)
- Fréquence modérée de lecture/écriture
- Flexibilité pour évolution
- Performance avec index GIN

**Alternatives rejetées** :
- Stockage hybride : Complexité excessive pour V1
- Stockage relationnel : Complexité excessive, migration lourde

---

## PARTIE 3 – NARRATIONS

### 3.1 Bucket proposé

**Nom** : `whiteboard-narrations`

**Rôle** : Stockage des fichiers audio de narration

### 3.2 Format audio

| Format | Codec | Qualité | Taille moyenne | Justification |
|--------|-------|---------|---------------|---------------|
| MP3 | AAC | 128 kbps | 1 Mo/min | Standard, compatible |
| WAV | PCM | 44.1 kHz | 10 Mo/min | Qualité maximale, trop lourd |
- OGG | Opus | 64 kbps | 0.5 Mo/min | Qualité suffisante, moins standard |

**Recommandation** : **MP3 (AAC, 128 kbps)**

**Justification** :
- Standard universel
- Compatible avec tous les lecteurs
- Taille raisonnable
- Qualité suffisante pour narration

### 3.3 Taille moyenne

| Durée | Taille MP3 (128 kbps) | Justification |
|-------|----------------------|---------------|
| 30 secondes | 0.5 Mo | Narration courte |
- 1 minute | 1 Mo | Narration typique |
- 5 minutes | 5 Mo | Narration longue |
- 10 minutes | 10 Mo | Narration très longue |

**Scénario typique** : 1-3 minutes → 1-3 Mo

### 3.4 Stratégie de stockage

**Structure** :
```
whiteboard-narrations/
  {project_id}/
    narration.mp3
```

**Politique de rétention** :
- Conserver tant que le projet existe
- Supprimer avec le projet (CASCADE)

**Justification** :
- Narration spécifique au projet
- Pas de réutilisation entre projets
- Nettoyage automatique via CASCADE

---

## PARTIE 4 – RENDUS

### 4.1 Stockage vidéo

**Bucket proposé** : `whiteboard-renders`

**Rôle** : Stockage des MP4 générés

### 4.2 Format vidéo

| Paramètre | Valeur V1 | Justification |
|-----------|-----------|---------------|
| Format | MP4 | Standard universel |
| Codec vidéo | H.264 | Standard, compatible |
- Codec audio | AAC | Standard, compatible |
- Résolution | 1080x1920 (9:16) | Format vertical mobile |
- Frame rate | 30 fps | Standard |
- Bitrate vidéo | 2-5 Mbps | Qualité raisonnable |
- Bitrate audio | 128 kbps | Qualité suffisante |

### 4.3 Taille estimée

| Durée | Taille MP4 (2-5 Mbps) | Justification |
|-------|----------------------|---------------|
| 30 secondes | 7.5-18.75 Mo | Vidéo courte |
- 1 minute | 15-37.5 Mo | Vidéo typique |
- 5 minutes | 75-187.5 Mo | Vidéo longue |
- 10 minutes | 150-375 Mo | Vidéo très longue |

**Scénario typique** : 1-3 minutes → 15-112.5 Mo

### 4.4 Historique des rendus

**Approche** : Conserver uniquement le dernier rendu par projet

**Justification** :
- Rendu déterministe (même Storyboard = même MP4)
- Pas besoin d'historique pour V1
- Économie de stockage
- Simplification de l'architecture

**Évolution future (V2+)** :
- Ajouter une table `whiteboard_render_history` si nécessaire
- Configurable par projet

### 4.5 Nettoyage automatique

**Politique** :
- Supprimer le MP4 avec le projet (CASCADE)
- Supprimer le MP4 si le rendu échoue (timeout 24h)

**Justification** :
- Rendu spécifique au projet
- Pas de réutilisation entre projets
- Nettoyage automatique via CASCADE

---

## PARTIE 5 – INDEXATION

### 5.1 Index nécessaires

| Index | Colonnes | Type | Requêtes | Justification |
|-------|----------|------|----------|---------------|
| idx_whiteboard_projects_id | id | B-tree | SELECT par ID | Recherche par ID |
- idx_whiteboard_projects_student_id | student_id | B-tree | SELECT par student_id | Liste des projets d'un étudiant |
- idx_whiteboard_projects_status | status | B-tree | SELECT par status | Filtrage par statut |
- idx_whiteboard_projects_created_at | created_at | B-tree | ORDER BY created_at | Tri par date |
- idx_whiteboard_projects_storyboard_json | storyboard_json | GIN | SELECT dans Storyboard | Recherche dans le Storyboard |
- idx_whiteboard_renders_id | id | B-tree | SELECT par ID | Recherche par ID |
- idx_whiteboard_renders_project_id | project_id | B-tree | SELECT par project_id | Liste des rendus d'un projet |
- idx_whiteboard_renders_status | status | B-tree | SELECT par status | Filtrage par statut |
- idx_whiteboard_renders_created_at | created_at | B-tree | ORDER BY created_at | Tri par date |

### 5.2 Recherches futures

| Recherche | Index | Justification |
|----------|-------|---------------|
| Projets par sujet | idx_whiteboard_projects_storyboard_json (GIN) | Recherche textuelle dans Storyboard |
- Projets par renderer | idx_whiteboard_projects_renderer_id (B-tree) | Filtrage par renderer |
- Projets par thème | idx_whiteboard_projects_theme_id (B-tree) | Filtrage par thème |
- Projets par narration_mode | idx_whiteboard_projects_narration_mode (B-tree) | Filtrage par mode de narration |
- Rendus en attente | idx_whiteboard_renders_status (B-tree) | Polling des jobs |
- Rendus échoués | idx_whiteboard_renders_status (B-tree) | Monitoring des erreurs |

### 5.3 Optimisation requise

| Optimisation | Priorité | Justification |
|--------------|----------|---------------|
| Index GIN sur storyboard_json | Haute | Recherche textuelle dans Storyboard |
- Index B-tree sur student_id | Haute | Liste des projets d'un étudiant |
- Index B-tree sur status (whiteboard_renders) | Haute | Polling des jobs |
- Partitionnement par date | Basse | Non nécessaire pour V1 (volume faible) |
- Materialized views | Basse | Non nécessaire pour V1 (volume faible) |

---

## PARTIE 6 – ÉVOLUTIVITÉ

### 6.1 Support V2

**Ajouts V2** :
- Animations complexes (slide_up, typewriter)
- Transitions entre scènes
- Zoom intelligent
- Surlignage intelligent

**Impact sur le schéma** :
- Aucune modification de table
- Ajout de champs dans storyboard_json (JSONB)
- Aucune migration requise

**Validation** : ✅ Supporté sans migration

### 6.2 Support V3

**Ajouts V3** :
- Écriture manuscrite
- Polices manuscrites
- Synchronisation progressive

**Impact sur le schéma** :
- Aucune modification de table
- Ajout de champs dans storyboard_json (JSONB)
- Ajout de bloc type : handwriting
- Aucune migration requise

**Validation** : ✅ Supporté sans migration

### 6.3 Support V4

**Ajouts V4** :
- Zoom intelligent
- Pan intelligent
- Navigation interactive

**Impact sur le schéma** :
- Aucune modification de table
- Ajout de champs dans storyboard_json (JSONB)
- Ajout de métadonnées de navigation
- Aucune migration requise

**Validation** : ✅ Supporté sans migration

### 6.4 Support V5

**Ajouts V5** :
- Synchronisation mot par mot
- Synchronisation audio
- Main virtuelle

**Impact sur le schéma** :
- Aucune modification de table
- Ajout de champs dans storyboard_json (JSONB)
- Ajout de métadonnées de synchronisation
- Aucune migration requise

**Validation** : ✅ Supporté sans migration

### 6.5 Conclusion évolutivité

**Le schéma supporte V2-V5 sans migration lourde** ✅

**Justification** :
- Stockage JSONB flexible
- Ajout de champs sans migration
- Aucune contrainte structurelle
- Évolution naturelle du format Storyboard

---

## PARTIE 7 – MATRICE DE DÉCISION

### 7.1 Matrice de stockage

| Donnée | Stockage | Pourquoi | Qui l'utilise | Coût de maintenance |
|--------|----------|---------|--------------|---------------------|
| WhiteboardProject | Table whiteboard_projects | Métadonnées du projet | Flutter, Supabase, Kamatera | Faible (index standards) |
- Storyboard | JSONB dans whiteboard_projects | Structure hiérarchique flexible | Flutter, Bobodo, Kamatera, Renderer | Faible (index GIN) |
- Narration audio | Bucket whiteboard-narrations | Fichiers audio volumineux | Flutter, Kamatera | Faible (nettoyage CASCADE) |
- Rendu MP4 | Bucket whiteboard-renders | Fichiers vidéo volumineux | Kamatera, Flutter | Faible (nettoyage CASCADE) |
- RenderJob | Table whiteboard_renders | Métadonnées du rendu | Flutter, Kamatera | Faible (index standards) |

### 7.2 Justification détaillée

#### WhiteboardProject

**Stockage** : Table whiteboard_projects

**Pourquoi** :
- Métadonnées structurées (id, student_id, subject, status, etc.)
- Requêtes de filtrage et de tri
- Intégrité référentielle (student_id → students.id)

**Qui l'utilise** :
- Flutter : Liste des projets, création, mise à jour
- Supabase : Stockage, indexation
- Kamatera : Récupération du Storyboard

**Coût de maintenance** : Faible
- Index standards (B-tree)
- Contraintes FK et CHECK
- Pas de maintenance spécifique

#### Storyboard

**Stockage** : JSONB dans whiteboard_projects

**Pourquoi** :
- Structure hiérarchique (Storyboard → Scenes → Blocks)
- Flexibilité pour évolution (V2-V5)
- Taille négligeable (~5-20 Ko)
- Performance avec index GIN

**Qui l'utilise** :
- Flutter : Édition, prévisualisation
- Bobodo : Génération
- Kamatera : Rendu
- Renderer : Traitement

**Coût de maintenance** : Faible
- Index GIN pour recherche textuelle
- Aucune migration pour ajouter des champs
- Compression automatique Supabase

#### Narration audio

**Stockage** : Bucket whiteboard-narrations

**Pourquoi** :
- Fichiers audio volumineux (1-10 Mo)
- Stockage objet optimisé pour fichiers
- Accès direct via URL

**Qui l'utilise** :
- Flutter : Enregistrement, lecture
- Kamatera : Mixage avec vidéo

**Coût de maintenance** : Faible
- Nettoyage automatique via CASCADE
- Pas de maintenance spécifique

#### Rendu MP4

**Stockage** : Bucket whiteboard-renders

**Pourquoi** :
- Fichiers vidéo volumineux (15-375 Mo)
- Stockage objet optimisé pour fichiers
- Accès direct via URL

**Qui l'utilise** :
- Kamatera : Upload
- Flutter : Lecture, publication

**Coût de maintenance** : Faible
- Nettoyage automatique via CASCADE
- Pas de maintenance spécifique

#### RenderJob

**Stockage** : Table whiteboard_renders

**Pourquoi** :
- Métadonnées structurées (id, project_id, status, video_url, etc.)
- Requêtes de filtrage et de tri
- Polling du statut de rendu

**Qui l'utilise** :
- Flutter : Polling du statut
- Kamatera : Mise à jour du statut

**Coût de maintenance** : Faible
- Index standards (B-tree)
- Contraintes FK
- Pas de maintenance spécifique

---

## CONCLUSION

### Validation du schéma

**Le schéma proposé est validé pour V1-V5** ✅

**Justification** :
- Stockage JSONB flexible pour le Storyboard
- Taille négligeable (~5-20 Ko)
- Performance avec index GIN
- Évolutivité sans migration lourde
- Coût de maintenance faible

### Risques identifiés

| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|------------|
| Taille Storyboard > 1 Go | Très faible | Moyen | Limiter le nombre de scènes/blocs |
- Index GIN lent | Faible | Faible | Optimiser les requêtes |
- Bucket saturation | Faible | Moyen | Nettoyage automatique CASCADE |
- Migration requise pour V2+ | Très faible | Élevé | Stockage JSONB flexible |

### Recommandations

1. **Conserver le stockage JSONB** pour le Storyboard
2. **Utiliser des index GIN** pour la recherche dans le Storyboard
3. **Nettoyage automatique CASCADE** pour les buckets
4. **Surveiller la taille des Storyboards** (limite recommandée : 100 Ko)
5. **Surveiller l'espace de stockage** des buckets

### Critère de validation

**Les futures tables Supabase du Smart Whiteboard ne nécessiteront pas une refonte après quelques mois de développement** ✅

**Justification** :
- Stockage JSONB flexible pour évolution
- Aucune contrainte structurelle
- Ajout de champs sans migration
- Coût de maintenance faible

---

**Fin du document**
