# Studio challenge — reproduire la vidéo de référence sur n'importe quel sujet

**Date : 28/10/2026.** Étude en lecture seule : rien n'a été modifié, déployé
ni commité. Fait suite à `PASSATION_STUDIO_3D_2026-08-14.md`,
`STUDIO_3D_CONCEPTION_SCENE_PAR_SUJET_2026-08-11.md`,
`STUDIO_INVENTAIRE_MOYENS_2026-08-11.md` et à `ETAT.md` §1 bis (chantier
`convoquer`, 05/09).

Compétences chargées avant d'écrire : `continuite-du-chantier`,
`studio-visuel-3d`, `etat-des-moyens`, `veille-externe`, `ou-tourne-le-code`.

> **La conclusion, d'abord.** Le style de la référence était écrit dans le
> moteur Blender. Le 18/08, le rendu est passé au moteur navigateur (Three.js),
> dix fois plus rapide, et **le style n'a pas suivi** : la production n'a
> aujourd'hui ni halo, ni brume, ni particules, ni masse rouge, ni flou de
> profondeur. Le rapprochement le moins cher avec la référence consiste donc à
> porter ce style dans le moteur qui tourne. Il ne demande pas de nouvelle
> machine. La voie « modèle vidéo génératif », qui a probablement servi à
> fabriquer la référence elle-même, coûterait **200 à 1 400 fois** le prix
> qu'un étudiant paie aujourd'hui pour une capsule. C'est à Jocelyn de
> trancher, chiffres en main (§6).

Chaque affirmation porte l'une de ces trois étiquettes :
**mesuré le 28/10** (avec la requête), **lu dans le dépôt** (fichier:ligne),
ou **annoncé / non vérifié**.

---

## 1. La référence, décrite

Deux captures envoyées par Jocelyn (TikTok, filigrane `@mathoholic.ch`) :

| | Image 1 | Image 2 |
|---|---|---|
| sujet montré | corps humain allongé, **filaire bleu holographique**, foyer **rouge incandescent** au thorax, particules rouges qui s'échappent | **gouttes / capsules de verre** maillées, posées sur une **grille 3D**, avec des lueurs rouges qui affleurent sous la grille |
| fond | bleu nuit, **brume en bandes ondulantes** | brume bleue au ciel, horizon |
| sous-titre | « Il faut qu'elle sorte, en continu, sinon elle s'accumule. » | « Et là, une confusion que presque tout le monde a. » |
| texte | blanc, gras, sans fond, centré en bas **dans** l'image 16:9 | idem |
| cadrage | **16:9 dans un écran 9:16**, bandes noires haut et bas (≈ 31 % de la hauteur pour l'image) | idem |

Ce qui se lit aussi : une **narration d'accroche** (« Et là, une confusion
que presque tout le monde a. »), écrite comme on raconte, pas comme on
récite un manuel. Le thème de l'image 1, la chaleur du corps qu'il faut
évacuer, est celui de `capsules/chaleur_corps.json` : la référence est donc
la même que celle du 30/07 et du 11/08. **Elle n'est pas nouvelle pour le
dépôt** : sa grammaire en dix éléments est déjà tenue dans la compétence
`studio-visuel-3d`.

**Comment la référence a-t-elle été fabriquée ? Non vérifié.** Deux recherches
sur « mathoholic » n'ont rien rendu. La brume fluide, la dispersion organique
des particules et la réfraction des capsules de verre sont la signature
habituelle des **modèles de diffusion vidéo** (Kling, Veo, Seedance…), plus
que d'un moteur 3D. C'est une **hypothèse**, pas un constat. Elle compte pour
le §6.

---

## 2. Ce qui existe : deux produits, et c'est le second qui est concerné

| | Tableau manuscrit | Animation 3D (« capsule ») |
|---|---|---|
| moteur | `whiteboard_vision/`, HTML + CSS | `studio_visuel/`, **Three.js + Chromium** depuis le 18/08 |
| où | LWS | pod RunPod (RTX 4090) |
| proche de la référence ? | non : écriture manuscrite | **oui, c'est le bon socle** |

### 2.1 La chaîne 3D telle qu'elle tourne (lu dans le dépôt + mesuré en base)

