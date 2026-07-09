# D.20 – PHASE 5 : MATRICE DES ÉCARTS

**Date** : 2026-06-28  
**Mission** : D.20 – Audit de conformité  
**Légende** : ✅ MATCH | ⚠️ PARTIAL MATCH | ❌ MISMATCH | 💀 BROKEN

---

## SECTION A – FLUTTER

### A.1 Écrans

| Composant | Attendu | Réel | Statut | Impact |
|-----------|---------|------|--------|--------|
| `SmartWhiteboardInputScreen` | Existe, route `/smart-whiteboard-input` | ✅ Existe, route définie | ✅ MATCH | — |
| `SmartWhiteboardStoryboardEditorScreen` | Existe, route `/smart-whiteboard-editor` | ✅ Existe, route définie | ✅ MATCH | — |
| `SmartWhiteboardPreviewScreen` | Existe, route `/smart-whiteboard-preview` | ✅ Existe, route définie | ✅ MATCH | — |
| `SmartWhiteboardProjectsListScreen` | Accessible depuis challenge feed | ⚠️ Route définie mais non accessible depuis le flow principal | ⚠️ PARTIAL MATCH | L'utilisateur ne peut pas lister ses projets précédents |

### A.2 Provider – États

| Composant | Attendu | Réel | Statut | Impact |
|-----------|---------|------|--------|--------|
| État `creating` | Décrit dans specs | Absent (remplacé par `loading`) | ⚠️ PARTIAL MATCH | UX : indicateur générique |
| État `bobodoGenerating` | Non documenté | Présent | ⚠️ PARTIAL MATCH | Surplus non documenté |
| Autres états | idle, editing, rendering, done, error | ✅ Présents | ✅ MATCH | — |

### A.3 Provider – Méthodes

| Composant | Attendu | Réel | Statut | Fichier:Ligne | Impact |
|-----------|---------|------|--------|---------------|--------|
| `createProject()` | Appelle SmartWhiteboardService | ✅ Appelle service | ✅ MATCH | provider.dart:89 | — |
| `generateStoryboard()` | Envoie subject réel à Edge Function | ❌ Envoie `subject=""` car `_currentProject` est null | 💀 BROKEN | provider.dart:139 | Storyboard généré sur sujet vide |
| `loadProjects()` | Appelle via SmartWhiteboardService | ⚠️ Bypass service → appel RPC direct | ⚠️ PARTIAL MATCH | provider.dart:543 | Incohérence architecturale |
| `generateTTS()` | Appelle TTS Edge Function | 💀 TODO stub, aucun appel réel | 💀 BROKEN | provider.dart:407 | Narration TTS non fonctionnelle |
| `recordNarration()` | Implémente enregistrement audio | 💀 TODO stub | 💀 BROKEN | provider.dart:421 | Narration user non fonctionnelle |
| `_narrationService` | Utilisé dans les méthodes narration | ⚠️ Accepté dans constructeur, jamais utilisé | ⚠️ PARTIAL MATCH | provider.dart:23 | Service instancié inutilement |

### A.4 Services – Cast sans null-check

| Composant | Attendu | Réel | Statut | Fichier:Ligne | Impact |
|-----------|---------|------|--------|---------------|--------|
| `SmartWhiteboardService.createProject()` | Retour sûr | Cast `as Map<String, dynamic>` sans null-check | ⚠️ PARTIAL MATCH | service.dart:38 | Crash si RPC retourne null |
| `SmartWhiteboardRenderService.waitForRenderCompletion()` | Accès `status['render']` sécurisé | Cast direct sans null-check | ⚠️ PARTIAL MATCH | render_service.dart:63 | Crash si `render` absent |

### A.5 Anomalie critique – `_currentProject` jamais assigné

| Composant | Attendu | Réel | Statut | Fichier:Ligne | Contrat | ADR | Impact |
|-----------|---------|------|--------|---------------|---------|-----|--------|
| `_currentProject` assigné après `createProject()` | Oui | ❌ Jamais assigné | 💀 BROKEN | provider.dart:100-103 | SMART_WHITEBOARD_DATA_CONTRACT.md §1.2 | ADR-SW-001 | Edge Function reçoit subject="" → storyboard incorrect/vide |

---

## SECTION B – SUPABASE

### B.1 Tables

