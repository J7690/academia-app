# BOBODO VOICE - Implementation Plan

## Date
12 Juin 2026

---

## OBJECTIF

Implémenter le MODE CONVERSATION VOCALE CONTINUE Bobodo Voice V1.

---

## DÉCISION TECHNOLOGIQUE VERROUILLÉE

**STT** : Faster Whisper Small

**TTS** : Piper

**Serveur** : Kamatera actuel (CPU only)

**Mémoire** : Architecture Bobodo existante

**RAG** : Architecture existante

**Historique** : Architecture existante

**Support Escalation** : Architecture existante

---

## EXPÉRIENCE UTILISATEUR ATTENDUE

### Mode Dictée (conserver)

- Flux actuel inchangé
- Aucun impact sur les fonctionnalités existantes

### Mode Conversation (nouveau)

**Flux attendu** :
1. Utilisateur active Conversation vocale
2. Bobodo écoute
3. Utilisateur parle
4. Transcription
5. Bobodo réfléchit
6. Bobodo répond vocalement
7. Lecture automatique
8. Fin lecture
9. Réactivation automatique de l'écoute
10. Utilisateur reparle

**Cycle continu**.

---

## OBLIGATIONS UX

1. ✅ Aucun panneau flottant séparé
2. ✅ Aucune fenêtre supplémentaire
3. ✅ Tout doit vivre dans l'interface Bobodo
4. ✅ UX inspirée de ChatGPT Voice
5. ✅ Affichage clair des états (écoute, traitement, réponse, pause, fin session)
6. ✅ Bouton Quitter Conversation obligatoire
7. ✅ Bouton Couper Bobodo obligatoire
8. ✅ Bouton Rejouer dernière réponse obligatoire

---

## OBLIGATIONS TECHNIQUES

1. ✅ Aucun impact sur Bobodo texte
2. ✅ Aucun impact sur mémoire émotionnelle
3. ✅ Aucun impact sur historique
4. ✅ Aucun impact sur RAG
5. ✅ Aucun impact sur Support Escalation
6. ✅ Aucun impact sur les sessions existantes
7. ✅ Aucun impact sur les fonctionnalités Academia

---

## GESTION DES INTERRUPTIONS

**Cas à gérer** :
1. ✅ Utilisateur coupe Bobodo
2. ✅ Utilisateur quitte écran
3. ✅ Perte Internet
4. ✅ Retour Internet
5. ✅ Timeout inactivité
6. ✅ Reprise session

---

## PLAN D'IMPLÉMENTATION

### PHASE 1 : Serveur - Piper TTS (2-3 jours)

**Objectif** : Intégrer Piper TTS sur le serveur Kamatera

**Étapes** :
1. Installer Piper TTS sur Kamatera
2. Télécharger la voix fr_FR-siwis-medium
3. Créer tts_service.py avec Piper
4. Tester la génération audio
5. Intégrer dans le serveur vocal existant
6. Tester le flux vocal complet

**Livrables** :
- tts_service.py modifié avec Piper
- Tests serveur validés

**Risques** :
- Téléchargement Piper (404 HuggingFace) - déjà rencontré
- **Mitigation** : Utiliser mirror alternatif ou téléchargement manuel

---

### PHASE 2 : Flutter - Mode Conversation (3-4 jours)

**Objectif** : Implémenter le mode conversation vocale continue dans Flutter

**Étapes** :
1. Ajouter un toggle Mode Dictée / Mode Conversation
2. Implémenter la machine d'états conversationnelle
3. Implémenter la réactivation automatique du micro
4. Implémenter les boutons de contrôle (Quitter, Couper, Rejouer)
5. Implémenter l'affichage des états
6. Implémenter la gestion des interruptions
7. Implémenter le timeout d'inactivité
8. Tester le flux conversationnel complet

**Livrables** :
- student_bobodo_tab.dart modifié
- bobodo_vocal_service.dart modifié
- Tests Flutter validés

**Risques** :
- Complexité de la machine d'états
- Gestion des interruptions
- **Mitigation** : Tests exhaustifs sur appareil réel

