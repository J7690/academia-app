# PHASE B.4 – BUCKETS VALIDATION

**Version** : 1.0  
**Date** : 23 Juin 2026  
**Phase** : B.4 – Storage Buckets  
**Mode** : DÉVELOPPEMENT AUTORISÉ  
**Objectif** : Créer l'infrastructure de stockage du Smart Whiteboard

---

## DIRECTIVE TECHNIQUE PERMANENTE

Toute intervention concernant Supabase, Storage, Buckets doit être réalisée via les RPC Python administrateurs présents dans `.windsurf`.

---

## PARTIE 1 – LIMITATION IDENTIFIÉE

### 1.1 Architecture Supabase Storage

**Problème identifié** : Supabase Storage utilise une API REST séparée, pas SQL.

**Conséquence** : Les buckets Storage ne peuvent pas être créés via admin_execute_sql.

**Architecture** :
- Supabase Database : accessible via SQL et RPC admin_execute_sql
- Supabase Storage : accessible uniquement via API REST (POST /storage/buckets)

### 1.2 Méthodes de création des buckets

Les buckets Storage doivent être créés via :

1. **Supabase CLI** :
```bash
supabase storage create buckets whiteboard-narrations
supabase storage create buckets whiteboard-renders
```

2. **Dashboard Supabase** :
   - Navigation vers Storage
   - Bouton "New bucket"
   - Configuration du bucket

3. **API Storage directe** :
```bash
POST https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/bucket
Authorization: Bearer <service_role_key>
Content-Type: application/json

{
  "id": "whiteboard-narrations",
  "name": "whiteboard-narrations",
  "public": false
}
```

---

## PARTIE 2 – BUCKETS EXISTANTS

### 2.1 Liste des buckets actuels

| ID | Nom | Public | Type | File Size Limit |
|----|-----|--------|------|----------------|
- application-files | application-files | False | STANDARD | None |
- university-media | university-media | True | STANDARD | None |
- landing-media | landing-media | True | STANDARD | None |
- challenge-media | challenge-media | True | STANDARD | None |
- hero_videos | hero_videos | True | STANDARD | None |
- community-media | community-media | True | STANDARD | None |
- video-assets | video-assets | True | STANDARD | None |
- marketplace-media | marketplace-media | True | STANDARD | None |
- prep-documents | prep-documents | True | STANDARD | 52428800 |
- td-documents | td-documents | False | STANDARD | None |

**Total** : 10 buckets existants

### 2.2 Buckets whiteboard requis

| Bucket requis | État |
|---------------|------|
- whiteboard-narrations | ❌ Non existant |
- whiteboard-renders | ❌ Non existant |

---

## PARTIE 3 – SPÉCIFICATION DES BUCKETS REQUIS

### 3.1 whiteboard-narrations

**Contenu** :
- mp3
- wav

**Organisation** :
- `project_id/narration.ext`

**Sécurité requise** :
- Propriétaire : accès à ses fichiers
- Admin : accès complet
- Service Role : accès complet

**Configuration recommandée** :
```json
{
  "id": "whiteboard-narrations",
  "name": "whiteboard-narrations",
  "public": false,
  "file_size_limit": 104857600,
  "allowed_mime_types": ["audio/mpeg", "audio/wav", "audio/mp3"]
}
```

### 3.2 whiteboard-renders

**Contenu** :
- mp4

**Organisation** :
- `project_id/render.mp4`

**Sécurité requise** :
- Propriétaire : accès à ses fichiers
- Admin : accès complet
- Service Role : accès complet

**Configuration recommandée** :
```json
{
  "id": "whiteboard-renders",
  "name": "whiteboard-renders",
  "public": false,
  "file_size_limit": 524288000,
  "allowed_mime_types": ["video/mp4"]
}
```

---

## PARTIE 4 – POLITIQUES STORAGE REQUISES

### 4.1 Politiques whiteboard-narrations

**Politique SELECT pour propriétaire** :
```sql
CREATE POLICY whiteboard_narrations_select_owner 
ON storage.objects FOR SELECT 
USING (
  bucket_id = 'whiteboard-narrations' 
  AND auth.uid()::text = (storage.foldername(name))[1]::text
)
```

**Politique INSERT pour propriétaire** :
```sql
CREATE POLICY whiteboard_narrations_insert_owner 
ON storage.objects FOR INSERT 
WITH CHECK (
  bucket_id = 'whiteboard-narrations' 
  AND auth.uid()::text = (storage.foldername(name))[1]::text
)
```

**Politique UPDATE pour propriétaire** :
```sql
CREATE POLICY whiteboard_narrations_update_owner 
ON storage.objects FOR UPDATE 
USING (
  bucket_id = 'whiteboard-narrations' 
  AND auth.uid()::text = (storage.foldername(name))[1]::text
)
```

**Politique DELETE pour propriétaire** :
```sql
CREATE POLICY whiteboard_narrations_delete_owner 
ON storage.objects FOR DELETE 
USING (
  bucket_id = 'whiteboard-narrations' 
  AND auth.uid()::text = (storage.foldername(name))[1]::text
)
```

