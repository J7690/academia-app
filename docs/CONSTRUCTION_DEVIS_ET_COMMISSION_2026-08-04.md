# Construction — devis négocié et commission indexée (04/08/2026)

Suite de `AUDIT_TARIFICATION_NEGOCIEE_2026-08-04.md`.
Tout ce qui suit est **appliqué en production** et vérifié par un parcours
complet, exécuté puis **annulé** (aucune donnée de test ne subsiste).

---

## 1. Une erreur de ma part, corrigée en cours de route

J'avais d'abord indexé `app_generate_referral_commission_for_payment`. Le test
en conditions réelles a montré que **ce n'est pas elle qui décide** : la
commission produite portait `share_scenario = first_click_100` et
`beneficiary_role = owner` — signature de
`app_generate_commission_split_for_payment`, appelée directement par la
confirmation de paiement.

Le vrai résolveur est `app.fn_resolve_commission_rate`. C'est lui que j'ai
enrichi. Sans ce test, j'aurais livré une indexation branchée sur une fonction
morte.

---

## 2. Ce qui a été construit

### 2.1 — L'indexation par matière et par grade

`app.commission_rules` portait déjà taux × plafond × priorité, indexés par
motif × niveau. Trois colonnes s'y ajoutent :

| Colonne | Rôle |
|---|---|
| `subject` | La matière, ou `*` |
| `teacher_grade` | Le grade du prestataire, ou `*` |
| `window_days` | **La fenêtre de commission, par règle** |

`app.fn_resolve_commission_rate` accepte désormais quatre critères et retourne
la fenêtre. **La spécificité prime sur la priorité** : une règle qui nomme la
matière *et* le grade l'emporte sur une règle générale de priorité supérieure.

Vérifié :

| Demande | Règle retenue | Taux |
|---|---|---|
| maths + agrégé | TD maths — enseignant agrégé | 10 % |
| maths + autre grade | TD maths — tous grades | 15 % |
| anglais | Accès TD (général) | 15 % |
| orientation | Consultation d'orientation | 12 % |

L'unicité portait sur `(motif, niveau)` — elle empêchait d'écrire une règle
« TD, maths, agrégé » à côté de « TD, toutes matières ». Elle porte désormais
sur les quatre dimensions.

### 2.2 — La fenêtre de 3 mois

La borne était écrite en dur dans le générateur : `INTERVAL '1 year'`,
identique pour tous les motifs. Elle vient maintenant de la règle.

**90 jours** sur les prestations négociées — `td_access`, `online_course`,
`orientation_consultation`, `prep_concours`. Les frais de dossier, d'inscription
et la scolarité gardent leur année : un dossier universitaire se joue sur une
année scolaire, pas sur un trimestre.

Le point de départ reste `user_referrals.attributed_at` — la date d'attribution
du prospect au commercial, non celle de création du compte. Si un élève s'inscrit
seul puis est démarché deux mois plus tard, la fenêtre court depuis le
démarchage : sinon le commercial travaillerait pour rien.

Vérifié : à 200 jours, `generated = false`.

### 2.3 — Le devis de prestation

`app.prestation_devis` — l'objet qui manquait, commun aux quatre offres (TD,
orientation, prépa, cours). Il porte la demande, le chiffrage, les deux montants
et l'état.

**Pourquoi deux montants.** `montant_total` est ce que paie l'élève ;
`part_prestataire` ce que touche l'enseignant ou le conseiller. Les porter tous
les deux permet d'exprimer un partage en pourcentage **comme** une marge ajoutée
au-dessus du tarif du prestataire — sans figer aujourd'hui le modèle économique.

Le parcours, avec une règle d'autorisation par transition :

```
1. depose      élève         → app_devis_deposer
2. transmis    administrateur → app_devis_transmettre
3. chiffre     prestataire    → app_devis_chiffrer
4. propose     administrateur → app_devis_proposer
5. accepte     élève          → app_devis_accepter   (crée le paiement)
6. paye        encaissement   → part + commission
   refuse / annule : élève, prestataire ou administrateur
```

