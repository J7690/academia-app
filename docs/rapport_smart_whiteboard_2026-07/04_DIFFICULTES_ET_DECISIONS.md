# 04 — Difficultés rencontrées et décisions prises

> Ce fichier est le plus utile pour la suite : il conserve la **cause racine** de chaque
> problème et le **raisonnement** derrière chaque décision. C'est ce qui évitera de refaire
> les mêmes essais.

---

## Table des difficultés

| # | Difficulté | Statut |
|---|---|---|
| 1 | Formules mathématiques affichées en double | ✅ Résolu |
| 2 | Textes qui se chevauchent, caméra qui vise à côté | ✅ Résolu |
| 3 | Voix et écriture désynchronisées | ✅ Résolu |
| 4 | La capture représentait 78 % du temps de rendu | ✅ Résolu |
| 5 | GSAP incompatible avec la capture par tranches | ⚠️ Contourné (contrainte permanente) |
| 6 | L'Edge Function TTS ignore le paramètre `speed` | ⚠️ Contourné côté worker |
| 7 | Maths lues comme des suites de symboles | ✅ Résolu |
| 8 | La locale française de SRE dit « triangle » pour Δ | ✅ Résolu |
| 9 | L'élision cassait les noms de variables | ✅ Résolu |
| 10 | Kokoro-82M trop lent sur le VPS | ❌ Abandonné, décision documentée |
| 11 | « 10-15 s après le clic » arithmétiquement impossible | ✅ Reformulé et résolu |
| 12 | `storage.list()` bloqué par les policies RLS | ✅ Résolu (sonde HEAD) |
| 13 | Le lecteur restait collé à l'aperçu | ✅ Résolu (`ValueKey`) |
| 14 | `beginFrame` (CDP) : images blanches et plus lent | ❌ Prototype écarté |
| 15 | `plan()` retourne 5 valeurs, pas 3 | ✅ Résolu |
| 16 | PowerShell mange les `$variables` dans les commandes SSH | ⚠️ Contourné (méthode à retenir) |
| 17 | Risque de voix inaudible au mixage (`amix`) | ✅ Prévenu |
| 18 | `invalid_storyboard: Block missing field: order` au 1er test réel | ✅ Résolu |

---

## 1. Formules mathématiques affichées en double

**Symptôme.** Chaque formule apparaissait deux fois à l'écran, l'une propre, l'autre en texte
brut superposé.

**Cause racine.** KaTeX produit **deux couches** : une couche visuelle HTML et une couche
**MathML** destinée aux lecteurs d'écran. Cette couche MathML est normalement masquée par la
feuille de style `katex.css`. Or celle-ci était chargée **depuis un CDN** : dans le navigateur
headless du serveur, sans accès réseau garanti, elle n'arrivait pas — et la couche MathML,
n'étant plus masquée, s'affichait.

**Décision.** Charger `katex.css` **localement** depuis le VPS, et retirer explicitement la
couche MathML du DOM.

**Enseignement général.** Dans un rendu serveur, **aucune ressource externe** ne doit être
critique. Ce qui n'est pas local peut manquer, et l'échec se manifeste de façon visuellement
déroutante — ici, une feuille de style manquante ressemblait à un bug de rendu de formule.

---

## 2. Textes qui se chevauchent, caméra qui vise à côté

**Symptôme.** Sur du contenu réel — définition longue, formule haute — les blocs se
superposaient et la caméra cadrait un espace vide.

**Cause racine.** Les positions verticales étaient **estimées en Python** (« environ 30
caractères par ligne »). Cette heuristique ignore la police réelle, les césures, la hauteur
d'une formule KaTeX. L'erreur s'accumule bloc après bloc.

**Décision.** Le **rendu en deux passes** (détaillé dans `01_INFRA_LWS.md` §2) : on ouvre la
page une première fois pour **mesurer** les positions réelles dans le navigateur, puis on
réécrit la page avec une caméra recalculée sur ces mesures.

**Enseignement général.** **Ne jamais estimer ce qu'on peut mesurer.** Le navigateur connaît
la position exacte de chaque élément ; lui demander coûte une passe de rendu et supprime toute
une classe de bugs.

---

## 3. Voix et écriture désynchronisées

**Symptôme.** La voix parlait d'une notion pendant qu'une autre s'écrivait ; parfois la voix
était coupée par le passage à la scène suivante.

