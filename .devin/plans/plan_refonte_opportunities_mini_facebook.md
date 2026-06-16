# Plan d'Implémentation : Refonte Opportunités "Mini-Facebook"

**Projet:** Academia  
**Module:** Opportunités (Étudiant & Admin)  
**Date:** 2025-01-04  
**Basé sur:** Audit du module existant + Cahier des charges "Mini-Facebook des Opportunités"

---

## 📊 ANALYSE ÉCARTS : EXISTANT vs CIBLE

### Légende
- ✅ **Existant** - Déjà implémenté, à conserver
- 🔄 **À modifier** - Existant mais nécessite adaptation
- 🆕 **Nouveau** - À créer de zéro

### Tableau comparatif

| Fonctionnalité | État actuel | Cible | Écart |
|----------------|-------------|-------|-------|
| **Tables opportunities** | ✅ 21 colonnes | Ajouter `price`, `reactions_count`, `comments_count` | 🔄 Extension |
| **Table opportunity_types** | ✅ Existe | Corriger données + ajouter `job`, `service`, `product` | 🔄 Migration données |
| **Table opportunity_applications** | ✅ 9 colonnes | Ajouter gestion statuts admin | 🔄 Extension |
| **Table opportunity_reactions** | ❌ N'existe pas | Nouvelle table | 🆕 Création |
| **Table opportunity_comments** | ❌ N'existe pas | Nouvelle table | 🆕 Création |
| **RPC listing étudiant** | ✅ Avec filtres | Ajouter pagination, compteurs | 🔄 Extension |
| **RPC réactions** | ❌ N'existe pas | CRUD réactions | 🆕 Création |
| **RPC commentaires** | ❌ N'existe pas | CRUD commentaires | 🆕 Création |
| **RPC admin candidatures** | ✅ Liste | Ajouter update statut | 🔄 Extension |
| **UI Feed étudiant** | ✅ GridView simple | Feed scroll infini + cards sociales | 🔄 Refonte UI |
| **UI Détail opportunité** | ❌ N'existe pas | Écran détail complet | 🆕 Création |
| **UI Réactions** | ❌ N'existe pas | Barre réactions | 🆕 Création |
| **UI Commentaires** | ❌ N'existe pas | Bottom sheet commentaires | 🆕 Création |
| **UI Admin candidatures** | ✅ Dialog liste | Ajouter gestion statuts | 🔄 Extension |
| **Notifications opportunités** | ❌ Pas de badge | Badge + notifications | 🆕 Création |

---

## 🏗️ ARCHITECTURE CIBLE

### Supabase (Backend)

```
Schema: app
├── opportunities (existant, étendu)
│   └── + price, reactions_count, comments_count
├── opportunity_types (existant, données corrigées)
├── opportunity_applications (existant, étendu)
│   └── + admin_notes, reviewed_at, reviewed_by
├── opportunity_reactions (NOUVEAU)
│   └── id, opportunity_id, user_id, reaction_type, created_at
└── opportunity_comments (NOUVEAU)
    └── id, opportunity_id, user_id, content, created_at

Schema: public (RPC)
├── Existants (conservés)
│   ├── app_student_list_opportunities (modifié: pagination + compteurs)
│   ├── app_student_get_opportunity_detail
│   ├── app_student_apply_for_opportunity
│   ├── app_student_list_my_opportunity_applications
│   ├── app_list_opportunity_types
│   ├── app_admin_list_opportunities
│   ├── app_admin_upsert_opportunity (modifié: nouveaux champs)
│   ├── app_admin_update_opportunity_status
│   ├── app_admin_list_opportunity_applications
│   ├── app_admin_list_opportunity_types
│   └── app_admin_upsert_opportunity_type
├── Nouveaux - Réactions
│   ├── app_opportunity_toggle_reaction
│   ├── app_opportunity_get_reactions
│   └── app_opportunity_get_my_reaction
├── Nouveaux - Commentaires
│   ├── app_opportunity_add_comment
│   ├── app_opportunity_list_comments
│   └── app_opportunity_delete_comment
└── Nouveaux - Admin
    └── app_admin_update_application_status
```

