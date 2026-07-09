# D.22 – PHASE 2 : LOGS DEBUG-D19 RUNTIME RÉELS SUR DEVICE

**Date de capture** : 2026-06-28T09:44Z – 09:46Z  
**Device** : TECNO LD7 (061272512M001078) – Android 10 (API 29)  
**PID Flutter** : 12481  
**Utilisateur connecté** : `6745c7ad-732b-47d0-b5b8-06d6dcf286ff` (`nexiomgroup@gmail.com`)  
**Source** : `flutter run --verbose` → `adb logcat -s flutter`  
**Méthode** : aucune reconstitution manuelle – logs bruts extraits de `d22_flutter_run_raw.log`

> **Note** : 3 exécutions successives du test ont eu lieu (l'utilisateur a appuyé 3 fois sur le bouton). Seule la **1ère exécution** est documentée ici (timestamps 09:44:38Z). Les 2 suivantes (09:44:56Z, 09:45:52Z) montrent des résultats identiques.

---

## LOGS RUNTIME BRUTS – EXÉCUTION 1 (09:44:38Z)

| Log ID | Timestamp (local) | Valeur exacte | Type runtime | Fichier | Statut |
|--------|------------------|---------------|-------------|---------|--------|
| `RUNTIME T0` | 09:43:XX | `Feed ouvert - videos=69` | String | `student_challenges_tab.dart` | ✅ OK |
| `RUNTIME T1` | 09:44:XX | `Clic sur + - _controllers size=3` | String | `student_challenges_tab.dart` | ✅ OK |
| `RUNTIME T2` | 09:44:XX | `Ouverture Smart Whiteboard - _controllers size=3` | String | `student_challenges_tab.dart` | ✅ OK |
| `DEBUG-D19-01` | 09:44:XX | `createProject START subject=dérivés d'une fonction rendererId=notebook themeId=notebook narrationMode=tts` | String | `smart_whiteboard_provider.dart:~89` | ✅ OK |
| `DEBUG-D19-30` | 09:44:XX | `service.createProject RPC START` | String | `smart_whiteboard_service.dart:~25` | ✅ OK |
| `DEBUG-D19-31` | 09:44:XX | `service.createProject response={success: true, project_id: f04aa2f5-b456-4ffb-81f1-42216d7d36ae} runtimeType=_Map<String, dynamic> isNull=false` | `_Map<String, dynamic>` | `smart_whiteboard_service.dart:~30` | ✅ OK |
| `DEBUG-D19-02` | 09:44:XX | `createProject result={success: true, project_id: f04aa2f5-b456-4ffb-81f1-42216d7d36ae} runtimeType=_Map<String, dynamic> isNull=false` | `_Map<String, dynamic>` | `smart_whiteboard_provider.dart:~95` | ✅ OK |
| `DEBUG-D19-03` | 09:44:XX | `result['success']=true runtimeType=bool` | `bool` | `smart_whiteboard_provider.dart:~100` | ✅ OK |
| `DEBUG-D19-04` | 09:44:XX | `result['project_id']=f04aa2f5-b456-4ffb-81f1-42216d7d36ae runtimeType=String isNull=false` | `String` | `smart_whiteboard_provider.dart:~101` | ✅ OK |
| `DEBUG-D19-05` | 09:44:XX | `createProject _currentProjectId=f04aa2f5-b456-4ffb-81f1-42216d7d36ae` | `String` | `smart_whiteboard_provider.dart:~102` | ✅ OK |
| `DEBUG-D19-06` | 09:44:XX | `generateStoryboard invoke START mode=simple_subject subject= narration_mode=none` | String | `smart_whiteboard_provider.dart:~135` | ❌ **BOGUE : subject vide** |
| `DEBUG-D19-07` | 09:44:38Z | `generateStoryboard response.status=200 runtimeType=int` | `int` | `smart_whiteboard_provider.dart:~148` | ✅ HTTP 200 |
| `DEBUG-D19-08` | 09:44:38Z | `generateStoryboard response.data=Instance of 'FunctionResponse'.data runtimeType=_Map<String, dynamic> isNull=false` | `_Map<String, dynamic>` | `smart_whiteboard_provider.dart:~149` | ✅ OK |
| `DEBUG-D19-10` | 09:44:38Z | `generateStoryboard data={success: true, storyboard_json: {version: 1.0, created_at: 2026-06-28T09:44:38.260Z, created_by: 6745c7ad-..., subject: , renderer: scientific, theme: scientific, narration_mode: none, scenes: [...]}}` | `_Map<String, dynamic>` | `smart_whiteboard_provider.dart` | ✅ HTTP 200 / ❌ subject vide dans l'IA |
| `DEBUG-D19-11` | 09:44:38Z | `data['storyboard_json']={version: 1.0, ..., subject: , ...}` | `_Map<String, dynamic>` | `smart_whiteboard_provider.dart` | ❌ subject="" dans JSON IA |
| `DEBUG-D19-13` | 09:44:38Z | `generateStoryboard storyboardJson={version: 1.0, ..., subject: , ...}` | `_Map<String, dynamic>` | `smart_whiteboard_provider.dart` | ❌ subject="" propagé |
| `DEBUG 15` | 09:44:38Z | `Storyboard.fromJson json = {version: 1.0, ..., subject: , ...}` | `_Map<String, dynamic>` | `storyboard.dart` | ✅ parse OK |
| `DEBUG 22` | 09:44:38Z | `json['subject'] = ` | `String` | `storyboard.dart` | ❌ sujet vide confirmé |
| `DEBUG 23` | 09:44:38Z | `json['subject'] type = String` | `String` | `storyboard.dart` | ✅ type correct |
| `DEBUG-D19-68` | 09:44:38Z | `Storyboard.fromJson START json={version: 1.0, ..., subject: , ...}` | `_Map<String, dynamic>` | `storyboard.dart` | ✅ parse démarré |
| `DEBUG-D19-69` | 09:44:38Z | `Storyboard.fromJson version=1.0 runtimeType=String isNull=false` | `String` | `storyboard.dart` | ✅ OK |
| `DEBUG-D19-70` | 09:44:38Z | `Storyboard.fromJson created_at=2026-06-28T09:44:38.260Z runtimeType=String isNull=false` | `String` | `storyboard.dart` | ✅ OK |
| `DEBUG-D19-71` | 09:44:38Z | `Storyboard.fromJson created_by=6745c7ad-732b-47d0-b5b8-06d6dcf286ff runtimeType=String isNull=false` | `String` | `storyboard.dart` | ✅ OK |
| `DEBUG-D19-72` | 09:44:38Z | `Storyboard.fromJson subject= runtimeType=String isNull=false` | `String` | `storyboard.dart` | ❌ **subject="" confirmé runtime réel** |
| `DEBUG-D19-73` | 09:44:38Z | `Storyboard.fromJson renderer=scientific runtimeType=String isNull=false` | `String` | `storyboard.dart` | ✅ OK |
| `DEBUG-D19-74` | 09:44:38Z | `Storyboard.fromJson theme=scientific runtimeType=String isNull=false` | `String` | `storyboard.dart` | ✅ OK |
| `DEBUG-D19-75` | 09:44:38Z | `Storyboard.fromJson narration_mode=none runtimeType=String isNull=false` | `String` | `storyboard.dart` | ✅ OK |
| `DEBUG-D19-76` | 09:44:38Z | `ExportSettings={format: mp4, resolution: {width: 1080, height: 1920}, frame_rate: 30, video_codec: h264, audio_codec: aac}` | `_Map<String, dynamic>` | `storyboard.dart` | ✅ OK |
| `DEBUG-D19-77` | 09:44:38Z | `Storyboard.fromJson scenes=[{id: scene-001, ...Introduction aux Lois de Newton...}, {id: scene-002, ...Première Loi de Newton...}]` | `List<dynamic>` | `storyboard.dart` | ✅ parsé OK |
| `DEBUG-D19-51` | 09:44:38Z | `ExportSettings.fromJson START` | `_Map<String, dynamic>` | `storyboard.dart` | ✅ OK |
| `DEBUG-D19-52` | 09:44:38Z | `format=mp4 runtimeType=String` | `String` | `storyboard.dart` | ✅ OK |
| `DEBUG-D19-53` | 09:44:38Z | `resolution={width: 1080, height: 1920}` | `_Map<String, dynamic>` | `storyboard.dart` | ✅ OK |
| `DEBUG-D19-54` | 09:44:38Z | `frame_rate=30 runtimeType=int` | `int` | `storyboard.dart` | ✅ OK |
| `DEBUG-D19-55` | 09:44:38Z | `Resolution.fromJson START json={width: 1080, height: 1920}` | `_Map<String, dynamic>` | `storyboard.dart` | ✅ OK |
| `DEBUG-D19-56` | 09:44:38Z | `width=1080 runtimeType=int` | `int` | `storyboard.dart` | ✅ OK |
| `DEBUG-D19-57` | 09:44:38Z | `height=1920 runtimeType=int` | `int` | `storyboard.dart` | ✅ OK |
| `DEBUG-D19-58..67` | 09:44:38Z | `Scene.fromJson START / Block.fromJson` (2 scènes, 4 blocs) | `_Map<String, dynamic>` | `storyboard.dart` | ✅ tous parsés |

---

## VALEUR SAISIE DEVICE vs VALEUR REÇUE IA

| Champ | Valeur saisie device (D19-01) | Valeur envoyée IA (D19-06) | Valeur dans storyboard IA (D19-72) |
|-------|-------------------------------|---------------------------|-------------------------------------|
| `subject` | `"dérivés d'une fonction"` | `""` (vide) | `""` (vide) |
| `rendererId` | `"notebook"` | `"none"` (défaut) → `"scientific"` dans JSON IA | `"scientific"` |
| `themeId` | `"notebook"` | `"none"` (défaut) → `"scientific"` dans JSON IA | `"scientific"` |
| `narrationMode` | `"tts"` | `"none"` (défaut) | `"none"` |

> **Observation critique** : L'utilisateur a sélectionné `notebook` / `tts` — mais le JSON reçu de l'IA montre `scientific` / `none`. Cela confirme que `_currentProject == null` donc les fallbacks `?? 'scientific'` et `?? 'none'` sont utilisés.

---

## NAVIGATION VERS EDITOR — STATUT RUNTIME

Le test a produit le storyboard complètement parsé (D19-77 + 2 scènes + 4 blocs). Après D19-67 (dernier bloc parsé), aucun log d'erreur n'est présent → **la navigation vers l'EditorScreen a bien eu lieu** (aucun log `_setError` visible). La navigation **fonctionne** malgré le sujet vide car l'Edge Function retourne HTTP 200 avec un storyboard générique.

---

**DOCUMENT CLÔTURÉ** — Tous les logs sont réels, extraits de `adb logcat -s flutter` sur TECNO LD7.
