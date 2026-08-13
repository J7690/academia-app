// L'invite de la capsule 3D — l'IA DECRIT une scene, elle ne la choisit plus.
//
// CE QUI CHANGE, ET POURQUOI.
// La version precedente enumerait dix formes -- `reseau`, `flux`, `strates`,
// `comparaison`, `titre`, `terrain`, `silhouette`, `chronologie`, `carte`,
// `ondes` -- et demandait au modele d'en CHOISIR une, puis de regler des
// nombres : `noeuds`, `couches`, `rayon`. Huit des dix n'acceptaient que cela.
//
// Mesure du 07/08 : « la sociologie » et « la germination » ont produit la MEME
// suite de formes. Un nombre de noeuds ne dit rien d'un sujet.
//
// Le moteur sait desormais executer une COMPOSITION : une suite de gestes,
// chacun nommant un verbe et ses coordonnees. La forme n'existe pas avant que
// la description l'ecrive. L'invite doit donc demander une DESCRIPTION, pas un
// choix.
//
// LA REGLE QUI PROTEGE L'ESTHETIQUE : le modele decrit CE QU'ON MONTRE, jamais
// COMMENT C'EST ECLAIRE. Couleurs, halo, exposition, epaisseur des aretes et
// cadrage viennent d'`academia3d_style.py` et sont identiques pour toutes les
// capsules. C'est ce qui fait qu'une capsule ressemble a toutes les autres tout
// en parlant de son sujet.

// La signature garde `mode` et `renderer` par compatibilite avec `index.ts:76`,
// meme si l'invite ne s'en sert plus : ce qui distinguait un rendu d'un autre
// etait le choix d'une forme dans un catalogue, et ce catalogue n'existe plus.
// Les changer ici sans changer l'appelant casserait la generation en silence.
export function getCapsulePrompt(_mode?: string, _renderer?: string): string {
  return `Tu conçois une capsule vidéo 3D pédagogique pour des étudiants
d'Afrique de l'Ouest. Format vertical 9:16, 60 à 110 secondes, 4 à 6 scènes.

Tu ne choisis pas une forme dans une liste : tu DÉCRIS la scène, en coordonnées.
Le moteur exécute ta description telle quelle.

════════ CE QUE TU DÉCIDES ════════

1. L'INTENTION de chaque scène — ce qu'elle fait comprendre. Six possibles :

   objet        montrer la chose elle-même (un organe, une machine, un fruit)
   processus    montrer une transformation, une suite d'étapes
   comparaison  opposer deux états, deux choix, deux quantités
   structure    montrer de quoi une chose est faite, ses parties
   echelle      montrer une grandeur, un rapport de taille, une étendue
   flux         montrer une circulation : sang, eau, argent, données, énergie

   C'est l'intention qui adapte la vidéo au sujet. La forme n'en est que la
   conséquence.

2. LES GESTES qui fabriquent la scène. Six verbes, tous décrits en NOMBRES :

   silhouetter  un squelette de segments, épaissi en volume.
                Pour tout ce qui a une ossature : corps, membre, plante, racine,
                vaisseau, neurone, rivière, branche, chaîne de montagnes.
                parametres: {
                  segments: [[[x,y,z],[x,y,z],…], [ …autre branche… ]],
                  rayons:   [r1, r2, …]  (une épaisseur par point, dans l'ordre),
                  lisser:   0 à 2,
                  nom:      "..."
                }
                Une branche qui repart d'un point DÉJÀ POSÉ doit reprendre ses
                coordonnées EXACTES : c'est ainsi qu'elle se raccorde.

   revolutionner  un profil tourné autour de l'axe vertical.
                Pour tout ce qui est de révolution : vase, colonne, entonnoir,
                fusée, verre, goutte, tour, cellule.
                parametres: { profil: [[rayon,hauteur], …], tours: 24 à 48,
                              position: [x,y,z] }
                Le profil part du bas. rayon ≥ 0.
                Le profil ne décale que la HAUTEUR : pour poser deux formes
                côte à côte — une comparaison — il FAUT leur donner des
                positions différentes en x, sinon elles se superposent.

   extruder     un contour 2D poussé en épaisseur.
                Pour une lettre, un symbole, un pays, une pièce, une section,
                une flèche, un panneau.
                parametres: { contour: [[x,y], …], epaisseur: 0.1 à 2.0 }
                Au moins 3 points, dans l'ordre du tracé.

   sculpter     un volume facetté à partir d'une base.
                bases: ovoide, sphere, galet, goutte, lentille
                parametres: { base, echelle, facettes: 1 à 3, position: [x,y,z],
                              deformation: 0 à 0.2 }

   napper       un terrain quadrillé jusqu'à l'horizon. Donne l'échelle.
                parametres: { cote: 60 à 220, pas: 24 à 60, amplitude: 0.5 à 3 }

   ecrire       du texte en volume. LE SECOURS : quand aucune forme ne convient,
                un mot, un chiffre ou une formule dit toujours le sujet.
                parametres: { texte: "...", taille: 0.8 à 1.6 }

3. LE RÔLE de chaque geste : "sujet" (ce dont on parle) ou "structure" (ce qui
   l'entoure et le situe). Le moteur en tire l'intensité lumineuse.

════════ CE QUE TU NE DÉCIDES PAS ════════

Couleurs, lumière, halo, exposition, épaisseur des traits, position de caméra,
durée des plans. Tout cela est fixe et identique pour toutes les capsules.
N'écris AUCUN de ces mots. Si tu en mets, ils seront ignorés.

════════ LES CONVENTIONS ════════

• Z est la HAUTEUR, Y la PROFONDEUR (négatif = loin), X la largeur.
• Un objet principal fait 2 à 5 unités. Reste dans −8..+8 en X et Z.
• Chiffres simples : deux décimales suffisent.

════════ CE QUE TU RENDS ════════

UNIQUEMENT ce JSON, sans texte autour, sans balise Markdown :

{
  "titre": "titre court et concret",
  "scenes": [
    {
      "id": "s1",
      "intention": "structure",
      "sujet": "ce que cette scène montre, en 3 à 6 mots",
      "narration": "Ce que la voix dit. Phrases courtes, ton d'enseignant.",
      "duree_s": 14,
      "gestes": [
        { "verbe": "silhouetter", "role": "structure",
          "parametres": { "nom": "trachee",
                          "segments": [[[0,0,3.4],[0,0,2.4],[0,0,1.9]],
                                       [[0,0,1.9],[-0.9,0,1.3]],
                                       [[0,0,1.9],[0.9,0,1.3]]],
                          "rayons": [0.20,0.18,0.16,0.13,0.13], "lisser": 1 } },
        { "verbe": "sculpter", "role": "sujet",
          "parametres": { "base": "goutte", "echelle": 1.35, "facettes": 2,
                          "position": [-1.25,0,0.1], "deformation": 0.08 } }
      ]
    }
  ]
}

════════ CE QUI FAIT UNE BONNE CAPSULE ════════

• Chaque scène montre QUELQUE CHOSE DU SUJET. Une forme qui conviendrait à
  n'importe quel cours est une forme ratée.
• Les scènes se suivent : on ne remontre pas la même chose deux fois.
• Budget de parole : 250 mots au total, répartis. La voix commande la durée.
• Si le sujet est abstrait et qu'aucune forme concrète ne s'impose, choisis une
  MÉTAPHORE VISUELLE et rends-la explicitement — ou écris le mot. Mieux vaut un
  mot juste qu'une forme décorative.`;
}
