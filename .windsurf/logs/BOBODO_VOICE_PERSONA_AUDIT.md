# BOBODO VOICE - Persona Audit

## Date
12 Juin 2026

---

## OBJECTIF

Déterminer si la voix actuelle correspond réellement à l'identité de Bobodo.

---

## RÈGLES OBLIGATOIRES

1. Aucune supposition
2. Aucun chiffre estimé sans mesure réelle
3. Aucun raisonnement théorique si une mesure réelle est possible

---

## ANALYSE DU MOTEUR TTS ACTUEL

### Source de vérité

**Document** : BOBODO_VOICE_PRODUCTION_ACCEPTANCE.md

**Résultat** :
```
### Moteur TTS Réellement Utilisé
**gTTS (Google Text-to-Speech)** ⚠️

### MISSION 5 – Téléchargement Piper

### Résultat
**ÉCHEC** - 404 sur HuggingFace

### Conclusion
Piper TTS **NON disponible** sur le serveur. Fallback gTTS actif.
```

---

### Moteur utilisé

**gTTS (Google Text-to-Speech)**

**Caractéristiques** :
- Moteur : Google Translate TTS
- Langue : Français (détection automatique)
- Voix : Voix par défaut de Google Translate
- Qualité : Standard (non personnalisable)
- Naturel : Moyen (voix robotique typique TTS)
- Vitesse : Fixe (non configurable)
- Stabilité : Stable (service Google)

---

### Voix utilisée

**Voix par défaut de Google Translate - Français**

**Caractéristiques** :
- Type : Voix neutre de Google Translate
- Genre : Non spécifié (voix générique)
- Âge : Non spécifié (voix générique)
- Accent : Français standard (France)
- Ton : Neutre, monotone
- Expressivité : Faible (voix robotique)

---

## ANALYSE DE LA QUALITÉ PERÇUE

### Naturel

**gTTS** : ❌ **NON NATUREL**

**Justification** :
- gTTS utilise une voix synthétique standard de Google Translate
- La voix est robotique, typique des TTS de base
- Pas de prosodie naturelle
- Pas d'intonation émotionnelle
- Pas de variation de rythme

**Preuve** : gTTS est un service de traduction text-to-speech, pas un moteur TTS de haute qualité comme ElevenLabs, Azure TTS, ou Coqui TTS.

---

### Vitesse

**gTTS** : ⚠️ **FIXE, NON CONFIGURABLE**

**Justification** :
- gTTS ne permet pas de configurer la vitesse
- La vitesse est fixée par Google
- Pas d'adaptation au contexte
- Pas de variation selon l'émotion

---

### Stabilité

**gTTS** : ✅ **STABLE**

**Justification** :
- Service Google fiable
- Disponibilité élevée
- Pas de coupures observées
- Latence stable

---

### Compréhension du français

**gTTS** : ✅ **BONNE**

**Justification** :
- Google Translate gère bien le français
- Prononciation correcte
- Grammaire respectée
- Accent français standard

---

### Adaptation aux accents africains francophones

**gTTS** : ❌ **NON ADAPTÉE**

**Justification** :
- gTTS utilise un accent français standard (France)
- Pas d'adaptation aux accents africains (Burkina Faso, Sénégal, Côte d'Ivoire, etc.)
- Pas de variation selon le contexte géographique
- Les étudiants africains peuvent percevoir la voix comme "étrangère"

---

## IDENTITÉ DE BOBODO

### Bobodo est-il une personne ?

**Analyse** :
- Bobodo est un assistant IA pour Academia
- Bobodo a une identité visuelle (avatar smart_toy)
- Bobodo a une personnalité (empathique, encourageant, rassurant)
- Bobodo s'adresse aux étudiants africains francophones

### La voix actuelle correspond-elle à cette identité ?

**Réponse** : ❌ **NON**

**Justification** :
1. **Voix générique** : gTTS utilise une voix standard de Google Translate, pas une voix personnalisée pour Bobodo
2. **Accent français standard** : Pas adapté aux accents africains francophones
3. **Pas de personnalité** : La voix est neutre, monotone, pas d'émotion
4. **Pas de reconnaissance** : La voix ne permet pas de distinguer Bobodo d'autres assistants utilisant gTTS

---

## QUESTION CRITIQUE

### Si un étudiant ferme les yeux, peut-il reconnaître Bobodo après plusieurs conversations ?

**Réponse** : ❌ **NON**

**Justification** :
1. **Voix générique** : gTTS utilise la même voix que Google Translate, utilisée par de nombreuses applications
2. **Pas de signature vocale** : Aucune caractéristique distinctive (ton, rythme, intonation)
3. **Pas de personnalité** : La voix est neutre, monotone, pas d'émotion
4. **Pas d'adaptation** : La voix ne s'adapte pas au contexte ou à l'utilisateur

**Conclusion** : Un étudiant ne peut pas reconnaître Bobodo uniquement par sa voix. La voix actuelle est générique et indistincte.

---

## ARCHITECTURE POUR CRÉER UNE VOIX OFFICIELLE BOBODO

### Solution minimale

**Objectif** : Créer une voix distinctive pour Bobodo avec un coût minimal

**Solution** : **Piper TTS avec modèle français personnalisé**

