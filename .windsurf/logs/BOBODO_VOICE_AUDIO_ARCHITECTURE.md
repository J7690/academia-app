# BOBODO VOICE - Audio Architecture Audit

## Date
12 Juin 2026

---

## OBJECTIF

Auditer le système audio actuel et déterminer s'il fonctionne en half duplex, pseudo duplex ou full duplex. Documenter le fonctionnement actuel, les limitations et la solution recommandée.

---

## ARCHITECTURE AUDIO ACTUELLE (CODE RÉEL)

### Source de vérité analysée

**Flutter** :
- `academia_app/lib/features/student/tabs/student_bobodo_tab.dart` (1584 lignes)
- `academia_app/lib/services/bobodo_vocal_service.dart` (95 lignes)

**Packages Flutter** :
- `flutter_sound` : Enregistrement audio
- `audioplayers` : Lecture audio

**Backend** :
- Services STT/TTS sur Kamatera (stt_service.py, tts_service.py) - NON dans codebase local

---

## COMPOSANTS AUDIO

### 1. Enregistrement (FlutterSound)

**Package** : `flutter_sound`

**Initialisation** (lignes 1141-1147) :
```dart
Future<void> _initRecorder() async {
  try {
    await _recorder.openRecorder();
  } catch (e) {
    debugPrint('[VOICE_RECORDER_INIT_ERROR] $e');
  }
}
```

**Démarrage** (lignes 1184-1218) :
```dart
await _recorder.startRecorder(
  codec: Codec.pcm16WAV,
  toStream: _audioStreamController?.sink,
);
```

**Configuration** :
- Codec : PCM16 WAV
- Sortie : Stream vers `_audioStreamController`
- Buffer : `_audioBuffer` (List<Uint8List>)

---

### 2. Lecture (AudioPlayer)

**Package** : `audioplayers`

**Initialisation** (ligne 38) :
```dart
final AudioPlayer _audioPlayer = AudioPlayer();
```

**Lecture** (lignes 1289-1298) :
```dart
await _audioPlayer.setSourceBytes(audioBytes);
await _audioPlayer.resume();

setState(() => _isSpeaking = true);

_audioPlayer.onPlayerComplete.listen((_) {
  setState(() => _isSpeaking = false);
});
```

**Arrêt** (lignes 1304-1307) :
```dart
void _stopAudioPlayback() {
  _audioPlayer.stop();
  setState(() => _isSpeaking = false);
}
```

---

### 3. WebSocket (BobodoVocalService)

**Service** : `bobodo_vocal_service.dart`

**Connexion** (lignes 25-57) :
```dart
_channel = WebSocketChannel.connect(Uri.parse('$_url?session_id=$sessionId'));
```

**Envoi audio** (lignes 59-77) :
```dart
void sendAudio(Uint8List audioBytes) {
  final base64Audio = base64Encode(audioBytes);
  final message = jsonEncode({
    'type': 'audio',
    'session_id': _sessionId,
    'audio': base64Audio,
  });
  _channel!.sink.add(message);
}
```

**Réception** (lignes 35-51) :
```dart
_channel!.stream.listen(
  (message) {
    final data = jsonDecode(message as String) as Map<String, dynamic>;
    _messageController.add(data);
  },
);
```

---

## ANALYSE : HALF DUPLEX VS PSEUDO DUPLEX VS FULL DUPLEX

### Définitions

**Half Duplex** :
- Un seul sens à la fois
- Enregistrement OU lecture
- Impossible de parler pendant la réponse

**Pseudo Duplex** :
- Deux sens mais avec latence
- Enregistrement ET lecture possible mais avec délai
- Interruption possible mais pas instantanée

**Full Duplex** :
- Deux sens simultanés
- Enregistrement ET lecture en même temps
- Interruption instantanée (VAD en temps réel)

---

### Architecture actuelle : HALF DUPLEX

**Preuve 1 : États mutuellement exclusifs**

