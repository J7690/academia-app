# BOBODO VOICE - Latency Audit

## Date
12 Juin 2026

---

## OBJECTIF

Mesurer précisément le temps réel nécessaire pour une interaction vocale complète.

---

## RÈGLES OBLIGATOIRES

1. Aucune supposition
2. Aucun chiffre estimé sans mesure réelle
3. Aucun raisonnement théorique si une mesure réelle est possible

---

## CONCLUSION PRÉLIMINAIRE

**IMPOSSIBLE DE COMPLÉTER L'AUDIT SANS MESURES RÉELLES**

**Justification** :
- Aucun appareil physique disponible pour tests
- Aucune mesure de latence réelle effectuée
- Les documents existants contiennent uniquement des estimations théoriques
- Les grilles de test sont vides (templates non remplis)

---

## ANALYSE DES DONNÉES DISPONIBLES

### Document 1 : BOBODO_VOICE_PRODUCTION_ACCEPTANCE.md

**Statut** : Benchmark NON RÉALISÉ

**Contenu** :
```
### MISSION 3 – Benchmark Réel

### Statut
**NON RÉALISÉ** - Pas d'appareil disponible pour test

### Plan de Test
- Phrase courte : "Bonjour Bobodo"
- Phrase moyenne : "Comment postuler à l'université ?"
- Phrase longue : 20 secondes de parole

### Mesures Attendues
- Temps transcription : 1-2s (Small)
- Temps réponse : 1-3s (Bobodo Edge Function)
- Temps synthèse : 2-4s (gTTS)
- Temps lecture : Variable

### Conclusion
Benchmark à réaliser sur appareil réel.
```

**Problème** :
- Les "Mesures Attendues" sont des estimations théoriques
- Aucune mesure réelle n'a été effectuée
- Le benchmark n'a pas été réalisé

---

### Document 2 : BOBODO_VOICE_USER_ACCEPTANCE_TEST.md

**Statut** : Template vide

**Contenu** :
```
| Test | Phrase | Temps Transcription | Temps Réponse Bobodo | Temps Synthèse | Temps Total | Résultat |
|------|--------|---------------------|----------------------|----------------|-------------|----------|
| 1 | "Bonjour Bobodo" | ___s | ___s | ___s | ___s | |
| 2 | "Comment postuler à l'université ?" | ___s | ___s | ___s | ___s | |
| 3 | 20 secondes de parole | ___s | ___s | ___s | ___s | |
```

**Problème** :
- Template de test vide
- Aucune mesure remplie
- Aucun test utilisateur effectué

---

### Document 3 : BOBODO_VOICE_PRODUCTION_ACCEPTANCE.md (Latence estimée)

**Contenu** :
```
### Latence Réelle
**Estimée** (non mesurée sur appareil) :
- STT : 1-2s
- Silence Detection : 0.5s
- TTS : 2-4s
- Total traitement : 3.5-6.5s
```

**Problème** :
- "Latence Réelle" est en fait une estimation
- "non mesurée sur appareil" explicitement indiqué
- Chiffres théoriques, pas réels

---

## ARCHITECTURE TECHNIQUE ANALYSÉE

### ÉTAPE 1 : Microphone → Serveur vocal

