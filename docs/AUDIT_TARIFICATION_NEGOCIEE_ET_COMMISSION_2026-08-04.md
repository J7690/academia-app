# Audit — tarification négociée (TD, orientation) et commission indexée
## Ce qui existe, ce qui manque, et le mécanisme proposé

**Date :** 4 août 2026
**Demande :** pouvoir paramétrer le coût d'une séance selon la matière et le
niveau de l'enseignant ; faire transiter la demande de l'étudiant par
l'administrateur vers un enseignant ou un conseiller ; fixer ensemble le montant
selon le volume horaire et le besoin ; appliquer un pourcentage au commercial,
**limité à 3 mois après l'inscription du prospect**.

---

## 1. La bonne surprise : le moteur de commission indexée existe déjà

`app.commission_rules` implémente **exactement** la structure demandée, et elle
est **active** :

| Motif | Niveau | Taux | Plafond | Priorité |
|---|---|---|---|---|
| `registration_fee` | Doctorat | 15 % | 50 000 | 30 |
| `registration_fee` | Master / Master1 | 15 % | 40 000 | 30 |
| `registration_fee` | LMD / Licence | 12 % | 25 000 | 30 |
| `registration_fee` | BTS | 10 % | 15 000 | 30 |
| `registration_fee` | `*` | 12 % | 25 000 | 20 |
| `application_fee` | `*` | 20 % | 5 000 | 10 |
| **`td_access`** | `*` | **15 %** | **3 000** | 10 |
| `tuition_deposit` | `*` | 5 % | 20 000 | 10 |
| `*` | `*` | 8 % | 10 000 | 0 |

Taux **par motif × niveau**, **plafond en valeur absolue**, **priorité** avec
repli sur le joker `*`. C'est la mécanique d'indexation que vous décrivez —
elle n'a simplement jamais servi, faute de paiements aboutis.

