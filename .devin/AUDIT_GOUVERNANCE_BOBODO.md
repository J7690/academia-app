# AUDIT GOUVERNANCE BOBODO – CARTOGRAPHIE DE LA CONNAISSANCE

**Date** : 8 juin 2026  
**Objectif** : Déterminer précisément ce que Bobodo doit savoir, expliquer, indiquer ou refuser  
**Portée** : Gouvernance de la connaissance Bobodo – Aucune modification de code ou de base de données

---

## PARTIE 1 – ANALYSE DE LA BASE EXISTANTE

### 1.1 Inventaire des fiches existantes (26 fiches au total)

#### Fiches historiques (13 fiches - novembre 2025)

| ID | Titre | Catégorie | Thème couvert | Niveau de détail |
|----|-------|-----------|---------------|-----------------|
| 1 | Présentation de Nexiom Group | nexiom | Présentation entreprise | Élevé |
| 2 | Le courtage en formation par Nexiom Group | nexiom | Modèle économique | Élevé |
| 3 | Rôle de la plateforme Academia | academia | Présentation plateforme | Moyen |
| 4 | Processus général de courtage via Academia | process | Parcours utilisateur | Élevé |
| 5 | Réductions négociées et absence de bourses d'études | process | Clarification financière | Élevé |
| 6 | Ambition et couverture géographique de Nexiom Group | nexiom | Vision géographique | Moyen |
| 7 | Rôle et limites de Bobodo | process | Limites de l'assistant | Critique |
| 8 | Cours d'appui organisés via Academia | academia | Service spécifique | Moyen |
| 9 | Petites formations et ateliers via Academia | academia | Service spécifique | Moyen |
| 10 | Bibliothèque, conseil et orientation sur la plateforme | academia | Services orientation | Moyen |
| 11 | Offre de formation propre à Nexiom Group | nexiom | Services internes | Élevé |
| 12 | Formations et accompagnement sur les marchés publics | nexiom | Service spécifique | Élevé |
| 13 | Formations non diplômantes et certifiantes sur demande | nexiom | Service spécifique | Élevé |

#### Fiches injectées le 8 juin 2026 (13 fiches)

| ID | Titre | Catégorie | Thème couvert | Niveau de détail |
|----|-------|-----------|---------------|-----------------|
| 14 | Présentation générale d'Academia | NEXIOM_ACADEMIA_INTERNE | Présentation plateforme | Moyen |
| 15 | Onglet Universités | NEXIOM_ACADEMIA_INTERNE | Navigation | Faible |
| 16 | Onglet Marketplace | NEXIOM_ACADEMIA_INTERNE | Navigation | Faible |
| 17 | Onglet TD | NEXIOM_ACADEMIA_INTERNE | Navigation + Service | Moyen |
| 18 | Préparation Concours | NEXIOM_ACADEMIA_INTERNE | Service | Moyen |
| 19 | Crédits IA | NEXIOM_ACADEMIA_INTERNE | Mécanisme | Faible |
| 20 | Accompagnement par des enseignants | NEXIOM_ACADEMIA_INTERNE | Service | Moyen |
| 21 | Bibliothèque de cours | NEXIOM_ACADEMIA_INTERNE | Navigation | Faible |
| 22 | Espace Live | NEXIOM_ACADEMIA_INTERNE | Service | Faible |
| 23 | Espace Challenge | NEXIOM_ACADEMIA_INTERNE | Service | Faible |
| 24 | Espace Opportunités | NEXIOM_ACADEMIA_INTERNE | Service | Faible |
| 25 | Messagerie et groupes | NEXIOM_ACADEMIA_INTERNE | Service | Faible |
| 26 | Orientation académique et professionnelle | ORIENTATION_ETUDES_EMPLOI | Service | Moyen |

### 1.2 Matrice de couverture fonctionnelle

