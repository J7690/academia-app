# Audit Refonte UX Mode Vocal Bobodo - 11 Juin 2026

## Objectif

Refondre le mode vocal pour un fonctionnement proche de ChatGPT Voice :
- L'utilisateur reste maître du moment où son message est envoyé
- Aucune transcription automatique
- Aucun envoi automatique
- Zone de saisie temporairement transformée en espace vocal

---

## Widgets Flutter à Supprimer

### 1. BobodoVocalButton (Widget Indépendant)
**Fichier** : `academia_app/lib/widgets/bobodo_vocal_button.dart`
**Action** : **SUPPRIMER**

**Raison** :
- Ce widget est actuellement un composant indépendant avec son propre UI (FloatingActionButton, indicateurs)
- Il n'intègre pas la zone de saisie Bobodo
- Il ne permet pas l'édition de la transcription
- Il envoie automatiquement le message à Bobodo

**Fonctionnalités à conserver** :
- Logique d'enregistrement audio (`FlutterSoundRecorder`)
- Logique de connexion WebSocket (`BobodoVocalService`)
- Gestion des permissions microphone
- Réception de la transcription

**Fonctionnalités à supprimer** :
- UI indépendante (FloatingActionButton, indicateurs)
- Envoi automatique à Bobodo (`onTranscription` callback)
- Callback `onAudioResponse` (lecture audio sera gérée différemment)

---

### 2. _buildVocalPanel (Panel Flottant)
**Fichier** : `academia_app/lib/features/student/tabs/student_bobodo_tab.dart`
**Lignes** : 940-1014
**Action** : **SUPPRIMER**

**Raison** :
- Panel flottant séparé de la zone de saisie
- Ne correspond pas au nouveau flux UX
- Crée une zone d'interaction supplémentaire

**Fonctionnalités à conserver** :
- Aucune (toutes seront réimplémentées dans la zone de saisie)

---

## Widgets Flutter à Fusionner avec la Zone de Saisie

### 1. Zone de Saisie Bobodo (_buildInputBar)
**Fichier** : `academia_app/lib/features/student/tabs/student_bobodo_tab.dart`
**Lignes** : 815-928
**Action** : **MODIFIER**

**État actuel** :
- Champ texte (`TextField`)
- Bouton emoji
- Bouton toggle vocal (`IconButton` avec icône micro)
- Bouton envoi

**Nouveau comportement** :
- **Mode texte** (actuel) : Champ texte + boutons
- **Mode vocal** (nouveau) : Animation audio + durée + boutons Stop/Annuler

**Modifications requises** :
- Ajouter état `_isRecordingMode` (bool)
- Ajouter état `_recordingDuration` (Duration)
- Ajouter état `_isTranscribing` (bool)
- Remplacer conditionnellement le `TextField` par l'interface vocale
- Intégrer logique d'enregistrement audio
- Intégrer logique de transcription STT
- Intégrer logique d'édition de transcription

---

## Méthodes à Supprimer

### Dans BobodoVocalButton
**Fichier** : `academia_app/lib/widgets/bobodo_vocal_button.dart`

**Méthodes à supprimer** :
- `build()` : UI indépendante
- `_onAudioData()` : Envoi automatique via WebSocket (remplacé par envoi manuel après transcription)

**Méthodes à conserver et déplacer** :
- `_initRecorder()` : Initialisation recorder (déplacer vers `student_bobodo_tab.dart`)
- `_requestPermission()` : Permission microphone (déplacer vers `student_bobodo_tab.dart`)
- `_startRecording()` : Démarrage enregistrement (déplacer vers `student_bobodo_tab.dart`)
- `_stopRecording()` : Arrêt enregistrement (déplacer vers `student_bobodo_tab.dart`)
- `_connectWebSocket()` : Connexion WebSocket (déplacer vers `student_bobodo_tab.dart`)

---

### Dans StudentBobodoTab
**Fichier** : `academia_app/lib/features/student/tabs/student_bobodo_tab.dart`

**Méthodes à supprimer** :
- `_buildVocalPanel()` : Panel flottant (lignes 940-1014)
- `_showVocalButton` : État toggle vocal (ligne 35)

