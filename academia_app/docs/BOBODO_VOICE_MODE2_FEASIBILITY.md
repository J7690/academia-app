# BOBODO — Faisabilité du Mode 2 (Conversation Vocale Continue)

**Date**: 2025-06-15  
**Objectif**: Déterminer si le Mode 2 peut être ajouté par raccordement des composants existants sans casser le Mode 1

---

## CLARIFICATION DES DEUX MODES

| | Mode 1 (Dictée) | Mode 2 (Conversation) |
|---|---|---|
| **Déclencheur** | Micro zone de saisie | Micro header |
| **Flux** | Voix → texte dans champ → édition → envoi manuel → réponse texte | Voix → transcription → envoi auto → réponse Bobodo → réponse vocale → relance écoute |
| **Contrôle utilisateur** | L'utilisateur édite et valide | Mains libres, boucle continue |
| **Réponse** | Texte uniquement | Texte + vocale |
| **Statut actuel** | ✅ Fonctionnel | ❌ Non fonctionnel |

---

## MISSION 1 — INVENTAIRE PRÉCIS

### Ce qui est DÉJÀ PRÊT

| Composant | Localisation | Détail |
|-----------|-------------|--------|
| Bouton header micro | `student_bobodo_tab.dart:404-412` | Toggle _isConversationMode |
| Machine à états conversation | `student_bobodo_tab.dart:28-37` | Enum ConversationState (idle, listening, processing, thinking, responding, playing, paused, ended) |
| Indicateur d'état UI | `student_bobodo_tab.dart:1608-1673` | Barre colorée avec icône et texte selon l'état |
| Contrôles conversation | `student_bobodo_tab.dart:1675-1712` | Boutons Quitter, Couper, Rejouer, Reprendre |
| Masquage input bar | `student_bobodo_tab.dart:292-299` | Input bar cachée quand _isConversationMode |
| WebSocket client | `bobodo_vocal_service.dart:1-163` | Connexion, sendAudio(), reconnexion auto |
| WebSocket connecté au démarrage | `student_bobodo_tab.dart:1237-1265` | _connectVocalWebSocket() dans initState |
| Listener WebSocket | `student_bobodo_tab.dart:1255-1261` | _onVocalMessage écoute messageStream |
| Dispatch messages WS | `student_bobodo_tab.dart:1364-1377` | Route transcription, audio_response, error |
| Réception audio_response | `student_bobodo_tab.dart:1413-1454` | Décode base64 → audioPlayer |
| Lecture audio | `student_bobodo_tab.dart:1424-1435` | audioPlayer.setSourceBytes + resume |
| Relance écoute après lecture | `student_bobodo_tab.dart:1564-1571` | _onAudioPlaybackComplete → _startVocalRecording |
| Timer d'inactivité | `student_bobodo_tab.dart:1574-1584` | 30s timeout → idle |
| Barge-in | `student_bobodo_tab.dart:1381-1387` | Arrête lecture si utilisateur parle |
| Mémoire conversation | `student_bobodo_tab.dart:1586-1606` | 10 derniers échanges |
| FlutterTts initialisé | `student_bobodo_tab.dart:157-161` | fr-FR, vitesse 0.9 |
| _speakWithLocalTts() | `student_bobodo_tab.dart:1456-1469` | TTS local comme fallback |
| Serveur WebSocket (Kamatera) | `.windsurf/main_server.py` | FastAPI + /ws endpoint |
| Serveur STT (Whisper) | `.windsurf/stt_service_v3.py` | Whisper Small + dictionnaire |
| Serveur TTS (Edge-TTS) | `.windsurf/tts_service_edge.py` | Edge-TTS + fallback gTTS |
| Handler WebSocket serveur | `.windsurf/websocket_handler_v2.py:108-140` | audio → STT → Bobodo → TTS → audio_response |

### Ce qui est DÉJÀ IMPLÉMENTÉ et FONCTIONNEL

| Composant | Statut |
|-----------|--------|
| Mode 1 (Dictée vocale) | ✅ Fonctionne |
| STT natif Android (speech_to_text) | ✅ Fonctionne |
| Envoi texte via Edge Function | ✅ Fonctionne |
| Réception réponse Bobodo | ✅ Fonctionne |
| Affichage messages | ✅ Fonctionne |
| Auto-scroll | ✅ Fonctionne |
| Restauration historique | ✅ Fonctionne |

### Ce qui est INUTILISÉ

