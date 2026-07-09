# AUDIT COMPLÉMENTAIRE – ACADEMIA SMART WHITEBOARD STUDIO

**Date** : 22 Juin 2026  
**Mode** : LECTURE SEULE  
**Objectif** : Déterminer la faisabilité d'un moteur de rendu pédagogique basé sur l'infrastructure existante

---

## PHASE 1 – AUDIT KAMATERA CLOUD

### 1.1 Serveur (basé sur audit existant)

| Paramètre | Valeur | Source |
|-----------|--------|--------|
| **IP publique** | 185.167.97.144 | STUDIO_KAMATERA_AUDIT.md |
| **WebSocket LiveKit** | ws://185.167.97.144:7880 | STUDIO_KAMATERA_AUDIT.md |
| **HTTP API LiveKit** | http://185.167.97.144:7880 | STUDIO_KAMATERA_AUDIT.md |
| **OS** | Ubuntu 24.04.4 LTS | STUDIO_KAMATERA_AUDIT.md |
| **vCPU** | 4 coeurs | STUDIO_KAMATERA_AUDIT.md |
| **RAM totale** | 9.7 Go | STUDIO_KAMATERA_AUDIT.md |
| **RAM utilisée** | 1.6 Go | STUDIO_KAMATERA_AUDIT.md |
| **RAM disponible** | 8.2 Go | STUDIO_KAMATERA_AUDIT.md |
| **Disque total** | 30 Go | STUDIO_KAMATERA_AUDIT.md |
| **Disque utilisé** | 17 Go (58%) | STUDIO_KAMATERA_AUDIT.md |
| **Disque disponible** | 12 Go | STUDIO_KAMATERA_AUDIT.md |
| **Bande passante** | 100 Mbps (Kamatera standard) | STUDIO_KAMATERA_AUDIT.md |
| **Région** | Non spécifiée | - |

### 1.2 Docker (basé sur audit existant)

| Conteneur | Image | État | Rôle |
|-----------|-------|------|------|
| livekit-server | livekit-server:latest | ✅ Actif (12 jours uptime) | Streaming temps réel |

**Observation critique** : Kamatera n'héberge que LiveKit. Aucun conteneur de traitement vidéo n'est actif sur Kamatera.

### 1.3 LiveKit (basé sur audit existant)

| Paramètre | Valeur |
|-----------|--------|
| **Version** | livekit-server:latest |
| **API Key** | APIKeylrmgQYJgiEZa |
| **WebSocket** | ws://185.167.97.144:7880 |
| **HTTP API** | http://185.167.97.144:7880 |
| **Redis** | 127.0.0.1:6379 (local) |
| **Capacité** | ~50 participants/room, ~10 rooms simultanées |
| **Recording** | Egress → Supabase Storage |
| **Enregistrement activé** | ✅ Oui (via Edge Function livekit-recording) |

### 1.4 FFmpeg (basé sur audit existant)

| Paramètre | Valeur |
|-----------|--------|
| **Présence** | ✅ Installé sur Kamatera |
| **Version** | 6.1.1-3ubuntu5 |
| **Localisation** | /usr/bin/ffmpeg |
| **Utilisation** | ❌ NON utilisé pour encodage vidéo sur Kamatera |
| **Utilisation réelle** | Docker local (academia-backend, academia-videoasset-worker) |

**Observation** : FFmpeg est installé sur Kamatera mais n'est PAS utilisé. Le traitement vidéo se fait en local via Docker ou sur Railway (indisponible).

### 1.5 Backend Python (basé sur audit existant)

| Composant | Localisation | Statut |
|-----------|-------------|--------|
| **main.py** | academia_bobodo_backend/ | ✅ Existe |
| **studio_video_renderer.py** | academia_bobodo_backend/ | ✅ Existe |
| **tv_pro_filter_builder.py** | academia_bobodo_backend/ | ✅ Existe |
| **videoasset_worker.py** | academia_bobodo_backend/ | ✅ Existe |
| **Déploiement** | Docker local (port 8001) | ⚠️ Local uniquement |
| **Déploiement production** | Railway | ❌ Indisponible |

