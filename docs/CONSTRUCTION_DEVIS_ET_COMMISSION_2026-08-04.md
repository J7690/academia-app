# Construction — devis négocié et commission indexée éditable (04/08/2026)

Suite de `AUDIT_TARIFICATION_NEGOCIEE_2026-08-04.md`.
**Appliqué en production**, vérifié par un parcours complet exécuté puis
**annulé** — aucune donnée de test ne subsiste.

---

## 1. Deux erreurs de ma part, trouvées par le test

**a) J'avais indexé la mauvaise fonction.** Le test réel a montré que la
commission venait de `app_generate_commission_split_for_payment` (signature
`share_scenario = first_click_100`), pas de
`app_generate_referral_commission_for_payment` que je modifiais. Le vrai
résolveur est `app.fn_resolve_commission_rate`.

**b) Les surcharges se sont empilées.** Chaque ajout de paramètre crée une
*nouvelle* fonction au lieu de remplacer l'ancienne. Trois versions du résolveur
coexistaient : un appel à quatre arguments devenait ambigu
(`function ... is not unique`) et **faisait échouer la confirmation de
paiement**. Les anciennes signatures ont été supprimées après vérification des
appelants.

Sans exécution réelle, ces deux défauts seraient partis en production.

---

## 2. Ce qui est en place

### 2.1 — TD indexé, et les autres prestations avec lui

| Motif | Rémunère | Notifie |
|---|---|---|
| `td_access` | **✅ (04/08)** | ✅ |
| `orientation_consultation` | **✅ (04/08)** | ✅ |
| `prep_concours` | **✅ (04/08)** | ✅ |
| `online_course` | **✅ (04/08)** | ✅ |
| `registration_fee`, `tuition_deposit` | ✅ | ✅ |
| `application_fee` | ❌ *(en attente)* | ❌ |
| `credit_purchase` | ❌ *(décision du 04/08)* | ❌ |

### 2.2 — La hiérarchie des taux, explicite

```
1. surcharge   (ce commercial, cette offre)      ← la plus précise
2. grille      (offre × niveau × matière × grade)
3. repli       (8 %)
```

**Le taux personnel n'écrase plus la grille.** Le générateur retenait
`LEAST(grille, taux du commercial)` : un commercial à 2 % ne dépassait jamais
2 %, même sur une offre réglée à 15 % — l'indexation ne servait à rien. La
dégressivité anti-cumul (0,85ⁿ sur un même élève) est conservée, mais elle
s'applique désormais au taux **résolu**, non plus au taux du profil.

### 2.3 — Édition par l'administrateur et par le manager

| RPC | Qui | Portée |
|---|---|---|
| `app_commission_grille_upsert` | administrateur | grille générale |
| `app_commission_taux_commercial_definir` | administrateur **ou manager** | un commercial × une offre |
| `app_commission_grilles_lister` | encadrement | admin : tout · manager : son équipe |
| `app_commission_simuler` | encadrement | « ce commercial, cette offre, combien ? » |

Le manager ne touche pas à la grille générale — ce serait lui donner la main sur
les équipes des autres. Il règle le taux **des commerciaux de son équipe**, et
un manager désactivé ou suspendu ne peut plus rien régler (`can_manager_act()`).

`app_commission_simuler` existe pour que l'interface montre l'effet **avant**
de valider : le taux, son origine, le plafond, la fenêtre et le montant.

### 2.4 — La fenêtre de 3 mois

`window_days` est une colonne de la règle. **90 jours** sur les quatre
prestations négociées ; un an conservé sur les frais d'inscription et la
scolarité — un dossier universitaire se joue sur une année scolaire.

Le point de départ reste `user_referrals.attributed_at` : si un élève s'inscrit
seul puis est démarché deux mois plus tard, la fenêtre court depuis le
démarchage.

### 2.5 — Le devis

`app.prestation_devis` porte la demande, le chiffrage et **deux montants** :
`montant_total` (ce que paie l'élève) et `part_prestataire` (ce que touche
l'enseignant). Les deux permettent d'exprimer un partage en pourcentage *comme*
une marge, sans figer le modèle.

Parcours : `depose → transmis → chiffre → propose → accepte → paye`, une règle
d'autorisation par transition. Deux garde-fous : on ne propose pas un prix
inférieur à la part du prestataire ; une prestation payée ne se refuse pas.

---

## 3. Vérification de bout en bout

```
A. grille seule       : 15,00 %  →  4 000 F   (plafond atteint)   origine : grille
B. manager règle 18 % : accepté (par manager)
   après surcharge    : 18,00 %  →  5 400 F   origine : surcharge_commercial
C. encaissement 30 000: commission 5 400 F au taux 0,18
D. au-delà de 90 jours: generated = false
```

Le parcours complet a été joué : dépôt élève → transmission admin → chiffrage
enseignant (20 000 pour 10 h) → prix élève 30 000 → acceptation → encaissement.

État après annulation : 0 devis, 0 commission, 0 surcharge, 0 paiement de devis,
attribution du prospect intacte. **Rien n'a persisté.**

---

## 4. Ce qui reste

| # | Élément | Nature |
|---|---|---|
| 1 | **Écrans Flutter** : demande élève, transmission admin, chiffrage prestataire, acceptation, et les deux écrans de réglage des grilles | Le socle serveur est prêt et testé ; l'interface reste entière |
| 2 | **Grille tarifaire réelle** par matière × grade | Décision commerciale — deux règles d'exemple seulement |
| 3 | **Bénéficiaire `counselor` + reversement** | Dépend du mode de rémunération du conseiller |
| 4 | **Rattrapage du prestataire désigné tardivement** | Le TD assigne l'enseignant après le paiement : sa part n'est créditée à personne |
| 5 | `application_fee` rémunère-t-il le commercial ? | Ouvert depuis le 03/08 |
| 6 | **Versionnement des RPC** | Les fonctions SQL ne sont pas dans le dépôt — angle mort structurel |
