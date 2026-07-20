# Audit Smart Whiteboard — Rapport structuré

**Date de l’audit** : 13 juillet 2026  
**Auditeur** : Cascade (assistant IDE)  
**Périmètre** : documentation, code Flutter, Supabase (tables / RPC / Edge Functions / Storage), Kamatera Cloud (worker Python), architecture et parcours utilisateur du Smart Whiteboard.  
**Méthode** : vérification exclusive via les scripts / RPC administrateurs de `.windsurf` et par SSH sur la VPS Kamatera, conformément à la directive du `SMART_WHITEBOARD_DATA_CONTRACT.md`.

---

## 1. Objectifs attendus du Smart Whiteboard

Le Smart Whiteboard doit permettre à un étudiant de créer une **vidéo pédagogique courte** (< 10 min) à partir d’un sujet, sans compétences en montage. Le parcours cible, défini dans `docs/SMART_WHITEBOARD_USER_JOURNEY.md` :

1. **Création** : choix du sujet, renderer, thème, mode de narration.  
2. **Génération de contenu** : 4 modes — sujet simple, texte complet, plan, cours existant.  
3. **Correction / édition** : storyboard éditable (scènes et blocs).  
4. **Narration** : TTS, enregistrement utilisateur ou aucune.  
5. **Prévisualisation** : lecture du MP4 généré.  
6. **Export / publication** : vidéo dans le feed Challenge.

Le pipeline technique attendu (d’après `docs/SMART_WHITEBOARD_DATA_CONTRACT.md` et `docs/SMART_WHITEBOARD_IMPLEMENTATION_PLAN.md`) :

- Flutter UI → appelle l’Edge Function `whiteboard-generate-storyboard` (OpenRouter).  
- L’Edge Function crée un projet via `whiteboard_create_project` et logue dans `app.whiteboard_ai_generations`.  
- Flutter édite le storyboard, puis crée un job de rendu via `whiteboard_create_render_job` dans `app.whiteboard_renders`.  
- Le worker Python sur Kamatera (`whiteboard-worker.service`) poll `whiteboard_fetch_queued_jobs`, génère des PNGs, assemble un MP4 avec FFmpeg, upload dans le bucket `whiteboard-renders`.  
- Flutter récupère l’URL via `whiteboard_get_render_status`.

---

## 2. État actuel constaté

### 2.1 Documentation

| Document | Rôle | Appreciation |
|----------|------|--------------|
| `docs/SMART_WHITEBOARD_USER_JOURNEY.md` | Parcours UX | Clé, bien défini. |
| `docs/SMART_WHITEBOARD_DATA_CONTRACT.md` | Contrat JSON / tables | Existe, mais diverge partiellement de l’implémentation. |
| `docs/SMART_WHITEBOARD_IMPLEMENTATION_PLAN.md` | Ordre de création | Existe. |
| `.windsurf/whiteboard_rpc_contract.md` | Signatures RPC | Existe. |
| `.windsurf/audit_smart_whiteboard_contracts.md` | Contrats Edge Function / OpenRouter | Existe. |
| `.windsurf/audit_smart_whiteboard_root_cause.md` | Cause racine JWT | Identifie un bug d’auth dans l’Edge Function. |
| `docs/ACADEMIA_DEPLOYMENT_STATUS.md` | État du déploiement | **Obsolète / incorrect** : indique tables/RPCs non déployées et worker inactif, ce qui est faux. |
| `docs/ACADEMIA_CURRENT_CHECKPOINT.md` | Avancement | Affirme l’infrastructure « Production validée », ce qui est partiellement vrai côté backend mais faux côté Edge Function et Flutter. |
| `docs/ACADEMIA_CHANGELOG.md` | Historique | Affirme la validation production Phase D.5I, en contradiction avec `ACADEMIA_DEPLOYMENT_STATUS.md`. |
| `docs/AUDIT_SMART_WHITEBOARD_STUDIO.md` | Audit Studio vidéo / Smart Whiteboard | Conclut que le Studio et le moteur timeline **ne sont pas faisables** en l’état (absence de storyboard JSON, backend non déployé, etc.). |

**Constat documentation** : il existe une **incohérence majeure** entre les documents de statut. La réalité vérifiée montre que le backend Supabase et le worker Kamatera sont déployés, mais que l’Edge Function et l’intégration Flutter restent bloquées.