| Fonctionnalité | Couverture actuelle | État | Gap identifié |
|----------------|-------------------|------|---------------|
| Présentation Academia | ✅ Complète | OK | Aucun |
| Navigation onglets | ✅ Partielle | OK | Détails procédures manquants |
| Recherche universités | ⚠️ Indirecte | À améliorer | Procédure détaillée manquante |
| Dépôt candidature | ❌ Absente | CRITIQUE | Procédure complète manquante |
| Suivi candidature | ❌ Absente | CRITIQUE | Statuts et parcours manquants |
| Documents requis | ❌ Absente | CRITIQUE | Liste et formats manquants |
| Critères admission | ❌ Absente | CRITIQUE | Critères généraux manquants |
| Crédits IA | ⚠️ Existence | À améliorer | Procédure utilisation manquante |
| Module TD | ⚠️ Existence | À améliorer | Procédure scan/correction manquante |
| Préparation concours | ⚠️ Existence | À améliorer | Procédure quiz/statistiques manquante |
| Marketplace | ⚠️ Existence | À améliorer | Procédure achat/commande manquante |
| Challenges | ⚠️ Existence | À améliorer | Procédure participation manquante |
| Communautés | ⚠️ Existence | À améliorer | Procédure groupes/messagerie manquante |
| Cours en ligne | ⚠️ Existence | À améliorer | Procédure inscription/progression manquante |
| Lives | ⚠️ Existence | À améliorer | Procédure rejoindre/replay manquante |
| Paiements | ❌ Absente | CRITIQUE | Procédure complète manquante |
| Profil étudiant | ❌ Absente | IMPORTANTE | Procédure modification manquante |
| Support | ❌ Absente | IMPORTANTE | Procédure contact manquante |
| Sécurité | ❌ Absente | IMPORTANTE | Procédure signalement manquante |

### 1.3 Limites des fiches existantes

**Fiche "Présentation générale d'Academia"** :
- ✅ Couvre bien la présentation générale
- ⚠️ Ne détaille pas les procédures spécifiques
- ⚠️ Ne répond pas aux questions "comment faire"

**Fiches onglets (Universités, Marketplace, TD, etc.)** :
- ✅ Indiquent où trouver les fonctionnalités
- ❌ N'expliquent pas comment les utiliser
- ❌ Ne détaillent pas les étapes utilisateur

**Fiche "Crédits IA"** :
- ✅ Explique l'existence des crédits
- ❌ N'explique pas comment les obtenir
- ❌ N'explique pas comment les utiliser
- ❌ Ne donne pas les coûts

**Fiche "Rôle et limites de Bobodo"** :
- ✅ Critique pour définir les limites
- ✅ Précise les domaines interdits (médical, juridique, financier)
- ⚠️ Pourrait être plus détaillée sur les limites techniques

---

## PARTIE 2 – ANALYSE DES 20 FICHES PROPOSÉES

### 2.1 Matrice de couverture

| Fiche proposée | État couverture | Niveau | Justification |
|----------------|-----------------|--------|---------------|
| Processus de candidature | ❌ Absente | CRITIQUE | Parcours fondamental, totalement manquant |
| Critères d'admission | ❌ Absente | CRITIQUE | Information essentielle pour les candidats |
| Documents requis | ❌ Absente | CRITIQUE | Indispensable pour déposer une candidature |
| Statuts de candidature | ❌ Absente | IMPORTANTE | Utile pour comprendre le suivi |
| Crédits IA (détail) | ⚠️ Partielle | IMPORTANTE | Existence connue, mais procédure manquante |
| Module TD (procédure) | ⚠️ Partielle | IMPORTANTE | Existence connue, mais scan/correction manquant |
| Préparation concours (procédure) | ⚠️ Partielle | IMPORTANTE | Existence connue, mais quiz/statistiques manquant |
| Marketplace (procédure) | ⚠️ Partielle | UTILE | Existence connue, mais achat/commande manquant |
| Challenges (procédure) | ⚠️ Partielle | UTILE | Existence connue, mais participation manquante |
| Communautés (procédure) | ⚠️ Partielle | UTILE | Existence connue, mais groupes/messagerie manquant |
| Cours en ligne (procédure) | ⚠️ Partielle | UTILE | Existence connue, mais inscription/progression manquant |
| Lives (procédure) | ⚠️ Partielle | UTILE | Existence connue, mais rejoindre/replay manquant |
| Opportunités (procédure) | ⚠️ Partielle | OPTIONNELLE | Existence connue, utilisation moins fréquente |
| Profil étudiant | ❌ Absente | IMPORTANTE | Procédure de modification manquante |
| Paiements | ❌ Absente | CRITIQUE | Procédure complète manquante |
| Support | ❌ Absente | IMPORTANTE | Procédure contact manquante |
| Orientation (détail) | ⚠️ Partielle | IMPORTANTE | Existence connue, mais accompagnement détaillé manquant |
| Enseignants (procédure) | ⚠️ Partielle | UTILE | Existence connue, mais sollicitation manquante |
| Bobodo (utilisation) | ⚠️ Partielle | IMPORTANTE | Existence connue, mais guide d'utilisation manquant |
| Sécurité et confidentialité | ❌ Absente | IMPORTANTE | Procédure signalement/blocage manquante |

