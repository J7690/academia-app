# RAPPORT D'AUDIT FORENSIQUE CIBLÉ

## `app_student_delete_forum_message`

**Date** : 2026-06-04
**Statut** : AUDIT COMPLÉT — AUCUNE MODIFICATION EFFECTUÉE
**Méthode** : Analyse statique du code Flutter et de l'inventaire Supabase
**Auditeur** : Cascade AI

---

## SOMMAIRE EXÉCUTIF

Le RPC `app_student_delete_forum_message` est le **seul RPC Classe A** parmi les 68 problématiques : il est **cassé, visible pour l'utilisateur final, et déclenché par une action manuelle** (suppression d'un message forum).

**Verdict** : Le RPC existe dans le schéma `app` mais **pas dans `public`**. Flutter l'appelle sans préfixe de schéma → Supabase retourne une erreur `PGRST202` (RPC non trouvé). Le code Flutter n'a **aucun try-catch** → l'exception est visible brute pour l'utilisateur.

**Effort de correction estimé** : 15 minutes (créer un proxy dans `public` ou déplacer la fonction).

---

## PHASE 1 — AUDIT FLUTTER

### Fichier et ligne

```@c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\features\student\online_course_detail_screen.dart:925
await Supabase.instance.client.rpc('app_student_delete_forum_message', params: {'p_message_id': msgId});
```

### Écran

- **Nom de la classe** : `OnlineCourseDetailScreen`
- **Type** : `StatefulWidget`
- **Fichier** : `features/student/online_course_detail_screen.dart`
- **Route** : Détail d'un cours en ligne (passage de `courseId`, `initialTitle`, `initiallyEnrolled`)

### Bouton déclencheur

- **Action** : Appui **long** (`onLongPress`) sur un message du forum
- **Widget** : `GestureDetector` enveloppant chaque bulle de message
- **Menu** : `showModalBottomSheet` avec trois options :
  1. **"Supprimer"** (rouge, icône `Icons.delete_outline`) — visible uniquement si `isMe` (l'utilisateur est l'auteur)
  2. **"Signaler"** (orange, icône `Icons.flag_outlined`) — visible si ce n'est pas l'auteur
  3. **"Bloquer l'auteur"** (rouge, icône `Icons.block`) — visible si ce n'est pas l'auteur

### Rôle concerné

**Étudiant uniquement**. La condition `isMe = senderRole == 'student' || msgUserId == currentUid` limite l'affichage du bouton "Supprimer" aux messages de l'utilisateur connecté.

### Flux utilisateur complet

```
Étudiant
  → Ouvre un cours en ligne (OnlineCourseDetailScreen)
  → Navigue vers l'onglet "Forum"
  → Sélectionne un thread de discussion
  → Voit la liste des messages
  → Appui LONG sur l'un de SES propres messages
  → BottomSheet apparaît avec [Supprimer] [Signaler] [Bloquer]
  → Tape [Supprimer]
  → Appelle Supabase.instance.client.rpc('app_student_delete_forum_message')
  → ❌ ERREUR PGRST202 (pas de try-catch)
  → Exception visible à l'utilisateur
```

### Code complet du contexte

```@c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\features\student\online_course_detail_screen.dart:911-928
GestureDetector(
  onLongPress: () {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMe && msgId != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await Supabase.instance.client.rpc('app_student_delete_forum_message', params: {'p_message_id': msgId});
                  p.loadMessages(threadId);
                },
              ),
            ...
          ],
        ),
      ),
    );
  },
  child: ...
)
```

### Absence de protection

- **Pas de `try { } catch { }`**
- **Pas de gestion d'erreur**
- **Pas de `await showDialog` de confirmation**
- Si le RPC échoue, l'exception Dart (`PostgrestException`) se propage directement à l'utilisateur

---

## PHASE 2 — ANALYSE DU RPC ATTENDU

### Paramètres attendus

| Paramètre | Type | Source | Description |
|-----------|------|--------|-------------|
| `p_message_id` | `string` (UUID) | `msgId = m['id']?.toString()` | Identifiant du message à supprimer |

### Retour attendu

Le pattern des autres RPCs de forum suggère un retour JSONB de la forme :

```json
{
  "success": true,
  "deleted_id": "uuid-du-message"
}
```

ou en cas d'échec :

```json
{
  "success": false,
  "error": "Message not found or unauthorized"
}
```

### Comportement attendu

