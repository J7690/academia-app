# Academia — Data Safety Inventory

> Document de référence pour remplir Google Play Data Safety et Apple App Privacy Details.
> Généré le 2026-03-16 à partir de l'audit du code source et de la base Supabase.

---

## 1. Données collectées par l'application

### 1.1 Informations personnelles (saisies par l'utilisateur)

| Donnée | Obligatoire | Table Supabase | Usage |
|--------|------------|----------------|-------|
| Nom complet | Oui | `app.students.full_name` | Identification, dossier universitaire |
| Email | Oui | `auth.users.email` | Authentification, communication |
| Mot de passe | Oui | `auth.users.encrypted_password` | Authentification (hashé, jamais stocké en clair) |
| Téléphone | Non | `app.students.phone` | Contact optionnel |
| Date de naissance | Non | `app.students.date_of_birth` | Dossier universitaire |
| Pays | Non | `app.students.country` | Personnalisation, dossier |
| Ville | Non | `app.students.city` | Personnalisation, dossier |
| Bio | Non | `app.students.bio` | Profil social |
| Photo de profil | Non | `app.students.avatar_url` → bucket `community-media` | Profil social |
| Site web | Non | `app.students.website_url` | Profil social |

### 1.2 Données académiques

| Donnée | Table | Usage |
|--------|-------|-------|
| Année/mention/établissement BEPC | `app.students.bepc_*` | Dossier universitaire |
| Année/série/mention/établissement BAC | `app.students.bac_*` | Dossier universitaire |
| Projet d'études | `app.students.study_project_text` | Dossier universitaire |
| Documents de dossier (CV, relevés, diplômes) | `app.student_dossier_documents` → bucket `application-files` | Candidature universitaire |
| Fichiers de candidature | `app.application_files` → bucket `application-files` | Candidature universitaire |

### 1.3 Données de communication

| Donnée | Table | Usage |
|--------|-------|-------|
| Messages communautaires | `app.community_posts` | Chat communautaire |
| Messages privés (DM) | `app.direct_messages` | Messagerie directe |
| Messages support | `app.support_messages` | Support client |
| Messages candidature | `app.application_messages` | Suivi candidature |
| Conversations IA (Bobodo) | `app.bobodo_messages` | Assistant IA |

### 1.4 Contenus générés par l'utilisateur

| Donnée | Table | Usage |
|--------|-------|-------|
| Vidéos (challenges) | `app.challenge_participations` → bucket `challenge-media`, `video-assets` | Création de contenu |
| Stories | `app.community_stories` → bucket `community-media` | Partage social |
| Commentaires vidéo | `app.video_comments`, `app.challenge_comments` | Interaction sociale |
| Réactions / likes | `app.video_likes`, `app.challenge_likes`, `app.community_post_reactions` | Interaction sociale |

### 1.5 Données d'activité et progression

| Donnée | Table | Usage |
|--------|-------|-------|
| Progression quiz/examens | `app.prep_quiz_attempts`, `app.prep_student_progress` | Suivi pédagogique |
| Résultats psychotechniques | `app.prep_psychotech_results` | Préparation concours |
| Inscriptions cours en ligne | `app.online_course_enrollments` | Suivi formation |
| Progression leçons | `app.online_course_lesson_progress` | Suivi formation |
| Inscriptions formations courtes | `app.short_training_registrations` | Gestion formations |
| Commandes marketplace | `app.marketplace_orders` | E-commerce |
| Candidatures opportunités | `app.opportunity_applications` | Emploi/stages |

### 1.6 Données techniques

| Donnée | Table/Mécanisme | Usage |
|--------|----------------|-------|
| FCM Device Token | `app.user_device_tokens` | Notifications push |
| Fuseau horaire | `app.students.timezone` | Personnalisation horaires |
| Géolocalisation (lat/lon) | `app.students.geo_latitude/longitude` | Météo locale (optionnel) |
| Présence en ligne | `app.user_presence` | Indicateur online communautés |
| Activité utilisateur | RPC `app_track_user_activity` | Détection inactivité |

---

## 2. SDK tiers et leurs pratiques de données

### 2.1 Firebase (Google)

| SDK | Version | Données | Partage |
|-----|---------|---------|---------|
| `firebase_core` | ^4.5.0 | Identifiant d'installation | Non partagé |
| `firebase_messaging` | ^16.1.2 | FCM token, données de message | Non partagé (infrastructure) |
| `firebase_analytics` | ^12.1.3 | Événements d'usage, identifiant appareil | Google Analytics (déclaré) |
| `firebase_crashlytics` | ^5.0.8 | **Non activé** (code commenté) | — |

### 2.2 Publicité

| SDK | Version | Données | Statut |
|-----|---------|---------|--------|
| `google_mobile_ads` | ^5.1.0 | ID publicitaire, données d'interaction | **Test ID uniquement** (`ca-app-pub-3940256099942544`) — pas de publicité réelle en production |

### 2.3 Monitoring