### Flutter (Frontend)

```
academia_app/lib/
├── providers/
│   ├── student_opportunities_provider.dart (MODIFIÉ)
│   ├── admin_opportunities_provider.dart (MODIFIÉ)
│   ├── opportunity_reactions_provider.dart (NOUVEAU)
│   └── opportunity_comments_provider.dart (NOUVEAU)
├── features/student/
│   ├── tabs/
│   │   └── student_opportunities_tab.dart (REFONTE COMPLÈTE)
│   └── opportunities/
│       ├── opportunity_detail_screen.dart (NOUVEAU)
│       └── opportunity_apply_dialog.dart (EXTRAIT)
├── features/admin/
│   └── admin_opportunities_screen.dart (MODIFIÉ)
└── widgets/opportunities/
    ├── opportunity_feed_card.dart (NOUVEAU)
    ├── opportunity_reactions_bar.dart (NOUVEAU)
    ├── opportunity_comments_sheet.dart (NOUVEAU)
    ├── opportunity_type_badge.dart (NOUVEAU)
    └── opportunity_skeleton_loader.dart (NOUVEAU)
```

---

## 📅 PLAN D'IMPLÉMENTATION PAR PHASES

### PHASE 0 : Préparation (0.5 jour)
**Objectif:** Corriger les incohérences existantes avant d'ajouter du nouveau

| Tâche | Type | Fichier/Table | Détail |
|-------|------|---------------|--------|
| 0.1 | SQL | `opportunity_types` | Corriger données: `code: "vendeur"` → `code: "job"`, `label: "emploi"` → `label: "Emploi"` |
| 0.2 | SQL | `opportunity_types` | Insérer types manquants: `service` (Service), `product` (Bien) |
| 0.3 | SQL | `opportunities` | Mettre à jour `type` existant si nécessaire |

**Livrable:** Migration SQL `phase0_fix_opportunity_types.sql`

---

### PHASE 1 : Extensions Backend (1.5 jours)
**Objectif:** Étendre les tables et RPC existantes sans casser le fonctionnement actuel

#### 1.1 Extensions de tables

| Tâche | Table | Colonnes ajoutées |
|-------|-------|-------------------|
| 1.1.1 | `opportunities` | `price NUMERIC(12,2)`, `reactions_count INT DEFAULT 0`, `comments_count INT DEFAULT 0` |
| 1.1.2 | `opportunity_applications` | `admin_notes TEXT`, `reviewed_at TIMESTAMPTZ`, `reviewed_by UUID` |

#### 1.2 Nouvelles tables

| Tâche | Table | Colonnes |
|-------|-------|----------|
| 1.2.1 | `opportunity_reactions` | `id UUID PK`, `opportunity_id UUID FK`, `user_id UUID`, `reaction_type TEXT CHECK (IN ('like','love'))`, `created_at TIMESTAMPTZ`, UNIQUE(opportunity_id, user_id) |
| 1.2.2 | `opportunity_comments` | `id UUID PK`, `opportunity_id UUID FK`, `user_id UUID`, `content TEXT NOT NULL`, `created_at TIMESTAMPTZ` |

#### 1.3 Policies RLS

| Tâche | Table | Policies |
|-------|-------|----------|
| 1.3.1 | `opportunity_reactions` | SELECT (public), INSERT/DELETE (own user_id) |
| 1.3.2 | `opportunity_comments` | SELECT (public), INSERT (authenticated), DELETE (own user_id OR admin) |

#### 1.4 Nouvelles RPC

