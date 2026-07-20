# CHRONOGRAMME — Smart Whiteboard : De l'état actuel à la qualité attendue

**Version** : 1.0  
**Date** : 15 Juillet 2026  
**Auteur** : Software Architect  
**Objectif** : Plan d'exécution rigoureux pour atteindre la qualité documentée du Smart Whiteboard

---

## PARTIE 0 — ÉTAT DES LIEUX (Ce qui fonctionne actuellement)

### 0.1 Supabase (✅ Fonctionnel)

| Composant | État | Détail |
|-----------|------|--------|
| Table `app.whiteboard_projects` | ✅ | 12 colonnes, RLS, indexes |
| Table `app.whiteboard_renders` | ✅ | 12 colonnes, RLS, indexes |
| Table `app.whiteboard_ai_generations` | ✅ | Logs des générations IA |
| RPCs (7+) | ✅ | create/update/get/list/delete project, create_render_job, get_render_status, fetch_queued_jobs, mark_processing/done/failed |
| Bucket `whiteboard-renders` | ✅ | Stockage MP4 |
| Bucket `whiteboard-narrations` | ✅ | Stockage audio |
| Edge Function `whiteboard-generate-storyboard` | ✅ | Génération storyboard via OpenRouter |
| Système de crédits | ✅ | reserve/confirm/refund |

### 0.2 Kamatera Cloud (✅ Fonctionnel — Qualité insuffisante)

| Composant | État | Détail |
|-----------|------|--------|
| VPS 185.167.97.144 | ✅ | Ubuntu 24.04, 4 vCPU, 9.7 Go RAM |
| Service `whiteboard-worker` | ✅ | systemd, boucle de polling |
| `whiteboard_render_worker.py` | ✅ | Orchestrateur : poll → render PNG → assemble → upload |
| `whiteboard_png_renderer.py` v2 | ⚠️ | **Pillow uniquement** : texte sur fond uni, pas d'éléments visuels |
| `whiteboard_ffmpeg_assembler.py` v9 | ✅ | H.264 main@4.0, 720×1280, durées respectées |
| `whiteboard_upload_renderer.py` | ✅ | Upload vers Supabase Storage |
| FFmpeg 6.1.1 | ✅ | Installé et fonctionnel |
| Python 3.11+ | ✅ | Avec Pillow, httpx, dotenv |
| Matplotlib | ⚠️ | Installé mais rendu formules très basique |
| **Node.js / Playwright** | ❌ | **NON installé** |
| **KaTeX** | ❌ | **NON installé** |
| **Fonts riches** | ❌ | Seulement DejaVuSans système |

### 0.3 Flutter (✅ Fonctionnel)

| Composant | État | Détail |
|-----------|------|--------|
| Input Screen (4 modes A/B/C/D) | ✅ | Sujet simple, texte complet, plan, cours existant |
| Storyboard Editor | ✅ | Édition des blocs/scènes |
| Preview Screen | ✅ | Lecture vidéo via AcademiaPlaybackView (MediaTek-safe) |
| Publish → Challenge Feed | ✅ | Publication fonctionnelle |
| Provider (état machine) | ✅ | idle→loading→bobodoGenerating→editing→rendering→done |
| `flutter_math_fork` | ⚠️ | Dans pubspec mais pas utilisé dans le renderer serveur |

### 0.4 Problèmes de qualité identifiés

| Problème | Impact | Cause racine |
|----------|--------|--------------|
| Formules = texte matplotlib basique | Élevé | Pas de KaTeX/MathJax côté serveur |
| Aucun élément graphique (encadrés, icônes) | Élevé | Pillow = dessin primitif uniquement |
| Aucune animation (images statiques) | Élevé | 1 PNG fixe par scène, pas de transitions |
| Pas de diagrammes/schémas/graphes | Élevé | Aucun moteur de diagrammes |
| Pas de différenciation visuelle des blocs | Moyen | Tous les blocs = texte simple |
| Police système générique (DejaVu) | Moyen | Pas de fonts typographiques modernes |
| Pas d'écriture manuscrite | Moyen | Prévu V3, non implémenté |
| Pas de surlignage/zoom | Faible | Prévu V3-V4 |

---