| SDK | Version | Données | Statut |
|-----|---------|---------|--------|
| `sentry_flutter` | ^8.8.0 | **Non activé** (code commenté) | — |

### 2.4 Achats intégrés

| SDK | Version | Données | Statut |
|-----|---------|---------|--------|
| `in_app_purchase` | ^3.1.9 | Historique achats | **Déclaré mais non intégré en production** |

### 2.5 Infrastructure (non tiers au sens stores)

| Service | Rôle | Données transitant |
|---------|------|-------------------|
| Supabase | BaaS (auth, DB, storage, realtime) | Toutes les données applicatives |
| Supabase Edge Functions | Serverless functions | Requêtes IA, notifications |

### 2.6 Autres SDK

| SDK | Données |
|-----|---------|
| `shared_preferences` | Préférences locales uniquement (pas de PII) |
| `hive` / `sqflite` | Cache local (pas de PII) |
| `flutter_secure_storage` | Stockage sécurisé local |
| `device_info_plus` | Info appareil (modèle, OS) pour debug |
| `connectivity_plus` | État réseau (pas de données) |
| `url_launcher` | Ouverture URLs (pas de données) |
| `share_plus` | Partage natif (pas de données collectées) |

---

## 3. Permissions Android

| Permission | Raison |
|-----------|--------|
| `INTERNET` | Accès réseau (obligatoire) |
| `RECORD_AUDIO` | Enregistrement messages vocaux communautés |
| `READ_MEDIA_VIDEO` / `READ_MEDIA_IMAGES` | Sélection fichiers galerie |
| `WRITE_EXTERNAL_STORAGE` (≤28) | Sauvegarde vidéos galerie |
| `POST_NOTIFICATIONS` | Notifications push |
| `RECEIVE_BOOT_COMPLETED` | Redémarrage service FCM |
| `VIBRATE` | Vibration notifications |
| `WAKE_LOCK` | Maintien service FCM |
| `FOREGROUND_SERVICE` | Service FCM arrière-plan |
| `ACCESS_NETWORK_STATE` | Vérification connectivité |
| `CAMERA` | Capture vidéo (challenges) |

---

## 4. Réponses Google Play Data Safety

### Data types collected

| Category | Data type | Collected | Shared | Purpose |
|----------|-----------|-----------|--------|---------|
| **Personal info** | Name | Yes | No | App functionality |
| **Personal info** | Email address | Yes | No | App functionality, Account management |
| **Personal info** | Phone number | Optional | No | App functionality |
| **Personal info** | Date of birth | Optional | No | App functionality |
| **Personal info** | Address (city, country) | Optional | No | App functionality |
| **Photos & videos** | Photos | Optional | No | App functionality (profile, stories) |
| **Photos & videos** | Videos | Optional | No | App functionality (challenges) |
| **Files & docs** | Files & docs | Optional | No | App functionality (academic documents) |
| **Messages** | In-app messages | Yes | No | App functionality |
| **App activity** | App interactions | Yes | No | Analytics, App functionality |
| **Device info** | Device identifiers | Yes | No | App functionality (push notifications) |
| **Location** | Approximate location | Optional | No | App functionality (weather) |

### Data deletion

- **Can users request data deletion?** Yes
- **In-app deletion path:** Profile > Paramètres > Supprimer mon compte
- **Web deletion URL:** https://nexiomgroup.space/delete-account
- **Deletion timeframe:** Up to 60 days for complete data purge
- **Data retained after deletion:** Anonymized transaction records for legal/accounting purposes

### Security

- **Data encrypted in transit?** Yes (HTTPS/TLS)
- **Data encrypted at rest?** Yes (Supabase infrastructure)
- **Can users request data export?** Contact support (contact@nexiomgroup.space)

---

## 5. Réponses Apple App Privacy Details

### Data Linked to You

| Data type | Linked to identity | Used for tracking |
|-----------|-------------------|-------------------|
| Name | Yes | No |
| Email Address | Yes | No |
| Phone Number | Yes | No |
| Photos or Videos | Yes | No |
| User Content (messages, posts) | Yes | No |
| Identifiers (device ID) | Yes | No |
| Usage Data | Yes | No |

### Data Not Linked to You

| Data type | Purpose |
|-----------|---------|
| Diagnostics | App functionality |
| Coarse Location | App functionality |

### Data Used to Track You

**None.** L'application n'utilise pas de données pour le suivi publicitaire inter-applications.

---

## 6. Checklist Play Console

- [x] Privacy Policy URL: `https://nexiomgroup.space/privacy`
- [x] Data safety form: remplir selon section 4 ci-dessus
- [x] Data deletion: chemin in-app + URL web
- [x] App content rating: à remplir (éducation)
- [x] Target audience: 16+ (pas de contenu enfants)

## 7. Checklist App Store Connect

- [x] Privacy Policy URL: `https://nexiomgroup.space/privacy`
- [x] App Privacy Details: remplir selon section 5 ci-dessus
- [x] Account deletion: conforme (in-app + web)
- [x] Age rating: 12+ ou 17+ selon contenu
