# VALIDATION LOT A – FICHES BOBODO

**Date** : 8 juin 2026  
**Objectif** : Valider que les fiches du LOT A correspondent exactement au fonctionnement réel d'Academia  
**Méthode** : Audit du code réel (écrans, providers, RPC, enums)

---

## 1. CANDIDATURES

### 1.1 Étapes réelles (basées sur le code)

**RPC utilisée** : `app_create_application`

**Paramètres réels** :
- `p_program_id` (UUID, obligatoire)
- `p_motivation_text` (TEXT, optionnel)
- `p_requested_degree_level` (TEXT, optionnel)
- `p_requested_study_mode` (TEXT, optionnel)
- `p_requested_schedule` (TEXT, optionnel)
- `p_discount_requested` (BOOLEAN, optionnel)
- `p_discount_details` (TEXT, optionnel)
- `p_student_comment` (TEXT, optionnel)

**Dialog utilisateur** (`application_request_dialog.dart`) :
1. Niveau d'étude souhaité (TextField)
2. Mode d'étude souhaité (TextField - présentiel, en ligne, etc.)
3. Disponibilités / horaires préférés (TextField, 2 lignes)
4. Checkbox : "Je souhaite demander une réduction ou un échelonnement des frais"
5. Si réduction cochée : Détail de la demande (TextField, 3 lignes)
6. Commentaire pour l'université / l'équipe (TextField, 3 lignes)

**Validation** : Au moins un champ parmi niveau, mode ou horaires doit être rempli. Si réduction cochée, le détail est obligatoire.

**Erreur dossier incomplet** : La RPC retourne `dossier_incomplete` si le profil académique de l'étudiant n'est pas complet.

---

### 1.2 Documents réellement demandés

**Formats acceptés** (dans `student_application_detail_screen.dart`) :
- pdf
- jpg
- jpeg
- png
- doc
- docx

**Upload** : Via FilePicker avec `withData: true`, un seul fichier à la fois.

**Type** : 'document'

**Obligation** : Aucune information dans le code ne précise quels documents sont obligatoires vs facultatifs. C'est géré par la validation côté RPC (`dossier_incomplete`).

---

### 1.3 Actions réellement disponibles

**Dans l'onglet Candidatures** (`student_applications_tab.dart`) :
- Filtrer par statut (tous, draft, submitted, under_review, accepted, rejected, canceled)
- Cliquer sur une candidature pour voir le détail

**Dans l'écran détail** (`student_application_detail_screen.dart`) :
- Onglet "Détails" : informations de la candidature
- Onglet "Documents" : ajouter des documents (bouton flottant +)
- Onglet "Messages" : messagerie avec l'université
- Onglet "Paiements" : déclarer un paiement, voir l'historique

---

## 2. STATUTS DE CANDIDATURE

### 2.1 Statuts réellement utilisés

**Enum** : Non trouvé dans le code SQL audité. Les statuts sont stockés comme TEXT.

**Statuts dans le code Flutter** (`student_applications_tab.dart`) :
- `draft` (gris)
- `submitted` (bleu)
- `under_review` (orange)
- `accepted` (vert)
- `rejected` (rouge)
- `canceled` (gris)

**Couleurs définies** :
```dart
const _kApplicationsStatusDraftColor = Color(0xFF9CA3AF);
const _kApplicationsStatusSubmittedColor = Color(0xFF3275D0);
const _kApplicationsStatusUnderReviewColor = Color(0xFFF6A623);
const _kApplicationsStatusAcceptedColor = Color(0xFF1B8F5A);
const _kApplicationsStatusRejectedColor = Color(0xFFE53935);
const _kApplicationsStatusCanceledColor = Color(0xFF6B7280);
```

**Transitions** : Non documentées dans le code audité. Les statuts sont modifiés par les RPCs université/admin (`app_university_update_application_status`, `app_admin_update_application_status`).

---

## 3. CRITÈRES D'ADMISSION

### 3.1 Ce qui est géré par Academia

**Validation du dossier** : La RPC `app_create_application` vérifie si le profil académique de l'étudiant est complet. Si incomplet, retourne `dossier_incomplete` avec la liste des champs manquants.

**Champs vérifiés** : Non visibles dans le code audité (probablement dans la RPC côté base de données).

---

### 3.2 Ce qui dépend des universités

**Critères d'admission** : Non gérés par Academia. Chaque université partenaire définit ses propres critères.

**Limites** : Academia ne peut pas informer l'étudiant sur les critères spécifiques d'une université. Bobodo doit rediriger vers la fiche université ou contacter l'université.

