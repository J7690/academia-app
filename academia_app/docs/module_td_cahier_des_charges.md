# 📘 ACADEMIA – MODULE TRAVAUX DIRIGÉS (TD)

## Wireframes · Base de données · Permissions · Workflow · Cahier des charges

---

# 1️⃣ WIREFRAMES DÉTAILLÉS (DESCRIPTION FONCTIONNELLE)

> ⚠️ Ce sont des **wireframes fonctionnels textuels** (UX + UI logic), conçus pour être traduits directement en écrans Flutter.

---

## 🟥 1.1 WIREFRAME — ADMINISTRATEUR TD

### 🔹 Écran A1 – Dashboard Admin (Cockpit)

**Header**

* Logo Academia
* Menu latéral (TD, Étudiants, Enseignants, Programmes, Paiements, Messages)

**Cards principales**

* 🟠 Paiements TD en attente
* 🔵 Étudiants à orienter
* 🟢 Enseignants disponibles
* 🟣 TD programmés cette semaine
* 💰 Revenus TD (jour / mois)

---

### 🔹 Écran A2 – Gestion des Filières

* Bouton ➕ Créer filière
* Liste des filières

  * Nom
  * Niveaux associés
  * Nombre de programmes TD
  * Statut (Actif / Désactivé)

**Actions admin**

* Modifier
* Désactiver
* Supprimer

---

### 🔹 Écran A3 – Gestion des Programmes & TD

* Bouton ➕ Créer programme TD
* Formulaire :

  * Filière
  * Niveau
  * Titre
  * Description
  * Modalité (En ligne / Présentiel / Hybride)
  * Prix
* Ajout de :

  * collections TD
  * séances
  * sujets
  * documents (PDF, corrigés)

👉 **Seul l’admin voit cet écran**

---

### 🔹 Écran A4 – Gestion des Enseignants

* Bouton ➕ Créer enseignant
* Fiche enseignant :

  * Nom
  * Discipline
  * Niveaux
  * Zone géographique
  * Disponibilité
* Actions :

  * Suspendre
  * Supprimer
  * Voir historique affectations

---

### 🔹 Écran A5 – Paiements & Affectation (ÉCRAN CLÉ)

Quand un étudiant paie :

**Carte demande**

* Étudiant
* Filière
* Niveau
* Type TD
* Zone

**Action admin**

* Sélection enseignant (liste filtrée)
* Bouton 👉 Assigner

➡️ Notification enseignant déclenchée **après validation**

---

### 🔹 Écran A6 – Messagerie centrale

* Conversations :

  * Étudiant ↔ Admin
  * Enseignant ↔ Admin
* Historique conservé
* Pièces jointes possibles

---

## 🟦 1.2 WIREFRAME — ENSEIGNANT

### 🔹 Écran E1 – Dashboard Enseignant

* TD assignés
* Étudiants affectés
* Planning
* Statut missions

❌ Pas de bouton “Créer”
❌ Pas de modification

---

### 🔹 Écran E2 – Détail TD

* Informations TD
* Liste étudiants
* Accès documents (créés par admin)

---

### 🔹 Écran E3 – Messagerie Admin

* Propositions de nouveaux TD (message)
* Questions pédagogiques

---

## 🟩 1.3 WIREFRAME — ÉTUDIANT

### 🔹 Écran S1 – Catalogue TD

* Filtres : filière / niveau
* Cartes TD :

  * Titre
  * Modalité
  * Prix
  * Badge 🔓 / 🔒

---

### 🔹 Écran S2 – Détail TD

✔ Visible gratuitement :

* Objectifs
* Sujets (titres)
* Planning

❌ Verrouillé :

* Téléchargements
* Corrigés
* Certificat

---

### 🔹 Écran S3 – Paiement

* Choix :

  * Collection
  * Document
  * Certification
* Paiement
* Statut : **En attente validation admin**

---

### 🔹 Écran S4 – Messagerie Admin

* Demandes
* Questions
* Suivi orientation

---

# 2️⃣ SCHÉMA DE BASE DE DONNÉES (SIMPLIFIÉ & EXACT)

### 2.1 Tables principales (noms RÉELS Supabase)

