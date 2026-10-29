# Studio 3D — illustrer n'importe quel sujet, à la demande (29/10/2026)

Suite de `STUDIO_3D_BIBLIOTHEQUE_ILLUSTRATION_2026-10-28.md` (les sept étagères) et
de la phase B mise en ligne le 29/10 (`main` `ee7fc29`, génération v71).

La question de Jocelyn, après l'essai « l'eau » sur le TECNO :

> Ici on parle de l'eau, je ne vois pas les équations chimiques qui s'écrivent, qui
> s'équilibrent. Comment enrichir pour que tout ce qu'un usager évoque puisse être
> produit, et de très haut niveau ? Par de vraies recherches externes. Comment
> documenter et mettre en place un dispositif qui, à la demande, nous fournit ce
> dont on a besoin ?

## 1. La réponse courte

1. **La règle qui ressort de la recherche externe : l'IA choisit, notre code
   calcule.** Les modèles se trompent encore sur la science qu'ils dessinent (§3).
   Ils sont bons pour décider *quoi* montrer. Ils ne doivent jamais fixer *ce qui
   est vrai à l'écran* : un coefficient, une géométrie, une courbe. Notre code le
   calcule, de façon exacte.
2. **Le catalogue fermé reste la base, mais il devient extensible à la demande.**
   Quand la capsule demande une chose absente, un **résolveur** la cherche dans des
   sources ouvertes vérifiées, la met en cache, et elle entre au catalogue. La
   bibliothèque grandit avec l'usage, sans qu'on la remplisse à la main (§5).
3. **La chimie est le meilleur premier lot.** « L'eau » appelle exactement ce qu'on
   sait faire de façon exacte et animée : `2 H₂ + O₂ → 2 H₂O` qui s'écrit, des
   atomes comptés de chaque côté, des coefficients qui apparaissent quand ça ne
   tombe pas juste, et les molécules en 3D au-dessus de chaque terme (§4).

## 2. Ce qui existe déjà, et ce qui sert

| déjà là | où | ce qu'on en fait |
|---|---|---|
| 15 verbes dont 5 phénomènes et 3 accessoires | `lecteur.js`, `validate_capsule.ts` (phase B, en ligne) | la base du vocabulaire |
| molécules en boules et bâtonnets, 9 formules | `MOLECULES` de `lecteur.js` | s'étend à **toute** formule par PubChem (§5) |
| texte écrit dans la toile | `ecrireTexte()`, `lecteur.js:918` | support des équations et des indices |
| formules mathématiques KaTeX | `whiteboard_vision/` (tableau manuscrit) | prouvé côté tableau ; le tableau est à l'arrêt depuis la suppression de LWS |
| catalogue fermé de 69 objets, validé par test | `validate_capsule_termes_test.ts` | le modèle de la règle « on ne cite que ce qui existe » |
| banc de vérification image par image | `index.html`, `verifierCapsule()` | la porte d'entrée d'un nouvel élément |
| fabrication de la vidéo sur le téléphone | `exporterPourApp()`, 29/10 | tout élément nouveau entre aussi dans la vidéo publiée |

**Ce qui existe et ne sert pas encore** : KaTeX est déjà dans le dépôt pour le
tableau, mais pas dans le lecteur 3D. Les formules mathématiques (fractions,
intégrales) peuvent passer par le même chemin plutôt que par une nouvelle
bibliothèque.

## 3. Ce que dit la recherche externe

### La littérature : le « code d'abord » marche, l'image générée non

- **TheoremExplainAgent** (ACL 2025, TIGER-AI-Lab) : un agent qui écrit des scripts
  Manim pour expliquer 240 théorèmes. 93,8 % de vidéos produites avec o3-mini, note
  globale 0,77, et « la plupart des vidéos ont de petits défauts de mise en page ».
  **Mesure publiée sur un banc**, pas une démonstration.
- **Code2Video** (NUS Show Lab, NeurIPS 2025, arXiv 2510.01174) : trois agents
  (planificateur, codeur, critique visuel). **+40 %** sur leur métrique par rapport
  à la génération de code directe. Code et données publics. **Mesure.**
- **Le contrepoint** : un article ICML 2026 sur la vidéo scientifique automatique
  montre que les modèles de vision chargés de vérifier les figures **ratent jusqu'à
  86 % des erreurs injectées**. Un juge automatique ne suffit donc pas à garantir
  l'exactitude. Il peut classer, pas certifier.
