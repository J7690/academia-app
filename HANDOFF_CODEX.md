# PASSATION A CODEX — Candidatures : telephone, WhatsApp, messagerie, paiements

Tu reprends un chantier en cours sur le depot Academia. Ce document contient
TOUT ce dont tu as besoin : ce qui est fait, ce qui reste, ou sont les choses,
et ce que tu ne dois pas toucher.

---

## 0. REGLES STRICTES — A LIRE AVANT TOUT

1. **Travaille uniquement dans `academia_app/`** pour le code Flutter.
   Le `lib/` et `pubspec.yaml` a la RACINE sont un vieux projet historique :
   n'y touche JAMAIS. Le dossier `./flutter/` est un SDK committe : ignore-le.
2. **Ne fais JAMAIS `git commit` ni `git push`** sans autorisation explicite
   de l'utilisateur. Laisse les fichiers modifies dans le working tree.
3. **Ne touche pas** aux fichiers `whiteboard_*`, `academia_bobodo_backend/`,
   au systeme de parrainage (`referral-*`, `install_referrer_service`,
   `deep_link_service`, `share_tracking_service`, `netlify.toml`, `_redirects`).
   Ce sont d'autres chantiers, certains deja deployes en production.
4. **En SQL, JAMAIS `||` pour concatener des tableaux TEXT[]** — toujours
   `array_append`. Le `||` sur un litteral non type a bloque 97 % des
   etudiants pendant un mois (defaut connu et documente).
5. **N'affiche jamais la SERVICE_ROLE_KEY** ni aucun secret dans tes reponses.
6. **Ne modifie pas les fichiers de migration deja appliques.** Cree de
   nouvelles migrations datees si besoin.

---

## 1. OU EST QUOI

| Chose | Chemin |
|---|---|
| App Flutter (la vraie) | `C:\Users\fasop\AndroidStudioProjects\academia\academia_app\` |
| Sources Flutter | `academia_app\lib\` |
| Migrations Supabase | `supabase\migrations\` |
| Chargeur de secrets | `.windsurf\env_loader.py` (fournit `SERVICE_ROLE_KEY`) |
| Projet Supabase prod | `https://thevdfcwlcqzdoybfvgs.supabase.co` |
| Schema metier | `app` (PAS expose via PostgREST : acces uniquement par les RPC `public.app_*`) |
| Branche de travail | `candidature-dossier-inline` |

### Executer du SQL sur Supabase (le seul moyen)

Il n'y a pas de psql. On passe par la RPC `admin_execute_sql` :

```python
import sys, requests
sys.path.insert(0, r"C:\Users\fasop\AndroidStudioProjects\academia\.windsurf")
from env_loader import SERVICE_ROLE_KEY

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
H = {"apikey": SERVICE_ROLE_KEY,
     "Authorization": "Bearer " + SERVICE_ROLE_KEY,
     "Content-Type": "application/json"}

r = requests.post(URL + "/rest/v1/rpc/admin_execute_sql",
                  headers=H, json={"p_sql": "TON SQL ICI"}, timeout=60)
data = r.json()
# Succes : data.get("ok") == True
# SELECT : parfois data["rows"] present, parfois juste "affected_rows"
# Pour lire les rows de facon fiable : SELECT prosrc FROM pg_proc ...
```

Pieges connus de `admin_execute_sql` :
- **BEGIN/COMMIT interdits** → erreur `0A000`. Applique les statements un par un.
- Certaines requetes SELECT (`count(*)`, `CASE`, `pg_get_function_arguments`)
  retournent `mode:"exec"` sans `rows`. Pour verifier le corps d'une fonction,
  `SELECT p.prosrc FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE p.proname='nom'` fonctionne bien.
- **CREATE OR REPLACE avec une signature differente cree une SURCHARGE**,
  il ne remplace pas. Il faut `DROP FUNCTION` l'ancienne signature d'abord.

---

## 2. ETAT D'AVANCEMENT — ce qui est DEJA FAIT et VERIFIE

### Base de donnees : TERMINE et verifie en production

La migration `supabase/migrations/20260920100000_telephone_whatsapp_obligatoires_candidature.sql`
a ete **appliquee en production** et verifiee via `prosrc` :

