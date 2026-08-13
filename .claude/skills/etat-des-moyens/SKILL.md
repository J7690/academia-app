---
name: etat-des-moyens
description: Relever ce dont on dispose REELLEMENT — machines, services, outils, acces — avant de conclure quoi que ce soit sur la capacite, le cout ou la latence. Obligatoire avant toute decision d'architecture, tout chiffrage de temps d'attente, et toute affirmation du type « on ne peut pas » ou « il faudrait ».
---

# Relever les moyens, avant de conclure

## Pourquoi cette competence existe

Le 11/08/2026, une conception entiere du Studio 3D a ete rendue sur un coût fixe
de machine estime a **3 min 25**. Le relevé fait une heure plus tard a montre que
le vrai coût approche la **demi-heure** : chaque pod reinstalle apt, pip, et
retelecharge Blender (~15 min) puis le modele HuggingFace (~10 min).

Le chiffre etait ecrit **dans notre propre code**, `install_pod.sh:17`. Personne
ne l'avait lu. Comme le temps mural d'un rendu decoupe sur N machines vaut
`T/N + F` et qu'aucun N ne descend sous `F`, tout le raisonnement etait faux.

Le meme relevé a montre que **Docker etait installe sur LWS avec 136 Go libres**,
inutilise, alors que l'image de pod est ecrite comme travail a faire dans notre
propre depot.

> On ne deduit pas un moyen. On le releve.

## Quand cette procedure est OBLIGATOIRE

- Avant tout chiffrage de latence, de coût ou de capacite.
- Avant toute decision d'architecture qui suppose une machine, un service ou un outil.
- Avant d'ecrire « il faudrait installer X » — X est peut-etre deja la.
- Avant d'ecrire « on ne peut pas » — c'est une affirmation sur un etat, elle se mesure.
- A la reprise d'un chantier laisse en sommeil.

## Le relevé — commandes exactes

### LWS

```bash
ssh -o BatchMode=yes -o ConnectTimeout=15 lws-nexiom "nproc; free -g | head -2; df -h / | tail -1; systemctl list-units --type=service --no-pager --all | grep -Ei 'whiteboard|studio|academia|worker'; for c in python3 blender ffmpeg node deno git docker; do printf '%-10s ' \$c; (command -v \$c >/dev/null && \$c --version 2>&1 | head -1) || echo ABSENT; done; ls -1 /opt/"
```

**Etat mesure le 11/08/2026** — a re-mesurer, pas a recopier :

| Poste | Valeur |
|---|---|
| CPU / RAM / disque | 4 vCPU, 8 Go, 147 Go dont **136 libres** |
| GPU | **aucun** |
| Services actifs | `studio-amorceur`, `studio-preparateur`, `whiteboard-worker`, `video-worker` |
| Presents | python 3.12.3, ffmpeg 6.1.1, node 20.20.2, git, **docker 29.6.2** |
| **Absents** | **blender**, **deno** |

Consequence a ne pas oublier : **Deno est absent de LWS**. La tache marquee
« premiere chose a faire » dans CLAUDE.md (`deno test validate_test.ts`) ne peut
donc pas y etre executee non plus.

### Les acces — IL Y A PLUSIEURS ROUTES, les essayer toutes avant de conclure

**La faute a ne pas refaire.** Le 11/08, j'ai annonce « je n'ai pas pu interroger la
base » apres avoir constate qu'un connecteur ne demarrait pas. Un **second**
connecteur Supabase etait disponible depuis le debut de la session et fonctionnait.
Je ne l'avais pas essaye. Une route fermee n'est pas une absence de route.

**Trois routes vers Supabase**, a tester dans cet ordre :

| Route | Comment | Ecriture |
|---|---|---|
| connecteur **claude.ai** (nom en UUID) | `ToolSearch` puis `list_projects` | **POSSIBLE — attention** |
| `supabase-lecture` de `.mcp.json` | exige `SUPABASE_ACCESS_TOKEN` | interdite (`--read-only`) |
| **depuis LWS** | les services y detiennent deja `SUPABASE_SERVICE_KEY` ; lancer un appel PostgREST **sur la machine**, la cle ne transite jamais | selon la requete |

> Le connecteur claude.ai **n'est pas en lecture seule** : il expose `execute_sql`,
> `apply_migration` et `deploy_edge_function`. Les interdits d'ecriture en production
> tiennent alors par **discipline**, plus par contrainte technique. Ne s'en servir que
> pour des `select`, sauf autorisation explicite de Jocelyn.

```bash
# Presence du jeton du connecteur du depot. Verifier la PRESENCE, jamais la valeur.
if [ -n "${SUPABASE_ACCESS_TOKEN:-}" ]; then echo "jeton present"; else echo "ABSENT"; fi
```

Si toutes les routes sont fermees : **le dire immediatement**, ne pas travailler une
heure puis annoncer qu'on n'a pas pu verifier.
**Ne jamais demander un jeton en conversation, ne jamais le saisir soi-meme.**

### Le pod RunPod — lire le code, il fait foi

La clé RunPod est chez Supabase, pas sur le poste : on ne peut pas interroger
RunPod d'ici. Ce qui se passe reellement a chaque location se lit dans :

- `studio_visuel/studio_amorceur.py` — **c'est lui qui tourne en production**
- `studio_visuel/install_pod.sh` — **plus a jour, diverge** (il installe ComfyUI,
  l'amorceur non). Deux sources d'installation divergentes = panne en attente.

### Supabase

Sans connecteur, lire le depot — et **dire** que c'est le depot et non la base :

```bash
ls -1 supabase/functions/ | wc -l && ls -1 supabase/migrations/ | tail -12
```

## Les trois regles

1. **Ce qui n'est pas mesure n'est pas su.** Un moyen suppose se declare comme
   suppose, ou ne se declare pas.
2. **Lire notre propre code avant de chercher dehors.** Le chiffre de 15 minutes
   etait dans un commentaire depuis le 30/07.
3. **Un acces manquant se signale tout de suite.** Une conclusion rendue en
   precisant « je n'ai pas pu verifier X » vaut mieux qu'une conclusion confiante.

## Ce que le relevé doit produire

Un document date `docs/STUDIO_INVENTAIRE_MOYENS_<AAAA-MM-JJ>.md`, ou au minimum
une section datee, distinguant :

- **mesure aujourd'hui** — avec la commande qui l'a produit ;
- **lu dans le depot** — avec fichier:ligne ;
- **non verifie** — nommement, sans le noyer.

Reference : `docs/STUDIO_INVENTAIRE_MOYENS_2026-08-11.md`.
