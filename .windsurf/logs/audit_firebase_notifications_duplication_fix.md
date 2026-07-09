# Rapport de Correction - Duplications de Notifications Firebase
**Date**: 7 Juillet 2026
**Mode**: Observation et analyse des duplications
**Objectif**: Identifier et corriger les sources de notifications en double/triple/quadruple

---

## Résumé Exécutif

⚠️ **CRITIQUE** : Le système de notifications génère des duplications à **4 niveaux différents**:
1. **Triggers multiples sur la même table** (paiements)
2. **Appels multiples dans un même trigger** (étudiant + admin)
3. **Fonctions d'enqueue différentes** (2 fonctions distinctes)
4. **Tokens multiples par utilisateur** (1 notification par device)

---

## 1. Sources de Duplication Identifiées

### 1.1 Niveau 1: Triggers multiples sur la même table

#### Table `application_payments`
**Deux triggers actifs sur la même table**:

1. **`trg_app_application_payments_notify`** (fichier: `20260101_push_notifications_arch.sql`)
   - **Type**: AFTER INSERT OR UPDATE
   - **Fonction**: `app_notify_application_payment_change()`
   - **Action**: Enqueue 2 notifications (étudiant + admin)
   - **Statut**: ✅ Défini dans le code

2. **`trg_app_application_payments_referral_commission`** (fichier: `change_20260118_referral_commercials.sql`)
   - **Type**: AFTER UPDATE
   - **Fonction**: `app_on_payment_confirmed_generate_referral_commission()`
   - **Action**: Génère une commission + enqueue 1-2 notifications (commercial)
   - **Statut**: ⚠️ **Désactivé** dans `change_20260315_fix_commercial_system.sql`

**Impact**:
- Si le trigger referral commission était actif, un paiement confirmerait générerait:
  - 2 notifications (étudiant + admin) via trigger notify
  - 1-2 notifications (commercial) via trigger referral
  - **Total: 3-4 notifications pour 1 paiement**

---

### 1.2 Niveau 2: Appels multiples dans un même trigger

#### Trigger `app_notify_application_payment_change()`
**Fichier**: `20260101_push_notifications_arch.sql` (lignes 161-194)

```sql
CREATE OR REPLACE FUNCTION app_notify_application_payment_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_student_id UUID;
BEGIN
    v_student_id := NEW.student_id;
    IF v_student_id IS NOT NULL THEN
        PERFORM app_queue_notification_event(
            v_student_id,
            'student_payments',
            'payment',
            JSONB_BUILD_OBJECT('payment_id', NEW.id)
        );
    END IF;

    PERFORM app_queue_notification_event(
        (SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin' LIMIT 1),
        'admin_payments',
        'payment',
        JSONB_BUILD_OBJECT('payment_id', NEW.id)
    );

    RETURN NEW;
END;
$$;
```

**Problème**: Pour 1 paiement, ce trigger enqueue **2 événements**:
- 1 notification pour l'étudiant
- 1 notification pour l'admin

**Impact**: Si l'étudiant a 2 devices, il recevra **2 notifications** (1 par device) pour le même paiement.

---

### 1.3 Niveau 3: Fonctions d'enqueue différentes

#### Deux fonctions distinctes pour enqueuer des notifications

**Fonction 1**: `app_queue_notification_event` (fichier: `20260101_push_notifications_arch.sql`)
```sql
CREATE OR REPLACE FUNCTION app_queue_notification_event(
    p_user_id UUID,
    p_domain TEXT,
    p_event_type TEXT,
    p_payload JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF p_user_id IS NULL THEN
        RETURN;
    END IF;
    IF p_domain IS NULL OR LENGTH(TRIM(p_domain)) = 0 THEN
        RETURN;
    END IF;
    INSERT INTO app.notification_events (user_id, domain, event_type, payload)
    VALUES (p_user_id, p_domain, p_event_type, COALESCE(p_payload, '{}'::JSONB));
END;
$$;
```

