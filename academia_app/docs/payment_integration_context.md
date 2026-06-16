# Payment Integration Context — Academia x LigdiCash

> Reference UNIQUE pour le module paiements. Avant toute modif: lire CE fichier + UNIQUEMENT les fichiers de la section 2. NE PAS rescanner tout le projet. NE PAS toucher auth/routing global/DDD/modules non listes.
> MAJ: 26 mai 2026 (preparation tests reels LigdiCash).

---

## 1. Architecture

Flutter (LigdiCashPaymentSheet -> LigdiCashProvider -> LigdiCashService) -> Edge Functions (initiate/confirm/callback/payout) -> LigdiCash API (Payin sans redirection + Withdrawal top_up_wallet=1) -> RPC app_confirm_ligdicash_payment (idempotent) -> tables app.application_payments / marketplace_payments / payment_receipts + payout_queue + platform_ledger + actor_balances + subscriptions + referral_commissions + revenue_split_rules.

### 1.1 Flutter (3 couches)
- Service lib/services/ligdicash_service.dart : initiatePayment / confirmOtp ; extraction robuste de FunctionException.details.
- Provider lib/providers/ligdicash_provider.dart : etats idle|sendingOtp|waitingOtp|confirming|processing|success|error ; _humanizeError() codes->FR.
- Widget lib/widgets/ligdicash_payment_sheet.dart : 3 vues (Phone -> OTP avec ussd_code -> Success). API : LigdiCashPaymentSheet.show(context, paymentType, paymentId, amount, currency, description, onSuccess). TOUS les ecrans passent par ce widget.

