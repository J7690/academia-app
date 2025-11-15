# Academia – README & Plan d’action Windsurf

## 1. Vision globale de la plateforme

Academia est une plateforme multi-rôles construite avec **Flutter (front)** et **Supabase (backend BaaS)**, orchestrée par **Windsurf** qui applique automatiquement toutes les règles du dossier `.windsurf` (méthodes Supabase validées, procédures, sécurité, etc.).

Rôles principaux (à détailler au fur et à mesure) :
- **Student** : inscription, profil, inscription aux programmes, suivi de progression.
- **University** : gestion des formations, des cours, des enseignants, des étudiants.
- **Partner (entreprises, institutions)** : offres, partenariats, stages, projets.
- **Admin** : supervision globale, modération, configuration système.

Objectif : une base technique **propre, robuste, 100% pilotable par Windsurf**, où toute action Supabase passe par les méthodes validées (RPC + REST), sans SQL manuel.

---

## 2. Stack technique

### 2.1. Frontend
- **Framework** : Flutter 3.x
- **Langage** : Dart 3.x
- **Architecture** : 
  - Approche modulaire inspirée DDD : `features/` par contexte métier
  - `providers/` pour la logique de state management
  - `services/` pour l’accès Supabase via méthodes validées
  - `widgets/` pour la UI réutilisable
- **Navigation** : `go_router`
- **State management** : `provider`

### 2.2. Backend
- **BaaS** : Supabase
- **Base de données** : PostgreSQL (schéma `app` dédié à l’application)
- **API** :
  - RPC Postgres via `/rest/v1/rpc/...`
  - REST Supabase via `/rest/v1/{table}`
- **Sécurité** : RLS (Row Level Security) activée et pilotée par des policies
- **Storage** : buckets pour documents, images, etc. (à définir par rôle)

### 2.3. Orchestration Windsurf
- Dossier `.windsurf` = **source d’autorité** pour :
  - méthodes Supabase (RPC, REST, helpers Python)
  - procédures d’intervention
  - règles de sécurité et de coding
  - scripts d’audit / monitoring
- Windsurf **doit toujours** :
  - détecter les tâches Supabase
  - utiliser les méthodes validées (`auto_supabase_import`, RPC, etc.)
  - respecter les procédures du dossier `.windsurf`

---

## 3. Organisation du code (cible) – Flutter + DDD léger

Dans le projet Flutter principal (`academia_app/`) :

```text
lib/
  main.dart                  # Entrée Flutter, initialisation Supabase
  config/
    supabase_config.dart     # URL, clés, options Supabase (via système validé)
  core/
    routing/                 # Routes & navigation (go_router)
    theme/                   # Thème global
    widgets/                 # Widgets génériques (button, layout, etc.)
  features/
    auth/                    # Authentification & session
    student/                 # Fonctions spécifiques étudiant
    university/              # Fonctions spécifique université
    partner/                 # Fonctions spécifiques partenaires
    admin/                   # Panneau admin
  providers/
    supabase_provider.dart   # Accès consolidé Supabase via RPC + REST validés
  services/
    supabase_rpc_service.dart# Appels HTTP/RPC vers Supabase
  widgets/
    loading_widget.dart
    error_widget.dart
    data_table_widget.dart
  screens/
    home_screen.dart
    data_screen.dart
```

Cette structure sera enrichie **par rôle** au fur et à mesure des spécifications que tu me donneras.

---

## 4. Connexion Supabase (schéma `app`)

### 4.1. Configuration Flutter

Dans `lib/config/supabase_config.dart` (existant) :
- `SupabaseConfig.url` = URL de ton projet Supabase
- `SupabaseConfig.anonKey` = clé anonyme
- `SupabaseConfig.serviceKey` = clé service (uniquement côté backend / scripts sécurisés)

Dans `main.dart` :
- `Supabase.initialize(url: SupabaseConfig.url, anonKey: SupabaseConfig.anonKey)`
- Démarrage de l’app avec un widget racine (ici `AcademiaApp`).

### 4.2. Schéma `app` dans Supabase