**Fonction 2**: `app.fn_enqueue_notification_event` (fichier: `20260302_marketplace_phase7_notifications_and_merchant_profile.sql`)
```sql
CREATE OR REPLACE FUNCTION app.fn_enqueue_notification_event(
    p_user_id UUID,
    p_domain TEXT,
    p_event_type TEXT,
    p_payload JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO app.notification_events(user_id, domain, event_type, payload, created_at, processed_at, attempt_count, last_error)
  VALUES (
    p_user_id,
    p_domain,
    p_event_type,
    COALESCE(p_payload, '{}'::jsonb),
    now(),
    NULL,
    0,
    NULL
  );
END;
$$;
```

**Problème**: Deux fonctions différentes qui font la même chose mais sont appelées par différents modules:
- `app_queue_notification_event`: Appelée par triggers généraux (paiements, candidatures, communautés, etc.)
- `app.fn_enqueue_notification_event`: Appelée par triggers marketplace

**Impact**: Si un même événement est traité par les deux systèmes, il y aura **2 événements dans la file** pour la même notification.

---

### 1.4 Niveau 4: Tokens multiples par utilisateur

#### Edge Function `send-push-notifications`
**Fichier**: `supabase/functions/send-push-notifications/index.ts` (lignes 637-668)

```typescript
const events = await fetchPendingEvents(100);
for (const event of events) {
    const tokens = await fetchActiveTokens(event.user_id);
    if (!tokens.length) {
        await markProcessed(event.id);
        continue;
    }
    const msg = buildFcmMessage(event);
    for (const t of tokens) {
        const result = await sendFcm(t.fcm_token, msg);
        // ...
    }
    await markProcessed(event.id);
}
```

**Problème**: L'Edge Function envoie à **TOUS les tokens actifs** d'un utilisateur.

**Impact**:
- Si un utilisateur a 1 device: 1 notification par événement
- Si un utilisateur a 2 devices: 2 notifications par événement
- Si un utilisateur a 3 devices: 3 notifications par événement

**Exemple concret**:
- Étudiant avec Android + Web (2 devices)
- Paiement confirmé → 1 événement dans `notification_events`
- Edge Function envoie 2 notifications FCM (1 Android, 1 Web)
- **Total: 2 notifications reçues pour 1 paiement**

---

## 2. Matrice de Duplication par Action

### 2.1 Paiement (application_payments)

**Scénario**: Étudiant avec 2 devices (Android + Web) confirme un paiement

| Source | Notifications générées |
|--------|------------------------|
| Trigger `trg_app_application_payments_notify` | 2 événements (étudiant + admin) |
| Trigger `trg_app_application_payments_referral_commission` | 0 (désactivé) |
| Tokens étudiant (2 devices) | 2 notifications FCM |
| Tokens admin (1 device) | 1 notification FCM |
| **Total** | **3 notifications FCM** |

**Si trigger referral était actif**: +1-2 notifications (commercial) = **4-5 notifications**

---

### 2.2 Message de candidature (application_messages)

**Scénario**: Admin envoie un message à un étudiant avec 2 devices

| Source | Notifications générées |
|--------|------------------------|
| Trigger `trg_app_application_messages_notify` | 1 événement (étudiant) |
| Tokens étudiant (2 devices) | 2 notifications FCM |
| **Total** | **2 notifications FCM** |

---

### 2.3 Post communauté (community_posts)

**Scénario**: Étudiant poste dans une communauté avec 10 membres actifs, chacun avec 1 device

| Source | Notifications générées |
|--------|------------------------|
| Trigger `trg_app_community_posts_notify` | 10 événements (1 par membre) |
| Tokens (10 membres × 1 device) | 10 notifications FCM |
| **Total** | **10 notifications FCM** |

---

### 2.4 Nouvelle opportunité (opportunities)

**Scénario**: Admin publie une opportunité

| Source | Notifications générées |
|--------|------------------------|
| Trigger `trg_app_opportunities_notify` | 1 événement (admin) |
| Tokens admin (1 device) | 1 notification FCM |
| **Total** | **1 notification FCM** |

