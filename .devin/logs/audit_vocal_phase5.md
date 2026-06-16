# AUDIT FLUTTER ET SUPABASE - PHASE 5 INTÉGRATION VOCAL

**Date** : 10 juin 2026  
**Objectif** : Audit préalable à l'intégration vocale Flutter

---

## AUDIT FLUTTER

### Fichiers existants liés au vocal
- `lib/services/bobodo_vocal_service.dart` - Service WebSocket pour Bobodo Vocal
- `lib/widgets/bobodo_vocal_button.dart` - Bouton microphone pour Bobodo Vocal

### Packages audio installés
- `record: ^6.1.2` - Enregistrement audio
- `audioplayers: ^6.0.0` - Lecture audio
- `just_audio: ^0.9.36` - Lecture audio avancée
- `ffmpeg_kit_flutter_new_audio: ^2.0.0` - Traitement audio

### Permissions Android
- `android.permission.RECORD_AUDIO` - ✅ Configurée

### Autres fichiers audio (119 fichiers)
- `lib/features/student/community_audio_recorder.dart`
- `lib/services/studio_audio_service.dart`
- `lib/video/audio_mix_service.dart`
- `lib/widgets/audio_picker_sheet.dart`
- ...et 115 autres fichiers

---

## AUDIT SUPABASE

### Edge Functions
- `bobodo-chat` - ✅ ACTIVE (version 62)

### Tables liées au vocal
- Aucune table spécifique au vocal trouvée

### RPCs liées au vocal
- Aucune RPC spécifique au vocal trouvée

---

## ANALYSE

### Composants existants
1. **Service WebSocket** : `BobodoVocalService` implémenté
2. **Widget bouton** : `BobodoVocalButton` implémenté
3. **Edge Function** : `bobodo-chat` déployée

### Manque
1. **Intégration UI** : Le widget `BobodoVocalButton` n'est utilisé nulle part
2. **Tables/RPCs** : Aucune structure de données spécifique au vocal
3. **Mode hybride** : Pas de basculement texte/vocal implémenté

---

## RECOMMANDATIONS

### Phase 5 - Intégration Flutter
1. Intégrer `BobodoVocalButton` dans l'onglet Bobodo existant
2. Ajouter un mode hybride (texte/vocal) avec toggle
3. Connecter le bouton à l'Edge Function `bobodo-chat`
4. Gérer les erreurs de connexion WebSocket

### Phase 6 - Validation fonctionnelle
1. Tester la transcription STT (placeholder)
2. Tester la synthèse TTS (gTTS)
3. Tester la connexion WebSocket
4. Tester l'intégration avec bobodo-chat

---

## CONCLUSION

L'infrastructure de base est en place (service, widget, Edge Function). L'intégration UI est nécessaire pour rendre la fonctionnalité accessible aux utilisateurs.

---

**AUDIT TERMINÉ**