**Capacités du backend** :
- `/studio/video/render` - Rendu vidéo avec overlays
- `/studio/ai/transcribe` - Transcription via ASR externe
- `/studio/ai/analyze` - Analyse IA
- `/studio/audio/render` - Mixage audio
- Support timeline JSON (TV PRO)
- Support keyframes, animations, transforms

---

## PHASE 2 – AUDIT SMART WHITEBOARD

### 2.1 Studio Scientifique (challenge_scientific_studio_screen.dart)

**Modèles de données** :

```dart
class SciStroke {
  final List<PointVector> points;  // x, y, pressure
  final Color color;
  final double size;
  final int? startMs;  // Visibilité temporelle
  final int? endMs;
}

class SciAnnotation {
  String id;
  String content;
  bool isLatex;
  Offset position;  // relative (0..1, 0..1)
  double fontSize;
  double scale;
  Color color;
  Color bgColor;
  int? startMs;
  int? endMs;
}
```

**Capacités identifiées** :
- ✅ Dessin libre avec `perfect_freehand`
- ✅ Annotations texte/LaTeX avec `flutter_math_fork`
- ✅ Coordonnées relatives (scalabilité)
- ✅ Visibilité temporelle (startMs, endMs)
- ✅ Export JSON via `toJson()`
- ✅ Undo/redo pour les traits
- ✅ Palette de couleurs (8 couleurs)
- ✅ Épaisseurs variables (5 tailles)
- ✅ Pinch-to-resize pour annotations

**Limites identifiées** :
- ❌ Pas de timestamp individuel par point
- ❌ Pas de pression enregistrée par défaut (pressure = 0.5)
- ❌ Pas de calques multiples
- ❌ Pas d'animation de tracé progressif
- ❌ Pas de rejouer des tracés

### 2.2 Whiteboard Canvas (whiteboard_canvas.dart)

**Modèles de données** :

```dart
class WhiteboardStroke {
  final String id;
  final String userId;
  final List<Point> points;  // x, y, pressure
  final Color color;
  final double strokeWidth;
  final bool isEraser;
  final DateTime createdAt;
}

class Point {
  final double x;
  final double y;
  final double pressure;
}
```

**Capacités identifiées** :
- ✅ Dessin avec `perfect_freehand`
- ✅ Support pression (0.0-1.0)
- ✅ Outils : stylo, surligneur, gomme
- ✅ Palette de couleurs (8 couleurs)
- ✅ Épaisseurs variables (4 tailles)
- ✅ Synchronisation remote strokes (live sessions)
- ✅ Undo local
- ✅ CustomPainter pour rendu

**Limites identifiées** :
- ❌ Pas de timestamp par point
- ❌ Pas de rejouer des tracés
- ❌ Pas d'animation d'écriture progressive

### 2.3 Capacités de dessin

**Question : Peut-on enregistrer chaque trait individuellement ?**

**Réponse** : ✅ OUI
- Chaque trait est stocké comme un objet `SciStroke` ou `WhiteboardStroke`
- Liste complète des points par trait
- Métadonnées par trait (couleur, taille, outil)

**Question : Peut-on récupérer points, pressure, timestamp ?**

**Réponse** : ⚠️ PARTIEL
- ✅ Points : `[x, y]` pour chaque point
- ✅ Pressure : `pressure` (0.0-1.0) pour chaque point
- ❌ Timestamp : NON - pas de timestamp individuel par point
- ⚠️ Temporel : `startMs/endMs` par trait (visibilité, pas tracé)

**Question : Peut-on rejouer les tracés ?**

**Réponse** : ❌ NON
- Aucun composant de rejouer identifié
- Pas d'AnimationController pour les traits
- Pas de timestamp pour reconstruction temporelle

**Question : Peut-on produire une animation d'écriture progressive ?**

**Réponse** : ❌ NON avec l'implémentation actuelle
- Pas de timestamp par point
- Pas de composant d'animation de tracé
- Nécessiterait une refonte du modèle de données