```dart
bool _isRecording = false;   // Enregistrement
bool _isSpeaking = false;     // Lecture
```

- `_isRecording` et `_isSpeaking` ne peuvent pas être true en même temps
- Pas de mécanisme pour permettre les deux simultanément

**Preuve 2 : FlutterSoundRecorder**

- `startRecorder()` monopolise le microphone
- Pas de possibilité d'enregistrer pendant la lecture
- Le package ne supporte pas le duplex

**Preuve 3 : AudioPlayer**

- `setSourceBytes()` + `resume()` monopolise la sortie audio
- Pas de possibilité de mixer audio entrée/sortie
- Le package ne supporte pas le duplex

**Preuve 4 : Flux audio**

```
Enregistrement → Buffer → WebSocket → STT → Transcription
                                            ↓
                                    Bobodo → Réponse → TTS → Audio → Lecture
```

- Flux unidirectionnel
- Pas de boucle de retour
- Pas de détection VAD

---

## LIMITATIONS ACTUELLES

### 1. Pas de VAD (Voice Activity Detection)

**Problème** :
- Aucune détection de parole côté client
- User doit cliquer stop manuellement
- Pas de détection automatique de fin de parole

**Impact** :
- UX dégradée
- Pas de mode conversation naturel
- Dépendance aux clics manuels

---

### 2. Pas d'interruption pendant la réponse

**Problème** :
- User ne peut pas parler pendant la lecture
- Bouton stop existe mais arrête seulement la lecture
- Pas de détection de parole pendant TTS

**Impact** :
- Pas de conversation fluide
- User doit attendre la fin de la réponse
- Pas de mode ChatGPT Voice

---

### 3. Latence WebSocket

**Problème** :
- Audio envoyé en base64 via WebSocket
- Latence réseau non négligeable
- Pas de streaming audio

**Impact** :
- Délai entre parole et transcription
- Délai entre réponse et TTS
- Pas de temps réel

---

### 4. Monopolisation des ressources audio

**Problème** :
- FlutterSoundRecorder monopolise le microphone
- AudioPlayer monopolise la sortie audio
- Pas de partage des ressources

**Impact** :
- Impossible d'enregistrer pendant la lecture
- Impossible de mixer audio
- Half duplex strict

---

## SOLUTION RECOMMANDÉE

### Phase 1 : PSEUDO DUPLEX (V1)

**Objectif** : Permettre l'interruption pendant la réponse

**Implémentation** :

1. **VAD côté client**
   - Utiliser un package VAD Flutter
   - Détecter automatiquement la fin de parole
   - Stopper l'enregistrement automatiquement

2. **Interruption TTS**
   - Détecter parole pendant la lecture
   - Stopper AudioPlayer
   - Réactiver le micro

3. **Streaming WebSocket**
   - Envoyer audio en streaming (pas en base64 complet)
   - Réduire la latence
   - Permettre transcription en temps réel

**Packages Flutter** :
- `flutter_sound` (déjà utilisé)
- `audioplayers` (déjà utilisé)
- `voice_activity_detection` (à ajouter)

**Impact** :
- UX améliorée
- Mode conversation possible
- Latence réduite

---

### Phase 2 : FULL DUPLEX (V2)

**Objectif** : Permettre enregistrement et lecture simultanés

**Implémentation** :

1. **Audio mixing**
   - Utiliser un package de mixing audio
   - Mixer entrée et sortie
   - Permettre full duplex

2. **Streaming bidirectionnel**
   - WebSocket full duplex
   - Streaming audio entrée/sortie
   - Latence minimale

3. **VAD temps réel**
   - VAD côté serveur
   - Détection de parole en temps réel
   - Interruption instantanée

**Packages Flutter** :
- `flutter_sound` (déjà utilisé)
- `audioplayers` (déjà utilisé)
- `just_audio` (pour mixing)
- `voice_activity_detection` (à ajouter)

**Impact** :
- Full duplex complet
- Mode ChatGPT Voice
- UX optimale

