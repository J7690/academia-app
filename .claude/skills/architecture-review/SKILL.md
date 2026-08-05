---
name: architecture-review
description: Evaluer une decision de structure avant de l'implementer — ou vit la logique, quelles valeurs sont couplees, quel moteur est celui de production. A utiliser avant tout changement qui traverse plusieurs couches ou ajoute une dependance.
---

# Relire l'architecture avant d'ecrire

## Les couches, et ce qui a le droit de parler a quoi

```
Flutter (academia_app/lib)
   ├─ features/   ecrans          -> ne parlent JAMAIS a la base directement
   ├─ providers/  etat
   └─ services/   acces reseau    -> seuls a appeler Supabase
Supabase
   ├─ public.*    RPC appelables  <- seule surface exposee
   ├─ app.*       schema metier   -> NON expose a PostgREST
   └─ functions/  Edge Functions Deno
VPS LWS (academia_bobodo_backend)
   └─ worker de rendu, SORT vers Supabase en polling
```

Deux consequences qui se verifient a chaque fois :

- **Un ecran qui interroge Supabase directement est une erreur de couche.** La
  requete va dans `services/`.
- **Le worker n'a aucun port entrant.** Toute solution qui demande d'ouvrir un
  port est a rejeter — le pare-feu ne se touche pas (`CLAUDE.md` §3).

## Les valeurs couplees — modifier les DEUX cotes

Elles cassent en silence quand un seul cote change :

| Valeur | Les deux endroits | Ce qui casse |
|---|---|---|
| `INTRO_SEC = 3.2` | `whiteboard_page_builder.plan()` **et** `adelay` ffmpeg dans `whiteboard_render_worker.py` | voix decalee sur toute la video |
| `renders/<id>/preview.mp4` | `whiteboard_upload_renderer.preview_object_key` **et** `SmartWhiteboardRenderService._previewObjectKey` | apercu casse **en silence** (404 lu comme « pas pret ») |

Avant de changer une constante partagee : chercher son autre occurrence.

```bash
rg "INTRO_SEC|preview_object_key|_previewObjectKey" academia_app/lib academia_bobodo_backend
```

## Les contraintes non negociables

Elles viennent de l'experience, pas d'une preference. Toute proposition qui les
enfreint est a ecarter d'emblee :

1. **100 % CSS pour les animations.** `record_scene.js` n'avance que les
   animations CSS. GSAP ou Lottie pilote en JS casse la capture par tranches —
   donc la rapidite *et* l'apercu.
2. **Aucun calcul d'IA sur le VPS.** Ses 4 vCPU sont dedies a la capture. Toute
   IA passe par une Edge Function.
3. **Degradation gracieuse obligatoire.** L'etudiant doit toujours obtenir son
   cours, meme imparfait. **On nettoie, on ne rejette pas** — rejeter lui fait
   perdre ses credits *et* sa video.

Corollaire appris a ses depens : **la degradation gracieuse doit rester
bruyante.** Un repli silencieux a masque une panne reelle pendant deux essais
complets. Se rabattre, oui ; le taire, non.

## Le piege des moteurs abandonnes

`whiteboard_engine_remotion/`, `scene_template.html`, la chaine Pillow : ce sont
des **archives**. Le moteur de production est
`academia_bobodo_backend/whiteboard_vision/`. Modifier une archive donne
l'illusion d'avancer.

De meme : `academia_bobodo_backend/studio_visuel/` est **en sommeil depuis le
05/08/2026**. Lire `docs/STUDIO_VISUEL_ETAT_2026-08-05.md` avant d'y toucher.

## Ce qu'une relecture doit produire

Pas un avis. Un **choix, avec son cout** :

- l'option retenue et **pourquoi**, en une phrase ;
- ce qu'elle coute (fichiers touches, valeurs couplees a synchroniser) ;
- l'option ecartee et le motif ;
- ce qui reste **non etabli** et devrait etre mesure avant de s'engager.

L'agent `feature-dev:code-architect` peut produire le plan detaille une fois le
choix arrete.