### 2.2 Doublons identifiés

| Fiche proposée | Fiche existante similaire | Type de doublon | Action recommandée |
|----------------|---------------------------|-----------------|---------------------|
| Orientation académique et professionnelle | Orientation académique et professionnelle (fiche 26) | Doublon exact | Fusionner ou supprimer la proposition |
| Enseignants (procédure) | Accompagnement par des enseignants (fiche 20) | Partiel | Compléter la fiche existante |
| Bobodo (utilisation) | Rôle et limites de Bobodo (fiche 7) | Partiel | Compléter la fiche existante |

---

## PARTIE 3 – CLASSIFICATION DES CONNAISSANCES

### 3.1 Matrice EXPLIQUER / GUIDER / REDIRIGER / REFUSER

| Sujet | Action Bobodo | Justification |
|-------|---------------|---------------|
| **CANDIDATURES** | | |
| Comment déposer une candidature | EXPLIQUER | Procédure utilisateur fondamentale |
| Comment suivre sa candidature | EXPLIQUER | Procédure utilisateur fondamentale |
| Statuts de candidature | EXPLIQUER | Information essentielle pour le suivi |
| Documents requis | EXPLIQUER | Information indispensable |
| Critères d'admission | EXPLIQUER | Information essentielle |
| Annuler une candidature | EXPLIQUER | Procédure utilisateur |
| Modifier une candidature | EXPLIQUER | Procédure utilisateur |
| **UNIVERSITÉS** | | |
| Où trouver les universités | GUIDER | Navigation dans l'application |
| Comment postuler à une université | EXPLIQUER | Procédure utilisateur |
| Contacter une université | REDIRIGER | Contact direct avec l'université |
| Détails spécifiques d'une université | GUIDER | Navigation vers la fiche université |
| **CRÉDITS IA** | | |
| Comment utiliser les crédits IA | EXPLIQUER | Procédure utilisateur |
| Comment obtenir des crédits IA | EXPLIQUER | Procédure utilisateur |
| Coût des crédits IA | EXPLIQUER | Information essentielle |
| Solde de crédits | GUIDER | Navigation vers l'écran concerné |
| **TD** | | |
| Comment scanner un exercice | EXPLIQUER | Procédure utilisateur |
| Comment obtenir une correction IA | EXPLIQUER | Procédure utilisateur |
| Comment demander un enseignant | EXPLIQUER | Procédure utilisateur |
| Statistiques TD | GUIDER | Navigation vers l'écran concerné |
| **PRÉPARATION CONCOURS** | | |
| Comment faire un quiz | EXPLIQUER | Procédure utilisateur |
| Comment voir ses statistiques | GUIDER | Navigation vers l'écran concerné |
| Tests psychotechniques | EXPLIQUER | Procédure utilisateur |
| Sessions live concours | EXPLIQUER | Procédure utilisateur |
| **MARKETPLACE** | | |
| Comment acheter sur le marketplace | EXPLIQUER | Procédure utilisateur |
| Comment passer commande | EXPLIQUER | Procédure utilisateur |
| Suivi de commande | GUIDER | Navigation vers l'écran concerné |
| Contacter un vendeur | REDIRIGER | Contact direct via marketplace |
| **CHALLENGES** | | |
| Comment participer à un challenge | EXPLIQUER | Procédure utilisateur |
| Comment publier une vidéo | EXPLIQUER | Procédure utilisateur |
| Classement | GUIDER | Navigation vers l'écran concerné |
| **COMMUNAUTÉS** | | |
| Comment rejoindre un groupe | EXPLIQUER | Procédure utilisateur |
| Comment créer un groupe | EXPLIQUER | Procédure utilisateur |
| Messagerie directe | EXPLIQUER | Procédure utilisateur |
| **COURS EN LIGNE** | | |
| Comment s'inscrire à une formation | EXPLIQUER | Procédure utilisateur |
| Progression | GUIDER | Navigation vers l'écran concerné |
| Modules de formation | GUIDER | Navigation vers l'écran concerné |
| **LIVES** | | |
| Comment rejoindre un live | EXPLIQUER | Procédure utilisateur |
| Comment voir les replays | EXPLIQUER | Procédure utilisateur |
| Calendrier des lives | GUIDER | Navigation vers l'écran concerné |
| **PAIEMENTS** | | |
| Comment effectuer un paiement | EXPLIQUER | Procédure utilisateur |
| Canaux de paiement | EXPLIQUER | Information essentielle |
| Déclarer un paiement existant | EXPLIQUER | Procédure utilisateur |
| Suivi de paiement | GUIDER | Navigation vers l'écran concerné |
| Problème de paiement | REDIRIGER | Contact support |
| **PROFIL** | | |
| Comment modifier son profil | EXPLIQUER | Procédure utilisateur |
| Informations académiques | EXPLIQUER | Procédure utilisateur |
| **SUPPORT** | | |
| Comment contacter le support | EXPLIQUER | Procédure utilisateur |
| FAQ | GUIDER | Navigation vers la FAQ |
| Problème technique | REDIRIGER | Contact support |
| Réclamation | REDIRIGER | Contact support |
| **ORIENTATION** | | |
| Aide au choix d'études | EXPLIQUER | Service Bobodo |
| Conseiller humain | REDIRIGER | Contact orientation |
| **ENSEIGNANTS** | | |
| Comment solliciter un enseignant | EXPLIQUER | Procédure utilisateur |
| Types d'accompagnement | EXPLIQUER | Information essentielle |
| **SÉCURITÉ** | | |
| Comment signaler un contenu | EXPLIQUER | Procédure utilisateur |
| Comment bloquer un utilisateur | EXPLIQUER | Procédure utilisateur |
| Suppression de compte | REDIRIGER | Procédure sensible |
| **INFORMATIONS SENSIBLES** | | |
| RPC internes | REFUSER | Information technique |
| Tables Supabase | REFUSER | Information technique |
| Architecture de l'application | REFUSER | Information technique |
| Mécanismes financiers internes | REFUSER | Information sensible |
| Règles administratives privées | REFUSER | Information sensible |
| Logique de sécurité | REFUSER | Information technique |
| Secrets API | REFUSER | Information sensible |
| Données privées d'autres utilisateurs | REFUSER | Protection vie privée |
| Avis médicaux | REFUSER | Déjà limité par fiche existante |
| Avis juridiques | REFUSER | Déjà limité par fiche existante |
| Avis financiers | REFUSER | Déjà limité par fiche existante |