| Tâche | Fonction | Paramètres | Description |
|-------|----------|------------|-------------|
| 1.4.1 | `app_opportunity_toggle_reaction` | `p_opportunity_id, p_reaction_type` | Toggle like/love, met à jour compteur |
| 1.4.2 | `app_opportunity_get_reactions` | `p_opportunity_id` | Compteurs par type |
| 1.4.3 | `app_opportunity_get_my_reaction` | `p_opportunity_id` | Ma réaction actuelle |
| 1.4.4 | `app_opportunity_add_comment` | `p_opportunity_id, p_content` | Ajouter commentaire, incrémenter compteur |
| 1.4.5 | `app_opportunity_list_comments` | `p_opportunity_id, p_limit, p_offset` | Liste paginée |
| 1.4.6 | `app_opportunity_delete_comment` | `p_comment_id` | Supprimer (vérifie ownership) |
| 1.4.7 | `app_admin_update_application_status` | `p_application_id, p_status, p_admin_notes` | Changer statut candidature |

#### 1.5 Modification RPC existantes

| Tâche | Fonction | Modification |
|-------|----------|--------------|
| 1.5.1 | `app_student_list_opportunities` | Ajouter `p_limit`, `p_offset`, retourner `reactions_count`, `comments_count`, `my_reaction` |
| 1.5.2 | `app_admin_upsert_opportunity` | Ajouter `p_price` |

**Livrable:** Migration SQL `phase1_opportunities_social.sql`

---

### PHASE 2 : Nouveaux Providers Flutter (1 jour)
**Objectif:** Créer les providers pour réactions et commentaires

#### 2.1 OpportunityReactionsProvider

```dart
// Fichier: providers/opportunity_reactions_provider.dart
class OpportunityReactionsProvider extends ChangeNotifier {
  // État
  Map<String, String?> _myReactions; // opportunity_id → reaction_type
  Map<String, Map<String, int>> _reactionCounts; // opportunity_id → {like: n, love: m}
  
  // Méthodes
  Future<void> toggleReaction(String opportunityId, String reactionType);
  Future<void> loadMyReaction(String opportunityId);
  String? getMyReaction(String opportunityId);
  Map<String, int> getReactionCounts(String opportunityId);
}
```

#### 2.2 OpportunityCommentsProvider

```dart
// Fichier: providers/opportunity_comments_provider.dart
class OpportunityCommentsProvider extends ChangeNotifier {
  // État
  Map<String, List<Map<String, dynamic>>> _comments; // opportunity_id → comments
  Map<String, bool> _hasMore;
  
  // Méthodes
  Future<void> loadComments(String opportunityId, {bool refresh = false});
  Future<void> addComment(String opportunityId, String content);
  Future<void> deleteComment(String commentId, String opportunityId);
  List<Map<String, dynamic>> getComments(String opportunityId);
}
```

#### 2.3 Modifications StudentOpportunitiesProvider

```dart
// Ajouts dans student_opportunities_provider.dart
- Pagination: _currentPage, _hasMore, loadMore()
- Intégration compteurs réactions/commentaires dans les données
- Méthode refreshFeed() pour pull-to-refresh
```

**Livrable:** 3 fichiers Dart (2 nouveaux + 1 modifié)

---

### PHASE 3 : Nouveaux Widgets Flutter (1.5 jours)
**Objectif:** Créer les composants UI réutilisables

#### 3.1 OpportunityFeedCard

```dart
// Fichier: widgets/opportunities/opportunity_feed_card.dart
// Structure:
// ┌─────────────────────────────────────┐
// │ [Logo] Org Name          il y a 2j  │ ← Header
// ├─────────────────────────────────────┤
// │ Titre de l'opportunité              │
// │ Description courte tronquée...      │ ← Body
// │ [Badge Type] [Lieu] [Prix]          │
// ├─────────────────────────────────────┤
// │ 👍 12  ❤️ 5    💬 3 commentaires    │ ← Stats
// ├─────────────────────────────────────┤
// │ [👍] [❤️]  [💬]  [Postuler/Contacter]│ ← Actions
// └─────────────────────────────────────┘
```

**Props:**
- `opportunity: Map<String, dynamic>`
- `onTap: VoidCallback?`
- `onReaction: Function(String type)?`
- `onComment: VoidCallback?`
- `onAction: VoidCallback?` (Postuler/Contacter/Acheter)

#### 3.2 OpportunityReactionsBar

