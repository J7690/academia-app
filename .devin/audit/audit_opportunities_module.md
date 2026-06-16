# Audit du Module Opportunités - Academia App

**Date:** 2025-01-04  
**Statut:** Audit complet (lecture seule, aucune modification)

---

## 1. RÉSUMÉ EXÉCUTIF

Le module **Opportunités** est **entièrement fonctionnel** côté backend (Supabase) et frontend (Flutter). Il permet aux étudiants de consulter et postuler à des offres (stages, emplois, etc.) et aux admins de gérer ces opportunités.

| Composant | État | Détails |
|-----------|------|---------|
| Tables Supabase | ✅ Déployées | 3 tables dans schema `app` |
| Fonctions RPC | ✅ Déployées | 12 fonctions (11 métier + 1 trigger) |
| Policies RLS | ✅ Actives | 4 policies |
| Storage | ✅ Configuré | Bucket `application-files` (privé) |
| Flutter Admin | ✅ Complet | Écran + Provider |
| Flutter Étudiant | ✅ Complet | Onglet + Provider |

---

## 2. ARCHITECTURE SUPABASE

### 2.1 Tables (schema `app`)

#### `app.opportunities` - 21 colonnes
| Colonne | Type | Nullable | Default |
|---------|------|----------|---------|
| `id` | uuid | NO | `gen_random_uuid()` |
| `title` | text | NO | - |
| `short_description` | text | NO | - |
| `description` | text | YES | - |
| `type` | text | NO | - |
| `category` | text | YES | - |
| `organization_name` | text | NO | - |
| `organization_logo_url` | text | YES | - |
| `country` | text | NO | - |
| `city` | text | NO | - |
| `is_remote_possible` | boolean | NO | `false` |
| `contract_type` | text | YES | - |
| `duration_months` | integer | YES | - |
| `start_date` | date | YES | - |
| `application_deadline` | date | YES | - |
| `status` | text | NO | `'draft'` |
| `is_featured` | boolean | NO | `false` |
| `is_active` | boolean | NO | `true` |
| `created_by_user_id` | uuid | NO | - |
| `created_at` | timestamptz | NO | `now()` |
| `updated_at` | timestamptz | NO | `now()` |

#### `app.opportunity_applications` - 9 colonnes
| Colonne | Type | Nullable | Default |
|---------|------|----------|---------|
| `id` | uuid | NO | `gen_random_uuid()` |
| `opportunity_id` | uuid | NO | FK → opportunities |
| `student_id` | uuid | NO | FK → students |
| `message` | text | YES | - |
| `cv_url` | text | YES | - |
| `extra_data` | jsonb | YES | - |
| `status` | text | NO | `'submitted'` |
| `created_at` | timestamptz | NO | `now()` |
| `updated_at` | timestamptz | NO | `now()` |

#### `app.opportunity_types` - 7 colonnes
| Colonne | Type | Nullable | Default |
|---------|------|----------|---------|
| `id` | uuid | NO | `gen_random_uuid()` |
| `code` | text | NO | UNIQUE |
| `label` | text | NO | - |
| `sort_order` | integer | NO | `0` |
| `is_active` | boolean | NO | `true` |
| `created_at` | timestamptz | NO | `now()` |
| `updated_at` | timestamptz | NO | `now()` |

### 2.2 Fonctions RPC (schema `public`)

#### Fonctions Étudiant
| Fonction | Paramètres | Retour | Description |
|----------|------------|--------|-------------|
| `app_student_list_opportunities` | `p_type TEXT, p_search TEXT` | JSONB | Liste des opportunités publiées/actives avec filtres |
| `app_student_get_opportunity_detail` | `p_opportunity_id UUID` | JSONB | Détail d'une opportunité |
| `app_student_apply_for_opportunity` | `p_opportunity_id, p_message, p_cv_url, p_extra_data` | JSONB | Postuler (vérifie rôle student, doublon) |
| `app_student_list_my_opportunity_applications` | - | JSONB | Mes candidatures avec infos opportunité |
| `app_list_opportunity_types` | - | JSONB | Types actifs (public) |