### 2.4 Capacités Flutter

**Composants identifiés** :
- ✅ `CustomPainter` - Utilisé dans whiteboard_canvas.dart
- ✅ `Path` - Utilisé implicitement par perfect_freehand
- ❌ `AnimationController` - Non utilisé pour les traits
- ❌ `Rive` - Non présent dans le code
- ❌ `Lottie` - Non présent dans le code
- ✅ `animate_do` - Présent pour UI animations (fade, slide, etc.)

**Possibilités de réutilisation** :
- ✅ CustomPainter peut être étendu pour l'animation
- ✅ perfect_freehand peut être utilisé pour le lissage
- ⚠️ AnimationController doit être ajouté pour les traits
- ❌ Rive/Lottie non disponibles (seraient utiles pour animations complexes)

---

## PHASE 3 – AUDIT AUDIO

### 3.1 Services Audio

| Service | Fichier | Rôle | Statut |
|---------|---------|------|--------|
| **StudioAudioService** | studio_audio_service.dart | Mixage audio backend | ✅ Actif |
| **AudioMixService** | audio_mix_service.dart | Mixage FFmpeg local | ❌ Désactivé |
| **BobodoVocalService** | bobodo_vocal_service.dart | WebSocket vocal | ✅ Actif |
| **StudioAiService** | studio_ai_service.dart | Transcription/analyse | ✅ Actif |

### 3.2 Transcription (studio_ai_service.dart)

**Endpoint** : `/studio/ai/transcribe`

**Paramètres** :
```dart
{
  'participation_id': String,
  'video_type': 'challenge' | 'free',
  'language': String?,
  'free_video_id': String?
}
```

**Backend (main.py)** :
```python
async def call_studio_asr(video_url: str, language: Optional[str]) -> List[Dict[str, Any]]:
    # Appelle STUDIO_ASR_URL (service externe)
    # Retourne une liste de sous-titres
```

**Réponse** :
```python
class StudioTranscriptionResponse(BaseModel):
    success: bool
    participation_id: str
    subtitles: List[Dict[str, Any]]  # Format non spécifié dans le code
    overlays: Dict[str, Any]
    video_type: Optional[str] = "challenge"
    free_video_id: Optional[str] = None
```

### 3.3 Capacités de transcription

**Question : Peut-on obtenir une transcription mot par mot ?**

**Réponse** : ❌ INCERTAIN - Non prouvé par le code analysé
- Le code appelle un service ASR externe (`STUDIO_ASR_URL`)
- Le format de retour `subtitles` n'est pas spécifié dans le code
- Aucun exemple de structure avec timestamps mot par mot
- Aucune validation du format de retour

**Question : Existe-t-il déjà une fonctionnalité similaire ?**

**Réponse** : ❌ NON identifiée
- Aucun composant de synchronisation mot par mot
- Aucun composant de karaoke/word-level timing
- La transcription est stockée dans `overlays["subtitles"]` sans structure détaillée

**Question : Existe-t-il un composant réutilisable ?**

**Réponse** : ❌ NON
- Pas de service de synchronisation audio-texte
- Pas de composant Flutter pour affichage mot par mot
- Nécessiterait développement complet

---

## PHASE 4 – AUDIT RENDU VIDÉO

### 4.1 Studio Video Renderer (studio_video_renderer.py)

**Endpoint** : `/render`

**Paramètres** :
```python
class RenderRequest(BaseModel):
    video_url: str
    overlays: Dict[str, Any] = {}
    participation_id: str
```

**Capacités FFmpeg** :
- ✅ Transcodage multi-résolution (main, 480p, 360p, 240p)
- ✅ H.264 Baseline Level 3.0 (MediaTek-friendly)
- ✅ Filter complex pour overlays
- ✅ Support keyframes
- ✅ Support animations
- ✅ Support transforms

**Profils de transcodage** :
| Profil | Résolution | Bitrate | FPS |
|--------|------------|---------|-----|
| main | 720p max | 900k | auto |
| 480p | 480p | 600k | 30 |
| 360p | 360p | 450k | 30 |
| 240p | 240p | 300k | 24 |

