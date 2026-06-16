# BOBODO — Audit UX Final du Mode Vocal (basé sur code Flutter actuel)

**Date**: 2025-06-15  
**Méthode**: Analyse du code Flutter réel + observations sur téléphone  
**Fichier source**: `lib/features/student/tabs/student_bobodo_tab.dart` (2018 lignes)

---

## MISSION 1 — CARTOGRAPHIE VISUELLE DE TOUS LES ÉTATS

### État 1 : ACTIVATION DU MODE VOCAL

| Attribut | Valeur réelle |
|----------|---------------|
| **Déclencheur** | Tap sur `Icons.record_voice_over` dans le header (ligne 426-434) |
| **Retour visuel immédiat** | 1. Icône header passe de blanc → bleu (ligne 429) |
| | 2. SnackBar "Conversation vocale activée. Parlez, Bobodo vous répondra." (3s) (ligne 1583-1588) |
| | 3. Bandeau persistant bleu apparaît : "Conversation vocale active — Bobodo vous répondra automatiquement à la voix." (ligne 294-312) |
| | 4. Indicateur d'état apparaît dans le header : "Parlez maintenant" + 🎤 bleu (ligne 448-452, état listening) |
| | 5. Input bar disparaît (ligne 320: `if (!_isConversationMode)`) |
| | 6. Contrôles conversation apparaissent : "❌ Quitter" (ligne 313-318) |
| **Ce que l'utilisateur entend** | Rien |
| **Widgets** | SnackBar, Container (bandeau), Container (indicateur état), TextButton.icon (contrôles) |
| **Contrôles disponibles** | "❌ Quitter" uniquement |

### État 2 : ÉCOUTE DU MICROPHONE (l'utilisateur parle)

| Attribut | Valeur réelle |
|----------|---------------|
| **Indicateur d'état** | "Parlez maintenant" + `Icons.mic` bleu (ligne 1691-1694) |
| **Bandeau persistant** | Toujours visible : "Conversation vocale active..." |
| **Feedback audio en cours** | **AUCUN** — Pas de waveform, pas de pulsation, pas d'animation |
| **Contrôles** | "❌ Quitter" uniquement |
| **Ce que l'utilisateur entend** | Sa propre voix (pas de feedback sonore de l'app) |
| **Durée** | Jusqu'à 30s max ou 3s de silence (paramètres STT natif, lignes 1313-1314) |

**⚠️ DÉFAUT** : L'utilisateur n'a AUCUNE confirmation visuelle que sa voix est captée. Le texte "Parlez maintenant" reste statique. Pas d'animation, pas de changement de couleur.

### État 3 : DÉTECTION FIN DE PAROLE

| Attribut | Valeur réelle |
|----------|---------------|
| **Déclencheur** | STT natif détecte `result.finalResult == true` (ligne 1308) |
| **Transition** | `_handleSpeechResult()` → `_onTranscriptionReceived()` |
| **Retour visuel** | Indicateur passe à "Bobodo réfléchit..." + 🧠 bleu (setState ligne 1414) |
| **Délai visible** | Instantané (transition directe de listening → thinking) |
| **Ce que l'utilisateur voit** | Le texte change dans le bandeau d'état |
| **Contrôles** | "❌ Quitter" |

**⚠️ DÉFAUT** : L'utilisateur ne voit pas son texte transcrit. Il ne sait pas si Bobodo a correctement compris ce qu'il a dit. La transcription n'est pas affichée visuellement avant envoi.

### État 4 : ENVOI DE LA REQUÊTE / ATTENTE RÉPONSE IA

| Attribut | Valeur réelle |
|----------|---------------|
| **Indicateur d'état** | "Bobodo réfléchit..." + `Icons.psychology` bleu (ligne 1701-1704) |
| **Sous-titre header** | "En train de réfléchir..." (ligne 406) |
| **Zone messages** | Bulle utilisateur visible + typing indicator (shimmer 3 points) |
| **Durée** | 3-15 secondes (réseau + OpenRouter) |
| **Contrôles** | "❌ Quitter" |
| **Ce que l'utilisateur entend** | Rien |

### État 5 : RÉPONSE VOCALE (TTS EN COURS)

| Attribut | Valeur réelle |
|----------|---------------|
| **Indicateur d'état** | "Bobodo parle..." + `Icons.volume_up` bleu (ligne 1711-1714) |
| **Zone messages** | Bulle bot avec texte de la réponse visible |
| **Audio** | FlutterTts Google fr-FR lit le texte (lignes 1518-1523) |
| **Contrôles** | "❌ Quitter" + "⏹ Couper" (car `_isSpeaking == true`, ligne 1758) |
| **Ce que l'utilisateur entend** | **Voix Google TTS en français** |