---

## PARTIE 4 – ANALYSE DES QUESTIONS RÉELLES

### 4.1 Données disponibles

**Tables Bobodo existantes** :
- `app.bobodo_messages` : 600 enregistrements
- `app.bobodo_detected_needs` : 112 enregistrements
- `app.bobodo_unanswered_questions` : 12 enregistrements
- `app.bobodo_conversation_memory` : 0 enregistrement

**Structure des tables** :
- `bobodo_messages` : id, session_id, sender, content, safety_flag, created_at
- `bobodo_detected_needs` : id, session_id, question_text, category, need_summary, created_at
- `bobodo_unanswered_questions` : id, session_id, question_text, category, status, created_at

**Note** : Les données existent mais n'ont pas pu être extraites pour analyse détaillée lors de cet audit (problème technique d'accès). Une analyse approfondie des questions réelles nécessitera un accès direct aux données.

### 4.2 Questions les plus probables (basé sur l'audit fonctionnel)

| Rang | Question | Catégorie | Fréquence estimée | Réponse disponible |
|------|----------|-----------|-------------------|-------------------|
| 1 | Comment postuler à une université ? | Candidatures | Très élevée | ❌ Non |
| 2 | Quels documents faut-il pour postuler ? | Candidatures | Très élevée | ❌ Non |
| 3 | Comment suivre ma candidature ? | Candidatures | Très élevée | ❌ Non |
| 4 | Que signifie le statut "En étude" ? | Candidatures | Élevée | ❌ Non |
| 5 | Comment utiliser les crédits IA ? | Crédits IA | Élevée | ⚠️ Partielle |
| 6 | Comment obtenir des crédits IA ? | Crédits IA | Élevée | ❌ Non |
| 7 | Comment scanner un exercice TD ? | TD | Élevée | ❌ Non |
| 8 | Comment participer à un quiz concours ? | Préparation concours | Élevée | ❌ Non |
| 9 | Comment acheter sur le marketplace ? | Marketplace | Moyenne | ❌ Non |
| 10 | Comment rejoindre un groupe ? | Communautés | Moyenne | ❌ Non |
| 11 | Comment contacter le support ? | Support | Moyenne | ❌ Non |
| 12 | Comment modifier mon profil ? | Profil | Moyenne | ❌ Non |
| 13 | Comment effectuer un paiement ? | Paiements | Très élevée | ❌ Non |
| 14 | Quels sont les canaux de paiement ? | Paiements | Élevée | ❌ Non |
| 15 | Comment déclarer un paiement existant ? | Paiements | Élevée | ❌ Non |
| 16 | Qu'est-ce qu'Academia ? | Général | Élevée | ✅ Oui |
| 17 | Comment trouver une université ? | Universités | Élevée | ⚠️ Partielle |
| 18 | Comment accéder aux TD ? | TD | Moyenne | ⚠️ Partielle |
| 19 | Comment accéder à la préparation concours ? | Préparation concours | Moyenne | ⚠️ Partielle |
| 20 | Comment utiliser Bobodo ? | Bobodo | Moyenne | ⚠️ Partielle |

