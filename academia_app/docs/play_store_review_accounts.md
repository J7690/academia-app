# Comptes de revue Google Play — Academia

> **Document confidentiel** — À fournir dans Play Console > App access > Instructions

## Mot de passe commun

```
AcademiaReview2026!
```

## Comptes par rôle

| Rôle | Email | Dashboard | User ID |
|------|-------|-----------|---------|
| **Étudiant** | `student.review@academia.test` | Accueil, Cours, Communautés, Challenges, Marketplace, Concours, TD | `0fc48f26-1f57-4e6b-96f9-1690f111cad3` |
| **Enseignant** | `instructor.review@academia.test` | Cours en ligne, Forum, Lives, Corrections | `d9ab017a-36bb-4286-9e33-bb5c5afd9eea` |
| **Université** | `university.review@academia.test` | Gestion programmes, Étudiants, Mini-site | `61ff7e68-3926-4242-a30e-9bc18407acf9` |
| **Administrateur** | `admin.review@academia.test` | Dashboard complet (27 onglets), Modération, Analytics | `5f0584e1-e260-4635-aba9-ad3352f31a6a` |
| **Commercial** | `commercial.review@academia.test` | Tableau de bord commercial, Commissions, Parrainages | `c47212f3-c9e8-42e9-bb9e-5429c903e0ef` |
| **Marchand** | `merchant.review@academia.test` | Console marketplace, Produits, Commandes | `641c34fd-9cbd-49da-aa79-504ddfcde504` |

## Instructions pour Google Play Console

Copier-coller dans **App access** :

```
Academia est une plateforme éducative multi-rôles. Voici les comptes de test :

── COMPTE ÉTUDIANT (rôle principal) ──
Email : student.review@academia.test
Mot de passe : AcademiaReview2026!
Accès : cours, communautés, challenges vidéo, marketplace, préparation concours, tuteur IA, messagerie

── COMPTE ENSEIGNANT ──
Email : instructor.review@academia.test
Mot de passe : AcademiaReview2026!
Accès : gestion cours en ligne, forums, sessions live, corrections

── COMPTE UNIVERSITÉ ──
Email : university.review@academia.test
Mot de passe : AcademiaReview2026!
Accès : gestion programmes, étudiants inscrits, mini-site universitaire

── COMPTE ADMINISTRATEUR ──
Email : admin.review@academia.test
Mot de passe : AcademiaReview2026!
Accès : tableau de bord complet, modération UGC, analytics, gestion utilisateurs

── COMPTE COMMERCIAL ──
Email : commercial.review@academia.test
Mot de passe : AcademiaReview2026!
Accès : tableau de bord commercial, commissions, parrainages

── COMPTE MARCHAND ──
Email : merchant.review@academia.test
Mot de passe : AcademiaReview2026!
Accès : console marketplace, gestion produits, commandes

Note : L'application détecte automatiquement le rôle à la connexion et affiche le dashboard correspondant.
```

## Fonctionnalités testables par rôle

### Étudiant
- Naviguer entre les onglets (Accueil, Candidatures, Cours, Communautés, Partenaires, Prépa Concours, TD, Challenges, Lives)
- Publier un commentaire dans une communauté
- Signaler un message / bloquer un utilisateur
- Accéder au tuteur IA (crédits de bienvenue inclus)
- Voir les vidéos du feed Challenge
- Supprimer son propre message (DM, communauté, forum)
- Supprimer son compte depuis Paramètres

### Administrateur
- Consulter les signalements (onglet Modération UGC)
- Résoudre / rejeter un signalement
- Suspendre un utilisateur
- Consulter les analytics de navigation
- Gérer les communautés, challenges, marketplace

### Enseignant
- Voir ses cours assignés
- Gérer les sessions live
- Corriger les devoirs

### Université
- Voir les programmes
- Consulter les candidatures

### Commercial
- Voir ses commissions
- Consulter ses parrainages

### Marchand
- Gérer ses produits marketplace
- Consulter ses commandes

## Notes techniques

- Les comptes sont confirmés automatiquement (pas de vérification email nécessaire)
- Le rôle est stocké dans `user_metadata.role` de Supabase Auth
- L'AuthWrapper redirige automatiquement vers le bon dashboard selon le rôle
- Les comptes de test ne nécessitent aucune intervention manuelle