**Technologie** : WebSocket (ws://185.167.97.144:8000/ws)

**Code** (bobodo_vocal_service.dart) :
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

**Problème** :
- Audio envoyé en base64 (encodage supplémentaire)
- Pas de streaming (envoi complet)
- Latence réseau non mesurée

**Mesure requise** : Temps entre fin d'enregistrement et réception sur serveur

---

### ÉTAPE 2 : Serveur vocal → STT

**Technologie** : Faster Whisper Small

**Configuration** (Production Acceptance) :
- Modèle : `small`
- Taille : ~461 MB
- Device : `cpu`
- Compute type : `int8`
- Silence threshold : 500ms

**Problème** :
- Temps de transcription non mesuré
- Les "1-2s" sont une estimation théorique
- Aucun benchmark réel effectué

**Mesure requise** : Temps entre réception audio et transcription

---

### ÉTAPE 3 : STT → Bobodo

**Technologie** : Edge Function bobodo-chat

**Composants** :
- OpenRouter API (LLM)
- RAG Academia (pgvector)
- Mémoire émotionnelle
- Mémoire cross-session
- Profil étudiant

**Problème** :
- Temps de réponse non mesuré
- Les "1-3s" sont une estimation théorique
- Aucun benchmark réel effectué

**Mesure requise** : Temps entre transcription et réponse texte

---

### ÉTAPE 4 : Bobodo → TTS

**Technologie** : gTTS (Google Text-to-Speech)

**Statut** (Production Acceptance) :
- Piper TTS : NON disponible (404 HuggingFace)
- Fallback : gTTS actif

**Problème** :
- Temps de synthèse non mesuré
- Les "2-4s" sont une estimation théorique
- Aucun benchmark réel effectué

**Mesure requise** : Temps entre réponse texte et audio généré

---

### ÉTAPE 5 : TTS → Lecture audio Flutter

**Technologie** : AudioPlayer (audioplayers package)

**Code** (student_bobodo_tab.dart) :
```dart
await _audioPlayer.setSourceBytes(audioBytes);
await _audioPlayer.resume();
```

**Problème** :
- Temps de lecture non mesuré
- Variable selon longueur de la réponse
- Aucun benchmark réel effectué

**Mesure requise** : Temps entre réception audio et fin de lecture

---

### ÉTAPE 6 : Temps total utilisateur

**Problème** :
- Temps total non mesuré
- Les "3.5-6.5s" sont une estimation théorique
- Aucun benchmark réel effectué

**Mesure requise** : Temps entre fin de parole utilisateur et fin de lecture Bobodo

---

## ÉTAPE PAR ÉTAPE - ANALYSE

### ÉTAPE 1 : Microphone → Serveur vocal

**Mesure réelle** : ❌ INDISPONIBLE

**Estimation théorique** : ❌ NON FOURNIE

**Conclusion** : Impossible de mesurer sans appareil

---

### ÉTAPE 2 : Serveur vocal → STT

**Mesure réelle** : ❌ INDISPONIBLE

**Estimation théorique** : 1-2s (Small)

**Conclusion** : Estimation théorique, pas de mesure réelle

---

### ÉTAPE 3 : STT → Bobodo

**Mesure réelle** : ❌ INDISPONIBLE

**Estimation théorique** : 1-3s (Edge Function)

**Conclusion** : Estimation théorique, pas de mesure réelle

---

### ÉTAPE 4 : Bobodo → TTS

**Mesure réelle** : ❌ INDISPONIBLE

**Estimation théorique** : 2-4s (gTTS)

**Conclusion** : Estimation théorique, pas de mesure réelle

---

### ÉTAPE 5 : TTS → Lecture audio Flutter

**Mesure réelle** : ❌ INDISPONIBLE

**Estimation théorique** : Variable

**Conclusion** : Estimation théorique, pas de mesure réelle

---

### ÉTAPE 6 : Temps total utilisateur

**Mesure réelle** : ❌ INDISPONIBLE

**Estimation théorique** : 3.5-6.5s

**Conclusion** : Estimation théorique, pas de mesure réelle

---

## SYNTHÈSE

### Temps minimum

**Mesure réelle** : ❌ INDISPONIBLE

**Estimation théorique** : 3.5s

**Conclusion** : Estimation théorique, pas de mesure réelle

---

### Temps moyen

**Mesure réelle** : ❌ INDISPONIBLE

**Estimation théorique** : 5s

**Conclusion** : Estimation théorique, pas de mesure réelle

---

### Temps maximum

**Mesure réelle** : ❌ INDISPONIBLE

**Estimation théorique** : 6.5s

**Conclusion** : Estimation théorique, pas de mesure réelle

---

## FACTEUR LIMITANT PRINCIPAL

**Analyse théorique** (sans mesure réelle) :

**Composants identifiés** :
1. Encodage base64 (Flutter)
2. Latence réseau WebSocket
3. Transcription STT (Faster Whisper Small)
4. Traitement Edge Function (OpenRouter + RAG)
5. Synthèse TTS (gTTS)
6. Lecture audio (AudioPlayer)

**Estimation théorique** :
- STT : 1-2s (consomme le plus)
- TTS : 2-4s (consomme le plus)
- Edge Function : 1-3s
- Réseau : <1s
- Encodage : <0.5s

**Conclusion théorique** : STT et TTS sont les facteurs limitants

**Problème** : Sans mesure réelle, impossible de confirmer

---

## OPTIMISATION POSSIBLE

### Ce qui peut être optimisé (théorique)

1. **STT** :
   - Passer de Small à Tiny (plus rapide, moins précis)
   - Passer de CPU à GPU (si disponible)
   - Streaming STT (transcription en temps réel)

2. **TTS** :
   - Installer Piper TTS (plus rapide que gTTS)
   - Streaming TTS (lecture pendant génération)
   - Utiliser un modèle plus léger

3. **Réseau** :
   - Streaming WebSocket (envoi par chunks)
   - Réduire taille des chunks
   - Optimiser encodage base64

4. **Edge Function** :
   - Cache RAG
   - Optimiser requêtes OpenRouter
   - Réduire taille de l'historique

### Ce qui ne peut pas être optimisé (théorique)

1. **Latence réseau physique** : Dépend de la connexion utilisateur
2. **Temps de parole utilisateur** : Dépend de l'utilisateur
3. **Temps de lecture audio** : Dépend de la longueur de la réponse

**Problème** : Sans mesure réelle, impossible de confirmer les optimisations

---

## CONCLUSION

### IMPOSSIBILITÉ DE COMPLÉTER L'AUDIT

**Raisons** :
1. Aucun appareil physique disponible pour tests
2. Aucune mesure de latence réelle effectuée
3. Les documents existants contiennent uniquement des estimations théoriques
4. Les grilles de test sont vides (templates non remplis)

**Règles obligatoires non respectées** :
- ❌ Aucune supposition (impossible sans mesures)
- ❌ Aucun chiffre estimé sans mesure réelle (les seules données sont des estimations)
- ❌ Aucun raisonnement théorique si une mesure réelle est possible (mesure possible mais non effectuée)

---

## RECOMMANDATION

**AVANT TOUTE IMPLÉMENTATION DU MODE CONVERSATION** :

1. **Effectuer des mesures réelles sur appareil physique**
   - Android ou iOS
   - Réseau stable (4G/WiFi)
   - Conditions contrôlées

2. **Remplir la grille de test BOBODO_VOICE_USER_ACCEPTANCE_TEST.md**
   - Mesurer chaque étape
   - Noter les temps réels
   - Identifier les facteurs limitants

3. **Benchmark complet**
   - Phrase courte
   - Phrase moyenne
   - Phrase longue
   - Multiples tests pour moyenne/max

4. **Analyser les résultats**
   - Identifier le facteur limitant réel
   - Déterminer les optimisations possibles
   - Valider la latence acceptable

---

## STATUT FINAL

**AUDIT INCOMPLET**

**Justification** :
- Aucune mesure réelle disponible
- Impossible de respecter les règles obligatoires
- Audit ne peut être complété sans tests sur appareil réel

---

## SIGN-OFF

**Audit réalisé** : 12 Juin 2026
**Auditeur** : Cascade AI
**Statut** : INCOMPLET - Mesures réelles requises