- **La chimie dessinée par l'IA** : une évaluation de GPT-4o (arXiv 2505.05501)
  relève des substances mal étiquetées et des atomes mal reliés. Une prépublication
  de 2026 constate de nets progrès sur les structures simples, mais des erreurs
  fréquentes sur les molécules complexes. Des chimistes, cités par Chemistry World,
  demandent qu'on **bannisse** le dessin de structures par IA générative.

**Ce qu'on en déduit.** La voie « l'IA écrit une description, notre moteur
l'exécute » est celle qui fonctionne, et c'est déjà la nôtre. Le gain des agents
codeurs vient d'une **boucle de critique**, pas du code libre. Et l'exactitude
scientifique doit sortir d'un calcul, jamais d'un dessin ou d'un jugement de modèle.

### Les plateformes : comment le marché fait

- **Vyond** : une bibliothèque de dizaines de milliers d'éléments, plus « Text to
  Prop » depuis 2023, qui fabrique dans son style un élément absent. C'est
  exactement le dispositif à la demande, appliqué à des accessoires de bureau, pas à
  la science. Chiffres de l'éditeur ou de revendeurs, **annonces**.
- **PhET** (Université du Colorado) : la référence des simulations scientifiques,
  écrites à la main par des équipes de chercheurs. Collection HTML5 historique sous
  CC BY 4.0. On peut s'en inspirer, pas l'intégrer dans notre rendu.
- **Les modèles vidéo** (Veo 3.1 sur l'API Gemini) : de 0,05 $ à 0,60 $ par
  seconde selon l'offre (agrégateur, **non lu** sur la page de Google). Une capsule
  de 60 s coûterait de 3 à 36 $, contre environ 0,007 $ aujourd'hui. Ils ne sont pas
  non plus déterministes : la vidéo publiée ne serait pas celle qu'on a vue.

### Les dépôts et les sources ouvertes

| source | ce qu'elle apporte | licence | vérifié |
|---|---|---|---|
| **PubChem** (PUG REST) | la vraie géométrie 3D de presque toute molécule, par son nom | données du gouvernement américain, domaine public, citation de la NLM demandée ; certains dépôts tiers ont leurs propres droits | **appel mesuré** : glucose, 24 atomes, **1,1 s**, 4 Ko, sans clé. Conditions lues sur une page NCBI archivée seulement |
| **KaTeX** + mhchem | équations chimiques écrites (`\ce{2H2 + O2 -> 2H2O}`) | MIT (le portage mhchem de KaTeX) | résumé lu, pas le fichier LICENSE |
| **MathJax** (sortie SVG) | une formule devient une image, donc une texture 3D | Apache 2.0 | résumé lu |
| **3Dmol.js** | visualiseur moléculaire WebGL | BSD | article lu ; inutile pour nous, notre rendu suffit |
| **Équilibrage chimique** | algorithme exact : noyau d'une matrice entière | code de Nayuki lisible ; on écrit le nôtre (≈ 60 lignes) | méthode publiée et connue |
| **TRELLIS.2** (Microsoft) | un objet 3D fabriqué à partir d'une image | MIT d'après plusieurs sources, **fichier LICENSE non lu** | carte 24 Go exigée, donc notre pod GPU |
| **Meshy** (API payante) | un objet 3D à partir d'un texte | sortie à nous sur les offres payantes (CC BY sur l'offre gratuite) | page de prix lue, versions contradictoires |
| **Motion Canvas** | animations vectorielles en TypeScript | MIT | dépôt peut-être à l'abandon (signalement non vérifié) ; non retenu |

## 4. Le premier lot : la chimie exacte et animée

Trois verbes nouveaux, tous calculés par notre code :

| verbe | ce que l'IA écrit | ce que notre code calcule | ce qui bouge à l'écran |
|---|---|---|---|
| `reaction` | `{ equation: "H2 + O2 -> H2O" }` | les coefficients (`2, 1, 2`), par le noyau de la matrice des atomes | l'équation s'écrit, les atomes sont comptés de chaque côté (rouge quand ça ne tombe pas juste), les coefficients apparaissent un à un, tout passe au vert |
| `molecule` (étendu) | `{ formule: "C6H12O6" }` ou `{ nom: "glucose" }` | la géométrie réelle, tirée de PubChem et mise en cache | la molécule tourne. Pendant la réaction, autant de molécules qu'indique le coefficient |
| `equation` | `{ latex: "\\int_a^b f(x)\\,dx" }` | le rendu exact (KaTeX ou MathJax en SVG) | la formule apparaît terme à terme |

