# Studio 3D — comment la lecture sur l'appareil s'articule, pour n'importe quel sujet

**Date : 28/10/2026.** Conception seule : rien n'est implémenté ni déployé.
Suite de `STUDIO_CHANGEMENT_DE_PARADIGME_2026-10-28.md` et du prototype
`academia_bobodo_backend/studio_visuel/prototype_lecture_appareil/`.

**Ce qui est acquis** (mesuré le 28/10 sur le TECNO de Jocelyn : Android 10,
4 Go, Mali-G52 MC2) :
- **la lecture tient** : 58,6 i/s en palier léger, bascule automatique à 3,4 s ;
- **l'export tient** : 10 s de vidéo en 21,2 s ;
- **la qualité est validée par Jocelyn** : « l'image ressemble à ce que je
  t'ai fourni ».

**La question de Jocelyn** : pour n'importe quel sujet, peut-on obtenir une
vidéo parlée avec un temps de production très court, et comment cela
s'articule-t-il ?

---

## 1. La réponse en une phrase

**Oui. L'étudiant peut voir et entendre la première scène environ 10 à 20 s
après avoir tapé son sujet (estimation), contre 2 à 5 min aujourd'hui
(mesuré).** Il faut pour cela trois changements :
1. ne plus fabriquer de vidéo, mais **jouer** la capsule ;
2. fabriquer la voix **scène par scène, en parallèle**, et commencer à jouer
   dès que la première est prête ;
3. donner à l'IA un **vocabulaire de décors** qui couvre tous les sujets,
   au lieu de deux décors choisis à la main.

---

## 2. Où passe le temps — aujourd'hui, puis demain

| Étape | Aujourd'hui | Demain | Source |
|---|---|---|---|
| l'IA écrit la capsule | « quelques secondes » (Gemini 2.5 Flash, ≈ 2 600 jetons en sortie) | inchangé, mais les scènes arrivent **une à une** si on lit la réponse au fil de l'eau | `08_LATENCE_2026-07-28.md` ; `whiteboard_ai_generations` |
| la voix | **les scènes l'une après l'autre**, sur LWS, avec calage des durées et nappe sonore : ≈ 35 s au total | **toutes les scènes en parallèle**, depuis une Edge Function : le temps de la plus longue, quelques secondes (*estimé, à mesurer*) | `narration.py:120-176`, ETAT §1 bis |
| la machine GPU | amorçage ≈ 20 s à plus de 25 min, puis rendu 85–184 s | **aucune** | `app.studio_jobs`, mesuré |
| encodage + dépôt + téléchargement | 8–12 Mo | **≈ 0,4 Mo** de voix ; le moteur est déjà dans l'app | prototype |
| première image sur le téléphone | — | **6,6 s mesurées**, mais surtout le téléchargement de three.js : intégré à l'app, **≈ 1 s** (*estimé*) | prototype, TECNO |
| **commande → première image parlée** | **2 min 12 à 4 min 54** (mesuré) | **≈ 10 à 20 s** (*estimé*) | |