---

## 4. CRÉDITS IA

### 4.1 Achat

**RPCs** :
- `app_student_get_credit_balance` : récupérer le solde
- `app_student_list_credit_packs` : lister les packs disponibles
- `app_student_purchase_credits` : acheter un pack (après paiement LigdiCash confirmé)

**Provider** : `CreditProvider` dans `credit_provider.dart`

**Données retournées par `app_student_get_credit_balance`** :
- `balance` : solde actuel
- `total_purchased` : total acheté
- `total_consumed` : total consommé
- `total_gifted` : total offert (bonus)
- `last_weekly_bonus` : date du dernier bonus hebdomadaire

---

### 4.2 Consommation

**RPCs** :
- `app_student_check_ai_access` : vérifier si accès autorisé pour une action
- `app_student_list_ai_action_prices` : lister les prix des actions IA

**Fonctionnement** : La consommation se produit côté Edge Function. Le Provider met à jour le solde localement via `deductLocally(int amount)`.

**Bonus hebdomadaire** :
- RPC : `app_student_claim_weekly_bonus`
- Condition : minimum 6 jours depuis le dernier bonus
- Données retournées : `new_balance`, `credits_added`

---

### 4.3 Affichage du solde

**Widget** : `CreditBalanceChip` dans `credit_balance_chip.dart`

**Affichage** : Dans l'AppBar des écrans :
- `student_prep_concours_screen.dart`
- `student_td_root_screen.dart`

**Action** : Tap sur le chip ouvre la boutique de crédits (non implémenté dans le code audité).

---

### 4.4 Utilisation TD

**Coût** : Déterminé par l'action IA via `app_student_check_ai_access`

**Actions TD** : Non détaillées dans le code audité. Probablement :
- `td_scan_subject` : scan d'exercice
- `td_correction` : correction IA
- `td_quiz_generation` : génération de quiz

---

### 4.5 Utilisation concours

**Coût** : Déterminé par l'action IA via `app_student_check_ai_access`

**Actions concours** : Non détaillées dans le code audité. Probablement :
- `prep_quiz_correction` : correction de quiz
- `prep_ai_tutor` : tuteur IA
- `prep_psychotech` : tests psychotechniques

---

## 5. PAIEMENTS

### 5.1 Services payants

**Enum payment_reason** (dans `change_20251228_payment_phase1_schema.sql`) :
- `application_fee` : frais de candidature
- `registration_fee` : frais d'inscription
- `tuition_deposit` : acompte frais de scolarité
- `td_access` : accès TD
- `other` : autre

**Services payants identifiés** :
- Candidatures (application_fee, registration_fee)
- TD (td_access)
- Crédits IA (via packs)

---

### 5.2 Services gratuits

**Non documentés dans le code audité.** Probablement :
- Consultation des offres de formation
- Consultation des universités
- Messagerie
- Communautés
- Lives (peut être payant)

---

### 5.3 Étapes utilisateur

**Déclaration de paiement** (dans `student_application_detail_screen.dart`) :
1. Cliquer sur "Déclarer un paiement" dans l'onglet Paiements
2. Sélectionner le canal :
   - Orange Money
   - Moov Money
   - Telecel Money
3. Saisir le montant
4. Saisir la référence opérateur (ID Trans / ref. SMS) - obligatoire pour mobile money
5. Saisir une note (optionnel)
6. Valider

**RPC** : `app_student_declare_payment`

**Paramètres** :
- `p_payment_id` (UUID)
- `p_channel` (payment_channel)
- `p_amount_paid` (NUMERIC)
- `p_external_reference` (TEXT)
- `p_student_note` (TEXT)

**Canaux** (enum payment_channel) :
- `cash`
- `orange_money`
- `moov_money`
- `telecel_money`
- `ligdicash` (ajouté dans `change_20260319_ligdicash_phase1_foundations.sql`)

**Statuts** (enum payment_status) :
- `pending`
- `declared_by_student`
- `under_verification`
- `confirmed`
- `rejected`
- `cancelled`
- `processing` (ajouté pour LigdiCash)

---

## 6. SUPPORT

### 6.1 Icône flottante

**Widget** : `SupportFab` dans `support_fab.dart`

