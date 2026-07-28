# Quel moteur pour la mise en scène ? — Décision technique argumentée

**Date** : 25 juillet 2026
**Question posée par le propriétaire** : « Tu parles de chantier Remotion alors qu'on
avait décidé de renforcer le dispositif déjà en place sur LWS. Il faut faire la
distinction de ce qu'on va utiliser réellement AVANT de faire les implémentations. »

La question est juste, et elle repose sur un malentendu qu'il faut lever d'abord.

---

## 1. Le malentendu : les DEUX moteurs sont déjà en place sur LWS

« Le dispositif déjà en place » ne désigne pas un moteur, mais deux. Tous les deux sont
installés sur LWS et **tous les deux ont produit une vidéo aujourd'hui**, sous mes yeux :

| | Vision | Remotion |
|---|---|---|
| Installé sur LWS | ✅ | ✅ |
| Vidéo produite le 25/07 | ✅ 80 s de vidéo en 170 s | ✅ 151 s de vidéo en 169 s |
| Utilisé par l'app aujourd'hui | ✅ | ❌ (désactivé par précaution) |
| Code déjà écrit | template HTML + Python | **1 087 lignes de composants React** |

Choisir Remotion **n'est donc pas ouvrir un nouveau chantier** : c'est activer un moteur
déjà déployé, déjà fonctionnel, et déjà porteur du travail de mise en scène (cahier
continu, annotations, rappel) écrit en juillet mais jamais vu à l'écran faute de rendu.

---

## 2. Le fait technique décisif : Vision ne peut pas animer

Ce n'est pas une préférence, c'est une limite d'architecture, lisible dans le code.

`whiteboard_scene_engine.py` → `render_scene_to_png()` → `capture_final_frame()` :
**une seule capture d'écran par scène**, prise *après* la fin des animations CSS. Le
commentaire du code le dit explicitement :

> « Pour l'instant, capture un seul frame final par scène (Phase E ajoutera le
> multi-frame). »

Puis ffmpeg assemble ces images fixes. **Une vidéo Vision est un diaporama d'images
fixes.** Tout ce que tu demandes — l'écriture qui progresse, la feuille qui défile, le
cercle qui se trace puis s'efface, la caméra qui remonte vers une notion — suppose de
produire **30 images différentes par seconde**. Vision en produit **une par scène**.

### Que coûterait de rendre Vision animé ?

Une vidéo de 80 s à 30 images/s = **2 400 captures**. Aujourd'hui une capture Playwright
prend ~1,5 s (lancement de page, attente des animations). Même optimisé à 0,3 s par
image, cela ferait **12 minutes de rendu par vidéo**, contre 170 s aujourd'hui. Ce
n'est pas viable pour des étudiants qui attendent leur vidéo.

---

## 3. Les trois options réelles (recherche externe à l'appui)

### Option A — Remotion (le moteur studio déjà déployé)
Remotion rend **chaque image comme une capture de navigateur**, ce qui est lent en
théorie mais gère tout ce qu'un navigateur sait afficher. Mesuré chez nous : **151 s de
vidéo produite en 169 s**, soit quasiment le temps réel — nettement mieux que le
diaporama Vision (80 s de vidéo en 170 s).

- ✅ Écosystème complet **déjà installé** : `@remotion/paths` (tracé manuscrit),
  `transitions`, `motion-blur` (mouvements de caméra), `google-fonts` (Caveat),
  `media-utils` (calage sur la voix), `lottie`.
- ✅ Timing déterministe, image par image → synchronisation parfaite avec la narration.
- ✅ 1 087 lignes de composants déjà écrites (`Annotation.tsx`, `Scene.tsx`, `blocks.tsx`).
- ⚠️ Licence commerciale Remotion (à vérifier selon le nombre d'employés/CA — gratuite
  pour les particuliers et petites structures, payante au-delà).

### Option B — Vision v2 « screencast » (garder le HTML, filmer la page)
Plutôt que de capturer une image, on **filme** la page pendant que les animations CSS se
jouent, via l'API `page.screencast` de Playwright (disponible depuis la v1.59, qui permet
de démarrer/arrêter l'enregistrement en cours de test).

- ✅ Réutilise tout le travail HTML/CSS/KaTeX existant.
- ✅ Rendu ≈ temps réel.
- ❌ Cadence variable, qualité dépendante du navigateur ; la synchro fine avec l'audio
  devient délicate (c'est le point faible pour un cours où la voix commente l'écriture).
- ❌ Il faudrait **réécrire toute la mise en scène en CSS/JS** — c'est-à-dire refaire ce
  qui existe déjà en React côté Remotion.
