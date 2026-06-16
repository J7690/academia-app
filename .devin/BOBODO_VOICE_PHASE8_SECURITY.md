# BOBODO VOCAL - PHASE 8 : SÉCURITÉ ET CONFIDENTIALITÉ

**Date** : 10 juin 2026  
**Statut** : ✅ TERMINÉ

---

## CONFIDENTIALITÉ DES DONNÉES

### Audio utilisateur

**Capture** :
- Données : Audio brut (WAV 16kHz mono)
- Transmission : WebSocket chiffré (TLS 1.3)
- Stockage : **Aucun stockage** (traitement en mémoire uniquement)
- Conservation : **Éphémère** (suppression immédiate après traitement)

**Justification** :
- Conformité RGPD (minimisation des données)
- Protection vie privée (pas de conservation audio)
- Réduction risque fuite de données

---

### Texte transcrit (STT)

**Données** : Texte transcrit de l'audio
- Transmission : HTTP POST chiffré (TLS 1.3) vers Edge Function
- Stockage : **Aucun stockage dédié** (intégré dans conversation Bobodo existante)
- Conservation : **Conforme Bobodo** (historique conversationnel existant)

**Justification** :
- Réutilisation architecture existante (bobodo_messages)
- Conformité RGPD (conservation limitée)
- Traçabilité (audit logs)

---

### Réponse IA (LLM)

**Données** : Texte réponse générée
- Transmission : HTTP POST chiffré (TLS 1.3) depuis Edge Function
- Stockage : **Aucun stockage dédié** (intégré dans conversation Bobodo existante)
- Conservation : **Conforme Bobodo** (historique conversationnel existant)

**Justification** :
- Réutilisation architecture existante (bobodo_messages)
- Conformité RGPD (conservation limitée)
- Traçabilité (audit logs)

---

### Audio synthétisé (TTS)

**Données** : Audio généré (WAV/MP3)
- Transmission : WebSocket chiffré (TLS 1.3)
- Stockage : **Aucun stockage** (traitement en mémoire uniquement)
- Conservation : **Éphémère** (suppression immédiate après playback)

**Justification** :
- Conformité RGPD (minimisation des données)
- Protection vie privée (pas de conservation audio)
- Réduction risque fuite de données

---

## CONFORMITÉ BOBODO

### Politique existante

**Conversation Bobodo** :
- Historique stocké dans `bobodo_messages`
- Conservation : 90 jours (configurable)
- Accès : Étudiant (propres messages), Admin (tous)
- RLS : Restriction par student_id

**Audit logs** :
- Table `admin_audit_log`
- Actions : création, modification, suppression
- Accès : Admin uniquement

**Feedback utilisateur** :
- Table `bobodo_feedback` (optionnel)
- Notation : up/down
- Commentaire : optionnel

---

### Adaptation pour Bobodo Vocal

**Aucune modification requise** :
- Audio non stocké (conforme minimisation)
- Texte intégré dans conversation existante
- Historique conversationnel déjà conforme
- Audit logs déjà en place

**Nouvelles métriques** (optionnel) :
- Mode vocal utilisé (oui/non)
- Durée moyenne message vocal
- Taux d'erreur STT/TTS
- Latence moyenne

---

## RISQUES ET MITIGATIONS

### Risque 1 : Interception audio

**Risque** : Interception audio pendant transmission
- Probabilité : Faible (TLS 1.3)
- Impact : Élevé (données sensibles)

**Mitigation** :
- ✅ WebSocket chiffré (TLS 1.3)
- ✅ Certificat SSL valide
- ✅ HSTS activé
- ✅ Rotation clés automatique

---

### Risque 2 : Fuite de données serveur

**Risque** : Accès non autorisé au serveur vocal
- Probabilité : Faible (SSH + firewall)
- Impact : Élevé (audio en mémoire)

**Mitigation** :
- ✅ SSH key-based auth
- ✅ Firewall UFW restrictif
- ✅ Pas de stockage audio (données éphémères)
- ✅ Logs anonymisés (pas de contenu audio)

---

### Risque 3 : Injection audio malveillante