**Pourquoi l'IA ne donne pas les coefficients.** S'ils sont faux, la vidéo enseigne
une erreur. Si notre code ne trouve pas d'équilibre, l'équation est fausse : la
validation l'écarte et le dit, comme pour une molécule inconnue.

**Ce que verrait l'étudiant dans « l'eau »** : deux molécules H₂ et une O₂ qui
s'approchent, `H₂ + O₂ → H₂O` qui s'écrit, « H : 2 | 2 », « O : 2 | 1 » en rouge, le
2 qui se pose devant H₂O, puis devant H₂, et l'ensemble passe au vert. Ensuite, deux
molécules d'eau en 3D.

## 5. Le dispositif à la demande : le résolveur

Aujourd'hui, une demande hors catalogue finit en geste absent (« bois », le 29/10).
Le résolveur la transforme en élément, et l'élément reste.

```
capsule générée ──► validation ──► élément connu ?  ── oui ──► joué
                                        │ non
                                        ▼
                      résolveur (fonction Edge, avant la lecture)
        1. synonymes et carte notion → éléments   (« bois » → « arbre », bûche)
        2. sources ouvertes vérifiées, par famille :
             molécule → PubChem      objet → Objaverse CC-BY / CC0 filtré
             créature → Quaternius   formule → KaTeX / MathJax
        3. fabrication (option) : TRELLIS.2 sur le pod, ou Meshy payant
        4. repli : le mot écrit, et la demande enregistrée
                                        │
                                        ▼
      cache Supabase (allégé, licence et auteur notés) ──► catalogue, version +1
```

Cinq règles, chacune tirée d'un défaut déjà payé :

1. **Rien n'entre sans sa licence lue** : la source, l'auteur, la licence et la date
   sont enregistrés avec l'élément, et l'attribution s'affiche à l'écran.
2. **Rien n'entre sans passer le banc** : la vérification image par image (pixels
   allumés, mouvement) qui sert déjà aux capsules.
3. **Un élément fabriqué (étape 3) reste « à valider »** tant qu'un humain ne l'a pas
   vu. Le juge automatique peut classer, il ne publie pas, puisqu'il rate jusqu'à
   86 % des erreurs.
4. **Chaque demande non servie est comptée.** Le tableau « ce qu'on nous a demandé
   et qu'on n'avait pas » devient la liste de travail. C'est lui qui dit quoi
   ajouter, pas une intuition.
5. **Le résolveur tourne avant la lecture, jamais pendant.** Le téléphone reçoit une
   capsule dont tous les éléments existent. On a déjà vu ce que coûte une attente
   sur le téléphone (objets de 35 Mo, 28/10).

## 6. Mesurer qu'on illustre tout : le banc de couverture