- `app.students.whatsapp_phone` (TEXT, nullable) : colonne creee.
- `app_student_update_full_profile` : nouvelle signature 24 params avec
  `p_whatsapp_phone` ; l'ancienne surcharge 23 params a ete DROPee.
  COALESCE partout (null = ne pas ecraser).
- `app_is_student_dossier_complete` : exige maintenant `full_name`,
  `last_diploma`, `phone`, `whatsapp_phone` (via `array_append`).
- `app_get_university_application_detail` : retourne `whatsapp_phone` dans
  `student_profile`, et inclut phone/whatsapp_phone dans son controle interne
  de dossier incomplet.

### Flutter : PARTIELLEMENT FAIT — LE CODE NE COMPILE PAS EN L'ETAT

Deja modifie (sauvegarde sur disque, pas encore compile) :

- `lib/features/student/dossier_fields.dart` :
  enum `DossierFieldKind.phone` ajoute ; champs `phone` et `whatsapp_phone`
  ajoutes a l'etape "Identite" avec hints ; hint ajoute a `full_name`.
- `lib/providers/student_profile_provider.dart` :
  parametre `whatsappPhone` ajoute a `updateProfile()`, envoye comme
  `p_whatsapp_phone`.
- `lib/features/student/dossier_completion_sheet.dart` :
  methode `_prefillFromProfile` ajoutee (appelee a la fin de
  `_applyMissingFields`) ; validation telephone >= 8 chiffres ajoutee dans
  `_validateCurrentStep`.

**MANQUANT — a faire en premier, sinon rien ne compile / rien ne marche :**