**Politiques pour Admin et Service Role** : Accès complet

### 4.2 Politiques whiteboard-renders

**Politique SELECT pour propriétaire** :
```sql
CREATE POLICY whiteboard_renders_select_owner 
ON storage.objects FOR SELECT 
USING (
  bucket_id = 'whiteboard-renders' 
  AND auth.uid()::text = (storage.foldername(name))[1]::text
)
```

**Politique INSERT pour propriétaire** :
```sql
CREATE POLICY whiteboard_renders_insert_owner 
ON storage.objects FOR INSERT 
WITH CHECK (
  bucket_id = 'whiteboard-renders' 
  AND auth.uid()::text = (storage.foldername(name))[1]::text
)
```

**Politique UPDATE pour propriétaire** :
```sql
CREATE POLICY whiteboard_renders_update_owner 
ON storage.objects FOR UPDATE 
USING (
  bucket_id = 'whiteboard-renders' 
  AND auth.uid()::text = (storage.foldername(name))[1]::text
)
```

**Politique DELETE pour propriétaire** :
```sql
CREATE POLICY whiteboard_renders_delete_owner 
ON storage.objects FOR DELETE 
USING (
  bucket_id = 'whiteboard-renders' 
  AND auth.uid()::text = (storage.foldername(name))[1]::text
)
```

**Politiques pour Admin et Service Role** : Accès complet

---

## PARTIE 5 – TESTS IMPOSSIBLES

### 5.1 Tests upload / lecture / suppression

**Impossibilité** : Les tests upload/lecture/suppression ne peuvent pas être effectués car :
1. Les buckets n'existent pas encore
2. Les buckets ne peuvent pas être créés via admin_execute_sql
3. Les tests nécessitent l'API Storage REST

### 5.2 Tests de politiques Storage

**Impossibilité** : Les tests de politiques Storage ne peuvent pas être effectués car :
1. Les buckets n'existent pas encore
2. Les politiques Storage ne peuvent être créées que sur des buckets existants
3. Les tests nécessitent une authentification réelle

---

## PARTIE 6 – NON-RÉGRESSION

### 6.1 Buckets existants

**Aucun bucket modifié** ✅

Les buckets existants sont inchangés :
- application-files
- university-media
- landing-media
- challenge-media
- hero_videos
- community-media
- video-assets
- marketplace-media
- prep-documents
- td-documents

### 6.2 Buckets Challenge

**Aucun bucket Challenge modifié** ✅

Le bucket challenge-media existe toujours avec la même configuration.

### 6.3 Buckets Bobodo

**Aucun bucket Bobodo modifié** ✅

---

## PARTIE 7 – RECOMMANDATIONS

### 7.1 Création des buckets

**Recommandation** : Utiliser Supabase CLI pour créer les buckets

```bash
# Création bucket whiteboard-narrations
supabase storage create buckets whiteboard-narrations

# Création bucket whiteboard-renders
supabase storage create buckets whiteboard-renders
```

### 7.2 Configuration des buckets

**Recommandation** : Configurer les buckets via Dashboard Supabase

1. Navigation vers Storage
2. Sélectionner le bucket
3. Configurer :
   - File size limit
   - Allowed MIME types
   - Public/Private

### 7.3 Création des politiques Storage

**Recommandation** : Créer les politiques Storage via admin_execute_sql après création des buckets

Une fois les buckets créés via Supabase CLI ou Dashboard, les politiques Storage peuvent être créées via admin_execute_sql.

---

## PARTIE 8 – DÉCISION

### 8.1 Résumé

**Limitation identifiée** :
- ❌ Les buckets Storage ne peuvent pas être créés via admin_execute_sql
- ❌ Les tests upload/lecture/suppression ne peuvent pas être effectués
- ❌ Les politiques Storage ne peuvent pas être créées (buckets non existants)

**Non-régression** :
- ✅ Aucun bucket existant modifié
- ✅ Aucun bucket Challenge modifié
- ✅ Aucun bucket Bobodo modifié

### 8.2 Décision

**PHASE B.4 À CORRIGER** ❌

**Justification** :
1. Les buckets whiteboard-narrations et whiteboard-renders n'existent pas
2. Les buckets ne peuvent pas être créés via admin_execute_sql (limitation d'architecture)
3. Les tests upload/lecture/suppression ne peuvent pas être effectués
4. Les politiques Storage ne peuvent pas être créées (buckets non existants)

**Action requise** :
Les buckets doivent être créés manuellement via Supabase CLI ou Dashboard Supabase avant de continuer avec Phase B.4.

**Commandes recommandées** :
```bash
supabase storage create buckets whiteboard-narrations
supabase storage create buckets whiteboard-renders
```

Une fois les buckets créés, Phase B.4 pourra être complétée avec la création des politiques Storage et les tests.

---

**Fin du document**
