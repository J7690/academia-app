# Smart Whiteboard — Plan « Spot Studio » (27/07/2026)

Objectif : un rendu qui semble monté avec plusieurs logiciels (motion design +
whiteboard + sound design), aligné sur les standards 2025-2026 du marché, en
intervenant DÈS la génération (storyboard, narration) jusqu'à la mise en scène.

## Ce que dit le marché (recherches du 27/07/2026)

- **Hybride whiteboard + motion graphics** : le pur whiteboard est perçu comme
  daté (pic 2014-2016). Le standard actuel : dessin manuscrit + accents de
  couleur, éléments de marque, transitions motion graphics (videoexplainers.com).
- **Typographie cinétique** : les mots-clés bougent, grossissent, changent de
  couleur EN SYNCHRONISATION avec la voix. Retention through rhythm (yansmedia).
- **Contiguïté temporelle** (Mayer, CTML) : ce qui s'affiche = ce qui se dit, au
  même instant. +40 % de charge cognitive en moins, +65 % de rétention.
- **Segmentation** : une idée à la fois, phrases ≤ 15 mots, ~150 mots/minute,
  pauses d'assimilation. Trop d'animations simultanées = contre-productif.
- **Sound design** : les spots pros vivent de leurs whoosh/pops/scratch d'écriture
  et d'un lit musical discret sous la voix. C'est LE marqueur « montage pro ».
- **Storytelling** : accroche → progression → récap visuel → appel à l'action.

## Vague E — Génération : le storyboard devient une RÉALISATION
Fichier : `supabase/functions/whiteboard-generate-storyboard/index.ts` (prompt v2.4 → v3)

1. **`narration` PAR BLOC** (pas seulement par scène) : le worker sait déjà caler
   l'écriture sur la voix bloc par bloc (`build_block_narration`), mais le prompt
   ne demande pas ce champ. Le générateur écrira 1 phrase de voix off par bloc
   → contiguïté temporelle parfaite, voix continue.
2. **`beat` par scène** : `hook | concept | example | exercise | correction | recap`.
   Le moteur adapte la mise en scène au rôle narratif (accroche plus punchy,
   récap en carte de synthèse).
3. **`key_words` par bloc** (1 à 3 mots copiés du contenu) : mots-clés destinés à
   la typographie cinétique (pop + couleur au moment où ils s'écrivent).
4. **Scène RECAP obligatoire en fin** : 3 à 5 points à retenir, courts → carte de
   synthèse animée + générique de fin.
5. **Contraintes de rythme dans le prompt** : phrases de narration ≤ 15 mots,
   ton oral direct, une question rhétorique dans l'accroche.

Rétro-compatibilité : tous les nouveaux champs sont OPTIONNELS, nettoyés par la
validation (comme emphasis/write_speed en v2.4). Les anciens storyboards restent rendus.

## Vague F — Mise en scène : typographie cinétique + habillage de chapitre
Fichier : `academia_bobodo_backend/whiteboard_vision/whiteboard_page_builder.py`

1. **Typographie cinétique** : les `key_words` s'écrivent en plus gros, en couleur
   d'accent, avec un pop élastique — synchronisés mot à mot (déjà word-level).
2. **Bandeaux de chapitre** : numérotation 01/02/03 sur la plaquette de titre de
   scène + barre de progression du cours en bas d'écran (fine, animée).
3. **Carte de synthèse finale** (beat `recap`) : les points à retenir apparaissent
   en liste à coches animées, puis générique de fin (logo + plaquette).
4. **Célébration de correction** (beat `correction`) : étoile/coche tamponnée
   après la dernière ligne (pop), style « validé par le prof ».
Contrainte inchangée : 100 % CSS (compatibilité capture par tranches).

## Vague G — Sound design : le marqueur « plusieurs logiciels »
Fichier : `academia_bobodo_backend/whiteboard_render_worker.py` (mixage ffmpeg, zéro capture)

1. **Bruitages** : whoosh au générique et aux plaquettes, pop discret aux badges,
   scratch de stylo léger pendant l'écriture (boucle basse, -22 dB), tampon à la
   correction. Banque de sons libres (CC0) stockée sur le VPS.
2. **Lit musical** : boucle discrète (-26 dB) avec sidechain/ducking sous la voix
   (ffmpeg `sidechaincompress`), fondu d'entrée/sortie.
3. Mixage entièrement en post (ffmpeg `amix`), calé sur les instants déjà connus
   du `plan()` : aucun impact sur la capture ni sur la synchronisation.

## Ordre conseillé
E (génération) → F (mise en scène) → G (son). E et F se testent ensemble sur un
rendu réel ; G se superpose sans risque.

## Déjà livré (27/07/2026)
- Générique d'ouverture animé (carte-titre lettres en cascade, sortie balayage).
- Main+stylo qui suit l'écriture mot à mot (100 % CSS).
- Badges pop, plaquettes déployées, formules pop, liseré synchronisé.
- Maths parlées via Speech Rule Engine ClearSpeak fr + corrections françaises.
- Kokoro (voix locale) testé et écarté : RTF 3,25-4,5 sur le VPS (trop lent).