## PARTIE 1 — ARCHITECTURE CIBLE

### Vision Engine (documenté dans SMART_WHITEBOARD_VISION_ENGINE_PLAN.md)

```
┌──────────────┐    ┌──────────────────┐    ┌───────────────────┐
│ Flutter      │    │ Supabase         │    │ Kamatera VPS      │
│ (éditeur)    │───▶│ (render job)     │───▶│                   │
│              │    │                  │    │ 1. HTML Template  │
│              │    │                  │    │    + KaTeX         │
│              │    │                  │    │    + CSS/Canvas    │
│              │    │                  │    │ 2. Playwright     │
│              │    │                  │    │    capture frames  │
│              │◀───│ (video_url)      │◀───│ 3. FFmpeg         │
│              │    │                  │    │    assemble MP4   │
└──────────────┘    └──────────────────┘    └───────────────────┘
```

### Choix technologiques pour le rendu

| Composant | Technologie | Justification |
|-----------|-------------|---------------|
| Rendu global | HTML/CSS/Canvas filmé par Playwright | Layout flexible, animations CSS, KaTeX natif |
| Formules mathématiques | KaTeX (server-side rendering) | Qualité LaTeX, rendu instantané, léger |
| Diagrammes | Mermaid.js + graphes SVG | Standard, scriptable, intégrable HTML |
| Graphes de fonctions | Function-plot (D3-based) | Graphes mathématiques précis |
| Animations | CSS @keyframes + JS timeline | fade_in, slide_up, scale_in par bloc |
| Capture | Playwright (Chromium headless) | Déterministe, 30fps, résolution exacte |
| Assemblage | FFmpeg (existant v9) | Conservé tel quel |
| Polices | Inter, JetBrains Mono, Noto Serif | Modernes, lisibles, scientifiques |

---

## PARTIE 2 — CHRONOGRAMME DES TÂCHES

### PHASE A — Préparation Kamatera (Jour 1-2)

#### A.1 Installation Node.js + npm
- **Cible** : Kamatera VPS
- **Action** : Installer Node.js 20 LTS via nodesource
- **Commande** : `curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt-get install -y nodejs`
- **Vérification** : `node --version` → v20.x, `npm --version` → 10.x
- **Prérequis** : Aucun
- **Risque** : Faible (installation standard)

#### A.2 Installation Playwright + Chromium
- **Cible** : Kamatera VPS
- **Action** : Installer Playwright et ses dépendances système
- **Commandes** :
  ```bash
  npm init -y
  npm install playwright@latest
  npx playwright install chromium
  npx playwright install-deps chromium
  ```
- **Vérification** : `npx playwright --version`, test capture d'une page blanche
- **Prérequis** : A.1
- **Risque** : Moyen (dépendances système Chromium sur Ubuntu)

#### A.3 Installation KaTeX (server-side)
- **Cible** : Kamatera VPS
- **Action** : Installer KaTeX pour le rendu LaTeX côté serveur
- **Commande** : `npm install katex`
- **Vérification** : Script test qui rend `\frac{a}{b}` en HTML
- **Prérequis** : A.1
- **Risque** : Faible

#### A.4 Installation Mermaid CLI (diagrammes)
- **Cible** : Kamatera VPS
- **Action** : Installer mermaid-cli pour générer des diagrammes SVG
- **Commande** : `npm install @mermaid-js/mermaid-cli`
- **Vérification** : Génération d'un diagramme test
- **Prérequis** : A.1, A.2 (Playwright requis par mermaid-cli)
- **Risque** : Faible

#### A.5 Installation polices typographiques
- **Cible** : Kamatera VPS
- **Action** : Installer des polices modernes pour le rendu HTML
- **Commandes** :
  ```bash
  apt-get install -y fonts-inter fonts-noto fonts-noto-cjk
  # + polices manuelles si nécessaire
  wget -O /usr/share/fonts/truetype/jetbrains-mono.ttf https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip
  fc-cache -fv
  ```
- **Vérification** : `fc-list | grep -i inter`, `fc-list | grep -i jetbrain`
- **Prérequis** : Aucun
- **Risque** : Faible