### 4.2 TV Pro Filter Builder (tv_pro_filter_builder.py)

**Fonction** : `build_tv_pro_filtergraph(timeline: Dict[str, Any])`

**Capacités identifiées** :
- ✅ Support timeline JSON
- ✅ Support overlays avec `start_at_seconds` / `end_at_seconds`
- ✅ Support position (x, y, align)
- ✅ Support keyframes (t, x, y, etc.)
- ✅ Support animations (animation dict)
- ✅ Support transforms (transform dict)
- ✅ Expressions FFmpeg complexes pour keyframes
- ✅ Expressions enable/disable temporelles

**Structure timeline** :
```python
{
  "overlays": [
    {
      "type": "text|image|video",
      "start_at_seconds": float,
      "end_at_seconds": float,
      "position": {"x": int, "y": int} | "align": "top_left|...",
      "keyframes": [{"t": float, "x": float, "y": float, ...}],
      "animation": {...},
      "transform": {...}
    }
  ]
}
```

### 4.3 Capacités de rendu pédagogique

**Question : Peut-il recevoir un storyboard JSON ?**

**Réponse** : ✅ OUI
- Le système TV PRO utilise déjà un timeline JSON
- La structure supporte overlays, keyframes, animations
- Le backend peut être étendu pour accepter un storyboard

**Question : Peut-il produire titres ?**

**Réponse** : ✅ OUI (avec adaptation)
- Support text overlays via FFmpeg drawtext
- Positionnement flexible (x, y, align)
- Visibilité temporelle (start_at, end_at)
- Nécessite mapping storyboard → timeline JSON

**Question : Peut-il produire écriture progressive ?**

**Réponse** : ⚠️ PARTIEL (nécessite développement)
- Support keyframes pour position/opacity
- Peut simuler écriture progressive via keyframes opacity
- Mais nécessite génération automatique des keyframes depuis les traits
- Pas de composant prêt à l'emploi

**Question : Peut-il produire surlignage ?**

**Réponse** : ✅ OUI (avec adaptation)
- Support rectangles/shapes via FFmpeg
- Peut simuler surlignage via drawbox
- Nécessite mapping storyboard → timeline JSON

**Question : Peut-il produire zoom ?**

**Réponse** : ✅ OUI
- Support zoom/pan via FFmpeg scale/pan filters
- Keyframes pour zoom progressif
- Déjà supporté par TV PRO filter builder

**Question : Peut-il produire encadrement ?**

**Réponse** : ✅ OUI
- Support rectangles/bordures via FFmpeg drawbox
- Positionnement flexible
- Déjà supporté par TV PRO filter builder

**Question : Peut-il produire transitions ?**

**Réponse** : ⚠️ LIMITÉ
- FFmpeg supporte transitions (xfade, etc.)
- Mais pas intégré dans le filter builder actuel
- Nécessiterait développement

### 4.4 Estimation des capacités

| Fonctionnalité | Disponible | Nécessite adaptation | Nécessite développement complet |
|---------------|------------|---------------------|--------------------------------|
| Storyboard JSON | ✅ OUI | ⚠️ Mapping | ❌ |
| Titres | ✅ OUI | ⚠️ Mapping | ❌ |
| Écriture progressive | ⚠️ Keyframes | ✅ Génération auto | ❌ |
| Surlignage | ✅ OUI | ⚠️ Mapping | ❌ |
| Zoom | ✅ OUI | ⚠️ Mapping | ❌ |
| Encadrement | ✅ OUI | ⚠️ Mapping | ❌ |
| Transitions | ❌ | ❌ | ✅ OUI |

---

## PHASE 5 – FAISABILITÉ SMART TIMELINE ENGINE

### 5.1 Architecture cible proposée

```
Script
↓
Bobodo
↓
Storyboard JSON
↓
Voix
↓
Transcription
↓
Animations
↓
Rendu Kamatera
↓
MP4
```

