# Bilan Comparatif — Système Commercial Academia vs Best Practices Industrie
## 15 Mars 2026

---

## 1. CE QUI EST EN PLACE (après corrections du 15 mars 2026)

### 1.1 Flux complet end-to-end

```
┌─────────────────────────────────────────────────────────────────────┐
│ ÉTAPE 1 : CRÉATION DU COMPTE COMMERCIAL (Admin)                    │
│ Admin crée un compte → Edge Function → auth.users + commercial_    │
│ profiles (ref_code UNIQUE, ref_link, commission_rate, tier)        │
└───────────────────────────┬─────────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────────┐
│ ÉTAPE 2 : PARTAGE DU LIEN (Commercial)                             │
│ Dashboard commercial → copier/partager ref_link                     │
│ Format: https://domain.netlify.app/?ref=COMM-xxxxxxxx              │
│ Partage: WhatsApp, Facebook, Telegram, copier                      │
└───────────────────────────┬─────────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────────┐
│ ÉTAPE 3 : CAPTURE DU CODE REFERRAL (Étudiant)                      │
│ WEB: Uri.base capture ?ref=COMM-xxx → SharedPreferences            │
│ MOBILE: Saisie manuelle du code à l'inscription → SharedPreferences│
│ Clé: 'pending_referral_code_v1' + 'pending_referral_source_v1'     │
└───────────────────────────┬─────────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────────┐
│ ÉTAPE 4 : ATTACHEMENT DU PROSPECT (auth_wrapper.dart)              │
│ Après login → _attachReferralIfNeeded()                            │
│ → RPC app_register_referral_for_current_user(p_ref_code, p_source) │
│ → INSERT app.user_referrals (student_id, commercial_user_id)       │
│ → Trigger notification au commercial                               │
│ PROTECTIONS:                                                       │
│   ✅ Idempotent: si student déjà référé → skip (pas d'écrasement)  │
│   ✅ UNIQUE INDEX sur student_id (1 seul referral par étudiant)     │
│   ✅ Vérifie commercial actif + ref_code valide                     │
│   ✅ Crée le profil étudiant si inexistant (auto-provision)         │
│   ✅ SharedPreferences nettoyées après succès                       │
│   ✅ Fenêtre d'attribution: 1 an depuis attributed_at               │
└───────────────────────────┬─────────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────────┐
│ ÉTAPE 5 : COMPTEUR DE PROSPECTS (Dashboard commercial)             │
│ prospects_count = COUNT(*) FROM user_referrals WHERE commercial_id │
│ prospects_with_application = COUNT(DISTINCT student_id) JOIN apps   │
│ Anonymisé: PRO-001, PRO-002... (pas de données personnelles)       │
│ Statuts: registered_only → has_application → payment_declared →    │
│          payment_confirmed                                         │
└───────────────────────────┬─────────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────────┐
│ ÉTAPE 6 : SOUSCRIPTION FORMATION + PAIEMENT                       │
│ Étudiant candidature → application_payments créé                   │
│ Admin confirme paiement → app_admin_confirm_payment                │
└───────────────────────────┬─────────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────────┐
│ ÉTAPE 7 : GÉNÉRATION AUTOMATIQUE DE COMMISSION                    │
│ Dans app_admin_confirm_payment (inline, chemin unique) :           │
│ 1. Cherche commercial referrer via user_referrals                  │
│ 2. Vérifie profil commercial actif                                 │
│ 3. Résout le taux via fn_resolve_commission_rate (commission_rules)│
│ 4. Vérifie le cap dégressif via fn_check_commission_cap            │
│ 5. LEAST(resolved_rate, cap_adjusted_rate) → taux final            │
│ 6. amount_paid × taux_final → commission_amount (plafonné max)     │
│ 7. INSERT referral_commissions (status='pending')                  │
│ PROTECTIONS:                                                       │
│   ✅ UNIQUE INDEX sur (commercial_user_id, payment_id)              │
│   ✅ Cap dégressif: rate × 0.85^n (n = commissions existantes)     │
│   ✅ Max commissions par prospect (default 3)                       │
│   ✅ Max amount cap par règle                                       │
│   ✅ Fenêtre 12 mois (vérifié dans confirm_payment)                │
│   ✅ Unités cohérentes: tout en fraction (0.12 = 12%)               │
└───────────────────────────┬─────────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────────┐
│ ÉTAPE 8 : TRIGGERS POST-COMMISSION                                 │
│ → fn_update_commercial_tier : recalcule tier + compteur            │
│ → app_notify_commercial_commission : notification push             │
│ Tiers: Bronze(0) → Silver(5) → Gold(15) → Diamond(30)             │
│ Basé sur COUNT(DISTINCT student_id) avec commissions               │
└───────────────────────────┬─────────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────────┐
│ ÉTAPE 9 : DASHBOARD COMMERCIAL (temps réel)                        │
│ Onglet Accueil: Tier badge, lien referral, KPIs, leaderboard       │
│ Onglet Prospects: Liste anonymisée PRO-xxx avec statuts             │
│ Onglet Finances: Commissions (pending/approved/paid), paiements     │
│                  prospects, milestones, leaderboard mensuel          │
└───────────────────────────┬─────────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────────┐
│ ÉTAPE 10 : ADMIN — GESTION COMPLÈTE                               │
│ Liste commerciaux + stats + ref_code + ref_link                    │
│ Modifier taux commission / cap par prospect                        │
│ Valider/rejeter commissions (pending → approved/paid/rejected)     │
│ Valider/rejeter réclamations de milestones                         │
│ Suspendre/réactiver/supprimer comptes                              │
│ Grille de commissions (CRUD commission_rules)                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 Tables et données

| Table | Rôle | Protections |
|-------|------|-------------|
| `commercial_profiles` | Profil du commercial | PK user_id, UNIQUE ref_code |
| `user_referrals` | Attribution prospect→commercial | UNIQUE student_id (1 commercial par étudiant), INDEX commercial_user_id |
| `referral_commissions` | Commissions générées | UNIQUE (commercial_user_id, payment_id), INDEX student_id, INDEX status |
| `commission_rules` | Grille de taux configurable | Résolution: exact → wildcard payment_reason → wildcard degree → wildcard total |
| `commercial_milestones` | Bonus de palier | 4 seuils: 5/15/30/50 commissions |
| `commercial_milestone_claims` | Réclamations de bonus | status: pending → paid/rejected |

### 1.3 Grille de commissions actuelle

| Type de paiement | Taux | Plafond |
|------------------|------|---------|
| Frais de dossier (application_fee) | 20% | 5 000 XOF |
| Frais inscription BTS | 10% | 15 000 XOF |
| Frais inscription Licence/LMD | 12% | 25 000 XOF |
| Frais inscription Master | 15% | 40 000 XOF |
| Frais inscription Doctorat | 15% | 50 000 XOF |
| Acompte scolarité (tuition_deposit) | 5% | 20 000 XOF |
| Accès TD | 15% | 3 000 XOF |
| Défaut (tout autre) | 8% | 10 000 XOF |

---

## 2. COMPARAISON AVEC LES BEST PRACTICES INDUSTRIE

### 2.1 Modèles de référence analysés

| Plateforme | Modèle | Cookie/Attribution | Tiers | Commission |
|------------|--------|-------------------|-------|------------|
| **Amazon Associates** | Last-click, cookie 24h | 24 heures | Non | 1-10% selon catégorie |
| **Shopify Affiliates** | Last-click, cookie 30j | 30 jours | Non | $150/merchant référé |
| **Uber Referral** | Code unique, first-click | Permanent (code) | Oui (bonus cumulatifs) | Crédit fixe ($5-15) |
| **Airbnb Affiliates** | Cookie 30j | 30 jours | Non | 30% service fee |
| **Dropbox Referral** | Code unique | Permanent | Oui (stockage crescendo) | Stockage gratuit |
| **Tesla Referral** | Code unique | Permanent | Oui (miles → accessoires → voiture) | Escalating rewards |
| **Coinbase Referral** | Code unique | Permanent | Oui | % des frais de trading |
| **PayPal Referral** | Code unique | Permanent | Non | Cash fixe |
| **Academia** | Code unique (COMM-xxx) | **12 mois** | **Oui (4 tiers + 4 milestones)** | **5-20% selon type paiement** |

### 2.2 Comparaison point par point

| Critère | Best Practice Industrie | Academia | Statut |
|---------|------------------------|----------|--------|
| **Attribution** | First-click avec code unique | ✅ First-click, COMM-xxx unique, 1 commercial/étudiant | ✅ Conforme |
| **Fenêtre d'attribution** | 30 jours (e-commerce) à permanent (SaaS) | ✅ 12 mois — adapté au cycle universitaire | ✅ Excellent |
| **Anti-fraude: double attribution** | 1 referrer par client | ✅ UNIQUE INDEX student_id | ✅ Conforme |
| **Anti-fraude: double commission** | 1 commission par transaction | ✅ UNIQUE (commercial_user_id, payment_id) | ✅ Conforme |
| **Cap/plafond** | Max par transaction ou par période | ✅ Max amount + max commissions/prospect (3) + dégressif | ✅ Supérieur |
| **Tiers/gamification** | Escalating rewards (Tesla, Coinbase) | ✅ Bronze→Silver→Gold→Diamond + milestones | ✅ Conforme |
| **Anonymisation** | RGPD: pas de PII partagé | ✅ PRO-001, PRO-002 (pas de noms) | ✅ Conforme |
| **Leaderboard** | Compétition saine (Uber, T-Mobile) | ✅ Top 10 mensuel anonymisé | ✅ Conforme |
| **Notifications temps réel** | Alertes instant | ✅ Push notification sur nouveau referral + commission | ✅ Conforme |
| **Transparence** | Dashboard en libre-service | ✅ 3 onglets (Accueil, Prospects, Finances) | ✅ Conforme |
| **Multi-canal capture** | Web + mobile + QR | ⚠️ Web auto + mobile manuel (pas de deep link ni QR) | ⚠️ Partiel |
| **Double-sided incentives** | Récompense référent ET référé | ❌ Pas de récompense pour l'étudiant référé | ❌ Manquant |
| **A/B testing** | Tester variantes de programme | ❌ Pas de framework A/B testing | ❌ Non prioritaire |
| **Revenue share récurrent** | Commission sur chaque paiement | ✅ Multi-commissions par étudiant (jusqu'au cap) | ✅ Conforme |

### 2.3 Score global

**Academia obtient 11/14 critères conformes (79%)** — Ce qui est **au-dessus de la moyenne** pour une plateforme EdTech en démarrage. Les 3 manques sont :
1. Deep links + QR code (amélioration de la capture)
2. Double-sided incentives (bonus pour l'étudiant qui utilise un code)
3. A/B testing (non prioritaire en phase de lancement)

---

## 3. ROBUSTESSE DES COMPTEURS — ANALYSE DÉTAILLÉE

### 3.1 Compteur de prospects (user_referrals)

| Test | Résultat |
|------|----------|
| **Idempotence**: étudiant déjà référé → re-tentative | ✅ RPC retourne `{attached: false, reason: 'already_attached'}` |
| **Contrainte DB**: UNIQUE INDEX sur student_id | ✅ INSERT impossible en doublon même en cas de race condition |
| **Code invalide**: ref_code inexistant | ✅ RPC retourne `{error: 'ref_code_not_found'}` |
| **Commercial inactif**: is_active = false | ✅ RPC ignore les profils inactifs |
| **Étudiant sans profil**: app.students vide | ✅ RPC crée automatiquement le profil étudiant |
| **Session expirée**: auth.uid() = NULL | ✅ RPC retourne `{error: 'not_authenticated'}` |
| **Rôle non-étudiant**: commercial essaie de s'auto-référer | ✅ RPC vérifie role = 'student' |

### 3.2 Compteur de commissions (referral_commissions)

| Test | Résultat |
|------|----------|
| **Double commission même paiement** | ✅ UNIQUE (commercial_user_id, payment_id) + IF NOT EXISTS |
| **Cap dégressif** | ✅ fn_check_commission_cap retourne allowed=false si count >= max_cap |
| **Taux dégressif** | ✅ rate × 0.85^n (commission 1: 100%, commission 2: 85%, commission 3: 72%) |
| **Unités cohérentes** | ✅ Tout en fraction (0.12 = 12%) après FIX du 15 mars |
| **Plafond montant** | ✅ max_amount appliqué si > 0 |
| **Fenêtre expirée** | ✅ Vérifie attributed_at + 12 mois dans confirm_payment |
| **Paiement non confirmé** | ✅ Vérifie status = 'confirmed' |
| **Paiement sans montant** | ✅ Vérifie amount_paid > 0 |

### 3.3 Compteur de tier (fn_update_commercial_tier)

| Test | Résultat |
|------|----------|
| **Recalcul automatique** | ✅ Trigger AFTER INSERT/UPDATE/DELETE sur referral_commissions |
| **Seuils corrects** | ✅ COUNT(DISTINCT student_id) >= 5/15/30 → Silver/Gold/Diamond |
| **Compteur total_confirmed_payments** | ✅ COUNT(*) de toutes commissions (pending+approved+paid) |

---

## 4. OUTILS FLUTTER — VÉRIFICATION PACKAGES

| Package | Version | Rôle dans le flux commercial | Statut |
|---------|---------|------------------------------|--------|
| `supabase_flutter` | ^2.10.3 | Appels RPC, auth, realtime | ✅ À jour |
| `shared_preferences` | ^2.2.2 | Stockage code referral pré-login | ✅ À jour |
| `provider` | ^6.1.1 | State management (CommercialDashboardProvider) | ✅ À jour |
| `url_launcher` | ^6.2.5 | Partage lien WhatsApp/Facebook/Telegram | ✅ À jour |

**Aucun package obsolète ou déprécié** n'est utilisé dans le flux commercial.

---

## 5. CORRECTIONS APPLIQUÉES LE 15 MARS 2026

### Session 1 (Audit initial)
1. ✅ **ref_code/ref_link visibles admin** — Lecture depuis commercialsOverview
2. ✅ **Unités de taux unifiées** — fn_check_commission_cap divise par 100
3. ✅ **Double chemin commission supprimé** — Trigger désactivé
4. ✅ **Capture referral mobile** — Champ "Code de parrainage" à l'inscription
5. ✅ **Compteur tier aligné** — DISTINCT students vs COUNT(*)
6. ✅ **Domaine Netlify unifié** — Tous sur dulcet-snickerdoodle
7. ✅ **Doublons commission_rules** — Nettoyés (licence→Licence)

### Session 2 (Robustesse)
8. ✅ **UNIQUE INDEX corrigé** — (commercial_user_id, student_id) → (commercial_user_id, payment_id) — permet les commissions multiples par étudiant (une par paiement, jusqu'au cap)
9. ✅ **td_access rate corrigé** — 0.0 → 0.15 (15%) avec max 3000 XOF

---

## 6. CE QUI MANQUE ENCORE (ROADMAP FUTURE)

### P1 — Recommandé avant lancement commercial

| # | Amélioration | Effort | Impact |
|---|-------------|--------|--------|
| 1 | **Deep links Android** (App Links) pour capture automatique du code referral via lien cliqué sur mobile | 2-3h | Haut |
| 2 | **QR code** généré pour chaque commercial (affichable dans le dashboard) | 1-2h | Moyen |
| 3 | **Double-sided incentive** : petit bonus (ex: badge, priorité) pour l'étudiant qui utilise un code | 2-3h | Moyen |

### P2 — Post-lancement

| # | Amélioration | Effort | Impact |
|---|-------------|--------|--------|
| 4 | **Audit trail complet** : log chaque changement de statut commission (qui, quand, pourquoi) | 1-2h | Moyen |
| 5 | **Export CSV** des commissions pour comptabilité | 1h | Moyen |
| 6 | **Notifications détaillées** : "PRO-003 a souscrit à Licence Informatique — commission 3 000 XOF" | 1h | Haut |
| 7 | **Dashboard analytics** : conversion rate par commercial, CAC vs autres canaux | 3-4h | Moyen |

---

## 7. CONCLUSION

Le système commercial Academia est **fonctionnel et robuste** après les 9 corrections appliquées. Il couvre les standards essentiels de l'industrie :

- ✅ **Attribution first-click** avec code unique et fenêtre 12 mois
- ✅ **Anti-fraude** : contraintes DB, idempotence, cap dégressif
- ✅ **Gamification** : 4 tiers + 4 milestones + leaderboard
- ✅ **Transparence** : dashboard complet en 3 onglets
- ✅ **Anonymisation** : conforme RGPD
- ✅ **Multi-paiement** : commission sur chaque paiement (inscription, scolarité, TD...)
- ✅ **Admin control** : grille configurable, validation manuelle, suspension

Le flux **lien → inscription → prospect tracké → souscription → commission calculée → notification** est complet et protégé contre les cas limites (doublons, race conditions, codes invalides, commerciaux inactifs, fenêtre expirée).

**La confiance des commerciaux repose sur 3 piliers, tous en place :**
1. **Transparence** : ils voient chaque prospect, chaque paiement, chaque commission en temps réel
2. **Fiabilité** : les compteurs sont protégés par des contraintes DB, pas seulement du code applicatif
3. **Équité** : la grille est configurable, les taux dégressifs évitent les abus, les milestones récompensent la performance