### 1.2 Edge Functions (supabase/functions/)
- ligdicash-initiate (user JWT) : verifie ownership, status pending->processing, retourne ussd_code (Orange *144*4*6*{montant}#, Moov *555*6#, Telecel *100*6#). Aucun appel API.
- ligdicash-confirm (user JWT) : LIVE = POST /pay/v01/straight/checkout-invoice/create avec OTP -> polling GET /confirm/?invoiceToken= (10x3s) -> RPC ; MOCK = OTP 123456.
- ligdicash-callback (--no-verify-jwt) : webhook backup, parse JSON + form-urlencoded, re-verify via /confirm/, idempotent, toujours 200.
- ligdicash-payout (admin/service_role) : POST /pay/v01/withdrawal/create (top_up_wallet:1) + verify, UPDATE payout_queue + INSERT platform_ledger.
- ligdicash-diag / ligdicash-diagnostic : outils debug, ignorer en prod.

### 1.3 Supabase
Tables (schema app) : application_payments (cols ligdicash_token, ligdicash_transaction_id, ligdicash_operator, payment_method, channel, phone_number, status), marketplace_payments (idem + payment_provider), payment_receipts, payment_proofs, payout_queue, platform_ledger, actor_balances, subscriptions, subscription_plans, revenue_split_rules, referral_commissions, commission_rules, commercial_profiles.payout_phone.
Enums : payment_status (pending/processing/declared_by_student/under_verification/confirmed/rejected/cancelled), payment_channel (+ligdicash), payment_reason (+subscription, marketplace_purchase, online_course).
RPC cle : app_confirm_ligdicash_payment(p_payment_id, p_ligdicash_token, p_ligdicash_transaction_id, p_ligdicash_operator, p_payment_type) - idempotent ; cree recu, commission, ledger ; active subscription/TD ; split via revenue_split_rules -> actor_balances.
Autres RPC : app_admin_finance_overview/live_feed/payout_feed/actor_history, app_commercial_request_payout, app_merchant_request_payout, app_instructor_request_payout, app_university_request_payout, app_student_check_subscription, app_resolve_revenue_split.
Triggers/cron : trg_auto_payout_on_balance_change ; pg_cron expire_subscriptions (2h/j) ; reset_stale_processing_payments (30min).
Realtime : platform_ledger + payout_queue.

---

## 2. Mandatory Files Before Any Payment Intervention

A LIRE OBLIGATOIREMENT avant toute modif paiement (et UNIQUEMENT ceux-ci, sauf decouverte explicite) :

### Flutter (academia_app/lib/)
- services/ligdicash_service.dart
- providers/ligdicash_provider.dart
- providers/subscription_provider.dart
- providers/credit_provider.dart
- providers/admin_finance_provider.dart
- providers/admin_payout_provider.dart
- providers/admin_payments_provider.dart
- providers/admin_payment_detail_provider.dart
- providers/admin_payment_receipts_provider.dart
- providers/admin_application_payments_provider.dart
- providers/student_application_payments_provider.dart
- providers/university_payments_provider.dart
- providers/university_application_payments_provider.dart
- widgets/ligdicash_payment_sheet.dart
- widgets/paywall_overlay.dart
- utils/payment_receipt_pdf.dart
- features/admin/admin_payments_screen.dart
- features/admin/admin_payment_detail_screen.dart
- features/admin/admin_payment_receipts_screen.dart
- features/admin/admin_payouts_screen.dart
- features/admin/admin_finance_screen.dart
- features/student/student_payments_screen.dart
- features/student/student_application_detail_screen.dart
- features/student/student_td_root_screen.dart  (point d'integration TD)
- features/student/credit_store_screen.dart
- features/student/widgets/student_short_trainings_section.dart
- features/student/marketplace/student_marketplace_cart_screen_v1.dart
- features/instructor/instructor_revenue_tab.dart
- features/university/university_revenue_tab.dart
- features/university/university_payments_screen.dart
- features/commercial/commercial_dashboard_screen.dart
- features/merchant/merchant_marketplace_console_screen_v2.dart

### Backend Edge Functions (supabase/functions/)
- ligdicash-initiate/index.ts
- ligdicash-confirm/index.ts
- ligdicash-callback/index.ts
- ligdicash-payout/index.ts
- ligdicash-diag/index.ts (debug only)
- ligdicash-diagnostic/index.ts (debug only)

### SQL migrations (.windsurf/sql_changes/)
- change_20260319_ligdicash_phase1_foundations.sql
- change_20260319_ligdicash_phase1_rpcs.sql
- change_20260319_ligdicash_phase7_crons.sql
- change_20260407_add_split_to_confirm_rpc.sql

### Audits / logs (.windsurf/logs/)
- audit_payments_supabase.json
- audit_payments_bilan_complet.md

### Config / secrets (jamais commit)
- supabase/.env (LIGDICASH_API_KEY, LIGDICASH_BEARER_TOKEN, LIGDICASH_MODE, LIGDICASH_CALLBACK_URL)
- secrets Edge Functions Supabase (dashboard) : memes cles
- academia_app/lib/main.dart : enregistrement des Providers (LigdiCashProvider, SubscriptionProvider, AdminFinanceProvider, etc.)

### REGLE
Si un fichier paiement n'est pas dans cette liste, NE PAS le modifier sans mettre a jour ce document AVANT.

---

## 3. Flux transactionnels

### 3.1 Payin mobile money (Orange / Moov / Telecel) — flux nominal

1. Utilisateur clique "Payer maintenant" -> ecran appelle LigdiCashPaymentSheet.show(paymentType, paymentId, amount, description, onSuccess).
2. Saisie operateur + numero (226XXXXXXXX) -> Provider.initiatePayment.
3. Edge ligdicash-initiate : valide ownership + amount, met status=processing, channel=ligdicash, payment_method=ligdicash_otp, phone_number=clean ; retourne {success, mode, ussd_code, message, amount, operator}.
4. Vue OTP affiche le ussd_code. L'utilisateur compose le code USSD sur son telephone et recoit un OTP par SMS de l'operateur.
5. Saisie OTP -> Provider.confirmOtp -> Edge ligdicash-confirm -> POST straight/checkout-invoice/create (avec OTP, customer=phone, external_id=payment_id, custom_data={payment_id, payment_type}, callback_url) -> response_code 00 + token.
6. Polling /confirm/?invoiceToken= 10 x 3s. statut completed -> RPC app_confirm_ligdicash_payment ; statuts failed/cancelled/rejected -> 402 echec definitif ; timeout -> 408.
7. RPC : INSERT payment_receipts, UPDATE application_payments.status=confirmed + amount_paid=amount_due, INSERT referral_commissions (si referrer), split via revenue_split_rules -> actor_balances + INSERT platform_ledger, active subscription / TD enrollment selon payment_reason. Idempotente (re-appels retournent already_confirmed).
8. Webhook ligdicash-callback (asynchrone) : LigdiCash POSTe -> re-verify -> RPC (idempotente) en fallback si polling a timeout.
9. UI Success : recu, badge mode si mock, onSuccess() recharge l'ecran appelant.

### 3.2 Erreurs / retry / timeout
- invalid_otp_code : retour OTP view, retryOtp().
- ligdicash_otp_failed / ligdicash_payment_failed : message FR, bouton "Renvoyer le code" -> retryOtp ne ré-appelle PAS initiate (juste reset l'etat ; pour recommencer, fermer la sheet et la re-ouvrir).
- network_error : message reseau, retry possible.
- Timeout (408) : message "Le paiement n'a pas abouti dans le delai imparti, verifiez votre solde" ; webhook callback peut encore confirmer en arriere-plan.
- Cron reset_stale_processing_payments (30 min) : remet processing > 2h en pending pour debloquer.

### 3.3 Payout (versement vers beneficiaire)
1. Acteur (commercial / merchant / instructor / university) saisit son payout_phone (sauvegarde dans le profil correspondant).
2. UI -> RPC app_*_request_payout -> INSERT payout_queue (status=pending) + deduit actor_balances.balance_available.
3. Trigger trg_auto_payout_on_balance_change OU pg_cron 15min OU bouton admin "Trigger payouts" -> Edge ligdicash-payout.
4. Edge : pour chaque payout pending -> POST /pay/v01/withdrawal/create (top_up_wallet:1, customer=phone, custom_data={payout_id, beneficiary_type}) -> verify /withdrawal/confirm/.
5. completed -> UPDATE payout_queue + INSERT platform_ledger (debit) ; failed -> retry_count++.
6. Universite : ZERO flux d'argent (feature_disabled cote backend, onglet revenu masque ; conserve neanmoins le code pour audit).

### 3.4 Subscriptions premium
- PaywallOverlay (lib/widgets/paywall_overlay.dart) wrappe les ecrans premium (ex : Prep Concours).
- subscription_provider.checkFeatureAccessServer / hasFeatureAccess -> RPC app_student_check_subscription.
- createSubscriptionPayment -> INSERT application_payment (reason=subscription) + subscription pending -> ouvre LigdiCashPaymentSheet (paymentType=subscription).
- A la confirmation, RPC app_confirm_ligdicash_payment passe subscription.status=active, expires_at calcule sur duration_days.


---

## 4. Variables et secrets

### 4.1 Edge Functions (Supabase Dashboard -> Settings -> Edge Functions -> Secrets)
- LIGDICASH_API_KEY        : cle Apikey (header)
- LIGDICASH_BEARER_TOKEN   : token Authorization Bearer
- LIGDICASH_MODE           : 'mock' (defaut) ou 'live'
- LIGDICASH_CALLBACK_URL   : optionnel ; defaut = \/functions/v1/ligdicash-callback
- SUPABASE_URL             : auto
- SUPABASE_SERVICE_ROLE_KEY: auto

### 4.2 Endpoints LigdiCash (production)
- Payin mobile money    : POST  https://app.ligdicash.com/pay/v01/straight/checkout-invoice/create
- Payin verify          : GET   https://app.ligdicash.com/pay/v01/redirect/checkout-invoice/confirm/?invoiceToken={token}
- Withdrawal create     : POST  https://app.ligdicash.com/pay/v01/withdrawal/create
- Withdrawal verify     : GET   https://app.ligdicash.com/pay/v01/withdrawal/confirm/?withdrawalToken={token}

### 4.3 Headers requis (toutes requetes API)
Apikey: <LIGDICASH_API_KEY>
Authorization: Bearer <LIGDICASH_BEARER_TOKEN>
Accept: application/json
Content-Type: application/json

### 4.4 Webhook public
URL : https://<project>.supabase.co/functions/v1/ligdicash-callback
Deploye avec --no-verify-jwt. A donner a l'equipe LigdiCash pour configuration cote operateur.

### 4.5 USSD operateurs (Burkina Faso)
- Orange Money  : *144*4*6*{montant}#
- Moov Money    : *555*6#
- Telecel Money : *100*6#

### 4.6 Securite
- Service role JAMAIS expose cote Flutter (uniquement Edge Functions).
- Toutes les RPC critiques utilisent SECURITY DEFINER + verification auth.uid().
- app_confirm_ligdicash_payment est idempotente (anti double-credit).
- Webhook re-verifie via /confirm/ en mode live (anti-spoofing).
- Verification ownership systematique (student_id == auth.uid() ou buyer_id == auth.uid()).
- Aucun secret ne doit apparaitre dans le code Flutter ni dans des logs cote client.
- Ne JAMAIS afficher LIGDICASH_API_KEY ou LIGDICASH_BEARER_TOKEN en clair dans ce document ou ailleurs dans le repo.

---

## 5. Differences Sandbox vs Production

| Aspect | Mock (LIGDICASH_MODE=mock) | Live (LIGDICASH_MODE=live) |
|---|---|---|
| OTP | Force a 123456 | Genere par l'operateur via USSD |
| Appel API LigdiCash | Aucun | straight/checkout-invoice/create + verify |
| Polling | Non | 10 x 3s (~30s max) |
| Withdrawal | Simule, marque completed direct | POST /withdrawal/create + verify |
| Callback | Trust direct | Re-verify obligatoire |
| Recu | MOCK_TXN_<ts>, MOCK_OPERATOR | transaction_id et operator_name reels |
| Badge UI | "Mode test" affiche | Pas de badge |
| Ledger | description prefixee [MOCK] pour payouts | description normale |

Endpoints, headers et URLs callback identiques. Seul change LIGDICASH_MODE et la presence des secrets API.

A faire avant les tests live :
1. supabase secrets set LIGDICASH_API_KEY=... LIGDICASH_BEARER_TOKEN=... LIGDICASH_MODE=live
2. (Optionnel) supabase secrets set LIGDICASH_CALLBACK_URL=...
3. Redeployer les 4 Edge Functions :
   - supabase functions deploy ligdicash-initiate
   - supabase functions deploy ligdicash-confirm
   - supabase functions deploy ligdicash-callback --no-verify-jwt
   - supabase functions deploy ligdicash-payout
4. Communiquer l'URL callback a l'equipe LigdiCash.
5. Test E2E avec petit montant (500 XOF) sur chaque operateur.


---

## 6. Checklist preparation tests demain

### Frontend (Flutter)
- [ ] LigdiCashPaymentSheet branche sur les 6 points d'integration : application_detail, td_root, marketplace_cart, credit_store, paywall_overlay (subscription), short_trainings.
- [ ] Loader sur Provider.isLoading (sendingOtp / confirming).
- [ ] Affichage ussd_code dans la vue OTP.
- [ ] Messages d'erreur FR via _humanizeError.
- [ ] onSuccess recharge bien l'ecran appelant (paiements / TD / panier / abonnement).
- [ ] Badge "Mode test" disparait quand LIGDICASH_MODE=live.
- [ ] Ecrans Revenus (instructor / university / merchant / commercial) : alerte si payout_phone manquant.

### Backend (Edge Functions)
- [ ] Les 4 Edge deployees avec versions a jour (initiate, confirm, callback --no-verify-jwt, payout).
- [ ] Secrets LIGDICASH_API_KEY, LIGDICASH_BEARER_TOKEN, LIGDICASH_MODE=live configures.
- [ ] Logs Edge Functions accessibles (Supabase Dashboard) pour debug live.
- [ ] CORS OK (Access-Control-Allow-Origin: *).
- [ ] external_id = payment_id dans invoiceBody (pour reconciliation callback).
- [ ] callback_url pointe sur ligdicash-callback du projet.

### Supabase
- [ ] Tables : application_payments, marketplace_payments, payment_receipts, payout_queue, platform_ledger, actor_balances, subscriptions, revenue_split_rules, referral_commissions presentes.
- [ ] Enums payment_status / channel / reason a jour (incluant 'ligdicash', 'processing', 'subscription', 'marketplace_purchase').
- [ ] RLS : student own / admin all / service_role ALL sur payout_queue + platform_ledger + actor_balances.
- [ ] RPC app_confirm_ligdicash_payment idempotente (test : double appel = already_confirmed).
- [ ] Triggers + pg_cron actifs (expire_subscriptions, reset_stale_processing_payments, auto_payout).
- [ ] Realtime publication : platform_ledger + payout_queue.

### LigdiCash (cote partenaire)
- [ ] API_KEY + BEARER_TOKEN production recus.
- [ ] URL callback Academia communiquee a LigdiCash.
- [ ] Compte marchand active sur Orange / Moov / Telecel.
- [ ] Plage IP Supabase whitelistee si requis.
- [ ] Numeros test fournis par LigdiCash pour chaque operateur.

### Tests E2E (a executer demain)
- [ ] Payin Orange Money : 500 XOF -> recu + actor_balances credites.
- [ ] Payin Moov Money : 500 XOF.
- [ ] Payin Telecel : 500 XOF.
- [ ] OTP invalide -> message FR clair, retry possible.
- [ ] Solde insuffisant -> 402, status reste pending/processing.
- [ ] Timeout simule -> 408, callback peut encore confirmer.
- [ ] Webhook callback recu en parallele -> idempotence verifiee (already_confirmed).
- [ ] Payout LigdiCash -> LigdiCash : top_up_wallet=1, status completed, ledger debit.
- [ ] Refresh actor_balances apres payout (balance_available diminue).
- [ ] Subscription Premium : paiement -> subscription.status=active, expires_at correct.

---

## 7. Regles de travail apres audit

Apres lecture de ce document :
1. Lire UNIQUEMENT les fichiers de la section 2 + ce document.
2. Ne pas rescanner tout le projet.
3. Modifier UNIQUEMENT les zones liees au paiement.

### Interdictions
- Ne pas refaire un audit global a chaque tache.
- Ne pas relire toute l'architecture.
- Ne pas modifier auth, routing global, DDD, modules non lies aux paiements.
- Ne pas refactoriser le projet.

### Mise a jour de ce document
A chaque modification structurante (ajout fichier critique, nouvelle RPC, changement de flow) : METTRE A JOUR la section concernee de ce document AVANT de commit.

---

## 8. Analyse vs documentation officielle LigdiCash (27 mai 2026)

Sources verifiees :
- https://developers.ligdicash.com/ (doc officielle)
- https://developers.ligdicash.com/api1/payin-sans-redirection (payin)
- https://developers.ligdicash.com/api1/payout (payout)
- https://developers.ligdicash.com/api1/callback (callback)
- https://github.com/Ligdicash/ligdicash-php (SDK officiel reference)

### 8.1 Conformite actuelle (OK)

- Endpoints production identiques : app.ligdicash.com/pay/v01/straight/checkout-invoice/create + /redirect/checkout-invoice/confirm/ + /withdrawal/create + /withdrawal/confirm/.
- Headers requis presents : Apikey + Authorization Bearer + Accept + Content-Type.
- Architecture securisee : appels API LigdiCash uniquement depuis Edge Functions (jamais depuis Flutter). Secrets en variables d'env serveur.
- Idempotence : RPC app_confirm_ligdicash_payment retourne already_confirmed sur re-appel.
- transaction_id unique : on utilise payment_id (UUID) comme external_id dans invoiceBody.
- custom_data callback : on parse les 2 formats (array de {keyof_customdata, valueof_customdata} ET object direct).
- response_code = '00' verifie partout pour considerer une operation reussie.
- Webhook ligdicash-callback retourne toujours HTTP 200 (anti-retry LigdiCash) + re-verify via /confirm/ en mode live (anti-spoofing).
- Gestion erreurs : codes mappes en messages FR via _humanizeError, jamais d'ecran blanc.
- top_up_wallet:1 pour payout : conforme a la doc (transfert wallet puis mobile money).

### 8.2 Gaps detectes a CORRIGER ou CLARIFIER avant tests

| # | Gap | Doc officielle | Etat Academia | Action |
|---|---|---|---|---|
| G1 | Variable platform | SDK PHP utilise platform: 'test' | 'live' (defaut 'test') | On a LIGDICASH_MODE mock | 'live' (mock = bypass total) | Ajouter LIGDICASH_PLATFORM = test | live separe de LIGDICASH_MODE. 'test' = vraies cles sandbox + appels API reels (pas mock). |
| G2 | URL sandbox | Non publiee dans doc publique — fournie avec les credentials sandbox | On utilise toujours app.ligdicash.com | Parametrer LIGDICASH_BASE_URL (defaut app.ligdicash.com) et remplacer les URLs hardcodees dans les 3 Edge Functions live. |
| G3 | Endpoint de verification independant | GET transaction par token (type=payin / payout) — appelable a tout moment | On ne verifie que pendant le confirm | Ajouter Edge Function ligdicash-verify(payment_id) pour re-check post-callback ou retry manuel (admin). |
| G4 | Gestion statut PENDING explicite | Doc liste : completed, pending, failed, cancelled | Notre polling break uniquement sur completed/failed/cancelled/rejected | Ajouter log explicite si pending au-dela des 30s + ne pas marquer le paiement failed cote DB tant que callback ou verify n'a pas confirme. Actuellement OK car on retourne 408 sans modifier la DB. A confirmer cote UI. |
| G5 | Table dediee aux evenements webhook | Bonne pratique fintech recommandee | Pas de table webhook_events | Optionnel mais recommande : creer app.payment_webhook_events (raw_payload, received_at, processed, payment_id) pour audit + replay. |
| G6 | Param payout : nom variable | Doc officielle : top_up_wallet (0 ou 1) | OK on utilise top_up_wallet:1 | Aucun changement. (Memo interne disait LigdiCash to LigdiCash, c'est plus precis : transfert wallet PUIS mobile money). |
| G7 | Logs structures | LigdiCash valorise les logs pendant la validation | Logs via console.log dans Edge Functions | Verifier que tous les appels API loggent : payment_id, http_status, response_code, response_text, token. Deja le cas pour confirm/callback/payout. |
| G8 | UI : etat 'processing' apres timeout 408 | Doc : statut peut basculer apres 30s via webhook | Provider passe en state.error directement | Ajouter un state 'processing' visible : message "Paiement en cours de verification, recu sous peu" + polling Realtime sur application_payments.status. |

### 8.3 A demander a l'equipe LigdiCash demain

1. URL de base exacte pour l'environnement sandbox/test (si differente de app.ligdicash.com).
2. Cles sandbox (API_KEY + BEARER_TOKEN) pour notre projet API de test.
3. Numeros de test Orange Money / Moov / Telecel pour declencher succes / echec / OTP invalide / solde insuffisant.
4. Format exact attendu du callback (JSON ou form-urlencoded) en sandbox vs prod.
5. Plage d'IP source de LigdiCash pour eventuel whitelist cote Supabase.
6. SLA temps de reponse webhook attendu (defaut Stripe = 5s, a confirmer pour LigdiCash).
7. Procedure exacte pour passer en production (certificat de conformite, signature contrat).
8. Existe-t-il un dashboard sandbox pour voir les transactions de test ?

### 8.4 Renforcements rapides a implementer ce soir (si temps)

Priorite haute :
- (G2) Ajouter LIGDICASH_BASE_URL en env + factoriser dans les 3 Edge Functions live.
- (G3) Edge Function ligdicash-verify pour audit manuel post-test.
- (G8) State 'processing' UI + Realtime subscription sur le paiement courant.

Priorite moyenne :
- (G5) Table app.payment_webhook_events + INSERT systematique dans ligdicash-callback.
- (G7) Centraliser format de log (JSON.stringify d'un objet structure).

Priorite basse :
- (G1) Renommer LIGDICASH_MODE en LIGDICASH_PLATFORM. Garder retro-compat.

---

## 9. Audit live Supabase (27 mai 2026, mode test)

Execute via .windsurf/test_ligdicash_e2e_today.py (service_role key sur project thevdfcwlcqzdoybfvgs).

### 9.1 Etat infrastructure
| Composant | Etat |
|---|---|
| ligdicash-initiate | DEPLOYEE (HTTP 401 sans user JWT, attendu) |
| ligdicash-confirm | DEPLOYEE (HTTP 401 sans user JWT) |
| ligdicash-callback | DEPLOYEE (HTTP 200, --no-verify-jwt OK) |
| ligdicash-payout | DEPLOYEE (HTTP 400 attendu sans body) |
| ligdicash-diag | DEPLOYEE |
| ligdicash-diagnostic | NON DEPLOYEE (alias inutilise, OK a ignorer) |
| RPC app_confirm_ligdicash_payment | OK, 13715 chars, signature 5 params correcte |
| RLS application_payments / actor_balances / payout_queue | 3 policies chacun |
| RLS platform_ledger / subscriptions | 2 policies chacun |
| Vault secrets ligdicash | NULL (secrets dans Edge Functions Secrets, pas vault) |

### 9.2 Donnees actuelles (schema app)
| Table | Count |
|---|---|
| application_payments | 14 |
| marketplace_payments | 0 |
| payment_receipts | 8 |
| payout_queue | 0 |
| platform_ledger | 3 |
| actor_balances | 0 |
| subscriptions | 0 |
| subscription_plans | 3 |
| revenue_split_rules | 19 |
| referral_commissions | 0 |

### 9.3 Paiements LigdiCash existants (channel=ligdicash)
- 1 paiement CONFIRMED (id 10d9425e..., 100 XOF, credit_purchase, 17 avril 2026, has_token=true) -> preuve que le flux MOCK fonctionne deja end-to-end.
- 13 paiements PENDING avec channel=ligdicash mais sans token -> declarations interrompues (artefacts d'anciens tests). N'impacte pas demain.

### 9.4 pg_cron actifs
- #4 expire_subscriptions    : 0 2 * * *
- #5 reset_stale_processing_payments : 30 * * * *
- #8 process_pending_payouts : */15 * * * *

### 9.5 Points d'attention pour les tests
1. **actor_balances=0 et subscriptions=0 et referral_commissions=0** : aucun split de revenus reel n'a abouti. Le 1er test E2E reel produira les premieres lignes -> a surveiller en priorite (validation chaine complete : payment -> ledger -> split -> actor_balances).
2. **payout_queue=0** : aucun payout teste, attendre flux complet apres credit actor_balances.
3. **13 paiements PENDING ligdicash sans token** : optionnel SQL nettoyage 'UPDATE app.application_payments SET status=cancelled WHERE channel=ligdicash AND status=pending AND ligdicash_token IS NULL'.
4. **Secrets vault NULL** : confirme que LIGDICASH_API_KEY/BEARER/MODE sont dans Edge Functions Secrets. Pour basculer en live demain : supabase secrets set LIGDICASH_MODE=live LIGDICASH_API_KEY=... LIGDICASH_BEARER_TOKEN=... puis redeployer les 4 fonctions.

### 9.6 Conclusion audit
INFRASTRUCTURE PRETE pour les tests reels. Ne manque que :
- Vraies cles API_KEY + BEARER_TOKEN sandbox/production (a obtenir aupres LigdiCash demain).
- Confirmation URL base reste app.ligdicash.com en sandbox (ou URL alternative).

Re-run rapide : python .windsurf/test_ligdicash_e2e_today.py

---

## 10. Credentials Supabase (admin permanent)

Reference utilisee pour les audits/tests (deja stockee en clair dans .windsurf/supabase_permanent_config.json) :

- Project ID  : thevdfcwlcqzdoybfvgs
- URL         : https://thevdfcwlcqzdoybfvgs.supabase.co
- Service role: present dans .windsurf/supabase_permanent_config.json (JAMAIS commit dans le repo Flutter)
- DB direct   : postgres://...db.thevdfcwlcqzdoybfvgs.supabase.co:5432
- RPC d'audit : execute_sql, list_tables_detailed, describe_table_detailed (cf. fichier config)

Ne jamais utiliser ces cles cote Flutter / cote client. Reservees aux scripts .windsurf et Edge Functions.

---

## 11. Montant minimum de paiement (29 mai 2026)

Regle globale : MIN_PAYMENT_AMOUNT = 10 XOF pour tous les services (application, subscription, td, short_training, marketplace, credit_purchase).

Implementation :
- supabase/functions/ligdicash-initiate/index.ts : check 'amount < 10' renvoie 400 'amount_below_minimum' + message FR + minimum.
- academia_app/lib/providers/ligdicash_provider.dart : _humanizeError case 'amount_below_minimum' -> 'Le montant minimum est de 10 XOF.'

Pour modifier le minimum : changer MIN_PAYMENT_AMOUNT dans ligdicash-initiate et redeployer (supabase functions deploy ligdicash-initiate). Pas besoin de toucher Flutter (le provider mappe juste le code d'erreur).

Pas de contrainte DB ajoutee : la verification cote Edge Function est la source de verite (single gateway).
Pas de modif sur ligdicash-payout (les minimums payout sont fixes par LigdiCash cote API).

---

## 12. Montant editable cote Flutter (29 mai 2026)

### Objectif
Permettre a l'utilisateur de modifier le montant a payer dans LigdiCashPaymentSheet (utile pour tests, paiements partiels, dons libres). Minimum applique : 10 XOF.

### Implementation

**Edge Function** supabase/functions/ligdicash-initiate/index.ts :
- Nouveau parametre body 'amount_override' (number, optionnel).
- Si fourni et > 0 : remplace amount_due (application_payments) ou gross_amount (marketplace_payments) ET sert de montant a payer.
- Sinon : utilise le montant DB d'origine.
- Le check MIN_PAYMENT_AMOUNT=10 s'applique sur la valeur finale (override ou DB).

**Service** academia_app/lib/services/ligdicash_service.dart :
- initiatePayment({..., double? amountOverride}) -> body.amount_override si > 0.

**Provider** academia_app/lib/providers/ligdicash_provider.dart :
- initiatePayment({..., double? amountOverride}) propage au service.
- _humanizeError gere 'amount_below_minimum'.

**Widget** academia_app/lib/widgets/ligdicash_payment_sheet.dart :
- _amountController initialise avec widget.amount.
- Carte montant : TextField numerique (digitsOnly) au lieu de Text statique.
- Hint sous la carte : 'Montant modifiable. Minimum 10 XOF.'.
- Bouton Continuer : validation amt >= 10, calcul override = (amt != widget.amount), passe amountOverride au provider.
- Champ desactive a partir de waitingOtp (deja une transaction en cours).

### Impact base
amount_due / gross_amount du paiement est MUTE quand un override est applique. Le recu et le ledger refletent le montant reellement paye. Aucun script SQL a executer : single source of truth = Edge Function.

### Pour bloquer cette fonctionnalite en prod
Conditionner le rendu du TextField sur LIGDICASH_MODE / build flavor (LigdiCashProvider.mode == 'live' -> read-only). A faire avant release publique.

---

## 13. Dossier-preuve LigdiCash (29 mai 2026)

Quand LigdiCash demande de prouver qu'une transaction s'est bien passee (support, audit, contestation), utiliser le script .windsurf/generate_ligdicash_proof.py.

### Utilisation
```
python .windsurf/generate_ligdicash_proof.py <payment_id_academia>
```

### Champs a fournir (par ordre d'importance)

**Minimum (3 champs) :**
- request_id (ex P2782222872026) - identifiant unique cote LigdiCash
- id_invoice (ex 78222287) - facture interne LigdiCash, decode depuis JWT du token
- external_id (ex d45fe314-...) - notre payment_id Academia, lien entre les 2 systemes

**Complementaire :**
- logfile (ex 202605291648176a19c351e139e) - id log LigdiCash
- token JWT complet stocke dans application_payments.ligdicash_token
- customer (numero phone), montant, devise, operator_name, date_debit

**Cote Academia (Supabase) :**
- application_payments.id, .status (=confirmed), .reference_code
- payment_receipts.receipt_number (ex REC-20260529164821-7aab31)
- Logs Edge Functions ligdicash-initiate / ligdicash-confirm / ligdicash-callback (3 lignes Received -> Verify -> Confirm result)

### Sources des donnees
- Bloc A/B : appel live a verify_token via ligdicash-diag (action verify_token)
- Bloc C : tables app.application_payments + app.payment_receipts
- Bloc D : Supabase Dashboard > Edge Functions > Logs

### Actions disponibles dans ligdicash-diag
- info : affiche mode + prefix des cles
- send_otp : test debitotp
- confirm : test debitwallet/withotp
- check_balance : test endpoints balance (404 normalement, LigdiCash ne l'expose pas)
- verify_token : verify direct d'une invoice par son JWT (ajoute le 29 mai 2026)

### Ou voir les transactions dans le dashboard LigdiCash
- client.ligdicash.com > Marchands > Projets API > carte du projet > 2eme icone (transactions du projet)
- PAS dans Portefeuille > Transactions (qui liste les mouvements de wallet, pas les payins API)
