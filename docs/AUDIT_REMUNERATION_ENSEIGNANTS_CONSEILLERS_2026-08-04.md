# Audit — rémunération des enseignants et des conseillers d'orientation
## et proposition d'un mécanisme de commission indexée

**Date :** 4 août 2026
**Périmètre :** enseignant de TD, enseignant de cours en ligne, prépa concours,
conseiller d'orientation. Modèle de partage des revenus, soldes, reversements.
**Nature :** audit + proposition. **Un seul correctif appliqué** (§1), signalé
comme tel : il s'agissait d'un défaut qui prenait l'argent sans rendre le
service.

---

## 1. URGENT — corrigé pendant l'audit : tout paiement TD plantait

`app_confirm_ligdicash_payment` cherchait le professeur ainsi :

```sql
SELECT te.teacher_id FROM app.td_enrollments te WHERE te.payment_id = ...
```

**La colonne `teacher_id` n'existe pas.** Elle s'appelle `assigned_teacher_id`.

Conséquence, vérifiée en conditions réelles : toute confirmation d'un paiement
`td_access` levait `ERREUR 42703 : column te.teacher_id does not exist`, ce qui
faisait échouer la fonction entière. L'Edge Function renvoyait
`confirmation_rpc_failed`.

**L'étudiant était débité par LigdiCash, et son paiement n'était jamais
confirmé.** Ni accès TD, ni reçu, ni écriture comptable.

Le défaut ne se déclenchait que sur le chemin `td` — c'est pourquoi il a survécu :
un seul paiement TD existe en base, validé à la main en janvier 2026, avant que
ce code n'existe.

Corrigé et vérifié : le paiement TD aboutit désormais (`succes=true`, reçu émis).

---

## 2. Ce qui existe aujourd'hui

### 2.1 — Deux systèmes de rémunération parallèles

| | Registre | Bénéficiaires | Alimenté par |
|---|---|---|---|
| **Commissions d'apport** | `referral_commissions` | commercial (+ promoteur, créateur) | `app_generate_referral_commission_for_payment` |
| **Partage de revenus** | `actor_balances` | enseignant, université, marchand | `app_resolve_revenue_split` + `revenue_split_rules` |

Les deux coexistent volontairement : le bénéficiaire `commercial` est
**désactivé** dans `revenue_split_rules` pour éviter un double crédit.

### 2.2 — La table des partages, telle qu'elle est

| Motif | Répartition active | Total |
|---|---|---|
| `online_course` | enseignant 60 % · plateforme 30 % | **90 %** |
| `td_access` | enseignant 55 % · plateforme 30 % | **85 %** |
| `application_fee` | plateforme 85 % | **85 %** |
| `registration_fee` | plateforme 85 % | **85 %** |
| `tuition_deposit` | plateforme 90 % | **90 %** |
| `marketplace_purchase` | marchand 90 % · plateforme 10 % | 100 % |
| `subscription` | plateforme 100 % | 100 % |

**Aucune ligne ne totalise 100 %, sauf marketplace et abonnement.** Les 10 à
15 % manquants sont les parts « commercial » désactivées. L'argent reste
évidemment sur le compte de la plateforme — mais **il n'est écrit nulle part** :
le grand livre ne trace que ce qui est explicitement réparti. La comptabilité
est donc muette sur 15 % du chiffre d'affaires.

Deux lignes sont pires : `registration_fee` totaliserait **170 %** et
`tuition_deposit` **180 %** si les parts université étaient réactivées. Ce sont
des bombes à retardement : un simple `is_active = true` distribuerait plus que
l'argent encaissé.

### 2.3 — Ce qui n'existe pas du tout

| Sujet | État |
|---|---|
| Rémunération du **conseiller d'orientation** | **Néant** |
| Rémunération **prépa concours** | **Néant** — aucune règle |
| Type de bénéficiaire `counselor` | N'existe pas |
| Motif de paiement `orientation` | **N'existe pas dans l'enum** |
| Motif de paiement `prep_concours` | **N'existe pas dans l'enum** |
| Fonction de reversement conseiller | N'existe pas |