### 2.2 Supabase (vérifié via `admin_execute_sql`)

#### Tables existantes dans `app`

- `app.whiteboard_projects`
- `app.whiteboard_renders`
- `app.whiteboard_ai_generations`

Détail des colonnes sauvegardé dans :  
`.windsurf/logs/audit_whiteboard_tables_columns.json`

#### RPCs existantes dans `public`

Toutes les RPCs attendues du contrat sont présentes :

- `whiteboard_create_project`
- `whiteboard_get_project`
- `whiteboard_update_project`
- `whiteboard_delete_project`
- `whiteboard_list_projects`
- `whiteboard_create_render_job`
- `whiteboard_get_render_status`
- `whiteboard_fetch_queued_jobs`
- `whiteboard_mark_processing`
- `whiteboard_mark_done`
- `whiteboard_mark_failed`
- `whiteboard_get_any_student_id`

Définitions complètes sauvegardées dans :  
`.windsurf/logs/audit_whiteboard_rpc_definitions.json`

#### Buckets Storage

- `whiteboard-renders` ✅
- `whiteboard-narrations` ✅

#### Edge Function

- `whiteboard-generate-storyboard` : **déployée** et joignable (test retourne `401` sur appel sans JWT valide, ce qui prouve qu’elle existe).  
- Fichier source : `supabase/functions/whiteboard-generate-storyboard/index.ts`.

### 2.3 Kamatera Cloud (vérifié via SSH)

#### Service systemd

- `whiteboard-worker.service` : **actif (running)** depuis plusieurs jours.
- Fichiers présents dans `/opt/whiteboard-worker/` :
  - `whiteboard_render_worker.py`
  - `whiteboard_png_renderer.py`
  - `whiteboard_ffmpeg_assembler.py`
  - `whiteboard_upload_renderer.py`
- FFmpeg 6.1.1 présent.
- Dépendances Python (httpx, Pillow, python-dotenv, requests) installées.

#### Test de bout en bout effectué

Un projet et un job de rendu de test ont été insérés via `admin_execute_sql` :

- Le worker a bien **récupéré le job** via `whiteboard_fetch_queued_jobs`.
- Le worker a marqué le job comme `processing`, puis `failed` avec l’erreur `"No PNGs provided"` (storyboard vide volontairement).
- Le job et le projet de test ont été supprimés après le test.

**Conclusion Kamatera** : le worker est fonctionnel et connecté à Supabase. Les RPCs `fetch_queued_jobs` / `mark_processing` / `mark_failed` fonctionnent.

### 2.4 Flutter

Le module Smart Whiteboard est intégré dans `academia_app/lib/features/challenge/smart_whiteboard/`.

#### Fichiers existants

- `providers/smart_whiteboard_provider.dart`
- `screens/smart_whiteboard_input_screen.dart`
- `screens/smart_whiteboard_storyboard_editor_screen.dart`
- `screens/smart_whiteboard_preview_screen.dart`
- `screens/smart_whiteboard_projects_list_screen.dart`
- `services/smart_whiteboard_service.dart`
- `services/smart_whiteboard_render_service.dart`
- `services/smart_whiteboard_narration_service.dart`
- `models/storyboard_models.dart`

#### Navigation

- Routes nommées dans `academia_app/lib/main.dart` :
  - `/smart-whiteboard-input`
  - `/smart-whiteboard-editor`
  - `/smart-whiteboard-preview`
  - `/smart-whiteboard-projects`
- Provider global instancié dans `main.dart`.
- Bouton d’entrée dans `student_challenges_tab.dart` via `_openCreateVideoFromFeed` → `_openSmartWhiteboard`.

#### Point positif

La structure globale (models, services, provider, écrans) est en place. Le provider gère les états `idle/loading/bobodoGenerating/editing/narrating/previewing/rendering/done/error`.

---

## 3. Problèmes identifiés

### 3.1 Incohérences documentaires critiques

- `docs/ACADEMIA_DEPLOYMENT_STATUS.md` indique à tort que `whiteboard_projects`, `whiteboard_renders`, les RPCs `whiteboard_*` et le worker Kamatera ne sont **pas** déployés.
- `docs/ACADEMIA_CURRENT_CHECKPOINT.md` et `docs/ACADEMIA_CHANGELOG.md` affirment le contraire (« Production validée »).
- `docs/AUDIT_SMART_WHITEBOARD_STUDIO.md` concluait que le backend n’était pas déployé ; cette conclusion est aujourd’hui obsolète pour le pipeline Smart Whiteboard, même si elle reste pertinente pour le Studio vidéo général.

