---
name: project-map
description: S'orienter dans le depot Academia avant de toucher a quoi que ce soit — les deux projets Flutter, le SDK committe a ignorer, ou vit chaque couche. A utiliser au debut de toute tache qui touche du code inconnu, ou quand une recherche ramene des resultats incoherents.
---

# S'orienter dans Academia

Ce depot a trois pieges de structure qui font perdre des heures. Les connaitre
d'abord, chercher ensuite.

## Les trois pieges, dans l'ordre de cout

**1. Il y a DEUX projets Flutter.** `./pubspec.yaml` + `./lib/` est le projet
racine historique. **`academia_app/pubspec.yaml` + `academia_app/lib/` est
l'application reelle.** Toute commande `flutter` se lance **depuis
`academia_app/`**. Une commande lancee a la racine analyse le mauvais projet et
rend un resultat qui a l'air valide.

**2. `./flutter/` est un SDK Flutter complet, committe.** Ce n'est pas du code
applicatif. Ne jamais y chercher un bug, ne jamais le modifier, toujours
l'exclure des recherches. Sans exclusion, `rg` y noie tout resultat utile.

**3. Le depot contient des moteurs de rendu abandonnes**, conserves comme
archives : `whiteboard_engine_remotion/`, `scene_template.html`, la chaine
Pillow. **Le moteur de production est `academia_bobodo_backend/whiteboard_vision/`.**
Corriger un bug dans une archive donne l'illusion d'avancer.

## La forme du depot

| Chemin | Ce que c'est |
|---|---|
| `academia_app/lib/` | l'application Flutter reelle |
| `academia_app/lib/features/` | ecrans, par domaine metier |
| `academia_app/lib/services/` | acces reseau, Supabase, LiveKit, notifications |
| `academia_app/lib/providers/` | etat applicatif |
| `supabase/functions/` | Edge Functions Deno |
| `supabase/migrations/` | schema, en migrations horodatees |
| `academia_bobodo_backend/` | worker Python de rendu video (tourne sur le VPS LWS) |
| `academia_bobodo_backend/whiteboard_vision/` | le moteur de rendu **de production** |
| `academia_bobodo_backend/studio_visuel/` | studio GPU — **en sommeil depuis le 05/08/2026** |
| `docs/` | rapports dates ; on ajoute, on ne reecrit pas |
| `packages/` | paquets Flutter locaux |

## Convention Supabase, et sa consequence

Le schema metier est **`app`**. Les fonctions appelables sont dans **`public`**.
`app` n'est **pas** expose a PostgREST : une table de `app` n'est donc jamais
lisible directement depuis l'application — elle passe par une RPC de `public`.
Chercher une table dans `app` et conclure « l'app y accede » est faux.

## Comment chercher sans se tromper

Toujours exclure le SDK et les dependances :

```bash
rg "<motif>" academia_app/lib supabase academia_bobodo_backend
```

Pour une vue d'ensemble reelle plutot que supposee :

```bash
git ls-files | grep -v "^flutter/" | wc -l
```

## Avant de conclure « ca n'existe pas »

Une recherche vide dans ce depot signifie souvent qu'on a cherche au mauvais
endroit — pas que la chose n'existe pas. Verifier dans l'ordre : ai-je exclu
`flutter/` ? ai-je cherche dans `academia_app/lib` et pas `lib/` ? le symbole
est-il genere (`*.g.dart`, `*.freezed.dart`) et donc absent des sources ?

## Ce qu'il faut lire selon la tache

- **Contexte general** : `CLAUDE.md` a la racine.
- **Smart Whiteboard** : `docs/rapport_smart_whiteboard_2026-07/README.md`.
- **Studio visuel (en sommeil)** : `docs/STUDIO_VISUEL_ETAT_2026-08-05.md`
  **avant toute reprise** — l'orchestrateur facture a la seconde.
- **Methode de travail** : `docs/ACADEMIA_PERMANENT_EXECUTION_PROTOCOL.md`.

Voir aussi la competence `implement-and-verify` pour les commandes de
verification, et `deep-debug` quand quelque chose ne se comporte pas comme
prevu.