```
App Flutter — choix « Animation 3D » (smart_whiteboard_input_screen.dart:363)
 └─> Edge Function whiteboard-generate-storyboard   (engine=studio)
      LLM via OpenRouter (llm.ts, modèle principal + repli, temp. 0,35)
      prompt_capsule.ts : 4–6 scènes, intention + gestes (7 verbes, 69 termes)
      validate_capsule.ts : on nettoie, on ne rejette pas — 15 crédits débités
 └─> app.studio_jobs (a_preparer) ── déclencheur → runpod-control (créer la machine)
 └─> LWS studio-preparateur : traduit, SYNTHÉTISE LA VOIX (whiteboard-tts →
      Voxtral mini TTS, voix fr_marie_neutral, tempo 0,88), cale les durées
 └─> pod : image academia0/academia-studio:1.3.0, moteur 1.5.2 tiré du bucket
      studio-moteur ; rendre_capsule_web.js → academia3d_web.js (Three.js,
      Chromium --use-angle=gl-egl) → JPEG → montage.py (ASS incrustés, voix,
      x264 crf 24 / 2,5 Mbit/s) → porte d'acceptation → Storage
 └─> preview_ready → l'app suit par studio_etat_travail puis URL signée
```

Mesuré le 28/10 dans `app.studio_config` : `version_moteur = 1.5.2`,
`image_pod = academia0/academia-studio:1.3.0`,
`env_pod = {"MOTEUR_RENDU":"web","FLAGS_CHROMIUM":"--use-angle=gl-egl"}`.

### 2.2 Les intervenants

| Qui / quoi | Rôle | État au 28/10 |
|---|---|---|
| **Jocelyn** | seul décideur et seul valideur à l'image ; autorise commit, push, déploiement | — |
| Sessions d'agent (Claude) | conception, code, mesures ; ni écriture en production, ni déploiement sans accord | — |
| **Supabase** `thevdfcwlcqzdoybfvgs` | Edge Functions `whiteboard-generate-storyboard`, `whiteboard-tts`, `runpod-control`, `runpod-watchdog`, `studio-orchestrateur`, `studio-jeton-huggingface` ; RPC `studio_*` ; tables `studio_jobs`, `gpu_pods`, `studio_config` ; buckets `studio-visuel` (74 objets), `studio-moteur` (1.4.9 → 1.5.2) | mesuré |
| **OpenRouter** | le LLM du storyboard (modèle dans un secret, non lisible ici) **et** la voix (Voxtral) | lu dans le dépôt |
| **LWS** `31.207.38.60` | `studio-preparateur` (voix, durées), `whiteboard-worker`, `video-worker` ; Docker pour construire l'image du pod | **non vérifié : SSH expire** (4 essais sur la séance, ping 50 %) |
| **RunPod** | machine louée à la seconde, RTX 4090 par défaut (`runpod-control/index.ts:46`) ; 64 machines au total, **toutes `terminated`** | mesuré |
| **Docker Hub** `academia0` | héberge l'image du pod (4,47 Go) | lu dans le dépôt |
| **HuggingFace / Objaverse / Cap3D** | source des 764 modèles 3D de `convoquer` (licences `by`, `by-sa`, `cc0`) | lu dans le dépôt |
| cron `runpod-watchdog`, `studio-reprise-orphelins` | filets de sécurité, toutes les 2 min | **actifs** (mesuré) |
| cron `studio-orchestrateur` | ancienne chaîne concurrente | **désactivé** (mesuré) |

---

## 3. Ce qui fonctionne réellement — mesuré le 28/10

Requête en lecture seule sur `app.studio_jobs`, via le connecteur claude.ai.
Le connecteur du dépôt `supabase-lecture` n'a pas démarré (délai dépassé).

**41 travaux 3D** depuis le 31/07 : 23 `preview_ready`, 14 `failed`, 4 `archived`.
**Le dernier date du 05/09. Aucun depuis, soit sept semaines et demie.**

Depuis le passage au moteur navigateur (19/08) : **13 livrés sur 18 (72 %)**.

| | mesure |
|---|---|
| commande → vidéo | **2,2 à 4,9 min**, médiane ≈ 3,3 min |
| rendu seul sur le pod | **85 à 184 s** pour 619 à 1 419 images (≈ 0,13 s/image) |
| vidéo | 39–47 s, 1080×1920, 8–12 Mo (ETAT §1 bis) |
| coût GPU | ≈ **0,04 $** la capsule (ETAT §1 bis, non recalculé : `cout_gpu_usd` est vide sur toutes les lignes) |
| les 5 échecs | 3 au dépôt (fichier trop lourd, corrigé en 1.4.4), 2 « image figée » sur le volcan (corrigés en 1.5.x) |

