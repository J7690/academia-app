# BOBODO VOICE - Test Plan

## Date
12 Juin 2026

---

## OBJECTIF

Documenter le plan de tests pour le mode conversation vocale continue.

---

## ENVIRONNEMENT DE TEST

### Appareil

**Appareil** : Android (réel)

**OS** : Android 10+

**RAM** : 4GB+

**Stockage** : 32GB+

**Microphone** : Fonctionnel

**Haut-parleur** : Fonctionnel

---

### Réseau

**Type** : WiFi ou 4G

**Latence** : < 100ms

**Stabilité** : Stable

---

## TESTS SERVEUR

### Test 1 : Installation Piper TTS

**Objectif** : Valider l'installation Piper TTS

**Étapes** :
1. SSH sur Kamatera
2. Exécuter `pip install piper-tts`
3. Vérifier installation `pip show piper-tts`
4. Installer espeak-ng
5. Vérifier installation `espeak-ng --version`

**Critère de succès** :
- ✅ Piper TTS installé sans erreur
- ✅ espeak-ng installé sans erreur

---

### Test 2 : Téléchargement Voix Française

**Objectif** : Valider le téléchargement de la voix française

**Étapes** :
1. Créer dossier `/root/piper_voices`
2. Télécharger fr_FR-siwis-medium.onnx
3. Télécharger fr_FR-siwis-medium.onnx.json
4. Vérifier fichiers existants
5. Vérifier taille fichiers (> 0)

**Critère de succès** :
- ✅ Fichiers téléchargés
- ✅ Taille fichiers > 0

---

### Test 3 : Génération Audio

**Objectif** : Valider la génération audio avec Piper

**Étapes** :
1. Exécuter script test
2. Générer audio pour "Bonjour, je suis Bobodo."
3. Sauvegarder fichier `/tmp/test_piper.wav`
4. Vérifier fichier généré
5. Écouter fichier audio

**Critère de succès** :
- ✅ Fichier audio généré
- ✅ Audio intelligible
- ✅ Voix française claire

---

### Test 4 : Latence

**Objectif** : Valider la latence de génération audio

**Étapes** :
1. Exécuter script test latence
2. Mesurer temps génération pour 10 phrases
3. Calculer latence moyenne
4. Calculer latence max
5. Calculer latence min

**Critère de succès** :
- ✅ Latence moyenne < 1s
- ✅ Latence max < 3s

---

### Test 5 : Fallback gTTS

**Objectif** : Valider le fallback gTTS

**Étapes** :
1. Simuler erreur Piper
2. Vérifier fallback gTTS activé
3. Générer audio avec gTTS
4. Vérifier fichier généré

**Critère de succès** :
- ✅ Fallback gTTS fonctionnel
- ✅ Audio généré

---

### Test 6 : WebSocket

**Objectif** : Valider l'intégration WebSocket

**Étapes** :
1. Démarrer serveur WebSocket
2. Connecter client WebSocket
3. Envoyer message texte
4. Recevoir réponse audio
5. Vérifier audio base64
6. Décoder audio
7. Écouter audio

**Critère de succès** :
- ✅ WebSocket connecté
- ✅ Message reçu
- ✅ Audio reçu
- ✅ Audio décodable
- ✅ Audio intelligible

---

## TESTS FLUTTER

### Test 1 : Toggle Mode Dictée / Mode Conversation

**Objectif** : Valider le toggle mode dictée/conversation

**Étapes** :
1. Ouvrir écran Bobodo
2. Cliquer sur toggle mode
3. Vérifier état "Mode Conversation"
4. Cliquer sur toggle mode
5. Vérifier état "Mode Dictée"

**Critère de succès** :
- ✅ Toggle fonctionnel
- ✅ État correct affiché

---

### Test 2 : Machine d'états Conversationnelle

**Objectif** : Valider la machine d'états

