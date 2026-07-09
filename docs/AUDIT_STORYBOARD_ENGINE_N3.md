# AUDIT SUPPLÉMENTAIRE N°3 – STORYBOARD ENGINE & SMART WHITEBOARD RENDERER

**Date** : 22 Juin 2026  
**Mode** : LECTURE SEULE  
**Objectif** : Déterminer la faisabilité d'un moteur de rendu pédagogique basé sur l'existant

---

## PHASE 1 – AUDIT DU MOTEUR DE RENDU EXISTANT

### 1.1 studio_video_renderer.py

**Endpoint** : `/render`

**Paramètres** :
```python
class RenderRequest(BaseModel):
    video_url: str
    overlays: Dict[str, Any] = {}
    participation_id: str
```

**Capacités** :
- ✅ Téléchargement vidéo depuis URL
- ✅ Transcodage multi-résolution (main, 480p, 360p, 240p)
- ✅ Upload vers Supabase Storage
- ❌ PAS de génération automatique depuis données structurées
- ❌ PAS de création de vidéo ex nihilo
- ❌ Nécessite une vidéo source en entrée

**Observation critique** : Le moteur actuel est un **transcodeur**, pas un **générateur**. Il ne peut pas créer une vidéo à partir de rien, il transforme une vidéo existante.

### 1.2 tv_pro_filter_builder.py

**Fonction** : `build_tv_pro_filtergraph(timeline: Dict[str, Any])`

**Structure timeline JSON** :
```python
{
  "overlays": [
    {
      "type": "text|image|video|pip|background|banner|lower_third|ticker",
      "start_at_seconds": float,
      "end_at_seconds": float,
      "position": {"x": int, "y": int} | "align": "top_left|...",
      "text": str,  # pour type text
      "source_url": str,  # pour type image/video
      "keyframes": [{"t": float, "x": float, "y": float, ...}],
      "animation": {"mode": "slide_from_left|..."},
      "transform": {"scale": float, "rotate": float, "opacity": float}
    }
  ]
}
```

**Capacités** :
- ✅ Lecture de timeline JSON structurée
- ✅ Support overlays multiples (text, image, video, pip)
- ✅ Support keyframes (position, scale, rotate, opacity)
- ✅ Support animations prédéfinies (slide_from_left, slide_from_right, etc.)
- ✅ Support transforms (scale, rotate, opacity)
- ✅ Expressions FFmpeg complexes pour keyframes
- ✅ Visibilité temporelle (start_at_seconds, end_at_seconds)
- ✅ Positionnement flexible (x, y, align)
- ✅ Maximum 24 overlays par timeline

**Limites** :
- ❌ Nécessite une vidéo source en entrée
- ❌ Pas de génération de contenu (texte, images)
- ❌ Pas de création de scènes
- ❌ Pas de génération automatique de keyframes
- ❌ Formats d'animation limités (slide, pas d'écriture progressive)

### 1.3 Pipeline vidéo existant

**Architecture actuelle** :
```
Vidéo source (uploadée ou existante)
↓
studio_video_renderer.py (transcodage)
↓
tv_pro_filter_builder.py (overlays)
↓
FFmpeg (rendu)
↓
MP4 multi-résolution
```

**Observation** : Le pipeline est **orienté transformation**, pas **génération**.

### 1.4 Réponse à la question

**Le moteur actuel peut-il générer automatiquement une vidéo à partir de données structurées ?**

**Réponse** : ❌ NON

**Justification** :
- Le moteur nécessite obligatoirement une `video_url` en entrée
- Il ne peut pas créer une vidéo ex nihilo
- Il ne peut pas générer de contenu (texte, images, animations)
- Il ne peut transformer que ce qui existe déjà

**Exemple** :
```json
{
  "title":"Photosynthèse",
  "content":"La photosynthèse permet..."
}
```