### État 6 : RETOUR À L'ÉCOUTE (après fin TTS)

| Attribut | Valeur réelle |
|----------|---------------|
| **Déclencheur** | `_speakWithLocalTts()` termine → `_onAudioPlaybackComplete()` (ligne 1524-1525) |
| **Indicateur d'état** | Revient à "Parlez maintenant" + 🎤 bleu (ligne 1637) |
| **Contrôles** | "❌ Quitter" (bouton "Couper" disparaît) |
| **Ce que l'utilisateur entend** | Silence |
| **Notification de reprise** | **Texte "Parlez maintenant" uniquement** — pas de son, pas de vibration |

**⚠️ DÉFAUT** : La transition TTS terminé → "Parlez maintenant" est silencieuse. L'utilisateur peut ne pas remarquer qu'il doit reparler, surtout s'il ne regarde pas l'écran.

### État 7 : ARRÊT MANUEL (quitter)

| Attribut | Valeur réelle |
|----------|---------------|
| **Déclencheur** | Tap sur "❌ Quitter" (TextButton.icon, ligne 1751-1754) |
| **Action** | `_quitConversation()` : `_isConversationMode = false`, arrêt STT, arrêt TTS (ligne 1609-1617) |
| **Résultat visuel** | Retour complet au mode texte : input bar réapparaît, bandeau disparaît, indicateur disparaît |
| **Contrôles** | Input bar standard avec emoji + champ + micro + envoi |

### État 8 : SORTIE AUTOMATIQUE (inactivité 30s)

| Attribut | Valeur réelle |
|----------|---------------|
| **Déclencheur** | Timer 30s sans parole (ligne 1646-1651) |
| **Action** | `_conversationState = idle` → arrêt écoute |
| **Résultat visuel** | Indicateur passe à "En attente" + ⏳ gris |
| **Contrôles** | "❌ Quitter" reste visible |
| **Problème** | L'utilisateur reste en mode conversation mais plus d'écoute. Il doit quitter et réactiver. |

### État 9 : ERREUR RÉSEAU

| Attribut | Valeur réelle |
|----------|---------------|
| **Quand** | `sendUserMessage()` échoue (HTTP error ou network) |
| **Indicateur** | `provider.error != null` → barre rouge avec message d'erreur (ligne 292-293) |
| **Comportement mode conversation** | L'écoute est relancée automatiquement (lignes 1444-1461) |
| **Contrôles** | "❌ Quitter" + barre d'erreur avec "Réessayer" |

### État 10 : ERREUR D'ENREGISTREMENT

| Attribut | Valeur réelle |
|----------|---------------|
| **Quand** | `_speechToText.listen()` échoue ou n'est pas disponible |
| **Action** | `_onVocalError()` → SnackBar avec message d'erreur (ligne 1554-1562) |
| **État résultant** | `_isRecordingMode = false` — retour silencieux au mode texte |
| **Problème** | En mode conversation, l'erreur STT ne relance pas forcément l'écoute |

---

## MISSION 2 — COMPRÉHENSION UTILISATEUR

### Question : Un étudiant qui ouvre Bobodo pour la première fois peut-il comprendre seul comment utiliser le mode conversation vocale ?

## NON.

### Justification par points :

| # | Problème | Impact |
|---|----------|--------|
| 1 | **Le bouton d'activation n'est pas reconnaissable** | L'icône `record_voice_over` est petite (20px), blanche sur fond bleu, noyée parmi 4 autres boutons blancs identiques en taille. Aucun utilisateur ne comprend spontanément que ce bouton déclenche un mode conversation vocale continue. |
| 2 | **Le tooltip nécessite un long press** | "Conversation vocale" n'est visible qu'au long press. Sur Android, très peu d'utilisateurs font un long press sur un bouton d'action. |
| 3 | **Le SnackBar disparaît après 3s** | L'instruction "Parlez, Bobodo vous répondra" est visible 3 secondes seulement. Si l'utilisateur ne lit pas immédiatement, l'information est perdue. |
| 4 | **"Parlez maintenant" n'est pas assez explicite** | L'utilisateur ne sait pas : combien de temps parler, comment arrêter, si Bobodo l'entend. |
| 5 | **Aucun feedback audio d'écoute** | Pendant l'écoute, RIEN ne confirme visuellement/auditivement que la voix est captée. Pas de waveform, pas d'animation. |
| 6 | **La transcription n'est pas montrée** | L'utilisateur ne voit jamais ce que Bobodo a "compris". Il passe directement de "Parlez maintenant" à "Bobodo réfléchit..." sans voir le texte transcrit. |
| 7 | **La reprise d'écoute est silencieuse** | Après la réponse vocale de Bobodo, le retour à "Parlez maintenant" est silencieux. Si l'utilisateur ne regarde pas l'écran, il ne sait pas que c'est son tour. |