---

## COMPARAISON

| Caractéristique | Actuel (Half Duplex) | Pseudo Duplex (V1) | Full Duplex (V2) |
|----------------|----------------------|-------------------|------------------|
| Enregistrement pendant lecture | ❌ | ❌ | ✅ |
| Interruption pendant réponse | ❌ (stop manuel) | ✅ (VAD) | ✅ (VAD temps réel) |
| VAD automatique | ❌ | ✅ | ✅ |
| Streaming audio | ❌ (base64 complet) | ✅ | ✅ |
| Latence | Élevée | Moyenne | Faible |
| Complexité | Faible | Moyenne | Élevée |
| Mode conversation | ❌ | ✅ | ✅ |
| Mode ChatGPT Voice | ❌ | ⚠️ (partiel) | ✅ |

---

## RISQUES

### 1. Compatibilité FlutterSound

**Risque** : FlutterSound ne supporte pas le duplex

**Mitigation** :
- Tester sur différents appareils
- Fallback sur half duplex si nécessaire
- Utiliser un package alternatif si besoin

---

### 2. Performance VAD

**Risque** : VAD consomme beaucoup de CPU

**Mitigation** :
- Optimiser le seuil VAD
- Utiliser VAD côté serveur si possible
- Tests sur appareils bas de gamme

---

### 3. Latence WebSocket

**Risque** : Streaming WebSocket augmente la latence

**Mitigation** :
- Optimiser la taille des chunks
- Utiliser WebRTC si possible
- Tests sur différents réseaux

---

### 4. Mixing audio

**Risque** : Mixing audio complexe à implémenter

**Mitigation** :
- Utiliser un package éprouvé
- Tests approfondis
- Fallback sur pseudo duplex

---

## RECOMMANDATIONS

### Phase 1 (CRITIQUE - Pseudo Duplex)

1. **Ajouter VAD côté client**
   - Package `voice_activity_detection`
   - Détection automatique de fin de parole
   - Stop enregistrement automatique

2. **Implémenter interruption TTS**
   - Détecter parole pendant lecture
   - Stop AudioPlayer
   - Réactiver micro

3. **Streaming WebSocket**
   - Envoyer audio en streaming
   - Réduire latence
   - Transcription en temps réel

### Phase 2 (OPTIONNEL - Full Duplex)

4. **Audio mixing**
   - Package `just_audio`
   - Mixer entrée/sortie
   - Full duplex complet

5. **VAD temps réel**
   - VAD côté serveur
   - Interruption instantanée
   - Latence minimale

---

## CONCLUSION

### Architecture actuelle = HALF DUPLEX

**Preuves** :
- États mutuellement exclusifs (_isRecording vs _isSpeaking)
- FlutterSoundRecorder monopolise le microphone
- AudioPlayer monopolise la sortie audio
- Pas de VAD
- Pas d'interruption pendant la réponse

**Limitations** :
- Pas de mode conversation naturel
- Dépendance aux clics manuels
- Latence élevée
- UX dégradée

### Solution recommandée = PSEUDO DUPLEX (V1)

**Améliorations** :
- VAD automatique
- Interruption pendant la réponse
- Streaming WebSocket
- Latence réduite

**Impact** :
- Mode conversation possible
- UX améliorée
- Complexité raisonnable

### Full Duplex (V2) = OPTIONNEL

**Améliorations** :
- Full duplex complet
- Mixing audio
- VAD temps réel

**Impact** :
- Mode ChatGPT Voice complet
- UX optimale
- Complexité élevée

---

## LIVRABLES SUIVANTS

1. BOBODO_VOICE_INTERRUPTION_AUDIT.md
2. BOBODO_VOICE_AUTO_LISTENING.md
3. BOBODO_VOICE_MEMORY_COMPATIBILITY_V2.md
4. BOBODO_VOICE_UX_FINAL.md
5. BOBODO_FULL_VOICE_CONVERSATION_ARCHITECTURE.md
