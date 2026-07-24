# Smart Whiteboard Studio — Stack 2026 (haut de gamme, quasi-gratuit)

Objectif : un studio de montage combinant **CapCut + Canva + GoodNotes**, adapté au
**monde académique** (effets lumineux, animations, zooms, maths propres, voix off),
avec la **meilleure combinaison d'outils open-source auto-hébergés** → rendu haut de
gamme pour un **coût par vidéo ≈ 0** (uniquement du calcul sur ton Kamatera).

Principe directeur : **tout ce qui est récurrent (1 vidéo/élève) tourne en local**
(gratuit). Les services payants (HyperFrames/HeyGen, Canva) servent **uniquement au
one-shot** (créer un template de marque réutilisable), jamais au pipeline de masse.

---

## 1. Moteur de rendu — Remotion + son écosystème
Remotion (React) est le socle. On y ajoute ses paquets officiels (tous gratuits) :

| Paquet | Ce qu'il apporte | Rôle « studio » |
|---|---|---|
| `@remotion/transitions` | `TransitionSeries` + presets (slide, wipe, clockWipe, flip, fade) | Transitions entre scènes (style CapCut) |
| `@remotion/lottie` | Joue des animations Lottie | Icônes/illustrations animées, effets lumineux prêts |
| `@remotion/skia` | Shaders GPU (glow, halos, dégradés animés) | **Effets lumineux** haut de gamme |
| `@remotion/motion-blur` | `<Trail>`, `<CameraMotionBlur>` | Mouvement cinématique, zooms doux |
| `@remotion/paths` | Animation de tracés SVG | **Écriture manuscrite** (effet GoodNotes) |
| `@remotion/media-utils` | Waveform audio, mesure | Sous-titres/rythme calés sur la voix |
| **Onda** (communautaire) | 70 composants + 18 transitions prêts | Accélère le montage stylé |

## 2. Maths animées — Manim (MIT)
Pour le cœur académique (formules qui s'écrivent, constructions géométriques, tracés
de fonctions), **Manim** est imbattable. On rend chaque animation math en clip, puis on
la **composite** dans Remotion via `<OffthreadVideo>`. KaTeX reste pour les formules
simples/statique. Coût : 0 (calcul local).

## 3. Narration — Kokoro-82M (Apache 2.0) ⟶ upgrade de Piper
Recherche 2026 : **Kokoro-82M** est le meilleur TTS open-source par défaut — 82M params,
**licence Apache 2.0** (commerciale OK), **54 voix dont le français**, tourne **sur CPU à
~6× le temps réel**, et bat Coqui XTTS/MetaVoice en tests d'écoute. Déploiement clé en
main via **Kokoro-FastAPI** (image Docker, API compatible OpenAI). → on remplace Piper.
- Option premium ponctuelle : **Chatterbox-Turbo** (MIT, clonage de voix, préféré à
  ElevenLabs à 65 % en test aveugle) si tu veux une voix « signature » de marque.
- À éviter en commercial : **XTTS v2** (licence non-commerciale).
Coût : 0 (auto-hébergé).

## 4. Assets libres (droits commerciaux, sans attribution)
| Source | Contenu | Licence / coût |
|---|---|---|
| **Pexels API** | Photos + **vidéos** de fond | Pexels License, commercial sans attribution, **gratuit** (200 req/h) |
| **LottieFiles** | 100 000+ animations, icônes « éducation » | Lottie Simple License, commercial sans attribution |
| **Lucide / Tabler icons** | Icônes vectorielles | Open-source |
| **Excalidraw / rough.js** | Rendu « dessiné main » (schémas) | MIT |

## 5. Effets « haut de gamme » (comment on obtient le style)
- **Effets lumineux / glow** : `@remotion/skia` (shaders) + calques Lottie lumineux.
- **Zooms** : Ken Burns (échelle animée) sur images/fond + `CameraMotionBlur` pour la douceur.
- **Écriture progressive** : `@remotion/paths` (tracé SVG) pour titres/schémas manuscrits.
- **Révélation ligne par ligne** : stagger par mot/ligne (déjà ajouté au moteur).
- **Transitions** : `TransitionSeries` (slide/zoom/fondu enchaîné entre scènes).
- **Rythme** : durées calées sur la voix Kokoro (le visuel suit la narration).

## 6. Les connecteurs/MCP (« plugins ») — quand les utiliser
- **Canva** (connecté) : concevoir **une fois** des templates de marque, fonds, cartouches
  → exportés puis réutilisés gratuitement dans Remotion. Pas pour chaque vidéo (quotas).
- **HyperFrames / HeyGen** (connecté) : rendu IA clé en main avec avatars/voix — **payant
  par rendu**. Utile pour une intro « présentateur » ponctuelle, **pas** le pipeline de masse.
- Le pipeline élève reste **100 % local** (Remotion + Manim + Kokoro) = coût ≈ 0.

---

## Feuille de route recommandée (par vagues, sans exploser les coûts)
1. **Vague 1 (maintenant)** : Remotion + `@remotion/transitions` + Ken Burns/glow + révélation
   ligne par ligne + **Kokoro** (voix FR). → saut visuel immédiat, 0 coût.
2. **Vague 2** : `@remotion/lottie` (icônes/illustrations animées, Pexels pour les fonds) +
   `@remotion/paths` (écriture manuscrite) + `@remotion/skia` (glow premium).
3. **Vague 3** : **Manim** pour les scènes mathématiques compositées (matière scientifique).
4. **Vague 4 (option)** : Chatterbox pour une voix de marque ; images IA locales (Flux/SD) si besoin.

## Coût — synthèse
Tout le pipeline récurrent est **open-source et auto-hébergé sur Kamatera** : la dépense
est le **CPU/GPU déjà loué**, pas des crédits IA par vidéo. Les seuls appels externes
(Pexels, LottieFiles) sont **gratuits**. Les services payants restent **optionnels et ponctuels**.

## Sources
- [Remotion — ressources & écosystème](https://www.remotion.dev/docs/resources) · [Transitions](https://www.remotion.dev/docs/transitions/) · [Lottie](https://www.remotion.dev/docs/lottie) · [Motion blur](https://www.remotion.dev/docs/motion-blur/) · [Intégrations tierces](https://www.remotion.dev/docs/third-party)
- [Best Self-Hosted TTS 2026 (Kokoro, Chatterbox, Piper…)](https://www.sevenlabs.site/blogs/best-self-hosted-tts-models-2026) · [Kokoro-82M (Hugging Face)](https://huggingface.co/hexgrad/Kokoro-82M) · [Kokoro-FastAPI](https://github.com/remsky/Kokoro-FastAPI)
- [Pexels API (image + vidéo gratuites)](https://www.pexels.com/api/) · [Pexels License](https://www.pexels.com/license/)
- [LottieFiles — animations gratuites](https://lottiefiles.com/) · [Manim Community (MIT)](https://www.manim.community/)
