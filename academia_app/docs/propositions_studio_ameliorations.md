# Propositions Ameliorations — Studio Video Academia
## 21 Mars 2026 — Benchmark TikTok / YouTube / Instagram / CapCut

---

## MATRICE COMPARATIVE : Academia vs Leaders

| Fonctionnalite | TikTok | YouTube Shorts | Instagram Reels | CapCut | **Academia** |
|----------------|--------|----------------|-----------------|--------|-------------|
| Filtres couleur live | 50+ | 10+ | 30+ | 100+ | **6** (Normal,Chaud,Froid,N&B,Sepia,Vif) |
| Timer countdown | 3s,10s | Non | 3s,10s | 3s,10s | **off,3s,5s,10s** OK |
| Multi-segments | Oui | Oui | Oui | Oui | **Code mais non fusionne** |
| Flash/torche | Oui | Oui | Oui | Oui | **OK** |
| Switch cam | Oui | Oui | Oui | Oui | **OK** |
| Vitesse capture | 0.3-3x | 0.5-2x | 0.5-3x | 0.1-100x | **0.5-3x** OK |
| Speed ramp (courbe) | Oui | Non | Non | Oui | **Non** |
| Trim/crop/rotate | Oui | Oui | Oui | Oui | **OK** (CapCut screen) |
| Transitions entre clips | 50+ | 5 | 10+ | 200+ | **Non** |
| Templates predefinis | 1000+ | Non | 100+ | 10000+ | **Non** |
| Green screen/Chroma key | Oui | Non | Oui | Oui | **Non** |
| Background removal IA | Oui | Non | Non | Oui | **Non** |
| Texte anime | 20+ styles | 5 | 10+ | 50+ | **Basique** (statique) |
| Text-to-speech IA | 10+ voix | Non | Non | 20+ voix | **Non** |
| Auto-captions IA | Oui | Oui | Oui | Oui | **Non** |
| Sous-titres manuels | Oui | Oui | Oui | Oui | **OK** (champ texte) |
| Musique/sons bibliotheque | 500K+ | YouTube Music | 10K+ | 500K+ | **Table challenge_video_assets** |
| Voiceover enregistrement | Oui | Oui | Oui | Oui | **Non** |
| Voice effects (robot,echo) | 10+ | Non | Non | 20+ | **Non** |
| Beauty mode/filtre visage | Oui | Non | Oui | Oui | **Non** |
| Stickers animes | 1000+ | Non | 500+ | 5000+ | **Basique** (star,heart,idea) |
| Emoji animes | Oui | Oui | Oui | Oui | **Non** |
| GIF integration | Oui via GIPHY | Non | Oui via GIPHY | Oui | **Non** |
| Keyframe animation | Non | Non | Non | Oui | **Non** |
| PIP (Picture-in-Picture) | Oui | Non | Non | Oui | **Non** |
| Motion tracking overlays | Non | Non | Non | Oui | **Non** |
| Duet (side-by-side) | Oui | Collab | Remix | Non | **Duo Live OK** (pas video) |
| Stitch (clip+reponse) | Oui | Remix | Remix | Non | **Non** |
| Q&A stickers interactifs | Non | Oui | Oui | Non | **Non** |
| Sondage dans video | Non | Non | Oui | Non | **Non** |
| Whiteboard/dessin | Non | Non | Non | Non | **OK** (Scientific Studio) |
| LaTeX/equations | Non | Non | Non | Non | **OK** (unique!) |
| AR 3D objets | Oui (effets) | Non | Oui (effets) | Non | **OK** |
| Export watermarke | Oui | Non | Oui | Non | **OK** (sur demande) |
| Transcoding serveur multi-res | Oui (auto) | Oui (auto) | Oui (auto) | Cloud | **Non** (original seul) |
| HLS adaptive bitrate | Oui | Oui | Oui | Non | **Non** |
| Upload resume/chunk | Oui | Oui | Oui | Non | **Non** |

---

## PROPOSITIONS CONCRETES — Classees par IMPACT x FAISABILITE

### TIER 1 — Impact ENORME, Faisable maintenant (VPS FFmpeg disponible)

#### P1. Fusion multi-segments + transitions
**Gap** : Camera capture multi-segments mais seul le 1er est utilise
**Cible** : TikTok, CapCut
**Implementation** :
- FFmpeg `concat` sur le VPS pour fusionner les segments
- Ajouter 5 transitions basiques entre clips : fade, slide, zoom, dissolve, wipe
- Edge Function `merge-video-segments` qui recoit les URLs segments + transition type
- Retourne l'URL du fichier fusionne
**Effort** : 4-6h | **Impact UX** : TRES ELEVE