Ce JSON ne peut PAS être transformé en vidéo par le moteur actuel. Il faudrait d'abord générer une vidéo source, ce que le moteur ne fait pas.

### 1.5 Ce qui existe déjà

| Composant | Statut | Utilité |
|-----------|--------|---------|
| FFmpeg | ✅ Installé | Transcodage, filtres |
| studio_video_renderer.py | ✅ Existe | Transcodage multi-résolution |
| tv_pro_filter_builder.py | ✅ Existe | Interprétation timeline JSON |
| Timeline JSON | ✅ Existe | Structure overlays |
| Keyframes | ✅ Supporté | Animations basiques |
| Animations prédéfinies | ✅ Supporté | Slide, fade, etc. |

### 1.6 Ce qui est réutilisable

| Composant | Réutilisation | Adaptation nécessaire |
|-----------|---------------|----------------------|
| FFmpeg | 100% | Aucune |
| tv_pro_filter_builder.py | 60% | Extension pour nouveaux types d'overlays |
| Timeline JSON | 80% | Extension pour storyboard pédagogique |
| Keyframes | 70% | Génération automatique depuis contenu |

### 1.7 Ce qui manque

| Composant | Nécessité |
|-----------|-----------|
| Générateur de vidéo source | Critique |
| Générateur de contenu (texte, images) | Critique |
| Générateur d'animations d'écriture | Critique |
| Générateur de keyframes automatiques | Critique |
| Moteur de storyboard pédagogique | Critique |

---

## PHASE 2 – AUDIT STORYBOARD ENGINE

### 2.1 Structure proche existante

**Timeline JSON TV PRO** :
```json
{
  "overlays": [
    {
      "type": "text",
      "text": "...",
      "start_at_seconds": 0.0,
      "end_at_seconds": 5.0,
      "position": {"x": 100, "y": 100}
    }
  ]
}
```

**Storyboard pédagogique cible** :
```json
{
  "page": "cahier",
  "elements": [
    {
      "type": "title",
      "text": "Photosynthèse"
    },
    {
      "type": "paragraph",
      "text": "La photosynthèse est..."
    },
    {
      "type": "formula",
      "text": "CO2 + H2O"
    }
  ]
}
```

**Similarités** :
- ✅ Structure JSON
- ✅ Liste d'éléments
- ✅ Types d'éléments
- ✅ Propriétés textuelles

**Différences** :
- ❌ Timeline : synchronisation temporelle (start_at_seconds)
- ❌ Storyboard : organisation sémantique (page, elements)
- ❌ Timeline : nécessite vidéo source
- ❌ Storyboard : peut être généré ex nihilo

### 2.2 Moteur pouvant lire un JSON et générer un rendu

**Existant** : `tv_pro_filter_builder.py`

**Capacité** : ✅ OUI, mais limité
- Lit un timeline JSON
- Génère un filter_complex FFmpeg
- Applique des overlays sur une vidéo source

**Limitation** : ❌ Ne peut pas générer de vidéo source
- Nécessite une vidéo en entrée
- Ne peut pas créer de scènes
- Ne peut pas générer de contenu

**Conclusion** : Le moteur existe mais est **incomplet** pour un storyboard pédagogique. Il manque la génération de la vidéo source.

### 2.3 Système de couches ou de scènes

**Existant** : ❌ NON
- Aucun système de couches identifié
- Aucun système de scènes identifié
- Timeline JSON utilise des overlays, pas des scènes

**Nécessité** : Développement complet
- Système de scènes (pages)
- Système de couches (background, foreground, etc.)
- Transition entre scènes

### 2.4 Système de keyframes exploitable

**Existant** : ✅ OUI
- Support keyframes dans timeline JSON
- Expressions FFmpeg pour keyframes
- Support position, scale, rotate, opacity

**Limitation** : ❌ Génération manuelle
- Les keyframes doivent être définis manuellement
- Pas de génération automatique depuis contenu
- Pas d'algorithmes de keyframing intelligent

