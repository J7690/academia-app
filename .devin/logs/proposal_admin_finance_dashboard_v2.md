# PROPOSITION V2 — Tableau de bord financier administrateur (LIVE)
## Date: 17 Avril 2026 — Révisée après validation utilisateur

---

# DÉCISIONS VALIDÉES

| Point | Décision |
|---|---|
| Graphique | **Barres** entrées (vert) + sorties (rouge) |
| Export CSV | **OUI** |
| Fusion 4→1 onglet | **OUI** — 1 onglet "Finance" avec 5 sous-onglets |
| Auto-refresh | **10 secondes** via Supabase Realtime (pas polling) |
| Historique | **1 an** complet |
| Notifications live | **OUI** — Payin + Payout en tête de liste avec couleurs acteurs |

---

# ARCHITECTURE TECHNIQUE

## Mécanisme temps réel : Supabase Realtime (pas polling)

Au lieu de polling toutes les 10s (qui surcharge le serveur), on utilise **Supabase Realtime** :
- S'abonner aux `INSERT` sur `app.platform_ledger` (chaque payin/payout/split y est enregistré)
- S'abonner aux `INSERT/UPDATE` sur `app.payout_queue` (chaque payout créé/complété)
- Quand un événement arrive → **injection en tête de liste** + animation highlight couleur

```dart
// Supabase Realtime — écoute live les transactions
final channel = Supabase.instance.client.channel('admin_finance')
  .onPostgresChanges(
    event: PostgresChangeEvent.insert,
    schema: 'app',
    table: 'platform_ledger',
    callback: (payload) {
      // Nouvelle transaction → injecter en tête + highlight vert/rouge
      _onNewLedgerEntry(payload.newRecord);
    },
  )
  .onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'app',
    table: 'payout_queue',
    callback: (payload) {
      // Payout créé/traité → mettre à jour la liste
      _onPayoutChange(payload.newRecord);
    },
  )
  .subscribe();
```

**Avantages vs polling :**
- Instantané (< 1 seconde de latence)
- Zéro charge serveur supplémentaire (WebSocket, pas HTTP)
- Ne fatigue pas le dispositif

**Fallback :** Timer 30s pour recharger les KPIs numériques (montants agrégés).

---

# DESIGN DÉTAILLÉ

## Sous-onglet 1 : VUE D'ENSEMBLE — Live Dashboard

```
┌─────────────────────────────────────────────────────────────┐
│  💰 FINANCE    [Vue d'ens.] [Flux] [Payouts] [Acteurs] [Config]  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │          SOLDE PLATEFORME ACADEMIA                  │   │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐       │   │
│  │  │ 💚 Dispo. │  │ 🟡 Attente│  │ 🔵 Transit│       │   │
│  │  │  150 000  │  │   25 000  │  │    8 000  │       │   │
│  │  │    XOF    │  │    XOF    │  │    XOF    │       │   │
│  │  └───────────┘  └───────────┘  └───────────┘       │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌──────────┐│
│  │↓ ENTRÉES   │ │↑ SORTIES   │ │✅ Taux     │ │⚠️ Échecs ││
│  │  ce mois   │ │  ce mois   │ │  succès    │ │  payout  ││
│  │ +350 000   │ │ -120 000   │ │  95.2%     │ │   2      ││
│  │ (45 tx)    │ │ (12 tx)    │ │  payout    │ │  ← ROUGE ││
│  └────────────┘ └────────────┘ └────────────┘ └──────────┘│
│                                                             │
│  📊 FLUX — 30 DERNIERS JOURS                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  ▓ ▓ ▓ ▓ ▓ ▓ ▓ (VERT = entrées)                   │   │
│  │  ░ ░ ░ ░ ░ ░ ░ (ROUGE = sorties)                   │   │
│  │  Axe X = jours, Axe Y = montant XOF                │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  🍩 RÉPARTITION PAR SOURCE        🍩 RÉPARTITION SORTIES   │
│  ┌─────────────────────┐         ┌─────────────────────┐   │
│  │ TD access    55%    │         │ Enseignants  60%     │   │
│  │ Inscription  25%    │         │ Commerciaux  30%     │   │
│  │ Marketplace  15%    │         │ Marchands    10%     │   │
│  │ Abonnement    5%    │         │                      │   │
│  └─────────────────────┘         └─────────────────────┘   │
│                                                             │
│  ⚡ ACTIVITÉ LIVE                              (temps réel) │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 🟢 NOUVEAU  ↓ Payin +5 000 XOF                     │   │
│  │             Étudiant Ouédraogo Amidou               │   │
│  │             TD Access — il y a 3s                    │   │
│  │─────────────────────────────────────────────────────│   │
│  │ 🔵 NOUVEAU  ↑ Payout -2 750 XOF                    │   │
│  │             → Enseignant Traoré Ibrahim              │   │
│  │             Commission TD 55% — il y a 3s           │   │
│  │─────────────────────────────────────────────────────│   │
│  │ 🟠 NOUVEAU  ↑ Payout -750 XOF                      │   │
│  │             → Commercial Sawadogo Marc               │   │
│  │             Commission TD 15% — il y a 3s           │   │
│  │─────────────────────────────────────────────────────│   │
│  │ ⚪          ↓ Payin +15 000 XOF                     │   │
│  │             Étudiant Compaoré Fatou                  │   │
│  │             Registration fee — il y a 2h            │   │
│  │─────────────────────────────────────────────────────│   │
│  │             ... (scroll infini, 1 an d'historique)  │   │
│  │                                                     │   │
│  │                    [Exporter CSV ⬇]                 │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Système de notifications couleur (badges live)

| Badge | Couleur | Signification |
|---|---|---|
| 🟢 **NOUVEAU** | Vert vif `#16A34A` | Payin reçu — un étudiant vient de payer |
| 🔵 **NOUVEAU** | Bleu `#2563EB` | Payout envoyé — un enseignant a reçu sa commission |
| 🟠 **NOUVEAU** | Orange `#EA580C` | Payout envoyé — un commercial a reçu sa commission |
| 🟣 **NOUVEAU** | Violet `#7C3AED` | Payout envoyé — un marchand a reçu son paiement |
| 🔴 **ÉCHEC** | Rouge `#DC2626` | Payout échoué — nécessite attention |
| ⚪ (pas de badge) | Gris | Transaction ancienne (> 30s) |

