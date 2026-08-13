---
name: veille-externe
description: Aller voir comment le probleme est resolu AILLEURS avant de trancher — plateformes concurrentes, litterature, depots publics — et croiser les sources plutot que retenir la premiere. Obligatoire avant toute decision d'architecture, tout choix de composant, et toute conclusion du type « la seule facon de faire, c'est ».
---

# Voir comment ca marche ailleurs, avant de decider

## Pourquoi cette competence existe

Le 11/08/2026, une conception du Studio 3D a ete rendue apres lecture de la
litterature academique — mais **sans aucune etude des plateformes**. Aucun regard
sur la facon dont ce genre de video est reellement produit ailleurs, ni sur les
outils du marche. Une voie entiere (le modele video generatif) avait ete ecartee
d'emblee sur une mauvaise lecture d'une consigne passee, et jamais rouverte.

Jocelyn a pose la question : « as-tu fait des recherches croisees, comparees,
externes ? » La reponse etait non. Elle ne doit plus l'etre.

> Le premier resultat de recherche n'est pas une conclusion. C'est une hypothese.

## Quand cette procedure est OBLIGATOIRE

- Avant d'adopter, d'ecarter ou de remplacer un composant.
- Avant toute decision d'architecture.
- Avant d'ecrire « la seule facon », « il n'existe pas de », « c'est impossible ».
- Quand une conclusion arrange trop le plan en cours.

## Les quatre angles — n'en sauter aucun

Un seul angle donne une reponse qui se tient et qui est fausse. Il en faut quatre :

1. **La litterature.** arXiv, actes de conference. Cherche les **bancs d'essai**
   plutot que les demonstrations : un banc publie des taux d'echec, une
   demonstration publie ses meilleurs cas.
2. **Les plateformes.** Comment le marche resout-il ce probleme aujourd'hui ?
   Qui vend ce service, avec quel pipeline, a quel prix, avec quel delai ?
   Ne pas confondre ce qu'un outil fait avec ce que sa page d'accueil montre.
3. **Les depots publics.** Le code et les issues fermees disent ce que la
   documentation tait. Une fonctionnalite demandee et refusee est une reponse.
4. **Ce que nous avons deja essaye.** Voir `continuite-du-chantier`. Le depot
   contient des moteurs abandonnes et des decisions motivees.

## Croiser, puis REFUTER

Une source qui confirme n'apprend rien. Avant de retenir une conclusion :

- **Chercher ce qui la contredit**, explicitement.
- **Attaquer les chiffres** : mesures ou annonce commerciale ? sur quel materiel ?
  quelle version ? Un chiffre de page produit n'est pas une mesure.
- **Attaquer les licences a la source.** Pas un resume, pas un billet : le fichier
  LICENSE. Le 11/08, un resume disait « permissive terms allow commercial
  distribution » ; le texte reel excluait **l'Union europeenne, le Royaume-Uni et
  la Coree du Sud**, et imposait une licence commerciale au-dela d'un million
  d'utilisateurs mensuels.
- **Attaquer la fraicheur.** Une source d'avant Blender 4.2 parle d'EEVEE Legacy
  et ne vaut plus. Une source d'avant 2026 sur les modeles ouverts non plus.

Quand la refutation tient, la conclusion tombe. On le **dit**, on ne la garde pas
« sous reserve ».

## Ce qu'une conclusion doit porter

| Element | Sans quoi |
|---|---|
| la source, en lien | c'est un souvenir |
| sa date | c'est peut-etre perime |
| **mesure** ou **annonce** ? | c'est du marketing |
| ce qui a ete **cherche pour contredire** | c'est une confirmation de biais |
| ce qu'on **n'a pas pu verifier** | c'est une affirmation en trop |

## Le piege de l'outil parallele

Les sous-agents et les workflows sont utiles pour couvrir plusieurs angles a la
fois. Ils tombent aussi : le 11/08, six agents sur huit ont ete tues par une
limite de session. **Verifier ce qui est reellement revenu** avant de synthetiser,
et refaire soi-meme ce qui manque plutot que de rendre une synthese trouee sans
le dire. Le journal du workflow (`journal.jsonl`) contient les resultats des
agents qui ont abouti : les recuperer avant de relancer.

## Ce qui est deja tranche, et ne se rouvre pas sans motif NOUVEAU

Voir `official-research` pour les licences, et `continuite-du-chantier` pour les
decisions du chantier. Rappel des interdits durables :

- **Railway et Kamatera** — abandonnes, ne pas y revenir.
- **Aucun calcul d'IA sur le VPS LWS** — 4 vCPU, pas de GPU.
- **100 % CSS** pour les animations du whiteboard.
- **Ne jamais accepter des conditions d'utilisation a la place de Jocelyn.**

Rouvrir une decision est permis. Le faire sans dire qu'elle etait tranchee, non.
