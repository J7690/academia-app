# Le navigateur sans carte graphique contre Blender sur RTX 4090
**Mesure du 18/08/2026.** Banc reproductible :
`academia_bobodo_backend/studio_visuel/bancs/mesure_navigateur.js`

---

## Le résultat

| | **LWS, navigateur, sans GPU** | **RunPod, Blender, RTX 4090** |
|---|---|---|
| Moteur | ANGLE / SwiftShader (logiciel) | EEVEE Next |
| Secondes par image | **0,284** | ~1,3 |
| Images par seconde | **3,52** | 0,77 |
| Amorçage | **aucun** — machine allumée | 3 s / 10,4 min / **> 25 min** selon l'hôte |
| Coût horaire | **0** | 0,74 $ |

**Le rendu logiciel est 4,6 × plus rapide par image que Blender sur une carte
louée.** Sur la capsule « pluie » (1 193 images) : **5 min 40 sur LWS** contre
27 min de rendu plus la loterie d'amorçage.

Conditions : 1080×1920, 60 images, scène du compositeur — un solide de
révolution (`revolutionner`, profil du bécher) et une sphère facettée
(`sculpter`), filaire bleu sur fond noir, orbite de 26°.

---

## Pourquoi cette mesure-ci est valide, alors que celles du 11/08 étaient fausses

Trois bancs WebGL avaient été produits le 11/08 puis **retirés** :
- une boucle sur `requestAnimationFrame` plafonnait à ~5 images ;
- une boucle synchrone annonçait **9 434 images/s** sur des captures de 10 Ko —
  du vide compté très vite.

Trois garde-fous ont donc été posés ici, et ils sont dans le code du banc :

1. **On relit les pixels à chaque image** (`gl.readPixels`). Cela force le moteur
   à terminer son travail : sans cette lecture, on chronomètre une file
   d'attente, pas un rendu.
2. **On compte les pixels allumés.** Minimum mesuré : **660**. Une image noire
   invalide la mesure (`valide: false`).
3. **On écrit une capture témoin** — 106 197 octets, `docs/temoin_webgl_2026-08-18.png`.
   Elle a été regardée : le bécher et la sphère y sont.

Sortie brute :
```json
{ "moteur_graphique": "ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (Subzero)), SwiftShader driver)",
  "images": 60, "secondes_totales": 17.04, "secondes_par_image": 0.284,
  "images_par_seconde": 3.52, "pixels_allumes_minimum": 660,
  "temoin_octets": 106197, "valide": true, "erreurs_page": [] }
```

---

## Les quatre obstacles rencontrés, et leur cause

Ils valent d'être notés : quiconque refera ce banc les rencontrera.

1. **`Cannot find module 'playwright'`** — les modules sont dans `/opt/rendu`,
   le script ailleurs. → `NODE_PATH=/opt/rendu/node_modules`.
2. **`ERR_PACKAGE_PATH_NOT_EXPORTED`** — depuis la 0.15x, three.js n'expose plus
   `three/build/three.module.js` via `require.resolve`. → charger par chemin.
3. **CORS `origin 'null'`** — Chromium refuse **tout** import de module ES en
   `file://`. → servir la page par un serveur HTTP local. C'est obligatoire,
   pas contournable.
4. **`Could not create a WebGL context`** — `--use-angle=gl-egl` engage la carte
   NVIDIA (mesure du 11/08) et échoue là où il n'y en a pas. → sur LWS :
   `--use-gl=angle --use-angle=swiftshader --enable-unsafe-swiftshader`.

---

## Ce que cette mesure ne dit PAS

- **La scène d'essai porte deux objets, sans post-traitement.** Les vraies
  scènes en ont deux à quatre, plus le verre et le halo. Ce sera plus lent —
  de combien, non mesuré.
- **Le rendu logiciel occupe le processeur**, celui-là même qui fait tourner le
  préparateur et la chaîne du tableau. Découper en tranches parallèles comme le
  tableau ne donnera pas un gain proportionnel.
- **`readPixels` coûte cher** et n'existe que pour rendre la mesure honnête. En
  production on capture autrement : le chiffre réel devrait être meilleur.
- La qualité visuelle comparée (anticrénelage, halo, profondeur de champ) n'a
  **pas** été évaluée. Seule la vitesse l'a été.

---

## Décision

**On migre le rendu des capsules 3D vers le navigateur sur LWS.** L'écart de
4,6 × tient une large marge de sécurité, et surtout il fait disparaître
l'amorçage, la facturation à l'heure, et la moitié des défauts de ce chantier.

Ce qui **ne bouge pas** : les six verbes, l'invite, la validation, le
compositeur, le style, la porte d'acceptation, l'aiguillage `engine`.
Ce qui change : **le dos du compositeur seulement**.