---

### PHASE 3 : Tests sur appareil réel (2-3 jours)

**Objectif** : Valider l'expérience utilisateur sur appareil réel

**Étapes** :
1. Installer l'app sur appareil Android
2. Tester le mode dictée (validation non-régression)
3. Tester le mode conversation
4. Mesurer la latence réelle
5. Tester les interruptions
6. Tester le timeout d'inactivité
7. Tester la reprise session
8. Valider l'UX finale

**Livrables** :
- Tests appareil réel validés
- Mesures de latence réelles
- Rapport de test

**Risques** :
- Latence supérieure à 3s
- Problèmes de stabilité
- **Mitigation** : Optimisations si nécessaire

---

### PHASE 4 : Déploiement (1 jour)

**Objectif** : Déployer en production

**Étapes** :
1. Déployer tts_service.py sur Kamatera
2. Déployer Flutter sur Play Store (beta)
3. Monitoring
4. Validation finale

**Livrables** :
- Déploiement production validé
- Monitoring en place

**Risques** :
- Problèmes de déploiement
- **Mitigation** : Rollback plan

---

## PLANNING

**Total estimé** : 8-11 jours

**Phase 1** : 2-3 jours (Serveur - Piper TTS)
**Phase 2** : 3-4 jours (Flutter - Mode Conversation)
**Phase 3** : 2-3 jours (Tests appareil réel)
**Phase 4** : 1 jour (Déploiement)

---

## LIVRABLES OBLIGATOIRES

1. ✅ BOBODO_VOICE_IMPLEMENTATION_PLAN.md (ce document)
2. ⏳ BOBODO_VOICE_FLUTTER_CHANGES.md
3. ⏳ BOBODO_VOICE_SERVER_CHANGES.md
4. ⏳ BOBODO_VOICE_TEST_PLAN.md

---

## RISQUES GLOBAUX

### Risque 1 : Téléchargement Piper (404 HuggingFace)

**Probabilité** : Moyenne
**Impact** : Élevé
**Mitigation** : Utiliser mirror alternatif ou téléchargement manuel

---

### Risque 2 : Latence supérieure à 3s

**Probabilité** : Faible
**Impact** : Moyen
**Mitigation** : Optimisations si nécessaire

---

### Risque 3 : Problèmes de stabilité

**Probabilité** : Faible
**Impact** : Élevé
**Mitigation** : Tests exhaustifs, rollback plan

---

### Risque 4 : Impact sur Bobodo texte

**Probabilité** : Faible
**Impact** : Élevé
**Mitigation** : Tests non-régression

---

## EXIGENCES COMPLÉMENTAIRES (VALIDÉES)

### Exigence 1 : Mode Conversation Continue
- ✅ Déjà prévu dans le plan initial
- Cycle : Listening → Processing → Thinking → Responding → Playing → Listening

### Exigence 2 : Streaming Temps Réel
- ❌ NON prévu dans le plan initial
- LLM Streaming (OpenRouter streaming API)
- TTS Streaming (Piper streaming output)
- Objectif : première réponse audio < 2 secondes

### Exigence 3 : Interruption Utilisateur (Barge-in)
- ❌ NON prévu dans le plan initial
- Arrêt immédiat TTS si utilisateur reprend la parole
- Arrêt lecture
- Retour automatique à l'écoute
- Comportement similaire à ChatGPT Voice

### Exigence 4 : Détection d'Activité Vocale (VAD)
- ❌ NON prévu dans le plan initial
- Silero VAD ou WebRTC VAD
- Détection début/fin de parole
- Réduction bruit
- Économie batterie

### Exigence 5 : Mémoire Conversationnelle
- ❌ NON prévu dans le plan initial
- 10 derniers échanges ou résumé dynamique
- Contexte préservé entre échanges

### Exigence 6 : Architecture Multilingue
- ❌ NON prévu dans le plan initial
- VoiceProvider abstrait
- Support futur : Français, Mooré, Dioula, Fulfuldé