---

## PARTIE 5 – DÉTECTION DES RISQUES

### 5.1 Informations à ne JAMAIS injecter dans Bobodo

**INFORMATIONS TECHNIQUES** :
- Noms des RPC (Remote Procedure Calls)
- Noms des tables Supabase
- Structure des bases de données
- Clés étrangères et relations
- Index et contraintes
- Triggers et fonctions SQL
- Edge Functions internes
- URLs internes de l'API
- Secrets et clés API
- Tokens d'authentification
- Logique de RLS (Row Level Security)

**INFORMATIONS ARCHITECTURALES** :
- Architecture DDD (Domain Driven Design)
- Structure des providers Flutter
- Structure des repositories
- Structure des services
- Chemins de fichiers internes
- Noms de packages et modules
- Configuration de build
- Variables d'environnement

**INFORMATIONS FINANCIÈRES INTERNES** :
- Mécanismes de commission
- Taux de commission
- Flux financiers internes
- Contrats avec les partenaires
- Conditions de négociation
- Marges et bénéfices
- Historique des transactions
- Données bancaires
- Informations sur les comptes LigdiCash

**INFORMATIONS ADMINISTRATIVES PRIVÉES** :
- Procédures de validation administrative
- Critères de validation internes
- Règles de modération
- Liste des utilisateurs bloqués
- Historique des sanctions
- Logs d'audit
- Données personnelles des autres utilisateurs
- Informations de contact des autres utilisateurs