#### P2. Auto-captions IA (sous-titres automatiques)
**Gap** : Pas de transcription automatique
**Cible** : TikTok, YouTube, Instagram, CapCut (tous l'ont)
**Implementation** :
- Edge Function `transcribe-video` utilisant OpenRouter/Whisper API (ou Whisper.cpp local sur VPS)
- Envoie l'audio extrait via FFmpeg sur VPS → transcription → retourne SRT/JSON timecodes
- Afficher les sous-titres dans le Studio, editables par l'utilisateur
- Style de sous-titres : classique, highlight mot par mot (style CapCut), karaoke
**Effort** : 6-8h | **Impact UX** : ENORME (accessibilite + viralite)

#### P3. Transcoding multi-resolution serveur (HLS)
**Gap** : Seule la resolution "original" est disponible
**Cible** : YouTube, TikTok, Instagram (tous font ca automatiquement)
**Implementation** :
- Job FFmpeg sur le VPS apres upload : generer 3 renditions (1080p, 720p, 480p)
- Generer playlist HLS (.m3u8) avec adaptive bitrate
- Stocker les segments dans Supabase Storage bucket `video-assets`
- Mettre a jour `video_renditions` table avec les 3 entrees
- Le player choisit automatiquement la qualite selon le reseau
**Effort** : 6-8h | **Impact UX** : CRITIQUE (qualite lecture Afrique = reseau variable)

#### P4. Text-to-Speech IA (voix off automatique)
**Gap** : Pas de voix off automatique
**Cible** : TikTok (10+ voix), CapCut (20+ voix)
**Implementation** :
- Edge Function `text-to-speech` via OpenRouter (ou ElevenLabs/Google TTS)
- L'etudiant tape un texte → choisit une voix → genere l'audio
- FFmpeg sur VPS merge l'audio TTS avec la video
- Voix en francais + anglais + langues locales (moore, dioula)
**Effort** : 4-5h | **Impact UX** : ELEVE (education + accessibilite)

---

### TIER 2 — Impact ELEVE, Effort modere

#### P5. Texte anime (apparition lettre par lettre, bounce, typewriter)
**Gap** : Texte statique uniquement
**Cible** : TikTok (20+ styles), CapCut (50+ styles)
**Implementation** :
- 8 animations texte : typewriter, bounce, fade-in, slide-up, scale, wave, glow, shake
- Implemente cote Flutter avec AnimationController sur les overlays texte
- Stocker animation_type dans le JSON overlays existant
- Rendu cote client (pas besoin de serveur)
**Effort** : 4-5h | **Impact UX** : ELEVE

#### P6. Voiceover (enregistrement voix off)
**Gap** : Pas possible d'enregistrer une narration sur la video
**Cible** : TikTok, Instagram, InShot, CapCut
**Implementation** :
- Bouton "Voix off" dans le Studio → ouvre un enregistreur audio
- Package `record` pour capture micro
- Ajout comme piste audio dans le timeline (AudioMixService deja en place)
- FFmpeg merge voiceover + video originale
**Effort** : 3-4h | **Impact UX** : ELEVE

#### P7. Voice effects (robot, echo, chipmunk, grave)
**Gap** : Pas d'effets vocaux
**Cible** : TikTok (10+ effets), CapCut (20+)
**Implementation** :
- FFmpeg filtres audio : `aecho`, `asetrate` (chipmunk/grave), `flanger` (robot)
- 6 presets : Normal, Robot, Echo, Chipmunk, Grave, Radio
- Traitement sur VPS via Edge Function `voice-effect`
- Preview en temps reel cote Flutter avec `audio_session`
**Effort** : 3-4h | **Impact UX** : MOYEN-ELEVE

#### P8. Green screen / Background removal
**Gap** : Pas de fond vert ni suppression arriere-plan
**Cible** : TikTok, Instagram, CapCut
**Implementation** :
- Option A (simple) : Chroma key avec slider tolerance (Flutter `ColorFiltered`)
- Option B (IA) : FFmpeg + modele segmentation sur VPS (mediapipe/rembg)
- Bibliotheque de fonds : universite, tableau noir, nature, abstrait, couleur unie
- L'utilisateur choisit son fond apres capture
**Effort** : 5-7h | **Impact UX** : ELEVE

#### P9. Upload resume/chunk (gros fichiers)
**Gap** : Upload en un seul bloc (echoue souvent sur reseau africain)
**Cible** : YouTube, TikTok (upload robuste)
**Implementation** :
- Tus protocol (resumable uploads) via Edge Function
- Decouper le fichier en chunks de 2MB
- Resume automatique si connexion coupee
- Barre de progression fiable
**Effort** : 4-5h | **Impact UX** : CRITIQUE pour l'Afrique de l'Ouest

---

### TIER 3 — Impact MOYEN, Differenciation Academia

#### P10. Templates video predefinis
**Gap** : Pas de templates
**Cible** : CapCut (10 000+), Instagram (100+), TikTok (1000+)
**Implementation** :
- 20 templates Education : presentation cours, quiz interactif, resume, experience labo
- Format JSON : positions texte/stickers/timing pre-configures
- Table `video_templates` dans Supabase
- L'etudiant choisit un template → les zones sont pre-remplies
**Effort** : 6-8h | **Impact UX** : MOYEN

#### P11. Stitch (clip + ma reponse)
**Gap** : Pas de stitch
**Cible** : TikTok Stitch, YouTube Remix
**Implementation** :
- Bouton "Repondre" sur une video du feed
- Ouvre la camera avec les 3 premieres secondes de la video originale en intro
- FFmpeg concat sur VPS : intro + nouveau clip
- Lien vers la video originale dans les metadonnees
**Effort** : 4-5h | **Impact UX** : MOYEN (viralite + engagement)

#### P12. Duet video (pas juste live)
**Gap** : Duo existe en live mais pas en video pre-enregistree
**Cible** : TikTok Duet, YouTube Collab
**Implementation** :
- Bouton "Duet" sur une video du feed
- Ouvre la camera en split-screen (original a gauche, camera a droite)
- FFmpeg `hstack` sur VPS pour fusionner les 2 videos
- Stocker parent_participation_id (deja en place)
**Effort** : 5-6h | **Impact UX** : MOYEN

#### P13. Beauty mode / Filtre visage
**Gap** : Pas de beautification
**Cible** : TikTok, Instagram, CapCut
**Implementation** :
- Package `google_mlkit_face_detection` pour detection visage
- Filtres : lissage peau, agrandissement yeux, blanchiment dents, contour
- Applique en temps reel sur le preview camera (shader custom)
**Effort** : 6-8h | **Impact UX** : MOYEN

#### P14. Speed ramp (courbe de vitesse)
**Gap** : Vitesse constante uniquement
**Cible** : CapCut, InShot
**Implementation** :
- UI : courbe Bezier draggable pour definir la vitesse par segment
- FFmpeg `setpts` avec expression variable sur VPS
- 5 presets : Montage, Bullet Time, Flash, Smooth In/Out, Custom
**Effort** : 4-5h | **Impact UX** : MOYEN

#### P15. PIP (Picture-in-Picture)
**Gap** : Pas de PIP
**Cible** : CapCut, InShot
**Implementation** :
- Overlay draggable d'une 2eme video/image par-dessus la principale
- Redimensionnable + repositionnable
- FFmpeg `overlay` sur VPS pour export final
**Effort** : 4-5h | **Impact UX** : MOYEN

---

## PLAN D'IMPLEMENTATION RECOMMANDE

### Sprint 1 (Semaine 1) — Fondations serveur + UX critique
| # | Proposition | Effort |
|---|------------|--------|
| P3 | Transcoding multi-resolution HLS | 6-8h |
| P9 | Upload resume/chunk | 4-5h |
| P1 | Fusion multi-segments + transitions | 4-6h |

**Resultat** : Upload fiable + videos en multi-qualite + segments fusionnes

### Sprint 2 (Semaine 2) — IA + Audio
| # | Proposition | Effort |
|---|------------|--------|
| P2 | Auto-captions IA | 6-8h |
| P4 | Text-to-Speech IA | 4-5h |
| P6 | Voiceover | 3-4h |
| P7 | Voice effects | 3-4h |

**Resultat** : Sous-titres auto + voix IA + narration + effets vocaux

### Sprint 3 (Semaine 3) — Visuel + Engagement
| # | Proposition | Effort |
|---|------------|--------|
| P5 | Texte anime | 4-5h |
| P8 | Green screen | 5-7h |
| P11 | Stitch | 4-5h |
| P12 | Duet video | 5-6h |

**Resultat** : Textes animes + fond vert + remix social

### Sprint 4 (Semaine 4) — Polish + Differenciation
| # | Proposition | Effort |
|---|------------|--------|
| P10 | Templates | 6-8h |
| P13 | Beauty mode | 6-8h |
| P14 | Speed ramp | 4-5h |
| P15 | PIP | 4-5h |

**Resultat** : Templates education + beautification + effets pro

---

## AVANTAGES CONCURRENTIELS UNIQUES D'ACADEMIA

Ces fonctionnalites n'existent chez AUCUN concurrent :

1. **Studio Scientifique** : whiteboard + LaTeX + annotations temporisees
2. **AR 3D objets** sur video educative
3. **Quiz en direct** pendant les lives
4. **Live Duo educatif** (prof + eleve split-screen)
5. **Systeme de challenges** gamifie avec points et badges
6. **Correction IA** (Edge Function prep-grade-assignment)
7. **Context educatif** : videos liees a des concours, des TD, des universites

**Recommandation** : Garder et enrichir ces differenciateurs tout en rattrapant le retard sur les features standards (auto-captions, transitions, TTS, HLS).
