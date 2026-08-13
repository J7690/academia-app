# Studio visuel — chronogramme jusqu'à la première capsule de production

> **06/08/2026.** Mandat de Jocelyn : **aller en production**. La consommation de
> crédits n'est pas un critère pour l'instant ; on rationalisera une fois qu'une
> capsule correcte sera sortie — musique, voix, animations, scènes cohérentes et
> fluides.
>
> Ce document remplace le plan de reprise pour la partie exécution. Les
> constats mesurés restent dans `STUDIO_VISUEL_REPRISE_2026-08-05.md` et
> `STUDIO_VISUEL_MESURE_CAPSULES_2026-08-05.md`.

---

## État mesuré au départ, le 06/08 vers 10 h

| Élément | État | Preuve |
|---|---|---|
| VPS LWS | **actif**, 5 jours d'uptime, 136 Go libres | `ssh lws-nexiom` |
| `studio-amorceur` (systemd) | **actif** | `systemctl is-active` |
| Voix (`whiteboard-tts`) | **fonctionne** | HTTP 200, MP3, 3,56 s |
| Sound design | **fonctionne**, synthétisé ffmpeg | capsule locale sonore |
| 10 archétypes Blender | **tous visibles** après correctif `filaire` | banc local 1080×1920 |
| Montage + sous-titres + contrôle | **fonctionne** | capsule 30,4 s, 4 scènes, aucune sombre |
| `/opt/studio_visuel` sur LWS | **PÉRIMÉ** — `scenes_sombres` absent | `grep` distant |
| Scènes `genere` | **noires, cause non établie** | hypothèse VAE réfutée |
| `runpod-watchdog` (cron) | actif, `succeeded` toutes les 2 min | `cron.job_run_details` |
| Solde du compte RunPod | **INCONNU** — hors de ma portée | — |

---

## Le principe de ce chronogramme

**Deux voies, menées dans cet ordre.** La voie procédurale est prête ; la voie
« matière » (`genere`) ne l'est pas. Attendre la seconde pour livrer la première
retarderait tout sans rien garantir.

> **P3 sort une capsule complète sans `genere`.** C'est la première vidéo
> correcte. `genere` s'y ajoute en P5.

---

## Phase 1 — Remettre la production au niveau du code · **0,00 $** · ~20 min

Le VPS exécute encore le code d'avant le 05/08. Lancer une capsule maintenant
relivrerait le défaut déjà corrigé.

1. Déployer les modules de `academia_bobodo_backend/studio_visuel/` vers
   `/opt/studio_visuel/`, **fins de ligne normalisées à destination** (la leçon
   des trois machines perdues sur du CRLF).
2. Corriger `studio_amorceur.py` : le `sed` d'extraction du jeton HuggingFace a
   une substitution **vide** (`//` au lieu de `/\1/`), le jeton n'a donc jamais
   pu être récupéré — et le journal annonçait un mode dégradé normal.
3. Vérifier par md5, fichier par fichier, que le distant égale le dépôt.

**Fait quand** : `md5sum` identiques sur les 13 modules, et `scenes_sombres`
présent côté LWS.

---

## Phase 2 — Boucler la voix, en local · **~0,01 $** · ~15 min

La règle d'or du projet est que **la voix commande l'image**. Elle n'a jamais été
exercée sur le Studio : les durées de la capsule de contrôle du 06/08 viennent
d'une estimation par nombre de mots.

1. Faire tourner `narration.py` sur LWS pour la capsule de contrôle.
2. Vérifier que chaque scène porte `mesuree: true` et une durée **mesurée**.
3. Re-rendre la capsule avec ces durées et confronter voix et sous-titres.

**Fait quand** : les quatre scènes portent une durée mesurée, et la voix tombe
dans sa scène.

---

## Phase 3 — Première capsule de production complète · **~0,21 $** · ~35 min

Sans `genere`. Six scènes procédurales, voix, musique, sous-titres.

1. Déposer le travail dans la file (`studio_mettre_en_file`).
2. **Un seul** appel à `studio-orchestrateur` — un appel, au plus une machine,
   aucune boucle. On ne réactive pas le cron à ce stade.
3. Le veilleur reste le filet : il éteint toute machine oisive.
4. Contrôle scène par scène, puis livraison.

**Fait quand** : une capsule déposée dans Storage, aucune scène sombre, du son,
et une URL signée que Jocelyn peut ouvrir.