**Qui s'en sert : personne en dehors de l'équipe.** Les 41 travaux viennent de
**3 comptes**, dont un compte d'essai en `.test`. Aucun étudiant réel n'a
commandé de capsule 3D.

Le tableau manuscrit, à titre de comparaison : 99 rendus `done`, 16 `failed`,
**dernier le 09/09**, aucun depuis.

**Ce qu'un étudiant paie** (mesuré dans `app.credit_packs`) : une capsule
coûte **15 crédits** (`index.ts:137`). Selon le pack, le crédit vaut de
0,67 à 1 FCFA. **Une capsule rapporte donc 10 à 15 FCFA, soit environ
0,02 $** (au taux supposé de 600 FCFA pour 1 $, non vérifié). **Le seul
coût GPU de 0,04 $ dépasse déjà ce prix.**

---

## 4. Ce qui coince, avec les causes connues

### 4.1 La trouvaille du jour : le style de la référence n'est pas dans le moteur de production

Vérifié par lecture de `web/academia3d_web.js` et `web/rendre_capsule_web.js` :
aucune occurrence de bloom, de brouillard, de particules, de flou de
profondeur ni de matière de feu. Le seul « halo » est un mot de commentaire
(`academia3d_web.js:37`). Les matières se réduisent à `MeshBasicMaterial` en
fil de fer et à du verre additif, sur fond noir et sans lumière.

| # | Élément de la référence | Blender (`style_reference.py`) | **Production (navigateur)** |
|---|---|---|---|
| 1 | filaire bleu émissif | `filaire()` | ✅ `matiereFilaire` |
| 2 | sommets lumineux | absent | ❌ |
| 3 | surface translucide | `matiere_hologramme()` (Fresnel) | 🟡 verre plat, **sans** Fresnel |
| 4 | masse rouge incandescente | `matiere_feu()` | ❌ |
| 5 | brume bleue en bandes | `matiere_brume()` | ❌ |
| 6 | halo / bloom | `compositing()` | ❌ |
| 7 | profondeur de champ | f/2.8 | ❌ |
| 8 | particules chaudes | partiel | ❌ |
| 9 | grille + lueur affleurante | `sol_grille()` | 🟡 `napper` : grille sans lueur |
| 10 | sous-titres blancs gras | ASS | ✅ (DejaVu Sans, contour noir) |

Le **cadre cinéma** (`cadre_cinema`, `style_reference.py:548`) n'existe que
côté Blender, et à 62 % de la hauteur, pas en 16:9. Le chemin navigateur rend
en 1080×1920 plein cadre. Le **son**, en revanche, est bien branché : la nappe
et les accents de `sound_design.py` sont mélangés sur LWS dans
`narration.caler` (`narration.py:293-310`), avant la location de la machine.
Je l'avais d'abord noté absent en ne cherchant que dans `montage.py`.
L'écoute, elle, n'a pas été refaite aujourd'hui.

**Ce n'est pas un défaut caché, c'est un renoncement qu'on n'a pas écrit.**
Le portage du 18/08 a été annoncé comme portant « les six verbes »
(`academia3d_web.js:4`) et il les porte. Mais la grammaire visuelle n'était pas
dans les verbes : elle était dans `style_reference.py`, que le portage n'a pas
repris. On a gagné un facteur 10 sur le temps de rendu et perdu au passage
l'atmosphère de la référence, sans que personne ne l'écrive.

### 4.2 Les défauts déjà inscrits dans ETAT.md, toujours ouverts

| Défaut | Où |
|---|---|
| un objet convoqué dense rend un **aplat blanc** (le volcan) | ETAT §4.2 bis |
| le verbe `ecrire` est inconnu du moteur navigateur : les textes 3D disparaissent | ETAT §4.2 ter |
| `silhouetter`, `extruder` et `ecrire` n'ont pas été conclus par l'audit | ETAT §4.3 |
| hors des 69 termes, les silhouettes restent génériques | ETAT §4.2 |
| aucune reprise quand un travail attend sans machine (81 min mesurées) | ETAT §8 |
| l'URL signée de 6 h est publiée telle quelle dans le Challenge | ETAT §8 |
| les codes techniques des erreurs 3D sont affichés à l'étudiant | ETAT §8 |