**Méthodes à modifier** :
- `_buildInputBar()` : Ajouter logique mode vocal
- `_send()` : Ne plus envoyer automatiquement la transcription

---

## Méthodes à Ajouter

### Dans StudentBobodoTab
**Fichier** : `academia_app/lib/features/student/tabs/student_bobodo_tab.dart`

**Nouvelles méthodes** :
- `_startVocalRecording()` : Démarrer enregistrement vocal
- `_stopVocalRecording()` : Arrêter enregistrement et lancer transcription
- `_cancelVocalRecording()` : Annuler enregistrement
- `_onTranscriptionReceived(String text)` : Recevoir transcription et l'afficher dans le champ texte
- `_buildVocalInputInterface()` : Interface vocale (animation, durée, boutons)
- `_buildAudioWaveform()` : Animation ondulations audio
- `_formatRecordingDuration(Duration duration)` : Formater durée (MM:SS)

---

## Impact Exact sur BobodoProvider

**Fichier** : `academia_app/lib/providers/bobodo_provider.dart`

**Impact** : **AUCUN**

**Raison** :
- `BobodoProvider` gère uniquement les messages et les sessions
- Il ne gère pas l'interface vocale
- La transcription sera envoyée via `sendUserMessage()` comme un message texte normal
- Aucune modification requise

---

## Impact Exact sur bobodo_vocal_button.dart

**Fichier** : `academia_app/lib/widgets/bobodo_vocal_button.dart`

**Impact** : **SUPPRESSION COMPLÈTE**

**Raison** :
- Ce widget sera supprimé
- Ses fonctionnalités seront intégrées directement dans `student_bobodo_tab.dart`
- Le fichier peut être supprimé du projet

---

## Impact Exact sur student_bobodo_tab.dart

**Fichier** : `academia_app/lib/features/student/tabs/student_bobodo_tab.dart`

**Impact** : **MODIFICATIONS MAJEURES**

**Modifications requises** :

1. **Imports** :
   - Ajouter `import 'package:flutter_sound/flutter_sound.dart';`
   - Ajouter `import 'package:permission_handler/permission_handler.dart';`
   - Ajouter `import '../services/bobodo_vocal_service.dart';`
   - Ajouter `import 'dart:async';`
   - Ajouter `import 'dart:typed_data';`

2. **État** :
   - Ajouter `FlutterSoundRecorder _recorder;`
   - Ajouter `BobodoVocalService _vocalService;`
   - Ajouter `StreamController<Uint8List>? _audioStreamController;`
   - Ajouter `StreamSubscription? _messageSubscription;`
   - Ajouter `StreamSubscription? _errorSubscription;`
   - Ajouter `bool _isRecordingMode = false;`
   - Ajouter `bool _isTranscribing = false;`
   - Ajouter `Duration _recordingDuration = Duration.zero;`
   - Ajouter `Timer? _recordingTimer;`
   - Ajouter `bool _isVocalConnected = false;`

3. **Méthodes init/dispose** :
   - `initState()` : Initialiser recorder, vocal service, stream controller
   - `dispose()` : Nettoyer recorder, vocal service, subscriptions, timers

4. **Méthodes vocales** :
   - `_initRecorder()` : Initialiser FlutterSoundRecorder
   - `_connectVocalWebSocket()` : Connecter au service vocal
   - `_startVocalRecording()` : Démarrer enregistrement
   - `_stopVocalRecording()` : Arrêter et transcrire
   - `_cancelVocalRecording()` : Annuler
   - `_onAudioData(Uint8List data)` : Accumuler audio
   - `_onVocalMessage(Map message)` : Gérer messages WebSocket
   - `_onTranscriptionReceived(String text)` : Afficher transcription dans champ texte

5. **UI** :
   - `_buildInputBar()` : Modifier pour supporter mode vocal
   - `_buildVocalInputInterface()` : Nouvelle interface vocale
   - `_buildAudioWaveform()` : Animation audio
   - Supprimer `_buildVocalPanel()`

