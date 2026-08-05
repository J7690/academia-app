---
name: official-research
description: Se documenter sur une technologie a partir des sources officielles, en datant et en citant. A utiliser avant d'adopter une bibliotheque, de changer une API, de trancher une question de licence, ou quand une reponse repose sur un souvenir plutot que sur une source.
---

# Chercher aux sources officielles

Ce projet tourne sur des couches qui bougent vite : Flutter, Supabase, LiveKit,
Android, modeles ouverts. Un souvenir de version est une source de defaut.

## L'ordre des sources

1. **La documentation officielle de l'editeur** — flutter.dev, supabase.com/docs,
   docs.livekit.io, developer.android.com.
2. **Le depot du projet** — CHANGELOG, notes de version, issues fermees. C'est
   souvent la seule source exacte sur « depuis quelle version ».
3. **Le code de la dependance installee**, dans `~/.pub-cache` ou
   `academia_app/.dart_tool`. Il ne ment pas sur ce qui est reellement present.
4. En dernier — et en le disant — un billet ou une reponse de forum.

## Ce qu'une reponse doit porter

- **La source**, en lien.
- **La version** concernee, et celle utilisee ici.
- **La date** de la source. Une reponse de 2023 sur Android 14 est suspecte.
- Ce qui est **affirme par la source** vs ce qui est **deduit**.

Sans ces quatre elements, ce n'est pas de la documentation, c'est un souvenir.

## Verifier ce qu'on utilise vraiment, avant de chercher

```bash
cd academia_app && flutter pub deps --style=compact | head -40
cd academia_app && flutter pub outdated
```

Chercher la documentation d'une version qu'on n'utilise pas est la facon la
plus rapide de perdre une heure.

## Les licences sont une specification technique, pas un detail juridique

Ce projet a deja ecarte des composants pour cette seule raison, et ces
decisions **ne se rouvrent pas sans motif** :

| Composant | Decision | Motif |
|---|---|---|
| Storyboard AI | ecarte | GPL-3.0 — contaminerait l'APK |
| FLUX.1-dev | ecarte | licence non commerciale |
| FLUX.1-schnell | depot restreint | exige un compte et l'acceptation de conditions |
| WAN 2.2 | retenu | Apache-2.0 |
| Musique | synthetisee | aucun abonnement |

Avant d'adopter une dependance : **lire sa licence**. Une GPL dans un APK
distribue est un probleme qu'on ne decouvre pas apres coup.

**Ne jamais accepter des conditions d'utilisation a la place de Jocelyn.** Si un
depot exige l'acceptation de conditions, le dire et s'arreter la.

## Ce qui est deja tranche dans ce projet

Ne pas re-explorer sans raison nouvelle — c'est documente dans
`docs/rapport_smart_whiteboard_2026-07/06_RESTE_A_FAIRE.md` :

- **100 % CSS** pour les animations du whiteboard. GSAP et Lottie pilotes en JS
  cassent la capture par tranches. Ecartes deliberement.
- **Aucun calcul d'IA sur le VPS.** Kokoro-82M en local a ete abandonne
  (RTF 3,25–4,5). Toute IA passe par une Edge Function.
- **Railway et Kamatera** sont abandonnes. Ne pas y revenir.

## Quand la source n'existe pas

Le dire. « Je n'ai pas trouve de source officielle ; voici ce que j'ai trouve et
son degre de fiabilite » est une reponse utile. Une affirmation confiante sans
source ne l'est pas.
