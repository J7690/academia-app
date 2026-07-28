# Smart Whiteboard — Cahier des charges « mise en scène » v2

**Date** : 25 juillet 2026
**Origine** : retours du propriétaire sur la vidéo Vision du 25/07 + diagnostic technique
de Claude (code, storyboard réel en base, tests de rendu réels sur LWS).
**Objectif** : un rendu « vrai professeur au tableau » — il écrit à la main, il explique
à voix haute, il entoure, il souligne, il remonte à une notion vue plus haut, puis
redescend continuer. Édition simple pour l'étudiant, rendu haut de gamme.

---

# PARTIE 1 — Diagnostic : où en est-on réellement

## 1.1 La bonne nouvelle : le storyboard est déjà riche

J'ai lu en base le storyboard réel du projet « la continuité » (scène 7). Le générateur
IA (v35) produit **déjà** tous les champs de mise en scène :

```jsonc
{
  "title": "Correction : pas si vite !",
  "narration": "Alors, as-tu trouvé ? Vérifions ensemble les trois points...",
  "transition": { "kind": "slide" },
  "recall":     { "kind": "circle", "target": 3 },   // remonter vers le bloc 3
  "duration_ms": 20000,
  "blocks": [
    { "type": "correction", "content": "...", "emphasis": "underline" }
  ]
}
```

**Donc l'intelligence pédagogique est là.** Le problème n'est pas la génération : c'est
que **le moteur de rendu Vision ignore ces champs**. Il produit des cartes statiques
empilées, sans écriture, sans annotation, sans rappel, sans voix.

## 1.2 Les 5 défauts constatés sur la vidéo du 25/07 (avec la cause exacte)

| # | Défaut visible | Cause identifiée dans le code | Gravité |
|---|---|---|---|
| 1 | **LaTeX affiché brut** : `\lim_{x \to 1^-}` lisible à l'écran | `whiteboard_scene_engine.py` n'applique KaTeX **que** sur les blocs `type=formula`. Les blocs `correction`/`paragraph` contenant du LaTeX inline sont échappés comme du texte | **Bloquante** — casse la crédibilité scientifique |
| 2 | **Numérotation corrompue** : `11.`, `12.`, `1₇`, `1Puisque`, `1Conclusion` | `whiteboard_scene_engine.py` ligne 124 : `data-step="{i}. "` où `i` est l'index **de ligne dans le bloc**. Chaque bloc n'ayant qu'une ligne, `i` vaut toujours 1 → le CSS préfixe « 1 » devant un contenu qui porte déjà sa propre numérotation | **Bloquante** |
| 3 | **Aucune voix** | Le moteur Vision utilise `whiteboard_narration.py` (gTTS/OpenRouter), pas Kokoro. Or `build_narration()` sort immédiatement si le paquet Python `gTTS` est absent — et le worker installé sur LWS n'a reçu que 4 fichiers `.py`, sans `requirements.txt` | **Bloquante** |
| 4 | **Blocs statiques**, pas d'écriture progressive, pas de feuille qui défile | Non implémenté dans le moteur Vision (c'est le moteur Remotion qui porte le cahier continu) | **Majeure** |
| 5 | **`emphasis` et `recall` ignorés** | Présents dans le storyboard, jamais lus par le moteur Vision | **Majeure** |

## 1.3 La question de fond : quel moteur garder

Deux moteurs coexistent aujourd'hui sur LWS, tous deux fonctionnels (testés le 25/07) :

| | **Vision** (HTML/Playwright/KaTeX) | **Remotion** (React) |
|---|---|---|
| Rendu testé | ✅ 154 s | ✅ 169 s |
| Utilisé en production | ✅ oui | ❌ non (désactivé) |
| Cahier continu / défilement | ❌ | ✅ conçu pour |
| Annotations animées (cercle/souligné) | ❌ | ✅ `Annotation.tsx` |
| Rappel pédagogique (remonter/redescendre) | ❌ | ✅ implémenté |
| Écriture manuscrite progressive | ❌ | ⚠️ police Caveat, tracé SVG à finir |
| Voix | gTTS (robotique) | Kokoro (meilleure) |
| Écosystème d'animation | limité | `@remotion/transitions`, `paths`, `skia`, `lottie`, `motion-blur` |