#### A.6 Audit post-installation
- **Action** : Script Python d'audit vérifiant tous les composants
- **Vérification** : node, npm, playwright, katex, mermaid, fonts, espace disque
- **Prérequis** : A.1–A.5

---

### PHASE B — Moteur de rendu HTML (Jour 2-5)

#### B.1 Créer le template HTML de scène (`scene_template.html`)
- **Cible** : `academia_bobodo_backend/whiteboard_vision/scene_template.html`
- **Action** : Créer un template HTML/CSS qui :
  - Affiche un fond thématique (scientific: sombre, notebook: clair)
  - Render les blocs dans une grille verticale
  - Applique des styles distincts par type de bloc :
    - **title** : grand, centré, bold
    - **paragraph** : texte normal avec marges
    - **formula** : KaTeX centré dans un encadré subtil
    - **definition** : encadré coloré avec icône 📘
    - **exercise** : encadré avec bordure gauche + numéro
    - **correction** : étapes numérotées, couleur accent
  - Supporte les animations CSS (@keyframes fade_in, slide_up)
  - Résolution : 1080×1920 (vertical mobile)
- **Prérequis** : A.3 (KaTeX CSS/JS local)
- **Risque** : Moyen (design itératif nécessaire)
- **Livrables** : `scene_template.html`, `scene_styles.css`, `scene_renderer.js`

#### B.2 Créer le script de capture Playwright (`whiteboard_playwright_capture.py`)
- **Cible** : `academia_bobodo_backend/whiteboard_vision/whiteboard_playwright_capture.py`
- **Action** : Script Python qui :
  1. Ouvre Chromium via Playwright (python bindings)
  2. Charge le template HTML avec les données d'une scène
  3. Attend les animations CSS (durée configurable)
  4. Capture N frames à 30fps (via `page.screenshot()` en boucle ou via `video_recording`)
  5. Retourne la liste des PNGs (ou un segment MP4)
- **Prérequis** : A.2, B.1
- **Commande d'installation** : `pip install playwright && playwright install chromium`
- **Risque** : Moyen (timing animations, performance)

#### B.3 Créer le renderer de formules KaTeX (`whiteboard_katex_renderer.js`)
- **Cible** : `academia_bobodo_backend/whiteboard_vision/whiteboard_katex_renderer.js`
- **Action** : Module Node.js qui :
  1. Prend une expression LaTeX en entrée
  2. Rend en HTML via `katex.renderToString()`
  3. Retourne le HTML complet (avec CSS inline)
- **Prérequis** : A.3
- **Risque** : Faible

#### B.4 Créer le renderer de diagrammes (`whiteboard_diagram_renderer.js`)
- **Cible** : `academia_bobodo_backend/whiteboard_vision/whiteboard_diagram_renderer.js`
- **Action** : Module qui :
  1. Prend une définition Mermaid en entrée (ou un graphe de fonction)
  2. Génère un SVG via mermaid-cli
  3. Retourne le SVG inline pour insertion dans le HTML
- **Prérequis** : A.4
- **Risque** : Faible

#### B.5 Créer le moteur de scène complet (`whiteboard_scene_engine.py`)
- **Cible** : `academia_bobodo_backend/whiteboard_vision/whiteboard_scene_engine.py`
- **Action** : Orchestrateur Python qui pour chaque scène :
  1. Pré-rend les formules KaTeX (appel Node.js)
  2. Pré-génère les diagrammes (si bloc diagram)
  3. Injecte les données dans le template HTML
  4. Lance la capture Playwright
  5. Retourne les frames ou le segment vidéo
- **Prérequis** : B.1, B.2, B.3, B.4
- **Risque** : Moyen (intégration)

#### B.6 Tests unitaires du moteur
- **Action** : Script de test avec storyboard de référence
- **Vérification** :
  - Formule `\frac{-b \pm \sqrt{b^2-4ac}}{2a}` rendue proprement
  - Définition dans un encadré
  - Exercice avec numérotation
  - Animation fade_in visible sur les frames
- **Prérequis** : B.5
- **Risque** : Faible

---

### PHASE C — Intégration Worker (Jour 5-7)