### 4.3 Un défaut de conformité, non inscrit : l'attribution CC-BY n'est jamais affichée

`convoquer.py:222` le dit lui-même : « 87,8 % des objets sont en `by` : leur
licence EXIGE de citer l'auteur ». La fonction `attribution()` existe
(`convoquer.py:227`). **Aucun fichier du dépôt ne l'appelle** (vérifié par
recherche sur tous les `.py` et `.js`). Les capsules « volcan » livrées le
05/09 utilisent l'objet `a091df40` (`by`) sans aucune mention. Par ailleurs,
la fonction rend des identifiants d'objet, pas les noms des auteurs : même
appelée, elle ne satisferait probablement pas la clause d'attribution.
**À corriger avant toute ouverture aux étudiants.**

### 4.4 Ce qui n'a pas pu être vérifié aujourd'hui

- **LWS** : SSH expire (quatre essais étalés sur la séance, ping à 50 % de
  pertes). L'état des
  services (`studio-preparateur`, `whiteboard-worker`) et l'écart entre
  `/opt/studio_visuel` et le dépôt **ne sont pas relevés**. Ils ne sont pas
  supposés non plus.
- **L'image du pod** n'a pas été ouverte (§ `ou-tourne-le-code` : on ne dit
  pas ce qu'elle contient sans l'avoir ouverte).
- **Le modèle LLM** réellement utilisé (secret `OPENROUTER_MODEL`).
- **La qualité perçue** des 13 capsules livrées : elles n'ont pas été regardées
  aujourd'hui.

---

## 5. Comment font les autres (veille du 28/10)

Les quatre angles de `veille-externe`. La littérature sur la génération de
scènes par code (SceneCraft, LL3M, 3DCodeBench, SimWorlds) est déjà couverte
par `STUDIO_3D_RECHERCHE_SCENE_GENEREE_2026-08-11.md` et n'est pas reprise.

### 5.1 Les chaînes « sans visage » des réseaux sociaux

Le schéma est le même chez les fournisseurs (InVideo, HeyGen, Captions,
PixVerse), d'après leurs propres guides, donc **des sources commerciales** :
script, découpage en plans, voix, puis visuels plan par plan (banque de
plans, image vers vidéo, ou titre), sous-titres calés sur la voix, montage.
Le guide de PixVerse recommande de découper en plans courts, **une idée par
plan**, plutôt que de demander tout le sujet à un seul prompt. **Aucun banc
d'essai indépendant** n'a été trouvé.

C'est très probablement la famille de la référence. Elle impose deux choses :
1. **TikTok** renforce depuis juillet 2026 la détection et l'étiquetage des
   comptes qui ne publient que du contenu généré par IA, en visant
   explicitement la **santé** parmi les sujets à risque (cbnews, Siècle
   Digital). Un corps humain et sa physiologie entrent dans cette catégorie.
2. Le **travail humain** de relecture reste entier : le guide de PixVerse le dit
   lui-même. Un modèle vidéo invente des détails, et l'exactitude
   scientifique n'est pas son objectif.

### 5.2 Le prix des modèles vidéo, par seconde produite

Ce sont des **annonces** relevées sur des agrégateurs datés d'août et
septembre 2026, pas des mesures. La page officielle de Google, mise à jour le
27/10, **ne montre plus Veo** et affiche un modèle « Gemini Omni Flash » à
environ 0,10 $/s en 720p : le marché bouge en semaines, et ces prix sont à
revérifier le jour de l'achat.

| Modèle | 720p | 1080p | Source |
|---|---|---|---|
| Veo 3.1 Lite | 0,05 $/s | 0,08 $/s | InVideo, d'après le tarif Gemini (08/2026) |
| Veo 3.1 Fast | 0,10 $/s | 0,12 $/s | idem |
| Veo 3.1 | 0,40 $/s | 0,40 $/s | idem |
| Kling 3.0 Turbo | ≈ 0,11 $/s | crédits | Kling API |
| LTX-2.3 Fast / Pro | — | 0,06 / 0,08 $/s | ltx.io |
| Wan (Alibaba, API) | 0,08 $/s | 0,17 $/s | agrégateurs |
| Seedance 2.x | ≈ 0,15–0,30 $/s selon revendeur | ≈ 0,37 $/s | **sources contradictoires** |

