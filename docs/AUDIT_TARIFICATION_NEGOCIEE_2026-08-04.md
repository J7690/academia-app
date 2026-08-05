# Audit — tarification négociée (TD, orientation) et commission indexée

**Date :** 4 août 2026
**Demande :** paramétrer le coût d'une séance selon la **matière** et le **niveau
de l'enseignant** ; faire transiter la demande de l'étudiant par l'administrateur
vers un enseignant ou un conseiller ; fixer **ensemble** le montant selon le
volume horaire et le besoin ; appliquer un **pourcentage au commercial**, limité
à **3 mois** après l'inscription du prospect.

---

## 1. La bonne surprise : le moteur d'indexation existe déjà

`app.commission_rules` implémente **exactement** la structure demandée, et elle
est **active** :

| Motif | Niveau | Taux | Plafond | Priorité |
|---|---|---|---|---|
| `registration_fee` | Doctorat | 15 % | 50 000 | 30 |
| `registration_fee` | Master | 15 % | 40 000 | 30 |
| `registration_fee` | LMD / Licence | 12 % | 25 000 | 30 |
| `registration_fee` | BTS | 10 % | 15 000 | 30 |
| `application_fee` | `*` | 20 % | 5 000 | 10 |
| **`td_access`** | `*` | **15 %** | **3 000** | 10 |
| `tuition_deposit` | `*` | 5 % | 20 000 | 10 |
| `*` | `*` | 8 % | 10 000 | 0 |

Taux **par motif × niveau**, **plafond absolu**, **priorité** avec repli sur le
joker. C'est la mécanique d'indexation demandée — elle n'a jamais servi, faute
de paiements aboutis.

**Il n'y a donc pas de moteur à inventer.** Il faut y ajouter deux dimensions
(matière, grade de l'enseignant) et une borne temporelle.

---

## 2. Le parcours « demande » : à moitié fait côté TD, absent côté orientation

### TD

| Pièce | État |
|---|---|
| `td_student_requests` | Existe — matière, niveau, modalité, créneau souhaité |
| `app_admin_update_td_program_price(programme, prix, statut)` | Existe |
| `app_td_admin_assign_teacher(inscription, enseignant)` | Existe |
| `td_teacher_profiles.hourly_rate` | Colonne présente, **table vide** |

Parcours réel : l'étudiant dépose une demande → l'administrateur crée un
programme et **fixe le prix seul** → l'étudiant paie.
**L'enseignant n'intervient jamais dans le prix.** Il est affecté *après*.

### Orientation

| Pièce | État |
|---|---|
| Demande, transmission, négociation | **Néant** — l'élève réserve un créneau directement |
| Paiement | **Néant** — `orientation_bookings` n'a aucune colonne de prix |
| `orientation_counselors.tarif_fcfa` | Existe, **vaut 0 pour les deux conseillers** |

### État réel

```
Demandes TD ......... 1 (« pending », jamais traitée)   Programmes TD .... 2
Profils enseignants . 0 (taux horaire jamais renseigné) Enseignants TD ... 2
Conseillers ......... 2 (tarif à 0)                     Réservations ..... 0
```

---

## 3. Les angles morts

### 3.1 — La fenêtre est de 12 mois, et elle est unique

```sql
IF v_payment.confirmed_at > v_ref.attributed_at + INTERVAL '1 year' THEN
    RETURN 'outside_12_month_window';
```

Vous demandez **3 mois**. Surtout, la borne est **la même pour tous les motifs** :
impossible d'avoir 12 mois sur les frais d'inscription et 3 mois sur les TD.
**La durée doit devenir une propriété de la règle**, comme le taux et le plafond.

### 3.2 — Le point de départ des 3 mois est ambigu

| Date | Colonne | Sens |
|---|---|---|
| Création du compte | `auth.users.created_at` | L'élève arrive sur Academia |
| **Attribution au commercial** | `user_referrals.attributed_at` | Le lien de parrainage est posé |

Le générateur utilise `attributed_at`. **Je le conserve** : si un élève s'inscrit
seul puis est démarché deux mois plus tard, la fenêtre doit courir depuis le
démarchage — sinon le commercial travaille pour rien.

### 3.3 — Le devis n'existe nulle part

Rien ne porte : montant proposé, volume horaire, matière, qui a proposé, qui a
validé, et le lien vers le paiement. Sans cet objet, le prix reste une colonne
écrasable sur `td_programs`, sans historique ni preuve.

### 3.4 — Prix payé ≠ rémunération du prestataire

`revenue_split_rules` donne à l'enseignant 55 % du montant. Dans un modèle
négocié, il faut pouvoir exprimer **les deux** : ce que paie l'élève, et ce que
touche le prestataire. Le devis doit porter les deux montants — c'est ce qui
permet de ne pas trancher aujourd'hui entre « partage » et « marge ».

---

## 4. Ce que j'ai construit

Conformément à votre instruction. Détail dans
`CONSTRUCTION_DEVIS_ET_COMMISSION_2026-08-04.md`.

1. **`window_days` par règle** — 90 jours sur les prestations négociées,
   365 ailleurs. La borne sort du code.
2. **`subject` et `teacher_grade` sur `commission_rules`** — l'indexation par
   matière et par niveau d'enseignant.
3. **`app.prestation_devis`** — l'objet manquant, commun aux trois offres.
4. **Les RPC du parcours** : déposer, transmettre, chiffrer, proposer, accepter.
5. **Les motifs `orientation_consultation` et `prep_concours`** dans l'enum.
6. **Le bénéficiaire `counselor`** et son reversement.

---

## 5. Décisions qui restent vôtres

1. **Les taux par matière et par grade** — j'ai posé une grille de départ, pas
   une recommandation financière.
2. **La prépa concours** suit-elle ce parcours négocié, ou reste-t-elle au
   catalogue ?
3. **Le conseiller** est-il payé à la consultation ou au forfait ?
4. `application_fee` et `td_access` rémunèrent-ils le commercial ? (question
   ouverte depuis le 03/08, elle conditionne la ligne « apporteur »)
