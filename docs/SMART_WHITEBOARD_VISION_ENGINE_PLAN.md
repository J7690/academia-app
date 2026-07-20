# Smart Whiteboard — Plan moteur animé (Phase Vision)

**Date** : 13 juillet 2026
**Objectif** : remplacer le rendu « diaporama » (PNG fixe × 5 s) par un vrai
moteur d'animation pédagogique de niveau CapCut / GoodNotes / Canva, tout en
gardant l'édition simple et le pipeline serveur existant (Kamatera + Supabase).

Moteur retenu : **scène HTML/CSS/Canvas animée, filmée côté serveur par
Playwright/Chromium**, puis assemblée en MP4 par FFmpeg.

---

## 1. Pourquoi ce choix

L'architecture actuelle génère une image fixe par scène (Pillow) et les
concatène. Elle ne peut, par construction, produire aucune animation
(écriture progressive, apparition/disparition, déplacements). Filmer une page
web animée permet :

- écriture « à la main » progressive, fondus, glissements, surlignage ;
- maths propres via **KaTeX/MathJax** (rendu vectoriel, pas du texte brut) ;
- mise en page libre type Canva (CSS/flex/grid, images, formes) ;
- une seule techno de rendu réutilisable pour l'aperçu app ET l'export vidéo ;
- pas de dépendance à une police système fragile (web fonts embarquées).

---

## 2. Vue d'ensemble du pipeline

```
Flutter (éditeur timeline)
   │  storyboard v2 (JSON avec timeline par bloc)
   ▼
Supabase  whiteboard_create_render_job → whiteboard_renders(queued)
   │
   ▼
Worker Kamatera (nouveau moteur)
   1. scene_template.html + scene JSON  ─┐
   2. Playwright/Chromium ouvre la page  │  par scène
   3. capture image par image (30 fps)  ─┘  (ou WebM via MediaRecorder)
   4. FFmpeg : frames → segment MP4 par scène
   5. concat des scènes + piste audio (narration/silence)
   6. upload bucket whiteboard-renders → whiteboard_mark_done
   ▼
Flutter preview → « Publier dans le Challenge »
```

Ce qui est **réutilisé tel quel** : tables `whiteboard_*`, RPCs, buckets,
service systemd `whiteboard-worker`, écrans Flutter, flux de publication.
Ce qui **change** : le trio `png_renderer / ffmpeg_assembler` devient un
moteur `scene_renderer (HTML) + playwright_capturer + ffmpeg`.

---

## 3. Storyboard v2 — timeline par bloc

On étend le bloc actuel (`type`, `content`) avec une **timeline** optionnelle.
Rétrocompatible : sans timeline, valeurs par défaut (apparition au début).

```json
{
  "version": "2.0",
  "theme": "scientific",
  "scenes": [
    {
      "id": "s1",
      "duration_ms": 8000,
      "blocks": [
        {
          "id": "b1", "type": "title", "content": "Dérivée d'une fonction",
          "anim": { "enter": "handwrite", "at_ms": 0,    "duration_ms": 1200 }
        },
        {
          "id": "b2", "type": "paragraph", "content": "La dérivée mesure...",
          "anim": { "enter": "fade_up",   "at_ms": 1200, "exit": "fade",
                     "exit_at_ms": 6000, "duration_ms": 600 }
        },
        {
          "id": "b3", "type": "formula",
          "content": "f'(x)=\\lim_{h\\to0}\\frac{f(x+h)-f(x)}{h}",
          "anim": { "enter": "scale_in", "at_ms": 3000, "duration_ms": 800 }
        }
      ]
    }
  ]
}
```

Effets d'entrée V2 : `handwrite`, `fade_up`, `slide_in`, `scale_in`, `typewriter`.
Effets de sortie : `fade`, `slide_out`. La durée de scène pilote le timing global.

---

## 4. Édition simple côté Flutter

L'éditeur storyboard existant gagne, par bloc, un petit sélecteur :
« Apparition » (menu : écriture / fondu / glissement…), « Moment » (curseur sur
la timeline de la scène), « Disparition » (optionnel). Aucune notion de
keyframes exposée à l'utilisateur : on garde 3 réglages simples par bloc.
L'IA (Edge Function) peut pré-remplir des timelines par défaut cohérentes selon
le type de bloc → l'étudiant n'a rien à régler s'il ne veut pas.

---

## 5. Capture côté serveur (worker)

- `scene_template.html` : page autonome qui lit un `scene` JSON injecté et
  joue la timeline via CSS animations + Web Animations API. KaTeX pour les maths.
- Capture : Playwright pilote un `page.clock`/horloge virtuelle et exporte les
  frames (`page.screenshot` par pas de 1/30 s, ou capture WebM via
  `context.newContext({ recordVideo })`). Option la plus robuste pour un timing
  déterministe : rendu frame-par-frame piloté par un paramètre `?t=<ms>`.
- FFmpeg : frames PNG → segment MP4 par scène (mêmes réglages compatibles
  Android que le correctif V1 : profil/level legaux, BT709, faststart, audio).

Dépendances VPS à ajouter : `playwright` + navigateur Chromium
(`playwright install chromium`). Prévoir ~400 Mo et les libs système.

---

## 6. Jalons

1. **Prototype scène** (fait) : `scene_template.html` animé, ouvrable au navigateur.
2. **Capturer 1 scène** en MP4 via Playwright+FFmpeg sur le worker (POC serveur).
3. **Storyboard v2** : modèles Flutter + parsing worker (rétrocompatible v1).
4. **Éditeur** : 3 réglages d'animation par bloc + timelines IA par défaut.
5. **Multi-scènes + audio** : concat + narration, remplacement du renderer V1.
6. **Perf/coût** : temps de rendu par minute de vidéo, file d'attente, cache.

---

## 7. Risques

- **Temps de rendu** : la capture frame-par-frame est plus lente que Pillow.
  Mitigation : paralléliser par scène, viser 720p, mesurer tôt (jalon 2).
- **Ressources VPS** : Chromium headless consomme RAM/CPU. Mitigation :
  1 job à la fois (déjà le cas), limite de durée vidéo, monitoring.
- **Déterminisme du timing** : préférer le rendu piloté par `?t=` à
  l'enregistrement temps-réel pour éviter les frames perdues.
