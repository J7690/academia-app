# BOBODO FIELD VALIDATION GUIDE

**Date** : 9 juin 2026  
**Objectif** : Valider le comportement réel de Bobodo avec les 5 nouvelles fiches LOT B Phase 1

---

## INSTRUCTIONS

1. Ouvrir l'application Flutter Academia
2. Se connecter avec un compte étudiant
3. Naviguer vers l'onglet Bobodo
4. Tester chaque scénario ci-dessous
5. Noter les réponses et les notes
6. Compléter le rapport final

---

## PHASE 1 – TESTS FONCTIONNELS RÉELS

### Compte

**Scénario 1** : "Comment créer un compte ?"
- **Attendu** : Bobodo explique le processus d'inscription (nom, prénom, email, mot de passe, email de confirmation, code de parrainage)
- **Note** : ___/5

**Scénario 2** : "Je veux m'inscrire."
- **Attendu** : Bobodo guide vers l'écran d'inscription
- **Note** : ___/5

**Scénario 3** : "Je n'arrive pas à créer mon compte."
- **Attendu** : Bobodo propose de contacter Support si le problème persiste
- **Note** : ___/5

### Profil

**Scénario 4** : "Comment modifier mon profil ?"
- **Attendu** : Bobodo explique comment accéder à "Mon profil" et modifier les informations (nom, téléphone, pays, ville, date de naissance, BEPC, BAC, projet d'étude)
- **Note** : ___/5

**Scénario 5** : "Je veux changer mes informations."
- **Attendu** : Bobodo guide vers l'onglet "Mon profil"
- **Note** : ___/5

### Paiements

**Scénario 6** : "Mon paiement est en attente."
- **Attendu** : Bobodo explique que c'est normal (validation en cours), liste les canaux (Orange Money, Moov Money, Telecel Cash, LigdiCash), et propose de contacter Support après 24h
- **Note** : ___/5

**Scénario 7** : "J'ai payé mais rien ne change."
- **Attendu** : Bobodo explique le délai de validation et propose de vérifier la confirmation de l'opérateur
- **Note** : ___/5

**Scénario 8** : "Mon paiement ne passe pas."
- **Attendu** : Bobodo propose de contacter Support via l'icône flottante
- **Note** : ___/5

### Candidatures

**Scénario 9** : "Ma candidature est bloquée."
- **Attendu** : Bobodo explique les statuts possibles (brouillon, envoyée, en examen, acceptée, refusée, annulée) et propose de contacter Support en cas de doute
- **Note** : ___/5

**Scénario 10** : "Je ne vois pas l'évolution de ma candidature."
- **Attendu** : Bobodo guide vers l'onglet "Candidatures" pour vérifier le statut
- **Note** : ___/5

### Cours d'appui

**Scénario 11** : "Où trouver les cours d'appui ?"
- **Attendu** : Bobodo explique comment accéder à l'onglet "TD" et liste les sections disponibles (catalogue, inscriptions, ressources, classement, stats, IA Tuteur, groupes locaux, exercices)
- **Note** : ___/5

**Scénario 12** : "Je cherche un enseignant."
- **Attendu** : Bobodo guide vers l'onglet "TD" pour accéder aux cours d'appui et à l'IA Tuteur
- **Note** : ___/5

---

## PHASE 2 – TESTS CONVERSATIONNELS

Pour chaque scénario, vérifier :

### Utilisation du prénom
- Bobodo utilise-t-il le prénom de l'étudiant ?
- Note : ___/5

### Mémoire de la conversation
- Bobodo se souvient-il du contexte précédent ?
- Note : ___/5

### Rebond naturel
- Les réponses sont-elles naturelles et fluides ?
- Note : ___/5

### Absence de ton administratif
- Le ton est-il conversationnel et non administratif ?
- Note : ___/5

### Encouragements
- Bobodo encourage-t-il l'étudiant naturellement ?
- Note : ___/5

### Cohérence du contexte
- Les réponses sont-elles cohérentes avec le contexte ?
- Note : ___/5

---

## PHASE 3 – TESTS SUPPORT

Vérifier que Bobodo redirige correctement vers l'icône flottante Support lorsque :

### Scénario 13 : Information non disponible
- **Question** : Poser une question hors du périmètre des 5 fiches
- **Attendu** : Bobodo propose de contacter Support
- **Résultat** : ✅ / ❌

### Scénario 14 : Utilisateur insatisfait
- **Question** : "Ce n'est pas clair" ou "Je ne comprends pas"
- **Attendu** : Bobodo reformule puis propose Support si insatisfaction persiste
- **Résultat** : ✅ / ❌

### Scénario 15 : Intervention humaine requise
- **Question** : "Mon paiement est bloqué depuis 3 jours"
- **Attendu** : Bobodo propose de contacter Support via l'icône flottante
- **Résultat** : ✅ / ❌

---

## PHASE 4 – TESTS DE QUALITÉ

Pour chaque scénario, attribuer une note (1 à 5) :

### Compréhension
- Bobodo comprend-il correctement la question ?
- Note moyenne : ___/5

### Pertinence
- La réponse est-elle pertinente et utile ?
- Note moyenne : ___/5

### Ton
- Le ton est-il chaleureux et bienveillant ?
- Note moyenne : ___/5

### Naturel
- Les réponses sont-elles naturelles et non robotiques ?
- Note moyenne : ___/5

### Utilité
- La réponse aide-t-elle réellement l'étudiant ?
- Note moyenne : ___/5

---

## ANOMALIES OBSERVÉES

Lister toutes les anomalies détectées :

1. 
2. 
3. 
4. 
5. 

---

## AMÉLIORATIONS RECOMMANDÉES

Lister les améliorations recommandées :

1. 
2. 
3. 
4. 
5. 

---

## CONDITION D'OUVERTURE DU LOT B PHASE 2

Le LOT B Phase 2 ne sera ouvert que si :

- Compréhension ≥ 4/5 : ___
- Pertinence ≥ 4/5 : ___
- Naturel ≥ 4/5 : ___
- Aucune anomalie critique : ___

**Validation** : ✅ / ❌

---

## NOTES SUPPLÉMENTAIRES

Ajouter toute observation supplémentaire ici :

