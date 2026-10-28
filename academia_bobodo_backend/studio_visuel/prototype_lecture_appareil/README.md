# Prototype — la capsule jouée par l'appareil (28/10/2026)

Preuve du §7 de `docs/STUDIO_CHANGEMENT_DE_PARADIGME_2026-10-28.md`. **Aucun
lien avec la production** : rien ici n'est déployé ni appelé par l'app.

| Fichier | Contenu |
|---|---|
| `index.html` | la page : décors procéduraux (Three.js 0.178), voix, sous-titres dans la toile, paliers, banc, export MP4 (Mediabunny 1.61.3) |
| `corps.json` | maillage de base **MakeHuman**, groupe `body`, **CC0 1.0** (en-tête du fichier source), simplifié à 2 975 triangles par regroupement de sommets (cellule 0,35) |
| `narration.mp3` | la vraie narration de la capsule `168ccb14` « le cerveau » (`studio-visuel/capsules/capsule/1788566123/narration.wav`, lue le 28/10), réencodée en MP3 64 kbit/s mono |

Le choix du décor de chaque scène (corps ou gouttes, foyer à la tête ou au
thorax) est fait **à la main** dans `CAPSULE` : c'est l'information que l'IA
devrait fournir dans une vraie chaîne.

## Ouvrir

- **Publié** : https://claude.ai/artifact/7ok358bQ6YfY3sh3pjoL4z (privé : il faut être connecté à claude.ai dans Chrome).
- **En local** : la page n'a pas d'en-tête HTML (l'Artifact l'ajoute). Il faut la servir avec l'enveloppe, par exemple avec le petit serveur de la séance, ou en la publiant.

## Mesures sur le poste de développement (28/10, Intel UHD Graphics, ANGLE D3D11, WebGL2)

| | mesure |
|---|---|
| première image | 1,0 à 1,65 s après l'ouverture (6,1 s une fois) |
| données chargées | 0,39 à 0,75 Mo transférés |
| banc (capacité brute) | **complet 58,5 i/s · léger 61,8 i/s** |
| lecture, panneau masqué | complet 26,8 i/s → bascule automatique à t = 5,2 s ; léger 30,6 i/s (plafond à 30 : bridage du panneau masqué, non significatif) |
| export 10 s | **38,1 s** (0,26× le temps réel), 2,52 Mo, H.264 + AAC, 1280×720 ; relu : 10,005 s, son décodé |
| images | les 5 scènes vérifiées une par une à l'image |

**Défaut trouvé et corrigé pendant l'essai** : au changement de palier, la
toile des sous-titres changeait de taille et l'ancienne phrase restait visible
sous la nouvelle. Sa taille est désormais fixe ; vérifié à l'image en palier léger.

## Mesures sur le TECNO de Jocelyn (28/10, 10:09 UTC) — LA mesure qui décide

Relevé renvoyé par la page elle-même au poste (`adb reverse tcp:8765`, page
ouverte dans Chrome avec `#auto`), sans recopie à la main.

| | mesure | seuil | verdict |
|---|---|---|---|
| appareil | **Android 10 · 8 cœurs · 4 Go · Mali-G52 MC2** (OpenGL ES 3.2, WebGL2) | — | bas de gamme : le cas redouté |
| banc, palier complet 1280×720 | 14,4 i/s | ≥ 24 | **non** |
| banc, palier léger 854×480 | **48,9 i/s** | ≥ 24 | **oui, ×2** |
| lecture réelle, palier léger | **58,6 i/s** en moyenne, **59,5 i/s au pire 5 %**, 2 428 images | ≥ 24 | **oui** (calé sur les 60 Hz de l'écran) |
| lecture réelle, palier complet | 16,7 i/s ; **bascule automatique vers léger à t = 3,4 s** | — | la bascule a fonctionné seule |
| export 10 s | **21,2 s** (0,47× le temps réel), 2,08 Mo, H.264 + AAC, 1280×720 | < 30 s | **oui** |
| première image | 6,61 s après l'ouverture | < 3 s une fois les données reçues | non tranché : le chiffre inclut le téléchargement de three.js depuis le CDN |
| données chargées | 0,98 Mo | < 3 Mo | **oui** |

**Non vérifié** : la page dans le cadre de l'Artifact (le navigateur de la
séance n'était pas connecté à claude.ai) ; la ressemblance jugée par Jocelyn ;
la consommation de batterie et la chauffe sur une lecture longue.