1. `dossier_completion_sheet.dart`, methode `_buildField` (~ligne 483) : le
   `switch` sur `field.kind` n'a PAS de cas `DossierFieldKind.phone` →
   **erreur de compilation** (le switch n'est pas exhaustif, pas de return).
   Ajouter :

   ```dart
   case DossierFieldKind.phone:
     return TextField(
       controller: _controllers[field.key],
       enabled: !_saving,
       keyboardType: TextInputType.phone,
       decoration: InputDecoration(
         labelText: field.label,
         hintText: field.hint,
         border: const OutlineInputBorder(),
         prefixIcon: const Icon(Icons.phone),
       ),
     );
   ```

2. `dossier_completion_sheet.dart`, methode `_saveAndVerify` (~ligne 180) :
   l'appel `widget.profileProvider.updateProfile(...)` ne passe PAS
   `phone:` ni `whatsappPhone:` → les valeurs ne sont jamais sauvees et
   l'etudiant tournerait en boucle "dossier incomplet". Ajouter dans l'appel :

   ```dart
   phone: _text('phone'),
   whatsappPhone: _text('whatsapp_phone'),
   ```

---

## 3. PLAN D'ACTION — PHASE 1 (suite immediate)

### 1A. Terminer le Flutter de la Phase 1

- [ ] Ajouter le cas `DossierFieldKind.phone` dans `_buildField` (ci-dessus).
- [ ] Passer `phone:` et `whatsappPhone:` dans `_saveAndVerify` (ci-dessus).
- [ ] `dossier_fields.dart` — ajouter les hints manquants :
  - `bepc_institution` → `hint: 'ex : Lycee Zinda'`
  - `bac_institution` → `hint: 'ex : Lycee Philippe Zinda Kabore'`
  (les dropdowns `mention`/`choice` n'ont pas besoin de hint).
- [ ] `lib/features/student/application_request_dialog.dart` — ajouter
  `hintText` a tous les TextField (ils n'ont que des `labelText`) :
  - Niveau souhaite → `hintText: 'Ex : Licence 1, Master 2, BTS'`
  - Mode → `hintText: 'Ex : Presentiel'`
  - Disponibilites → `hintText: 'Ex : lundi-vendredi, matinee 8h-12h'`
  - Commentaire → `hintText: 'Ex : je souhaite commencer a la rentree de janvier'`
- [ ] `lib/features/student/student_profile_screen.dart` (~ligne 198) : le
  champ "Telephone" existe sans `keyboardType`. Ajouter
  `keyboardType: TextInputType.phone` et ajouter un second champ
  "Numero WhatsApp" lie a `whatsapp_phone` (meme pattern que phone,
  via `updateProfile(whatsappPhone: ...)`).

### 1B. Verifier la Phase 1

```powershell
cd C:\Users\fasop\AndroidStudioProjects\academia\academia_app
flutter analyze
```

ATTENTION : le projet a ~2100 issues PRE-EXISTANTES (lints info). Ne corrige
que les erreurs dans les fichiers que tu as modifies. Puis :

```powershell
flutter build apk --debug
```

Verification SQL (script python temporaire, pattern ci-dessus, supprime-le
apres) : confirmer que `app_is_student_dossier_complete` retourne bien
`phone` et `whatsapp_phone` dans `missing_fields` pour un etudiant sans
telephone.

**Quand la Phase 1 compile : arrete-toi et fais le point avec l'utilisateur.**

---

## 4. PHASE 2 — Messages predefinis editables (admin)

Objectif : l'admin clique un bouton, un message pre-rempli avec les donnees
de la candidature apparait dans le compositeur, **il peut le modifier avant
d'envoyer**.

- [ ] Creer `lib/features/admin/application_message_templates.dart` :
  7 templates (constantes Dart) avec placeholders `{nom}`, `{filiere}`,
  `{universite}` :
  1. Etudiant — accuse reception de candidature
  2. Etudiant — dossier transmis a l'universite
  3. Etudiant — reponse defavorable
  4. Etudiant — acceptation + instructions de paiement (voir note Phase 4 :
     le message doit citer les VRAIS noms d'onglets une fois choisis)
  5. Universite — transmission du dossier
  6. Universite — accuse reception de leur reponse
  7. Etudiant — relance/intermediaire
- [ ] `admin_application_detail_screen.dart` (~ligne 899, zone compositeur
  avec le dropdown `_target`) : ajouter une rangee de boutons/chips de
  templates. Cliquer remplit le `TextEditingController` du compositeur avec
  le texte interpole — l'admin edite puis envoie via les RPC existants
  `app_add_application_message_from_admin_to_{student,university}`.
- [ ] Interpolation : prendre `student_full_name`, `program_title`,
  `university_name`, `requested_degree_level` depuis la candidature chargee.

---

## 5. PHASE 3 — Messagerie enrichie (images, vocal, video, accuses)

Systeme concerne : `app.application_messages` (texte seul aujourd'hui).
**Le schema de cette table et ses 9 RPC n'existent PAS dans le depot** — ils
sont en base uniquement. AVANT de modifier une RPC, dumpe son corps via
`prosrc` (pattern SQL ci-dessus) et copie-le dans la migration.

Modele de reference a copier : `lib/providers/support_messages_provider.dart`
(upload media + realtime + p_type/p_media_url deja implementes pour le
support chat).

- [ ] Migration : `ALTER TABLE app.application_messages ADD COLUMN
  type TEXT DEFAULT 'text', ADD COLUMN media_url TEXT, ADD COLUMN
  media_mime TEXT;`
- [ ] Migration : modifier les 4 RPC d'envoi
  (`app_add_application_message_from_{admin_to_student, admin_to_university,
  student, university}`) pour accepter `p_type`, `p_media_url`,
  `p_media_mime`. Et les 3 RPC de listing pour les retourner.
- [ ] Bucket Storage `application-media` PRIVE (pas `community-media` qui est
  public) + policies : seuls l'admin, l'etudiant proprietaire et l'universite
  concernee lisent. URLs signees.
- [ ] Flutter : boutons piece jointe dans les compositeurs des 3 ecrans
  (`admin_application_detail_screen.dart`,
  `student_application_detail_screen.dart`,
  `university_application_detail_screen.dart`). Packages probables a
  ajouter dans `academia_app/pubspec.yaml` : `record` (vocal),
  `image_picker` (image/video — verifier s'il est deja la), `audioplayers`
  ou `just_audio` (lecture vocale), `video_player` (lecture video).
  **Prefere des versions publiees il y a plus de 7 jours.**
- [ ] Bulles de message : afficher image (preview), audio (play/pause),
  video (lecteur) selon `type`.
- [ ] Accuses de lecture : les `app_mark_application_messages_read_for_*`
  existent deja ; exposer un `read_at` par message dans les RPC de listing
  et afficher ✓ / ✓✓ dans les bulles.
- [ ] Temps reel (optionnel en v1) : NE L'ACTIVE qu'apres avoir cree des
  policies RLS SELECT sur `app.application_messages` qui filtrent par
  `audience` + role — sinon les messages admin↔universite fuiteraient
  vers l'etudiant via Realtime.

---

## 6. PHASE 4 — Onglets etudiant + guidage paiement

Navigation actuelle : `student_dashboard_screen.dart`, barre du bas avec 11
entrees (Accueil, Candidatures, Communautes, Universites, Concours, TD,
Challenges, Opportunites[gele], Cours, Lives, Orientation). **Paiements et
Documents sont enterres dans un menu "…"** (`student_home_mobile.dart`
~ligne 306) — c'est pour ca que les etudiants abandonnent.

- [ ] Ajouter un onglet "Paiements" dedie → `StudentPaymentsScreen` remanie.
- [ ] Ajouter un onglet "Documents" dedie → `StudentDocumentsScreen`.
- [ ] `student_payments_screen.dart` : section en haut "Candidatures
  acceptees a regler" — uniquement `status='accepted'` + `discount_rate`
  non null + pas de paiement confirme. Chaque carte : programme, universite,
  montant (fixe serveur via `app_get_program_brokerage_fee`), bouton
  "Payer mes frais de courtage", **date limite visible**.
- [ ] Guidage : etapes numerotees dans `ligdicash_payment_sheet.dart`
  (1. operateur, 2. composer le code USSD affiche, 3. saisir l'OTP recu par
  SMS, 4. confirmer) + une ligne d'explication sous chaque bouton.
- [ ] Traduire les statuts bruts affiches ("pending"→"En attente",
  "confirmed"→"Confirme", "under_verification"→"En verification",
  "rejected"→"Rejete") dans `student_application_detail_screen.dart` et
  `student_payments_screen.dart`.
- [ ] `student_documents_screen.dart` : texte d'intro expliquant que bon de
  courtage + recu doivent etre presentes ensemble a la scolarite.
- [ ] Deadline de 7 jours : recommande = colonne
  `app.applications.payment_deadline TIMESTAMPTZ` posee cote serveur dans
  `app_admin_set_application_discount` (c'est le moment ou le paiement se
  deverrouille) = `now() + interval '7 days'`, plus un RPC admin pour
  prolonger. Confirmer la regle metier avec l'utilisateur avant de coder.
- [ ] **Securite** : l'eligibilite au paiement doit etre verifiee COTE
  SERVEUR (dans `app_create_application_payment`), pas seulement en cachant
  le bouton Flutter.

---

## 7. ARCHITECTURE UTILE (resultats d'audit)

- Messagerie candidature : RPCs `app_list_application_messages_for_{admin,
  student,university}`, `app_add_application_message_from_{admin_to_student,
  admin_to_university, student, university}`,
  `app_mark_application_messages_read_for_{admin,student,university}`.
  Colonne `audience` ('student'|'university') : l'universite ne voit JAMAIS
  les messages de l'etudiant et inversement. L'admin est le relais obligatoire.
- Statuts candidature : `draft, submitted, under_review, accepted, rejected,
  canceled`. Seule l'universite change le statut
  (`app_university_update_application_status`). L'admin : transmet
  (`app_admin_forward_application`), fixe le taux
  (`app_admin_set_application_discount` — deverrouille le paiement),
  verifie/confirme les paiements.
- Paiement : 2 chemins — LigdiCash (`ligdicash-initiate`/`ligdicash-confirm`
  edge functions) et declaration manuelle (`app_student_declare_payment`,
  verifiee par l'admin via `app_admin_verify_payment` puis
  `app_admin_confirm_payment` qui emet recu + bon de courtage).
- Providers cles : `student_profile_provider.dart`,
  `student_applications_provider.dart`,
  `{admin,student,university}_application_messages_provider.dart`,
  `admin_application_payments_provider.dart`.

---

## 8. ORDRE ET DISCIPLINE

1. Finir Phase 1 (compilation + analyze) → **stop, point avec l'utilisateur**.
2. Phase 2 (templates) → stop, point.
3. Phase 4 (onglets + guidage paiement) → stop, point.
4. Phase 3 (messagerie enrichie) → la plus lourde, en dernier.

Apres chaque modification : `flutter analyze` sur les fichiers touches, et un
build debug avant de declarer quoi que ce soit termine. Pas de commit sans
autorisation explicite.