**Le conseiller d'orientation n'est pas payé, parce que l'élève ne paie pas.**
`orientation_counselors.tarif_fcfa` existe et est lu par `app_orientation_book`…
puis n'est utilisé nulle part. `orientation_bookings` ne porte **aucune colonne
de paiement**. La consultation est réservée, la salle est créée, l'entretien a
lieu — gratuitement, quel que soit le tarif affiché.

Le conseiller possède pourtant déjà un `payout_phone`. L'intention existait ;
la chaîne n'a jamais été construite.

### 2.4 — État réel des flux

```
Conseillers d'orientation ......... 2      Réservations ............. 0
Inscriptions TD ................... 1      Paiements TD ............. 1 (manuel, 01/2026)
Paiements cours en ligne .......... 0      Paiements abonnement ..... 0
Soldes dans actor_balances ........ 0      File de reversement ...... 0
```

**Aucun enseignant, aucun conseiller n'a jamais rien perçu par la plateforme.**
Le mécanisme de partage n'a jamais tourné une seule fois — d'abord parce que
`amount_paid` n'était pas écrit (corrigé aujourd'hui), ensuite parce que le
chemin TD plantait (§1).

### 2.5 — Un défaut de séquence : le professeur assigné après le paiement

Le partage cherche le professeur **au moment de la confirmation du paiement**.
Or l'inscription TD existante est `assignment_status = 'unassigned'` : le
professeur est désigné plus tard, par l'administration.

Vérifié : le paiement aboutit, mais la part enseignant n'est créditée à
personne, et **elle ne le sera jamais** — rien ne repasse au moment de
l'affectation. Le même problème se pose pour toute prestation dont
l'intervenant est désigné après l'encaissement.

---

## 3. Proposition — une règle unique, trois bénéficiaires

### 3.1 — Le principe

> **Tout paiement se répartit intégralement, à l'instant de l'encaissement,
> entre trois rôles au plus : celui qui a apporté l'élève, celui qui rend le
> service, et la plateforme. La somme fait toujours 100 %.**

Trois exigences en découlent :

1. **La somme vaut 100 %, toujours.** Une contrainte en base doit le garantir,
   plutôt qu'un contrôle de relecture. Aujourd'hui rien n'empêche 170 %.
2. **La part de la plateforme est un solde, pas un pourcentage.** Elle se calcule
   par différence : `plateforme = 100 % − apporteur − prestataire`. On ne peut
   alors plus distribuer plus qu'on n'a encaissé.
3. **Ce qui n'est attribué à personne revient à la plateforme, et s'écrit.**
   Aujourd'hui, les 15 % non répartis n'apparaissent dans aucune écriture.

### 3.2 — Grille proposée

Les taux ci-dessous sont une **base de discussion**, pas une recommandation
financière : je n'ai ni vos coûts, ni vos marges cibles.

| Prestation | Apporteur | Prestataire | Plateforme |
|---|---|---|---|
| **Consultation d'orientation** | commercial 10 % | conseiller **60 %** | 30 % |
| **TD (accès)** | commercial 10 % | enseignant **55 %** | 35 % |
| **Cours en ligne** | commercial 10 % | enseignant **60 %** | 30 % |
| **Prépa concours** | commercial 10 % | enseignant **50 %** | 40 % |
| Frais de dossier | commercial 15 % | — | 85 % |
| Frais d'inscription | commercial 15 % | — | 85 % |
| Acompte scolarité | commercial 10 % | — | 90 % |
| Achat de crédits IA | **0 %** | — | 100 % |
| Abonnement | à arbitrer | — | solde |

L'achat de crédits reste à 100 % plateforme, conformément à votre décision : ces
crédits financent OpenRouter, il n'y a pas de marge à partager.

Pourquoi la prépa concours rémunère moins que le TD : le contenu y est
mutualisé et réutilisé d'une session à l'autre, alors qu'un TD est un
accompagnement individuel. À vous de trancher.

### 3.3 — Ce qu'il faut construire

**a. Deux valeurs manquantes dans l'enum `payment_reason`** :
`orientation_consultation` et `prep_concours`. Sans elles, ces prestations ne
peuvent littéralement pas être facturées.

