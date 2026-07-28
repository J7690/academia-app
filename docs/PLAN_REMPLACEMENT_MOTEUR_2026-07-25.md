# Remplacer Remotion — analyse et plan de reprise

**Date** : 25 juillet 2026, fin de journée
**Décision du propriétaire** : remplacer Remotion par un moteur plus simple et plus efficace.

---

## 1. Ce que la journée a réellement établi

### Le fait décisif, découvert tardivement
Un worker non identifié, sur une machine inaccessible, consommait la même file que LWS
et rendait tout avec le moteur **Vision**. Il a intercepté la quasi-totalité des rendus
de la journée. **Tous les « succès Remotion » mesurés étaient en réalité des rendus
Vision.**

| Rendu | Moteur demandé | Temps | Vidéo | Ratio | Réellement produit par |
|---|---|---|---|---|---|
| remotion | remotion | 169 s | 151 s | 1,12× | worker fantôme → Vision |
| gravité | remotion | 114 s | 86 s | 1,33× | worker fantôme → Vision |
| manuscrit complet | remotion | 160 s | 154 s | 1,04× | worker fantôme → Vision |
| v36 production | remotion | 165 s | 156 s | 1,06× | worker fantôme → Vision |

Après verrouillage de la file (seuls les workers identifiés reçoivent du travail), **tout
rendu réellement effectué par Remotion prend 12 à 20 minutes** pour 2 min 30 de vidéo,
manuscrit ou non. Le témoin en mode « machine » (aucune écriture animée) est aussi lent :
**l'écriture manuscrite n'était pas le problème.**

### Conclusion technique
Remotion rend chaque image en pilotant un navigateur. Il compense normalement par la
parallélisation sur plusieurs cœurs — mais la mémoire de ce serveur (8 Go) nous a
contraints à `concurrency: 1`. Résultat : **1 cœur sur 4 utilisé, ~4 à 5× le temps réel**.
C'est structurel sur cette machine, pas un défaut de code.

### Ce qui reste acquis et réutilisable
- Verrou de la file de rendu (registre `app.whiteboard_workers`) — le worker fantôme est
  neutralisé définitivement, sans accès à sa machine.
- Générateur v36 : narration sans LaTeX, `emphasis_target`, `write_speed`, `writing_style`.
- Verbalisation française des maths (`math_speech_fr.py`) : « f de x », « l'intégrale de a
  à b »… — indépendante du moteur.
- Rythme piloté par la voix, correctifs KaTeX et numérotation du moteur Vision.
- Le **cahier des charges de la mise en scène**, désormais précis parce qu'implémenté une
  fois : écriture progressive, annotations ciblées transitoires, rappel pédagogique,
  défilement adouci, pagination.

---

## 2. Les options, avec leurs coûts réels

| Option | Vitesse attendue | Ce qu'on réutilise | Coût | Risque |
|---|---|---|---|---|
| **A. Vision v2 — HTML animé + capture vidéo** | **≈ 1× temps réel** (mesuré : Vision tourne à 1,0-1,4×) | Tout le HTML/CSS/KaTeX existant, le worker, la narration | Réécrire la mise en scène en CSS/JS — mais elle est **déjà spécifiée et déjà écrite une fois** en React | Capture en temps réel : risque d'images perdues sous charge |
| **B. Revideo / Motion Canvas** | 5-10× plus rapide que Remotion (rendu Canvas 2D, sans navigateur à photographier) | Rien du visuel ; la narration et le worker restent | Réécriture complète des composants ; KaTeX sur canvas est laborieux ; communauté 20× plus petite | Nouveau cadre à maîtriser |
| **C. Manim** | Rendu Cairo sur CPU, réputé **lent** sur animations complexes | Rien ; mais LaTeX natif et gestes pédagogiques intégrés (`Write`, `Circumscribe`) | Réécriture complète en Python | La lenteur est le reproche principal fait à Manim — on remplacerait un problème par le même |
| **D. Serveur plus puissant** | Remotion à 4 cœurs ≈ 4× plus rapide | Tout | Coût mensuel | Ne règle rien si la charge augmente |