- 200 sujets tirés des programmes du Burkina (collège, lycée, première année
  d'université), par discipline.
- Pour chaque sujet : la part des scènes qui montrent un élément **pertinent**, la
  part des demandes servies par le résolveur, et la part écrites en repli.
- Cible : passer de **15,6 %** de scènes avec un objet réel (mesuré le 28/10) à plus
  de **80 %** de scènes qui montrent ce que dit la phrase.
- Le test de compréhension façon *TeachQuiz* (Code2Video) peut s'ajouter : un modèle
  répond à un quiz avant et après la vidéo. Il classe, il ne certifie pas.

## 7. Ce qui a été écarté, et pourquoi

| écarté | motif |
|---|---|
| générer la vidéo avec un modèle vidéo (Veo, etc.) | de 400 à 5 000 fois plus cher par capsule ; non déterministe, donc la vidéo publiée diffère de celle qu'on a vue ; erreurs scientifiques documentées |
| laisser l'IA écrire du code JavaScript exécuté sur le téléphone | faille de sécurité dans la WebView de l'étudiant ; notre liste fermée de verbes donne le même gain, sans le risque |
| laisser l'IA dessiner les structures chimiques ou donner les coefficients | erreurs documentées ; appel de chimistes à l'interdire |
| un juge automatique qui publie seul | il rate jusqu'à 86 % des erreurs (ICML 2026) |
| intégrer PhET | des simulations interactives écrites à la main, pas un vocabulaire qu'on peut composer |

## 8. Le plan

Il complète les phases C à E du 28/10 sans les remplacer.

| lot | contenu | effort estimé | nouvel APK ? |
|---|---|---|---|
| **B2** chimie exacte | `reaction` avec équilibrage, `molecule` étendu par PubChem et mis en cache, indices bien écrits, consigne et tests | 2 à 3 jours | non |
| **B3** formules | `equation` (KaTeX ou MathJax en texture), écriture terme à terme | 1 à 2 jours | non |
| **R** résolveur | fonction Edge, cache Supabase, carte notion → éléments, tableau des demandes non servies | 3 à 4 jours | non |
| C, D, E | créatures et milieux, mathématiques et société, banc de 200 sujets (plan du 28/10) | environ 2 semaines | non |

Tout se joue côté lecteur et serveur. L'application installée en profite sans
réinstallation, sauf le téléchargement et la publication, qui sont dans la 1.0.9+41.

## 9. Non vérifié, nommément

- les conditions de PubChem lues **à la source** (seule une page NCBI archivée l'a été) ;
- le fichier LICENSE de TRELLIS.2, de KaTeX mhchem et de MathJax (résumés seulement) ;
- les prix de Veo 3.1 sur la page de Google (agrégateur seulement) ;
- le chiffre exact de 93,8 % de TheoremExplainAgent : sa définition du succès n'a
  pas été lue dans l'article complet ;
- le rendu de KaTeX ou MathJax **comme texture** dans notre lecteur, et son coût sur
  le TECNO.

## Sources (consultées le 29/10/2026)

- TheoremExplainAgent : [ACL 2025](https://aclanthology.org/2025.acl-long.332), [arXiv 2502.19400](https://arxiv.org/pdf/2502.19400)
- Code2Video : [arXiv 2510.01174](https://arxiv.org/pdf/2510.01174), [NeurIPS 2025](https://neurips.cc/virtual/2025/131666)
- Vérification des figures scientifiques : [ICML 2026](https://icml.cc/virtual/2026/76623)
- Chimie et IA générative : [arXiv 2505.05501](https://arxiv.org/pdf/2505.05501), [Chemistry World](https://www.chemistryworld.com/news/the-chemistry-community-should-ban-drawing-chemical-structures-with-generative-ai-chemists-warn/4022242.article), [prépublication 2026](https://www.preprints.org/manuscript/202607.2292), [Duke](https://sites.duke.edu/ddmc/2026/02/10/molecular-mess/)
- Scènes 3D écrites par des modèles : [WorldCoder-Bench](https://arxiv.org/pdf/2606.01869), [SceneCraft](https://arxiv.org/pdf/2403.01248)
- Vyond : [bilan 2023](https://www.vyond.com/blog/vyond-in-2023-big-advances-in-applied-ai-and-accessibility-more-happy-customers/), [document revendeur 2026](https://assets.applytosupply.digitalmarketplace.service.gov.uk/g-cloud-15/documents/705959/227305132873709-service-definition-document-2026-01-29-0900.pdf)
- PhET : [licence HTML5](https://phet.colorado.edu/en/licensing/html)
- PubChem : [notes 3D](https://pubchem.ncbi.nlm.nih.gov/release3d.html), [politiques NCBI](https://www.ncbi.nlm.nih.gov/home/about/policies/), [page NCBI archivée](https://cybercemetery.unt.edu/oilspill/20120927235528mp_/http://www.ncbi.nlm.nih.gov/About/disclaimer.html)
- KaTeX : [extensions](https://katex.org/docs/libs) ; MathJax : [Wikipédia](https://en.wikipedia.org/wiki/MathJax), [sortie SVG](https://docs.mathjax.org/en/v3.0/output/svg.html)
- 3Dmol.js : [article](https://pmc.ncbi.nlm.nih.gov/articles/PMC4393526)
- Équilibrage : [Nayuki](https://www.nayuki.io/page/chemical-equation-balancer-javascript), [méthode du noyau](https://hackage-content-origin.haskell.org/package/chemical-equation)
- TRELLIS.2 : [ComfyUI wiki](https://comfyui-wiki.com/en/models/trellis/trellis-2) ; Meshy : [prix de l'API](https://docs.meshy.ai/api/pricing)
- Veo : [benchlm](https://benchlm.ai/media-pricing/veo)
- Motion Canvas : [documentation](https://motioncanvas.io/docs)
- Mesure : `curl "https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/name/glucose/SDF?record_type=3d"` → 1 137 ms, 4 037 octets, 24 atomes.