#### Fonctions Admin
| Fonction | Paramètres | Retour | Description |
|----------|------------|--------|-------------|
| `app_admin_list_opportunities` | - | JSONB | Toutes les opportunités (vérifie rôle admin) |
| `app_admin_upsert_opportunity` | 18 params | JSONB | Créer/modifier une opportunité |
| `app_admin_update_opportunity_status` | `p_opportunity_id, p_status, p_is_featured, p_is_active` | JSONB | Mise à jour rapide statut |
| `app_admin_list_opportunity_applications` | `p_opportunity_id UUID` | JSONB | Candidatures pour une opportunité |
| `app_admin_list_opportunity_types` | - | JSONB | Tous les types (actifs + inactifs) |
| `app_admin_upsert_opportunity_type` | `p_type_id, p_code, p_label, p_sort_order, p_is_active` | JSONB | Créer/modifier un type |

#### Trigger
| Fonction | Type | Description |
|----------|------|-------------|
| `app_notify_opportunity_change` | trigger | Notifie lors de publication d'opportunité |

### 2.3 Policies RLS

| Table | Policy | Cmd | Condition |
|-------|--------|-----|-----------|
| `opportunities` | `public_select_published_opportunities` | SELECT | `is_active=true AND status='published' AND deadline>=today` |
| `opportunity_applications` | `student_select_own_opportunity_applications` | SELECT | `student_id = auth.uid()` |
| `opportunity_applications` | `student_insert_own_opportunity_applications` | INSERT | `student_id = auth.uid()` |
| `opportunity_types` | `public_select_active_opportunity_types` | SELECT | `is_active = true` |

### 2.4 Storage

| Bucket | Public | Policy |
|--------|--------|--------|
| `application-files` | ❌ Privé | `students_manage_own_application_files` (authenticated, ALL) |

**Chemin de stockage CV:** `{user_id}/opportunities/{opportunity_id}/{filename}`

---

## 3. ARCHITECTURE FLUTTER

### 3.1 Fichiers

```
academia_app/lib/
├── providers/
│   ├── student_opportunities_provider.dart   # Provider étudiant
│   └── admin_opportunities_provider.dart     # Provider admin
├── features/
│   ├── student/
│   │   ├── student_dashboard_screen.dart     # Dashboard avec onglet index=2
│   │   └── tabs/
│   │       └── student_opportunities_tab.dart # Onglet opportunités
│   └── admin/
│       └── admin_opportunities_screen.dart   # Écran admin complet
└── main.dart                                  # Providers enregistrés
```

### 3.2 StudentOpportunitiesProvider

**Fichier:** `@/academia_app/lib/providers/student_opportunities_provider.dart`

| Méthode | RPC appelée | Description |
|---------|-------------|-------------|
| `loadOpportunities(type, search)` | `app_student_list_opportunities` | Charge les opportunités avec filtres |
| `loadTypes()` | `app_list_opportunity_types` | Charge les types pour les filtres |
| `loadMyApplications()` | `app_student_list_my_opportunity_applications` | Mes candidatures |
| `applyForOpportunity(...)` | `app_student_apply_for_opportunity` | Postuler |
| `uploadCvFile(...)` | Storage API | Upload CV dans `application-files` |

**État:**
- `_opportunities: List<Map<String, dynamic>>`
- `_applications: List<Map<String, dynamic>>`
- `_types: List<Map<String, dynamic>>`
- `_isLoading: bool`
- `_error: String?`

### 3.3 AdminOpportunitiesProvider

**Fichier:** `@/academia_app/lib/providers/admin_opportunities_provider.dart`

| Méthode | RPC appelée | Description |
|---------|-------------|-------------|
| `loadOpportunities()` | `app_admin_list_opportunities` | Toutes les opportunités |
| `loadTypes()` | `app_admin_list_opportunity_types` | Tous les types |
| `upsertOpportunity(...)` | `app_admin_upsert_opportunity` | Créer/modifier |
| `updateOpportunityStatus(...)` | `app_admin_update_opportunity_status` | Mise à jour rapide |
| `loadApplicationsForOpportunity(id)` | `app_admin_list_opportunity_applications` | Candidatures |
| `upsertType(...)` | `app_admin_upsert_opportunity_type` | Gérer les types |
| `createCvSignedUrl(cvUrl)` | Storage API | URL signée pour voir CV |