**INFORMATIONS SÉCURITÉ** :
- Mécanismes d'authentification
- Logique de vérification d'identité
- Procédures anti-fraude
- Règles de détection d'anomalies
- Configuration de sécurité
- Protocoles de chiffrement

**INFORMATIONS SENSIBLES** :
- Données personnelles (PII)
- Informations médicales
- Informations juridiques confidentielles
- Secrets commerciaux
- Propriété intellectuelle non publiée
- Informations sur les employés Nexiom
- Salaires et rémunérations

### 5.2 Règles de gouvernance

**RÈGLE 1** : Bobodo ne doit jamais exposer la structure technique de l'application.

**RÈGLE 2** : Bobodo ne doit jamais donner accès à des informations privées d'autres utilisateurs.

**RÈGLE 3** : Bobodo ne doit jamais révéler des mécanismes financiers internes.

**RÈGLE 4** : Bobodo ne doit jamais fournir des avis médicaux, juridiques ou financiers (déjà couvert par la fiche existante).

**RÈGLE 5** : Bobodo doit toujours rediriger vers le support pour les problèmes techniques.

**RÈGLE 6** : Bobodo doit toujours rediriger vers un conseiller humain pour les questions sensibles.

**RÈGLE 7** : Bobodo ne doit jamais exposer des secrets ou des clés API.

**RÈGLE 8** : Bobodo ne doit jamais révéler des informations sur les procédures administratives internes.

---

## PARTIE 6 – PLAN D'INJECTION FINAL

### LOT A – INJECTION IMMÉDIATE (CRITIQUE)

**7 fiches à injecter en priorité absolue**

1. **Processus de candidature**
   - Titre : Comment déposer une candidature sur Academia
   - Catégorie : NEXIOM_ACADEMIA_INTERNE
   - Priorité : CRITIQUE
   - Justification : Parcours fondamental, question la plus fréquente

2. **Documents requis pour candidature**
   - Titre : Documents nécessaires pour une candidature
   - Catégorie : NEXIOM_ACADEMIA_INTERNE
   - Priorité : CRITIQUE
   - Justification : Indispensable pour déposer une candidature

3. **Critères d'admission**
   - Titre : Critères d'admission des universités partenaires
   - Catégorie : NEXIOM_ACADEMIA_INTERNE
   - Priorité : CRITIQUE
   - Justification : Information essentielle pour les candidats

4. **Statuts de candidature**
   - Titre : Comprendre les statuts de candidature
   - Catégorie : NEXIOM_ACADEMIA_INTERNE
   - Priorité : CRITIQUE
   - Justification : Essentiel pour le suivi du dossier

5. **Paiements**
   - Titre : Effectuer un paiement sur Academia
   - Catégorie : NEXIOM_ACADEMIA_INTERNE
   - Priorité : CRITIQUE
   - Justification : Parcours fondamental, question très fréquente

6. **Crédits IA (détail)**
   - Titre : Guide complet des crédits IA
   - Catégorie : NEXIOM_ACADEMIA_INTERNE
   - Priorité : CRITIQUE
   - Justification : Compléter la fiche existante avec la procédure

7. **Suivi de candidature**
   - Titre : Comment suivre sa candidature
   - Catégorie : NEXIOM_ACADEMIA_INTERNE
   - Priorité : CRITIQUE
   - Justification : Parcours fondamental

---

### LOT B – INJECTION RECOMMANDÉE (IMPORTANTE)

**8 fiches à injecter en deuxième priorité**

1. **Module TD (procédure)**
   - Titre : Comment utiliser le module TD
   - Catégorie : NEXIOM_ACADEMIA_INTERNE
   - Priorité : IMPORTANTE
   - Action : Compléter la fiche existante "Onglet TD"