- ⚠️ La capture vidéo Playwright ajoute une charge CPU et des écritures disque notables.

### Option C — Motion Canvas / Revideo (réécriture complète)
Motion Canvas rend via Canvas 2D — plus rapide pour des graphiques simples, mais limité
à ce que Canvas sait faire. Revideo en est un fork orienté production automatisée.
Licence MIT (gratuite).

- ✅ Licence MIT, sans condition.
- ❌ **Repartir de zéro** : ni le HTML de Vision ni le React de Remotion ne se réutilisent.
- ❌ Communauté bien plus restreinte (~8 000 et ~3 000 téléchargements hebdomadaires,
  contre ~60 000 pour Remotion) → moins de ressources en cas de blocage.
- ❌ KaTeX/formules et polices manuscrites à réintégrer manuellement.

---

## 4. Recommandation

**Option A — Remotion**, pour trois raisons factuelles :

1. **C'est le seul moteur capable d'animer** sans réécriture ni explosion des temps de
   rendu. Vision est structurellement un diaporama.
2. **Il est déjà en place et déjà plus rapide** que Vision sur nos mesures réelles
   d'aujourd'hui (quasi temps réel contre 2× le temps réel).
3. **Le travail de mise en scène y est déjà écrit** (annotations transitoires, rappel
   pédagogique, cahier continu) — il n'a jamais été vu, faute de rendu, mais il existe.

**Vision n'est pas jeté** : il reste le moteur de production actuel et le repli de
sécurité tant que Remotion n'est pas validé. Les correctifs du jour (formules, rythme,
voix scientifique) profitent d'ailleurs **aux deux moteurs** — la narration est commune.

### Le seul point à vérifier avant de s'engager : la licence Remotion
Remotion est gratuit pour les particuliers et les petites structures, mais impose une
licence payante au-delà d'un certain seuil (nombre d'employés / chiffre d'affaires).
**À vérifier sur remotion.pro avant d'industrialiser.** Si le seuil est franchi, l'option
C (Revideo, MIT) redevient pertinente — mais au prix d'une réécriture complète.

---

## 5. Ce qu'il faudra installer sur LWS (si Option A retenue)

| Paquet | Rôle dans la mise en scène | État |
|---|---|---|
| `@remotion/paths` | **Écriture manuscrite** : tracé SVG progressif | ✅ installé |
| `@remotion/google-fonts` | Polices Caveat / Patrick Hand | ✅ installé |
| `@remotion/transitions` | Passage d'une page à l'autre | ✅ installé |
| `@remotion/motion-blur` | Douceur du défilement et des rappels | ✅ installé |
| `@remotion/media-utils` | Calage écriture ↔ voix (waveform) | ✅ installé |
| `katex` | Formules | ✅ installé |
| `@remotion/lottie` | Illustrations animées (vague 2) | ✅ installé |
| `@remotion/skia` | Effets lumineux premium (optionnel) | ❌ à installer si besoin |

**Rien de bloquant à installer.** L'outillage est complet ; le travail restant est du
code, pas de l'infrastructure.

---

## 6. Plan d'implémentation proposé (si Option A validée)

1. **Écriture progressive** — révélation ligne par ligne calée sur la narration
   (`media-utils`), en police manuscrite ou machine selon `writing_style`.
2. **Feuille continue + défilement** — la caméra descend quand l'écriture atteint le bas ;
   rien ne s'efface ; nouvelle page quand la feuille est pleine.
3. **Annotations ciblées** — cercle/souligné qui se tracent, tiennent ~1,6 s puis
   s'effacent ; surlignage persistant ; sur **un mot** (`emphasis_target`), pas tout le bloc.
4. **Rappel pédagogique** — remontée caméra vers la notion visée, ré-annotation, retour.
5. **Enrichir le générateur** pour qu'il décrive tout cela dans les scènes
   (`writing_style`, `emphasis_target`, `page_break`).
6. Rendu de validation, comparaison côte à côte avec Vision, puis bascule de l'app.

## Sources

- [Remotion vs Motion Canvas vs Revideo — comparatif 2026](https://www.pkgpulse.com/blog/remotion-vs-motion-canvas-vs-revideo-programmatic-video-2026)
- [Alternatives à Remotion, matrice 2026 (approche, vitesse, coût)](https://autoae.online/blog/remotion-alternatives-compared-2026)
- [Playwright — API Screencast](https://playwright.dev/docs/api/class-screencast)
- [Playwright Screencast : coût CPU et stockage](https://testdino.com/blog/playwright-screencast)
- [Effet handwriting en SVG (stroke-dasharray / stroke-dashoffset)](https://css-tricks.com/how-to-get-handwriting-animation-with-irregular-svg-strokes/)