**Impact** : impossible de savoir quelle version de la vérité utiliser pour planifier la suite.

### 3.2 Edge Function `whiteboard-generate-storyboard` — blocage authentification

Le fichier `supabase/functions/whiteboard-generate-storyboard/index.ts` crée un client Supabase avec la **service role key** pour vérifier le JWT utilisateur :

```@c:\Users\fasop\AndroidStudioProjects\academia\supabase\functions\whiteboard-generate-storyboard\index.ts:332-339
    const supabaseUser = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    });
    const { data: userData, error: userError } = await supabaseUser.auth.getUser(jwt);
    if (userError || !userData?.user) {
      return jsonResponse({ error: 'not_authenticated' }, 401);
    }
```

Cette combinaison est documentée comme non fiable dans `.windsurf/audit_smart_whiteboard_root_cause.md`. L’appel authentifié depuis Flutter échouera systématiquement avec `not_authenticated`, bloquant la génération de storyboard.

**Conséquence** : aucun utilisateur ne peut créer de projet Smart Whiteboard via l’UI.

### 3.3 Edge Function dépend de tables/RPCs supplémentaires

L’Edge Function appelle :

- `app_student_reserve_credits`, `app_student_confirm_credits`, `app_student_refund_credits` ✅ (vérifiées, existent)
- `whiteboard_create_project` ✅ (existe)
- insertion dans `app.whiteboard_ai_generations` ✅ (existe)
- `admin_execute_sql` ✅ (existe)

Ces dépendances sont présentes, donc une fois le bug JWT corrigé, l’Edge Function devrait pouvoir fonctionner.

### 3.4 Flutter — cast incorrect de `whiteboard_list_projects`

Dans le provider :

```@c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\features\challenge\smart_whiteboard\providers\smart_whiteboard_provider.dart:576-605
  Future<void> loadProjects() async {
    ...
    final response = await client.rpc('whiteboard_list_projects');
    ...
      _projects = response as List<dynamic>;
    ...
  }
```

Or la RPC retourne un objet JSON :

```json
{ "success": true, "projects": [ ... ] }
```

`response` est donc un `Map<String, dynamic>`, pas une `List`. Le cast `response as List<dynamic>` lèvera une exception `TypeError`. L’écran `smart_whiteboard_projects_list_screen.dart` ne pourra jamais afficher la liste.

### 3.5 Flutter — named routes ignorent les arguments

Dans `main.dart`, les builders de routes ne récupèrent pas les `arguments` passés via `Navigator.pushNamed` :

```@c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\main.dart:326-329
          '/smart-whiteboard-input': (_) => const SmartWhiteboardInputScreen(),
          '/smart-whiteboard-editor': (_) => const SmartWhiteboardStoryboardEditorScreen(),
          '/smart-whiteboard-preview': (_) => const SmartWhiteboardPreviewScreen(),
          '/smart-whiteboard-projects': (_) => const SmartWhiteboardProjectsListScreen(),
```

Pourtant `smart_whiteboard_projects_list_screen.dart` envoie des arguments :

```@c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\features\challenge\smart_whiteboard\screens\smart_whiteboard_projects_list_screen.dart:204-211
  void _handleEdit(dynamic project) {
    final projectId = project['id'] as String;
    Navigator.pushNamed(
      context,
      '/smart-whiteboard-editor',
      arguments: {'projectId': projectId},
    );
  }
```

**Conséquence** : ouvrir un projet existant depuis la liste ne recharge pas le bon projet.

### 3.6 Flutter — modes B/C/D non transmis à l’Edge Function

Dans `smart_whiteboard_input_screen.dart`, seul le sujet est transmis au provider :

```@c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\features\challenge\smart_whiteboard\screens\smart_whiteboard_input_screen.dart:52-58
    await provider.createProject(
      subject: subject,
      rendererId: _selectedRenderer.name,
      themeId: _selectedTheme.name,
      narrationMode: _selectedNarrationMode.name,
    );

    await provider.generateStoryboard();
```

`generateStoryboard` utilise les valeurs par défaut (`mode = 'simple_subject'`, `content = ''`). Le contenu saisi dans `_contentController` n’est jamais envoyé.

