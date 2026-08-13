---
name: continuite-du-chantier
description: Reprendre le contexte de ce qui a deja ete decide, essaye et abandonne AVANT de proposer — pour ne pas reinventer, ne pas contredire une decision motivee sans le savoir, et ne pas redecouvrir un defaut deja diagnostique. Obligatoire a la reprise de tout chantier, et avant toute proposition qui touche une couche qu'on n'a pas ecrite dans la seance.
---

# Reprendre le fil, avant de proposer

## Pourquoi cette competence existe

Le 11/08/2026, une banque d'objets 3D sous licence CC0 a ete recommandee comme
solution neuve. Le depot contenait deja `contours/fabriquer_contours.py`, dont
l'entete tranchait la question **dans l'autre sens**, avec un motif :

> « Un contour recupere sur internet arrive avec sa licence, son auteur, et le
> doute qui va avec. Pour une plateforme commerciale, chaque fichier devrait etre
> trace, verifie, renouvele. Ceux-ci sont generes par des equations : ils nous
> appartiennent sans discussion. »

La meme seance, une conception a designe « montrer l'objet du sujet » comme le
trou a combler — alors que `capsules/chaleur_corps.json` contenait deja une scene
`genere` dont l'invite etait, mot pour mot, l'image de reference fournie par
Jocelyn. Le projet avait deja repondu a cette question ; la reponse avait ete
refusee. Le proposer a nouveau sans le savoir fait perdre la confiance autant que
le temps.

> Une proposition qui ignore une decision passee n'est pas neuve. Elle est amnesique.

## Quand cette procedure est OBLIGATOIRE

- A la reprise d'un chantier laisse en sommeil.
- Avant toute proposition touchant une couche qu'on n'a pas ecrite dans la seance.
- Avant d'ecrire « il faudrait », « on pourrait », « la solution serait ».
- Quand une idee parait evidente. Si elle l'est, elle a probablement deja ete eue.

## L'ordre de lecture

1. **Le hook de demarrage.** Il annonce l'etat **mesure** — branche, fichiers non
   commites, mise en sommeil. Il ne vieillit pas, contrairement a CLAUDE.md.
2. **Les documents dates de `docs/`**, du plus recent au plus ancien. La convention
   du projet est d'**ajouter un fichier date sans reecrire l'historique** : le plus
   recent corrige le precedent, il ne l'annule pas.
3. **Les entetes de fichiers.** Ce depot documente le **pourquoi** dans les
   docstrings, pas seulement le quoi. `style_reference.py`, `montage.py`,
   `studio_amorceur.py` et `fabriquer_contours.py` portent chacun des decisions
   motivees et des pieges mesures. Les lire avant de les modifier.
4. **Le journal git** — `git log --oneline -20`, et les messages de commit, qui
   disent ce qui a ete repare et pourquoi.

## Les trois questions a se poser avant toute proposition

1. **Est-ce que ca a deja ete essaye ?** Le depot conserve des moteurs abandonnes
   (`whiteboard_engine_remotion/`, `scene_template.html`, chaine Pillow) comme
   archives. Le moteur de production est `whiteboard_vision/` pour le tableau, et
   `studio_visuel/` pour la 3D.
2. **Est-ce que ca contredit une decision motivee ?** Si oui, le dire, citer le
   motif, et expliquer ce qui a change. Une decision se rouvre — pas en silence.
3. **Est-ce que le defaut est deja diagnostique ?** Un symptome identique peut
   avoir une cause differente ; l'inverse aussi. Chercher avant de rediagnostiquer.

## Ce qui doit apparaitre dans une proposition

| Element | Pourquoi |
|---|---|
| ce qui existe deja et qui sert | eviter de reecrire |
| ce qui existe deja et qui **ne sert pas** | souvent la trouvaille la plus rentable |
| la decision passee qu'on contredit, et son motif | pour que Jocelyn arbitre en connaissance |
| ce qui a change depuis | sans quoi rouvrir n'est pas justifie |

Exemple mesure le 11/08 : `matiere_feu` et `matiere_brume` sont ecrites, abouties,
et **appelees par aucun archetype de production** — seulement par un fichier
d'essai. Les brancher coute presque rien et change l'image. Une proposition qui
ignore l'existant serait passee a cote.

## La regle qui prime

> **Ne jamais deduire un etat de ce qu'on ne voit pas.**

Elle vient des sept defauts recenses dans `docs/STUDIO_VISUEL_ETAT_2026-08-05.md`.
Six se cachaient derriere une absence de message ; le septieme derriere un message
de **succes** — une video noire et muette livree a un etudiant comme « prete ».

## Documenter pour la suite

En fin de chantier, **ajouter un fichier date** dans `docs/` :

- ce qui a ete **mesure**, avec la commande ;
- ce qui a ete **decide**, avec le motif ;
- ce qui a ete **ecarte**, avec le motif — c'est la partie qu'on oublie, et c'est
  celle qui evite de reouvrir la meme question dans trois semaines ;
- ce qui reste **non verifie**, nommement.

Ne pas reecrire un document existant : en ajouter un, et le lier.