```text
-- Schéma logique TD implémenté dans le schéma app

app.td_fields
- id UUID PRIMARY KEY
- name TEXT
- status TEXT (ex: active / inactive)

app.td_programs
- id UUID PRIMARY KEY
- field_id UUID -> app.td_fields.id
- level TEXT
- title TEXT
- description TEXT
- modality td_modality (online | onsite | hybrid)
- price NUMERIC(12,2)
- currency TEXT (ex: XOF)
- status td_program_status (draft | published | inactive)

app.td_collections
- id UUID PRIMARY KEY
- program_id UUID -> app.td_programs.id
- title TEXT
- description TEXT
- position INTEGER

app.td_sessions
- id UUID PRIMARY KEY
- collection_id UUID -> app.td_collections.id
- title TEXT
- document_url TEXT (contenu verrouillé côté UI)
- is_preview BOOLEAN
- position INTEGER

app.td_teachers
- id UUID PRIMARY KEY
- user_id UUID -> auth.users.id
- full_name TEXT
- discipline TEXT
- zone TEXT
- levels TEXT[]
- availability TEXT
- status TEXT (active | suspended | removed)

app.td_enrollments
- id UUID PRIMARY KEY
- student_id UUID -> auth.users.id
- program_id UUID -> app.td_programs.id
- collection_id UUID? -> app.td_collections.id
- access_scope TEXT (program | collection | document | certification)
- payment_id UUID -> app.application_payments.id
- access_status td_enrollment_status
- assignment_status td_assignment_status
- assigned_teacher_id UUID? -> app.td_teachers.id
- activated_at TIMESTAMPTZ?
- completed_at TIMESTAMPTZ?

-- Réutilisation du moteur de paiement global
app.application_payments
- id UUID PRIMARY KEY
- student_id UUID -> auth.users.id
- amount_due NUMERIC(12,2)
- amount_paid NUMERIC(12,2)?
- payment_reason payment_reason (inclut la valeur 'td_access')
- status payment_status
- reference_code TEXT

app.td_messages
- id UUID PRIMARY KEY
- td_enrollment_id UUID -> app.td_enrollments.id
- thread_type TEXT (student_admin | teacher_admin)
- student_user_id UUID -> auth.users.id
- teacher_user_id UUID -> auth.users.id
- admin_user_id UUID -> auth.users.id
- sender_role TEXT (admin | student | teacher)
- sender_user_id UUID -> auth.users.id
- content TEXT
- attachment_url TEXT?
- created_at TIMESTAMPTZ
- read_at TIMESTAMPTZ?
```

### 2.2 Types ENUM & intégration paiements / notifications

- `td_modality` : `online | onsite | hybrid`
- `td_program_status` : `draft | published | inactive`
- `td_enrollment_status` : `pending_payment | waiting_admin | active | completed | cancelled`
- `td_assignment_status` : `unassigned | assigned | closed`
- `payment_reason` (existant) : **nouvelle valeur** `td_access` pour distinguer les paiements TD.

Conséquence :
- tous les paiements TD passent par `app.application_payments` avec `payment_reason = 'td_access'` ;
- les triggers et notifications existants (`student_payments`, `admin_payments`) s'appliquent automatiquement aux TD.

---

# 3️⃣ MATRICE PERMISSIONS & RLS (CLAIRE)

| Action              | Admin | Enseignant  | Étudiant |
| ------------------- | ----- | ----------- | -------- |
| Créer filière       | ✅     | ❌           | ❌        |
| Créer TD            | ✅     | ❌           | ❌        |
| Modifier TD         | ✅     | ❌           | ❌        |
| Voir TD             | ✅     | ✅ (assigné) | ✅        |
| Télécharger         | ✅     | ❌           | 💳       |
| Assigner enseignant | ✅     | ❌           | ❌        |
| Messagerie          | ✅     | ↔ Admin     | ↔ Admin  |

---

# 4️⃣ WORKFLOW PAIEMENT → VALIDATION → ACCÈS

```text
Étudiant consulte TD
      ↓
Étudiant paie
      ↓
Paiement = EN ATTENTE
      ↓
Admin notifié
      ↓
Admin analyse (niveau, zone)
      ↓
Admin assigne enseignant
      ↓
Accès étudiant débloqué
      ↓
Notification enseignant
      ↓
TD exécuté
```

❌ Aucun automatisme
✅ Contrôle humain total

---

# 5️⃣ CAHIER DES CHARGES OFFICIEL (PRÊT PDF)

## 🎯 Objectif

Créer un module TD premium, centralisé, institutionnel, piloté par l’administrateur.

## 🎓 Philosophie

* L’étudiant consomme
* L’enseignant exécute
* L’administrateur orchestre

## 🎨 Design

* Application mobile éducative
* Couleurs douces + accents forts
* Icônes pédagogiques
* Zéro look “site web”

## 💰 Monétisation

* Paiement progressif
* Accès contrôlé
* Certification payante

## 🔐 Gouvernance

* Centralisation
* Qualité
* Traçabilité

---

# 6️⃣ MESSAGE FINAL À WINSURF (COPIER-COLLER)

> Le module TD d’Academia repose sur un administrateur central unique.
> L’administrateur crée toutes les filières, programmes, TD et collections.
> Les enseignants et les étudiants ne créent aucun contenu.
> Ils consultent, communiquent avec l’admin, et exécutent après validation.
> Le design doit être moderne, coloré, pédagogique, type application mobile éducative.

---

## ✅ Prochaine étape possible

* Export **PDF prêt à envoyer**
* Découpage en **tickets techniques**
* Mapping Flutter (screens + providers)
* Mapping Supabase (tables + RLS exactes)

👉 Dis-moi **ce que tu veux en premier**, et je te le livre immédiatement.