### 3.4 Écrans

#### StudentOpportunitiesTab (index=2 dans dashboard)
- **Recherche:** Champ texte avec filtre sur titre, organisation, ville, pays
- **Filtres:** ChoiceChips par type d'opportunité
- **Affichage:** GridView responsive (1 col mobile, 2 cols desktop)
- **Actions:** Bouton "Postuler" → Dialog avec message + upload CV

#### AdminOpportunitiesScreen
- **Liste:** ListView avec Cards (titre, org, type, ville, statut, featured)
- **Actions par opportunité:**
  - Switch actif/inactif
  - Toggle featured (étoile)
  - Modifier (dialog complet)
  - Voir candidatures (dialog)
- **Gestion types:** Dialog accessible via icône catégorie dans AppBar
- **FAB:** Créer nouvelle opportunité

---

## 4. DONNÉES ACTUELLES

| Métrique | Valeur |
|----------|--------|
| Opportunités | 1 |
| Candidatures | 2 |
| Types | 1 |

### Opportunité existante
```json
{
  "id": "d4c9af3a-5f43-421e-811f-8bee360d8f09",
  "title": "stage a nexiom group",
  "organization_name": "nexiom group",
  "type": "internship",
  "city": "bobo",
  "country": "Burkina",
  "status": "published",
  "is_active": true,
  "is_featured": true
}
```

### Type existant
```json
{
  "id": "761e4086-e6d2-45f9-8861-2cf752a108e6",
  "code": "vendeur",
  "label": "emploi",
  "sort_order": 2,
  "is_active": true
}
```

---

## 5. FLUX UTILISATEUR

### Étudiant
```
Dashboard → Onglet "Opportunités" (index 2)
    ↓
StudentOpportunitiesTab
    ↓
loadOpportunities() + loadTypes()
    ↓
Affichage grille avec filtres
    ↓
Clic "Postuler" → Dialog
    ↓
[Optionnel] Upload CV → Storage
    ↓
applyForOpportunity() → RPC
    ↓
Confirmation SnackBar
```

### Admin
```
Admin Dashboard → Opportunités
    ↓
AdminOpportunitiesScreen
    ↓
loadOpportunities() + loadTypes()
    ↓
Liste avec actions
    ↓
Créer/Modifier → Dialog → upsertOpportunity()
Voir candidatures → Dialog → loadApplicationsForOpportunity()
Gérer types → Dialog → upsertType()
```

---

## 6. POINTS D'ATTENTION

### ✅ Points forts
1. **Architecture complète** - Tables, RPC, RLS, Storage bien structurés
2. **Sécurité** - Vérification des rôles dans chaque RPC admin
3. **Filtrage** - Recherche et filtres par type côté étudiant
4. **Upload CV** - Stockage sécurisé avec signed URLs

### ⚠️ Points à surveiller
1. **Type incohérent** - Le type existant a `code: "vendeur"` et `label: "emploi"` (inversé?)
2. **Pas de notification étudiant** - Pas de badge "nouveau" pour les opportunités dans le dashboard
3. **Pas de détail opportunité** - L'étudiant ne peut pas voir le détail complet avant de postuler
4. **Statut candidature** - Pas de gestion du statut des candidatures côté admin (accepted/rejected)

### 💡 Améliorations possibles
1. Ajouter un écran de détail opportunité pour l'étudiant
2. Permettre à l'admin de changer le statut des candidatures
3. Ajouter des notifications pour les nouvelles opportunités
4. Enrichir les types par défaut (Stage, Emploi, Bourse, Bénévolat, etc.)

---

## 7. FICHIERS DE RÉFÉRENCE

- **SQL Schema:** `.windsurf/supabase_opportunities.sql`
- **Audit JSON:** `.windsurf/logs/audit_opportunities_module.json`
- **Script audit:** `.windsurf/audit_opportunities_module.py`

---

*Audit réalisé automatiquement via Windsurf - Aucune modification effectuée*