Convention cible :
- Tout ce qui appartient à l’application : tables dans le schéma `app` (ex: `app.students`, `app.universities`, `app.courses`, etc.).
- Les fonctions RPC génériques peuvent rester dans `public`, mais toutes les tables métier restent dans `app`.

Cela sera détaillé **par rôle** :
- Student → tables `app.students`, `app.enrollments`, `app.progress`, etc.
- University → `app.universities`, `app.programs`, `app.courses`, `app.teachers`, etc.
- Partner → `app.partners`, `app.offers`, etc.
- Admin → tables de configuration / logs.

---

## 5. Bonnes pratiques RLS / RPC / Storage

### 5.1. RLS (Row Level Security)

- RLS **activé** sur toutes les tables exposées à l’extérieur.
- Policies dédiées **par rôle** :
  - `student` ne voit que ses propres données ou celles auxquelles il est inscrit.
  - `university` ne voit que les données de ses propres programmes / étudiants.
  - `partner` ne voit que ses offres, ses contrats.
  - `admin` a des accès élargis via un rôle spécial / clé service.
- Utilisation de `auth.uid()` dans les policies.

### 5.2. RPC

- Les fonctions RPC sont utilisées pour :
  - les opérations sensibles
  - les agrégations complexes
  - l’audit et le monitoring
- Exemple de fonctions déjà en place / validées :
  - `list_tables_detailed()`
  - `describe_table_detailed(p_table_name)`
  - `table_exists(p_table_name)`
  - `create_table_safe(p_table_name, p_table_definition)`

### 5.3. Storage

- Buckets définis **par usage** (à préciser plus tard) :
  - `app-students-files`
  - `app-universities-docs`
  - `app-partners-assets`
- Règles d’accès Storage alignées avec RLS.

---

## 6. Commandes CLI (Flutter & Supabase)

### 6.1. Côté Supabase

Initialisation / connexion locale (si utilisation Supabase CLI) :

```bash
# Depuis un terminal (hors Windsurf)
supabase login
supabase init
supabase link --project-ref <PROJECT_REF>

# Appliquer des migrations SQL
supabase db push
supabase db reset   # attention : destructive
```

Les scripts RPC / SQL structurants seront gérés dans `.windsurf` (déjà en cours) et/ou dans `supabase/migrations/` si on industrialise avec la CLI officielle.

### 6.2. Côté Flutter

Projet principal : `academia/academia_app`.

```bash
cd academia/academia_app

# Récupérer les dépendances
flutter pub get

# Lancer en debug (mobile / émulateur)
flutter run

# Lancer en web
flutter run -d chrome

# Analyse statique
flutter analyze

# Tests Flutter
flutter test
```

Pour Android (que l’on peut laisser pour plus tard comme tu l’as demandé) :

```bash
# (facultatif pour l’instant)
flutter build apk --debug
```

---

## 7. Plan d’action Windsurf – Backend d’abord

### Étape B1 – Vérification Supabase
- [x] Vérifier état du système via `.windsurf/auto_scheduler.py --once`.
- [x] Confirmer que les RPC génériques (`list_tables_detailed`, etc.) sont opérationnels.
- [x] Générer l’audit complet de la base (déjà fait).

### Étape B2 – Normaliser le schéma `app`
- [ ] Créer ou déplacer les tables métiers dans le schéma `app`.
- [ ] Définir le **noyau minimal** commun à tous les rôles :
  - `app.users` (profil global)
  - `app.roles` (student, university, partner, admin)
  - `app.user_roles` (association user ↔ rôle)
- [ ] Créer les tables spécifiques par rôle (sera fait avec tes specs détaillées).

### Étape B3 – RLS & Policies
- [ ] Activer RLS sur toutes les tables `app.*`.
- [ ] Créer des policies par rôle :
  - `policy_student_select_own_data`
  - `policy_university_manage_its_programs`
  - `policy_partner_manage_its_offers`
  - `policy_admin_full_access` (via rôle dédié ou service key)