**Causes racines, au nombre de trois.**
1. La durée de scène venait du storyboard (`duration_ms`), pas de la voix réelle.
2. Une seule narration par scène couvrait plusieurs blocs (résolu en vague E par la narration
   par bloc).
3. Le générique de 3,2 s décalait l'image mais pas l'audio.

**Décisions.**
- **La voix est la référence temporelle.** La narration est produite **avant** la page ; c'est
  elle qui fixe la durée de chaque scène. `-shortest` n'est **pas** utilisé au mux : la vidéo
  est la référence de longueur, et un court silence final est préférable à une image tronquée.
- Narration **par bloc** (vague E).
- Décalage de la narration par ffmpeg `adelay` de `INTRO_SEC` dans le worker.

**Enseignement général.** Dans une vidéo pédagogique, **l'image se cale sur la voix, jamais
l'inverse**. Une voix coupée est perçue comme un défaut grave ; un demi-seconde de silence ne
se remarque pas.

---

## 4. La capture représentait 78 % du temps de rendu

**Mesure.** 194 secondes de capture sur 250 secondes de rendu total.

**Décision.** Filmer la **même page** en 3 tranches simultanées, chaque processus avançant les
animations CSS jusqu'à son instant de départ.

**Ce qui rend la chose possible** : les animations sont 100 % CSS, donc *seekables*. Un
processus peut sauter à la seconde 40 et filmer à partir de là.

**Effet secondaire heureux** : ce découpage a rendu l'**aperçu instantané** trivial à
implémenter — la tranche 0 est déjà un fichier autonome.

---

## 5. GSAP incompatible avec la capture par tranches ⚠️

**Le contexte.** GSAP est devenu gratuit et offrirait des timelines riches, de la typographie
cinétique avancée, des effets SVG — exactement le vocabulaire « spot » recherché.

**La cause de l'incompatibilité.** `record_scene.js` avance le temps en manipulant
`document.getAnimations()`, qui ne retourne que les animations **CSS** (Web Animations API).
Une animation pilotée par GSAP en JavaScript resterait **figée** dans une tranche démarrant à
la seconde 40 : les 40 premières secondes d'animation n'auraient jamais été jouées.

**Décision : 100 % CSS, non négociable.**

**Ce que cela coûte.** Certains effets sont plus laborieux à écrire en CSS pur (les
`@keyframes` sont verbeux, pas de calcul dynamique).

**Ce que cela rapporte.** La capture par tranches reste possible — donc le rendu reste rapide
**et** l'aperçu instantané fonctionne. Un moteur plus expressif mais 3 fois plus lent aurait
été un mauvais échange.

> ⚠️ **À retenir absolument** : toute future amélioration visuelle doit être réalisable en CSS
> pur. Si une animation exige du JavaScript impératif, elle casse la capture parallèle et
> l'aperçu instantané.

---

## 6. L'Edge Function TTS ignore le paramètre `speed` ⚠️

**Constat.** L'Edge Function `whiteboard-tts` reçoit `input` et `voice` mais **n'utilise pas**
`speed`. Envoyer un débit plus lent n'avait donc aucun effet.

**Décision.** Appliquer le ralenti **côté worker**, par ffmpeg `atempo`, suivi d'une
normalisation `loudnorm` à -16 LUFS.

**Pourquoi ne pas corriger l'Edge Function.** Le modèle TTS utilisé n'expose pas
nécessairement ce contrôle, et `atempo` donne un résultat maîtrisé et **identique quel que soit
le fournisseur TTS**. Le traitement côté worker rend la chaîne indépendante du fournisseur.

> ⚠️ **Piège pour l'avenir** : ne pas ré-ajouter un paramètre `speed` dans les appels TTS en
> croyant qu'il agit. Le réglage se fait dans `whiteboard_narration.py` via `TTS_SPEED = 0.88`.

---

## 7 & 8. Maths parlées : du charabia au français correct

**Symptôme initial.** `x^2 + bx + c = 0` lu comme une suite de symboles.

**Première solution** : `math_speech_fr.py`, module regex maison. Efficace sur les cas simples,
mais butant sur les fractions imbriquées, les limites, les vecteurs — problème
**structurellement** hors de portée des expressions régulières, car la structure
mathématique est un **arbre**, pas une chaîne.

**Solution retenue** : une chaîne qui respecte la structure.