### Exigence 7 : Fallback Réseau
- ❌ NON prévu dans le plan initial
- Fallback local si serveur indisponible
- Message vocal utilisateur

### Exigence 8 : Flutter - ConversationModePage
- ❌ NON prévu dans le plan initial
- Page dédiée mode conversation
- Boutons : Démarrer, Couper, Rejouer, Quitter
- États visibles : Écoute, Traitement, Réflexion, Réponse, Lecture

### Exigence 9 : Serveur - WebSocket Bidirectionnel
- ❌ NON prévu dans le plan initial
- WebSocket bidirectionnel
- Streaming audio
- Gestion interruption
- Logging détaillé

### Exigence 10 : Tests Étendus
- ❌ NON prévu dans le plan initial
- Réseau faible
- Casque Bluetooth
- Haut-parleur

---

## PLAN D'IMPLÉMENTATION RÉVISÉ

### PHASE 1 : Serveur - Piper TTS + Streaming (3-4 jours)

**Objectif** : Intégrer Piper TTS avec streaming sur le serveur Kamatera

**Étapes** :
1. Installer Piper TTS sur Kamatera
2. Télécharger la voix fr_FR-siwis-medium
3. Créer tts_service.py avec Piper
4. Implémenter TTS Streaming (génération par chunks)
5. Créer WebSocket bidirectionnel
6. Implémenter gestion interruption (barge-in)
7. Implémenter logging détaillé
8. Tester la génération audio streaming
9. Tester l'interruption

**Livrables** :
- tts_service.py modifié avec Piper Streaming
- WebSocket bidirectionnel
- Tests serveur validés

**Risques** :
- Téléchargement Piper (404 HuggingFace)
- Complexité streaming TTS
- **Mitigation** : Mirror alternatif, tests exhaustifs

---

### PHASE 2 : Serveur - LLM Streaming (2-3 jours)

**Objectif** : Intégrer LLM Streaming (OpenRouter streaming API)

**Étapes** :
1. Modifier Edge Function bobodo-chat pour streaming
2. Implémenter streaming response
3. Intégrer avec WebSocket
4. Tester streaming LLM
5. Mesurer latence première réponse

**Livrables** :
- Edge Function bobodo-chat modifiée
- Tests LLM streaming validés

**Risques** :
- Complexité streaming LLM
- Latence OpenRouter
- **Mitigation** : Tests exhaustifs, fallback non-streaming

---

### PHASE 3 : Flutter - VAD (2-3 jours)

**Objectif** : Intégrer VAD (Silero ou WebRTC)

**Étapes** :
1. Choisir VAD (Silero ou WebRTC)
2. Intégrer VAD dans Flutter
3. Implémenter détection début/fin de parole
4. Implémenter réduction bruit
5. Tester VAD sur appareil réel

**Livrables** :
- VAD intégré
- Tests VAD validés

**Risques** :
- Performance VAD sur mobile
- Consommation batterie
- **Mitigation** : Optimisations, tests appareil réel

---

### PHASE 4 : Flutter - ConversationModePage (3-4 jours)

**Objectif** : Créer ConversationModePage dédiée

**Étapes** :
1. Créer ConversationModePage
2. Implémenter boutons (Démarrer, Couper, Rejouer, Quitter)
3. Implémenter affichage états (Écoute, Traitement, Réflexion, Réponse, Lecture)
4. Intégrer VAD
5. Intégrer WebSocket streaming
6. Implémenter barge-in
7. Tester la page

**Livrables** :
- ConversationModePage créée
- Tests Flutter validés

**Risques** :
- Complexité page
- Gestion états
- **Mitigation** : Tests exhaustifs

---

### PHASE 5 : Flutter - Mémoire Conversationnelle (2-3 jours)

**Objectif** : Implémenter mémoire conversationnelle

**Étapes** :
1. Créer structure mémoire (10 derniers échanges)
2. Implémenter résumé dynamique
3. Intégrer avec Edge Function
4. Tester mémoire conversationnelle

**Livrables** :
- Mémoire conversationnelle implémentée
- Tests mémoire validés