#### C.1 Modifier `whiteboard_render_worker.py` — Basculer vers Vision Engine
- **Cible** : Kamatera `/opt/whiteboard-worker/whiteboard_render_worker.py`
- **Action** : Remplacer l'appel à `render_storyboard_to_pngs()` (Pillow) par l'appel au nouveau `whiteboard_scene_engine.py`
- **Stratégie** : Feature flag `RENDERER_ENGINE=vision|legacy`
  - `legacy` = ancien Pillow (fallback sécurité)
  - `vision` = nouveau HTML/Playwright
- **Prérequis** : B.5, B.6 validés
- **Risque** : Moyen (régression possible, d'où le feature flag)

#### C.2 Conserver et adapter `whiteboard_ffmpeg_assembler.py`
- **Cible** : Kamatera
- **Action** : Adapter l'assembleur pour accepter :
  - Option 1 : PNGs frames (comme actuellement) 
  - Option 2 : Segments MP4 par scène (si Playwright fait du video_recording)
- **Modification** : Ajout d'un mode `concat_segments` en plus du mode `concat_images`
- **Prérequis** : C.1
- **Risque** : Faible (l'assembleur v9 est stable)

#### C.3 Déploiement sur Kamatera
- **Cible** : VPS 185.167.97.144
- **Action** :
  1. Backup des fichiers existants
  2. Copie des nouveaux fichiers (dossier `whiteboard_vision/`)
  3. Mise à jour du worker
  4. Redémarrage du service
  5. Test avec un nouveau render job
- **Prérequis** : C.1, C.2
- **Risque** : Moyen (rollback possible via backup)

#### C.4 Test bout-en-bout avec vérification qualité
- **Action** :
  1. Générer un storyboard contenant : titre, paragraphe, formule complexe, définition, exercice, correction
  2. Lancer un render job
  3. Vérifier le MP4 produit :
     - `ffprobe` : 720×1280, H.264 main@4.0, 30fps
     - Visuel : formule propre, encadrés, animations
     - Décodage : `ffmpeg -f null -` OK
  4. Lecture sur appareil Android d'entrée de gamme
- **Prérequis** : C.3
- **Risque** : Faible (rollback possible)

---

### PHASE D — Enrichissement de la génération IA (Jour 7-9)

#### D.1 Enrichir le prompt de `whiteboard-generate-storyboard`
- **Cible** : `supabase/functions/whiteboard-generate-storyboard/index.ts`
- **Action** : Modifier le system prompt pour que le LLM génère :
  - Des formules en syntaxe LaTeX complète (pas texte brut)
  - Des métadonnées d'animation par bloc (`animation.type`, `animation.delay`)
  - Des blocs de type `diagram` avec définition Mermaid
  - Des `highlight_words` pour les mots importants
- **Prérequis** : B.1 (le template doit supporter ces features)
- **Risque** : Moyen (qualité du LLM sur le JSON enrichi)

#### D.2 Ajouter le type de bloc `diagram`
- **Cible** : Edge Function + Worker + Flutter
- **Action** :
  - Edge Function : ajouter `diagram` dans `validTypes`
  - Worker : le scene engine doit savoir rendre un bloc `diagram`
  - Flutter : afficher un placeholder/aperçu pour le bloc diagram dans l'éditeur
- **Prérequis** : B.4, D.1
- **Risque** : Faible

#### D.3 Ajouter le type de bloc `graph` (graphe de fonction)
- **Cible** : Edge Function + Worker + Flutter
- **Action** :
  - Format du bloc : `{"type": "graph", "content": "f(x) = x^2 - 3x + 2", "domain": [-5, 5]}`
  - Le scene engine rend le graphe via function-plot ou Chart.js
  - Le LLM génère le bloc quand le sujet contient des fonctions/courbes
- **Prérequis** : B.4, D.1
- **Risque** : Moyen

#### D.4 Redéployer l'Edge Function
- **Cible** : Supabase
- **Action** : `supabase functions deploy whiteboard-generate-storyboard`
- **Prérequis** : D.1, D.2, D.3
- **Risque** : Faible

---

### PHASE E — Animations (Jour 9-11)

#### E.1 Implémenter les animations CSS dans le template
- **Cible** : `scene_template.html` / `scene_styles.css`
- **Action** : Créer les animations :
  - `fade_in` : opacité 0→1 (500ms)
  - `slide_up` : translateY(30px)→0 + opacité (600ms)
  - `scale_in` : scale(0.8)→1 + opacité (400ms)
  - `typewriter` : texte lettre par lettre (pour titres)
  - `draw_line` : trait qui se dessine (pour séparateurs)
- **Prérequis** : B.1
- **Risque** : Faible

#### E.2 Implémenter le séquencement temporel
- **Cible** : `scene_renderer.js`
- **Action** : Chaque bloc apparaît avec un `delay` croissant basé sur :
  - Son `order` dans la scène
  - Son `animation.delay` (si spécifié dans le storyboard)
  - La durée totale de la scène (`duration_ms`)
- **Prérequis** : E.1
- **Risque** : Moyen (timing vs capture frames)

#### E.3 Synchroniser capture Playwright avec animations
- **Cible** : `whiteboard_playwright_capture.py`
- **Action** : 
  - Attendre que toutes les animations soient terminées avant de capturer le dernier frame
  - Ou capturer frame-par-frame pendant les animations (30fps)
  - Durée de capture = `duration_ms` de la scène
- **Prérequis** : E.2
- **Risque** : Moyen (déterminisme du timing)

---

### PHASE F — Flutter : Affichage enrichi dans l'éditeur (Jour 11-13)

#### F.1 Enrichir `WhiteboardBlockWidget` avec `flutter_math_fork`
- **Cible** : `academia_app/lib/features/challenge/smart_whiteboard/widgets/`
- **Action** : Afficher les formules LaTeX dans l'éditeur Flutter via `flutter_math_fork` (déjà dans pubspec)
- **Prérequis** : Aucun (package déjà disponible)
- **Risque** : Faible

#### F.2 Afficher les blocs `diagram` / `graph` dans l'éditeur
- **Cible** : Flutter widgets
- **Action** : Afficher un aperçu (placeholder ou rendu simplifié) pour les nouveaux types de blocs
- **Prérequis** : D.2, D.3
- **Risque** : Faible

#### F.3 Prévisualisation des animations dans l'éditeur
- **Cible** : Éditeur de storyboard Flutter
- **Action** : Widget de prévisualisation qui montre un aperçu animé (optional, low priority)
- **Prérequis** : F.1, F.2
- **Risque** : Moyen (complexité UI)

---

### PHASE G — Narration et Audio (Jour 13-15)

#### G.1 Intégration TTS (Text-to-Speech)
- **Cible** : Nouvelle Edge Function `whiteboard-generate-narration`
- **Action** :
  - Appeler une API TTS (OpenAI TTS / ElevenLabs via OpenRouter)
  - Générer l'audio à partir du script de narration
  - Uploader dans le bucket `whiteboard-narrations`
  - Retourner l'URL audio
- **Compte requis** : OpenAI API key (déjà via OpenRouter) ou ElevenLabs (nouveau compte possible)
- **Prérequis** : Supabase bucket déjà créé
- **Risque** : Moyen (coût API, qualité voix)

#### G.2 Synchronisation audio-vidéo dans l'assembleur
- **Cible** : `whiteboard_ffmpeg_assembler.py`
- **Action** : Accepter un paramètre `audio_path` et le mixer avec la vidéo via FFmpeg
- **Commande FFmpeg** : `-i video.mp4 -i narration.mp3 -c:v copy -c:a aac -shortest output.mp4`
- **Prérequis** : G.1
- **Risque** : Faible (FFmpeg gère nativement)

#### G.3 Flutter : Interface de narration
- **Cible** : Smart Whiteboard narration screen
- **Action** : Permettre à l'utilisateur de :
  - Enregistrer sa voix
  - Ou générer via TTS (1 bouton)
  - Prévisualiser l'audio
- **Prérequis** : G.1
- **Risque** : Moyen

---

## PARTIE 3 — COMPTES ET RESSOURCES NÉCESSAIRES

### 3.1 Comptes déjà disponibles

| Service | Compte | Utilisation |
|---------|--------|-------------|
| Supabase | ✅ Existant | Tables, RPCs, Edge Functions, Storage |
| OpenRouter | ✅ Existant | LLM pour génération storyboard |
| Kamatera | ✅ Existant | VPS pour rendu vidéo |

### 3.2 Comptes / ressources à configurer

| Service | Action requise | Phase | Coût estimé |
|---------|---------------|-------|-------------|
| **Aucun nouveau compte requis** | Playwright, KaTeX, Mermaid sont open-source et gratuits | A | 0€ |
| **OpenRouter (TTS)** | Vérifier que le crédit OpenRouter couvre les appels TTS (OpenAI voices) | G | ~0.015$/min audio |
| **ElevenLabs** (optionnel) | Créer un compte si voix françaises de haute qualité requises | G | 5$/mois (starter) |
| **Google Fonts** | Télécharger Inter, JetBrains Mono, Noto Serif (gratuit) | A.5 | 0€ |

### 3.3 Ressources VPS (capacité actuelle vs requise)

| Ressource | Actuel | Requis | Marge |
|-----------|--------|--------|-------|
| RAM | 9.7 Go (1.6 utilisé) | +2 Go pour Chromium | ✅ OK |
| Disque | 30 Go (17 utilisé) | +3 Go (Node, Playwright, Chromium) | ✅ OK |
| CPU | 4 vCPU | Suffisant pour capture 30fps | ✅ OK |
| Bande passante | 100 Mbps | Suffisant | ✅ OK |

---

## PARTIE 4 — TABLEAU RÉCAPITULATIF (CHRONOGRAMME)

| Phase | Tâche | Cible | Jours | Dépendances | Priorité |
|-------|-------|-------|-------|-------------|----------|
| **A** | **Préparation Kamatera** | VPS | **1-2** | — | 🔴 Critique |
| A.1 | Installer Node.js 20 | Kamatera | 1 | — | 🔴 |
| A.2 | Installer Playwright + Chromium | Kamatera | 1 | A.1 | 🔴 |
| A.3 | Installer KaTeX | Kamatera | 1 | A.1 | 🔴 |
| A.4 | Installer Mermaid CLI | Kamatera | 1 | A.1, A.2 | 🟡 |
| A.5 | Installer polices modernes | Kamatera | 1 | — | 🟡 |
| A.6 | Audit post-installation | Kamatera | 1 | A.1-A.5 | 🔴 |
| **B** | **Moteur de rendu HTML** | Code | **2-5** | A | 🔴 Critique |
| B.1 | Template HTML de scène | Code | 2-3 | A.3 | 🔴 |
| B.2 | Script capture Playwright | Code | 3-4 | A.2, B.1 | 🔴 |
| B.3 | Renderer KaTeX | Code | 3 | A.3 | 🔴 |
| B.4 | Renderer diagrammes | Code | 4 | A.4 | 🟡 |
| B.5 | Moteur de scène complet | Code | 4-5 | B.1-B.4 | 🔴 |
| B.6 | Tests unitaires | Code | 5 | B.5 | 🔴 |
| **C** | **Intégration Worker** | Kamatera | **5-7** | B | 🔴 Critique |
| C.1 | Basculer worker → Vision Engine | Code + Kamatera | 5-6 | B.5 | 🔴 |
| C.2 | Adapter FFmpeg assembler | Code | 5-6 | C.1 | 🟡 |
| C.3 | Déploiement sur Kamatera | Kamatera | 6-7 | C.1, C.2 | 🔴 |
| C.4 | Test bout-en-bout | Kamatera + Device | 7 | C.3 | 🔴 |
| **D** | **Enrichissement IA** | Supabase | **7-9** | C | 🟡 Important |
| D.1 | Enrichir prompt LLM | Edge Function | 7-8 | B.1 | 🟡 |
| D.2 | Bloc `diagram` | Multi | 8 | B.4, D.1 | 🟡 |
| D.3 | Bloc `graph` | Multi | 8-9 | B.4, D.1 | 🟡 |
| D.4 | Redéployer Edge Function | Supabase | 9 | D.1-D.3 | 🟡 |
| **E** | **Animations** | Code + Kamatera | **9-11** | B | 🟡 Important |
| E.1 | Animations CSS | Code | 9-10 | B.1 | 🟡 |
| E.2 | Séquencement temporel | Code | 10 | E.1 | 🟡 |
| E.3 | Synchronisation capture | Code | 10-11 | E.2 | 🟡 |
| **F** | **Flutter enrichi** | Flutter | **11-13** | D | 🟢 Normal |
| F.1 | flutter_math_fork dans éditeur | Flutter | 11-12 | — | 🟢 |
| F.2 | Blocs diagram/graph | Flutter | 12 | D.2, D.3 | 🟢 |
| F.3 | Preview animations | Flutter | 12-13 | F.1, F.2 | 🟢 |
| **G** | **Narration Audio** | Multi | **13-15** | — | 🟢 Normal |
| G.1 | Edge Function TTS | Supabase | 13-14 | — | 🟢 |
| G.2 | Mixage audio-vidéo | Kamatera | 14 | G.1 | 🟢 |
| G.3 | Interface Flutter narration | Flutter | 14-15 | G.1 | 🟢 |

---

## PARTIE 5 — PROTOCOLE D'AUDIT PAR PHASE

Avant et après chaque phase, les audits suivants sont OBLIGATOIRES :

### Audit Supabase
```python
# Via .windsurf/audit_*.py
- Tables : vérifier colonnes, indexes, RLS
- RPCs : tester chaque RPC modifiée
- Edge Functions : vérifier déploiement et réponse
- Buckets : vérifier accès et contenu
```

### Audit Kamatera
```bash
# Via SSH
- Service whiteboard-worker : statut, logs
- Dépendances : node, npm, playwright, katex, matplotlib
- Espace disque et RAM
- Test de rendu avec storyboard de référence
```

### Audit Flutter
```bash
# Compilation et analyse
flutter analyze
flutter build apk --debug
# Test sur device physique (TECNO LD7)
```

### Harmonisation des 3 dispositifs
À chaque phase, vérifier que :
1. Le **storyboard JSON** produit par Supabase est consommable par Kamatera
2. Le **MP4** produit par Kamatera est lisible par Flutter (AcademiaPlaybackView)
3. Les **nouveaux types de blocs** sont supportés par les 3 (Edge Function → Worker → Flutter)

---

## PARTIE 6 — CRITÈRES D'ACCEPTATION GLOBAUX

| Critère | Mesure | Objectif |
|---------|--------|----------|
| Qualité formules | Rendu LaTeX propre (KaTeX) | Comparable à un PDF LaTeX |
| Qualité visuelle | Encadrés, icônes, séparateurs | Comparable à GoodNotes |
| Animations | Blocs qui apparaissent progressivement | Fluide à 30fps |
| Diagrammes | Graphes/schémas clairs et lisibles | Comparable à un manuel |
| Compatibilité | Lecture sur Android d'entrée de gamme | 0 crash MediaCodec |
| Performance | Rendu d'un storyboard 10 scènes | < 3 minutes |
| Narration | Voix IA synchronisée (optionnel V1+) | Clarté audio |

---

## PARTIE 7 — ROLLBACK ET SÉCURITÉ

| Situation | Action |
|-----------|--------|
| Vision Engine échoue sur Kamatera | Revenir au renderer Pillow via `RENDERER_ENGINE=legacy` |
| Playwright trop lent | Optimiser (pool de browsers, capture vidéo native) |
| KaTeX ne supporte pas une formule | Fallback matplotlib (existant) |
| Espace disque insuffisant | Nettoyer `/tmp` + augmenter disque Kamatera |
| Edge Function timeout | Augmenter max_tokens ou simplifier le prompt |

---

## CONCLUSION

**Durée totale estimée** : 15 jours de développement (phases A→G)

**Phases critiques** (bloquantes) : A, B, C  
**Phases importantes** (qualité) : D, E  
**Phases normales** (amélioration) : F, G  

**Aucun nouveau compte payant n'est requis** — toute la stack est open-source (Node.js, Playwright, KaTeX, Mermaid) et s'installe sur le VPS Kamatera existant.

**La clé du succès** : Le passage de Pillow (texte-sur-image) à HTML/CSS/Canvas + Playwright (rendu web filmé) permet d'atteindre la qualité "GoodNotes" documentée sans changer l'architecture globale (le worker poll toujours Supabase, génère toujours un MP4, l'upload toujours dans le même bucket).

---

**Fin du document**
