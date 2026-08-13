---
name: tracer-la-valeur
description: Suivre UNE valeur d'un bout a l'autre de la chaine et la MESURER a chaque frontiere, au lieu de lire le code couche par couche. Obligatoire des qu'un symptome survit a un correctif, et avant toute deuxieme variante d'un meme correctif.
---

# Tracer la valeur, frontiere par frontiere

## Pourquoi cette competence existe

Sur le Studio visuel, **le meme defaut a ete trouve a huit endroits
successifs** : l'invite, la validation serveur, la normalisation du pod, le
dictionnaire de rendu, le choix d'engine dans l'app, l'analyse cote app, la
reconnaissance de capsule du preparateur, puis les chemins codes en dur dans
l'image.

Symptome unique et constant du 07/08 au 13/08 : **deux sujets sans rapport
donnaient la meme video**. Sept des huit couches ne levaient **aucune erreur**.

A chaque fois, la sequence a ete la meme : trouver une couche, la corriger, la
declarer resolue, et voir le symptome survivre. Ce qui manquait n'etait pas de
la rigueur dans la lecture du code — c'etait de regarder **la donnee**.

## La cause de fond, propre a ce depot

Chaque couche applique la **degradation gracieuse** : « on nettoie, on ne
rejette pas ». C'est une bonne regle, elle protege l'etudiant, et elle est
inscrite dans les contraintes non negociables du projet.

Empilee huit fois, elle produit une chaine ou **rien n'echoue et rien n'est
juste** : chaque etage rattrape ce qu'il ne comprend pas vers son defaut, et le
message qui l'aurait dit n'est jamais emis.

Un correctif de plus ne change donc rien tant que les autres etages corrigent
encore.

## La procedure

**1. Choisir UNE valeur observable**, pas un comportement. Pas « la video est
generique » mais : *le champ `gestes` de la scene 1*.

**2. Lister les frontieres qu'elle traverse.** Pour une capsule 3D :

```
invite -> validation serveur -> app Flutter -> table studio_jobs
  -> preparateur LWS -> manifeste prepare -> image du pod
  -> normalisation -> dictionnaire de rendu -> Blender
```

**3. MESURER a chaque frontiere.** Une requete, pas une lecture de code :

```sql
select (select count(*) from jsonb_array_elements(manifeste->'scenes') s
          where s ? 'gestes')                       as scenes_avec_gestes,
       manifeste->'scenes'->0->>'archetype'         as archetype_s1,
       (select string_agg(distinct g->>'verbe', ', ')
          from jsonb_array_elements(manifeste->'scenes') s,
               jsonb_array_elements(s->'gestes') g)  as verbes
from app.studio_jobs where id = '<id>';
```

C'est exactement cette requete qui a montre, le 12/08, `scenes_avec_gestes = 0`
et `archetype_s1 = 'reseau'` — la composition de l'IA effacee, en silence, par
une couche qu'aucune lecture de code n'avait designee.

**4. La premiere frontiere ou la valeur change de sens est la couche fautive.**
Pas la premiere qu'on trouve en lisant : la premiere ou la MESURE bascule.

**5. Apres correction, remesurer la meme requete.** Le correctif se prouve sur
la donnee a l'arrivee, jamais sur le code modifie.

**6. Chercher les autres etages AVANT de conclure.** Une fois la couche connue,
la meme question se pose a toutes les autres : *celle-ci aussi corrige-t-elle
en silence ?* C'est cette question, posee huit fois, qui a fini par vider le
defaut.

## Le signal d'alarme

> **Un symptome qui survit a un correctif juste est la preuve qu'il y a une
> autre couche.** Ce n'est jamais la preuve que le correctif etait faux.

Des qu'on s'apprete a ecrire une **deuxieme variante du meme correctif** :
s'arreter, et tracer la valeur.

## Ce qu'on ecrit dans le code

Quand une couche corrige, elle doit le **nommer** : `corrections.push(...)`,
`journal.degrade(...)`, `alertes.append(...)`. Une correction silencieuse est
pire que la correction elle-meme — c'est ce qui a coute six jours.

Voir aussi : `deep-debug`, `ou-tourne-le-code`, `continuite-du-chantier`, et
la memoire `huit-couches-du-meme-defaut`.