### 5.2 Analyse composant par composant

#### 5.2.1 Script → Bobodo

**État actuel** : ✅ DISPONIBLE
- Bobodo chat existe et fonctionne
- Edge Function `bobodo-chat` déployée
- Système de crédits intégré
- OpenRouter pour génération

**Capacité à générer storyboard** : ❌ NON
- Bobodo génère du texte, pas de JSON structuré
- Pas de prompt pour générer storyboard
- Pas de format storyboard défini

**Nécessite** : Développement complet
- Définir format storyboard JSON
- Créer prompt Bobodo pour génération storyboard
- Valider et parser le JSON généré

#### 5.2.2 Storyboard JSON → Voix

**État actuel** : ⚠️ PARTIEL
- TTS existe via `flutter_tts`
- BobodoVocalService pour WebSocket vocal
- Pas de génération audio depuis storyboard

**Capacité à générer voix depuis storyboard** : ❌ NON
- Aucun composant de TTS batch
- Aucun composant de génération audio depuis script
- Pas de synchronisation avec storyboard

**Nécessite** : Développement complet
- Service TTS batch (Edge Function ou backend)
- Mapping storyboard → segments audio
- Génération fichiers audio synchronisés

#### 5.2.3 Voix → Transcription

**État actuel** : ⚠️ PARTIEL
- Transcription existe via `studio_ai_service`
- Appelle service ASR externe
- Format retour non spécifié

**Capacité transcription mot par mot** : ❌ INCERTAIN
- Format retour non documenté
- Pas de preuve de timestamps mot par mot
- Service ASR externe non audité

**Nécessite** : Audit + développement
- Auditer le service ASR externe
- Valider format de retour
- Si pas de mot par mot : changer de service ou développer

#### 5.2.4 Transcription → Animations

**État actuel** : ❌ NON
- Aucun composant de génération d'animations depuis transcription
- Aucun composant de synchronisation mot par mot
- Studio scientifique ne supporte pas animation de tracé

**Capacité à générer animations** : ❌ NON
- Pas de timestamp par point dans les traits
- Pas de composant d'animation de tracé
- Pas de mapping transcription → animations

**Nécessite** : Développement complet
- Refonte modèle de données (ajouter timestamp par point)
- Composant d'animation de tracé (AnimationController)
- Algorithme de mapping transcription → keyframes

#### 5.2.5 Animations → Rendu Kamatera

**État actuel** : ⚠️ PARTIEL
- Backend Python existe avec timeline JSON
- TV Pro filter builder supporte keyframes/animations
- FFmpeg installé sur Kamatera mais non utilisé

**Capacité à rendre depuis storyboard** : ⚠️ PARTIEL
- Timeline JSON existe mais format TV PRO
- Mapping storyboard → timeline nécessaire
- Backend doit être déployé sur Kamatera (actuellement local)

**Nécessite** : Adaptation + déploiement
- Définir format storyboard compatible avec timeline
- Mapper storyboard → timeline JSON
- Déployer backend sur Kamatera
- Activer FFmpeg sur Kamatera

#### 5.2.6 Rendu Kamatera → MP4

**État actuel** : ✅ DISPONIBLE
- FFmpeg transcodage fonctionne
- Multi-résolution supportée
- Upload Supabase Storage

**Capacité à produire MP4** : ✅ OUI
- Backend peut produire MP4
- Renditions multi-résolution
- Upload automatique

**Nécessite** : Déploiement sur Kamatera
- Déployer backend sur Kamatera
- Configurer FFmpeg sur Kamatera

### 5.3 Faisabilité globale

**Architecture proposée réalisable ?** : ❌ NON dans l'état actuel

**Blocages critiques** :
1. **Bobodo ne génère pas de storyboard JSON** - Développement complet nécessaire
2. **Pas de TTS batch depuis storyboard** - Développement complet nécessaire
3. **Transcription mot par mot non prouvée** - Audit + développement nécessaires
4. **Pas d'animation de tracé** - Refonte modèle + développement complet
5. **Backend non déployé sur Kamatera** - Déploiement nécessaire
6. **Format storyboard non défini** - Conception nécessaire