```
LaTeX ──KaTeX──► MathML ──speech-rule-engine (ClearSpeak, fr)──► phrase française
```

MathML est un arbre : SRE peut donc raisonner sur la structure et produire « la fraction de
numérateur… de dénominateur… » correctement, à toute profondeur d'imbrication.

**Nouvelle difficulté : la locale française de SRE est imparfaite.** D'où la table `_FIXES` :

| SRE produit | Corrigé en | Raison |
|---|---|---|
| « triangle » | « delta » | Δ se dit delta en maths ; « triangle » est le nom de la *forme*, pas du *symbole* |
| « flèche droite » | « tend vers » | Notation de limite |
| limites | « par valeurs supérieures / inférieures » | Formulation académique française |
| vecteurs | forme corrigée | Ordre des mots inadapté |

**La difficulté n° 9 : l'élision cassait les variables.** La règle d'élision française
(« de x » → « d'x ») était appliquée à **tous** les mots. Résultat : des noms de variables et
des symboles courts se retrouvaient élidés à tort, produisant des sons incompréhensibles.

**Correction** : l'élision est restreinte aux **vrais mots, de 3 lettres ou plus**. « de
l'ensemble » ✅, mais pas d'élision devant une variable d'une ou deux lettres.

**Robustesse de la chaîne** : batch (une seule ouverture de Chromium pour toutes les formules)
+ cache + **repli automatique sur `math_speech_fr.py`** si SRE échoue. Une chaîne à 4 maillons
doit avoir un plan B.

---

## 10. Kokoro-82M : essai rigoureux, abandon assumé ❌

**L'objectif.** Une voix neuronale plus naturelle, en local, sans coût par requête.

**La mesure — un banc d'essai a été construit exprès.**

| Variante | RTF (facteur temps réel) | Traduction concrète |
|---|---|---|
| Kokoro-82M PyTorch CPU | **3,25** | 1 min de voix = 3 min 15 de calcul |
| Kokoro ONNX int8 | **4,5** | Pire encore |

**Pourquoi l'ONNX int8, censé être plus rapide, est plus lent ici** : l'affinité des threads
est bridée sur ce VPS, ce qui annule le bénéfice de la quantification.

**Décision : abandon.** Sur un cours de 90 secondes, la seule synthèse vocale prendrait 5
minutes — plus que tout le reste du rendu réuni. C'est incompatible avec l'exigence de
rapidité, qui est **la** priorité de l'utilisateur.

**Nettoyage effectué** : `/opt/kokoro-tts` et le cache HuggingFace supprimés du VPS, scripts de
banc d'essai locaux supprimés. Un artefact conservé pour référence d'écoute :
`academia_bobodo_backend/kokoro_echantillon_fr.wav`.

> ❌ **Règle pour l'avenir** : **pas de calcul d'IA sur la machine de rendu.** Toute
> amélioration de voix passe par une **Edge Function cloud**. Le VPS a 4 vCPU, ils sont
> entièrement dédiés à la capture vidéo — c'est là qu'ils rapportent le plus.

---

## 11. « 10-15 secondes après le clic » — impossible, donc reformulé ✅

**Le calcul.** Un cours de 90 s demande ~130 s de rendu. Même en divisant par 3 la capture,
on ne descend pas à 15 s. Ajouter des cœurs ne règle rien : la synthèse vocale et la mesure
sont séquentielles par nature.

**La reformulation.** Le besoin réel n'est pas « tout finir en 15 s », c'est « **ne pas
attendre devant un écran vide** ». On livre donc les 15 premières secondes en ~15 secondes.

**Décision.** L'aperçu instantané, côté serveur et côté application (voir `01` §4 et `03`).
Détail qui compte : la tranche 0 est filmée **seule d'abord**, donc sur 4 vCPU non partagés,
à vitesse maximale — puis les autres tranches partent en parallèle.

**Enseignement général.** Quand une exigence est arithmétiquement impossible, il faut chercher
**le besoin derrière l'exigence**. Ici, reformuler a permis de satisfaire l'utilisateur
au lieu de lui expliquer pourquoi c'était infaisable.

---

## 12. `storage.list()` bloqué par les policies RLS ✅

**Symptôme.** L'application ne détectait jamais l'aperçu, alors que le serveur le publiait.

**Cause racine.** La détection utilisait `storage.list()`, soumis aux **policies RLS**, que
l'utilisateur n'a pas.

**Décision.** Sonder l'URL publique par une requête **HEAD** — la lecture d'un bucket public
ne passe pas par RLS, la détection ne peut donc plus échouer pour une question de droits.

**Bonus** : un HEAD est très léger, ce qui autorise un polling toutes les 2 s.

---

## 13. Le lecteur restait collé à l'aperçu ✅

**Symptôme.** La vidéo complète devenait disponible, mais l'étudiant continuait de voir
l'aperçu de 15 s en boucle.

**Cause racine.** Flutter **réutilise** un widget de même type et même position dans l'arbre.
Le lecteur vidéo était conservé, avec son contrôleur interne toujours attaché à l'ancienne
source.

**Décision.** `AcademiaPlaybackView(key: ValueKey(url), ...)` — la clé dépend de l'URL, donc
Flutter détruit et recrée le lecteur au changement de source.

**Enseignement général.** Tout widget encapsulant un **état externe** (contrôleur vidéo, socket,
lecteur audio) doit porter une clé dérivée de sa source. Sinon le cycle de vie du widget et
celui de la ressource divergent silencieusement.

---

## 14. `beginFrame` (CDP) : prototype écarté ❌

**L'idée.** `HeadlessExperimental.beginFrame` permet une capture **déterministe** image par
image, en temps virtuel : chaque image est parfaite, indépendamment de la charge machine.

**Le résultat mesuré** (`proto_capture_bf.js`) :
- **Plus lent** que la capture temps réel.
- Les images fixes ressortaient **blanches** — le rendu n'était pas achevé au moment de la
  capture.

**Décision.** Conserver la capture temps réel. Le fichier prototype reste comme trace de
l'essai.

> ⚠️ **Piège rencontré pendant la validation de la vague F** : `proto_capture_bf.js` a d'abord
> été utilisé pour prendre les captures de contrôle, qui sont ressorties **blanches** — ce qui
> a fait croire un moment que les animations ne fonctionnaient pas. Le problème venait de
> l'outil de capture, pas de la mise en scène. **Pour toute validation visuelle, utiliser
> `snap_still.js`.**

**Enseignement général.** Quand une validation échoue, vérifier **l'instrument de mesure**
avant de suspecter l'objet mesuré.

---

## 15. `plan()` retourne 5 valeurs, pas 3 ✅

**Symptôme.** Au premier test du sound design :
```
ValueError: too many values to unpack (expected 3)
```

**Cause.** `plan()` retourne `(planned, kf, total, doc_height, recalls)`. Le code de la vague G
en attendait 3.

**Correction.** `planned, _, total, _, _ = plan(storyboard, narration)`.

**Enseignement.** Un tuple de retour à 5 éléments non nommés est fragile. Si `plan()` évolue
encore, envisager une `dataclass` ou un `NamedTuple` — les appelants seraient alors insensibles
à l'ajout d'un champ.

---

## 16. PowerShell mange les `$variables` dans les commandes SSH ⚠️

**Symptôme.** Les commandes SSH contenant des variables shell (`$i`, `$f`, `$1`) arrivaient sur
le serveur avec les variables **déjà substituées par PowerShell** — donc vides.

**Décision.** Écrire un **script `.sh`**, le copier par `scp`, puis convertir les fins de ligne
avant exécution :

```powershell
ssh lws-nexiom "sed -i 's/\r$//' /chemin/script.sh && bash /chemin/script.sh args"
```

Le `sed` est indispensable : un script écrit sous Windows porte des `CRLF` que bash refuse.

> ⚠️ **Méthode à retenir** pour toute commande distante non triviale : script + `scp` + `sed`,
> jamais d'inline avec des `$`.

---

## 17. Risque de voix inaudible au mixage ✅ (prévenu)

**Le piège.** Le filtre `amix` de ffmpeg **divise par défaut** le volume par le nombre
d'entrées. Avec 29 entrées (voix + 16 bruitages + 12 grattés), la voix serait tombée à ~3 % de
son niveau — inaudible.

**Décision.** `amix=inputs=N:normalize=0:duration=first`

- `normalize=0` — chaque entrée garde le volume qu'on lui a assigné. Les volumes relatifs sont
  fixés explicitement (voix 1,0 ; whoosh 0,32 ; pop 0,26 ; tampon 0,40 ; gratté 0,10 ; musique
  0,10).
- `duration=first` — la voix est la référence temporelle.

**Vérification** : le mixage de test rend **88,900 s** pour une attente de 88,9 s — durée
exacte au centième.

---

## 18. `Block missing field: order` — la validation trop stricte ✅

**Symptôme.** Premier test grandeur nature (sujet « La Loi Normale Centrée Réduite »),
27/07/2026 17h33 :

```
FunctionException(status: 500, details: {error: invalid_storyboard,
detail: Block missing field: order, ...})
```

**Cause racine.** Le modèle a omis le champ `order` sur un bloc. La validation exigeait
5 champs par bloc (`id`, `type`, `content`, `order`, `visible`) et **rejetait toute la
génération** si l'un manquait.

Or `order` est **déductible** : c'est la position du bloc dans le tableau. `id` n'a besoin que
d'être unique. `visible` vaut `true` par défaut. On perdait donc un cours entier — et les
crédits de l'étudiant — pour trois champs qu'on savait calculer.

**Deuxième défaut, plus révélateur.** Les champs de premier niveau `created_at`, `created_by`,
`subject`, `renderer`, `theme`, `narration_mode` étaient **exigés** par la validation… puis
**écrasés** juste après, lignes 282-283, par les valeurs de la requête. On rejetait des
générations pour des champs qu'on remplaçait de toute façon.

**Décision : étendre « nettoyer, jamais rejeter » aux champs structurels.**

La règle appliquée : **n'exiger que l'irremplaçable.**

| Niveau | Exigé | Complété silencieusement |
|---|---|---|
| Storyboard | `scenes` (non vide) | `version`, `export_settings` — le reste est écrasé par la requête |
| Scène | `blocks` (tableau non vide) | `id`, `order` (= position), `title` (= `''`), `duration_ms` (= 8000, recalculé ensuite d'après la voix) |
| Bloc | `content` non vide | `id`, `order` (= position), `visible` (= `true`), `type` (inconnu → `paragraph`) |

Trois adoucissements supplémentaires, du même esprit :
- **Bloc vide → écarté**, au lieu de faire échouer le cours. On ne renonce que si la scène se
  retrouve sans aucun bloc.
- **Scène sans blocs exploitables → écartée.** Perdre une scène sur huit est infiniment
  préférable à perdre le cours entier.
- **Plafonds par troncature** (20 scènes, 10 blocs) au lieu du rejet : un cours un peu trop
  long vaut mieux qu'aucun cours.

**Enseignement général.** Une validation ne doit rejeter que ce qu'elle **ne peut pas
réparer**. Tout champ déductible de la structure, ou écrasé plus loin dans le traitement, ne
doit jamais être une condition de rejet. La question à se poser devant chaque contrôle :
*« si ce champ manque, est-ce que je sais quoi mettre ? »* Si oui, le mettre.

**Portée du correctif.** Cette classe de panne était **latente sur tous les champs
structurels** : le même cours aurait pu échouer sur un `id` manquant, un `visible` oublié, un
`title` absent. Le test grandeur nature a révélé une occurrence ; le correctif couvre la
famille entière.

---

## Deux décisions transversales qui méritent d'être conservées

### A. « Nettoyer, jamais rejeter » (validation du storyboard)

Un modèle de langage se trompe. Rejeter une génération entière pour un `beat` mal orthographié
ferait perdre à l'étudiant ses crédits **et** sa vidéo. On supprime donc le champ fautif et on
rend la vidéo sans cet enrichissement.

**Conséquence heureuse** : cette philosophie rend les champs v3 **rétro-compatibles par
construction**. Aucun storyboard existant ne casse, aucune migration n'est nécessaire.

### B. « Dégradation gracieuse » à chaque maillon

Chaque brique ajoutée pendant la session a un plan B explicite :

| Brique | Si elle échoue |
|---|---|
| Mesure des positions | Positions estimées (moins précises, mais ça rend) |
| Capture par tranches | Enregistrement d'une seule traite |
| Publication de l'aperçu | Journalisée et ignorée, le rendu continue |
| SRE (maths parlées) | Repli sur `math_speech_fr.py` (regex) |
| TTS OpenRouter | Repli sur gTTS |
| Sound design | Narration seule |
| Collage audio | Vidéo muette |

**Le principe** : *l'étudiant a toujours son cours.* Une vidéo imparfaite vaut infiniment mieux
qu'un échec — et sur une chaîne à 5 maillons, un échec sans plan B serait fréquent.