---

## MISSION 3 — RETOURS VISUELS

| Action de l'utilisateur | Retour visuel reçu | Suffisant ? |
|------------------------|---------------------|:-----------:|
| Active le mode vocal | SnackBar 3s + bandeau + indicateur "Parlez maintenant" | ⚠️ Partiel — SnackBar éphémère |
| Commence à parler | **Aucun changement visuel** | ❌ Insuffisant |
| Continue à parler | **Aucun changement visuel** (texte reste "Parlez maintenant") | ❌ Insuffisant |
| Termine sa phrase | Indicateur passe à "Bobodo réfléchit..." | ✅ Clair |
| Attend Bobodo | Typing indicator (shimmer 3 points) + "Bobodo réfléchit..." | ✅ Clair |
| Reçoit réponse vocale | "Bobodo parle..." + voix audible + bouton "Couper" apparaît | ✅ Clair |
| Doit reprendre la parole | "Parlez maintenant" réapparaît silencieusement | ⚠️ Insuffisant sans signal audio |

### Étapes où l'utilisateur peut penser que l'app est bloquée

1. **Pendant l'écoute** : Aucun feedback → l'utilisateur peut croire que l'app ne fonctionne pas
2. **Après le TTS** : Si l'utilisateur ne regarde pas l'écran, il ne sait pas que l'écoute a repris
3. **Après 30s d'inactivité** : L'état passe à "En attente" sans explication → l'utilisateur est perdu

---

## MISSION 4 — CONTRÔLES DISPONIBLES

| Contrôle | Existe | Visible | Compréhensible | Accessible |
|----------|:------:|:-------:|:--------------:|:----------:|
| Quitter la conversation | ✅ | ✅ (toujours) | ✅ "❌ Quitter" avec label | ✅ |
| Couper la réponse vocale | ✅ | ✅ (si TTS actif) | ✅ "⏹ Couper" avec label | ✅ |
| Reprendre (après pause) | ✅ | ✅ (si paused) | ✅ "▶ Reprendre" avec label | ✅ |
| Arrêter l'écoute manuellement | ❌ | ❌ | — | — |
| Envoyer immédiatement | ❌ | ❌ | — | — |
| Annuler une écoute en cours | ❌ | ❌ | — | — |
| Relancer une écoute manuellement | ❌ | ❌ | — | — |

**Manques critiques** :
- **Pas de bouton "Stop/Envoyer"** : L'utilisateur ne peut pas décider quand arrêter de parler et envoyer. Il doit attendre 3s de silence.
- **Pas de bouton "Annuler"** : Si l'utilisateur a mal parlé, il ne peut pas annuler avant envoi.
- **Pas de bouton "Reparler"** : Si l'état est "idle" (inactivité), l'utilisateur ne peut pas relancer l'écoute sans quitter et réactiver le mode.

---

## MISSION 5 — COHÉRENCE DES TROIS MODES

### MODE 1 : Texte → texte

| Attribut | Valeur |
|----------|--------|
| **Déclencheur** | Tap dans le champ texte + tap bouton envoi |
| **Parcours** | Tape → Envoi (➤) → Typing indicator → Réponse texte |
| **Indicateurs** | Bouton envoi activé/désactivé + typing indicator |
| **Contrôles** | Bouton envoi, clavier |
| **Risque confusion** | Aucun — mode naturel et standard |

### MODE 2 : Voix → texte

| Attribut | Valeur |
|----------|--------|
| **Déclencheur** | Tap micro bleu 🎤 dans l'input bar (ligne 1092-1098) |
| **Parcours** | Micro → Waveform + chrono → Stop/Annuler → Texte dans champ → Édition → Envoi |
| **Indicateurs** | Waveform animé + chrono + "Transcription en cours..." |
| **Contrôles** | Stop ⏹ + Annuler ❌ |
| **Risque confusion** | ⚠️ L'utilisateur peut confondre ce micro avec le micro header |

### MODE 3 : Conversation vocale continue

| Attribut | Valeur |
|----------|--------|
| **Déclencheur** | Tap icône 👤🔊 (`record_voice_over`) dans le header (ligne 426-434) |
| **Parcours** | Activation → "Parlez maintenant" → (silence 3s) → "Bobodo réfléchit..." → "Bobodo parle..." → "Parlez maintenant" → boucle |
| **Indicateurs** | Bandeau + indicateur d'état + SnackBar initial |
| **Contrôles** | "Quitter" + "Couper" (pendant TTS) |
| **Risque confusion** | 🔴 ÉLEVÉ — voir ci-dessous |

### Risques de confusion entre les modes

