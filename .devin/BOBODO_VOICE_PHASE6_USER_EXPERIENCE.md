# BOBODO VOCAL - PHASE 6 : EXPÉRIENCE UTILISATEUR

**Date** : 10 juin 2026  
**Statut** : ✅ TERMINÉ

---

## PARCOURS UTILISATEUR COMPLET

### Étape 1 : Accès à Bobodo Vocal

**UI Flutter** :
- Onglet Bobodo existant
- Nouveau bouton "Mode Vocal" (icône microphone)
- Toggle entre mode texte et mode vocal
- Animation de transition fluide

**Déclenchement** :
- Tap sur bouton microphone
- Demande permission microphone (Android)
- État visuel : microphone actif (pulsation)

---

### Étape 2 : Capture Audio

**UI Flutter** :
- Animation d'onde sonore (visualisation audio)
- Timer d'enregistrement (max 30s)
- Bouton "Arrêter" (icône carré)
- Bouton "Annuler" (icône croix)

**Comportement** :
- Capture audio en temps réel
- Streaming vers WebSocket
- Visualisation amplitude audio
- Feedback visuel (enregistrement en cours)

**Gestion erreurs** :
- Permission refusée : message explicite + redirection settings
- Microphone indisponible : message d'erreur
- Connexion WebSocket échouée : retry automatique (3 tentatives)

---

### Étape 3 : Traitement Audio (STT)

**Backend** :
- Réception audio via WebSocket
- Faster-Whisper transcription
- Temps réel : affichage texte progressif
- Latence : 1-2s

**UI Flutter** :
- Animation "Bobodo écoute..."
- Affichage texte transcrit en temps réel
- Feedback visuel (traitement en cours)

**Gestion erreurs** :
- Transcription échouée : message "Je n'ai pas compris, peux-tu répéter ?"
- Timeout : message "Délai dépassé, réessaie"

---

### Étape 4 : Génération Réponse (LLM)

**Backend** :
- Envoi texte à Edge Function bobodo-chat
- RAG vectoriel + historique
- OpenRouter LLM
- Temps : 2-5s

**UI Flutter** :
- Animation "Bobodo réfléchit..."
- Affichage réponse texte en temps réel (streaming)
- Feedback visuel (génération en cours)

**Gestion erreurs** :
- LLM échoué : message "Désolé, j'ai un problème technique. Réessaie plus tard."
- Timeout : message "Réponse trop longue, reformule ta question"

---

### Étape 5 : Synthèse Audio (TTS)

**Backend** :
- Réception texte réponse
- Piper TTS synthèse
- Streaming audio via WebSocket
- Temps : 1-2s

**UI Flutter** :
- Animation "Bobodo parle..."
- Visualisation onde sonore (playback)
- Bouton "Arrêter" (icône carré)
- Bouton "Mode silencieux" (icône haut-parleur barré)

**Gestion erreurs** :
- TTS échoué : fallback affichage texte uniquement
- Audio corrompu : message "Problème audio, réponse affichée en texte"

---

### Étape 6 : Mode Silencieux

**UI Flutter** :
- Toggle "Mode silencieux" (icône haut-parleur barré)
- Désactive TTS
- Affiche uniquement texte réponse
- Persistance préférence utilisateur

**Comportement** :
- Si activé : pas de synthèse audio
- Si désactivé : synthèse audio activée
- Par défaut : activé (vocal)

---

### Étape 7 : Conversation Continue

**UI Flutter** :
- Bouton microphone toujours visible
- Historique conversation (texte + audio)
- Possibilité de relancer audio
- Mode mixte (texte + vocal)

**Comportement** :
- Utilisateur peut alterner texte/vocal
- Historique conservé (comme mode texte)
- Contexte conversationnel maintenu

---

## DÉTAILS UI FLUTTER

### Écran Bobodo (modifié)

**Nouveaux composants** :
1. **Bouton microphone** (FloatingActionButton)
   - Position : bas droite
   - Icône : microphone
   - Animation : pulsation quand actif

2. **Visualisation audio** (CustomPainter)
   - Onde sonore animée
   - Amplitude temps réel
   - Couleur : bleu Academia

3. **Animation Bobodo**
   - "Écoute..." : icône oreille
   - "Réfléchit..." : icône cerveau
   - "Parle..." : icône haut-parleur

4. **Mode silencieux** (IconButton)
   - Position : haut droite
   - Icône : haut-parleur barré
   - Toggle on/off

5. **Boutons contrôle**
   - "Arrêter" : icône carré
   - "Annuler" : icône croix
   - Position : centre (quand actif)

### Flux audio

**Capture** :
- Package : `flutter_sound` ou `record`
- Format : WAV (16kHz, mono)
- Streaming : WebSocket

**Playback** :
- Package : `just_audio` ou `flutter_sound`
- Format : WAV/MP3
- Streaming : WebSocket

---

## GESTION ERREURS

### Erreurs microphone

**Permission refusée** :
```
"Bobodo a besoin d'accéder à ton microphone pour le mode vocal.
Active la permission dans les paramètres de ton appareil."
```
- Bouton : "Paramètres" (ouvre settings)

**Microphone indisponible** :
```
"Microphone indisponible. Vérifie que ton appareil a un microphone fonctionnel."
```

### Erreurs connexion

**WebSocket échoué** :
```
"Connexion au serveur vocal échouée. Vérifie ta connexion internet."
```
- Retry automatique (3 tentatives)
- Bouton : "Réessayer"

**Timeout** :
```
"Délai de connexion dépassé. Réessaie plus tard."
```

### Erreurs transcription

**Transcription échouée** :
```
"Je n'ai pas compris ce que tu as dit. Peux-tu répéter ?"
```

**Audio trop court** :
```
"Ton message est trop court. Parle un peu plus longtemps."
```

### Erreurs LLM

**LLM échoué** :
```
"Désolé, j'ai un problème technique. Réessaie plus tard."
```

**Timeout** :
```
"Ta question est trop complexe. Reformule-la plus simplement."
```

### Erreurs TTS

**TTS échoué** :
```
"Problème audio. La réponse s'affiche en texte."
```
- Fallback : affichage texte uniquement

---

## ACCESSIBILITÉ

### Utilisateurs malentendants

**Mode silencieux** :
- Activé par défaut pour malentendants
- Texte uniquement
- Vibrations pour notifications

### Utilisateurs non-voyants

**Vocal uniquement** :
- TTS activé par défaut
- Navigation vocale
- Feedback audio

---

## PERFORMANCE

### Latence cible

- Capture → STT : 1-2s
- STT → LLM : 0.5s
- LLM → TTS : 1-2s
- **Total** : 2.5-4.5s

### Performance acceptable

- **Optimal** : < 3s
- **Acceptable** : 3-5s
- **Limite** : > 5s (message d'attente)

---

## COMPLÉMENTS

### Animations

- Microphone : pulsation (1s cycle)
- Audio : onde sonore (temps réel)
- Bobodo : icônes dynamiques
- Transition : fade in/out (300ms)

### Feedback visuel

- Vert : succès
- Rouge : erreur
- Jaune : en cours
- Bleu : Academia brand

### Sons

- Start : bip doux
- Stop : bip doux
- Error : son d'erreur
- Success : son de succès

---

**RAPPORT PHASE 6 TERMINÉ**
