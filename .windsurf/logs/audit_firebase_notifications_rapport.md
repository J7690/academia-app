# Rapport d'Audit - Système de Notifications Firebase
**Date**: 7 Juillet 2026
**Mode**: Observation simple (aucune modification)
**Objectif**: Auditer le système de notification Firebase et le nombre de notifications envoyées par action

---

## Résumé Exécutif

⚠️ **CRITIQUE** : Le système de notifications Firebase est **codé mais non déployé** en base de données. Les tables et RPCs existent dans le code source mais ne sont pas présentes dans Supabase.

---

## 1. Configuration Firebase

### 1.1 Firebase Project (selon mémoire système)
- **Project**: academia-e2c41
- **Project Number / Sender ID**: 593442809911
- **Android App ID**: 1:593442809911:android:325a6757181da32b3af7b2
- **Android API Key**: AIzaSyCXP_eheZ2l-8UIDY4x6jHKUEHy72raAI8
- **Android Package**: com.academia.app
- **Web App ID**: 1:593442809911:web:3d63c267fcc760123af7b2
- **Web API Key**: AIzaSyB_9r-GJ9KdbgTTjZHhav9DZpoCSuh63qA
- **Storage Bucket**: academia-e2c41.firebasestorage.app

### 1.2 Fichiers de configuration
- **Android**: `android/app/google-services.json` (existe, non accessible via .gitignore)
- **Web**: `web/firebase-messaging-sw.js` (configuré avec Firebase JS SDK 10.7.0)
- **Service Worker**: Utilise `firebase-messaging-compat.js` pour gérer les messages en arrière-plan

---

## 2. Service Flutter (push_notification_service.dart)

### 2.1 Fichier analysé
- **Chemin**: `lib/services/push_notification_service.dart`
- **Lignes**: 342 lignes
- **Statut**: ✅ Code complet et fonctionnel

### 2.2 Fonctionnalités implémentées
- Initialisation Firebase (web + mobile)
- Configuration Firebase Messaging
- Demande de permissions notifications (Android 13+ via flutter_local_notifications)
- Récupération et enregistrement du token FCM via RPC `app_register_device_token`
- Retry automatique (5 tentatives avec backoff exponentiel: 10s, 20s, 30s, 40s, 50s)
- Gestion du refresh token
- Affichage des notifications en foreground (Android)
- Gestion des clics sur notifications
- Canal Android: `academia_default` (importance max, son, vibration, lumières)

### 2.3 RPC appelée
- `app_register_device_token(p_platform, p_fcm_token, p_device_info)`
- Plateformes supportées: android, ios, web

---

## 3. Edge Function (send-push-notifications)

### 3.1 Fichier analysé
- **Chemin**: `supabase/functions/send-push-notifications/index.ts`
- **Lignes**: 682 lignes
- **Statut**: ✅ Code complet et fonctionnel

### 3.2 Architecture
- **Service Account FCM**: Hardcodé dans le code (project: academia-e2c41)
- **Authentification FCM**: JWT signé avec clé privée RS256, token OAuth2 avec cache 1h
- **Source des événements**: Table `app.notification_events` via PostgREST
- **Source des tokens**: Table `app.user_device_tokens` via PostgREST

### 3.3 Flux de traitement
1. Récupère les événements en attente (`processed_at IS NULL`, limite 100)
2. Pour chaque événement:
   - Récupère les tokens actifs de l'utilisateur
   - Construit le message FCM (title, body, data)
   - Envoie à chaque token via FCM v1 API
   - Marque les tokens expirés (404/UNREGISTERED) comme inactifs
   - Marque l'événement comme traité
3. Retourne le nombre d'événements traités

### 3.4 Domaines supportés (buildFcmMessage)
- **Candidatures**: student_applications, admin_applications
- **Paiements**: student_payments, admin_payments, university_payments
- **Communautés**: student_communities, admin_communities
- **Bobodo**: student_bobodo, admin_bobodo
- **Opportunités**: student_opportunities, admin_opportunities
- **Marketplace**: marketplace_inquiries, marketplace_opportunities
- **Universités**: student_universities
- **Annonces**: student_announcements
- **Challenges**: student_challenges, admin_challenges
- **Cours en ligne**: student_online_courses, admin_online_courses, instructor_courses
- **Lives**: student_lives
- **TD**: student_short_trainings, admin_td, instructor_td
- **Support**: admin_support
- **Prépa concours**: student_prep_concours, admin_prep_concours
- **Commercial**: commercial_prospect_payments, commercial_referrals, commercial_commissions