**Conséquence** : les modes « Texte complet », « Plan » et « Cours existant » ne fonctionnent pas.

### 3.7 Flutter — narration non implémentée

Dans le provider :

```@c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\features\challenge\smart_whiteboard\providers\smart_whiteboard_provider.dart:447-465
  Future<void> generateTTS(String text, String voice) async {
    ...
      // TODO: Call TTS Edge Function
      _currentNarration = Narration(
        mode: NarrationMode.tts,
        voice: voice,
        audioUrl: null,
      );
    ...
  }
```

`recordNarration` est également un TODO.

**Conséquence** : la narration TTS ou enregistrement ne produit aucun fichier audio.

### 3.8 Flutter — prévisualisation sans publication

`smart_whiteboard_preview_screen.dart` affiche la vidéo mais ne propose **aucun bouton « Publier dans le Challenge »**. Les actions Partager/Télécharger sont des placeholders (`Fonctionnalité à implémenter`).

**Conséquence** : le parcours ne se termine pas par une publication dans le feed.

### 3.9 Mismatch statuts projet

Le contrat (`docs/SMART_WHITEBOARD_DATA_CONTRACT.md`) définit `status = draft|completed`.  
L’écran `smart_whiteboard_projects_list_screen.dart` filtre sur `draft/generating/ready/rendering/done`.  
L’enum Flutter `ProjectStatus` dans `storyboard_models.dart` ne contient que `draft` et `completed`.

**Conséquence** : la liste de projets affiche des statuts qui n’existent pas dans les modèles / contrat.

### 3.10 Liste des projets — champs `render_id` / `video_url` absents

`whiteboard_list_projects` retourne uniquement les colonnes de `app.whiteboard_projects`. L’écran tente cependant de lire `project['render_id']` et `project['video_url']` pour les projets terminés :

```@c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\features\challenge\smart_whiteboard\screens\smart_whiteboard_projects_list_screen.dart:254-268
  void _handleTap(dynamic project) {
    final status = project['status'] as String;
    if (status == 'done') {
      final renderId = project['render_id'] as String?;
      final videoUrl = project['video_url'] as String?;
      ...
    }
  }
```

**Conséquence** : impossible de relire une vidéo depuis la liste.

### 3.11 Worker — upload en mémoire et pas de TUS / chunked

`whiteboard_upload_renderer.py` lit le MP4 entier en RAM :

```@c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\logs\whiteboard_upload_renderer_kamatera.py:60-69
    data = mp4_path.read_bytes()

    async with httpx.AsyncClient(timeout=SUPABASE_HTTP_TIMEOUT) as client:
        resp = await client.put(
            storage_url,
            headers=_supabase_headers(),
            content=data,
        )
```

**Impact** : risque d’échec sur les vidéos longues ou les rendus consommateurs de mémoire. Non bloquant pour V1.

### 3.12 `whiteboard_create_render_job` bloque les appels service-role

La RPC vérifie `student_id = auth.uid()` :

```@c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\logs\audit_whiteboard_rpc_definitions.json:6-12
  SELECT EXISTS (
    SELECT 1 FROM app.whiteboard_projects
    WHERE id = p_project_id AND student_id = auth.uid()
  ) INTO v_project_exists;
```

C’est correct pour Flutter, mais empêche tout appel administrateur / worker / script de test utilisant la service role key. Ce n’est pas un bug en soi, mais cela complique les tests.

### 3.13 `whiteboard_create_project` n’a pas de vérification de propriété

La RPC insère `p_student_id` tel quel, sans vérifier `auth.uid()`.  
**Impact** : un utilisateur authentifié pourrait théoriquement créer un projet pour un autre étudiant. À corriger.

---

## 4. Synthèse par couche