### Animation d'entrée
- Nouvelle transaction → **slide-in depuis le haut** + **highlight couleur 5s** puis fondu
- Le badge "NOUVEAU" disparaît après 30 secondes
- Les transactions plus récentes **poussent** les anciennes vers le bas

### Informations affichées par transaction

**Pour un PAYIN :**
```
🟢 NOUVEAU  ↓ Payin +5 000 XOF
  Étudiant : Ouédraogo Amidou (ouedraogo@email.com)
  Motif : TD Access — Maths L1 S1
  Méthode : Orange Money via LigdiCash
  → Répartition : Enseignant 55% (2 750), Commercial 15% (750), Plateforme 30% (1 500)
  il y a 3 secondes
```

**Pour un PAYOUT :**
```
🔵 NOUVEAU  ↑ Payout -2 750 XOF
  Vers : Enseignant Traoré Ibrahim (226 70 XX XX XX)
  Source : Payin #abc123 — TD Access
  Status : ✅ Complété (LigdiCash → LigdiCash)
  il y a 3 secondes
```

---

## Sous-onglet 2 : FLUX (Grand Livre détaillé)

- **Filtres** : Période (7j / 30j / 90j / 6 mois / 1 an / custom), Direction (tout/crédit/débit), Type (payin/payout/split/commission)
- **Recherche** : Par nom d'acteur, ID transaction, description
- **Colonnes** : Date, Type, Acteur (nom + type), Description, Montant (+/-), Solde après
- **Pagination** : 50 par page, scroll infini
- **Export CSV** : Bouton "⬇ Exporter CSV" → télécharge l'ensemble filtré
- **Historique** : 1 an complet
- **Realtime** : Nouvelles entrées en tête avec animation

## Sous-onglet 3 : PAYOUTS

Header KPI :
```
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│ 🟡 12    │ │ 🔵 3     │ │ 🟢 145   │ │ 🔴 2     │
│ En attente│ │ En cours │ │ Complétés│ │ Échoués  │
│ 45 000   │ │ 8 000    │ │ 890 000  │ │ 5 000    │
└──────────┘ └──────────┘ └──────────┘ └──────────┘
```

- **Liste** : Filtrée par status, type d'acteur, période
- **Détail** : Tap → modal avec : nom acteur, phone, montant, raison, tentatives, token LigdiCash, erreurs
- **Actions** : "Retenter" (payouts échoués), "Déclencher tous" (pending)
- **Realtime** : Payout complété/échoué → migration en tête avec badge couleur
- **Notification acteur** : Chaque payout complété → badge vert à côté du nom de l'acteur

## Sous-onglet 4 : ACTEURS (Soldes & Historique)

- **Filtre** : Type (Commercial / Enseignant / Marchand / Tous)
- **Carte acteur** :
  ```
  ┌─────────────────────────────────────────┐
  │ 👤 Traoré Ibrahim         🟢 Actif     │
  │ Enseignant — 226 70 XX XX XX           │
  │                                         │
  │ Disponible : 0 XOF (auto-versé)        │
  │ Total gagné : 125 000 XOF              │
  │ Total versé : 125 000 XOF              │
  │                                         │
  │ 🔵 Dernier payout : 2 750 XOF — il y a 3s│
  │                     [Voir historique →] │
  └─────────────────────────────────────────┘
  ```