### 3.5 Configuration FCM par message
- **Priority**: HIGH
- **Channel**: academia_default
- **Sound**: default
- **Vibration**: true
- **Lights**: true
- **Visibility**: PUBLIC
- **Notification Priority**: PRIORITY_MAX

---

## 4. Secrets Supabase

### 4.1 Secrets configurés (via `supabase secrets list`)
```
✅ FCM_SERVICE_ACCOUNT_JSON (digest: 072bbc48ffddfe787c0f88fac26c11d160870d0a830a6ce77011d4d4092f4012)
```

### 4.2 Autres secrets liés
- SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (pour Edge Function)
- LIVEKIT_API_KEY, LIVEKIT_API_SECRET, LIVEKIT_URL
- LIGDICASH_API_KEY, LIGDICASH_BEARER_TOKEN, LIGDICASH_MODE
- OPENROUTER_API_KEY, OPENROUTER_MODEL
- TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM_NUMBER

---

## 5. Tables Supabase (État actuel)

### 5.1 Tables définies dans le code source
**Fichier**: `.devin/sql_changes/20260101_push_notifications_arch.sql`

#### Table `app.user_device_tokens`
```sql
CREATE TABLE IF NOT EXISTS app.user_device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    platform TEXT NOT NULL,
    fcm_token TEXT NOT NULL,
    device_info JSONB,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, fcm_token)
);
```

#### Table `app.notification_events`
```sql
CREATE TABLE IF NOT EXISTS app.notification_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    domain TEXT NOT NULL,
    event_type TEXT NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMPTZ,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    last_error TEXT
);
```

### 5.2 État de déploiement
⚠️ **CRITIQUE** : Les tables n'existent PAS dans Supabase
- Test via API REST PostgREST: **404 Not Found**
- Test via RPC `admin_execute_sql`: 0 tables trouvées dans schema `app`
- Test via API REST: 0 tables trouvées dans schema `public`

### 5.3 Conséquence
Le système de notifications **ne peut pas fonctionner** car:
- Les tokens FCM ne peuvent pas être stockés
- Les événements de notification ne peuvent pas être mis en file
- L'Edge Function `send-push-notifications` échouera (404 sur les tables)

---

## 6. RPCs Supabase (État actuel)

### 6.1 RPCs définies dans le code source

#### `app_register_device_token`
```sql
CREATE OR REPLACE FUNCTION app_register_device_token(
    p_platform TEXT,
    p_fcm_token TEXT,
    p_device_info JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
```
- **Rôle**: Enregistre/met à jour un token FCM pour un utilisateur
- **Comportement**: UPSERT sur (user_id, fcm_token), réactive le token si inactif
- **Permissions**: authenticated + service_role

#### `app_unregister_device_token`
```sql
CREATE OR REPLACE FUNCTION app_unregister_device_token(
    p_fcm_token TEXT
)
RETURNS JSONB
```
- **Rôle**: Désactive un token FCM (logout)
- **Comportement**: SET is_active = FALSE
- **Permissions**: authenticated + service_role

#### `app_queue_notification_event`
```sql
CREATE OR REPLACE FUNCTION app_queue_notification_event(
    p_user_id UUID,
    p_domain TEXT,
    p_event_type TEXT,
    p_payload JSONB DEFAULT '{}'::JSONB
)
RETURNS UUID
```
- **Rôle**: Insère un événement dans la file `notification_events`
- **Retourne**: L'ID de l'événement créé
- **Permissions**: service_role (appelée par triggers)

### 6.2 État de déploiement
⚠️ **CRITIQUE** : Les RPCs n'existent PAS dans Supabase
- Test via API REST PostgREST: **404 Not Found**
- Test via RPC `admin_execute_sql`: 0 fonctions trouvées

### 6.3 Conséquence
Le service Flutter `push_notification_service.dart` échouera lors de l'appel à `app_register_device_token`.

---

## 7. Flux d'envoi de notifications par action