| Composant | Attendu | Réel | Statut | Méthode de preuve | Impact |
|-----------|---------|------|--------|------------------|--------|
| `app.whiteboard_projects` | Existe, schéma app | ✅ Existe (FK error → table présente) | ✅ MATCH | REST RPC 409 + FK constraint | — |
| `app.whiteboard_renders` | Existe, schéma app | ✅ Probable (worker fetch retourne []) | ✅ MATCH | `whiteboard_fetch_queued_jobs` → 200 [] | — |
| `app.whiteboard_ai_generations` | Existe | ❓ Non prouvée | ⚠️ PARTIAL MATCH | Aucun appel direct | Logging IA non vérifié |

### B.2 RPCs Flutter

| RPC | Attendue | Réel | Statut | Méthode de preuve | Impact |
|-----|---------|------|--------|------------------|--------|
| `whiteboard_create_project` | Existe, schéma public | ✅ EXISTE | ✅ MATCH | REST → 409 FK (exécutée) | — |
| `whiteboard_fetch_queued_jobs` | Existe, schéma public | ✅ EXISTE | ✅ MATCH | REST → 200 [] | — |
| `whiteboard_get_project` | Existe, schéma public | ❓ Non prouvée | ⚠️ PARTIAL MATCH | Non testé | getProject() inutilisé dans le flow |
| `whiteboard_update_project` | Existe, schéma public | ❓ Non prouvée | ⚠️ PARTIAL MATCH | Non testé | updateStoryboard() inutilisé |
| `whiteboard_list_projects` | Existe, schéma public | ❓ Non prouvée | ⚠️ PARTIAL MATCH | Non testé | loadProjects() hors flow principal |
| `whiteboard_delete_project` | Existe, schéma public | ❓ Non prouvée | ⚠️ PARTIAL MATCH | Non testé | Hors flow principal |
| `whiteboard_create_render_job` | Existe, schéma public | ❓ Non prouvée | ⚠️ PARTIAL MATCH | Non testé | Jamais atteint (bloqué avant) |
| `whiteboard_get_render_status` | Existe, schéma public | ❓ Non prouvée | ⚠️ PARTIAL MATCH | Non testé | Jamais atteint |

### B.3 RPCs Worker

| RPC | Attendue | Réel | Statut | Méthode de preuve | Impact |
|-----|---------|------|--------|------------------|--------|
| `whiteboard_mark_processing` | Existe | ❓ Non prouvée directement | ⚠️ PARTIAL MATCH | Worker actif sans erreur → probable | — |
| `whiteboard_mark_done` | Existe | ❓ Non prouvée directement | ⚠️ PARTIAL MATCH | Worker actif sans erreur → probable | — |
| `whiteboard_mark_failed` | Existe | ❓ Non prouvée directement | ⚠️ PARTIAL MATCH | Worker actif sans erreur → probable | — |
| `whiteboard_get_any_student_id` | Existe | ❓ Non prouvée | ⚠️ PARTIAL MATCH | Non testé | — |

### B.4 Edge Function

| Composant | Attendu | Réel | Statut | Fichier:Ligne | Contrat | ADR | Impact |
|-----------|---------|------|--------|---------------|---------|-----|--------|
| `whiteboard-generate-storyboard` | Déployée, accessible avec JWT user | ✅ Déployée | ⚠️ PARTIAL MATCH | — | SMART_WHITEBOARD_DATA_CONTRACT.md §2 | ADR-EF-001 | 401 avec service_role (correct). Requiert JWT utilisateur. |
| Auth Edge Function | Requiert JWT user valide | ❌ Flutter envoie le bon JWT (Supabase.instance.client.functions.invoke gère automatiquement le JWT session) | ⚠️ À VÉRIFIER | audit_smart_whiteboard_wiring_final.md | — | — | L'Edge Function rejette → bloque tout le flow |

### B.5 Buckets Storage

| Composant | Attendu | Réel | Statut | Impact |
|-----------|---------|------|--------|--------|
| `whiteboard-renders` (non-public) | Existe | ✅ EXISTE, non-public | ✅ MATCH | — |
| `whiteboard-narrations` (non-public) | Existe | ✅ EXISTE, non-public | ✅ MATCH | — |

---

## SECTION C – KAMATERA

### C.1 Worker systemd

| Composant | Attendu | Réel | Statut | Impact |
|-----------|---------|------|--------|--------|
| `whiteboard-worker.service` | active, enabled | ✅ active (running), enabled depuis Jun 24 | ✅ MATCH | — |
| Worker PID actif | Process python3 présent | ✅ PID 395272 actif | ✅ MATCH | — |

### C.2 Scripts Python