- **Drill-down** : Tap → historique complet des transactions de l'acteur (1 an)
- **Alerte** : Badge rouge ⚠️ si `waiting_phone` (pas de numéro configuré)
- **Realtime** : Quand un acteur reçoit un payout → sa carte monte en tête + highlight

## Sous-onglet 5 : CONFIGURATION (Split Rules)

Inchangé — l'écran `admin_revenue_split_screen.dart` actuel est déjà opérationnel.

---

# DONNÉES — RPCs NÉCESSAIRES

## 1. `app_admin_finance_overview` (nouveau)
Retourne les KPIs agrégés pour la vue d'ensemble :
```sql
-- Solde plateforme (estimé depuis le ledger)
-- Entrées/Sorties du mois
-- Taux de succès payout
-- Répartition par source (donut)
-- Données graphique 30j (barres par jour)
```

## 2. `app_admin_finance_live_feed` (nouveau)
Retourne les dernières transactions avec noms d'acteurs résolus :
```sql
-- JOIN platform_ledger avec auth.users, application_payments, payout_queue
-- Résout : nom étudiant (payin), nom acteur (payout), méthode, raison
-- Pagination : LIMIT 50, OFFSET X
-- Filtre : période, direction, type
-- 1 an d'historique
```

## 3. `app_admin_finance_chart_data` (nouveau)
Retourne les données du graphique barres 30j :
```sql
-- GROUP BY date_trunc('day', created_at)
-- SUM(CASE direction WHEN 'credit' THEN amount END) as payin
-- SUM(CASE direction WHEN 'debit' THEN amount END) as payout
-- 30 derniers jours
```

## 4. `app_admin_finance_export_csv` (nouveau)
Retourne TOUTES les transactions pour une période (export CSV) :
```sql
-- Sans pagination, toutes les colonnes
-- Filtres : date_from, date_to, direction, type
```

## 5. Realtime — Configuration PostgreSQL
Activer la publication Realtime sur les tables concernées :
```sql
ALTER PUBLICATION supabase_realtime ADD TABLE app.platform_ledger;
ALTER PUBLICATION supabase_realtime ADD TABLE app.payout_queue;
```

---

# FLUTTER — COMPOSANTS

| Composant | Rôle |
|---|---|
| `AdminFinanceScreen` | Conteneur principal avec TabBar 5 sous-onglets |
| `AdminFinanceProvider` | Provider central : KPIs, chart, live feed, realtime subscription |
| `_FinanceOverviewTab` | KPIs + graphique + donut + live feed |
| `_FinanceLedgerTab` | Grand livre filtrable + export CSV |
| `_FinancePayoutsTab` | Payouts avec KPIs + actions + realtime |
| `_FinanceActorsTab` | Soldes acteurs + drill-down |
| `_FinanceConfigTab` | Split rules (réutilise l'existant) |
| `_LiveTransactionCard` | Widget transaction avec badge couleur + animation |
| `_BarChartWidget` | Graphique barres 30j (fl_chart) |
| `_DonutChartWidget` | Répartition par source (fl_chart) |

### Dépendance graphique : `fl_chart`
```yaml
fl_chart: ^0.69.0  # Barres + Donut charts
```

---

# PLAN D'IMPLÉMENTATION

| Phase | Contenu | Durée |
|---|---|---|
| **F1** | RPCs Supabase : finance_overview, live_feed, chart_data, export_csv | 3h |
| **F2** | Realtime : activer publication + RLS sur ledger/payout_queue | 30min |
| **F3** | Refactoring admin : fusionner 4 onglets → 1 "Finance" + AdminFinanceProvider | 1h |
| **F4** | Vue d'ensemble : KPIs + barres 30j (fl_chart) + donut + live feed | 4h |
| **F5** | Live feed : Supabase Realtime + animation slide-in + badges couleur + résolution noms acteurs | 3h |
| **F6** | Flux (Ledger) : filtres + recherche + pagination + export CSV | 2h |
| **F7** | Payouts enrichi : KPI header + modal détail + retry + realtime | 2h |
| **F8** | Acteurs enrichi : drill-down + alertes + migration en tête | 1.5h |
| **F9** | Build + test APK | 30min |

**Total estimé : ~17.5h**

---

# DIFFÉRENCES CLÉS VS V1

| Aspect | V1 | V2 |
|---|---|---|
| Refresh | Polling 5 min | **Supabase Realtime instantané** |
| Notifications | Aucune | **Badges couleur + slide-in par acteur** |
| Acteurs nommés | Non | **Oui : nom étudiant (payin), nom acteur (payout)** |
| Migration tête de liste | Non | **Oui : nouveau = tête + animation** |
| Graphiques | Non | **Barres 30j + 2 donuts** |
| Export CSV | Non | **Oui** |
| Historique | Non défini | **1 an** |