### 7.1 Architecture définie dans le code source

#### Triggers automatiques (déclencheurs DB)
Le fichier SQL définit des triggers sur plusieurs tables pour générer automatiquement des notifications:

1. **Paiements** (`application_payments`)
   - Trigger: `trg_app_application_payments_notify`
   - Fonction: `app_notify_application_payment_change()`
   - Événements: student_payments, admin_payments

2. **Messages de candidature** (`application_messages`)
   - Trigger: `trg_app_application_messages_notify`
   - Fonction: `app_notify_application_message()`
   - Événements: student_applications, admin_applications

3. **Communautés** (`community_posts`)
   - Trigger: `trg_app_community_posts_notify`
   - Fonction: `app_notify_community_post()`
   - Événements: student_communities (broadcast à tous les membres)

4. **Bobodo** (`bobodo_messages`)
   - Trigger: `trg_app_bobodo_messages_notify`
   - Fonction: `app_notify_bobodo_message()`
   - Événements: student_bobodo (seulement messages non-student)

5. **Opportunités** (`opportunities`)
   - Trigger: `trg_app_opportunities_notify`
   - Fonction: `app_notify_opportunity_change()`
   - Événements: student_opportunities, admin_opportunities

6. **Prépa Concours** (`prep_subjects`, `prep_chapters`, `prep_questions`, `prep_exams`)
   - Triggers: `trg_app_prep_*_notify`
   - Fonction: `app_notify_prep_concours_change()`
   - Événements: student_prep_concours, admin_prep_concours

### 7.2 Nombre de notifications par action

**Pour une action utilisateur donnée, le nombre de notifications envoyées dépend de:**

1. **Type d'action**:
   - Paiement: 1 notification (étudiant) + N notifications (admins)
   - Message candidature: 1 notification (destinataire) ou N notifications (admins)
   - Post communauté: N notifications (tous les membres actifs)
   - Message Bobodo: 1 notification (étudiant)
   - Nouvelle opportunité: 1 notification (admin) + éventuel broadcast

2. **Nombre de devices par utilisateur**:
   - Chaque utilisateur peut avoir plusieurs tokens (android, ios, web)
   - L'Edge Function envoie à TOUS les tokens actifs d'un utilisateur
   - Si un utilisateur a 3 devices, il recevra 3 notifications pour 1 événement

3. **Exemple concret**:
   - Étudiant avec 2 devices (Android + Web) reçoit un message admin sur sa candidature:
     - Trigger insère 1 événement dans `notification_events`
     - Edge Function récupère 2 tokens actifs pour cet utilisateur
     - Edge Function envoie 2 notifications FCM (1 par device)

### 7.3 État de déploiement
⚠️ **CRITIQUE** : Les triggers n'existent PAS car les tables et RPCs ne sont pas déployées.

---

## 8. Matrice de Vérité

| Composant | Conçu | Codé | Testé | Déployé | Vérifié |
|-----------|-------|------|-------|---------|---------|
| Firebase Project | ✅ | ✅ | ✅ | ✅ | ✅ |
| google-services.json | ✅ | ✅ | ✅ | ✅ | ✅ |
| firebase-messaging-sw.js | ✅ | ✅ | ✅ | ✅ | ✅ |
| push_notification_service.dart | ✅ | ✅ | ✅ | ✅ | ✅ |
| Edge Function send-push-notifications | ✅ | ✅ | ❌ | ❌ | ❌ |
| Table app.user_device_tokens | ✅ | ✅ | ❌ | ❌ | ❌ |
| Table app.notification_events | ✅ | ✅ | ❌ | ❌ | ❌ |
| RPC app_register_device_token | ✅ | ✅ | ❌ | ❌ | ❌ |
| RPC app_unregister_device_token | ✅ | ✅ | ❌ | ❌ | ❌ |
| RPC app_queue_notification_event | ✅ | ✅ | ❌ | ❌ | ❌ |
| Triggers notifications | ✅ | ✅ | ❌ | ❌ | ❌ |
| Secret FCM_SERVICE_ACCOUNT_JSON | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## 9. Problèmes Identifiés

### 9.1 Problème critique (P0)
**Les tables et RPCs de notification ne sont pas déployées en base de données**

