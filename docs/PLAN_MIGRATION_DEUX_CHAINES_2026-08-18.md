# Deux chaînes, deux contrats — audit et plan de migration
**18/08/2026.** Tout chiffre ici est mesuré. Ce qui n'est pas mesuré est nommé comme tel.

---

## 1. État mesuré ce soir

| Travail | Résultat |
|---|---|
| `50b5236d` « pluie » | **887 images rendues sur 886**, puis **REFUSÉ** : `image figee 3.16 s` |
| Machine `99y279x25nbzus` | muette 25 min, tuée `amorcage_jamais_abouti` — le conteneur n'a jamais démarré |
| Machine `yr8390em7tm5ls` | amorçage **parfait** (`moteur_installe > prete`), a rendu, coupée `sans_travail` |
| Dépense 24 h | **0,47 $** |

**Le refus est très probablement faux.** Seuil `GEL_MAX_S = 3.0 s`, gel mesuré **3,16 s**. Le
commentaire qui justifie ce seuil dit « la caméra bouge à chaque image » — vrai du temps des
archétypes, faux depuis l'orbite lente (14° sur toute une scène de comparaison). Deux images
consécutives d'un objet symétrique sont quasi identiques.

**Et on ne peut pas le vérifier : la vidéo refusée est jetée.** C'est le premier défaut à corriger.

---

## 2. Les deux chaînes — où elles se séparent, et où elles se mélangent

### Ce qui les sépare aujourd'hui (mesuré)

| | **Tableau** (`engine=vision2`) | **Animation 3D** (`engine=studio`) |
|---|---|---|
| Invite | `getSystemPrompt` | `getCapsulePrompt` |
| Validation | `validateStoryboard` | `validateCapsule` |
| Forme des scènes | `blocks`, `title` | `gestes`, `intention`, `sujet` |
| File | `app.whiteboard_renders` | `app.studio_jobs` |
| Rendu | **LWS**, Chromium + Playwright | **RunPod**, Blender EEVEE |
| Voix | optionnelle (`narration_mode`) | **obligatoire** — refus si absente |
| Contrôle qualité | **aucun** | `porte_acceptation` |

L'aiguillage tient à **un seul champ** : `engine`. Il est correct et vérifié.

### Où elles se mélangent — les cinq points à traiter

1. **`narration_mode` par défaut à « Aucune ».** Mesuré : 82 projets en `tts`, **12 muets**.
   Le tableau obéit et rend une vidéo muette ; la 3D l'ignore et exige une voix. Le même
   champ a deux sens. **C'est ce qui a produit la vidéo « topologie » sans voix du 18/08 :
   l'IA avait écrit la narration des 6 scènes sur 6, le mode disait de ne pas la prononcer.**

2. **Trois sélecteurs morts en 3D.** `theme`, `renderer`, `narration_mode` partent au serveur
   et ne sont **jamais relus** par la chaîne 3D. `getCapsulePrompt(_mode, _renderer)` ignore
   ses deux arguments.

3. **Le tableau n'a aucun contrôle qualité.** La 3D refuse une capsule figée ou muette ; le
   tableau a livré une vidéo sans piste audio marquée `done`. Le garde-fou existe
   (`montage.porte_acceptation`) et n'est pas branché côté tableau.

4. **Une règle du Studio a cassé tout le stockage de l'application** (30/07 → 18/08).
   Corrigé ce soir. Symptôme : `permission denied for table studio_jobs` en téléversant une
   image d'auto-école. Une règle sur `storage.objects` s'applique à **toute** l'application.

5. **L'exemple du champ Sujet est « Dérivée d'une fonction »** — le pire cas possible pour la
   3D : aucune forme à montrer.

---

## 3. Le contrat que l'interface doit rendre vrai

**Principe : au clic « Animation 3D », l'écran ne doit montrer que ce que la chaîne 3D lit
réellement.** Un champ affiché mais ignoré est un mensonge fait à l'étudiant.

| Champ | Tableau | Animation 3D |
|---|---|---|
| Sujet | affiché | affiché — exemple à changer : « La poussée d'Archimède » |
| Mode de saisie + Contenu | affiché | **affiché** — un texte collé donne à l'IA de la matière concrète |
| Thème | affiché | **masqué** (jamais lu) |
| Renderer | affiché | **masqué** (jamais lu) |
| Narration | affiché, **défaut à `tts`** | **masqué et forcé à `tts`** (la voix est obligatoire) |
| Style d'écriture | affiché | **masqué** (sans objet) |