| Confusion | Probabilité | Cause |
|-----------|:-----------:|-------|
| Micro input bar confondu avec micro header | **Élevée** | Deux icônes de microphone à l'écran (même si différentes). L'utilisateur peut taper sur le mauvais. |
| Mode 2 activé accidentellement pendant Mode 3 | **Impossible** | Input bar cachée en mode conversation |
| Mode 3 activé sans comprendre | **Élevée** | Bouton header petit, pas de label, tooltip au long press uniquement |
| Confusion entre "Parlez maintenant" et dictée | **Moyenne** | L'utilisateur ne comprend pas forcément que ce mode boucle automatiquement |

---

## MISSION 6 — PLAN DE CORRECTION

### Défauts UX BLOQUANTS

| # | Défaut | Impact utilisateur |
|---|--------|-------------------|
| B1 | **Aucun feedback visuel pendant l'écoute** | L'utilisateur ne sait pas si l'app capte sa voix |
| B2 | **Pas de signal de reprise après TTS** | L'utilisateur ne sait pas quand reparler (surtout s'il ne regarde pas l'écran) |
| B3 | **Transcription non montrée** | L'utilisateur ne peut pas vérifier si Bobodo a bien compris |

### Défauts UX MAJEURS

| # | Défaut | Impact utilisateur |
|---|--------|-------------------|
| M1 | **Pas de bouton pour arrêter l'écoute et envoyer** | L'utilisateur doit attendre 3s de silence — frustrant |
| M2 | **SnackBar éphémère comme seule instruction** | L'instruction d'utilisation disparaît en 3s |
| M3 | **État "idle" après 30s sans possibilité de relancer** | L'utilisateur doit quitter et réactiver |
| M4 | **Bouton d'activation non identifiable** | Icône 20px blanche parmi 4 boutons identiques |

### Défauts UX MINEURS

| # | Défaut | Impact |
|---|--------|--------|
| m1 | Tooltip visible uniquement au long press | Information cachée |
| m2 | Pas de distinction de taille entre micro header et autres boutons | Hiérarchie visuelle plate |

### Recommandations de correction

| # | Correction | Priorité | Lignes estimées |
|---|-----------|----------|-----------------|
| R1 | **Ajouter une animation pulsante pendant l'écoute** : cercle pulsant autour de l'icône 🎤 dans l'indicateur d'état | Bloquant | ~15 lignes |
| R2 | **Ajouter un bip/vibration à la reprise d'écoute** : `HapticFeedback.mediumImpact()` quand l'état repasse à listening | Bloquant | ~3 lignes |
| R3 | **Montrer le texte transcrit brièvement** : Afficher dans une bulle temporaire ou dans l'indicateur d'état le texte reconnu avant d'envoyer | Bloquant | ~10 lignes |
| R4 | **Ajouter un bouton "Envoyer" pendant l'écoute** : Permettre à l'utilisateur d'arrêter l'écoute et d'envoyer immédiatement sans attendre 3s | Majeur | ~8 lignes |
| R5 | **Remplacer le SnackBar par un dialog ou un bandeau d'instruction permanent** : Le bandeau actuel dit "Conversation vocale active" mais pas COMMENT l'utiliser | Majeur | ~5 lignes (modifier le texte du bandeau) |
| R6 | **Ajouter un bouton "Reparler" quand état idle** : Visible dans les contrôles quand `_conversationState == idle` | Majeur | ~6 lignes |
| R7 | **Augmenter la taille/distinction du bouton header** : Ajouter un badge ou une couleur distinctive même quand inactif | Mineur | ~5 lignes |

### Estimation totale

| Métrique | Valeur |
|----------|--------|
| Fichiers concernés | 1 (`student_bobodo_tab.dart`) |
| Lignes estimées ajoutées | ~50 |
| Lignes estimées modifiées | ~10 |
| Risque de régression | **Faible** — modifications visuelles uniquement |
| Dépendances ajoutées | 0 |
| Changement backend | 0 |

### Priorité de correction recommandée

**Phase 1 (critique — résout les 3 bloquants)** :
- R2 : Vibration à la reprise (3 lignes)
- R3 : Afficher texte transcrit (10 lignes)
- R5 : Améliorer texte du bandeau persistant (5 lignes)

**Phase 2 (majeur — améliore l'usabilité)** :
- R4 : Bouton "Envoyer" pendant l'écoute (8 lignes)
- R6 : Bouton "Reparler" en état idle (6 lignes)

**Phase 3 (cosmétique — polish)** :
- R1 : Animation pulsante (15 lignes)
- R7 : Badge ou couleur distinctive sur bouton header (5 lignes)

---

**En attente de validation et sélection des corrections à implémenter.**

*Aucune modification effectuée. Aucun commit.*