**Recommandation ferme : construire sur Remotion.** Tout ce que tu décris (écriture
progressive, feuille qui défile, encerclage qui disparaît, rappel vers le haut) existe
déjà partiellement dans le moteur Remotion et n'existe pas du tout dans Vision. Porter
ces fonctions sur Vision reviendrait à réécrire Remotion en moins bien. **Vision reste
en repli** de sécurité (il marche, il ne casse rien) le temps que Remotion soit validé.

Les 3 défauts « bloquants » (LaTeX, numérotation, voix) doivent malgré tout être
corrigés sur Vision, puisque c'est lui qui sert les étudiants aujourd'hui.

---

# PARTIE 2 — Ce qui était prévu au cahier des charges initial

`SMART_WHITEBOARD_EVOLUTION_ROADMAP.md` (23 juin) prévoyait déjà, en **V3** :
« animations avancées, **écriture manuscrite animée**, surlignage automatique, zoom
intelligent », avec pour dépendances « SVG, vector tracing, handwritten fonts ». En
**V2** : « voix IA avec sélection de voix, synchronisation mot à mot (timestamps) ».

`STUDIO_PRO_UPGRADE.md` (23 juillet) avait acté les correctifs suivants côté Remotion :
contenu centré, polices agrandies (titre 92 px, texte 46 px), lignes de cahier bleues +
marge rouge, annotations manuscrites animées (`Annotation.tsx`), titres en police
Caveat.

**Conclusion : ce que tu demandes aujourd'hui n'est pas un changement de cap — c'est
exactement la V2+V3 du cahier des charges, jamais terminée.** Le présent document la
reprend et la précise.

---

# PARTIE 3 — Spécification de la mise en scène cible

## 3.1 Le principe directeur : une seule feuille qui se remplit

Le rendu doit se lire comme **un cahier filmé**, pas comme un diaporama :

1. La caméra est cadrée sur une feuille de cahier (lignes bleues, marge rouge).
2. Le professeur écrit **ligne après ligne**, de haut en bas. **Rien ne disparaît.**
3. Quand l'écriture atteint le bas du cadre, **la feuille défile doucement vers le
   haut** (la caméra descend) — le contenu déjà écrit reste visible plus haut.
4. Quand la page est pleine, **on tourne la page** : nouvelle feuille vierge, on reprend
   en haut. La numérotation de page est visible en bas (`6/8` sur ta capture — à garder).

## 3.2 L'écriture — deux modes au choix de l'étudiant

| Mode | Rendu | Technique |
|---|---|---|
| `handwriting` (manuscrit) | Le texte se trace comme écrit à la main | Police manuscrite (Caveat / Patrick Hand) + révélation caractère par caractère calée sur la voix ; pour les titres et formules clés, tracé SVG (`stroke-dasharray` / `stroke-dashoffset` animé de la longueur du tracé vers 0 — technique standard de l'effet handwriting) via `@remotion/paths` |
| `typed` (machine) | Le texte apparaît proprement, mot par mot | Révélation par mot/ligne (déjà en place) |

Le choix est **un paramètre de projet** (comme `theme` et `renderer`), exposé dans
l'écran de création côté Flutter, et transporté dans le storyboard (`writing_style`).

## 3.3 Les annotations — ce que fait un prof avec son stylo

| Geste | Comportement attendu | Champ storyboard |
|---|---|---|
| **Encercler** | Le cercle se trace à la main (~0,4 s), **tient ~1,6 s**, puis **s'efface** (le trait se dé-dessine) | `emphasis: "circle"` |
| **Souligner** | Trait tracé sous le texte, tient, puis s'efface | `emphasis: "underline"` |
| **Surligner** | Bande de couleur — **reste** (c'est un marqueur, il ne s'efface pas) | `emphasis: "highlight"` |
| **Mettre en couleur / gras** | Le mot change de couleur ou d'épaisseur, reste | `emphasis: "color"` / `"bold"` *(à ajouter)* |
| **Rappel** | La caméra **remonte** vers une notion vue plus haut, la ré-annote (cercle ou couleur), maintient ~1,5 s, puis **redescend** à la ligne courante et l'écriture reprend | `recall: { target, kind }` |

Le rappel est le geste le plus pédagogique et le plus différenciant : il matérialise le
lien entre deux notions. Il existe déjà dans le moteur Remotion — il n'a jamais été vu à
l'écran faute de rendu.

## 3.4 La voix — le point le plus critique

Contrainte que tu as formulée : la voix doit lire correctement `f(x)`, les limites, les
formules — pas « f parenthèse x parenthèse » ni du charabia.

**Ce n'est pas un problème de moteur TTS, c'est un problème de préparation du texte.**
Aucun TTS grand public ne lit correctement du LaTeX brut. La solution standard :

1. **Traduire les maths en français parlé avant de les envoyer au TTS.** `\lim_{x \to
   1^-} (x+1)` doit devenir « la limite, quand x tend vers 1 par valeurs inférieures, de
   x plus 1 ». Deux voies : soit le générateur IA produit **une narration déjà rédigée
   en toutes lettres** (c'est déjà le cas : le champ `narration` de la scène 7 est en
   français naturel, sans LaTeX !), soit on passe par **Speech Rule Engine** (SRE), la
   bibliothèque de référence qui convertit MathML/LaTeX en descriptions parlées, et qui
   sait produire du SSML.
2. **Règle d'or à inscrire dans le générateur** : le champ `narration` ne doit **jamais**
   contenir de LaTeX. C'est du texte destiné à être lu à voix haute. (Aujourd'hui il est
   déjà propre — il faut le verrouiller pour que ça le reste.)