**Ce qu'on n'ajoute pas** : aucun champ nouveau. Trois des sept déjà posés sont jetés ; en
ajouter un huitième avant d'utiliser les sept premiers ne ferait qu'allonger le formulaire.
La piste « lire le niveau dans le profil » est morte, mesurée : `bac_series` est rempli pour
**8 étudiants sur 242** (3 %).

---

## 4. Le plan, dans l'ordre — du moins cher au plus lourd

### Étape 0 — arrêter de perdre les preuves *(minutes)*
Quand la porte refuse, **déposer quand même la vidéo** dans Storage sous `refuse/`, et écrire
la mesure dans `erreur`. Sans ça, un refus faux et un refus juste se ressemblent.

### Étape 1 — les défauts d'un seul mot *(minutes, aucun risque)*
- `narration_mode` par défaut → `tts` ; masqué et forcé en 3D.
- Masquer thème, renderer, style d'écriture quand `engine=studio`.
- Changer l'exemple du champ Sujet.
- `GEL_MAX_S` : relever à 5 s **et** mesurer le gel réel sur une capsule acceptée, pour
  choisir le seuil sur une mesure au lieu d'une intuition.

### Étape 2 — brancher la porte d'acceptation sur le tableau *(heures)*
Elle existe et fonctionne. Une vidéo muette ou figée ne doit jamais être livrée, quel que
soit le moteur.

### Étape 3 — la reprise automatique *(heures)*
Un travail `queued` sans machine depuis 6 minutes doit en redemander une. La veille sait déjà
le détecter (`TRAVAIL EN FILE SANS MACHINE`) ; il suffit de brancher l'alerte sur l'action.
Mesuré ce soir : « pluie » a attendu **81 minutes** sans que personne ne réagisse.

### Étape 4 — LA MESURE QUI DÉCIDE DE TOUT *(une demi-journée, coût nul)*

**Question : Three.js dans Chromium sur LWS, sans carte graphique, est-il assez rapide ?**

Ce qui rend la question sérieuse — mesuré ce soir sur le tableau, sur LWS, sans GPU :
```
[capture] 5 tranches en parallele (total 89.3 s)
[capture] apercu pret en 44.0 s
```
Aperçu en 44 secondes, vidéo de 89 s en trois minutes, machine toujours allumée.

À comparer avec la 3D : amorçage **3 s / 10,4 min / > 25 min** selon l'hôte, 27 min de rendu,
0,30 $ la capsule, et une machine sur deux qui meurt avant de démarrer.

**Protocole** : porter **une seule** scène composée en Three.js, la capturer avec la chaîne du
tableau, mesurer images/seconde et durée totale. Rien d'autre.

- **Si c'est assez rapide** → on abandonne RunPod et Blender. Disparaissent : l'image de
  4,47 Go, la loterie d'amorçage, la facturation à l'heure, la moitié des défauts de ce
  chantier.
- **Si ce n'est pas assez rapide** → on garde Blender **en sachant pourquoi**, et on attaque
  la taille de l'image : 4,47 Go pour un moteur de 82 Ko, alors que le moteur se tire
  désormais depuis Storage et n'a plus besoin d'être dedans.

**Mes mesures WebGL du 11/08 étaient fausses et je les ai retirées.** C'est précisément
pourquoi cette étape doit être refaite proprement avant toute décision.

### Étape 5 — la migration, si et seulement si l'étape 4 le permet
Ce qui **ne bouge pas** : les six verbes, l'invite, la validation, le compositeur, le style,
la porte d'acceptation, l'aiguillage `engine`. C'est la partie difficile, et elle est bonne —
mesuré le 18/08 sur « le pétrole » : cinq scènes distinctes, un derrick, un puits sous terre,
un oléoduc, une coque de navire en fuseau, là où quatre jours plus tôt le modèle écrivait
« un galet » pour un bateau.

Ce qui change : **le dos du compositeur seulement** — la géométrie Blender devient de la
géométrie Three.js.

---

## 5. Ce que je ne sais pas

- Si le gel de 3,16 s était réel ou un artefact du seuil. **La vidéo a été jetée.**
- La vitesse de WebGL logiciel sur LWS. **Non mesurée** (étape 4).
- Pourquoi certains hôtes RunPod dépassent 25 minutes de tirage. Corrélation avec la taille
  de l'image **supposée**, non prouvée.
- Si `napper` dans quatre scènes sur cinq (« le pétrole ») est un tic du modèle ou un hasard.
  **Un seul sujet observé.**
