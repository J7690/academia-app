# Consignes pour Windsurf + Dispositif Play Store

**Date :** 14 juillet 2026
**Contexte :** la logique base de données (commissions multi-acteurs, anti-doublon, attribution owner/promoteur/créateur) est **déjà appliquée en production** et versionnée dans `supabase/migrations/`. Ce document couvre uniquement ce qui ne peut pas être fait à distance : outillage local, sécurité, build et Play Store.

---

# PARTIE A — Tâches à confier à Windsurf (dans le repo)

Copie-colle chaque bloc « PROMPT » à Windsurf. Ils sont classés par priorité.

## A0. 🔴 URGENT — Révoquer la clé service_role exposée

La clé `service_role` (accès admin total à la base) est écrite en clair dans plus de 50 scripts `.windsurf/*.py`, versionnés par git.

**À faire par toi (pas Windsurf), dans le dashboard Supabase :**
1. Va sur https://supabase.com/dashboard/project/thevdfcwlcqzdoybfvgs/settings/api
2. Section « Project API keys » → régénère la clé `service_role` (bouton reset/roll).
3. Mets à jour la nouvelle clé dans les secrets des edge functions (Settings → Edge Functions → Secrets) si elles l'utilisent.

**PROMPT Windsurf :**
> Purge la clé service_role de tout le dépôt. 1) Déplace la clé et toutes les URL/API keys hardcodées des scripts `.windsurf/*.py` vers un fichier `.windsurf/.env` (déjà git-ignoré) chargé via `os.environ`. 2) Ajoute au `.gitignore` : `.windsurf/*.py` si ces scripts ne doivent pas être partagés, ou au minimum garde `.windsurf/.env`. 3) Purge la clé de l'historique git avec `git filter-repo` (ou BFG). 4) Considère l'ancienne clé comme compromise : confirme-moi qu'elle a été régénérée côté Supabase avant de terminer.

## A1. 🔴 Réactiver et fiabiliser l'Install Referrer (cœur du Play Store)

**État réel constaté :** le mécanisme est codé mais **désactivé** :
- `academia_app/pubspec.yaml` : `# installreferrer2: ^2.0.1` (commenté)
- `install_referrer_service.dart` : `// import 'package:installreferrer/installreferrer.dart';` (commenté)
- `auth_wrapper.dart` ligne ~55 : `// InstallReferrerService.instance.initialize();` (commenté)
- Incohérence : le code appelle `InstallReferrerService.instance` alors que la classe expose un `factory InstallReferrerService()` (singleton) — `.instance` n'existe pas.

**PROMPT Windsurf :**
> Réactive la capture Install Referrer Play Store dans academia_app. 1) Dans pubspec.yaml, ajoute une dépendance Install Referrer valide et publiée sur pub.dev (vérifie le nom exact et la dernière version compatible : `android_play_install_referrer` est le package de référence maintenu ; si `installreferrer2` n'existe plus, utilise `android_play_install_referrer`). 2) Dans install_referrer_service.dart, dé-commente l'import et adapte l'API au package retenu. 3) Corrige l'accès singleton : remplace tous les `InstallReferrerService.instance` par `InstallReferrerService()` (ou ajoute un getter statique `static InstallReferrerService get instance => _instance;`). 4) Dans auth_wrapper.dart, dé-commente `initialize()` et garde l'ordre de priorité : Install Referrer d'abord, puis fallback paramètres URL. 5) `flutter pub get` puis `flutter analyze` et corrige toute erreur. Ne touche pas à la logique Supabase.

## A2. 🔴 Fixer un applicationId réel et cohérent (bloquant Play Store)

**État réel constaté :**
- `android/app/build.gradle.kts` : `applicationId = "com.example.academia"` et `namespace = "com.example.academia"` → **Google Play refuse tout `com.example.*`**.
- `supabase/functions/referral-redirect/index.ts` ligne 73 : redirige vers `id=com.academia.app` → **ne correspond pas** à l'applicationId.

**PROMPT Windsurf :**
> Remplace l'applicationId de placeholder par un identifiant définitif, par exemple `com.nexiumgroup.academia` (confirme le nom avec moi avant). 1) Mets à jour `namespace` ET `applicationId` dans android/app/build.gradle.kts. 2) Renomme le package Kotlin/Java sous android/app/src/main/kotlin (dossier + `package` de MainActivity) pour correspondre. 3) Dans supabase/functions/referral-redirect/index.ts, mets le même identifiant dans l'URL Play Store (`id=com.nexiumgroup.academia`). 4) Vérifie que le build Android compile (`flutter build apk --debug`). Ne redéploie pas l'edge function toi-même : donne-moi la commande exacte.

Note : après modif de l'edge function, elle devra être redéployée (`supabase functions deploy referral-redirect`).

## A3. 🟠 Vérifier que mes modifications Flutter compilent

J'ai modifié 3 fichiers (part créateur + fenêtre promoteur dans l'admin, capture du visuel dans le partage).

**PROMPT Windsurf :**
> Lance `flutter analyze` sur academia_app et corrige d'éventuelles erreurs dans : lib/providers/admin_commission_share_config_provider.dart, lib/features/admin/admin_commission_share_config_screen.dart, lib/services/share_tracking_service.dart. Ces fichiers ont été étendus pour gérer creator_percentage, promoter_window_days et content_asset_id. Ne change pas la logique métier, corrige seulement la compilation.

## A4. 🟠 Résorber la dérive de schéma (schema drift)