| Couche | Existe ? | Fonctionnel ? | Blocage principal |
|--------|----------|---------------|-------------------|
| Documentation d’architecture | ✅ | ⚠️ | Incohérences entre documents de statut |
| Tables Supabase `whiteboard_*` | ✅ | ✅ | — |
| RPCs Supabase `whiteboard_*` | ✅ | ✅ | `create_render_job` et `get_project` restreignes `auth.uid()` (OK pour Flutter) |
| Buckets Storage | ✅ | ✅ | — |
| Edge Function `whiteboard-generate-storyboard` | ✅ | ❌ | Bug JWT → `not_authenticated` |
| Worker Kamatera | ✅ | ✅ | Aucun job en file, mais test de job traité OK |
| Flutter — structure | ✅ | ⚠️ | Routes, provider, écrans présents |
| Flutter — génération storyboard | ✅ | ❌ | Edge Function inacessible + modes B/C/D non transmis |
| Flutter — liste des projets | ✅ | ❌ | Cast `List<dynamic>` + arguments de route ignorés |
| Flutter — narration | ⚠️ | ❌ | TODO |
| Flutter — publication | ⚠️ | ❌ | Aucun bouton de publication |

---

## 5. Recommandations

### Critiques (à corriger en premier)

1. **Corriger l’authentification de l’Edge Function** `whiteboard-generate-storyboard` : utiliser le JWT de l’en-tête `Authorization` directement, sans créer un second client service-role, ou utiliser `supabase.auth.getUser(jwt)` avec un client anon. Voir `.windsurf/audit_smart_whiteboard_root_cause.md`.
2. **Corriger le provider Flutter** : `loadProjects` doit traiter `response['projects']` et non caster `response` en `List`.
3. **Passer les arguments aux routes** dans `main.dart` (`ModalRoute.of(context).settings.arguments`) ou utiliser `MaterialPageRoute` explicites partout.
4. **Transmettre le mode et le contenu** depuis `SmartWhiteboardInputScreen` vers `generateStoryboard`.
5. **Ajouter un bouton « Publier dans le Challenge »** dans `SmartWhiteboardPreviewScreen` et appeler le flux de publication existant (`app_student_submit_challenge` ou équivalent).

### Haute priorité

6. Aligner les statuts projet entre le contrat, l’enum Flutter et l’UI (`draft/completed` ou `draft/generating/ready/rendering/done`).
7. Remplir `render_id` / `video_url` dans la réponse de `whiteboard_list_projects` pour les projets terminés, ou adapter l’UI.
8. Implémenter la narration TTS / enregistrement ou masquer ces options en V1.
9. Ajouter une vérification `student_id = auth.uid()` dans `whiteboard_create_project`.
10. Mettre à jour `docs/ACADEMIA_DEPLOYMENT_STATUS.md` et `docs/ACADEMIA_CURRENT_CHECKPOINT.md` pour refléter la réalité.

### Améliorations

11. Remplacer l’upload en mémoire du worker par un upload chunked / TUS.
12. Ajouter des logs structurés et des métriques sur le worker.

---

## 6. Preuves et artefacts générés

- `.windsurf/logs/audit_whiteboard_tables_columns.json` — colonnes des tables Smart Whiteboard.
- `.windsurf/logs/audit_whiteboard_rpc_definitions.json` — définitions des RPCs Smart Whiteboard.
- `.windsurf/logs/whiteboard_render_worker_kamatera.py` — copie du worker Kamatera.
- `.windsurf/logs/whiteboard_png_renderer_kamatera.py` — renderer PNG Kamatera.
- `.windsurf/logs/whiteboard_ffmpeg_assembler_kamatera.py` — assembleur FFmpeg Kamatera.
- `.windsurf/logs/whiteboard_upload_renderer_kamatera.py` — uploader Kamatera.
- `docs/AUDIT_SMART_WHITEBOARD_COMPLET.md` — ce rapport.

---

## 7. Verdict

Le **backend Smart Whiteboard est majoritairement déployé et opérationnel** : tables, RPCs, Storage, Edge Function (déployée mais boguée) et worker Kamatera (actif et capable de traiter un job).  
Le **principal blocage fonctionnel** réside dans l’**Edge Function `whiteboard-generate-storyboard`** qui ne parvient pas à authentifier l’utilisateur, empêchant toute création de projet depuis l’application.  
Le **second blocage** est dans le **provider Flutter** qui ne sait pas interpréter la réponse de `whiteboard_list_projects`, rendant la liste des projets inutilisable.  
Enfin, le **parcours de publication n’est pas terminé** : narration, prévisualisation et publication dans le Challenge sont incomplètes ou absente.

**Note globale** : backend ≈ 80 % fonctionnel ; Flutter ≈ 50 % structuré mais non fonctionnel en bout en bout ; documentation ≈ 30 % cohérente (incohérences majeures à résoudre).