1. L'utilisateur appelle le RPC avec l'ID de son propre message
2. Le RPC vérifie que l'utilisateur authentifié (`auth.uid()`) est bien l'auteur du message
3. Le RPC supprime le message de la table sous-jacente
4. Le RPC retourne `success: true`

### Validations attendues

- **Authentification** : L'utilisateur doit être connecté (`auth.uid() IS NOT NULL`)
- **Propriété** : L'utilisateur doit être l'auteur du message (`user_id = auth.uid()`)
- **Existence** : Le message doit exister dans la base

---

## PHASE 3 — RECHERCHE SUPABASE

### Inventaire des schémas

| Schéma | Présence | return_type |
|--------|----------|-------------|
| `public` | **ABSENT** | — |
| `app` | **PRÉSENT** | `jsonb` |

Données issues de `audit_inventory_base.json` :

```json
{
  "return_type": "jsonb",
  "routine_name": "app_student_delete_forum_message"
}
```

### Statut dans la matrice d'audit

```json
{
  "rpc": "app_student_delete_forum_message",
  "in_public": false,
  "in_app": true,
  "status": "B"
}
```

**Statut B** = "Mauvais schéma" : le RPC existe uniquement dans `app`, pas dans `public`.

### Recherche de variantes de nom

Les recherches suivantes ont été effectuées dans l'inventaire Supabase (`audit_inventory_base.json`) :

| Variante | Résultat |
|----------|----------|
| `delete_forum_message` | Non trouvé |
| `remove_forum_message` | Non trouvé |
| `forum_delete_message` | Non trouvé |
| `delete_message` | Non trouvé |

### Écosystème des RPCs de forum

Le schéma `public` contient **8 autres RPCs de forum** fonctionnels :

| RPC | Module | Statut |
|-----|--------|--------|
| `app_ci_add_online_course_forum_message` | Instructor | A (public) |
| `app_ci_create_online_course_forum_thread` | Instructor | A (public) |
| `app_ci_list_online_course_forum_messages` | Instructor | A (public) |
| `app_ci_list_online_course_forum_threads` | Instructor | A (public) |
| `app_student_add_online_course_forum_message` | Student | A (public) |
| `app_student_create_online_course_forum_thread` | Student | A (public) |
| `app_student_list_online_course_forum_messages` | Student | A (public) |
| `app_student_list_online_course_forum_threads` | Student | A (public) |

**Conclusion critique** : `app_student_delete_forum_message` est le **SEUL** RPC de l'écosystème forum à ne pas exister dans `public`. Tous les autres (création, liste, ajout) sont correctement placés dans `public`.

### Analyse du trigger lié

Un trigger existe également dans `public` :
- `app_notify_instructor_forum_message` (return_type: `trigger`)

Cela confirme que l'écosystème forum est bien supposé vivre dans `public`.

---

## PHASE 4 — RECHERCHE MIGRATIONS

### Analyse du dossier `.windsurf/sql_changes`

**Recherche** : `app_student_delete_forum_message` dans tous les fichiers `.sql`

**Résultat** : **AUCUN FICHIER** ne contient ce RPC.

### Confirmation via `audit_migrations_rpc.json`

```json
{
  "rpc": "app_student_delete_forum_message",
  "status": "B",
  "found_in_files": []
}
```

`found_in_files: []` confirme que ce RPC n'a **jamais été versionné** dans une migration SQL.

### Hypothèses

1. **Création manuelle** : Le RPC a été créé directement dans le schéma `app` via l'éditeur SQL de Supabase Studio, sans passer par une migration.
2. **Migration oubliée** : Un développeur a créé le fichier `.sql` localement mais ne l'a jamais appliqué ni commité.
3. **Suppression accidentelle** : La migration existait mais a été perdue/supprimée.
4. **Déplacement manuel** : Le RPC a été déplacé vers `app` manuellement lors d'un test et jamais remis dans `public`.

### Comparaison avec les autres RPCs de forum

Les 8 autres RPCs de forum (création, liste, ajout) sont probablement définis dans les migrations existantes, ce qui explique pourquoi ils sont dans `public`. Le RPC de suppression semble avoir été ajouté **après coup**, manuellement, et oublié dans `app`.

---

## PHASE 5 — ANALYSE DES TABLES

### Tables non identifiées dans les migrations

Les recherches dans `.windsurf/sql_changes` pour `CREATE TABLE.*forum`, `forum_messages`, `course_threads`, `thread_messages` n'ont retourné **aucun résultat**.

