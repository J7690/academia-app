# Bobodo Voice V1 - Guide de Test Complet

## Phase 8 : Tests Complets

### 1. Tests Serveur (Kamatera)

#### 1.1 Test WebSocket TTS
```bash
# Test de connexion WebSocket
wscat -c ws://185.167.97.144:8000/ws

# Envoyer message TTS
{"type": "tts_request", "text": "Bonjour, je suis Bobodo"}

# Vérifier réponse audio
```

#### 1.2 Test Edge Function Streaming
```bash
# Test sans streaming
curl -X POST https://[SUPABASE_URL]/functions/v1/bobodo-chat \
  -H "Authorization: Bearer [JWT]" \
  -H "apikey: [ANON_KEY]" \
  -H "Content-Type: application/json" \
  -d '{"message": "Bonjour", "session_id": "test"}'

# Test avec streaming
curl -X POST "https://[SUPABASE_URL]/functions/v1/bobodo-chat?stream=true" \
  -H "Authorization: Bearer [JWT]" \
  -H "apikey: [ANON_KEY]" \
  -H "Content-Type: application/json" \
  -d '{"message": "Bonjour", "session_id": "test"}'
```

#### 1.3 Test Piper TTS
```bash
# Test direct Piper
cd /opt/piper-tts
python3 -c "
from tts_service import TTSService
service = TTSService()
audio = service.generate_audio('Test de synthèse vocale')
print(f'Audio généré: {len(audio)} octets')
"
```

### 2. Tests Flutter (Émulateur)

#### 2.1 Test Mode Dictée
1. Ouvrir l'onglet Bobodo
2. Cliquer sur l'icône micro
3. Parler (test: "Qu'est-ce qu'Academia ?")
4. Vérifier transcription dans champ texte
5. Envoyer message
6. Vérifier réponse audio

#### 2.2 Test Mode Conversation
1. Activer le mode conversation (icône micro dans header)
2. Vérifier indicateur d'état "En attente"
3. Cliquer sur bouton "Démarrer"
4. Vérifier état "Écoute"
5. Parler (test: "Bonjour")
6. Vérifier transcription automatique
7. Vérifier état "Réflexion"
8. Vérifier réponse audio
9. Vérifier retour automatique à "Écoute"

#### 2.3 Test VAD (Voice Activity Detection)
1. Démarrer mode conversation
2. Parler pendant 2 secondes
3. S'arrêter de parler
4. Vérifier arrêt automatique après 800ms de silence
5. Vérifier envoi transcription

#### 2.4 Test Barge-in (Interruption)
1. Démarrer mode conversation
2. Poser une question
3. Attendre début réponse audio
4. Parler pendant la réponse
5. Vérifier arrêt immédiat de l'audio
6. Vérifier nouvelle transcription
7. Vérifier nouvelle réponse

#### 2.5 Test Mémoire Conversationnelle
1. Démarrer mode conversation
2. Poser 5 questions successives
3. Vérifier maintien du contexte
4. Poser une question liée à la 3ème question
5. Vérifier réponse contextuelle

#### 2.6 Test Contrôles Conversation
1. Démarrer mode conversation
2. Tester bouton "Quitter" → vérifier retour mode dictée
3. Tester bouton "Couper" pendant lecture → vérifier arrêt
4. Tester bouton "Rejouer" → vérifier relecture
5. Tester bouton "Reprendre" après pause → vérifier reprise

#### 2.7 Test Fallback Réseau
1. Désactiver connexion WiFi
2. Démarrer mode conversation
3. Poser une question
4. Vérifier notification "Mode hors ligne"
5. Vérifier utilisation TTS local (FlutterTts)

### 3. Tests Appareil Réel

#### 3.1 Préparation
```bash
# Build APK
cd academia_app
flutter build apk --release

# Installer sur appareil
adb install build/app/outputs/flutter-apk/app-release.apk
```

#### 3.2 Test Audio Qualité
1. Tester dans environnement calme
2. Tester dans environnement bruyant
3. Vérifier clarté transcription
4. Vérifier qualité audio TTS

#### 3.3 Test Bluetooth
1. Connecter casque Bluetooth
2. Tester enregistrement via Bluetooth
3. Tester lecture via Bluetooth
4. Vérifier synchronisation

#### 3.4 Test Performance
1. Mesurer latence transcription → < 2s
2. Mesurer latence TTS → < 1s
3. Mesurer latence totale → < 3s
4. Vérifier consommation batterie

#### 3.5 Test Réseau Faible
1. Simuler réseau 3G
2. Tester mode conversation
3. Vérifier fallback TTS local
4. Vérifier reprise connexion

### 4. Tests Non-Régression

#### 4.1 Mode Texte
1. Vérifier envoi message texte normal
2. Vérifier réponse texte normale
3. Vérifier historique messages
4. Vérifier feedback messages

#### 4.2 Mode Dictée
1. Vérifier transcription dictée
2. Vérifier édition transcription
3. Vérifier envoi manuel
4. Vérifier réponse audio

#### 4.3 Sessions
1. Vérifier création session
2. Vérifier historique sessions
3. Vérifier nouvelle conversation
4. Vérifier suppression session

### 5. Critères de Succès

#### 5.1 Critères Fonctionnels
- ✓ Mode conversation fonctionne correctement
- ✓ VAD détecte voix et silence
- ✓ Barge-in interrompt lecture
- ✓ Mémoire maintient contexte (10 échanges)
- ✓ Fallback réseau utilise TTS local
- ✓ Contrôles conversation fonctionnent

#### 5.2 Critères Performance
- ✓ Latence transcription < 2s
- ✓ Latence TTS < 1s
- ✓ Latence totale < 3s
- ✓ Consommation batterie acceptable

#### 5.3 Critères UX
- ✓ États visibles et clairs
- ✓ Transitions fluides
- ✓ Audio clair et naturel
- ✓ Interface intuitive

### 6. Rapport de Test

#### 6.1 Template
```markdown
# Rapport de Test Bobodo Voice V1

## Date: [DATE]
## Testeur: [NOM]
## Appareil: [MODÈLE]
## Version Android: [VERSION]

## Résultats Tests Serveur
- WebSocket TTS: [PASS/FAIL]
- Edge Function Streaming: [PASS/FAIL]
- Piper TTS: [PASS/FAIL]

## Résultats Tests Flutter
- Mode Dictée: [PASS/FAIL]
- Mode Conversation: [PASS/FAIL]
- VAD: [PASS/FAIL]
- Barge-in: [PASS/FAIL]
- Mémoire: [PASS/FAIL]
- Contrôles: [PASS/FAIL]
- Fallback: [PASS/FAIL]

## Résultats Tests Appareil Réel
- Audio Qualité: [PASS/FAIL]
- Bluetooth: [PASS/FAIL]
- Performance: [PASS/FAIL]
- Réseau Faible: [PASS/FAIL]

## Résultats Tests Non-Régression
- Mode Texte: [PASS/FAIL]
- Mode Dictée: [PASS/FAIL]
- Sessions: [PASS/FAIL]

## Problèmes Identifiés
1. [Description]
2. [Description]

## Recommandations
1. [Recommandation]
2. [Recommandation]

## Conclusion
[APPROUVÉ/REJETÉ]
```

### 7. Checklist Avant Déploiement

- [ ] Tous tests serveur passent
- [ ] Tous tests Flutter passent
- [ ] Tous tests appareil réel passent
- [ ] Tous tests non-régression passent
- [ ] Latence dans les limites
- [ ] UX acceptable
- [ ] Aucun bug critique
- [ ] Documentation complète