**L'astuce qui fait gagner le plus.** On ne joue pas quand **tout** est
prêt, mais dès que la **scène 1** l'est. Les scènes 2 à 5 se fabriquent
pendant que l'étudiant regarde la 1, qui dure de 7 à 10 s. C'est le principe
d'une vidéo en streaming. Le dépôt l'avait déjà cherché pour le tableau
(l'« aperçu instantané » de juillet) ; ici, il tombe naturellement.

**La voix commande toujours l'image**, mais c'est désormais le **lecteur**
qui mesure la durée de chaque scène, sur l'audio qu'il vient de décoder (il
le fait déjà dans le prototype). Le calage côté serveur (`narration.caler`)
n'est plus nécessaire dans le chemin de l'étudiant.

---

## 3. L'articulation — qui fait quoi

```
ÉTUDIANT (app Flutter, ou app web)
 │  tape « la photosynthèse »
 ▼
EDGE FUNCTION whiteboard-generate-storyboard (existe ; moteur « studio »)
 │  LLM → capsule v2 : par scène { décor, foyer, gestes, narration }
 │  validate_capsule (existe) : on nettoie, on ne rejette pas
 │  → enregistre la capsule, débite les crédits
 ▼
EDGE FUNCTION « voix » (NOUVELLE, ~80 lignes)
 │  une requête TTS PAR SCÈNE, toutes lancées ensemble (Voxtral, déjà payé)
 │  → Storage : capsules/<id>/s1.mp3 … s5.mp3 ; marque chaque scène « prête »
 ▼
LECTEUR (dans l'app : une page locale dans une WebView, three.js embarqué)
 │  reçoit la capsule (≈ 10 Ko) puis s1.mp3 → JOUE ;
 │  s2…s5 arrivent pendant la lecture
 │  palier choisi seul (léger sur Mali-G52) ; remonte ses mesures et ses erreurs
 ▼
« PARTAGER » (seulement si l'étudiant le demande)
    sur le téléphone : export MP4 (90 s ≈ 3 min mesurées au prorata, en tâche de fond)
    ou, si le téléphone ne sait pas : rendu serveur (chaîne actuelle, gardée en repli)
```

| Machine | Rôle demain | Changement |
|---|---|---|
| **Supabase** | écrire la capsule, faire la voix, stocker, compter les crédits | **+1 Edge Function** (voix par scène) ; la fonction storyboard apprend les décors |
| **Téléphone** | **dessiner et jouer**, exporter à la demande | nouveau : le lecteur |
| **LWS** | plus dans le chemin de l'étudiant | il ne sert plus qu'au repli d'export et aux témoins de contrôle (dessin seulement, **aucune IA**) |
| **RunPod** | repli d'export seulement | il ne tourne plus pour chaque capsule |

**Les règles du dépôt tiennent :**
- aucune IA sur LWS ;
- 100 % CSS pour le tableau, que ce chantier ne touche pas ;
- dégradation gracieuse : sans WebGL2, ou trop lent même en palier léger,
  l'étudiant reçoit le MP4 de la chaîne actuelle.

---

## 4. « N'importe quel sujet » — le vrai travail est là

Le prototype a joué **deux décors choisis à la main**. Pour qu'un sujet
quelconque trouve son image, l'IA doit **choisir** dans un vocabulaire de
décors, chacun réglable. C'est la conclusion du 11/08, que le prototype
confirme : la pertinence vient du **vocabulaire**, pas des nouvelles
tentatives (3DCodeBench).

| Décor | Ce qu'il montre | Exemples de sujets | État |
|---|---|---|---|
| **corps** + foyer (tête, thorax, ventre, membre…) | le corps et l'endroit où « ça se passe » | cerveau, digestion, chaleur, sport, maladie | **fait** (prototype) |
| **gouttes / cellules** sur grille | des unités nombreuses, une population | neurones, cellules, molécules, électeurs, marché | **fait** (prototype) |
| **objet convoqué** (banque) | la chose elle-même | volcan, cœur, pyramide, tracteur | **fait côté pod** (`convoquer`, 69 termes) ; à porter dans le lecteur ; **attribution CC-BY à afficher** |
| **forme dessinée** (5 verbes) | ce qu'aucune banque n'a | flèche, profil, terrain, fuseau | **fait côté pod** (`academia3d_web.js`), à porter |
| **flux** de particules entre deux points | une circulation | sang, eau, argent, énergie, information | presque fait : les particules du foyer |
| **réseau** (nœuds reliés) | des relations | sociologie, internet, chaîne alimentaire | à faire, petit |
| **comparaison** (deux groupes face à face) | deux états, deux choix | avant/après, homme/animal | à faire, petit |
| **texte 3D** et **chiffres** | un mot-clé, une date, une formule | dates, définitions, maths | **manque** : le verbe `ecrire` est inconnu du moteur navigateur (ETAT §4.2 ter) |

Avec ces huit décors et un foyer réglable, les sujets **concrets** (SVT,
physique, géographie, technologie) sont bien couverts. Les sujets
**abstraits** (sociologie, philosophie) passent par la métaphore : réseau,
comparaison, texte. Le 11/08, nous avions noté que **rien ne prouve qu'un
modèle choisisse la bonne métaphore**. Cela se mesure sur les **≈ 214 sujets
déjà tapés** par les étudiants (`whiteboard_projects`), sans rien rendre :
l'IA choisit des décors, on lit ses choix.

---

## 5. Les coûts, par capsule de 90 s

| Poste | Aujourd'hui | Demain |
|---|---|---|
| IA (capsule) | ≈ 0,007 $ (*le journal en base indique 0,0012 $, avec un tarif codé en dur*) | identique |
| voix (Voxtral, 0,016 $ / 1 000 caractères) | ≈ 0,024 $ | identique, ou ≈ 0,006 $ avec une voix moins chère |
| GPU | ≈ 0,04 $ | **0 $** (sauf repli) |
| **total** | **≈ 0,07 $** | **≈ 0,03 $**, ou ≈ 0,013 $ avec une voix moins chère |
| ce que paie l'étudiant | 15 crédits ≈ 10 à 15 FCFA ≈ 0,02 $ | à décider |

Une capsule déjà fabriquée **se rejoue gratuitement**, puisque
`studio_creer_travail_etudiant` rend déjà l'existant. Le coût porte
uniquement sur les sujets **nouveaux**.

---

## 6. Ce qui reste fragile, nommé

1. **Le choix du décor pour un sujet abstrait** : non mesuré (§4).
2. **L'export de 90 s sur le téléphone** : environ 3 min au rythme mesuré
   (0,47× le temps réel). Il faut qu'il tourne en tâche de fond, ou que le
   serveur prenne le relais.
3. **La batterie et la chauffe** pendant une lecture longue : non mesurées.
4. **La porte d'acceptation change de nature.** Le serveur valide la
   capsule (JSON, voix présente et non muette) et le lecteur **remonte**
   chaque échec WebGL. Sans cette remontée, on recrée le défaut du 05/08 :
   un écran noir présenté comme prêt.
5. **La latence réelle de la voix par scène** (Voxtral) : non mesurée.
   C'est la première mesure du lot 2.
6. **Les téléphones plus faibles que le TECNO** (Android 9 et moins, puces
   PowerVR) : non mesurés. Ils recevront le MP4 de repli.

---

## 7. L'ordre de mise en place

Les durées sont des **estimations** d'effort d'agent. Chaque lot se termine
sur une mesure.

| Lot | Contenu | Durée | Preuve de fin |
|---|---|---|---|
| **1. Le lecteur** | fusionner les verbes d'`academia3d_web.js` et le style du prototype en **un seul lecteur**, avec three.js **embarqué** (plus de CDN) ; format « capsule v2 » écrit | 2–3 j | les 23 capsules livrées en base rejouées dans le lecteur |
| **2. La voix par scène** | Edge Function `voix` en parallèle → Storage ; le lecteur démarre sur la scène 1 | 1–2 j | **temps commande → première image parlée**, chronométré sur le TECNO |
| **3. Les décors** | `prompt_capsule.ts` et `validate_capsule.ts` v2 (décor, foyer) ; tests Deno | 2 j | les décors choisis sur 50 sujets réels de la base, relus |
| **4. Dans l'app** | écran de lecture (WebView) à la place de l'aperçu vidéo pour la 3D ; repli MP4 si WebGL2 manque ; app web | 2–3 j | parcours complet sur le TECNO, puis rouvert depuis « Mes cours » |
| **5. Partager** | export en tâche de fond, repli serveur, publication dans le Challenge | 2 j | une capsule partagée sur WhatsApp, puis lue |
| **6. Couverture** | décors réseau / comparaison / texte ; banque élargie (CC0, TRELLIS hors ligne) ; **attribution** | 3–5 j | taux de sujets « bien montrés » sur 50 sujets |

**Total : environ 2 à 3 semaines** pour une première version complète. Au
bout des lots 1, 2 et 4 (environ une semaine), un étudiant peut déjà taper
un sujet et voir sa capsule jouée en une vingtaine de secondes, avec les
décors du prototype.

**Ce que ces lots touchent dans l'app** : `smart_whiteboard_input_screen.dart`
et `smart_whiteboard_preview_screen.dart`, que l'autre séance modifie
actuellement. **Le lot 4 attend donc que ce travail soit commité.**

---

## 8. Corollaire, hors périmètre

Le **tableau manuscrit** est déjà une page HTML/CSS que l'on filme sur LWS.
Il pourrait être **joué** de la même façon sur le téléphone. Ses contraintes
(100 % CSS, animations déterministes) en font même le candidat le plus
simple. À ne pas mélanger avec ce chantier.
