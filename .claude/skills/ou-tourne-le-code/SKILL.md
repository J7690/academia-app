---
name: ou-tourne-le-code
description: Etablir OU s'execute reellement le code qu'on vient de corriger, et QUELLE version y tourne, avant de dire qu'un correctif est en place. Obligatoire avant toute affirmation du type « c'est corrige », « c'est deploye », « ca devrait marcher maintenant ».
---

# Ou tourne le code, et quelle version

## Pourquoi cette competence existe

Le 13/08/2026, un correctif juste, teste, et effectivement ecrit dans le depot
n'a rien change au comportement — parce qu'il n'etait execute nulle part.

Mesure faite ce jour-la sur LWS :

    /opt/studio_visuel/*.py           dates du 07/08_11:55
    academia_scene.py local vs LWS    48 lignes reellement differentes
    studio_preparateur.py             non deploye

Le moteur qui tournait en production avait **six jours de retard** sur le depot,
et personne ne le savait. Le meme jour, l'image du pod n'a pas pu etre
inspectee (Docker eteint) : ce qu'elle contenait a donc ete **suppose** —
et le rendu est mort sur `/workspace/blender/blender`, un chemin que le depot
avait deja corrige.

Ce n'est pas un oubli isole : c'est la consequence d'une architecture a **trois
machines et trois codes**, ou « modifier un fichier » et « changer ce qui
s'execute » sont deux actes distincts qu'on confond.

## Les trois machines, et ce qui y tourne

| Machine | Quel code | Comment il arrive | Comment on VERIFIE |
|---|---|---|---|
| **Supabase** | Edge Functions | `supabase functions deploy <nom>` | `supabase functions list`, ou la version dans le tableau de bord |
| **LWS** `31.207.38.60` | `/opt/studio_visuel/*.py` | `scp` **puis** `systemctl restart` | `diff` contre le local, fins de ligne neutralisees |
| **Pod RunPod** | l'image Docker | reconstruction + publication + bascule de `app.studio_config` | `docker create` + `docker cp` puis lire les fichiers |

## La procedure

**1. Nommer la machine.** Avant de corriger, dire a voix haute ou le fichier
s'execute. `studio_preparateur.py` tourne sur LWS ; `executer_capsule.py`
tourne dans le pod ; `validate_capsule.ts` tourne chez Supabase. Un meme depot,
trois destinations.

**2. Comparer, ne pas supposer.** Sur LWS, neutraliser les fins de ligne, sinon
un fichier identique parait entierement different :

```bash
ssh lws-nexiom "cat /opt/studio_visuel/<fichier>" > /tmp/lws.py
diff <(tr -d '\r' < /tmp/lws.py) <(tr -d '\r' < <fichier>) | grep -c "^[<>]"
```

Mesure du 13/08 : `narration.py` affichait 714 lignes de difference et n'en
avait **aucune** — c'etait du CRLF. `academia_scene.py` en avait 48, vraies.

**3. Sauvegarder avant d'ecraser.** `cp -p` dans un dossier date sur la machine
cible. Un deploiement qu'on ne peut pas defaire est un deploiement qu'on
n'ose pas refaire.

**4. Redemarrer, et le prouver.** `systemctl restart` puis `is-active` puis
lire les premieres lignes du journal. Un service redemarre qui recharge
l'ancien fichier existe.

**5. Pour le pod : lire DANS l'image, jamais autour.**

```bash
docker create --name extrait <image>
docker cp extrait:/opt/moteur/. /tmp/verif/
docker rm extrait
```

Comparer les dates de `app.studio_config` avec les dates des sources ne prouve
rien : c'est une correlation, pas une lecture.

## Ce qu'on n'a pas le droit de dire

- « c'est corrige » — sans avoir vu le fichier sur la machine qui l'execute
- « c'est deploye » — sans avoir vu le service redemarre le prendre
- « l'image contient X » — sans avoir ouvert l'image
- « ca devrait marcher maintenant » — le conditionnel est l'aveu qu'on n'a pas mesure

## Ce qu'on dit a la place

> « Corrige dans le depot. **Non deploye** : LWS tourne encore la version du
> 07/08. Deploiement + redemarrage a faire avant tout essai. »

Un correctif non deploye n'est pas un demi-correctif : c'est zero, et il coute
en plus la confiance qu'on met dans l'essai suivant.

Voir aussi : `implement-and-verify`, `etat-des-moyens`, et `ETAT.md` §2, qui
tient a jour la date de ce qui tourne sur chaque machine.
