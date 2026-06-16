# LOT B PHASE 1 - VALIDATION

**Date** : 9 juin 2026  
**Statut** : Rédaction terminée

---

## PÉRIMÈTRE

5 fiches PRIORITÉ CRITIQUE rédigées selon les règles :
- Conversationnelles
- Courtes
- Compréhensibles par un étudiant
- Orientées aide pratique
- Rédigées avec "tu"

---

## FICHES RÉDIGÉES

### 1. Comment créer un compte sur Academia ?

**Vérification code** : ✅ Confirmé
- Écran : `signup_screen.dart`
- Champs requis : nom, prénom, email, mot de passe
- Optionnel : code de parrainage, code d'invitation
- Processus : email de confirmation requis

**Contenu** :
- Informations requises confirmées
- Processus d'inscription décrit
- Email de confirmation mentionné
- Code de parrainage mentionné

**Style** : ✅ Conversationnel, "tu", orienté aide pratique

**Règle Support** : Non applicable (Bobodo peut répondre)

---

### 2. Comment modifier mon profil ?

**Vérification code** : ✅ Confirmé
- Écran : `student_profile_screen.dart`
- Champs modifiables : nom complet, téléphone, pays, ville, date de naissance
- Informations scolaires : BEPC (année, établissement, mention), BAC (année, série, mention, établissement)
- Projet d'étude : champ disponible

**Contenu** :
- Accès au profil confirmé
- Informations personnelles listées
- Informations scolaires détaillées
- Projet d'étude mentionné
- Sauvegarde mentionnée

**Style** : ✅ Conversationnel, "tu", orienté aide pratique

**Règle Support** : Non applicable (Bobodo peut répondre)

---

### 3. Mon paiement est en attente

**Vérification code** : ✅ Confirmé
- Écran : `student_payments_screen.dart`
- Canaux : Orange Money, Moov Money, Telecel Cash, LigdiCash
- Processus : déclaration de paiement, validation
- Statuts : en attente, validé, rejeté

**Contenu** :
- Signification du statut "en attente" expliquée
- Délais mentionnés (quelques minutes, 24h)
- Canaux de paiement listés
- Vérification confirmation opérateur
- Escalade vers Support après 24h

**Style** : ✅ Conversationnel, "tu", orienté aide pratique

**Règle Support** : ✅ Escalade vers Support intégrée

---

### 4. Ma candidature est bloquée

**Vérification code** : ✅ Confirmé
- Écran : `student_applications_tab.dart`
- Statuts : draft (brouillon), submitted (envoyée), under_review (en examen), accepted (acceptée), rejected (refusée), canceled (annulée)
- Couleurs : gris, bleu, orange, vert, rouge, gris

**Contenu** :
- Accès aux candidatures confirmé
- Statuts détaillés et expliqués
- Délai "en examen" mentionné
- Escalade vers Support en cas de doute

**Style** : ✅ Conversationnel, "tu", orienté aide pratique

**Règle Support** : ✅ Escalade vers Support intégrée

---

### 5. Comment accéder aux cours d'appui ?

**Vérification code** : ✅ Confirmé
- Écran : `student_td_root_screen.dart`
- Onglets : Accueil, Catalogue, Mes inscriptions, Ressources, Classement, Stats, IA Tuteur, Groupes locaux, Exercices
- Processus : catalogue → choix programme → inscription

**Contenu** :
- Accès à l'onglet TD confirmé
- Sections disponibles listées
- Processus d'inscription décrit
- Accès aux cours/exercices après inscription

**Style** : ✅ Conversationnel, "tu", orienté aide pratique

**Règle Support** : Non applicable (Bobodo peut répondre)

---

## VÉRIFICATION STYLE

### Conversationnel ✅
- Toutes les fiches utilisent "tu"
- Ton naturel et bienveillant
- Phrases courtes et directes

### Court ✅
- Fiche 1 : 262 caractères
- Fiche 2 : 398 caractères
- Fiche 3 : 428 caractères
- Fiche 4 : 498 caractères
- Fiche 5 : 438 caractères

### Compréhensible par un étudiant ✅
- Pas de jargon technique
- Pas de noms de tables/RPC
- Pas de détails d'architecture
- Langage simple et accessible

### Orienté aide pratique ✅
- Actions concrètes décrites
- Étapes claires
- Solutions proposées

---

## VÉRIFICATION RÈGLE SUPPORT

### Fiches avec escalade Support (2/5)
- Fiche 3 : Mon paiement est en attente ✅
- Fiche 4 : Ma candidature est bloquée ✅

### Fiches sans escalade Support (3/5)
- Fiche 1 : Comment créer un compte sur Academia ? ✅
- Fiche 2 : Comment modifier mon profil ? ✅
- Fiche 5 : Comment accéder aux cours d'appui ? ✅

### Formulation Support
- "utilise l'icône flottante Support pour contacter l'équipe d'administration"
- Naturelle et non administrative ✅

---

## VÉRIFICATION CODE

### Écrans Flutter vérifiés ✅
- `signup_screen.dart` (création compte)
- `student_profile_screen.dart` (modification profil)
- `student_payments_screen.dart` (paiements)
- `student_applications_tab.dart` (candidatures)
- `student_td_root_screen.dart` (TD)

### Informations confirmées ✅
- Champs requis/optionnels
- Processus de workflow
- Canaux de paiement
- Statuts de candidature
- Sections TD

### Aucune information non confirmée ✅
- Toutes les informations sont basées sur le code réel
- Aucune supposition

---

## CONCLUSION

**5 fiches rédigées** ✅
**Style conversationnel** ✅
**Vérification code** ✅
**Règle Support** ✅
**Prêt pour revue humaine** ✅

---

**VALIDATION TERMINÉE**