2. **Préparation concours (procédure)**
   - Titre : Guide du module Préparation Concours
   - Catégorie : NEXIOM_ACADEMIA_INTERNE
   - Priorité : IMPORTANTE
   - Action : Compléter la fiche existante "Préparation Concours"

3. **Profil étudiant**
   - Titre : Gérer mon profil étudiant
   - Catégorie : NEXIOM_ACADEMIA_INTERNE
   - Priorité : IMPORTANTE
   - Justification : Procédure de modification manquante

4. **Support**
   - Titre : Contacter le support Academia
   - Catégorie : NEXIOM_ACADEMIA_INTERNE
   - Priorité : IMPORTANTE
   - Justification : Procédure contact manquante

5. **Bobodo (utilisation)**
   - Titre : Guide d'utilisation de l'assistant Bobodo
   - Catégorie : NEXIOM_ACADEMIA_INTERNE
   - Priorité : IMPORTANTE
   - Action : Compléter la fiche existante "Rôle et limites de Bobodo"

6. **Orientation (détail)**
   - Titre : Service d'orientation Academia
   - Catégorie : ORIENTATION_ETUDES_EMPLOI
   - Priorité : IMPORTANTE
   - Action : Compléter la fiche existante "Orientation académique et professionnelle"

7. **Sécurité et confidentialité**
   - Titre : Sécurité et confidentialité sur Academia
   - Catégorie : NEXIOM_ACADEMIA_INTERNE
   - Priorité : IMPORTANTE
   - Justification : Procédure signalement/blocage manquante

8. **Enseignants (procédure)**
   - Titre : Comment solliciter un enseignant
   - Catégorie : NEXIOM_ACADEMIA_INTERNE
   - Priorité : IMPORTANTE
   - Action : Compléter la fiche existante "Accompagnement par des enseignants"

---

### LOT C – NE PAS INJECTER

**5 fiches à rejeter ou reporter**

1. **Marketplace (procédure)**
   - Statut : REPORTER
   - Justification : Existence connue, utilisation moins fréquente, priorité basse

2. **Challenges (procédure)**
   - Statut : REPORTER
   - Justification : Existence connue, utilisation moins fréquente, priorité basse

3. **Communautés (procédure)**
   - Statut : REPORTER
   - Justification : Existence connue, utilisation moins fréquente, priorité basse

4. **Cours en ligne (procédure)**
   - Statut : REPORTER
   - Justification : Existence connue, procédure relativement simple

5. **Lives (procédure)**
   - Statut : REPORTER
   - Justification : Existence connue, utilisation moins fréquente

6. **Opportunités (procédure)**
   - Statut : REJETER
   - Justification : Doublon avec fiche existante "Espace Opportunités"

---

### RÉSUMÉ DU PLAN D'INJECTION

| Lot | Nombre de fiches | Type d'action | Délai recommandé |
|-----|------------------|---------------|-----------------|
| LOT A | 7 | Nouvelles injections + compléments | Immédiat |
| LOT B | 8 | Compléments de fiches existantes | 1-2 semaines |
| LOT C | 6 | Reporter ou rejeter | À évaluer ultérieurement |

**Total fiches à créer/compléter** : 15 fiches

---

## CONCLUSION

Cet audit de gouvernance identifie :

1. **26 fiches existantes** dans `app.bobodo_knowledge` (13 historiques + 13 injectées le 8 juin 2026)
2. **15 fiches à créer/compléter** (7 critiques + 8 importantes)
3. **6 fiches à reporter/rejeter** (priorité basse ou doublons)
4. **8 catégories de connaissances** à classer selon le modèle EXPLIQUER/GUIDER/REDIRIGER/REFUSER
5. **Risques identifiés** : informations techniques, financières et sensibles à ne jamais exposer

**Recommandation principale** : Prioriser l'injection du LOT A (7 fiches critiques) pour répondre aux questions les plus fréquentes des étudiants : candidature, documents, critères, statuts, paiements, crédits IA.

---

**RAPPORT TERMINÉ – EN ATTENTE DE VALIDATION AVANT TOUTE INJECTION**