**Étapes** :
1. Activer mode conversation
2. Vérifier état "idle"
3. Démarrer enregistrement
4. Vérifier état "listening"
5. Arrêter enregistrement
6. Vérifier état "processing"
7. Recevoir transcription
8. Vérifier état "thinking"
9. Recevoir réponse
10. Vérifier état "responding"
11. Recevoir audio
12. Vérifier état "playing"
13. Fin lecture
14. Vérifier état "listening" (réactivation auto)

**Critère de succès** :
- ✅ Transitions d'états correctes
- ✅ États affichés correctement

---

### Test 3 : Réactivation Automatique du Micro

**Objectif** : Valider la réactivation automatique

**Étapes** :
1. Activer mode conversation
2. Enregistrer message
3. Recevoir réponse
4. Attendre fin lecture
5. Vérifier réactivation automatique
6. Vérifier enregistrement redémarré

**Critère de succès** :
- ✅ Réactivation automatique fonctionnelle
- ✅ Enregistrement redémarré

---

### Test 4 : Bouton Quitter Conversation

**Objectif** : Valider le bouton quitter conversation

**Étapes** :
1. Activer mode conversation
2. Cliquer bouton "Quitter Conversation"
3. Vérifier arrêt enregistrement
4. Vérifier arrêt audio
5. Vérifier retour mode dictée

**Critère de succès** :
- ✅ Arrêt enregistrement
- ✅ Arrêt audio
- ✅ Retour mode dictée

---

### Test 5 : Bouton Couper Bobodo

**Objectif** : Valider le bouton couper Bobodo

**Étapes** :
1. Activer mode conversation
2. Enregistrer message
3. Recevoir réponse
4. Attendre début lecture
5. Cliquer bouton "Couper"
6. Vérifier arrêt audio
7. Vérifier état "paused"

**Critère de succès** :
- ✅ Arrêt audio
- ✅ État "paused"

---

### Test 6 : Bouton Rejouer Dernière Réponse

**Objectif** : Valider le bouton rejouer

**Étapes** :
1. Activer mode conversation
2. Enregistrer message
3. Recevoir réponse
4. Attendre fin lecture
5. Cliquer bouton "Rejouer"
6. Vérifier relecture audio
7. Vérifier état "playing"

**Critère de succès** :
- ✅ Relecture audio
- ✅ État "playing"

---

### Test 7 : Affichage des États

**Objectif** : Valider l'affichage des états

**Étapes** :
1. Activer mode conversation
2. Vérifier affichage "En attente"
3. Démarrer enregistrement
4. Vérifier affichage "Écoute..."
5. Arrêter enregistrement
6. Vérifier affichage "Traitement..."
7. Recevoir transcription
8. Vérifier affichage "Bobodo réfléchit..."
9. Recevoir réponse
10. Vérifier affichage "Réponse..."
11. Recevoir audio
12. Vérifier affichage "Lecture..."
13. Cliquer couper
14. Vérifier affichage "Pause"
15. Cliquer quitter
16. Vérifier affichage "Session terminée"

**Critère de succès** :
- ✅ États affichés correctement
- ✅ Icônes correctes
- ✅ Couleurs correctes

---

## TESTS INTERRUPTIONS

### Test 1 : Utilisateur Coupe Bobodo

**Objectif** : Valider l'interruption par utilisateur

**Étapes** :
1. Activer mode conversation
2. Enregistrer message
3. Recevoir réponse
4. Attendre début lecture
5. Cliquer bouton "Couper"
6. Vérifier arrêt audio
7. Vérifier état "paused"
8. Cliquer bouton "Reprendre"
9. Vérifier reprise enregistrement

**Critère de succès** :
- ✅ Arrêt audio
- ✅ État "paused"
- ✅ Reprise enregistrement

---

### Test 2 : Utilisateur Quitte Écran

**Objectif** : Valider l'interruption par sortie écran

**Étapes** :
1. Activer mode conversation
2. Enregistrer message
3. Recevoir réponse
4. Attendre début lecture
5. Quitter écran Bobodo
6. Revenir écran Bobodo
7. Vérifier arrêt enregistrement
8. Vérifier arrêt audio
9. Vérifier retour mode dictée

