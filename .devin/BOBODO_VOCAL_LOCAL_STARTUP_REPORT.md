# BOBODO VOCAL - RAPPORT DÉMARRAGE LOCAL

**Date** : 10 juin 2026  
**Statut** : ⚠️ PARTIEL (difficultés dépendances Windows)

---

## ÉTAPE 1 - TÉLÉCHARGEMENT DES MODÈLES

**Statut** : ✅ **TERMINÉ**

**Modèles téléchargés** :
- Faster Whisper Medium : 4/4 fichiers
  - model.bin : 6378 KB
  - config.json : 2257 B
  - tokenizer.json : 3239 B
  - vocabulary.txt : 9861 B
- Piper fr_FR-medium : 2/2 fichiers
  - model.onnx : 49319 B
  - config.json : 49321 B

**Emplacement** : `.windsurf\bobodo-vocal\models\`

**Temps de téléchargement** : ~15 minutes

**Taille totale** : ~1.42 GB

---

## ÉTAPE 2 - INSTALLATION DÉPENDANCES

**Statut** : ❌ **ÉCHEC** (difficultés Windows)

### Tentative 1 : faster-whisper + piper-tts

**Erreur** : `piper-tts==1.2.0` n'est pas compatible avec Python 3.11 sur Windows

**Message** : `ERROR: Could not find a version that satisfies the requirement piper-phonemize~=1.1.0`

---

### Tentative 2 : faster-whisper + pyttsx3

**Erreur** : `av` nécessite Microsoft Visual C++ 14.0 Build Tools

**Message** : `error: Microsoft Visual C++ 14.0 or greater is required. Get it with "Microsoft C++ Build Tools"`

---

### Tentative 3 : openai-whisper + pyttsx3

**Erreur** : `openai-whisper` a des problèmes de dépendances

**Message** : `ModuleNotFoundError: No module named 'pkg_resources'`

---

## ANALYSE DES PROBLÈMES

### Problème 1 : Windows vs Linux

**Cause** : Les bibliothèques audio/vidéo (av, piper-tts) sont optimisées pour Linux et nécessitent des compilations C++ sur Windows

**Impact** : Installation locale sur Windows difficile

---

### Problème 2 : Dépendances système

**Cause** : Microsoft Visual C++ 14.0 Build Tools non installés

**Impact** : Impossible de compiler les extensions C++

---

### Problème 3 : Python 3.11

**Cause** : Certaines bibliothèques ne supportent pas Python 3.11

**Impact** : Incompatibilité de versions

---

## RECOMMANDATIONS

### Option A : Installation Visual C++ Build Tools

**Action** :
1. Installer Microsoft Visual C++ 14.0 Build Tools
2. Réessayer l'installation des dépendances
3. Tester le service

**Avantages** : Permet d'utiliser les bibliothèques complètes

**Inconvénients** : Nécessite installation logicielle supplémentaire

---

### Option B : Test sur Linux (WSL)

**Action** :
1. Activer WSL (Windows Subsystem for Linux)
2. Installer Ubuntu
3. Installer les dépendances sur Linux
4. Tester le service

**Avantages** : Environnement Linux natif, compatible avec Kamatera

**Inconvénients** : Nécessite configuration WSL

---

### Option C : Test simplifié (STT uniquement)

**Action** :
1. Installer uniquement openai-whisper (sans dépendances complexes)
2. Tester la transcription avec un fichier audio existant
3. Reporter les résultats

**Avantages** : Permet de valider le STT rapidement

**Inconvénients** : Ne teste pas la chaîne complète

---

### Option D : Déploiement direct sur Kamatera

**Action** :
1. Obtenir accès SSH Kamatera
2. Déployer directement sur Linux
3. Tester sur le serveur de production

**Avantages** : Environnement de production réel

**Inconvénients** : Nécessite accès SSH

---

## PROPOSITION

**Recommandation** : Option D (Déploiement direct sur Kamatera)

**Justification** :
- Kamatera est Linux (Ubuntu 22.04)
- Toutes les dépendances sont compatibles
- Environnement de production réel
- Évite les problèmes Windows

**Action requise** :
1. Obtenir accès SSH Kamatera
2. Suivre le plan de déploiement Phase 1
3. Tester sur le serveur

---

## CONCLUSION

**Statut** : Tests locaux impossibles sur Windows sans installation supplémentaire

**Recommandation** : Passer directement au déploiement sur Kamatera

**Raison** : Environnement Windows incompatible avec les dépendances audio/vidéo requises

---

**RAPPORT TERMINÉ**