| Composant | Attendu | Réel | Statut | Impact |
|-----------|---------|------|--------|--------|
| `whiteboard_render_worker.py` | `/opt/whiteboard-worker/` | ✅ Présent, 6230 bytes | ✅ MATCH | — |
| `whiteboard_png_renderer.py` | `/opt/whiteboard-worker/` | ✅ Présent, 6526 bytes | ✅ MATCH | — |
| `whiteboard_ffmpeg_assembler.py` | `/opt/whiteboard-worker/` | ✅ Présent, 1976 bytes | ✅ MATCH | — |
| `whiteboard_upload_renderer.py` | `/opt/whiteboard-worker/` | ✅ Présent, 1872 bytes | ✅ MATCH | — |

### C.3 Pipeline de rendu

| Composant | Attendu | Réel | Statut | Impact |
|-----------|---------|------|--------|--------|
| Poll `whiteboard_fetch_queued_jobs` | Toutes ~2s | ✅ Confirmé par logs (HTTP 200 toutes 2s) | ✅ MATCH | — |
| FFmpeg H.264 | Installé | ✅ v6.1.1 disponible | ✅ MATCH | — |
| Pillow (PNG rendering) | Installé | ✅ v12.2.0 | ✅ MATCH | — |
| httpx (upload) | Installé | ✅ v0.28.1 | ✅ MATCH | — |
| Bucket cible `whiteboard-renders` | Configuré | ✅ WHITEBOARD_BUCKET = "whiteboard-renders" | ✅ MATCH | — |

### C.4 Jobs traités

| Composant | Attendu | Réel | Statut | Impact |
|-----------|---------|------|--------|--------|
| Jobs rendus | Au moins 1 test job | ❌ 0 jobs créés, 0 traités | ❌ MISMATCH | Le rendu n'a jamais été testé end-to-end |

---

## SECTION D – ÉCARTS CRITIQUES PRIORISÉS

### PRIORITÉ 1 – BLOQUANT (flow utilisateur impossible)

| # | Écart | Composant | Fichier:Ligne | Impact utilisateur |
|---|-------|-----------|---------------|-------------------|
| **GAP-01** | `_currentProject` jamais assigné → subject="" envoyé à Edge Function | Flutter Provider | `provider.dart:100-103, 139` | Storyboard généré sur sujet vide. Flow bloqué fonctionnellement. |
| **GAP-02** | Edge Function retourne 401 (auth) | Supabase Edge Function | `whiteboard-generate-storyboard` | Storyboard jamais généré (confirmé par audit_smart_whiteboard_wiring_final.md) |

### PRIORITÉ 2 – DÉGRADÉ (features non fonctionnelles)

| # | Écart | Composant | Fichier:Ligne | Impact utilisateur |
|---|-------|-----------|---------------|-------------------|
| **GAP-03** | `generateTTS()` est un stub vide | Flutter Provider | `provider.dart:401-418` | Narration TTS indisponible |
| **GAP-04** | `recordNarration()` est un stub vide | Flutter Provider | `provider.dart:420-437` | Narration utilisateur indisponible |
| **GAP-05** | `SmartWhiteboardProjectsListScreen` non accessible depuis le flow | Flutter Navigation | `student_challenges_tab.dart:1928` | Utilisateur ne peut pas revoir ses projets |

### PRIORITÉ 3 – RISQUE TECHNIQUE (crash potentiel)

| # | Écart | Composant | Fichier:Ligne | Impact utilisateur |
|---|-------|-----------|---------------|-------------------|
| **GAP-06** | Cast `as Map<String, dynamic>` sans null-check dans services | Flutter Services | `service.dart:38, render_service.dart:63` | Crash potentiel si RPC retourne null ou type inattendu |
| **GAP-07** | `loadProjects()` bypass SmartWhiteboardService | Flutter Provider | `provider.dart:543` | Incohérence architecturale, RPC non vérifiée |

### PRIORITÉ 4 – ARCHITECTURE (non conforme aux ADRs)

| # | Écart | Composant | ADR concernée | Impact utilisateur |
|---|-------|-----------|---------------|-------------------|
| **GAP-08** | `_narrationService` instancié mais jamais utilisé | Flutter Provider | ADR-SW-NAR | Mémoire gaspillée, service inutile |
| **GAP-09** | `whiteboard_ai_generations` table non prouvée | Supabase | SMART_WHITEBOARD_DATA_CONTRACT §tables | Logging IA non vérifié |
| **GAP-10** | 0 jobs render traités — pipeline end-to-end non testé | Kamatera | ADR-KAM-001 | Rendu vidéo jamais validé en production |

---

**DOCUMENT CLÔTURÉ** – Matrice des écarts complète. 10 gaps identifiés, 2 critiques bloquants.