**Pourcentage de réutilisation estimé** : ~20%

| Composant | Réutilisation | Adaptation | Nouveau |
|-----------|---------------|------------|---------|
| Bobodo chat | 20% (texte) | - | 80% (storyboard) |
| TTS | 10% (flutter_tts) | - | 90% (batch) |
| Transcription | 30% (service) | 50% (format) | 20% (mot par mot) |
| Animations | 0% | - | 100% |
| Rendu FFmpeg | 40% (backend) | 40% (mapping) | 20% (déploiement) |

---

## LIVRABLE FINAL

### 1. État réel de Kamatera Cloud

**Serveur** :
- IP : 185.167.97.144
- OS : Ubuntu 24.04.4 LTS
- vCPU : 4 coeurs
- RAM : 9.7 Go (1.6 Go utilisé)
- Disque : 30 Go (17 Go utilisé)
- Bande passante : 100 Mbps

**Docker** :
- 1 conteneur : livekit-server
- Aucun conteneur de traitement vidéo

**LiveKit** :
- Version : latest
- Capacité : ~50 participants/room
- Recording : ✅ Activé (Egress → Supabase)

**FFmpeg** :
- Version : 6.1.1-3ubuntu5
- Installé : ✅ Oui
- Utilisé : ❌ NON (traitement vidéo local Docker)

**Backend Python** :
- main.py : ✅ Existe
- studio_video_renderer.py : ✅ Existe
- tv_pro_filter_builder.py : ✅ Existe
- Déploiement : Docker local (port 8001)
- Production : ❌ Indisponible (Railway bloqué)

### 2. Capacités réelles de LiveKit

**Fonctionnalités** :
- ✅ Streaming temps réel
- ✅ Egress recording
- ✅ Token JWT via Edge Function
- ✅ Synchronisation multi-participants
- ✅ Support audio/video

**Limites** :
- ❌ Pas de transcription intégrée
- ❌ Pas de synchronisation mot par mot
- ❌ Pas de génération de storyboard

### 3. Capacités réelles de FFmpeg

**Installé sur** :
- Kamatera : ✅ Oui (non utilisé)
- Docker local : ✅ Oui (utilisé)

**Capacités** :
- ✅ Transcodage multi-résolution
- ✅ H.264 Baseline Level 3.0
- ✅ Filter complex
- ✅ Keyframes
- ✅ Animations basiques
- ✅ Transitions (non intégré)

**Limites** :
- ❌ Non utilisé sur Kamatera
- ❌ Pas de pipeline de rendu pédagogique
- ❌ Pas de génération automatique de keyframes depuis traits

### 4. Capacités réelles du Studio Scientifique

**Fonctionnalités** :
- ✅ Dessin libre (perfect_freehand)
- ✅ Annotations LaTeX (flutter_math_fork)
- ✅ Coordonnées relatives
- ✅ Visibilité temporelle (startMs/endMs)
- ✅ Export JSON
- ✅ Undo/redo

**Limites** :
- ❌ Pas de timestamp par point
- ❌ Pas de pression enregistrée par défaut
- ❌ Pas de calques multiples
- ❌ Pas d'animation de tracé
- ❌ Pas de rejouer des tracés

### 5. Capacités réelles du système audio

**Fonctionnalités** :
- ✅ Mixage audio backend
- ✅ Transcription via ASR externe
- ✅ WebSocket vocal
- ✅ TTS (flutter_tts)

**Limites** :
- ❌ Format transcription non documenté
- ❌ Pas de preuve de timestamps mot par mot
- ❌ Pas de TTS batch
- ❌ Pas de synchronisation audio-texte

### 6. Faisabilité du Smart Whiteboard Studio

**Conclusion** : ❌ NON FAISABLE dans l'état actuel

**Blocages** :
1. Pas de timestamp par point pour animation de tracé
2. Pas de composant d'animation de tracé
3. Transcription mot par mot non prouvée
4. Pas de génération storyboard depuis Bobodo
5. Pas de TTS batch depuis storyboard