```dart
// Fichier: widgets/opportunities/opportunity_reactions_bar.dart
// Barre horizontale avec:
// - Bouton Like (👍) avec état actif/inactif
// - Bouton Love (❤️) avec état actif/inactif
// - Compteur commentaires cliquable
// - Bouton action principal (contextuel selon type)
```

#### 3.3 OpportunityCommentsSheet

```dart
// Fichier: widgets/opportunities/opportunity_comments_sheet.dart
// Bottom sheet avec:
// - Header avec compteur
// - Liste scrollable de commentaires
// - Champ de saisie en bas (sticky)
// - Chaque commentaire: avatar, nom, texte, date, [supprimer si owner]
```

#### 3.4 OpportunityTypeBadge

```dart
// Fichier: widgets/opportunities/opportunity_type_badge.dart
// Badge coloré selon le type:
// - job → Bleu (#3275D0) + icône briefcase
// - service → Vert (#1B8F5A) + icône handshake
// - product → Orange (#F6A623) + icône shopping_bag
```

#### 3.5 OpportunitySkeletonLoader

```dart
// Fichier: widgets/opportunities/opportunity_skeleton_loader.dart
// Skeleton animé reprenant la structure de OpportunityFeedCard
// Shimmer effect sur les zones de texte
```

**Livrable:** 5 fichiers Dart widgets

---

### PHASE 4 : Refonte UI Étudiant (2 jours)
**Objectif:** Transformer l'onglet en feed social

#### 4.1 Refonte StudentOpportunitiesTab

**Avant:**
- GridView responsive
- Cards simples
- Filtres par chips

**Après:**
- ListView avec scroll infini
- OpportunityFeedCard
- Pull-to-refresh
- Skeleton loaders
- Filtres en header sticky
- Animation d'apparition des cards

```dart
// Structure cible
Scaffold(
  body: RefreshIndicator(
    onRefresh: _onRefresh,
    child: CustomScrollView(
      slivers: [
        SliverAppBar(pinned: true, title: _FilterBar()),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index >= opportunities.length) {
                return _hasMore ? _LoadMoreIndicator() : null;
              }
              return OpportunityFeedCard(
                opportunity: opportunities[index],
                // ...callbacks
              );
            },
          ),
        ),
      ],
    ),
  ),
)
```

#### 4.2 Nouvel écran OpportunityDetailScreen

```dart
// Fichier: features/student/opportunities/opportunity_detail_screen.dart
// Écran complet avec:
// - AppBar avec titre
// - Header: logo, org, date
// - Corps: titre, description complète, infos détaillées
// - Section réactions (inline)
// - Section commentaires (expandable ou inline)
// - Bouton action flottant (Postuler/Contacter/Acheter)
```

#### 4.3 Dialog de candidature (extraction)

```dart
// Fichier: features/student/opportunities/opportunity_apply_dialog.dart
// Extraire la logique du dialog existant
// Améliorer l'UX:
// - Stepper si plusieurs étapes
// - Preview du CV uploadé
// - Confirmation visuelle
```

**Livrable:** 3 fichiers Dart (1 refonte + 2 nouveaux)

---

### PHASE 5 : Améliorations Admin (1 jour)
**Objectif:** Permettre la gestion des candidatures et la modération

#### 5.1 Gestion statuts candidatures

**Modifications AdminOpportunitiesProvider:**
```dart
// Nouvelle méthode
Future<void> updateApplicationStatus(
  String applicationId,
  String status, // 'pending', 'accepted', 'rejected'
  String? adminNotes,
);
```

**Modifications UI dialog candidatures:**
- Dropdown pour changer le statut
- Champ notes admin
- Badge coloré par statut
- Bouton "Notifier l'étudiant"

#### 5.2 Modération opportunités

**Ajouts UI:**
- Bouton "Masquer" (set is_active = false)
- Historique des actions (optionnel, phase ultérieure)

#### 5.3 Nouveaux filtres admin

- Filtre par statut candidature
- Filtre par date de création
- Tri par nombre de candidatures

**Livrable:** 2 fichiers Dart modifiés

---

### PHASE 6 : Notifications (0.5 jour)
**Objectif:** Intégrer les badges et notifications