**Caractéristiques** :
- Couleur : vert (#FF25D366)
- Icône : support_agent
- Badge : compteur de messages non-lus (rouge)
- Poll : toutes les 30 secondes pour mettre à jour le compteur

**RPC** : `app_get_support_unread_count`

**Action** : Tap ouvre `SupportChatScreen`

---

### 6.2 Formulaires

**Écran** : `SupportChatScreen` dans `support_chat_screen.dart`

**Provider** : `SupportMessagesProvider`

**Non audité en détail** : Le code de l'écran de chat n'a pas été lu dans cet audit.

---

### 6.3 Procédures de contact

**RPC** : `app_get_support_unread_count` pour le compteur

**Messages** : Probablement stockés dans une table `support_messages` (non auditée).

---

### 6.4 Comportement actuel

- Le FAB est présent sur plusieurs écrans (liste dans grep)
- Le compteur se met à jour automatiquement toutes les 30s
- Le badge affiche "99+" si > 99

---

## VALIDATION DES FICHES LOT A

### Fiche 1 : Processus de candidature

**Statut** : À CORRIGER

**Corrections nécessaires** :
- Préciser les champs demandés dans le dialog (niveau, mode, horaires, réduction, commentaire)
- Préciser que la motivation est optionnelle
- Préciser l'erreur "dossier_incomplete" si le profil académique est incomplet
- Préciser que les critères d'admission dépendent de l'université

---

### Fiche 2 : Documents requis

**Statut** : À CORRIGER

**Corrections nécessaires** :
- Préciser les formats acceptés : pdf, jpg, jpeg, png, doc, docx
- Préciser qu'il n'y a pas de liste de documents obligatoires vs facultatifs visible côté étudiant
- Préciser que l'obligation est vérifiée par la RPC (dossier_incomplete)
- Préciser que les documents sont uploadés un par un

---

### Fiche 3 : Critères d'admission

**Statut** : À CORRIGER

**Corrections nécessaires** :
- Préciser que Academia ne gère pas les critères d'admission
- Préciser que chaque université définit ses propres critères
- Préciser que Bobodo doit rediriger vers la fiche université
- Préciser que Academia vérifie seulement la complétude du dossier

---

### Fiche 4 : Statuts de candidature

**Statut** : À COMPLÉTER

**Informations à ajouter** :
- Liste exacte des statuts : draft, submitted, under_review, accepted, rejected, canceled
- Couleurs associées (gris, bleu, orange, vert, rouge, gris)
- Préciser que les transitions ne sont pas documentées dans le code
- Préciser que les statuts sont modifiés par l'université ou l'admin

---

### Fiche 5 : Paiements

**Statut** : À CORRIGER

**Corrections nécessaires** :
- Préciser les canaux : cash, orange_money, moov_money, telecel_money, ligdicash
- Préciser les statuts : pending, declared_by_student, under_verification, confirmed, rejected, cancelled, processing
- Préciser les payment_reason : application_fee, registration_fee, tuition_deposit, td_access, other
- Préciser que la référence opérateur est obligatoire pour mobile money
- Préciser les étapes de déclaration (canal, montant, référence, note)

---

### Fiche 6 : Crédits IA (détail)

**Statut** : À COMPLÉTER

**Informations à ajouter** :
- Préciser que l'achat se fait via LigdiCash
- Préciser le bonus hebdomadaire (minimum 6 jours entre deux bonus)
- Préciser que la consommation se produit côté Edge Function
- Préciser que le solde est affiché via CreditBalanceChip dans l'AppBar
- Préciser que les coûts sont déterminés par action IA via RPC

---

### Fiche 7 : Suivi de candidature

**Statut** : À CORRIGER

**Corrections nécessaires** :
- Préciser que le suivi se fait dans l'onglet "Candidatures"
- Préciser les filtres par statut
- Préciser les onglets du détail : Détails, Documents, Messages, Paiements
- Préciser que les messages ont un indicateur de non-lu
- Préciser que les documents peuvent être ajoutés via le bouton +

---

## RÉSUMÉ

| Fiche | Statut | Action |
|-------|--------|--------|
| Processus de candidature | À CORRIGER | Ajouter détails champs, erreur dossier_incomplete |
| Documents requis | À CORRIGER | Préciser formats, absence liste obligatoires |
| Critères d'admission | À CORRIGER | Préciser dépendance université, redirection |
| Statuts de candidature | À COMPLÉTER | Ajouter liste exacte, couleurs, transitions |
| Paiements | À CORRIGER | Préciser canaux, statuts, étapes déclaration |
| Crédits IA (détail) | À COMPLÉTER | Ajouter bonus, Edge Function, coûts par action |
| Suivi de candidature | À CORRIGER | Préciser onglets, filtres, indicateurs |

**Aucune fiche à abandonner.**

**Toutes les fiches nécessitent des corrections ou compléments.**

---

**RAPPORT TERMINÉ – EN ATTENTE DE VALIDATION**
