# PLAN D'ENRICHISSEMENT MASSIF BOBODO

**Date** : 9 juin 2026  
**Objectif** : Faire passer Bobodo d'assistant fonctionnel à véritable compagnon étudiant Academia

---

## 1. ÉTAT ACTUEL

### Base de connaissances

- **Total fiches** : 33
- **Vectorisées** : 33 (100%)
- **Catégories** : 5 (NEXIOM_ACADEMIA_INTERNE, ORIENTATION_ETUDES_EMPLOI, academia, nexiom, process)

### Couverture actuelle

**Zones couvertes** :
- ✅ Universités partenaires (critères généraux)
- ✅ Processus de sélection (statuts candidature)
- ✅ Paiements (processus, crédits IA)
- ✅ Suivi candidature (dashboard, filtres)
- ✅ Documents nécessaires
- ✅ Navigation Academia (onglets, fonctionnalités)

**Zones partiellement couvertes** :
- ⚠️ Universités partenaires (pas de liste détaillée par université)
- ⚠️ Processus de sélection (pas de calendrier spécifique)
- ⚠️ Paiements (pas de détails sur LigdiCash)

---

## 2. ZONES NON COUVERTES PRIORITAIRES

### Priorité 1 - Questions les plus fréquentes

Basé sur les besoins étudiants typiques :

1. **Calendrier des admissions**
   - Dates limites par université
   - Calendrier des cycles d'admission
   - Périodes de candidature

2. **Bourses et aides financières**
   - Bourses disponibles par université
   - Critères d'éligibilité
   - Processus de demande

3. **Logement étudiant**
   - Options de logement sur le campus
   - Logement hors campus
   - Coût et réservation

4. **Coût de la vie**
   - Coût par ville/université
   - Budget mensuel estimé
   - Comparaison entre villes

5. **Conditions linguistiques**
   - Exigences TOEFL/IELTS
   - Tests acceptés
   - Scores minimums

### Priorité 2 - Processus administratifs

6. **Visas et documents de voyage**
   - Types de visas étudiants
   - Documents requis
   - Processus de demande

7. **Assurance étudiante**
   - Assurances obligatoires
   - Couverture requise
   - Coût

8. **Travail étudiant**
   - Droits de travail pendant les études
   - Limites d'heures
   - Permis de travail

### Priorité 3 - Vie étudiante

9. **Services de santé**
   - Services médicaux sur le campus
   - Assurance santé
   - Urgences

10. **Clubs et activités**
    - Associations étudiantes
    - Sports et loisirs
    - Événements

11. **Support psychologique**
    - Services de counseling
    - Bien-être mental
    - Ressources

### Priorité 4 - Carrière

12. **Orientation carrière**
    - Services d'orientation
    - Ateliers carrière
    - Mentorat

13. **Stages et opportunités**
    - Programmes de stage
    - Offres d'emploi
    - Salons de l'emploi

14. **Alumni et réseau**
    - Réseau d'anciens élèves
    - Événements alumni
    - Mentorat

---

## 3. STRATÉGIE D'ENRICHISSEMENT

### Phase 1 - LOT B (Immédiat)

**Objectif** : Créer 15-20 nouvelles fiches pour les zones prioritaires

**Fiches proposées** :
1. Calendrier des admissions universitaires
2. Bourses disponibles pour les étudiants internationaux
3. Logement étudiant - options et coûts
4. Coût de la vie par ville universitaire
5. Conditions linguistiques (TOEFL, IELTS)
6. Visa étudiant - types et processus
7. Assurance étudiante - exigences
8. Travail étudiant pendant les études
9. Services de santé sur le campus
10. Clubs et associations étudiantes
11. Support psychologique et bien-être
12. Services d'orientation carrière
13. Programmes de stage
14. Réseau d'anciens élèves
15. Programmes d'échange universitaire

### Phase 2 - LOT C (Enrichissement)

**Objectif** : Créer des fiches détaillées par université

**Approche** :
- Une fiche par université partenaire majeure
- Détails spécifiques (admission, coût, logement, vie étudiante)
- Informations pratiques (contact, localisation)

### Phase 3 - LOT D (Questions fréquentes)

**Objectif** : Créer des fiches FAQ basées sur les questions réelles

**Approche** :
- Analyser les logs de conversations Bobodo
- Identifier les questions récurrentes
- Créer des fiches ciblées

---

## 4. PROCESSUS DE CRÉATION

### Pour chaque nouvelle fiche

1. **Recherche**
   - Vérifier les informations existantes dans le code
   - Consulter la documentation Academia
   - Vérifier la cohérence fonctionnelle

2. **Rédaction**
   - Titre clair et descriptif
   - Contenu complet et précis
   - Tone conversationnel (comme Bobodo)
   - Exemples concrets

3. **Validation**
   - Vérifier les doublons
   - Vérifier la cohérence avec les fiches existantes
   - Valider contre le code réel

4. **Injection**
   - Créer le script SQL
   - Exécuter via Supabase SQL Editor
   - Générer les embeddings via Edge Function

---

## 5. CATÉGORIES PROPOSÉES

**Nouvelles catégories** :
- `UNIVERSITES_PARTENAIRES` : Fiches spécifiques par université
- `VIE_ETUDIANTE` : Logement, santé, clubs, bien-être
- `ADMINISTRATIF` : Visas, assurances, documents
- `CARRIERE` : Orientation, stages, alumni
- `FINANCES` : Bourses, aides, coût de la vie

---

## 6. GOUVERNANCE DES SOURCES

**Règles à respecter** :
- Aucune modification des règles métier existantes
- Maintenir la hiérarchie des connaissances
- Respecter le blocage des universités non autorisées
- Maintenir la gouvernance des sources

---

## 7. MÉTRIQUES DE SUCCÈS

**Objectifs** :
- 50 fiches supplémentaires (LOT B + C + D)
- Couverture des 20 zones identifiées
- Réduction des questions non répondues par Bobodo
- Amélioration de la satisfaction utilisateur

---

## 8. PROCHAINES ÉTAPES

1. **LOT B** : Créer les 15 fiches prioritaires
2. **Validation** : Vérifier la cohérence et supprimer les doublons
3. **Injection** : Injecter et vectoriser
4. **Tests** : Valider les réponses Bobodo
5. **LOT C** : Créer les fiches par université
6. **LOT D** : Créer les fiches FAQ

---

**PLAN TERMINÉ - PRÊT POUR CRÉATION LOT B**