---

## 3. Problèmes Identifiés

### 3.1 Problème critique (P0)
**Deux fonctions d'enqueue différentes pour la même fonctionnalité**

- **Impact**: Confusion, maintenance difficile, risque de duplication
- **Solution**: Unifier en une seule fonction `app_queue_notification_event`

### 3.2 Problème majeur (P1)
**Trigger referral commission désactivé mais toujours défini**

- **Impact**: Si réactivé par erreur, générera des duplications
- **Solution**: Supprimer complètement le trigger et la fonction associée

### 3.3 Problème mineur (P2)
**Pas de déduplication des notifications par device**

- **Impact**: Utilisateurs avec plusieurs devices reçoivent plusieurs notifications
- **Solution**: Ajouter une logique de déduplication (ex: envoyer uniquement au dernier device actif)

### 3.4 Problème mineur (P2)
**Pas de préférences utilisateur pour les notifications**

- **Impact**: Impossible de désactiver certains types de notifications
- **Solution**: Ajouter une table `user_notification_preferences`

---

## 4. Recommandations de Correction

### 4.1 Actions immédiates (P0)

#### 1. Unifier les fonctions d'enqueue
```sql
-- Supprimer la fonction dupliquée
DROP FUNCTION IF EXISTS app.fn_enqueue_notification_event(UUID, TEXT, TEXT, JSONB);

-- Mettre à jour les triggers marketplace pour utiliser app_queue_notification_event
-- Dans change_20260302_marketplace_phase7_notifications_and_merchant_profile.sql:
-- Remplacer app.fn_enqueue_notification_event par app_queue_notification_event
```

#### 2. Supprimer le trigger referral commission
```sql
-- Supprimer le trigger désactivé
DROP TRIGGER IF EXISTS trg_app_application_payments_referral_commission ON app.application_payments;
DROP FUNCTION IF EXISTS app_on_payment_confirmed_generate_referral_commission();
```

### 4.2 Actions secondaires (P1)

#### 1. Ajouter une déduplication par événement
```sql
-- Ajouter une contrainte unique sur notification_events
-- Pour éviter les doublons exacts (même user, même domain, même type, même payload dans un court délai)

CREATE TABLE IF NOT EXISTS app.notification_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    domain TEXT NOT NULL,
    event_type TEXT NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMPTZ,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    last_error TEXT,
    -- Ajouter un index pour éviter les doublons rapprochés
    CONSTRAINT no_duplicate_recent_events EXCLUDE USING gist (
        user_id WITH =,
        domain WITH =,
        event_type WITH =,
        payload WITH =,
        created_at WITH &&
    )
    WHERE (processed_at IS NULL)
);
```

#### 2. Limiter l'envoi à un seul device par utilisateur
```typescript
// Dans send-push-notifications/index.ts
// Modifier fetchActiveTokens pour retourner uniquement le token le plus récent

async function fetchActiveTokens(userId: string) {
  const url = `${SUPABASE_URL}/rest/v1/user_device_tokens?user_id=eq.${userId}&is_active=eq.true&order=last_seen_at.desc&limit=1`;
  // ...
}
```

### 4.3 Actions d'amélioration (P2)

#### 1. Ajouter des préférences utilisateur
```sql
CREATE TABLE IF NOT EXISTS app.user_notification_preferences (
    user_id UUID PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
    student_payments BOOLEAN DEFAULT TRUE,
    admin_payments BOOLEAN DEFAULT TRUE,
    student_applications BOOLEAN DEFAULT TRUE,
    admin_applications BOOLEAN DEFAULT TRUE,
    student_communities BOOLEAN DEFAULT TRUE,
    student_bobodo BOOLEAN DEFAULT TRUE,
    student_opportunities BOOLEAN DEFAULT TRUE,
    admin_opportunities BOOLEAN DEFAULT TRUE,
    marketplace_inquiries BOOLEAN DEFAULT TRUE,
    marketplace_opportunities BOOLEAN DEFAULT TRUE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

#### 2. Ajouter une logique de déduplication dans les triggers
```sql
-- Avant d'enqueuer, vérifier si un événement similaire existe déjà