### Étape B4 – RPC métiers
- [ ] Créer des RPC par contexte (student, university, partner, admin).
- [ ] Chaque RPC doit :
  - valider les entrées
  - respecter RLS
  - retourner un JSON clair
- [ ] Documenter chaque RPC dans `.windsurf` pour Windsurf.

---

## 8. Plan d’action Windsurf – Frontend Flutter

### Étape F1 – Squelette général
- [x] Projet Flutter `academia_app` créé.
- [x] Intégration de `supabase_flutter`.
- [x] Écrans de base :
  - `HomeScreen` (audit, overview tables)
  - `DataScreen` (CRUD générique)
- [x] Widgets de base : `LoadingWidget`, `CustomErrorWidget`, `DataTableWidget`.

### Étape F2 – Architecture par rôles
Pour chaque rôle (que tu détailleras ensuite), on fera :
- [ ] Dossier `features/<role>/` (ex: `features/student/`)
- [ ] Écrans dédiés : dashboard, listing, détails, formulaires
- [ ] Providers dédiés : logique métier + appels RPC/REST
- [ ] Intégration dans la navigation `go_router`

### Étape F3 – Authentification
- [ ] Écran de login + signup (email/password, éventuellement OAuth si tu le souhaites plus tard).
- [ ] Gestion de session via `supabase_flutter`.
- [ ] Redirection selon rôle :
  - Student → dashboard étudiant
  - University → dashboard établissement
  - Partner → dashboard partenaire
  - Admin → panel d’administration

### Étape F4 – UI & UX
- [ ] Thème global (couleurs, typographie, icônes)
- [ ] Composants réutilisables (boutons, cartes, listes, etc.)
- [ ] Gestion des erreurs et des états de chargement partout.

---

## 9. Checklist des livrables techniques

### Backend (Supabase)
- [ ] Schéma `app` structuré et documenté.
- [ ] Tables minimales : `users`, `roles`, `user_roles`.
- [ ] Tables par rôle (à définir avec toi).
- [ ] RLS activé + policies par rôle.
- [ ] RPCs génériques (OK) + RPCs métiers (à créer).
- [ ] Storage buckets définis + règles.
- [ ] Scripts d’audit et de monitoring (déjà en grande partie en place via `.windsurf`).

### Frontend (Flutter)
- [x] Projet Flutter fonctionnel (`academia_app`).
- [x] Connexion Supabase initialisée.
- [x] Appels via `SupabaseRPCService` + `SupabaseProvider`.
- [x] Écrans de démonstration (audit, CRUD générique).
- [ ] Modules par rôle avec UX adaptée.
- [ ] Auth complète.

### Windsurf / .windsurf
- [x] Système d’auto-import de méthodes Supabase.
- [x] Forçage des méthodes validées (RPC/API).
- [x] Tests d’intégration des méthodes (`test_windsurf_auto_methods.py`).
- [x] Rapports de conformité (`windsurf_compliance_report.json`, etc.).
- [ ] Documentation spécifique par rôle (à compléter avec tes détails).

---

## 10. Comment utiliser ce README avec Windsurf

1. Ouvrir le workspace `academia` dans Windsurf.
2. Charger ce fichier `Academia_Windsurf_README.md` comme **référence centrale**.
3. Lors d’une nouvelle tâche (ex : "Créer le module Student"), Windsurf doit :
   - lire le plan ici
   - respecter l’architecture proposée
   - n’utiliser que les méthodes Supabase validées
   - documenter ses actions dans `.windsurf` si nécessaire.
4. Toi, tu peux me donner **rôle par rôle** :
   - les champs, les règles métier, les écrans souhaités
   - et on étendra ce plan proprement.

---

## 11. Étape suivante proposée

Tu peux maintenant :
- soit me dire **par quel rôle tu veux commencer** (student, university, partner, admin),
- soit me donner directement les **champs / règles métier** pour le premier rôle (par exemple : Student : structure du profil, parcours, inscriptions, etc.).

Je m’occuperai ensuite :
- de définir les tables `app.*` correspondantes,
- de proposer les RPC,
- puis les écrans Flutter associés et le flux complet.
