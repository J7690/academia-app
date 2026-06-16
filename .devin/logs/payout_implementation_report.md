# RAPPORT — Implémentation Payout Automatique LigdiCash→LigdiCash
## Date: 17 Avril 2026

---

## Changements effectués

### 1. Université — Complètement retirée du circuit payout

| Composant | Action |
|---|---|
| `university_dashboard_screen.dart` | Onglet "Revenus" supprimé (4 tabs → 3 tabs) |
| `university_revenue_tab.dart` | Import supprimé, widget plus référencé |
| `app_university_request_payout` RPC | Retourne `feature_disabled` |
| `revenue_split_rules` university | `is_active = FALSE` pour `registration_fee` (70%) et `tuition_deposit` (80%) |
| Redistribution | `registration_fee`: platform 15%→85%, `tuition_deposit`: platform 10%→90% |

### 2. Edge Function `ligdicash-payout` — LigdiCash→LigdiCash

```diff
- top_up_wallet: 0, // 0 = envoyer sur mobile money
+ top_up_wallet: 1, // 1 = transfert LigdiCash → LigdiCash (portefeuille du bénéficiaire)
```

### 3. Payout automatique — Trigger + pg_cron

**Trigger `trg_auto_payout_on_balance_change`** sur `app.actor_balances`:
- Se déclenche sur INSERT ou UPDATE de `available_balance`
- Calcule l'augmentation de solde
- Skip `platform` et `university`
- Résout le numéro téléphone du bénéficiaire (instructor/commercial/merchant)
- Insère dans `payout_queue` avec status `pending` (ou `waiting_phone` si pas de numéro)
- Déduit immédiatement le montant du `available_balance` (car en queue)

**pg_cron job `process_pending_payouts`**: toutes les 15 minutes
- Appelle l'Edge Function `ligdicash-payout` avec `all_pending: true`
- Traite tous les payouts en status `pending`

### 4. Flutter UI — Payout automatique

| Fichier | Avant | Après |
|---|---|---|
| `instructor_revenue_tab.dart` | Bouton "Retirer X XOF" | Bannière verte "Versements automatiques vers LigdiCash" |
| `commercial_dashboard_screen.dart` | Bouton "Demander versement" | Bannière verte "Commissions auto vers LigdiCash" |
| `merchant_marketplace_console_screen_v2.dart` | Bouton "Retirer mes revenus" | Bannière verte "Versements automatiques vers LigdiCash" |

Méthodes supprimées: `_requestPayout` (instructor, commercial), `_requestMerchantPayout` (merchant)

---

## Flux complet end-to-end

```
1.  Étudiant paie via LigdiCash (payin)
    → application_payments ou marketplace_payments créé

2.  LigdiCash callback → Edge Function ligdicash-confirm
    → RPC app_confirm_ligdicash_payment

3.  RPC confirme le paiement:
    a. Met status = 'confirmed'
    b. Génère un reçu (payment_receipts)
    c. Écrit au grand livre (platform_ledger: payin credit)
    d. Calcule commission commerciale (referral_commissions)
    e. Revenue split via app_resolve_revenue_split(payment_reason)
    f. Crédite actor_balances pour chaque bénéficiaire non-platform

4.  TRIGGER trg_auto_payout_on_balance_change intercepte le crédit:
    a. Insère dans payout_queue (status=pending)
    b. Déduit du available_balance
    
5.  pg_cron (toutes les 15min) → Edge Function ligdicash-payout:
    a. Récupère les payouts pending
    b. POST /pay/v01/withdrawal/create (top_up_wallet=1)
    c. LigdiCash transfert → portefeuille LigdiCash du bénéficiaire
    d. Met payout_queue.status = completed
```

---

## Revenue Split Rules (actives)

| payment_reason | platform | instructor | commercial | university |
|---|---|---|---|---|
| application_fee | 85% | — | 15% | ❌ |
| registration_fee | 85% | — | 15% | ❌ |
| tuition_deposit | 90% | — | 10% | ❌ |
| td_access | 30% | 55% | 15% | ❌ |
| online_course | 30% | 60% | 10% | ❌ |
| subscription | 100% | — | — | ❌ |
| credit_purchase | 85% | — | 15% | ❌ |

---

## Vérifications

| Check | Résultat |
|---|---|
| Trigger `trg_auto_payout_on_balance_change` | ✅ Existe |
| pg_cron `process_pending_payouts` (*/15) | ✅ Actif |
| Split rules totaux = 100% | ✅ Toutes OK |
| University payout disabled | ✅ `feature_disabled` |
| Edge Function `top_up_wallet: 1` | ✅ Vérifié |
| Trigger skip platform/university | ✅ Vérifié |
| Trigger résout phone par type | ✅ instructor/commercial/merchant |
| Build APK debug | ✅ Succès |

---

## Pour activer en LIVE

1. `supabase secrets set LIGDICASH_MODE=live`
2. `supabase functions deploy ligdicash-payout`
3. Tester un micro-paiement → vérifier que le split + payout auto fonctionne
4. Vérifier que le compte marchand LigdiCash a des liquidités suffisantes