**Les modèles ouverts.** *Wan 2.2* est sous **Apache-2.0**, vérifié sur la
fiche HuggingFace. C'était déjà la décision du 05/08. Le modèle 5B annonce
« 5 s de 720p en moins de 9 min sur une carte grand public ». Le 14B demande
**80 Go de VRAM** sur une seule carte, et les versions distillées en 4 étapes
annoncent un gain de 2× à 20× selon la base de comparaison. *LTX-2* n'est
**pas** open source : sa licence est gratuite sous 10 M$ de chiffre
d'affaires et interdit la concurrence avec Lightricks (texte de licence
daté du 05/01/2026). Le dépôt sait déjà appeler Wan en image vers vidéo
(`generateur_ia.py:226`), et **cette voie n'a jamais été exécutée**.

### 5.3 Les outils programmatiques — la famille de notre moteur

Manim, Remotion, Motion Canvas et Three.js rendent des images exactes,
déterministes et étiquetables, à coût marginal quasi nul. C'est notre voie
actuelle. Le bloom, la brume et les particules de la référence s'y obtiennent
par **post-traitement** : `UnrealBloomPass` (documentation officielle de
three.js, qui demande d'activer le tone mapping), bloom sélectif par calques,
brouillard exponentiel et plans de brume animés par un bruit déterministe.
Cela approche l'image de la référence **sans** la volumétrie peinte des
modèles de diffusion.

**OpenMontage** (`calesthio/OpenMontage`) orchestre Veo, Kling, FLUX et
ElevenLabs depuis un assistant de code. Il est sous **AGPL-3.0**, licence qui
contamine tout ce qu'on y relie, comme la GPL-3.0 qui a fait écarter
Storyboard AI le 05/08. On peut s'en inspirer comme source d'idées, **pas
l'intégrer**.

### 5.4 Ce que j'ai cherché pour contredire

- « La référence est faite en 3D temps réel » : rien ne l'établit, rien ne
  l'exclut. L'hypothèse de la diffusion reste une hypothèse (§1).
- « La vidéo générative est devenue assez bon marché » : à 0,05 $/s, le prix le
  plus bas annoncé, une capsule de 90 s coûte **4,50 $**, soit **180 fois** ce
  que paie l'étudiant. La baisse des prix ne ferme pas l'écart.
- « Wan auto-hébergé serait gratuit » : faux. Au rythme annoncé, 90 s de
  vidéo, c'est 18 plans de 5 s à environ 9 min chacun, donc près de
  **2 h 40 sur une seule carte**, ou 18 machines lancées ensemble, chacune
  avec son amorçage et le téléchargement de ses poids (environ 15 Go au moins).
  C'est incompatible avec l'attente d'un étudiant. Cela reste possible hors
  ligne, pour un catalogue.

---

## 6. Ce qu'il faut pour reproduire ce type de vidéo sur n'importe quel sujet

### 6.1 Trois voies, chiffrées

| | A. Moteur navigateur enrichi | B. Modèle vidéo génératif | C. Hybride |
|---|---|---|---|
| principe | porter les 10 éléments de style dans Three.js ; banque d'objets étendue | chaque plan généré par un modèle vidéo (texte ou image vers vidéo) | A pour la structure exacte ; plans génératifs **pré-fabriqués** pour l'atmosphère et l'accroche |
| ressemblance à la référence | ≈ 70–80 % (*estimation*) : même grammaire, sans volumétrie peinte | la plus proche (*hypothèse*) | proche sur l'accroche, exacte sur le fond |
| exactitude scientifique | **contrôlée** (on sait ce qu'on dessine) | **non contrôlée** (anatomie inventée, texte illisible) | contrôlée là où elle compte |
| « n'importe quel sujet » | limité par la banque (69 termes aujourd'hui) + 5 verbes de forme | oui, en apparence | banque + boucles génériques |
| coût par capsule de 90 s | ≈ 0,04–0,08 $ (*rendu ×1,5–2 attendu avec le post-traitement, non mesuré*) | **4,50 à 36 $** selon le modèle (*annonce*) | ≈ 0,05 $ + 0 à 1 $ si un plan d'accroche est généré à la demande |
| délai | ≈ 3–5 min (*mesuré à 3,3 min sans post-traitement*) | plans en parallèle, quelques minutes **si** les quotas de l'API le permettent (*non mesuré*) | ≈ A |
| décision passée contredite | aucune | **oui** : voie (a) « images génératives » refusée par Jocelyn le 11/08 | partiellement (a), pour l'atmosphère seulement |
| écart au prix payé (≈ 0,02 $) | ×2 à ×4 | **×200 à ×1 400** | ×2 à ×50 |

**Pourquoi rouvrir (a) seulement maintenant, et seulement en partie.** Le
refus du 11/08 visait « montrer le sujet par des images génératives ». Deux
faits ont changé depuis : la référence elle-même relève très probablement de
cette famille, et le prix par seconde est descendu jusqu'à 0,05 $ (annonce).
Aucun des deux ne lève l'objection de fond, qui est l'exactitude d'un cours.
La voie C ne demande donc **pas** à un modèle génératif de montrer le
sujet : seulement l'**atmosphère** (brume, grille, particules, corps
stylisé), fabriquée une fois et réutilisée. La décision revient à Jocelyn.

