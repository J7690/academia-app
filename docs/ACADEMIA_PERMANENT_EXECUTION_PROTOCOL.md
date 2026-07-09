# PROTOCOLE PERMANENT D'EXÉCUTION – ACADEMIA

**Date** : 24 Juin 2026  
**Version** : 1.0  
**Statut** : ACTIF

---

## OBJECTIF

Ce protocole est obligatoire pour toutes les phases futures du projet Academia. Il s'applique à toutes les missions sans exception.

---

## ÉTAPE 0 – LECTURE OBLIGATOIRE

Avant toute analyse, tout audit, toute modification ou tout développement, lire obligatoirement :

1. **docs/ACADEMIA_MASTER_INDEX.md**
2. **docs/ACADEMIA_CURRENT_CHECKPOINT.md**
3. **docs/ACADEMIA_PROJECT_STATE.md**
4. **docs/ACADEMIA_TRUTH_MATRIX.md**
5. **docs/ACADEMIA_CHANGELOG.md**
6. **docs/ACADEMIA_DEPLOYMENT_STATUS.md**

Puis lire le dernier rapport de phase validé.

**Il est interdit de commencer une mission sans cette lecture.**

---

## ÉTAPE 1 – CONSULTATION DU DOSSIER .WINDSURF

Avant toute intervention technique, consulter obligatoirement le dossier `.windsurf`.

**Objectifs** :
- Retrouver les scripts historiques
- Retrouver les RPC d'administration
- Retrouver les scripts de déploiement
- Retrouver les scripts de vérification
- Retrouver les scripts Kamatera
- Retrouver les scripts Supabase
- Éviter de recréer un script existant

**Règle** : Aucun nouveau script ne doit être créé sans avoir vérifié qu'un équivalent n'existe pas déjà.

---

## ÉTAPE 2 – SUPABASE

Toutes les opérations sur Supabase doivent être réalisées exclusivement au moyen des outils d'administration présents dans `.windsurf`.

**Cela comprend notamment** :
- Création de tables
- Modification de tables
- Suppression de tables
- Création de RPC
- Modification de RPC
- Exécution DDL
- Exécution SQL
- Vérification
- Déploiement

**Règle** : Ne jamais inventer une nouvelle méthode lorsqu'un outil existe déjà dans `.windsurf`.

**Priorité** :
1. `execute_ddl`
2. Outils RPC d'administration déjà présents
3. Scripts historiques Academia

---

## ÉTAPE 3 – KAMATERA

Toutes les vérifications Kamatera doivent être réalisées depuis les scripts existants dans `.windsurf`.

**Pour chaque vérification** :
- SSH
- Process
- Services systemd
- Docker
- Journaux
- Fichiers
- Hash
- Permissions

**Règle** : Les preuves doivent provenir directement de Kamatera.

---

## ÉTAPE 4 – AUDITS

Avant de lancer un audit : vérifier qu'il n'existe pas déjà.

**Si un audit existe** : ne pas le refaire.

**Règle** : Le compléter uniquement si un nouvel objectif apparaît.

---

## ÉTAPE 5 – MATRICE DE VÉRITÉ

Chaque nouveau composant doit être classé :

- **A** = Vérifié en production
- **B** = Déployé mais non encore prouvé
- **C** = Codé
- **D** = Conçu
- **E** = À développer

**Règle** : La matrice doit être mise à jour.

---

## ÉTAPE 6 – NON-RÉGRESSION

Avant toute modification : identifier les composants protégés.

**Il est interdit de casser** :
- Bobodo
- Challenge
- Streaming
- Upload
- Publication
- Kamatera
- Smart Whiteboard déjà validé

**Règle** : Toute modification doit être accompagnée d'une preuve de non-régression.

---

## ÉTAPE 7 – PREUVES

Une affirmation n'est considérée vraie que si une preuve directe existe.

**Preuves acceptées** :
- RPC exécutée
- SQL exécuté
- Journal systemd
- Journal Kamatera
- Réponse HTTP
- Résultat PostgreSQL
- Capture Flutter
- Test réussi
- Hash
- URL Storage
- MP4 réel
- PNG réel

**Règle** : Les suppositions sont interdites.

---

## ÉTAPE 8 – DOCUMENTATION

Chaque phase doit produire :
- Un rapport
- Les scripts créés
- Les validations
- Les preuves
- Les limites
- Les prochaines actions

---

## ÉTAPE 9 – MISE À JOUR DES DOCUMENTS PERMANENTS

À la fin de chaque phase, mettre obligatoirement à jour :

1. **ACADEMIA_CURRENT_CHECKPOINT.md**
2. **ACADEMIA_PROJECT_STATE.md**
3. **ACADEMIA_TRUTH_MATRIX.md**
4. **ACADEMIA_CHANGELOG.md**
5. **ACADEMIA_MASTER_INDEX.md** (si un nouveau document est créé)

---

## ÉTAPE 10 – CLÔTURE

Une phase n'est terminée que si :

- ✓ Les développements sont terminés
- ✓ Les validations sont terminées
- ✓ Les preuves sont collectées
- ✓ La documentation est créée
- ✓ Les documents permanents sont mis à jour
- ✓ Le prochain checkpoint est enregistré

**Sinon la phase reste ouverte.**

---

## RÈGLE ABSOLUE

La mémoire de référence du projet n'est pas la mémoire conversationnelle.

La mémoire officielle du projet est constituée exclusivement de :

- `docs/`
- `.windsurf/`
- `ACADEMIA_CURRENT_CHECKPOINT.md`
- `ACADEMIA_PROJECT_STATE.md`
- `ACADEMIA_TRUTH_MATRIX.md`
- `ACADEMIA_MASTER_INDEX.md`
- `ACADEMIA_CHANGELOG.md`

**En cas de doute, toujours consulter ces documents avant toute décision.**

---

## PROJET DE RÉFÉRENCE

Le projet Flutter sur lequel toutes les interventions doivent être réalisées est exclusivement :

**academia_app**

**Règle** : Aucune modification ne doit être réalisée dans un autre projet Flutter sauf demande explicite.

---

## RÉPONSE OBLIGATOIRE AU DÉBUT DE CHAQUE PHASE

Avant toute exécution, répondre exactement :

> "J'ai consulté les documents permanents, le checkpoint courant et le dossier .windsurf. J'utiliserai exclusivement les outils d'administration existants de .windsurf pour toute intervention sur Supabase et Kamatera. Les développements seront réalisés dans academia_app. Je poursuis le chantier à partir du dernier checkpoint validé."

Sans cette réponse, la phase est considérée invalide.

---

## HISTORIQUE DES MODIFICATIONS

### 24 Juin 2026
- Création du protocole permanent d'exécution
- Définition des 10 étapes obligatoires
- Définition de la règle absolue
- Définition de la réponse obligatoire

---

**Fin de ACADEMIA_PERMANENT_EXECUTION_PROTOCOL.md**