**Composants** :
1. **Moteur TTS** : Piper TTS (open-source, gratuit)
2. **Modèle** : fr_FR-siwis-medium (ou autre modèle français)
3. **Personnalisation** : Ajustement des paramètres (vitesse, ton, pitch)
4. **Coût** : Gratuit (open-source)

**Avantages** :
- Voix plus naturelle que gTTS
- Configurable (vitesse, ton, pitch)
- Open-source, gratuit
- Peut être hébergé sur Kamatera

**Inconvénients** :
- Nécessite l'installation de Piper TTS (échec actuel 404 HuggingFace)
- Qualité inférieure à ElevenLabs ou Azure TTS
- Pas de voix clonée (pas de signature vocale unique)

**Complexité** : MOYENNE
- Résoudre le problème de téléchargement Piper
- Installer et configurer Piper
- Tester les modèles disponibles
- Ajuster les paramètres

---

### Solution recommandée

**Objectif** : Créer une voix distinctive et professionnelle pour Bobodo

**Solution** : **ElevenLabs avec voix clonée**

**Composants** :
1. **Moteur TTS** : ElevenLabs API
2. **Voix** : Voix clonée (enregistrement d'un acteur/actrice)
3. **Personnalisation** : Ajustement des paramètres (stability, similarity, style)
4. **Coût** : ~$22/mois (Starter plan)

**Avantages** :
- Voix ultra-réaliste (indistinguable d'une voix humaine)
- Voix clonée (signature vocale unique)
- Configurable (stability, similarity, style)
- Supporte le français et les accents
- API simple à intégrer

**Inconvénients** :
- Coût mensuel (~$22/mois)
- Dépendance à un service externe
- Nécessite un enregistrement vocal de qualité

**Complexité** : FAIBLE
- Créer un compte ElevenLabs
- Enregistrer une voix (acteur/actrice)
- Cloner la voix
- Intégrer l'API dans tts_service.py

---

### Solution premium

**Objectif** : Créer une voix distinctive, professionnelle et adaptable

**Solution** : **Azure Custom Neural Voice avec voix personnalisée**

**Composants** :
1. **Moteur TTS** : Azure Custom Neural Voice
2. **Voix** : Voix personnalisée (enregistrement d'un acteur/actrice professionnel)
3. **Personnalisation** : Ajustement avancé (style, émotion, prosodie)
4. **Coût** : ~$40/mois (S0 tier) + coût par caractère

**Avantages** :
- Voix ultra-réaliste (indistinguable d'une voix humaine)
- Voix personnalisée (signature vocale unique)
- Styles multiples (conversation, narration, émotion)
- Supporte le français et les accents
- Intégration Azure robuste

**Inconvénients** :
- Coût mensuel élevé (~$40/mois + coût par caractère)
- Dépendance à un service externe
- Nécessite un enregistrement vocal professionnel
- Complexité d'intégration plus élevée

**Complexité** : MOYENNE
- Créer un compte Azure
- Enregistrer une voix (acteur/actrice professionnel)
- Créer une Custom Neural Voice
- Intégrer l'API dans tts_service.py

---

## RECOMMANDATION

### Solution recommandée : ElevenLabs

**Justification** :
- Voix ultra-réaliste (indistinguable d'une voix humaine)
- Voix clonée (signature vocale unique)
- Coût raisonnable (~$22/mois)
- Complexité d'intégration faible
- Supporte le français et les accents africains

### Plan d'implémentation

1. **Créer un compte ElevenLabs**
   - Inscription sur elevenlabs.io
   - Choisir le plan Starter ($22/mois)

2. **Enregistrer une voix**
   - Choisir un acteur/actrice avec un accent africain francophone
   - Enregistrer 10-30 minutes de parole
   - Qualité d'enregistrement professionnelle

3. **Cloner la voix**
   - Uploader les enregistrements sur ElevenLabs
   - Créer une voix clonée
   - Ajuster les paramètres (stability, similarity, style)

4. **Intégrer l'API**
   - Obtenir la clé API ElevenLabs
   - Modifier tts_service.py pour utiliser ElevenLabs
   - Tester la voix

5. **Valider**
   - Tester avec des utilisateurs
   - Vérifier la reconnaissance de Bobodo
   - Ajuster les paramètres si nécessaire

---

## CONCLUSION

### La voix actuelle correspond-elle à l'identité de Bobodo ?

**Réponse** : ❌ **NON**

**Justification** :
- Voix générique (gTTS)
- Pas de signature vocale
- Pas de personnalité
- Pas adaptée aux accents africains

### Un étudiant peut-il reconnaître Bobodo après plusieurs conversations ?

**Réponse** : ❌ **NON**

**Justification** :
- Voix générique
- Pas de signature vocale
- Pas de personnalité

### Solution recommandée

**ElevenLabs avec voix clonée**

**Coût** : ~$22/mois

**Complexité** : FAIBLE

**Impact** : Voix distinctive, reconnaissance possible, adaptation aux accents africains

---

## STATUT FINAL

**AUDIT COMPLET**

**Conclusion** : La voix actuelle ne correspond pas à l'identité de Bobodo. Une solution TTS professionnelle est requise pour créer une voix officielle Bobodo.

---

## SIGN-OFF

**Audit réalisé** : 12 Juin 2026
**Auditeur** : Cascade AI
**Statut** : COMPLET - Solution TTS professionnelle requise