| Composant | Existe à | Jamais appelé car |
|-----------|----------|-------------------|
| `_vocalService.sendAudio()` | `bobodo_vocal_service.dart:122` | Aucun appel dans le code client |
| Pipeline serveur complet (audio → STT → Bobodo → TTS → retour) | `websocket_handler_v2.py:108-140` | Jamais d'audio envoyé au WebSocket |
| `_onAudioResponseReceived()` en contexte réel | `student_bobodo_tab.dart:1413` | Jamais déclenché car serveur ne reçoit jamais d'audio |
| Transitions d'état thinking→playing→listening | `student_bobodo_tab.dart:1418-1434,1564-1571` | Jamais atteintes |
| `FlutterSoundRecorder _recorder` | `student_bobodo_tab.dart:76` | Ouvert mais jamais utilisé pour capturer audio brut |

### Ce qui MANQUE RÉELLEMENT

| # | Manque | Description |
|---|--------|-------------|
| M1 | **Capture audio brut en mode conversation** | En mode 2, il faut capturer le PCM/WAV brut (pas seulement le texte STT natif) pour l'envoyer au WebSocket |
| M2 | **Appel à `_vocalService.sendAudio(audioBytes)`** | La liaison entre l'enregistrement et le WebSocket |
| M3 | **OU Alternative : TTS local après réponse texte** | Si on garde le STT natif, il faut synthétiser vocalement la réponse texte reçue de l'Edge Function |

---

## MISSION 2 — RACCORDEMENT OU DÉVELOPPEMENT ?

### Réponse : **A) — Raccordement simple**

Deux stratégies possibles, chacune étant un raccordement de composants existants :

#### Stratégie 1 : Pipeline WebSocket complet (serveur fait tout)

```
Ce qui existe déjà    →  Ce qu'il faut raccorder
─────────────────────────────────────────────────
FlutterSoundRecorder  →  Capturer audio brut (PCM)
_vocalService         →  sendAudio(audioBytes)
Serveur WebSocket     →  Reçoit audio → STT → Bobodo → TTS → audio_response
_onVocalMessage()     →  Dispatche audio_response
_onAudioResponseReceived() → Joue audio
_onAudioPlaybackComplete() → Relance écoute
```

**Manque** : La capture audio brut + l'appel `sendAudio()`. Tout le reste est en place.

#### Stratégie 2 : STT natif + TTS local (tout côté client)

```
Ce qui existe déjà    →  Ce qu'il faut raccorder
─────────────────────────────────────────────────
_speechToText         →  Transcription (déjà fonctionnel)
provider.sendUserMessage() → Envoi texte (déjà fonctionnel)
loadMessages()        →  Réponse texte disponible (déjà fonctionnel)
_speakWithLocalTts()  →  Lire la réponse vocalement (EXISTE, non appelé)
_onAudioPlaybackComplete() → Relancer écoute (EXISTE, non atteint)
```

**Manque** : Après `loadMessages()` en mode conversation, extraire la dernière réponse Bobodo et appeler `_speakWithLocalTts(text)` → puis à la fin de la lecture, appeler `_onAudioPlaybackComplete()`.

#### Comparaison des deux stratégies

| Critère | Stratégie 1 (WebSocket) | Stratégie 2 (Local) |
|---------|------------------------|---------------------|
| Lignes de code à ajouter | ~20-30 | ~10-15 |
| Dépendance réseau | Serveur Kamatera requis | Pas de dépendance supplémentaire |
| Qualité STT | Whisper Small (meilleur) | STT natif Android (variable) |
| Qualité TTS | Edge-TTS Neural (excellent) | FlutterTts (correct) |
| Latence | Plus élevée (réseau aller-retour) | Plus faible (tout local sauf Edge Function) |
| Complexité | Capture audio brut + format WAV | Simple appel de méthode existante |
| Mode 1 impacté ? | Non | Non |

**Recommandation technique** : La Stratégie 2 est le raccordement le plus simple — environ 10-15 lignes de code. La Stratégie 1 offre une meilleure qualité mais nécessite plus de travail (capture PCM, format WAV).

---

## MISSION 3 — TABLEAU DE CONFORMITÉ PAR COMPOSANT