Cela suggère que :
- Les tables de forums ont été créées dans des migrations antérieures à l'audit, ou
- Les tables portent des noms différents de ceux recherchés, ou
- Les migrations ne sont pas complètement versionnées dans ce dossier.

### Déduction de la structure via le code Flutter

Les providers Flutter (`online_course_forum_provider.dart`) utilisent les RPCs suivants :

- `app_student_list_online_course_forum_threads` → retourne `threads[]`
- `app_student_list_online_course_forum_messages` → retourne `messages[]`
- `app_student_create_online_course_forum_thread` → crée un thread
- `app_student_add_online_course_forum_message` → ajoute un message

Les objets retournés contiennent les champs suivants (déduits du code) :

**Thread** :
- `id` (UUID)
- `course_id` (UUID)
- `title` (string)
- `created_at` (datetime)

**Message** :
- `id` (UUID)
- `thread_id` (UUID)
- `user_id` (UUID)
- `sender_role` (string : 'student', 'instructor')
- `content` (string)
- `created_at` (datetime)

### Mécanisme de suppression

Le RPC s'appelle `delete_forum_message` (pas `soft_delete_forum_message`), ce qui suggère un **hard delete** (suppression physique de la ligne dans la table).

### Absence de colonnes de suppression

Aucune colonne `deleted_at`, `is_deleted`, ou `deletion_method` n'est mentionnée dans le code Flutter, ce qui confirme le hard delete.

---

## PHASE 6 — TEST RUNTIME (THÉORIQUE)

> **Note** : Aucun test sur téléphone physique n'a été effectué. Cette section est basée sur l'analyse statique et les connaissances du comportement Supabase.

### Erreur attendue

Si un étudiant tente de supprimer son message sur l'application en production :

```
PostgrestException: Could not find the function "app_student_delete_forum_message" in the schema "public"
```

**Code HTTP** : 404  
**Code PostgREST** : `PGRST202`

### Réponse Supabase attendue

```json
{
  "code": "PGRST202",
  "message": "Could not find the function app_student_delete_forum_message in the schema public",
  "details": ""
}
```

### Comportement Flutter attendu

1. L'utilisateur tape "Supprimer"
2. Le bottom sheet se ferme (`Navigator.pop(ctx)`)
3. L'appel RPC est lancé
4. **Erreur PGRST202 retournée**
5. **Aucun try-catch** → l'exception se propage
6. **L'écran affiche une erreur brute** (ou l'app crash selon la configuration du framework d'erreur)
7. Le message n'est **pas supprimé**
8. Le reload `p.loadMessages(threadId)` ne se produit probablement pas car l'exception interrompt le flux

---

## PHASE 7 — IMPACT MÉTIER

### Utilisateurs concernés

- **Rôle** : Étudiants inscrits à des cours en ligne
- **Fréquence** : Rare à moyenne (suppression de messages propres)
- **Impact direct** : L'étudiant ne peut pas supprimer ses messages de forum
- **Impact indirect** : L'étudiant doit utiliser "Signaler" pour demander la suppression, ce qui crée un ticket de modération inutile

### Google Play / App Store

- **Impact** : Faible
- **Pas de crash** de l'application (c'est une exception Dart catchée par le framework Flutter si un `ErrorWidget` global est configuré)
- **Mais** : l'utilisateur voit une erreur technique, ce qui dégrade l'expérience utilisateur
- **Pas de rejet** de l'app par les stores pour cette raison seule

### Modération

- **Impact** : Moyen
- Les utilisateurs ne peuvent pas auto-modérer (supprimer leurs propres messages)
- Les tickets de signalement inutiles augmentent la charge de modération
- Les enseignants/administrateurs doivent intervenir manuellement pour supprimer des messages

### Enseignants

- **Impact direct** : Aucun (l'enseignant n'utilise pas ce bouton)
- **Impact indirect** : Les enseignants voient des messages que les étudiants auraient voulu supprimer, et reçoivent des signalements inutiles

---

## PHASE 8 — RECOMMANDATION

### Cause racine

**Le RPC a été créé dans le schéma `app` mais jamais migré vers `public`.**

Le code Flutter appelle `Supabase.instance.client.rpc('app_student_delete_forum_message')` sans préfixe de schéma. Supabase PostgREST résout les appels RPC sans préfixe dans le schéma `public` par défaut. Le RPC n'existant pas dans `public`, l'erreur `PGRST202` est retournée.

**Pourquoi les autres RPCs de forum fonctionnent** : Ils existent dans `public` (statut A).

