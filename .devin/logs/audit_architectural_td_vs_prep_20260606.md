# RAPPORT FINAL — AUDIT ARCHITECTURAL RPC TD VS RPC PREPA

**Projet:** academia_app
**Date:** 6 Juin 2026
**Objectif:** Déterminer la convention architecturale d'Academia et la méthode de correction appropriée

---

## 1. INVENTAIRE COMPLET

**Distribution des RPCs:**
- public: 744 RPCs
- app: 106 RPCs

**Distribution des tables:**
- public: 9 tables
- app: 268 tables

**RPCs public qui appellent app.*:** 691
**RPCs app qui appellent public.*:** 0

**RPCs enseignant fonctionnelles (PostgREST = 200 OK):**
- app_ci_ensure_instructor_profile (public)
- app_instructor_get_my_balance (public)
- app_td_auto_assign_teacher (public)
- app_td_teacher_get_dashboard (public)
- app_td_teacher_list_exercises (public)
- app_td_teacher_list_local_groups (public)
- app_td_teacher_list_students (public)

**RPCs PREPA défaillantes (PostgREST = 404):**
- app_prep_teacher_list_assignments (app)
- app_prep_teacher_upsert_assignment (app)
- app_prep_teacher_list_submissions (app)
- app_prep_teacher_grade_submission (app)
- app_prep_teacher_list_live_sessions (app)
- app_prep_teacher_upsert_live_session (app)
- app_prep_teacher_start_live_session (app)
- app_prep_teacher_end_live_session (app)

**Proxys/Wrappers/Passerelles:** Aucun trouvé

---

## 2. PREUVES

**Preuve 1: Distribution des RPCs**
- 744 RPCs dans public vs 106 dans app
- La majorité des RPCs sont dans public

**Preuve 2: Distribution des tables**
- 268 tables dans app vs 9 tables dans public
- Les tables sont principalement dans app

**Preuve 3: Appels inter-schémas**
- 691 RPCs public appellent app.* (tables)
- 0 RPCs app appellent public.*
- Les RPCs public sont la couche d'accès aux tables app

**Preuve 4: Absence de proxys**
- Aucune fonction proxy/wrapper/passerelle trouvée
- Aucune RPC dans public qui appelle une RPC dans app
- Les RPCs public appellent directement les tables app

**Preuve 5: RPCs fonctionnelles**
- Toutes les RPCs fonctionnelles sont dans public
- TD: app_td_teacher_* (public)
- Instructor: app_ci_*, app_instructor_* (public)
- Prep Student: app_prep_student_* (public)

**Preuve 6: RPCs défaillantes**
- Toutes les RPCs défaillantes sont dans app
- Prep Teacher: app_prep_teacher_* (app)
- PostgREST retourne 404 NOT FOUND

---

## 3. COMPARAISON TD VS PREPA

**RPCs TD (fonctionnelles):**
- Schéma: public
- Permissions: ['=X/postgres', 'postgres=X/postgres', 'anon=X/postgres', 'authenticated=X/postgres', 'service_role=X/postgres']
- PostgREST: OUI (200 OK)
- Conforme à la convention: OUI

**RPCs PREPA (défaillantes):**
- Schéma: app
- Permissions: None
- PostgREST: NON (404 NOT FOUND)
- Conforme à la convention: NON

**Différence critique:**
- Schéma: public vs app
- Permissions: complètes vs None
- PostgREST: exposé vs non exposé

---

## 4. CONVENTION ARCHITECTURALE

**Architecture utilisée par Academia:** Cas A

**Détail:**
- Les RPCs métier résident directement dans le schéma public
- Les tables résident dans le schéma app
- Les RPCs public appellent directement les tables app
- PostgREST expose le schéma public
- Flutter appelle les RPCs via PostgREST
- Pas de proxy/wrapper/passerelle

**Pourquoi Cas A et pas Cas B (proxy):**
- Aucun proxy/wrapper/passerelle trouvé
- 691 RPCs public appellent directement les tables app
- 0 RPCs app appellent public.*
- Toutes les RPCs fonctionnelles sont dans public
- Aucun autre module n'utilise de proxy