---

## 3. Recommandation : option A — Vision v2

**Pourquoi c'est le plus simple et le plus efficace ici :**

1. **C'est le seul moteur dont la vitesse est déjà prouvée sur cette machine** : 1,0 à
   1,4× le temps réel, mesuré aujourd'hui sur sept rendus.
2. **Le rendu visuel est déjà bon** : la feuille de cahier, les lignes bleues, la marge
   rouge, les formules KaTeX — tout cela sort déjà proprement de Vision (validé sur tes
   captures).
3. **Aucun nouvel outil** : Python + Node + Playwright + Chromium sont déjà installés et
   maîtrisés. Pas de nouveau langage, pas de nouvelle communauté à apprivoiser.
4. **La mise en scène est déjà spécifiée précisément** — la journée n'a pas été perdue :
   on sait exactement quels gestes produire, avec quel rythme, et pourquoi.

**Le changement de fond** : au lieu de *photographier* la page une fois par scène (ce qui
donne un diaporama), on **filme** la page pendant que les animations CSS se jouent. Le
navigateur compose alors les animations avec son moteur graphique — c'est précisément ce
pour quoi il est optimisé, contrairement à la reconstruction image par image de Remotion.

**Le risque, énoncé franchement** : une capture en temps réel peut perdre des images si la
machine est chargée. Deux garde-fous prévus : enregistrer à 25 images/seconde plutôt que
30, et **vérifier après coup que la durée du fichier correspond à la durée attendue** —
un écart signalerait des images perdues, et le job échouerait explicitement plutôt que de
livrer une vidéo saccadée.

---

## 4. Plan de reprise (ordre proposé)

### Étape 0 — Nettoyer, une fois la décision confirmée
- Archiver `whiteboard_engine_remotion/` (ne pas supprimer : la mise en scène React y est
  la meilleure documentation de ce qu'il faut reproduire).
- Retirer la branche `engine=remotion` du worker.
- Repasser l'application sur `engine: vision` (une ligne, déjà centralisée dans
  `lib/config/backend_hosts.dart`).

### Étape 1 — Capture vidéo au lieu de capture d'image
Remplacer `capture_final_frame` par un enregistrement de la page. Valider sur une scène :
durée du fichier = durée attendue.

### Étape 2 — Cahier continu et défilement
Une seule page HTML contenant toutes les scènes, qui défile — au lieu d'une page par scène.

### Étape 3 — Écriture progressive
Révélation mot par mot en CSS (`animation-delay` échelonné), police manuscrite Caveat déjà
téléchargée sur le serveur.

### Étape 4 — Annotations ciblées
Cercle et souligné en SVG animé (`stroke-dashoffset`), transitoires ; surlignage
persistant. Ciblage par `emphasis_target`, déjà produit par le générateur v36.

### Étape 5 — Rappel pédagogique
Défilement inverse vers la notion visée, ré-annotation, retour.

### Étape 6 — Validation
Rendu complet, mesure du ratio temps de rendu / durée de vidéo. **Critère d'acceptation :
sous 2× le temps réel.**

---

## 5. Ce qu'il ne faut pas refaire

- Ne jamais conclure qu'un rendu a réussi sans vérifier **quel moteur** l'a produit.
- Mesurer le ratio temps de rendu / durée de vidéo à chaque essai : c'est ce chiffre qui
  aurait révélé le problème dès le premier rendu.
- Face à un symptôme de mémoire ou de lenteur, borner le problème (découpage, limites)
  avant de chercher la fuite.

## Sources
- [Comparatif Remotion / Motion Canvas / Revideo 2026](https://www.pkgpulse.com/blog/remotion-vs-motion-canvas-vs-revideo-programmatic-video-2026)
- [Remotion — comparaison officielle avec Motion Canvas](https://www.remotion.dev/docs/compare/motion-canvas)
- [Manim — page performance (rendu Cairo sur CPU)](https://docs.manim.community/en/stable/contributing/performance.html)
- [Playwright — API Screencast](https://playwright.dev/docs/api/class-screencast)