**Risques** :
- Complexité résumé dynamique
- Latence résumé
- **Mitigation** : Tests exhaustifs

---

### PHASE 6 : Flutter - VoiceProvider Abstrait (2-3 jours)

**Objectif** : Créer VoiceProvider abstrait pour multilingue

**Étapes** :
1. Créer VoiceProvider abstrait
2. Implémenter PiperVoiceProvider
3. Préparer architecture pour Mooré, Dioula, Fulfuldé
4. Tester VoiceProvider

**Livrables** :
- VoiceProvider abstrait créé
- Tests VoiceProvider validés

**Risques** :
- Complexité architecture
- **Mitigation** : Tests exhaustifs

---

### PHASE 7 : Flutter - Fallback Réseau (2-3 jours)

**Objectif** : Implémenter fallback réseau

**Étapes** :
1. Créer système détection réseau
2. Implémenter fallback local
3. Implémenter message vocal utilisateur
4. Tester fallback

**Livrables** :
- Fallback réseau implémenté
- Tests fallback validés

**Risques** :
- Complexité fallback
- **Mitigation** : Tests exhaustifs

---

### PHASE 8 : Tests Étendus (3-4 jours)

**Objectif** : Tests étendus (réseau faible, Bluetooth, etc.)

**Étapes** :
1. Tests réseau faible
2. Tests casque Bluetooth
3. Tests haut-parleur
4. Tests stabilité
5. Mesures latence

**Livrables** :
- Tests étendus validés
- Rapport de test

**Risques** :
- Problèmes compatibilité
- **Mitigation** : Tests exhaustifs

---

### PHASE 9 : Déploiement (1-2 jours)

**Objectif** : Déployer en production

**Étapes** :
1. Déployer tts_service.py sur Kamatera
2. Déployer Edge Function bobodo-chat
3. Déployer Flutter sur Play Store (beta)
4. Monitoring
5. Validation finale

**Livrables** :
- Déploiement production validé
- Monitoring en place

**Risques** :
- Problèmes déploiement
- **Mitigation** : Rollback plan

---

## PLANNING RÉVISÉ

**Total estimé** : 20-27 jours

**Phase 1** : 3-4 jours (Serveur - Piper TTS + Streaming)
**Phase 2** : 2-3 jours (Serveur - LLM Streaming)
**Phase 3** : 2-3 jours (Flutter - VAD)
**Phase 4** : 3-4 jours (Flutter - ConversationModePage)
**Phase 5** : 2-3 jours (Flutter - Mémoire Conversationnelle)
**Phase 6** : 2-3 jours (Flutter - VoiceProvider Abstrait)
**Phase 7** : 2-3 jours (Flutter - Fallback Réseau)
**Phase 8** : 3-4 jours (Tests Étendus)
**Phase 9** : 1-2 jours (Déploiement)

---

## CRITÈRES DE SUCCÈS RÉVISÉS

1. ✅ Mode conversation implémenté
2. ✅ Cycle continu fonctionnel
3. ✅ Première réponse audio < 2s (streaming)
4. ✅ Interruption utilisateur fonctionnelle (barge-in)
5. ✅ VAD actif (Silero ou WebRTC)
6. ✅ Mémoire conversationnelle active (10 échanges)
7. ✅ VoiceProvider abstrait créé (multilingue)
8. ✅ Fallback réseau fonctionnel
9. ✅ ConversationModePage créée
10. ✅ WebSocket bidirectionnel fonctionnel
11. ✅ Tests étendus validés (réseau faible, Bluetooth)
12. ✅ Aucun impact sur Bobodo texte
13. ✅ Aucun impact sur mémoire émotionnelle
14. ✅ Aucun impact sur historique
15. ✅ Aucun impact sur RAG
16. ✅ Aucun impact sur Support Escalation

---

## SIGN-OFF

**Plan créé** : 12 Juin 2026
**Plan révisé** : 12 Juin 2026 (intégration 10 exigences complémentaires)
**Planificateur** : Cascade AI
**Statut** : PRÊT POUR IMPLÉMENTATION (révisé)