| Composant | Existe | Utilisé (Mode 1) | Utilisé (Mode 2) | Manquant pour Mode 2 |
|-----------|--------|-------------------|-------------------|---------------------|
| **UI Flutter — Bouton micro header** | ✅ | — | ✅ Active le mode | Rien |
| **UI Flutter — Indicateur d'état** | ✅ | — | ✅ Affiché | Rien |
| **UI Flutter — Contrôles (quitter/couper/reprendre)** | ✅ | — | ✅ Affichés | Rien |
| **UI Flutter — Masquage input bar** | ✅ | — | ✅ Input bar cachée | Rien |
| **BobodoVocalService — Connexion** | ✅ | — | ✅ Connecté au démarrage | Rien |
| **BobodoVocalService — sendAudio()** | ✅ | ❌ | ❌ Jamais appelé | **Appel manquant** (Stratégie 1 seulement) |
| **BobodoVocalService — messageStream** | ✅ | — | ✅ Listener en place | Rien |
| **WebSocket serveur — Réception audio** | ✅ | — | ❌ Jamais reçu | **Envoi côté client** (Stratégie 1 seulement) |
| **WebSocket serveur — Pipeline complet** | ✅ | — | ❌ Jamais activé | **Envoi côté client** (Stratégie 1 seulement) |
| **STT — speech_to_text natif** | ✅ | ✅ Dictée | ✅ Transcription | Rien |
| **STT — Whisper (serveur)** | ✅ | ❌ | ❌ Jamais activé | **Audio brut nécessaire** (Stratégie 1 seulement) |
| **TTS — FlutterTts (local)** | ✅ | ❌ | ❌ Jamais appelé dans le flux | **Appel après réponse texte** (Stratégie 2) |
| **TTS — Edge-TTS (serveur)** | ✅ | ❌ | ❌ Jamais activé | **Dépend de Stratégie 1** |
| **Audio Player** | ✅ | ❌ | ❌ Jamais joué | **Déclenché automatiquement par TTS** |
| **Conversation Loop (_onAudioPlaybackComplete)** | ✅ | — | ❌ Jamais atteint | **Liaison TTS → playback → relance** |
| **États UI (ConversationState)** | ✅ | — | ❌ Bloqué sur thinking | **Transitions après réponse** |
| **Indicateurs utilisateur** | ✅ | — | ✅ Affichés correctement | **Mise à jour après réponse vocale** |

---

## MISSION 4 — QUEL BOUTON POUR LE MODE 2 ?

### Ce que fait actuellement le micro du header

| Attribut | Valeur actuelle |
|----------|----------------|
| Widget | `IconButton` ligne 404 |
| Icône inactive | `Icons.mic_none` (blanc) |
| Icône active | `Icons.mic` (PrepTheme.primary) |
| Tooltip inactif | "Mode Dictée" |
| Tooltip actif | "Mode Conversation" |
| Action | `_toggleVoiceMode()` |
| Effet | Active `_isConversationMode` → cache l'input bar → affiche indicateur + contrôles → démarre écoute |

### Ce qu'il DEVRAIT faire (pour le Mode 2)

Exactement ce qu'il fait déjà en termes d'UI. Le bouton est correctement conçu pour activer le Mode 2.

La seule différence : au lieu de s'arrêter après l'envoi texte (état bloqué sur "thinking"), il devrait continuer vers la lecture vocale puis la relance d'écoute.

### Ce bouton est-il le bon candidat ?

**OUI.**

**Raisons** :

1. Il est déjà associé au concept "Mode Conversation" (tooltip)
2. Il active déjà `_isConversationMode` qui contrôle toute la logique
3. Il cache déjà l'input bar (pas besoin d'éditer le texte en mode conversation)
4. Il affiche déjà l'indicateur d'état et les contrôles
5. Il est visuellement distinct du micro de dictée (zone saisie)
6. L'utilisateur comprend naturellement : micro en bas = dictée, micro en haut = conversation

### Séparation claire des deux modes

```
MICRO BAS (zone de saisie) = MODE 1
  → Démarre speech_to_text natif
  → Place texte dans le champ
  → Utilisateur édite et envoie
  → Input bar reste visible
  → Pas de réponse vocale

MICRO HAUT (header) = MODE 2
  → Active le mode conversation
  → Cache l'input bar
  → Affiche indicateur d'état + contrôles
  → Voix → transcription → envoi auto → réponse vocale → boucle
  → Comparable à ChatGPT Voice
```

**Cette séparation est déjà implémentée dans l'UI.** Seul le flux audio/TTS est manquant dans le Mode 2.

---

## CONCLUSION

### Le Mode 2 peut être obtenu par raccordement simple

**Réponse : A — Raccordement des composants existants.**

Aucun développement architectural significatif nécessaire. Les briques sont toutes en place.

### Ce qui manque concrètement (Stratégie 2 — approche minimale)

1. Dans `_onTranscriptionReceived()` (ligne 1399), après `provider.sendUserMessage(text)` : attendre la fin du chargement
2. Détecter la réception de la réponse Bobodo (quand `isLoading` repasse à `false` et qu'un nouveau message bot existe)
3. Extraire le contenu texte du dernier message bot
4. Appeler `_speakWithLocalTts(text)` (qui existe déjà)
5. À la fin de la lecture, `_onAudioPlaybackComplete()` est déjà codé pour relancer l'écoute

### Impact sur le Mode 1

**ZÉRO.** Le Mode 1 est uniquement déclenché par le micro de la zone de saisie. Il utilise `_startVocalRecording()` avec la branche `!_isConversationMode` de `_onTranscriptionReceived()`. Cette branche n'est pas touchée.

---

**Aucune implémentation. Aucune correction. Aucun commit.**

*Fin du rapport.*