### 6.2 Les briques, une par une

| Brique | Existe | Manque |
|---|---|---|
| **Moteur de rendu** | Three.js + Chromium sur pod, déterministe, 0,13 s/image | post-traitement (bloom sélectif, brume, profondeur de champ), particules déterministes, sommets lumineux, matière « énergie » rouge ancrée dans un objet, verre à effet Fresnel, cadre 16:9 |
| **Banque d'objets 3D** | 69 termes, 764 objets Objaverse, licences vérifiées ; banc `test_index_objets.py` | couverture mesurée sur de vrais sujets ; 250–400 termes pour le programme ; **attribution affichée** ; objets lisibles (aplat blanc) ; TRELLIS.2 (MIT, retenu le 11/08) pour combler hors ligne |
| **Scènes par l'IA** | invite à intentions + 7 verbes, validation qui nettoie, 37 tests Deno | le **ton** de la référence (accroche, idée reçue, révélation) ; relier chaque geste aux mots de sa scène ; dire **où** loger l'énergie (« le thorax ») |
| **Voix** | Voxtral mini TTS via OpenRouter, voix `fr_marie_neutral`, tempo 0,88, loudnorm −16 LUFS | un comparatif à l'oreille (voix plus grave, plus expressive), coût négligeable |
| **Sous-titres** | ASS incrustés, zone basse protégée | style de la référence : police ronde et grasse, sans contour lourd, à l'intérieur du cadre 16:9 |
| **Son** | `sound_design.py` (nappe synthétisée, ducking, accents), mélangé sur LWS par `narration.caler` | une écoute de contrôle ; une ambiance plus « cinéma » si la référence l'exige |
| **Contrôle** | porte d'acceptation à 6 mesures, journal du pod remonté même en cas de succès | juge visuel en refus seulement (conçu le 11/08, jamais construit) |

### 6.3 L'ordre de construction recommandé

Les durées sont des **estimations** d'effort d'agent, à corriger après le
premier lot.

| Lot | Contenu | Durée | Coût machine | Vérification |
|---|---|---|---|---|
| **0** | **Décisions de Jocelyn** : voie A, B ou C ; prix d'une capsule ; format 16:9 cadré ou 9:16 plein | — | 0 | — |
| **1** | **Parité de style** dans `academia3d_web.js` : bloom sélectif, brume, particules et sommets (graine fixe), verre Fresnel, lueur sous la grille, cadre 16:9, style des sous-titres | 2–3 j | ≈ 1 $ d'essais | les deux images de référence recomposées à la main avec les verbes, comme le test d'acceptation du 11/08 ; mesure en s/image avant/après |
| **2** | **Objets convoqués lisibles** (§4.2 bis) : arêtes par seuil d'angle (`EdgesGeometry`) ou décimation, plus du verre | 1 j | < 1 $ | le volcan du 05/09 rejoué : plus d'aplat blanc |
| **3** | **`incandescer`** : la masse rouge **dans** un objet, à une zone donnée par l'IA (fraction de la boîte englobante) | 1 j | < 1 $ | le corps avec son foyer au thorax (image 1) |
| **4** | **Banque** : mesurer la couverture sur les sujets réellement tapés (whiteboard_projects), étendre à 250–400 termes, **attribution au générique** | 2–3 j | 0 | taux de sujets qui trouvent leur objet, avant et après |
| **5** | **Écriture** : invite au ton de la référence, gestes liés aux mots, comparaison entre scènes (préconisée le 14/08) | 1 j | ≈ 0,01 $ | 10 sujets, lus |
| **6** | **Voix** : trois voix comparées sur trois phrases | ½ j | < 0,10 $ | écoute par Jocelyn |
| **7** | **Option C**, si elle est décidée : banque d'ambiances pré-générées (50 à 100 boucles de 5 s), puis un plan d'accroche par capsule | 2 j | **25 à 100 $** une fois (*annonce*) | duel à l'image contre le lot 1 |
| **8** | Exploitation : image du pod allégée (4,47 Go), reprise automatique, accès LWS rétabli, URL durable dans le Challenge | 2 j | — | journal de bout en bout |