**Risque** : Audio contenant commandes malveillantes
- Probabilité : Très faible (STT texte uniquement)
- Impact : Faible (pas d'exécution de code)

**Mitigation** :
- ✅ STT produit texte uniquement (pas d'exécution)
- ✅ Edge Function bobodo-chat valide input
- ✅ Rate limiting (prévention DoS)
- ✅ Sanitization input

---

### Risque 4 : Replay attack

**Risque** : Réutilisation audio enregistré
- Probabilité : Faible (authentification requise)
- Impact : Moyen (usurpation identité)

**Mitigation** :
- ✅ Authentification Supabase JWT requise
- ✅ Token expiration (1h)
- ✅ Rate limiting par utilisateur
- ✅ Détection patterns anormaux

---

### Risque 5 : Surcharge serveur (DoS)

**Risque** : Attaque par surcharge
- Probabilité : Moyenne (service public)
- Impact : Élevé (indisponibilité)

**Mitigation** :
- ✅ Rate limiting (100 req/min par utilisateur)
- ✅ Limite connexions simultanées (50)
- ✅ Auto-scaling (optionnel)
- ✅ Monitoring + alertes

---

### Risque 6 : Fuite modèle STT/TTS

**Risque** : Extraction de modèle IA
- Probabilité : Très faible (accès restreint)
- Impact : Faible (modèles open-source)

**Mitigation** :
- ✅ Modèles open-source (Whisper, Piper)
- ✅ Pas de secrets dans modèles
- ✅ Accès SSH restreint
- ✅ Monitoring accès

---

## CONFORMITÉ RGPD

### Principes RGPD

**Minimisation des données** :
- ✅ Audio non stocké (traitement éphémère)
- ✅ Texte intégré dans conversation existante
- ✅ Pas de données superflues

**Finalité limitée** :
- ✅ Audio : transcription uniquement
- ✅ Texte : réponse Bobodo uniquement
- ✅ Pas de réutilisation à d'autres fins

**Conservation limitée** :
- ✅ Audio : suppression immédiate
- ✅ Texte : 90 jours (conforme Bobodo)
- ✅ Logs : 30 jours

**Sécurité** :
- ✅ TLS 1.3 (transmission)
- ✅ SSH key-based (accès serveur)
- ✅ RLS (accès base de données)
- ✅ Audit logs (traçabilité)

**Droits utilisateur** :
- ✅ Accès historique (Bobodo existant)
- ✅ Suppression conversation (Bobodo existant)
- ✅ Export données (Bobodo existant)

---

## POLITIQUE DE CONSERVATION

### Audio

**Capture** :
- Stockage : Aucun
- Conservation : Éphémère (RAM uniquement)
- Suppression : Immédiate après traitement

**Synthèse** :
- Stockage : Aucun
- Conservation : Éphémère (RAM uniquement)
- Suppression : Immédiate après playback

---

### Texte

**Transcription** :
- Stockage : `bobodo_messages` (existante)
- Conservation : 90 jours
- Suppression : Automatique après 90 jours

**Réponse** :
- Stockage : `bobodo_messages` (existante)
- Conservation : 90 jours
- Suppression : Automatique après 90 jours

---

### Logs

**Application** :
- Stockage : `admin_audit_log` (existante)
- Conservation : 30 jours
- Suppression : Automatique après 30 jours

**Système** :
- Stockage : `/var/log/` (serveur)
- Conservation : 7 jours
- Suppression : Automatique (logrotate)

---

## CONSENTEMENT UTILISATEUR

### Premier lancement

**Message** :
```
Bobodo Vocal utilise ton microphone pour transcrire tes questions 
et te répondre par audio. Tes données audio ne sont pas stockées 
et sont traitées de manière sécurisée.

En activant le mode vocal, tu acceptes notre politique de confidentialité.

[Accepter] [Refuser]
```

**Persistance** :
- Préférence stockée localement (SharedPreferences)
- Possibilité de modifier ultérieurement
- Mode silencieux disponible (pas de TTS)

---

## AUDIT ET COMPLIANCE

### Audit interne

**Fréquence** : Trimestriel
- Vérification logs d'accès
- Analyse patterns anormaux
- Test vulnérabilités
- Review politique conservation

### Audit externe (optionnel)

**Fréquence** : Annuel
- Audit sécurité tiers
- Test pénétration
- Review conformité RGPD
- Certification ISO 27001 (optionnel)

---

## DOCUMENTATION UTILISATEUR

### Politique de confidentialité (mise à jour)

**Section à ajouter** :
```
Bobodo Vocal

Bobodo Vocal utilise ton microphone pour transcrire tes questions 
et te répondre par audio. Tes données audio ne sont pas stockées 
et sont traitées de manière sécurisée.

- Capture audio : éphémère (non stockée)
- Transcription : intégrée dans conversation Bobodo (90 jours)
- Synthèse audio : éphémère (non stockée)
- Transmission : chiffrée (TLS 1.3)

Tu peux désactiver le mode vocal à tout moment dans les paramètres.
```

---

## CONCLUSION

**Conformité** : ✅ Conforme RGPD
- Minimisation des données
- Conservation limitée
- Sécurité renforcée
- Droits utilisateur respectés

**Risques** : ✅ Mitigés
- Interception : TLS 1.3
- Fuite : Pas de stockage audio
- Injection : Validation input
- Replay : Authentification JWT
- DoS : Rate limiting

**Recommandation** : ✅ Déploiement autorisé
- Architecture sécurisée
- Politique conservation conforme
- Audit et monitoring en place
- Documentation utilisateur complète

---

**RAPPORT PHASE 8 TERMINÉ**