### 2.5 Réponses aux questions

**1. Existe-t-il déjà une structure proche dans le projet ?**

**Réponse** : ⚠️ PARTIEL
- Timeline JSON existe (TV PRO)
- Structure similaire (liste d'éléments)
- Mais orientation différente (temporelle vs sémantique)

**2. Existe-t-il déjà un moteur pouvant lire un JSON et générer un rendu ?**

**Réponse** : ⚠️ PARTIEL
- tv_pro_filter_builder.py existe
- Mais nécessite une vidéo source
- Ne peut pas générer ex nihilo

**3. Existe-t-il déjà un système de couches ou de scènes ?**

**Réponse** : ❌ NON
- Aucun système de scènes
- Aucun système de couches
- Nécessite développement complet

**4. Existe-t-il déjà un système de keyframes exploitable ?**

**Réponse** : ✅ OUI
- Support keyframes dans timeline JSON
- Expressions FFmpeg complexes
- Mais génération manuelle uniquement

---

## PHASE 3 – AUDIT WHITEBOARD RENDERER

### 3.1 Moteurs de texte animés

**Existant** : ❌ NON
- Aucun moteur de texte animé identifié
- Aucun composant d'animation de texte
- Aucun composant d'écriture progressive

**Packages Flutter** :
- `animate_do` : ✅ Présent (fade, slide, zoom UI animations)
- ❌ Pas d'animation de texte par caractère
- ❌ Pas d'animation d'écriture progressive

### 3.2 Moteurs Canvas

**Existant** : ✅ OUI
- `CustomPainter` utilisé dans whiteboard_canvas.dart
- `Canvas` utilisé dans plusieurs composants
- `perfect_freehand` pour dessin lissé

**Limitation** : ❌ Pas d'animation de tracé
- CustomPainter dessine statiquement
- Pas de AnimationController pour les traits
- Pas de rejouer des tracés

### 3.3 Moteurs CustomPainter

**Existant** : ✅ OUI
- Utilisé dans whiteboard_canvas.dart
- Utilisé dans video_overlays_layer.dart
- Utilisé dans zone_selector.dart

**Capacités** :
- ✅ Dessin statique
- ✅ Rendu d'overlays
- ❌ Pas d'animation de tracé
- ❌ Pas d'écriture progressive

### 3.4 Moteurs SVG

**Existant** : ✅ OUI
- `flutter_svg` présent dans pubspec.yaml
- Utilisé pour bobodo_avatar.svg

**Limitation** : ❌ Pas de génération SVG
- Pas de génération de SVG depuis texte
- Pas de conversion texte → SVG manuscrit

### 3.5 Moteurs Rive

**Existant** : ❌ NON
- Aucun package Rive identifié
- Aucun fichier .riv identifié

### 3.6 Moteurs Lottie

**Existant** : ❌ NON
- Aucun package Lottie identifié
- Aucun fichier .json Lottie identifié

### 3.7 Réponse à la question

**Existe-t-il déjà dans le projet des moteurs réutilisables pour générer des animations d'écriture progressive ?**

**Réponse** : ❌ NON

**Justification** :
- CustomPainter existe mais ne fait que du dessin statique
- Aucun AnimationController pour les traits
- Aucun composant d'écriture progressive
- Aucun composant d'animation par caractère
- Rive/Lottie non disponibles

**Nécessité** : Développement complet
- Composant d'animation de tracé
- Algorithme de génération de keyframes depuis texte
- Système de timestamp par point

---

## PHASE 4 – AUDIT SMART TIMELINE ENGINE

### 4.1 BobodoVocalService

**Existant** : ✅ OUI
- Service WebSocket pour interaction vocale
- Utilise flutter_sound pour enregistrement
- Utilise speech_to_text pour transcription
- Utilise flutter_tts pour synthèse vocale

**Limitation** : ❌ Pas de synchronisation contenu
- Transcription en temps réel
- Pas de timestamps mot par mot
- Pas de synchronisation avec animations

### 4.2 StudioAudioService

**Existant** : ✅ OUI
- Service de mixage audio backend
- Endpoint `/studio/audio/render`
- Mixage de pistes audio

**Limitation** : ❌ Pas de transcription
- Mixage uniquement
- Pas de transcription
- Pas de timestamps

### 4.3 LiveKit

**Existant** : ✅ OUI
- Streaming temps réel
- Recording via Egress
- Synchronisation multi-participants

**Limitation** : ❌ Pas de transcription intégrée
- Streaming uniquement
- Pas de transcription
- Pas de timestamps mot par mot

### 4.4 Système ASR existant

**Existant** : ⚠️ PARTIEL
- Service ASR externe (STUDIO_ASR_URL)
- Endpoint `/studio/ai/transcribe`
- Retourne une liste de sous-titres

**Format de retour** :
```python
class StudioTranscriptionResponse(BaseModel):
    success: bool
    participation_id: str
    subtitles: List[Dict[str, Any]]  # Format non spécifié
    overlays: Dict[str, Any]
```

**Limitation critique** : ❌ Format non documenté
- Le format de `subtitles` n'est pas spécifié dans le code
- Aucun exemple de structure avec timestamps
- Aucune validation du format de retour
- Service ASR externe non audité

### 4.5 Réponses aux questions

**1. Peut-on obtenir une transcription segmentée ?**

**Réponse** : ❌ INCERTAIN
- Service ASR externe existe
- Mais format de retour non documenté
- Aucune preuve de segmentation

**2. Peut-on obtenir des timestamps phrase par phrase ?**

**Réponse** : ❌ INCERTAIN
- Format non documenté
- Aucune preuve de timestamps phrase
- Service ASR externe non audité

**3. Peut-on obtenir des timestamps mot par mot ?**

**Réponse** : ❌ INCERTAIN
- Format non documenté
- Aucune preuve de timestamps mot
- Service ASR externe non audité

**4. Si non, quelle solution serait la plus simple à intégrer ?**

**Réponse** : Whisper local
- Whisper OpenAI peut fournir timestamps mot par mot
- Peut être déployé sur Kamatera
- Plus fiable qu'un service externe non audité
- Coût : développement d'une Edge Function

---

## PHASE 5 – AUDIT GÉNÉRATION MANUSCRITE

### 5.1 Polices manuscrites

**Existant** : ❌ NON
- Aucune police manuscrite identifiée dans les assets
- Polices utilisées : RobotoMono, monospace
- Aucun fichier .ttf manuscrit

**Polices disponibles** :
- RobotoMono (monospace)
- monospace (système)
- Aucune police cursive/handwriting

### 5.2 SVG manuscrits

**Existant** : ❌ NON
- Aucun SVG manuscrit identifié
- Seul SVG : bobodo_avatar.svg (avatar, pas texte)
- Aucun générateur de SVG

### 5.3 Moteurs de dessin de texte

**Existant** : ❌ NON
- Aucun moteur de dessin de texte identifié
- Aucun composant de conversion texte → image
- Aucun composant de conversion texte → SVG

### 5.4 Bibliothèques réutilisables

**Existant** : ❌ NON
- Aucune bibliothèque de génération manuscrite
- Aucun package flutter pour handwriting
- Aucun service backend pour génération manuscrite

### 5.5 Réponse à la question

**Existe-t-il déjà dans le projet des composants pour convertir automatiquement du texte en écriture manuscrite ?**

**Réponse** : ❌ NON

**Justification** :
- Aucune police manuscrite
- Aucun SVG manuscrit
- Aucun moteur de dessin de texte
- Aucune bibliothèque réutilisable

**Nécessité** : Développement complet
- Intégration d'une police manuscrite
- Développement d'un moteur de dessin de texte
- Ou utilisation d'un service externe (ex: Google Fonts, Calligraphr)

---

## PHASE 6 – ARCHITECTURE CIBLE

### 6.1 Architecture proposée

```
Bobodo
↓
Storyboard JSON
↓
Whiteboard Renderer
↓
Kamatera
↓
MP4
```

### 6.2 Analyse composant par composant

#### 6.2.1 Bobodo

**État actuel** : ✅ DISPONIBLE
- Bobodo chat existe et fonctionne
- Edge Function `bobodo-chat` déployée
- OpenRouter pour génération
- Système de crédits intégré

**Capacité à générer storyboard JSON** : ❌ NON
- Bobodo génère du texte, pas de JSON structuré
- Pas de prompt pour générer storyboard
- Pas de format storyboard défini

**Nécessite** : Développement complet
- Définir format storyboard JSON
- Créer prompt Bobodo pour génération storyboard
- Valider et parser le JSON généré

**Estimation** : Développement majeur

#### 6.2.2 Storyboard JSON

**État actuel** : ⚠️ PARTIEL
- Timeline JSON existe (TV PRO)
- Structure similaire mais orientation différente
- tv_pro_filter_builder.py peut lire du JSON

**Capacité à être utilisé comme storyboard** : ⚠️ PARTIEL
- Structure JSON existe
- Mais orientation temporelle, pas sémantique
- Nécessite adaptation pour storyboard pédagogique

**Nécessite** : Adaptation moyenne
- Définir format storyboard pédagogique
- Adapter tv_pro_filter_builder.py
- Créer mapper storyboard → timeline

**Estimation** : Adaptation moyenne

#### 6.2.3 Whiteboard Renderer

**État actuel** : ❌ NON
- Aucun moteur de whiteboard renderer
- CustomPainter existe mais statique
- Aucune animation de tracé

**Capacité à générer des animations** : ❌ NON
- Pas d'animation de tracé
- Pas d'écriture progressive
- Pas de génération de keyframes

**Nécessite** : Développement majeur
- Composant d'animation de tracé
- Algorithme de génération de keyframes
- Système de timestamp par point
- Génération de vidéo source

**Estimation** : Développement majeur

#### 6.2.4 Kamatera

**État actuel** : ✅ DISPONIBLE
- FFmpeg installé
- Backend Python existe
- tv_pro_filter_builder.py existe

**Capacité à rendre** : ✅ OUI (avec adaptation)
- FFmpeg peut rendre
- tv_pro_filter_builder.py peut générer des filtres
- Mais nécessite une vidéo source

**Nécessite** : Adaptation légère + déploiement
- Déployer backend sur Kamatera
- Adapter tv_pro_filter_builder.py pour storyboard
- Activer FFmpeg sur Kamatera

**Estimation** : Adaptation légère

### 6.3 Faisabilité globale

**Architecture proposée réalisable ?** : ❌ NON dans l'état actuel

**Blocages critiques** :
1. **Bobodo ne génère pas de storyboard JSON** - Développement majeur
2. **Pas de Whiteboard Renderer** - Développement majeur
3. **Pas de génération de vidéo source** - Développement majeur
4. **Pas d'animation de tracé** - Développement majeur
5. **Transcription mot par mot non prouvée** - Audit + développement
6. **Pas de génération manuscrite** - Développement majeur

**Pourcentage de réutilisation estimé** : ~15%

| Composant | Réutilisation | Adaptation | Nouveau |
|-----------|---------------|------------|---------|
| Bobodo | 10% (texte) | - | 90% (storyboard) |
| Storyboard JSON | 30% (structure) | 40% (format) | 30% (nouveau) |
| Whiteboard Renderer | 0% | - | 100% |
| Kamatera/FFmpeg | 50% (backend) | 30% (déploiement) | 20% (adaptation) |

### 6.4 Pour chaque composant

| Composant | Statut | Effort |
|-----------|--------|--------|
| Bobodo | Réutilisable immédiatement | - |
| Storyboard JSON | Adaptation légère | Moyen |
| Whiteboard Renderer | Développement majeur | Majeur |
| Kamatera | Adaptation légère | Léger |

---

## LIVRABLE FINAL

### 1. Capacités réelles du moteur vidéo actuel

**Moteur** : studio_video_renderer.py + tv_pro_filter_builder.py

**Capacités** :
- ✅ Transcodage multi-résolution (main, 480p, 360p, 240p)
- ✅ Lecture de timeline JSON
- ✅ Application d'overlays (text, image, video, pip)
- ✅ Support keyframes (position, scale, rotate, opacity)
- ✅ Animations prédéfinies (slide, fade)
- ✅ Upload Supabase Storage

**Limites** :
- ❌ Nécessite une vidéo source en entrée
- ❌ Pas de génération de contenu
- ❌ Pas de création de scènes
- ❌ Pas de génération automatique de keyframes

**Conclusion** : Moteur de **transformation**, pas de **génération**.

### 2. Capacités réelles de la Timeline actuelle

**Structure** : Timeline JSON TV PRO

**Capacités** :
- ✅ Structure JSON structurée
- ✅ Liste d'overlays
- ✅ Types d'overlays (text, image, video, pip)
- ✅ Visibilité temporelle (start_at_seconds, end_at_seconds)
- ✅ Positionnement flexible (x, y, align)
- ✅ Keyframes
- ✅ Animations prédéfinies

**Limites** :
- ❌ Orientation temporelle, pas sémantique
- ❌ Pas de système de scènes
- ❌ Pas de système de couches
- ❌ Génération manuelle des keyframes

**Conclusion** : Structure réutilisable mais nécessite adaptation pour storyboard pédagogique.

### 3. Capacités réelles de génération d'animations

**Moteurs existants** :
- ✅ CustomPainter (dessin statique)
- ✅ Canvas (dessin statique)
- ✅ animate_do (UI animations)
- ✅ perfect_freehand (dessin lissé)

**Limites** :
- ❌ Pas d'animation de tracé
- ❌ Pas d'écriture progressive
- ❌ Pas d'animation par caractère
- ❌ Pas de rejouer des tracés
- ❌ Pas de Rive/Lottie

**Conclusion** : Aucun moteur d'animation de tracé disponible.

### 4. Capacités réelles du système audio

**Services existants** :
- ✅ BobodoVocalService (WebSocket vocal)
- ✅ StudioAudioService (mixage audio)
- ✅ LiveKit (streaming)
- ✅ Service ASR externe (transcription)

**Limites** :
- ❌ Format transcription non documenté
- ❌ Pas de preuve de timestamps mot par mot
- ❌ Pas de synchronisation contenu-animations
- ❌ Service ASR externe non audité

**Conclusion** : Transcription existe mais format incertain, synchronisation non disponible.

### 5. Faisabilité du Storyboard Engine

**Conclusion** : ❌ NON FAISABLE dans l'état actuel

**Blocages** :
1. Bobodo ne génère pas de storyboard JSON
2. Format storyboard non défini
3. Pas de mapper storyboard → timeline
4. Pas de génération de contenu depuis storyboard

**Estimation** : 2-3 mois de développement

### 6. Faisabilité du Whiteboard Renderer

**Conclusion** : ❌ NON FAISABLE dans l'état actuel

**Blocages** :
1. Pas de moteur de whiteboard renderer
2. Pas d'animation de tracé
3. Pas d'écriture progressive
4. Pas de génération de vidéo source
5. Pas de génération manuscrite

**Estimation** : 3-4 mois de développement

### 7. Faisabilité du Smart Timeline Engine

**Conclusion** : ❌ NON FAISABLE dans l'état actuel

**Blocages** :
1. Transcription mot par mot non prouvée
2. Pas de synchronisation contenu-animations
3. Pas de système de déclenchement automatique
4. Pas de mapping transcription → keyframes

**Estimation** : 2-3 mois de développement

### 8. Estimation réaliste de développement

| Composant | Estimation | Complexité |
|-----------|------------|------------|
| Storyboard Engine (Bobodo) | 1-1.5 mois | Haute |
| Whiteboard Renderer | 2-2.5 mois | Très haute |
| Smart Timeline Engine | 1.5-2 mois | Haute |
| Transcription mot par mot | 0.5-1 mois | Moyenne |
| Génération manuscrite | 1-1.5 mois | Haute |
| Intégration Kamatera | 0.5 mois | Moyenne |
| **Total** | **6-8 mois** | **Très haute** |

### 9. Recommandation d'architecture

**Approche recommandée** : Ne PAS construire from scratch

**Raison** :
- Trop de composants manquants
- Complexité très élevée
- Temps de développement très long (6-8 mois)
- Risque technique élevé

**Alternative recommandée** : Utiliser une solution SaaS existante

**Solutions possibles** :
1. **Loom** : Enregistrement d'écran avec webcam, transcription intégrée
2. **Descript** : Transcription mot par mot, édition vidéo basée sur texte
3. **Canva** : Templates vidéo pédagogiques, animations prêtes
4. **Vyond** : Animation vidéo professionnelle, templates éducatifs

**Intégration** :
- Utiliser l'API de la solution SaaS
- Intégrer dans le workflow Academia
- Stocker les vidéos dans Supabase Storage
- Afficher dans l'interface Flutter

**Avantages** :
- Temps de développement réduit (1-2 mois)
- Fonctionnalités matures
- Maintenance réduite
- Risque technique faible

### 10. Liste précise des briques déjà présentes dans Academia

| Brique | Statut | Utilité pour Smart Whiteboard |
|--------|--------|-----------------------------|
| Kamatera (VPS) | ✅ Opérationnel | Hébergement backend |
| LiveKit | ✅ Opérationnel | Streaming (non utilisé pour rendu) |
| FFmpeg | ✅ Installé | Transcodage |
| studio_video_renderer.py | ✅ Existe | Transcodage (non génération) |
| tv_pro_filter_builder.py | ✅ Existe | Interprétation timeline JSON |
| Timeline JSON | ✅ Existe | Structure de base |
| Bobodo | ✅ Existe | Génération texte (non storyboard) |
| OpenRouter | ✅ Existe | Génération IA |
| CustomPainter | ✅ Existe | Dessin statique |
| Canvas | ✅ Existe | Dessin statique |
| perfect_freehand | ✅ Existe | Dessin lissé |
| flutter_math_fork | ✅ Existe | Rendu LaTeX |
| animate_do | ✅ Existe | UI animations |
| flutter_svg | ✅ Existe | Rendu SVG |
| flutter_tts | ✅ Existe | Synthèse vocale |
| speech_to_text | ✅ Existe | Transcription locale |
| Service ASR externe | ⚠️ Existe | Transcription (format incertain) |

**Total** : 16 briques existantes, mais aucune ne permet de générer des vidéos pédagogiques automatiquement.

---

## CONCLUSION

Le Storyboard Engine, le Whiteboard Renderer et le Smart Timeline Engine ne sont **PAS faisables** dans l'état actuel de l'infrastructure Academia. Bien que des briques existent (FFmpeg, timeline JSON, Bobodo), elles sont orientées **transformation** et non **génération**.

**Recommandation forte** : Utiliser une solution SaaS existante (Loom, Descript, Canva, Vyond) plutôt que de développer from scratch. Le temps de développement estimé (6-8 mois) et la complexité technique très élevée ne justifient pas l'approche from scratch pour une fonctionnalité qui existe déjà sur le marché.

**Si développement from scratch est impératif** : Suivre une approche incrémentale en commençant par la transcription mot par mot (Whisper local) et le Storyboard Engine (Bobodo), puis le Whiteboard Renderer, et enfin le Smart Timeline Engine.
