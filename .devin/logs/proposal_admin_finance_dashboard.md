# PROPOSITION — Tableau de bord financier administrateur
## Date: 17 Avril 2026

---

# 1. RECHERCHE EXTERNE — Meilleures pratiques

## 1.1 Stripe Dashboard
**Structure:** Home → Balances → Transactions → Payouts → Reporting
- **Home** : Vue d'ensemble avec widgets personnalisables (revenus, volume, graphiques)
- **Balances** : Solde disponible, en transit, en attente + historique top-ups/payouts
- **Transactions** : Liste filtrable de tous les paiements (status, montant, client, date)
- **Payouts** : Liste des versements vers le compte bancaire + calendrier payout
- **Reporting** : Rapports téléchargeables (réconciliation, balance, activité)

**Ce qu'on retient :** Le solde est CENTRAL (Available / Pending / In Transit), avec un grand livre détaillé en dessous.

## 1.2 PayPal Balance Report
**Structure:** Summary → Activity Overview → Detail
- **Summary** : Beginning Balance → Credits → Debits → Ending Balance (par devise)
- **Activity Overview** : Sales activity, Fees, Refunds, Chargebacks, Withdrawals
- **Available vs Withheld** : Distinction entre disponible et bloqué (risque/compliance)
- **Reconciliation** : Rapprochement transaction par transaction

**Ce qu'on retient :** La formule `Solde début + Entrées - Sorties = Solde fin` est universelle.

## 1.3 Square Dashboard
**Structure:** Sales Summary → Payment Methods → Payouts → Reports
- **Sales Summary** : Gross sales, Refunds, Net sales, Fees, Net deposit
- **Payment Methods** : Répartition par moyen de paiement (carte, cash, mobile)
- **Payouts** : Historique des virements vers le compte bancaire
- **Accounting reports** : P&L, Balance sheet, Cash flow

**Ce qu'on retient :** La décomposition `Gross → Fees → Net` est standard.

## 1.4 Dashboards Fintech (Perceptive Analytics)
7 dashboards recommandés pour les plateformes de paiement :
1. **Revenue & Transaction Performance** : GMV, take rate, revenue par segment
2. **Customer Acquisition** : CAC, sign-up to activation, onboarding time
3. **Customer Retention** : Active accounts, churn %, cohort retention
4. **Payment Method Usage** : Volume par méthode, taux de succès, adoption
5. **System Health** : Authorization rate, uptime, latency, error rate
6. **Fraud & Security** : Fraud rate, chargeback rate, false positives
7. **Cost & Fees** : Cost per transaction, interchange fees, net take rate

**Ce qu'on retient pour Academia :** On a besoin des dashboards #1, #4, #5, #7 adaptés à notre contexte.

## 1.5 LigdiCash Dashboard
- **dashboard.ligdicash.com** : Accès au compte marchand
- **Transactions** : Liste payin/payout de tous les projets API et Paylink
- **API limitée** : Pas d'API reporting/balance — les données doivent être reconstituées côté Supabase

---

# 2. AUDIT — ÉTAT ACTUEL (4 onglets séparés)

| Onglet actuel | Contenu | Limites |
|---|---|---|
| **Trésorerie** (212 lignes) | 8 KPI cards + Grand livre | Pas de graphique, pas de période, pas de solde global |
| **Payouts** (244 lignes) | Liste filtrée par status + bouton trigger | Pas de KPI de synthèse, pas d'historique |
| **Répartition revenus** (341 lignes) | CRUD des rules par reason | Config uniquement, pas de monitoring |
| **Soldes acteurs** (~200 lignes) | Liste filtrée par type | Basique, pas de drill-down |

**Problèmes :**
- 4 onglets séparés = vision fragmentée
- Pas de vue consolidée "flux d'argent" (entrées → redistribution → sorties)
- Pas de graphiques temporels
- Pas de solde LigdiCash en temps réel
- Pas d'alertes

---

# 3. PROPOSITION — NOUVEAU TABLEAU DE BORD FINANCIER UNIFIÉ