**Estimation travail** : 3-4 mois de développement complet

### 7. Faisabilité du Smart Timeline Engine

**Conclusion** : ❌ NON FAISABLE dans l'état actuel

**Blocages** :
1. Format storyboard non défini
2. Bobodo ne génère pas de storyboard
3. Pas de pipeline audio synchronisé
4. Pas de mapping transcription → animations
5. Backend non déployé sur Kamatera

**Estimation travail** : 4-6 mois de développement complet

### 8. Architecture recommandée

**Approche incrémentale** :

**Phase 1 (1 mois)** : Infrastructure
- Déployer backend Python sur Kamatera
- Activer FFmpeg sur Kamatera
- Créer RPC administrateur pour orchestration Kamatera

**Phase 2 (1 mois)** : Transcription
- Auditer service ASR externe
- Valider format de retour
- Si mot par mot : intégrer
- Sinon : implémenter Whisper local ou changer de service

**Phase 3 (1.5 mois)** : Animation de tracé
- Refonte modèle SciStroke (ajouter timestamp)
- Implémenter AnimationController pour traits
- Créer composant de rejouer des tracés
- Générer keyframes depuis traits

**Phase 4 (1.5 mois)** : Storyboard
- Définir format storyboard JSON
- Créer prompt Bobodo pour génération storyboard
- Implémenter validation et parsing
- Mapper storyboard → timeline JSON

**Phase 5 (1 mois)** : Audio synchronisé
- Implémenter TTS batch (Edge Function)
- Mapper storyboard → segments audio
- Synchroniser audio avec transcription

**Phase 6 (1 mois)** : Rendu pédagogique
- Intégrer pipeline complet
- Tester rendu depuis storyboard
- Optimiser performances

**Total estimé** : 6-7 mois

### 9. Estimation du travail nécessaire

| Composant | Estimation | Complexité |
|-----------|------------|------------|
| Infrastructure Kamatera | 1 mois | Moyenne |
| Transcription mot par mot | 1 mois | Haute |
| Animation de tracé | 1.5 mois | Haute |
| Storyboard Bobodo | 1.5 mois | Haute |
| Audio synchronisé | 1 mois | Moyenne |
| Rendu pédagogique | 1 mois | Moyenne |
| **Total** | **6-7 mois** | **Haute** |

### 10. Risques techniques identifiés

**Critiques** :
1. **Service ASR externe** : Format non documenté, dépendance externe
2. **Backend non déployé** : Railway bloqué, nécessite déploiement Kamatera
3. **Modèle de données** : Refonte nécessaire (timestamp par point)
4. **Performance** : Rendu vidéo sur Kamatera peut être lent
5. **Coût** : Kamatera limité en ressources (4 vCPU, 9.7 Go RAM)

**Moyens** :
1. **TTS batch** : Pas de solution existante, développement nécessaire
2. **Mapping storyboard** : Complexité de mapping non trivial
3. **Synchronisation** : Audio-transcription-animations difficile à synchroniser
4. **FFmpeg sur Kamatera** : Peut impacter les performances LiveKit

**Faibles** :
1. **Dépendance Bobodo** : OpenRouter peut changer
2. **Format storyboard** : Non standardisé
3. **Tests** : Complexité de tests E2E élevée

---

## CONCLUSION

Le Smart Whiteboard Studio et le Smart Timeline Engine ne sont **PAS faisables** dans l'état actuel de l'infrastructure. Bien que des composants existent (LiveKit, FFmpeg, backend Python, studio scientifique), ils ne sont pas intégrés pour former un pipeline de rendu pédagogique.

**Recommandation** : Suivre l'approche incrémentale en 6 phases (6-7 mois) pour construire progressivement les capacités manquantes, en commençant par l'infrastructure Kamatera et la transcription mot par mot.

**Alternative** : Utiliser une solution SaaS existante (ex: Loom, Descript) pour le rendu pédagogique, et se concentrer sur l'intégration plutôt que le développement from scratch.