**b. Un type de bénéficiaire `counselor`**, avec sa fonction de reversement
`app_counselor_request_payout`, calquée sur celle de l'enseignant.

**c. Le paiement de la consultation d'orientation.** `app_orientation_book` lit
déjà le tarif ; il faut qu'elle crée la ligne de paiement, et que la
réservation ne devienne `confirmed` qu'une fois l'encaissement vérifié.
**Point de conception important** : un entretien d'orientation se paie
*d'avance* — sinon on ne peut rien récupérer après coup. Le créneau doit donc
être réservé, puis libéré si le paiement n'aboutit pas dans le délai imparti.

**d. Le rattrapage de l'intervenant désigné tardivement.** Deux options :

| Option | Fonctionnement | Avantage | Inconvénient |
|---|---|---|---|
| **Crédit différé** | La part du prestataire est mise en `pending_balance` sans destinataire, puis attribuée à l'affectation | Rien n'est perdu | Une écriture en attente à surveiller |
| **Crédit à l'affectation** | La part n'est calculée qu'au moment où l'intervenant est désigné | Simple | Le grand livre est incomplet entre les deux |

Je recommande le **crédit différé** : la part est due dès l'encaissement,
l'incertitude ne porte que sur le destinataire. C'est aussi ce que reflète
`actor_balances.pending_balance`, déjà présente et jamais utilisée.

**e. Une contrainte d'intégrité** sur `revenue_split_rules` : la somme des
pourcentages actifs d'un même motif ne peut pas dépasser 100 %. Aujourd'hui,
réactiver la part université ferait distribuer 170 %.

### 3.4 — Ordre de construction proposé

1. **Contrainte des 100 %** et écriture explicite de la part plateforme. Cela
   assainit l'existant avant d'y ajouter quoi que ce soit.
2. **Rattrapage de l'intervenant tardif** — sans quoi les enseignants de TD ne
   seront jamais payés, même une fois tout le reste en place.
3. **Bénéficiaire `counselor` + reversement.**
4. **Paiement de la consultation d'orientation** (le plus gros morceau :
   enum, RPC de réservation, écran de paiement, libération du créneau).
5. **Prépa concours** : décider d'abord du modèle — à la séance, ou inclus dans
   l'abonnement. Les deux se défendent, mais ils ne se codent pas pareil.

---

## 4. Décisions qui vous reviennent

Je ne les prends pas à votre place ; elles conditionnent le reste.

1. **Les taux du tableau §3.2** — les miens sont des points de départ alignés
   sur l'existant (55 % TD, 60 % cours), pas une recommandation financière.
2. **La prépa concours est-elle vendue à la séance, ou incluse dans
   l'abonnement ?** Le partage n'a de sens que dans le premier cas.
3. **La consultation d'orientation est-elle payante ?** Aujourd'hui elle est
   gratuite dans les faits, quel que soit le tarif affiché. Si elle doit le
   rester, il faut retirer `tarif_fcfa` de l'écran plutôt que d'afficher un prix
   qui n'est jamais réclamé.
4. **`application_fee` et `td_access` rémunèrent-ils le commercial ?** Question
   restée ouverte depuis hier, et qui bloque la ligne « apporteur » du tableau.

---

## 5. Limites de cet audit

- Les taux existants (55 %, 60 %, 30 %) n'ont pas été confrontés à vos coûts
  réels : je constate ce qui est configuré, je ne juge pas si c'est rentable.
- Le module marketplace n'a été regardé que pour comparaison (90/10, cohérent).
- Aucun flux n'ayant jamais abouti, **rien de ce modèle n'a été éprouvé en
  conditions réelles**. Le premier paiement TD ou cours réellement encaissé sera
  le vrai test.
- Le correctif du §1 a été appliqué directement en base par remplacement ciblé
  dans le corps de la fonction. Il est vérifié, mais **il n'est pas encore dans
  le dépôt** : `supabase/functions` ne contient pas les RPC SQL. La question du
  versionnement des fonctions de base de données reste entière.