## 3.1 Architecture : 1 onglet "Finance" avec 5 sous-onglets

Remplacer les 4 onglets actuels par **1 seul onglet "Finance"** avec un design inspiré de Stripe/PayPal :

```
┌─────────────────────────────────────────────────────────┐
│  💰 FINANCE                                              │
│ ┌──────┬──────────┬────────┬───────────┬───────────────┐ │
│ │ Vue  │ Flux     │ Payouts│ Acteurs   │ Configuration │ │
│ │ d'en.│ (Ledger) │        │ (Soldes)  │ (Split rules) │ │
│ └──────┴──────────┴────────┴───────────┴───────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### Sous-onglet 1 : VUE D'ENSEMBLE (inspiré Stripe Home + PayPal Summary)

```
┌─────────────────────────────────────────────┐
│  SOLDE PLATEFORME                           │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐     │
│  │ Solde   │  │ En      │  │ En      │     │
│  │ dispo.  │  │ attente │  │ transit │     │
│  │ 150 000 │  │ 25 000  │  │ 8 000   │     │
│  │ XOF     │  │ XOF     │  │ XOF     │     │
│  └─────────┘  └─────────┘  └─────────┘     │
├─────────────────────────────────────────────┤
│  INDICATEURS CLÉS                           │
│  ┌──────────────┐ ┌──────────────┐          │
│  │ ↓ Entrées    │ │ ↑ Sorties    │          │
│  │   ce mois    │ │   ce mois    │          │
│  │ +350 000 XOF │ │ -120 000 XOF │          │
│  │ (45 tx)      │ │ (12 tx)      │          │
│  └──────────────┘ └──────────────┘          │
│  ┌──────────────┐ ┌──────────────┐          │
│  │ % Taux de    │ │ Payouts      │          │
│  │ succès       │ │ échoués      │          │
│  │ payout       │ │ ce mois      │          │
│  │ 95.2%        │ │ 2            │          │
│  └──────────────┘ └──────────────┘          │
├─────────────────────────────────────────────┤
│  GRAPHIQUE — Flux 30 derniers jours         │
│  ┌─────────────────────────────────┐        │
│  │  ▓▓▓  (entrées en vert)        │        │
│  │  ░░░  (sorties en rouge)        │        │
│  │  ───  (solde net en bleu)       │        │
│  └─────────────────────────────────┘        │
├─────────────────────────────────────────────┤
│  RÉPARTITION PAR SOURCE                     │
│  ┌───────────────────────────┐              │
│  │ ▓▓▓▓▓▓░░░░ TD 55%        │              │
│  │ ▓▓▓▓░░░░░░ Inscriptions  │              │
│  │ ▓▓░░░░░░░░ Marketplace   │              │
│  │ ▓░░░░░░░░░ Abonnements   │              │
│  └───────────────────────────┘              │
├─────────────────────────────────────────────┤
│  DERNIÈRES TRANSACTIONS (5)                 │
│  ▼ Payin +5000 XOF  TD access   il y a 2h  │
│  ▲ Payout -2750 XOF Enseignant  il y a 2h  │
│  ▼ Payin +15000 XOF Registration il y a 5h │
│  ...                                        │
│            [Voir tout →]                    │
└─────────────────────────────────────────────┘
```

**KPIs affichés :**
- Solde disponible / en attente / en transit
- Entrées du mois (volume + nombre de transactions)
- Sorties du mois (volume + nombre)
- Taux de succès payout (%)
- Payouts échoués (nombre, alerte rouge si > 0)
- Graphique barres 30j : entrées vs sorties vs solde net
- Donut chart : répartition par payment_reason

### Sous-onglet 2 : FLUX (Grand Livre / Ledger)

Inspiré de Stripe Transactions — liste chronologique de TOUTES les opérations :

- **Filtres** : Période (7j/30j/90j/custom), Direction (crédit/débit/tout), Type (payin/payout/split/commission)
- **Colonnes** : Date, Type, Description, Montant (+/-), Contrepartie, Solde après
- **Export** : Bouton "Exporter CSV"
- **Recherche** : Par ID de transaction ou description

### Sous-onglet 3 : PAYOUTS

Garder le contenu actuel de `admin_payouts_screen.dart` mais enrichi :

- **KPI header** : Total en attente / En cours / Complétés aujourd'hui / Échoués
- **Filtres** : Status, Type d'acteur, Période
- **Bouton "Traiter les versements"** (existant)
- **Détail payout** : Tap → modal avec historique des tentatives, token LigdiCash, erreurs
- **Retry** : Bouton "Retenter" sur les payouts échoués

### Sous-onglet 4 : ACTEURS (Soldes)

Enrichir `admin_actor_balances_screen.dart` :

- **Vue par acteur** : Filtre par type (Commercial/Enseignant/Marchand)
- **Carte acteur** : Nom, phone, disponible, en attente, gagné, retiré
- **Drill-down** : Tap → historique des transactions de l'acteur
- **Alerte** : Badge rouge si payout en `waiting_phone` (pas de numéro configuré)

### Sous-onglet 5 : CONFIGURATION (Split Rules)

Garder `admin_revenue_split_screen.dart` tel quel — il est déjà bien fait.

---

# 4. DONNÉES NÉCESSAIRES — NOUVELLE RPC

Pour alimenter la vue d'ensemble, il faut une nouvelle RPC `app_admin_finance_overview` qui retourne :

```json
{
  "balance": {
    "available": 150000,
    "pending_payouts": 25000,
    "in_transit": 8000
  },
  "month": {
    "total_payin": 350000,
    "total_payout": 120000,
    "payin_count": 45,
    "payout_count": 12,
    "payout_success_rate": 0.952,
    "payout_failed_count": 2
  },
  "by_reason": [
    {"reason": "td_access", "amount": 180000, "count": 25},
    {"reason": "registration_fee", "amount": 100000, "count": 12},
    {"reason": "marketplace_purchase", "amount": 50000, "count": 6},
    {"reason": "subscription", "amount": 20000, "count": 2}
  ],
  "chart_30d": [
    {"date": "2026-03-18", "payin": 15000, "payout": 5000},
    {"date": "2026-03-19", "payin": 22000, "payout": 8000},
    ...
  ],
  "recent_transactions": [
    {"type": "payin", "amount": 5000, "description": "...", "created_at": "..."},
    ...
  ],
  "alerts": {
    "failed_payouts": 2,
    "waiting_phone": 3,
    "low_balance": false
  }
}
```

---

# 5. PLAN D'IMPLÉMENTATION

| Phase | Contenu | Durée estimée |
|---|---|---|
| **F1** | RPC `app_admin_finance_overview` (agrège ledger + payouts + balances) | 2h |
| **F2** | Refactoring onglets admin : fusionner 4→1 onglet "Finance" avec sub-tabs | 1h |
| **F3** | Vue d'ensemble : KPI cards + graphique 30j + donut + dernières transactions | 3h |
| **F4** | Flux (Ledger) : filtres, recherche, pagination, export CSV | 2h |
| **F5** | Payouts enrichi : KPI header, détail modal, retry, alertes | 2h |
| **F6** | Acteurs enrichi : drill-down, alertes waiting_phone | 1h |
| **F7** | Configuration : garder tel quel (déjà opérationnel) | 0h |

**Total estimé : ~11h**

---

# 6. QUESTIONS POUR VALIDATION

1. **Graphique 30j** : barres (entrées/sorties séparées) ou courbe (solde net) ?
2. **Export CSV** : nécessaire pour le grand livre ?
3. **Alertes** : notification push admin si payout échoué ?
4. **Fréquence refresh** : auto-refresh toutes les 5 minutes sur la vue d'ensemble ?
5. **Historique** : combien de mois d'historique garder visible ? (30j, 90j, 1 an ?)
6. **Accord** sur la fusion des 4 onglets en 1 seul onglet "Finance" avec 5 sous-onglets ?