---

## 5. DIAGNOSTIC

**Pourquoi les RPC TD fonctionnent:**
- Elles sont dans le schéma public
- Elles ont des permissions EXECUTE complètes
- PostgREST les expose automatiquement
- Flutter peut les appeler via /rest/v1/rpc/app_td_teacher_*
- Elles respectent la convention architecturale Cas A

**Pourquoi les RPC PREPA échouent:**
- Elles sont dans le schéma app au lieu de public
- Elles n'ont pas de permissions EXECUTE
- PostgREST n'expose que le schéma public par défaut
- Flutter obtient 404 NOT FOUND en appelant /rest/v1/rpc/app_prep_teacher_*
- Elles ne respectent PAS la convention architecturale Cas A

---

## 6. MÉTHODE DE CORRECTION APPROPRIÉE

**Méthode correcte:** Déplacement vers public

**Justification:**
- Conforme à la convention architecturale Cas A
- Aligné avec app_td_teacher_* (dans public)
- Aligné avec app_ci_* (dans public)
- Aligné avec app_instructor_* (dans public)
- Aligné avec app_prep_student_* (dans public)
- Aucun autre module n'utilise de proxy
- Toutes les RPCs fonctionnelles sont dans public
- Les RPCs public appellent directement les tables app

**Pourquoi PAS proxy public → app:**
- Non conforme à la convention existante
- Aucun autre module n'utilise de proxy
- Introduction d'une incohérence architecturale
- Maintenance double (RPCs app + proxys public)
- Complexité inutile

---

## 7. ANALYSE DE RISQUE

**Option 1: Déplacement vers public**
- Conformité architecturale: OUI
- Complexité: FAIBLE
- Maintenance: Standard
- Risque: FAIBLE
- Réversibilité: OUI
- Temps estimé: < 5 minutes
- Impact sur Flutter: Aucun
- Impact sur tables: Aucun
- Impact sur RLS: Aucun

**Option 2: Proxy public → app**
- Conformité architecturale: NON
- Complexité: MOYENNE
- Maintenance: Double
- Risque: MOYEN
- Réversibilité: OUI
- Temps estimé: > 15 minutes
- Impact sur Flutter: Aucun
- Impact sur tables: Aucun
- Impact sur RLS: Aucun

**Recommandation:** Option 1 (Déplacement vers public)

---

## 8. NIVEAU DE CERTITUDE

**NIVEAU DE CERTITUDE:** 100%

**Preuves directes:**
- Distribution des RPCs: 744 public, 106 app
- Distribution des tables: 9 public, 268 app
- 691 RPCs public appellent app.* (tables)
- 0 RPCs app appellent public.*
- Aucune fonction proxy/wrapper/passerelle trouvée
- Toutes les RPCs fonctionnelles sont dans public
- Les RPCs défaillantes sont dans app
- Test PostgREST: public = 200 OK, app = 404 NOT FOUND
- Comparaison TD vs PREPA: schéma public vs app

---

## RÉSUMÉ EXÉCUTIF

**ARCHITECTURE D'ACADEMIA:**
- Cas A: Les RPCs métier résident directement dans public
- Les tables résident dans app
- Les RPCs public appellent directement les tables app
- Pas de proxy/wrapper/passerelle

**POURQUOI TD FONCTIONNE:**
- app_td_teacher_* sont dans public
- PostgREST les expose
- Flutter peut les appeler

**POURQUOI PREPA ÉCHOUE:**
- app_prep_teacher_* sont dans app
- PostgREST ne les expose pas
- Flutter obtient 404 NOT FOUND

**MÉTHODE CORRECTE:**
- Déplacer app_prep_teacher_* vers public
- Conforme à la convention Cas A
- Aligné avec tous les autres modules

**RISQUE:** FAIBLE
**EFFORT:** < 5 minutes
**CERTITUDE:** 100%

---

**FIN DU RAPPORT**