**Pourquoi le lot 1 passe avant tout le reste.** Il est le seul qui rapproche
**toutes** les capsules de la référence d'un coup, sur le moteur qui tourne
déjà. Il ne demande ni décision commerciale, ni nouvelle machine, ni licence
nouvelle. Il respecte en outre la règle de `studio-visuel-3d` : la brume et le
halo **habillent** toute scène, alors que l'énergie rouge (lot 3) ne se branche
qu'avec un objet où se loger.

### 6.4 Une idée commerciale, à trancher par Jocelyn

`studio_creer_travail_etudiant` rend **déjà** la capsule existante au lieu
d'en refabriquer une. En plus de la génération à la demande, on pourrait
constituer un **catalogue** : les 100 sujets les plus demandés du programme,
fabriqués une fois en qualité maximale, au besoin par la voie B ou C, relus
par un humain, puis servis à tous. Coût unique d'environ **450 à 1 000 $** en
voie B (*annonce*), nul ensuite. Cela inverse l'économie, qui est intenable
aujourd'hui à la demande.

---

## 7. Ce qui est décidé, écarté, et non vérifié

**Décidé dans ce document : rien.** Il propose, et Jocelyn arbitre.

**Écarté, avec motif :**
- **OpenMontage dans le produit** : licence AGPL-3.0, qui contamine.
- **Wan auto-hébergé à la demande** : environ 2 h 40 de calcul par capsule à
  un seul GPU (annonce). Il reste envisageable hors ligne.
- **Relever la limite du bucket** pour accueillir des capsules plus riches :
  déjà écarté le 20/08, la contrainte protège l'étudiant.

**Non vérifié :**
1. l'état de LWS (SSH injoignable le 28/10) ;
2. la façon dont la référence a été fabriquée ;
3. les prix des modèles vidéo : des annonces, et l'offre officielle de Google
   a changé depuis ;
4. le surcoût de rendu du post-traitement dans Chromium avec `gl-egl` ;
5. le taux de change FCFA/$ utilisé (600) ;
6. la qualité perçue des 13 capsules livrées, qui n'ont pas été regardées
   aujourd'hui.

## Sources

- InVideo, *AI Video Model Pricing (Aug 2026)* — https://invideo.io/blog/ai-video-model-pricing/
- Google, tarifs de l'API Gemini, page mise à jour le 27/10/2026 — https://ai.google.dev/gemini-api/docs/pricing
- Tarifs comparés, ModelsLab — https://modelslab.com/best-ai-video-api-2026 · TeamDay — https://www.teamday.ai/blog/best-ai-video-models-2026 · Infer — https://tryinfer.com/pricing/cheapest-ai-video-api
- Wan 2.2 I2V A14B (Apache-2.0) — https://huggingface.co/Wan-AI/Wan2.2-I2V-A14B
- Wan 2.2 distillé (LightX2V) — https://huggingface.co/lightx2v/Wan2.2-Distill-Models
- Licence LTX-2 — https://static.lightricks.com/legal/ltx-2-open-weights-license-0.X.pdf
- OpenMontage — https://github.com/calesthio/OpenMontage
- three.js, UnrealBloomPass — https://threejs.org/docs/pages/UnrealBloomPass.html
- PixVerse, chaînes sans visage — https://pixverse.ai/en/blog/faceless-youtube-ai-video-generator
- TikTok et les comptes de contenu IA — https://www.cbnews.fr/mobile/tiktok-s-attaque-aux-comptes-proposant-uniquement-du-contenu-genere-ia · https://siecledigital.fr/2026/07/15/tiktok-declare-la-guerre-aux-comptes-qui-saturent-la-plateforme-de-videos-generees-par-ia/