Deux garde-fous inscrits dans les fonctions :
- on ne propose pas à l'élève un prix **inférieur** à la part du prestataire ;
- une prestation **déjà payée** ne se refuse pas — elle se rembourse.

Aucune écriture directe sur la table : la logique vit dans les RPC, pas dans
l'application. Les `GRANT` sont explicites, un par un, conformément à la
fermeture par défaut posée ce matin.

### 2.4 — Deux motifs de paiement créés

`orientation_consultation` et `prep_concours` rejoignent l'énumération
`payment_reason`. Sans eux, ces prestations ne pouvaient littéralement pas être
facturées.

---

## 3. Vérification de bout en bout

Parcours complet exécuté puis **annulé** :

```
1. dépôt        : depose
2. transmission : transmis
3. chiffrage    : chiffre        (enseignant demande 20 000 pour 10 h)
4. proposition  : propose        (prix élève 30 000)
5. acceptation  : accepte        (paiement DEV-…)
6. encaissement : succès

   élève paie ........ 30 000
   part enseignant ... 20 000
   marge plateforme .. 10 000
   commission ........ 600

   au-delà de 90 jours : generated = false
```

État après annulation : 0 devis, 0 commission, 0 paiement de devis,
`td_access` toujours non rémunérateur, attribution du prospect intacte.
**Rien n'a persisté.**

---

## 4. Le point qui appelle votre arbitrage

**Le taux personnel du commercial plafonne la grille.**

`fn_check_commission_cap` calcule `commercial_profiles.commission_rate × 0,85ⁿ`
(dégressif au fil des commissions sur un même élève), puis le générateur retient
`LEAST(taux de la grille, taux du commercial)`.

Dans le test : grille à 15 %, commercial à 2 % → **2 % appliqués**, soit 600 F
au lieu des 4 000 F du plafond de la règle.

Ce n'est pas un défaut : c'est une règle en place, et elle est défendable — le
contrat individuel prime sur le barème. Mais elle **neutralise en grande partie
l'indexation que vous demandez** : régler finement les taux par matière et par
grade ne servira à rien tant que le taux individuel est plus bas.

Trois options :

| Option | Effet |
|---|---|
| **Garder** | Le contrat individuel prime. L'indexation ne joue que pour les commerciaux à taux élevé. |
| **Inverser** | La grille prime, le taux individuel devient un plancher. L'indexation reprend tout son sens. |
| **Supprimer le taux individuel** | Une seule source : la grille. Le plus simple à expliquer et à auditer. |

Je n'ai rien changé : c'est votre modèle de rémunération, pas une question
technique.

---

## 5. Ce qui reste à faire

| # | Élément | Pourquoi ce n'est pas fait |
|---|---|---|
| 1 | **Grille tarifaire par matière × grade** | Deux règles d'exemple seulement (`maths/agrégé` 10 %, `maths/tous` 15 %). La grille réelle est une décision commerciale. |
| 2 | **Bénéficiaire `counselor` + reversement** | Dépend de la réponse au §4 et du mode de rémunération du conseiller (à la consultation ou au forfait). |
| 3 | **Écrans Flutter** | Demande élève, transmission admin, chiffrage prestataire, acceptation. Le socle serveur est prêt et testé ; l'interface reste à construire. |
| 4 | **Rattrapage du prestataire désigné tardivement** | Signalé dans l'audit précédent : le TD assigne l'enseignant après le paiement, sa part n'est alors créditée à personne. |
| 5 | **Versionnement des RPC** | Les fonctions SQL ne sont pas dans le dépôt. C'est un angle mort structurel, indépendant de ce chantier. |

---

## 6. Décisions attendues

1. **Le taux individuel : plafond, plancher, ou supprimé ?** (§4) — c'est la
   plus structurante : elle décide si l'indexation sert à quelque chose.
2. **La grille réelle** par matière et par grade.
3. **Le conseiller** : payé à la consultation ou au forfait ?
4. **La prépa concours** suit-elle le parcours négocié, ou reste-t-elle au
   catalogue ?
5. `application_fee` et `td_access` **rémunèrent-ils le commercial ?**
   (ouverte depuis le 03/08 — aujourd'hui non, donc aucune commission TD ne
   sera générée tant que ce n'est pas tranché)