6. **Boutons** :
   - Remplacer bouton toggle vocal par bouton micro direct
   - Micro : Démarre mode vocal (remplace champ texte par interface vocale)
   - Stop : Arrête enregistrement et lance transcription
   - Annuler : Annule enregistrement et retour au champ texte

---

## Nouveau Flux UX

### Étape 1 : L'utilisateur appuie sur le micro
- Bouton micro dans la barre de saisie
- Transition vers mode vocal

### Étape 2 : L'enregistrement démarre
- Champ texte remplacé par interface vocale
- Animation ondulations audio
- Timer durée d'enregistrement
- Boutons Stop et Annuler

### Étape 3 : L'utilisateur parle
- Audio accumulé localement
- Aucun envoi serveur
- Aucune transcription

### Étape 4 : L'utilisateur appuie sur Stop
- Arrêt enregistrement
- Envoi audio au serveur STT
- Spinner "Transcription..."

### Étape 5 : Transcription reçue
- Texte affiché dans le champ texte normal
- Interface vocale remplacée par champ texte
- L'utilisateur peut éditer le texte

### Étape 6 : L'utilisateur clique sur Envoyer
- Message envoyé à Bobodo via `sendUserMessage()`
- Réponse reçue et affichée
- Réponse lue vocalement (AudioPlayer existant)

### Étape 7 : L'utilisateur appuie sur Annuler
- Audio supprimé
- Retour immédiat au champ texte
- Aucune transcription

---

## Impact Côté Serveur

**Fichiers serveur** : `stt_service.py`, `websocket_handler.py`

**Impact** : **AUCUN**

**Raison** :
- Le serveur STT actuel fonctionne déjà avec un modèle "enregistrement → transcription"
- La détection de silence peut être désactivée (plus nécessaire)
- Le serveur peut simplement transcrire l'audio complet reçu
- Aucune modification requise

**Optionnel** :
- Désactiver la détection de silence dans `stt_service.py`
- Transcrire immédiatement l'audio reçu (sans buffer)
- Simplifier le code serveur

---

## Résumé des Actions

### Suppressions
1. **Fichier** : `bobodo_vocal_button.dart` → SUPPRIMER
2. **Méthode** : `_buildVocalPanel()` dans `student_bobodo_tab.dart` → SUPPRIMER
3. **État** : `_showVocalButton` dans `student_bobodo_tab.dart` → SUPPRIMER

### Ajouts
1. **Méthodes** dans `student_bobodo_tab.dart` :
   - `_initRecorder()`
   - `_connectVocalWebSocket()`
   - `_startVocalRecording()`
   - `_stopVocalRecording()`
   - `_cancelVocalRecording()`
   - `_onAudioData()`
   - `_onVocalMessage()`
   - `_onTranscriptionReceived()`
   - `_buildVocalInputInterface()`
   - `_buildAudioWaveform()`
   - `_formatRecordingDuration()`

2. **État** dans `student_bobodo_tab.dart` :
   - `_recorder`
   - `_vocalService`
   - `_audioStreamController`
   - `_messageSubscription`
   - `_errorSubscription`
   - `_isRecordingMode`
   - `_isTranscribing`
   - `_recordingDuration`
   - `_recordingTimer`
   - `_isVocalConnected`

### Modifications
1. **Méthode** : `_buildInputBar()` dans `student_bobodo_tab.dart` → MODIFIER
2. **Méthode** : `_send()` dans `student_bobodo_tab.dart → MODIFIER (ne plus envoyer auto)
3. **UI** : Bouton toggle vocal → Bouton micro direct

---

## Plan d'Implémentation

1. **Phase 1** : Supprimer `bobodo_vocal_button.dart` et `_buildVocalPanel()`
2. **Phase 2** : Ajouter imports et état dans `student_bobodo_tab.dart`
3. **Phase 3** : Implémenter méthodes vocales (enregistrement, transcription)
4. **Phase 4** : Modifier `_buildInputBar()` pour supporter mode vocal
5. **Phase 5** : Implémenter interface vocale (animation, durée, boutons)
6. **Phase 6** : Tester le flux complet
7. **Phase 7** : Optionnel : Simplifier serveur STT (désactiver silence detection)
