# Studio visuel Academia — état à la mise en sommeil

> **05/08/2026.** Chantier **suspendu volontairement** pour renforcer les
> capacités avant reprise. Ce document est le point de reprise : il dit ce qui
> marche, ce qui ne marche pas, et ce qu'il ne faut surtout pas refaire.

---

## Rien ne facture

| | |
|---|---|
| Machines RunPod actives | **0** |
| `studio-orchestrateur` (pg_cron) | **désactivé** |
| `studio-reprise-orphelins` (pg_cron) | **désactivé** |
| `runpod-watchdog` (pg_cron) | **actif** — laissé exprès, c'est le filet |
| Travaux en attente | 0 |
| Dépense totale du chantier | **4,27 $** sur 15 locations |

Le veilleur reste actif à dessein : si une machine était créée par accident,
lui seul l'éteindra. Le désactiver serait retirer le seul garde-fou.

**Pour reprendre** : réactiver les deux tâches via
`cron.alter_job(jobid, active := TRUE)`.

---

## Ce qui fonctionne, mesuré

| Élément | Preuve |
|---|---|
| Veilleur (3 règles d'extinction) | a éteint 15 machines réelles |
| Création de pod sans exposer la clé | clé jamais lue, jamais transitée |
| Amorçage LWS → pod | Blender + scripts installés automatiquement |
| File de travaux, reprise des orphelins | travail rendu à la file après mort de machine |
| Narration OpenRouter | 4/4 scènes, durées **mesurées** imposées à l'image |
| Sound design synthétisé | nappe + ducking + accents, aucune licence |
| Génération d'images IA | **30 s, 24 Go VRAM, 0,004 $** par image |
| Archétype `flux` | seul vérifié visuellement comme réussi |

**Économie établie** : ~0,70 $ la capsule de 75 s, tout compris.
Écart mesuré entre 3D procédurale (0,50 $) et génération IA (0,65 $) : **1,3×**,
là où j'attendais 10×. La qualité IA est nettement supérieure.

---

## Ce qui ne fonctionne pas

**Les scènes `genere` rendent du NOIR.** Cause non établie — à mesurer, pas à
supposer. C'est le premier point à reprendre.

**Plusieurs archétypes non vérifiés visuellement** : `comparaison` sort noir,
`silhouette` n'a jamais tourné avec un vrai SVG en conditions réelles,
`titre`, `carte`, `chronologie`, `ondes` corrigés mais non revus après
correction.

**Phases 5 et 6 du chronogramme** non commencées : interface éditoriale,
image Docker.

---

## Les sept défauts de la semaine, et leur famille commune

Tous se ramènent à la même erreur : **conclure à partir d'une absence.**

| # | Défaut | Ce qui manquait |
|---|---|---|
| 1 | Émission volumétrique non masquée | rien dans le journal |
| 2 | Modificateur Wireframe sans faces | aucune erreur, objet invisible |
| 3 | Amorçage déclaré incomplet | sortie standard vide |
| 4 | Agent tué pendant un téléchargement | processus non listé |
| 5 | Correctif appliqué à moitié | erreur de nom, pas de syntaxe |
| 6 | Travail orphelin bloqué | absence de nouvelles lue comme « ça avance » |
| 7 | **Vidéo noire livrée comme « prête »** | contrôle qui ne regardait que la validité |

Le septième est le plus grave : les six premiers se cachaient derrière une
absence de message, celui-ci derrière un message de **succès**.

**Règle qui en découle, et qui doit survivre à ce chantier :**
> Ne jamais déduire un état de ce qu'on ne voit pas.
> Vérifier qu'un fichier est valide ne dit rien de ce qu'il contient.

---

## Trois erreurs de méthode à ne pas répéter

**Un correctif posé là où le défaut se voit n'est pas un correctif.** Les fins
de ligne CRLF ont coûté trois machines : j'ai d'abord corrigé un fichier, puis
ajouté un `.gitattributes` — qui ne régit que ce que git *stocke*. Le bon
correctif normalise **à la destination**, où l'on sait ce qui compte.

**Une machine au compteur n'est pas un atelier.** Sur un pod de 66 minutes :
12 minutes de calcul, le reste en attente pendant que je réfléchissais. Tout
préparer hors ligne, lancer une fois, récupérer, éteindre.

**La dégradation gracieuse doit rester bruyante.** Le repli « voix seule » a
masqué une panne réelle pendant deux essais complets.

---

## Décisions de licence, à ne pas rouvrir sans raison

| Sujet | Décision | Motif |
|---|---|---|
| Storyboard AI | **écarté** | GPL-3.0 ; contaminerait l'APK s'il y entrait |
| FLUX.1-dev | **écarté** | licence non commerciale |
| FLUX.1-schnell | dépôt **restreint** | exige un compte et l'acceptation de conditions |
| Modèle d'images retenu | miroir ouvert, Apache-2.0 | aucune barrière, usage commercial |
| WAN 2.2 (vidéo) | Apache-2.0 | seul modèle vidéo ouvert utilisable commercialement |
| Musique | **synthétisée** | aucun abonnement ; une musique générée par IA n'est protégée par aucun droit d'auteur |

---

## Facturation des trois plateformes

**HuggingFace : 0 $** — on télécharge des poids ouverts, aucun service consommé.
**Supabase : 0 $ marginal** — plan Pro déjà payé pour l'application ; le studio
ajoute ~36 000 appels de fonctions sur les 2 millions inclus.
**RunPod : seul coût variable** — 0,44 $/h, facturé à la seconde, extinction
automatique. Plafond automatique à 5 $/jour, jamais approché.

---

## Point de reprise

1. **Mesurer** pourquoi `genere` rend du noir. Ne rien supposer.
2. Revoir visuellement les dix archétypes, un rendu de contrôle par archétype.
3. Phase 5 — interface éditoriale. Phase 6 — image Docker (supprime 15 min
   d'installation par location).

Le chronogramme complet est dans `docs/CHRONOGRAMME_STUDIO_VISUEL.md`.