CREATE OR REPLACE FUNCTION app_queue_notification_event(
    p_user_id UUID,
    p_domain TEXT,
    p_event_type TEXT,
    p_payload JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_event_id UUID;
    v_recent_count INTEGER;
BEGIN
    IF p_user_id IS NULL THEN
        RETURN NULL;
    END IF;
    IF p_domain IS NULL OR LENGTH(TRIM(p_domain)) = 0 THEN
        RETURN NULL;
    END IF;

    -- Vérifier si un événement similaire existe dans les 5 dernières minutes
    SELECT COUNT(*)
    INTO v_recent_count
    FROM app.notification_events
    WHERE user_id = p_user_id
      AND domain = p_domain
      AND event_type = p_event_type
      AND created_at > NOW() - INTERVAL '5 minutes'
      AND processed_at IS NULL;

    IF v_recent_count > 0 THEN
        -- Événement similaire déjà en file, ne pas dupliquer
        RETURN NULL;
    END IF;

    INSERT INTO app.notification_events (user_id, domain, event_type, payload)
    VALUES (p_user_id, p_domain, p_event_type, COALESCE(p_payload, '{}'::JSONB))
    RETURNING id INTO v_event_id;

    RETURN v_event_id;
END;
$$;
```

---

## 5. Plan de Déploiement

### Étape 1: Unification des fonctions (P0)
1. Supprimer `app.fn_enqueue_notification_event`
2. Mettre à jour les triggers marketplace
3. Tester les notifications marketplace

### Étape 2: Suppression du trigger referral (P0)
1. Supprimer `trg_app_application_payments_referral_commission`
2. Supprimer `app_on_payment_confirmed_generate_referral_commission()`
3. Tester les paiements

### Étape 3: Déduplication par événement (P1)
1. Ajouter la contrainte EXCLUDE sur `notification_events`
2. Modifier `app_queue_notification_event` pour vérifier les doublons
3. Tester les scénarios de duplication

### Étape 4: Limitation par device (P1)
1. Modifier `fetchActiveTokens` pour retourner 1 token max
2. Tester avec plusieurs devices

### Étape 5: Préférences utilisateur (P2)
1. Créer la table `user_notification_preferences`
2. Modifier les triggers pour vérifier les préférences
3. Ajouter l'UI Flutter pour gérer les préférences

---

## 6. Conclusion

Les duplications de notifications proviennent de **4 sources distinctes**:

1. **Triggers multiples** sur la même table (résolu: trigger referral désactivé)
2. **Appels multiples** dans un trigger (conception: 1 notification par rôle)
3. **Fonctions d'enqueue différentes** (à corriger: unifier)
4. **Tokens multiples** par utilisateur (à optimiser: limiter à 1 device)

**Correction immédiate requise**: Unifier les fonctions d'enqueue et supprimer le trigger referral.

Une fois corrigé, le système enverra:
- **1 notification par device actif** pour chaque événement
- **1 notification par rôle** (étudiant, admin, commercial) concerné
- **0 duplication** par les fonctions d'enqueue

---

## Annexes

### A. Fichiers source analysés
1. `.devin/sql_changes/20260101_push_notifications_arch.sql`
2. `.devin/sql_changes/20260302_marketplace_phase7_notifications_and_merchant_profile.sql`
3. `.devin/sql_changes/change_20260118_referral_commercials.sql`
4. `.devin/sql_changes/change_20260315_fix_commercial_system.sql`
5. `supabase/functions/send-push-notifications/index.ts`

### B. Scripts de correction
À créer:
- `.windsurf/sql_changes/fix_20260707_unify_notification_enqueue.sql`
- `.windsurf/sql_changes/fix_20260707_remove_referral_trigger.sql`
- `.windsurf/sql_changes/fix_20260707_add_notification_deduplication.sql`

---

**Fin du rapport de correction**