**Conséquence pour la suite : il n'y a pas de moteur à inventer.** Il faut y
ajouter deux dimensions (matière, niveau de l'enseignant) et une borne
temporelle.

---

## 2. Le parcours « demande » existe côté TD, pas côté orientation

### 2.1 — TD : la moitié du chemin est faite

| Pièce | État |
|---|---|
| `td_student_requests` | Existe — `field_id, level, subject, description, preferred_modality, preferred_schedule, status, handled_by_admin_id, created_program_id` |
| `app_admin_update_td_program_price(programme, prix, statut)` | Existe |
| `app_td_admin_assign_teacher(inscription, enseignant)` | Existe |
| `td_teacher_profiles.hourly_rate` | **Colonne présente, table vide, jamais utilisée** |
| `td_programs.price` | Existe |

Le parcours réel aujourd'hui : l'étudiant dépose une demande → l'administrateur
crée un programme et **fixe le prix seul** → l'étudiant s'inscrit et paie.

**L'enseignant n'intervient jamais dans la fixation du prix.** Il est affecté
*après*, à l'inscription. Aucun objet ne modélise « l'administrateur et
l'enseignant conviennent d'un montant ».

### 2.2 — Orientation : rien du tout

| Pièce | État |
|---|---|
| Demande d'orientation | **N'existe pas** — l'élève réserve directement un créneau |
| Passage par l'administrateur | **N'existe pas** |
| Négociation du montant | **N'existe pas** |
| Paiement | **N'existe pas** — `orientation_bookings` n'a aucune colonne de prix |
| `orientation_counselors.tarif_fcfa` | Existe, **vaut 0 pour les deux conseillers** |

L'orientation est un tarif forfaitaire par conseiller, affiché, jamais réclamé.
Le modèle que vous décrivez — demande, transmission, devis — **est à construire
intégralement**.

### 2.3 — État réel

```
Demandes TD .................. 1 (statut « pending », jamais traitée)
Programmes TD ................ 2  · dont avec prix : 1
Profils enseignants TD ....... 0  · avec taux horaire : 0
Enseignants TD ............... 2
Conseillers .................. 2  · avec tarif : 0
```

---

## 3. Les angles morts

### 3.1 — La fenêtre de commission est de 12 mois, pas 3

`app_generate_referral_commission_for_payment` :

```sql
IF v_payment.confirmed_at > v_ref.attributed_at + INTERVAL '1 year' THEN
    RETURN 'outside_12_month_window';
```

Vous demandez **3 mois** pour ces prestations. Et la borne actuelle est
**unique** pour tous les motifs : il n'existe aucun moyen d'avoir 12 mois sur les
frais d'inscription et 3 mois sur les TD. **La durée doit devenir une propriété
de la règle**, comme le taux et le plafond.

À noter : `commission_share_config.promoter_window_days` vaut 30 — mais c'est une
fenêtre différente (attribution du promoteur), à ne pas confondre.

### 3.2 — Le point de départ des 3 mois est ambigu

Vous dites « après l'inscription du prospect sur la plateforme ». Trois dates
candidates existent, et elles diffèrent :

| Date | Colonne | Sens |
|---|---|---|
| Création du compte | `auth.users.created_at` | L'élève s'inscrit sur Academia |
| **Attribution au commercial** | `user_referrals.attributed_at` | Le lien de parrainage est enregistré |
| Premier paiement | `application_payments.confirmed_at` | — |

Le générateur utilise aujourd'hui `attributed_at`. **Je recommande de le
conserver** : c'est la date qui rattache l'élève au commercial, donc celle qui
fonde son droit. Si un élève s'inscrit seul puis est démarché trois mois plus
tard, la fenêtre doit courir depuis le démarchage, pas depuis l'inscription.
**À confirmer.**

### 3.3 — Le devis n'existe nulle part

Aucune table ne porte : montant proposé, volume horaire, matière, qui a proposé,
qui a validé, quand, et le lien vers le paiement qui en découle. Sans cet objet :

- on ne peut pas tracer **qui a fixé quel prix** ;
- on ne peut pas rouvrir une négociation ;
- on ne peut pas prouver à l'enseignant la base de sa rémunération ;
- le prix reste une colonne écrasable sur `td_programs`, sans historique.

### 3.4 — La commission se calcule sur un prix, pas sur une négociation

Le générateur lit `amount_paid`. Dans un modèle négocié, c'est correct — mais
**la règle applicable doit être choisie selon la matière et le niveau**, données
qui ne sont aujourd'hui rattachées ni au paiement, ni à la commission.

### 3.5 — Le prix payé et la rémunération du prestataire sont deux choses

Aujourd'hui `revenue_split_rules` donne à l'enseignant **55 % du montant**. Dans
un modèle négocié, ce n'est plus tenable : si l'enseignant et l'administrateur
conviennent de 20 000 FCFA pour dix heures, la question devient *« que touche
l'enseignant sur ces 20 000 ? »* — un pourcentage, ou le montant qu'il a lui-même
demandé, la plateforme ajoutant sa marge par-dessus ?

**Deux modèles économiques opposés, à trancher :**

| Modèle | Fonctionnement | Conséquence |
|---|---|---|
| **Partage** | Le prix est fixé, chacun en prend un pourcentage | L'enseignant subit la remise commerciale |
| **Marge** | L'enseignant annonce son tarif, la plateforme ajoute sa marge et la commission par-dessus | L'enseignant est garanti, l'élève paie plus |

Le second correspond mieux à ce que vous décrivez (« ensemble ils définissent le
montant à fournir »), mais il change la façon dont le prix affiché à l'élève est
construit. **C'est la décision structurante de tout ce chantier.**

---

## 4. Mécanisme proposé

### 4.1 — Un objet « devis de prestation »

Une table unique pour les trois offres (TD, orientation, prépa), portant :

- le **demandeur** et sa demande (matière, niveau, volume horaire souhaité) ;
- le **prestataire** pressenti (enseignant ou conseiller) ;
- le **montant convenu**, le **volume horaire retenu**, la **part prestataire** ;
- **qui a proposé, qui a validé, quand** ;
- l'**état** : brouillon → proposé → accepté par l'élève → payé → honoré ;
- le **paiement** qui en découle.

Cet objet devient la pièce comptable de référence : la commission comme la
rémunération s'y adossent, au lieu de dépendre d'une colonne `price` écrasable.

### 4.2 — Trois dimensions ajoutées à `commission_rules`

La table gère déjà motif × niveau. Il faut y ajouter :

| Dimension | Pourquoi |
|---|---|
| `subject` (matière) | Une heure de mathématiques ne se négocie pas comme une heure d'anglais |
| `teacher_grade` (niveau de l'enseignant) | Un agrégé et un étudiant en master ne coûtent pas pareil |
| **`window_days`** | La borne temporelle par règle — 90 jours ici, 365 ailleurs |

La résolution reste celle qui existe : la règle la plus spécifique gagne, avec
repli sur le joker. Aucune réécriture du moteur.

### 4.3 — Le parcours cible

```
1. L'élève dépose une demande      (matière, niveau, volume, besoin)
2. L'administrateur la transmet    à un enseignant ou un conseiller
3. Les deux conviennent du montant (volume horaire × tarif du prestataire)
4. Le devis est proposé à l'élève
5. L'élève accepte et paie
6. À l'encaissement :
      · part prestataire  → actor_balances
      · commission        → SI le commercial existe ET dans les 90 jours
      · solde             → plateforme
```

**Le point important de l'étape 6** : la commission n'est due que si l'élève a
été apporté par un commercial **et** que la prestation est payée dans les
90 jours suivant son attribution. Au-delà, la plateforme conserve la part.

### 4.4 — Ce qu'il faut construire

| # | Élément | Nature |
|---|---|---|
| 1 | `window_days` sur `commission_rules` | Colonne + lecture dans le générateur |
| 2 | `subject` et `teacher_grade` sur `commission_rules` | Colonnes + résolution |
| 3 | Table `prestation_devis` | Nouvelle |
| 4 | RPC : créer / proposer / accepter / refuser un devis | Nouvelles |
| 5 | Motifs `orientation_consultation` et `prep_concours` dans l'enum | Migration |
| 6 | Bénéficiaire `counselor` + reversement | Nouvelles |
| 7 | Grille tarifaire par matière × niveau d'enseignant | Nouvelle table |
| 8 | Écrans : demande élève, transmission admin, devis prestataire | Flutter |

---

## 5. Décisions requises avant construction

Je ne les tranche pas : elles engagent votre modèle économique.

1. **Partage ou marge ?** (§3.5) — la décision structurante.
2. **Point de départ des 90 jours** : attribution au commercial (recommandé) ou
   création du compte ?
3. **Qui fixe le prix final** : l'administrateur seul après avis de l'enseignant,
   ou accord explicite des deux ?
4. **L'élève peut-il refuser et renégocier**, ou le devis est-il ferme ?
5. **La prépa concours** est-elle concernée par ce parcours négocié, ou reste-t-elle
   au catalogue ?
6. **Le conseiller d'orientation** est-il payé à la consultation, ou au forfait
   mensuel ?

---

## 6. Ce que j'ai appliqué à ce stade

**Rien.** Cet audit est en lecture seule, hormis le correctif TD documenté dans
`AUDIT_REMUNERATION_ENSEIGNANTS_CONSEILLERS_2026-08-04.md` §1 (colonne
`teacher_id` inexistante, qui faisait échouer tout paiement TD).

La suite dépend des six décisions ci-dessus — en particulier de la première,
qui change la structure même du devis.