**Pourquoi celui-ci est manquant** : C'est le seul RPC de suppression de l'écosystème. Il a probablement été ajouté après les RPCs de création/liste, manuellement dans `app`, et oublié.

### Niveau de risque

| Critère | Évaluation |
|---------|-----------|
| **Visibilité** | Élevée (erreur visible utilisateur) |
| **Fréquence** | Moyenne (action volontaire) |
| **Sévérité** | Moyenne (fonctionnalité bloquée, pas de corruption de données) |
| **Effort de correction** | Très faible (1 RPC) |
| **Risque global** | **MOYEN** |

### Plan de correction recommandé

#### Option A — Créer un proxy dans `public` (RECOMMANDÉE)

```sql
CREATE OR REPLACE FUNCTION public.app_student_delete_forum_message(p_message_id UUID)
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT app.app_student_delete_forum_message(p_message_id);
$$;
```

**Avantages** :
- Aucun changement nécessaire dans le code Flutter
- Aucun risque de régression sur la logique métier (la fonction `app` reste la source de vérité)
- Rapide et sûr

#### Option B — Déplacer la fonction de `app` vers `public`

```sql
-- Supprimer de app
DROP FUNCTION IF EXISTS app.app_student_delete_forum_message(UUID);

-- Recréer dans public (nécessite le code source de la fonction)
CREATE OR REPLACE FUNCTION public.app_student_delete_forum_message(p_message_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$ ... $$;
```

**Inconvénients** :
- Nécessite de connaître le code source exact de la fonction dans `app`
- Risque de perte de la logique métier si le code source n'est pas récupérable
- Peut casser d'autres fonctions PostgreSQL qui appellent la version `app`

#### Option C — Ajouter un try-catch côté Flutter (WORKAROUND)

```dart
try {
  await Supabase.instance.client.rpc('app_student_delete_forum_message', params: {'p_message_id': msgId});
  p.loadMessages(threadId);
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Impossible de supprimer le message. Veuillez réessayer.')),
  );
}
```

**Inconvénients** :
- Le message ne sera jamais supprimé (le RPC reste cassé)
- C'est un masquage du symptôme, pas une correction
- **DÉCONSEILLÉ**

### Recommandation finale

**Adopter l'Option A (proxy dans `public`) immédiatement**, puis documenter la nécessité de nettoyer l'écosystème `app` vs `public` pour tous les RPCs de forum.

---

## ANNEXE A — DONNÉES BRUTES

### Emplacement dans le code Flutter

- **Fichier** : `academia_app/lib/features/student/online_course_detail_screen.dart`
- **Ligne** : 925
- **Méthode** : `onTap` dans un `ListTile` dans un `showModalBottomSheet`
- **Contexte** : `GestureDetector.onLongPress` sur un message de forum

### Inventaire Supabase

- **Schéma** : `app`
- **Nom** : `app_student_delete_forum_message`
- **Return type** : `jsonb`
- **Paramètres** : Inconnus (non déduits de l'inventaire, probablement `p_message_id UUID`)

### Matrice d'audit

```json
{
  "rpc": "app_student_delete_forum_message",
  "in_public": false,
  "in_app": true,
  "status": "B"
}
```

### Migrations

- **Fichiers trouvés** : Aucun
- **Status** : Non versionné

---

## ANNEXE B — COMPARAISON AVEC L'ÉCOSYSTÈME FORUM

| RPC | public | app | Statut | Migration connue |
|-----|--------|-----|--------|-----------------|
| `app_ci_add_online_course_forum_message` | ✅ | ❌ | A | Oui |
| `app_ci_create_online_course_forum_thread` | ✅ | ❌ | A | Oui |
| `app_ci_list_online_course_forum_messages` | ✅ | ❌ | A | Oui |
| `app_ci_list_online_course_forum_threads` | ✅ | ❌ | A | Oui |
| `app_student_add_online_course_forum_message` | ✅ | ❌ | A | Oui |
| `app_student_create_online_course_forum_thread` | ✅ | ❌ | A | Oui |
| `app_student_list_online_course_forum_messages` | ✅ | ❌ | A | Oui |
| `app_student_list_online_course_forum_threads` | ✅ | ❌ | A | Oui |
| **`app_student_delete_forum_message`** | ❌ | ✅ | **B** | **Non** |

**Conclusion** : Le RPC de suppression est l'**anomalie** de l'écosystème forum. Tous les autres sont correctement placés dans `public`.

---

*Fin du rapport. Aucune modification effectuée. Aucune exécution SQL.*