Tout le domaine commercial historique a été appliqué hors migration. Mes 5 migrations du 14/07 sont dans le repo, mais le reste (tables commerciales créées avant) n'y est pas.

**PROMPT Windsurf :**
> Rapatrie l'état réel de la base dans des migrations versionnées.
> ```bash
> cd academia
> supabase link --project-ref thevdfcwlcqzdoybfvgs
> supabase db pull            # nécessite le mot de passe DB
> ```
> Vérifie ensuite que `supabase migration list` montre l'historique aligné entre local et distant. Règle : à partir de maintenant, plus AUCUN changement de schéma via `admin_execute_sql` — tout passe par `supabase migration new` + `supabase db push`.

## A5. 🟢 (Plus tard) Écrans du rôle créateur de contenu

La base est prête (table `content_assets`, RPC `app_creator_upsert_content_asset`, `app_list_content_assets`, `app_admin_approve_content_asset`). Manque l'UI.

**PROMPT Windsurf :**
> Crée les écrans du rôle content_creator : (1) écran créateur pour uploader/lister ses visuels (appelle app_creator_upsert_content_asset + app_list_content_assets) ; (2) galerie côté commercial pour choisir un visuel approuvé et générer un lien de partage incluant `&asset=<content_asset_id>` (ShareTrackingService.registerShare accepte déjà contentAssetId) ; (3) onglet admin d'approbation (app_admin_approve_content_asset). Suis le style des écrans admin existants.

---

# PARTIE B — Dispositif Play Store : ce qui manque et où le chercher

Le principe (déjà codé) : lien commercial `https://academiea.com/ref/CODE` → Netlify redirige vers l'edge function `referral-redirect` → génère un token → redirige vers le Play Store avec `&referrer=TOKEN` → à l'installation, l'app lit le referrer (Install Referrer API) → résout le token → attribue le commercial owner.

Pour que ça marche en vrai, il manque **7 éléments**. Tableau : quoi / statut / où l'obtenir.

| # | Élément manquant | Statut | Où / comment l'obtenir |
|---|------------------|--------|------------------------|
| 1 | **Compte Google Play Console** | à créer si absent | https://play.google.com/console — inscription développeur, frais unique de 25 USD. Compte Google de l'entreprise (Nexium Group). |
| 2 | **applicationId définitif** (≠ com.example) | à décider | Choisir p.ex. `com.nexiumgroup.academia`. Voir tâche A2 (Windsurf le pose dans le code + l'edge function). |
| 3 | **Clé de signature (keystore)** | à générer | En local : `keytool -genkey -v -keystore academia-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`. Garde le `.jks` + mots de passe en lieu sûr (jamais dans git). Ou active « Play App Signing » dans la Console (recommandé). Référence : https://developer.android.com/studio/publish/app-signing |
| 4 | **Bundle AAB** | à builder | Après A1/A2 : `cd academia_app && flutter build appbundle --release`. Fichier produit : `build/app/outputs/bundle/release/app-release.aab`. |
| 5 | **Package Install Referrer activé** | manquant (commenté) | Voir tâche A1. Sans lui, l'attribution Play Store ne fonctionne pas. |
| 6 | **Domaine `academiea.com` + HTTPS pointant sur Netlify** | à configurer | Chez ton registrar (là où academiea.com est acheté : OVH, Namecheap, GoDaddy…) : ajoute le domaine comme « custom domain » sur ton site Netlify (Netlify → Site settings → Domain management), puis suis les enregistrements DNS que Netlify indique (souvent un CNAME/ALIAS). Netlify fournit le HTTPS (Let's Encrypt) automatiquement. La redirection `/ref/*` est déjà dans `netlify.toml`. |
| 7 | **Piste de test interne (Internal testing)** | à créer dans la Console | L'Install Referrer ne fonctionne QUE pour une install via le Play Store. Crée une « Internal testing track » dans Play Console, ajoute ton compte testeur, installe l'app via le lien de test pour valider l'attribution de bout en bout. |

### Éléments annexes exigés par la Console (à préparer)
- **Fiche du Store** : icône 512×512, feature graphic 1024×500, captures d'écran, description.
- **Politique de confidentialité (URL publique)** + **formulaire Data Safety** (obligatoires).
- **Content rating** (questionnaire IARC dans la Console).

### Ordre recommandé
1. Windsurf : A1 + A2 (activer Install Referrer + applicationId réel).
2. Toi : #1 compte Console, #3 keystore, #6 domaine+DNS.
3. Windsurf : #4 build AAB, redéploie l'edge function referral-redirect (nouveau package name).
4. Toi : upload AAB en Internal testing (#7), teste le parcours lien → install → attribution.
5. Passage en production quand le test est concluant.

---

# Récapitulatif : qui fait quoi

**Toi (accès humains/comptes)** : régénérer la clé Supabase (A0) ; créer le compte Play Console ; générer/garder le keystore ; configurer le domaine academiea.com + DNS ; préparer fiche Store + politique de confidentialité ; uploader l'AAB.

**Windsurf (dans le repo)** : A0 purge git, A1 Install Referrer, A2 applicationId, A3 compilation, A4 `supabase db pull`, A5 écrans créateur (plus tard), build AAB, redéploiement edge function.

**Déjà fait (moi, en prod + repo)** : schéma multi-acteurs, générateur de commissions unifié, branchement des chemins de paiement, fin du double crédit, UI admin des parts, migrations versionnées, anti-doublon vérifié.