---

## Phase 4 — Établir le noir de `genere` · **~0,15 $** · ~25 min

**La cause n'est pas connue et ne sera pas devinée.** L'hypothèse du débordement
VAE en `bfloat16` est réfutée : toutes les sources datées attribuent les images
noires à `float16` et prescrivent `bfloat16` — ce que le code fait déjà.

Sur une machine louée, une seule session de diagnostic :

1. Générer une image et **journaliser** : version de `diffusers`, dtype effectif
   de chaque sous-modèle, statistiques des latents avant décodage VAE
   (min/max/moyenne/NaN), luminosité de l'image obtenue.
2. Comparer trois variantes : telle quelle, VAE en `float32`, et
   `guidance_scale=0` (FLUX schnell ignore le guidage — le réglage actuel de 3,5
   est inerte, comme `negative_prompt` et `max_sequence_length`).
3. Retenir la variante qui produit une image, et **la mesurer**.

**Fait quand** : une image générée dont la luminosité est mesurée au-dessus du
seuil, et une cause écrite noir sur blanc.

---

## Phase 5 — La capsule complète, avec `genere` · **~0,25 $** · ~40 min

Structure et matière dans la même capsule, comme le prévoit la conception.

**Fait quand** : une capsule mêlant archétypes procéduraux et scènes générées,
aucune scène sombre, voix et musique.

---

## Phase 6 — Cohérence et fluidité · **~0,25 $** · ~40 min

C'est le seul point que la mesure ne tranche pas : il se juge à l'œil.

1. Regarder la capsule de P5 en entier.
2. Corriger ce qui accroche : raccords entre scènes, vitesse de caméra,
   lisibilité des sous-titres, niveau de la musique sous la voix.
3. Re-rendre et re-regarder.

**Fait quand** : Jocelyn la valide.

---

## Coût total attendu

| Phase | Coût |
|---|---|
| 1 · déploiement | 0,00 $ |
| 2 · voix | ~0,01 $ |
| 3 · première capsule | ~0,21 $ |
| 4 · diagnostic `genere` | ~0,15 $ |
| 5 · capsule complète | ~0,25 $ |
| 6 · fluidité | ~0,25 $ |
| **Total** | **~0,87 $** |

Le plafond automatique reste à **5 $/jour**, et le veilleur éteint toute machine
oisive. Coût mesuré d'une capsule de bout en bout au 31/07 : **0,205 $**.

---

## Pourquoi on ne change pas d'hébergeur

La question d'AWS ou d'un autre fournisseur se pose légitimement. Réponse :
**non, pas maintenant.** RunPod est déjà branché — création de machine par Edge
Function sans que la clé transite, veilleur éprouvé sur 15 extinctions réelles,
facturation à la seconde, 0,44 $/h. Changer d'hébergeur avant d'avoir sorti une
capsule correcte reviendrait à remplacer la seule partie de la chaîne qui a fait
ses preuves. On y reviendra à l'étape « rationalisation ».

---

## Ce que je ne peux pas faire, et que Jocelyn doit faire

**1. Vérifier le solde RunPod.** Je n'ai aucune visibilité sur le compte. Le
veilleur rend `succeeded` toutes les deux minutes, mais cela prouve seulement
que l'appel part — pas que RunPod l'accepte. **Sans crédit, tout s'arrête à la
phase 3.** Se connecter à runpod.io, relever le solde, et me le dire.

**2. Autoriser deux gestes en production.** Ils me sont accessibles mais sont
volontairement en `ask` :
   - le déploiement `scp` vers `/opt/studio_visuel` (phase 1) ;
   - l'appel à `studio-orchestrateur` (phase 3).

**3. Vérifier le nom du secret HuggingFace.** Le code lit `TOKEN_HUGGINGFACE` ;
le secret aurait été créé sous `Token_hugginface`. Les noms sont sensibles à la
casse. Non bloquant — le modèle d'images retenu est public — mais à corriger.

**4. Facultatif, pour ma lecture de la base** : définir
`SUPABASE_ACCESS_TOKEN` dans l'environnement, faute de quoi le serveur MCP en
lecture seule du dépôt ne démarre pas.

Aucun mot de passe, aucune clé privée ne doit m'être transmis. Les clés vivent
dans les secrets Supabase, et la chaîne est conçue pour qu'elles n'en sortent
jamais.