### Options de voix, du moins cher au plus qualitatif

| Option | Qualité FR | Coût | Licence | Verdict |
|---|---|---|---|---|
| **gTTS** (actuel, moteur Vision) | Robotique | Gratuit | — | ❌ à abandonner |
| **Kokoro-82M** (déjà installé sur LWS) | Bonne, naturelle | **0 €** (auto-hébergé, CPU) | Apache 2.0 | ✅ **socle recommandé** |
| **Chatterbox** (Resemble AI) | Très expressive, clonage de voix depuis 10 s | 0 € auto-hébergé (~6 Go) | MIT | ✅ si tu veux une **voix signature** de marque |
| **Google Cloud WaveNet** | Très bonne | ~4 $/1M caractères | commercial | 💡 le moins cher des managés |
| **OpenAI TTS / Fish Audio** | Très bonne | ~15 $/1M caractères | commercial | 💡 alternative |
| **ElevenLabs** | Excellente | Le plus cher | commercial | ⚠️ réservé si vraiment nécessaire |

**Recommandation** : rester sur **Kokoro** (déjà installé, 0 €) et régler le vrai
problème — la préparation du texte. Une vidéo de 3 min ≈ 2 500 caractères : même chez
Google WaveNet, cela coûterait ~0,01 € par vidéo. Le coût n'est donc **pas** le facteur
limitant ; **passer à un TTS payant sans corriger la lecture des maths ne réglerait
rien.** Tester d'abord Kokoro avec un texte bien préparé, et n'envisager un abonnement
que si la voix elle-même reste insuffisante.

---

# PARTIE 4 — Schéma de scène enrichi (contrat IA ↔ moteur)

Pour que LWS puisse rendre tout ce qui précède, le générateur doit décrire la mise en
scène **dans la scène elle-même**. Champs à ajouter au schéma existant :

```jsonc
{
  "writing_style": "handwriting" | "typed",   // niveau storyboard (choix étudiant)
  "scenes": [{
    "title": "...",
    "narration": "texte en toutes lettres, JAMAIS de LaTeX",
    "duration_ms": 20000,
    "transition": { "kind": "slide" },
    "recall": { "target": 3, "kind": "circle" },     // déjà supporté
    "page_break": false,                              // NOUVEAU : forcer une page neuve
    "blocks": [{
      "type": "correction",
      "content": "3. Est-ce que $\\lim_{x \\to 1} f(x) = f(1)$ ? Non !",
      "math_inline": true,                            // NOUVEAU : contient du LaTeX à rendre
      "emphasis": "underline",                        // circle|underline|highlight|color|bold
      "emphasis_target": "n'est PAS continue",        // NOUVEAU : sur QUELS mots, pas tout le bloc
      "write_speed": "normal"                         // NOUVEAU : lent pour une notion clé
    }]
  }]
}
```

**Trois ajouts essentiels** :
- `emphasis_target` : aujourd'hui l'annotation vise le bloc entier. Un prof entoure **un
  mot**, pas un paragraphe.
- `math_inline` : signale au moteur qu'il doit passer le contenu par KaTeX même si le
  bloc n'est pas de type `formula` (c'est la cause du défaut n°1).
- `page_break` : laisse l'IA décider des respirations (nouvelle page = nouveau chapitre).

Un **garde-fou serveur** doit ignorer silencieusement tout champ invalide (déjà le cas
pour `recall`) : le rendu ne doit jamais échouer à cause d'une hallucination de l'IA.

---