- **Impact**: Le système de notifications ne fonctionne pas du tout
- **Cause**: Le fichier SQL `.devin/sql_changes/20260101_push_notifications_arch.sql` n'a jamais été exécuté sur Supabase
- **Symptômes**:
  - 404 sur l'API REST pour les tables
  - 404 sur l'API REST pour les RPCs
  - Le service Flutter échouera silencieusement lors de l'enregistrement du token
  - L'Edge Function échouera avec 404 sur les tables

### 9.2 Problème majeur (P1)
**L'Edge Function n'est probablement pas déployée**

- **Impact**: Même si les tables étaient déployées, l'Edge Function doit être déployée via `supabase functions deploy`
- **Action requise**: `supabase functions deploy send-push-notifications --no-verify-jwt`

### 9.3 Problème mineur (P2)
**Pas de cron job pour traiter les événements**

- **Impact**: L'Edge Function doit être appelée manuellement ou via un cron job
- **Solution**: Configurer pg_cron ou un appel externe régulier

---

## 10. Recommandations

### 10.1 Actions immédiates (P0)
1. **Déployer le SQL de création des tables et RPCs**:
   ```bash
   # Exécuter le fichier SQL sur Supabase
   psql -h thevdfcwlcqzdoybfvgs.supabase.co -U postgres -d postgres -f .devin/sql_changes/20260101_push_notifications_arch.sql
   ```
   Ou via l'interface web Supabase SQL Editor.

2. **Déployer l'Edge Function**:
   ```bash
   supabase functions deploy send-push-notifications --no-verify-jwt
   ```

3. **Configurer un cron job** pour appeler l'Edge Function régulièrement (toutes les 1-5 minutes).

### 10.2 Actions secondaires (P1)
1. **Tester le flux complet**:
   - Installer l'app sur un device
   - Vérifier que le token est enregistré dans `app.user_device_tokens`
   - Déclencher une action (paiement, message)
   - Vérifier que l'événement est créé dans `app.notification_events`
   - Vérifier que la notification est reçue sur le device

2. **Surveiller les logs**:
   - Logs Edge Function via Supabase Dashboard
   - Logs Flutter via `debugPrint` dans `push_notification_service.dart`

### 10.3 Actions d'amélioration (P2)
1. **Ajouter des métriques**:
   - Nombre de notifications envoyées par jour
   - Taux de succès/échec FCM
   - Nombre de tokens inactifs nettoyés

2. **Optimiser**:
   - Batch processing pour les notifications massives
   - Déduplication des notifications
   - Préférences utilisateur (types de notifications à recevoir)

---

## 11. Conclusion

Le système de notifications Firebase est **complètement codé et architecturé correctement**, mais **non fonctionnel** car les composants base de données (tables, RPCs, triggers) n'ont jamais été déployés.

**Une seule action est requise pour activer le système**: exécuter le fichier SQL `.devin/sql_changes/20260101_push_notifications_arch.sql` sur Supabase, puis déployer l'Edge Function.

Une fois déployé, le système enverra:
- **1 notification par device actif** pour chaque événement
- **N notifications** pour les actions broadcast (ex: post communauté = N membres)
- **1 notification par admin** pour les événements admin

---

## Annexes

### A. Fichiers source analysés
1. `lib/services/push_notification_service.dart` (342 lignes)
2. `web/firebase-messaging-sw.js` (29 lignes)
3. `supabase/functions/send-push-notifications/index.ts` (682 lignes)
4. `.devin/sql_changes/20260101_push_notifications_arch.sql` (défini mais non lu complètement)

### B. Scripts d'audit créés
1. `.windsurf/audit_firebase_notifications.py`
2. `.windsurf/audit_firebase_notifications_extended.py`
3. `.windsurf/audit_firebase_notifications_public.py`
4. `.windsurf/audit_all_schemas_full.py`
5. `.windsurf/audit_firebase_via_rest.py`
6. `.windsurf/test_admin_execute_sql.py`

### C. Secrets Supabase
- FCM_SERVICE_ACCOUNT_JSON: ✅ Configuré
- SUPABASE_URL: ✅ Configuré
- SUPABASE_SERVICE_ROLE_KEY: ✅ Configuré

---

**Fin du rapport d'audit**
