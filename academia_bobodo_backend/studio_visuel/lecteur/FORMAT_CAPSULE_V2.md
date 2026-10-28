# Format « capsule v2 » — ce que le lecteur sait jouer

**28/10/2026.** Le lecteur (`lecteur.js`) accepte trois formats, et le dit
dans son journal quand il dégrade :

| Version | Reconnue à | Rendu |
|---|---|---|
| **v0** (avant le 12/08) | scènes à `archetype`, sans `gestes` | **repli** : grille et texte du sujet, signalé « archétype v0 non porté » |
| **v1** (12/08 → 05/09) | scènes à `gestes` | les gestes, avec le style de la référence |
| **v2** | `decor`, `foyer`, `voix` par scène, ou `objets` résolus | le décor choisi, le foyer, la voix qui fixe les durées |

Une capsule v1 est donc une capsule v2 sans décor. **Rien de ce qui est en
base n'est à migrer.**

## La capsule

```json
{
  "format": 2,
  "titre": "Le cerveau : notre centre de commande",
  "voix": "narration.mp3",
  "objets": { "volcan": { "url": "https://…/a091df40.glb", "attribution": "Modèle 3D : … (CC-BY)" } },
  "scenes": [ … ]
}
```

| Champ | Obligatoire | Rôle |
|---|---|---|
| `titre` | non | affiché au-dessus du lecteur |
| `voix` | non | narration d'un seul tenant (chemin relatif à la capsule). Ignoré si les scènes ont chacune leur `voix` |
| `objets` | non | objets de `convoquer` **déjà résolus par le serveur** (URL + attribution). Sans lui, le lecteur résout par `contours/index_objets.json` |

## Une scène

| Champ | Valeurs | Défaut | Rôle |
|---|---|---|---|
| `id` | texte | `s1`, `s2`… | |
| `intention` | `objet`, `processus`, `comparaison`, `structure`, `echelle`, `flux` | `objet` | règle le cadrage (porté de `academia3d_web.js`) |
| `decor` | `gestes`, `corps`, `gouttes`, `repli` | `gestes` s'il y a des gestes, sinon `repli` | le décor de la scène |
| `foyer` | `tete`, `thorax`, `ventre`, `bassin`, `jambes`, `bras`, `[x,y,z]` (décor corps) ; `"sujet"` (décor gestes) | thorax pour le corps, aucun sinon | où loger la masse rouge. **Sur les gestes, seulement si on le demande** : l'énergie a besoin d'un référent (compétence `studio-visuel-3d`) |
| `flux` | booléen | `false` | les braises s'échappent du foyer |
| `plan` | `approche`, `profil`, `reference` (corps) ; `rase`, `arc` (gouttes) | tiré de l'intention | le mouvement de caméra |
| `gestes` | liste `{ verbe, role, parametres }` | `[]` | les 7 verbes : `convoquer`, `revolutionner`, `sculpter`, `extruder`, `silhouetter`, `napper`, **`ecrire`** |
| `narration` | texte | — | les sous-titres, découpés par phrase au prorata de leur longueur |
| `duree_s` | secondes | 6 | **remplacée par la durée de la voix** quand la scène a la sienne |
| `voix` | chemin audio | — | voix de la scène. **La voix commande l'image** : le lecteur recale les durées sur l'audio décodé |

Coordonnées des gestes : celles de l'invite, **Z en haut, Y en profondeur**
(négatif = loin). La conversion vers three.js passe par un seul point, `v()`.

## Ce que le lecteur ne décide pas, et que l'IA ne décide pas non plus

La palette (bleu = structure, rouge = énergie), le halo, la brume, le verre,
l'épaisseur des arêtes, la police des sous-titres. C'est ce qui fait qu'une
capsule ressemble à toutes les autres tout en parlant de son sujet.

## Ce qui reste à décider (lot 3)

- `prompt_capsule.ts` et `validate_capsule.ts` n'émettent ni ne valident
  encore `decor`, `foyer`, `plan` et `flux`. L'exemple
  `exemple/cerveau_v2.json` les porte, choisis à la main.
- L'attribution des objets CC-BY ne donne que l'identifiant Sketchfab :
  l'index ne contient pas le nom des auteurs.