# PARTIE 5 — Ce qu'il faut installer sur LWS

## 5.1 Correctifs immédiats (moteur Vision, production actuelle)

| Paquet | Commande | Pourquoi |
|---|---|---|
| `gTTS` (Python) | `pip3 install gTTS` | Sans lui, **zéro voix**. Cause du défaut n°3 |

Les défauts n°1 (KaTeX inline) et n°2 (numérotation) sont des **corrections de code**
dans `whiteboard_scene_engine.py` — c'est à Claude de les faire, pas une installation.

## 5.2 Pour la mise en scène cible (moteur Remotion)

| Paquet | Rôle | Déjà installé ? |
|---|---|---|
| `@remotion/paths` | Tracé SVG progressif → **écriture manuscrite** | ✅ (dans `package.json`) |
| `@remotion/transitions` | Transitions entre scènes | ✅ |
| `@remotion/motion-blur` | Douceur des mouvements de caméra (défilement, rappel) | ✅ |
| `@remotion/google-fonts` | Polices **Caveat** / **Patrick Hand** (manuscrit) | ✅ |
| `@remotion/media-utils` | Waveform audio → **calage écriture / voix** | ✅ |
| `katex` | Formules | ✅ |
| **`speech-rule-engine`** | LaTeX/MathML → **texte parlable** (filet de sécurité TTS) | ❌ **à installer** |
| `@remotion/lottie` | Illustrations animées (vague 2) | ✅ |
| `@remotion/skia` | Effets lumineux premium (vague 2, optionnel) | ❌ |

**Bonne nouvelle : l'essentiel est déjà installé sur LWS.** Le blocage n'a jamais été
l'outillage — c'est que le moteur Remotion n'a jamais tourné en production. Il tourne
depuis aujourd'hui.

---

# PARTIE 6 — Plan d'exécution proposé (par vagues, sans régression)

### Vague 0 — Réparer l'existant (urgent, moteur Vision en production)
1. Corriger le rendu KaTeX inline (défaut n°1) — *code, Claude*
2. Corriger la numérotation dupliquée (défaut n°2) — *code, Claude*
3. Installer `gTTS` sur LWS pour rétablir la voix (défaut n°3) — *LWS, Windsurf*
4. Valider par un rendu réel — *Claude, via Supabase*

### Vague 1 — Basculer sur le moteur studio
5. Enrichir le générateur : `writing_style`, `emphasis_target`, `math_inline`,
   `page_break` + verrouiller « narration sans LaTeX » — *Edge Function, Claude*
6. Câbler ces champs dans le moteur Remotion (écriture progressive, défilement de page,
   annotations ciblées) — *code, Claude*
7. Brancher Kokoro sur le texte préparé, valider la lecture de `f(x)` — *Claude + test réel*
8. Rendu de validation, comparaison côte à côte avec Vision — *Claude*
9. Si validé : basculer l'app sur `engine: remotion` — *Claude*

### Vague 2 — Finitions haut de gamme
10. Choix manuscrit/machine exposé dans l'app — *Flutter*
11. Tracé SVG réel pour les titres et formules clés (`@remotion/paths`)
12. Illustrations Lottie, fonds Pexels, effets lumineux

### Vague 3 — Maths animées
13. Manim pour les formules qui se construisent (matières scientifiques)

---

## Sources externes consultées

- [Speech Rule Engine — LaTeX/MathML vers descriptions parlées](https://github.com/speech-rule-engine/speech-rule-engine)
- [Azure SSML — prononciation des expressions mathématiques (`mstts:prompt domain="Math"`)](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/speech-synthesis-markup-pronunciation)
- [Intelligibilité des TTS pour les expressions mathématiques (étude 2026)](https://arxiv.org/pdf/2506.11086)
- [Effet handwriting en SVG — stroke-dasharray / stroke-dashoffset](https://css-tricks.com/how-to-get-handwriting-animation-with-irregular-svg-strokes/)
- [Comparatif TTS auto-hébergés 2026 — Kokoro, Chatterbox, Piper](https://www.sevenlabs.site/blogs/best-self-hosted-tts-models-2026)
- [Chatterbox (Resemble AI) — MIT, préféré à ElevenLabs en test aveugle](https://www.tryspeakeasy.io/blog/open-source-text-to-speech-2026)
- [Comparatif prix des API TTS 2026 (Google WaveNet ~4 $/1M car.)](https://gradium.ai/content/best-elevenlabs-alternatives-2026-tts-apis-voice-quality-price)