**Critère de succès** :
- ✅ Arrêt enregistrement
- ✅ Arrêt audio
- ✅ Retour mode dictée

---

### Test 3 : Perte Internet

**Objectif** : Valider la gestion perte Internet

**Étapes** :
1. Activer mode conversation
2. Enregistrer message
3. Couper Internet
4. Vérifier affichage "Connexion perdue"
5. Vérifier état "paused"
6. Rétablir Internet
7. Vérifier reconnexion WebSocket
8. Vérifier reprise enregistrement

**Critère de succès** :
- ✅ Affichage "Connexion perdue"
- ✅ État "paused"
- ✅ Reconnexion WebSocket
- ✅ Reprise enregistrement

---

### Test 4 : Retour Internet

**Objectif** : Valider la reprise après retour Internet

**Étapes** :
1. Activer mode conversation
2. Couper Internet
3. Attendre 5 secondes
4. Rétablir Internet
5. Vérifier reconnexion automatique
6. Vérifier reprise enregistrement

**Critère de succès** :
- ✅ Reconnexion automatique
- ✅ Reprise enregistrement

---

### Test 5 : Timeout Inactivité

**Objectif** : Valider le timeout d'inactivité

**Étapes** :
1. Activer mode conversation
2. Démarrer enregistrement
3. Ne pas parler pendant 30 secondes
4. Vérifier arrêt enregistrement
5. Vérifier état "idle"
6. Vérifier affichage "Session en pause"
7. Parler
8. Vérifier reprise enregistrement

**Critère de succès** :
- ✅ Arrêt enregistrement
- ✅ État "idle"
- ✅ Affichage "Session en pause"
- ✅ Reprise enregistrement

---

### Test 6 : Reprise Session

**Objectif** : Valider la reprise session

**Étapes** :
1. Activer mode conversation
2. Enregistrer message
3. Recevoir réponse
4. Attendre timeout inactivité
5. Vérifier état "idle"
6. Parler
7. Vérifier reprise enregistrement
8. Vérifier envoi message

**Critère de succès** :
- ✅ Reprise enregistrement
- ✅ Envoi message

---

## TESTS NON-RÉGRESSION

### Test 1 : Mode Dictée

**Objectif** : Valider le mode dictée inchangé

**Étapes** :
1. Ouvrir écran Bobodo
2. Vérifier mode dictée par défaut
3. Cliquer bouton micro
4. Enregistrer message
5. Arrêter enregistrement
6. Vérifier transcription affichée
7. Vérifier envoi manuel requis
8. Envoyer message
9. Vérifier réponse reçue

**Critère de succès** :
- ✅ Mode dictée fonctionnel
- ✅ Transcription affichée
- ✅ Envoi manuel requis
- ✅ Réponse reçue

---

### Test 2 : Bobodo Texte

**Objectif** : Valider Bobodo texte inchangé

**Étapes** :
1. Ouvrir écran Bobodo
2. Taper message texte
3. Envoyer message
4. Vérifier réponse reçue
5. Vérifier historique
6. Vérifier mémoire émotionnelle

**Critère de succès** :
- ✅ Message envoyé
- ✅ Réponse reçue
- ✅ Historique intact
- ✅ Mémoire émotionnelle intacte

---

### Test 3 : Sessions

**Objectif** : Valider les sessions inchangées

**Étapes** :
1. Ouvrir écran Bobodo
2. Cliquer bouton sessions
3. Vérifier liste sessions
4. Sélectionner session
5. Vérifier messages chargés
6. Créer nouvelle session
7. Vérifier session créée

**Critère de succès** :
- ✅ Liste sessions affichée
- ✅ Session sélectionnée
- ✅ Messages chargés
- ✅ Nouvelle session créée

---

## TESTS APPAREIL RÉEL

### Test 1 : Installation APK

**Objectif** : Valider l'installation APK

**Étapes** :
1. Générer APK
2. Transférer APK sur appareil
3. Installer APK
4. Lancer application
5. Vérifier ouverture

**Critère de succès** :
- ✅ APK installé
- ✅ Application ouverte

---

### Test 2 : Mode Conversation