#### 6.1 Badge onglet Opportunités

**Modification StudentDashboardScreen:**
- Ajouter état `_hasNewOpportunities`
- Appeler RPC notification summary pour domaine `student_opportunities`
- Afficher badge sur l'onglet index=2

#### 6.2 Notifications push (si infra existante)

**Triggers Supabase:**
- Nouvelle opportunité publiée → notifier étudiants
- Statut candidature changé → notifier étudiant concerné
- Nouveau commentaire sur opportunité postulée → notifier étudiant

**Livrable:** 1 fichier Dart modifié + 1 migration SQL triggers

---

## 📋 CHECKLIST FINALE

### Avant déploiement

- [ ] Toutes les migrations SQL exécutées sans erreur
- [ ] RPC existantes toujours fonctionnelles (non-régression)
- [ ] Nouveaux providers enregistrés dans `main.dart`
- [ ] Tests manuels sur mobile (iOS + Android)
- [ ] Tests manuels sur desktop/web
- [ ] Pas de breaking change sur les données existantes

### Critères d'acceptation

- [ ] Feed scroll infini fonctionnel
- [ ] Pull-to-refresh fonctionnel
- [ ] Réactions like/love fonctionnelles
- [ ] Commentaires ajout/suppression fonctionnels
- [ ] Écran détail opportunité accessible
- [ ] Admin peut changer statut candidature
- [ ] Badge nouvelles opportunités visible
- [ ] UI conforme à la direction artistique (cards, ombres, coins arrondis)

---

## 📁 FICHIERS À CRÉER/MODIFIER

### Supabase (SQL)

| Fichier | Type | Description |
|---------|------|-------------|
| `phase0_fix_opportunity_types.sql` | Migration | Correction données types |
| `phase1_opportunities_social.sql` | Migration | Tables + RPC réactions/commentaires |
| `phase6_opportunities_notifications.sql` | Migration | Triggers notifications |

### Flutter

| Fichier | Type | Description |
|---------|------|-------------|
| `opportunity_reactions_provider.dart` | Nouveau | Provider réactions |
| `opportunity_comments_provider.dart` | Nouveau | Provider commentaires |
| `student_opportunities_provider.dart` | Modifié | Pagination + refresh |
| `admin_opportunities_provider.dart` | Modifié | Gestion statuts |
| `opportunity_feed_card.dart` | Nouveau | Widget card feed |
| `opportunity_reactions_bar.dart` | Nouveau | Widget barre réactions |
| `opportunity_comments_sheet.dart` | Nouveau | Widget sheet commentaires |
| `opportunity_type_badge.dart` | Nouveau | Widget badge type |
| `opportunity_skeleton_loader.dart` | Nouveau | Widget skeleton |
| `student_opportunities_tab.dart` | Refonte | Onglet feed social |
| `opportunity_detail_screen.dart` | Nouveau | Écran détail |
| `opportunity_apply_dialog.dart` | Nouveau | Dialog candidature |
| `admin_opportunities_screen.dart` | Modifié | Gestion candidatures |
| `student_dashboard_screen.dart` | Modifié | Badge notifications |
| `main.dart` | Modifié | Enregistrement providers |

---

## ⏱️ ESTIMATION TOTALE

| Phase | Durée estimée |
|-------|---------------|
| Phase 0 - Préparation | 0.5 jour |
| Phase 1 - Backend | 1.5 jours |
| Phase 2 - Providers | 1 jour |
| Phase 3 - Widgets | 1.5 jours |
| Phase 4 - UI Étudiant | 2 jours |
| Phase 5 - Admin | 1 jour |
| Phase 6 - Notifications | 0.5 jour |
| **TOTAL** | **8 jours** |

---

## 🚫 HORS PÉRIMÈTRE (RAPPEL)

- ❌ Messagerie privée
- ❌ Stories
- ❌ Profils sociaux publics
- ❌ Publications sans type structuré
- ❌ Threads de commentaires (1 niveau seulement)

---

*Plan généré le 2025-01-04 - Prêt pour validation avant implémentation*