**Objectif** : Valider le mode conversation sur appareil réel

**Étapes** :
1. Ouvrir écran Bobodo
2. Activer mode conversation
3. Enregistrer message
4. Recevoir réponse
5. Écouter audio
6. Vérifier réactivation automatique
7. Enregistrer deuxième message
8. Recevoir réponse
9. Écouter audio

**Critère de succès** :
- ✅ Mode conversation fonctionnel
- ✅ Audio intelligible
- ✅ Réactivation automatique

---

### Test 3 : Mesure Latence

**Objectif** : Mesurer la latence réelle

**Étapes** :
1. Activer mode conversation
2. Enregistrer message
3. Mesurer temps transcription
4. Mesurer temps réponse
5. Mesurer temps audio
6. Calculer latence totale

**Critère de succès** :
- ✅ Latence transcription < 2s
- ✅ Latence réponse < 2s
- ✅ Latence audio < 1s
- ✅ Latence totale < 3s

---

### Test 4 : Stabilité

**Objectif** : Valider la stabilité

**Étapes** :
1. Activer mode conversation
2. Effectuer 10 échanges
3. Vérifier absence crash
4. Vérifier absence freeze
5. Vérifier absence memory leak

**Critère de succès** :
- ✅ Aucun crash
- ✅ Aucun freeze
- ✅ Aucun memory leak

---

## RAPPORT DE TEST

### Template

```markdown
# Test Report - Bobodo Voice V1

## Date
[Date]

## Testeur
[Nom]

## Appareil
[Modèle]
[OS]
[RAM]

## Résultats Tests Serveur

### Test 1 : Installation Piper TTS
- Statut : ✅ / ❌
- Notes : [...]

### Test 2 : Téléchargement Voix Française
- Statut : ✅ / ❌
- Notes : [...]

[...]

## Résultats Tests Flutter

### Test 1 : Toggle Mode Dictée / Mode Conversation
- Statut : ✅ / ❌
- Notes : [...]

[...]

## Résultats Tests Interruptions

### Test 1 : Utilisateur Coupe Bobodo
- Statut : ✅ / ❌
- Notes : [...]

[...]

## Résultats Tests Non-Régression

### Test 1 : Mode Dictée
- Statut : ✅ / ❌
- Notes : [...]

[...]

## Résultats Tests Appareil Réel

### Test 1 : Installation APK
- Statut : ✅ / ❌
- Notes : [...]

[...]

## Mesures Latence

- Latence transcription moyenne : [X]s
- Latence réponse moyenne : [X]s
- Latence audio moyenne : [X]s
- Latence totale moyenne : [X]s

## Conclusion

- Statut global : ✅ / ❌
- Recommandation : [...]
```

---

## CRITÈRES DE VALIDATION

### Critères Serveur
1. ✅ Piper TTS installé
2. ✅ Voix française téléchargée
3. ✅ Génération audio fonctionnelle
4. ✅ Latence < 3s
5. ✅ Fallback gTTS fonctionnel
6. ✅ WebSocket intégré

### Critères Flutter
1. ✅ Toggle mode fonctionnel
2. ✅ Machine d'états fonctionnelle
3. ✅ Réactivation automatique fonctionnelle
4. ✅ Boutons de contrôle fonctionnels
5. ✅ Affichage états fonctionnel

### Critères Interruptions
1. ✅ Utilisateur coupe Bobodo
2. ✅ Utilisateur quitte écran
3. ✅ Perte Internet
4. ✅ Retour Internet
5. ✅ Timeout inactivité
6. ✅ Reprise session

### Critères Non-Régression
1. ✅ Mode dictée inchangé
2. ✅ Bobodo texte inchangé
3. ✅ Sessions inchangées

### Critères Appareil Réel
1. ✅ Installation APK
2. ✅ Mode conversation fonctionnel
3. ✅ Latence < 3s
4. ✅ Stabilité

---

## SIGN-OFF

**Document créé** : 12 Juin 2026
**Auteur** : Cascade AI
**Statut** : PRÊT POUR TESTS
