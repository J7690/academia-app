# ÉTAT — le document qui fait foi

> **Ce fichier prime sur tous les autres.** `docs/` en contient 219 ; dix
> s'annoncent comme « état », « plan » ou « chronogramme », et aucun ne dit
> lequel est vrai aujourd'hui. Celui-ci le dit. Les autres sont des **archives
> datées** : on les lit pour comprendre *pourquoi*, jamais pour savoir *où on en est*.
>
> **Relevé le : 13/08/2026.** Toute ligne non datée est réputée périmée.
> Toute affirmation ici doit être **mesurée**, jamais supposée (cf. §7).

---

## 1. Où on en est, en une phrase

Le **Studio visuel 3D** fabrique des capsules dont la forme est **composée par
l'IA** (verbes + coordonnées) et non plus choisie dans un catalogue. La chaîne
va bout en bout jusqu'au rendu ; **elle échoue sur le GPU RunPod**, et c'est le
seul verrou ouvert.

## 2. La chaîne, et qui exécute quoi

```
Étudiant (Flutter, APK du 13/08 18h18)
  └─> Edge Function `whiteboard-generate-storyboard`   ← Supabase, déployée 13/08
       │   engine=studio → capsule COMPOSÉE (intention + gestes)
       └─> app.studio_jobs (statut a_preparer)
            ├─ déclencheur `studio_reveiller_sur_file` → `runpod-control` (créer)
            └─> LWS `studio-preparateur.service`        ← /opt/studio_visuel/
                 traduit si besoin, SYNTHÉTISE LA VOIX, cale les durées
                 └─> statut queued
                      └─> Pod RunPod (image academia0/academia-studio:1.2.0)
                           entree.sh → sonde → worker_pod.py → executer_capsule.py
                           → Blender EEVEE → images → montage → Storage
```

**Trois machines, trois codes différents — c'est la source des confusions :**

| Où | Quel code | Comment on le met à jour | Vérifié le |
|---|---|---|---|
| Supabase | Edge Functions | `supabase functions deploy` (CLI locale, projet lié) | 13/08 |
| LWS `31.207.38.60` | `/opt/studio_visuel/*.py` | `scp` puis `systemctl restart studio-preparateur` | 13/08 |
| Pod RunPod | **dans l'image Docker** | ⚠️ reconstruction — **voir §5** | 12/08 |

## 3. Ce qui est MESURÉ comme fonctionnant

- **Choix de l'étudiant transmis** — `engine: "studio"` arrive au serveur (12/08).
- **Composition par l'IA** — « Poussée d'Archimède », sujet jamais vu : 5 scènes,
  5 intentions distinctes (objet → flux → processus → comparaison → échelle),
  verbes `revolutionner`/`sculpter`/`extruder`, **0 correction**.
- **La composition survit à toute la chaîne** — manifeste préparé : 5 scènes sur 5
  portant leurs `gestes`, archétype vide (13/08, travail `afd29a95`).
- **Réveil événementiel** — machine créée **1,5 s** après l'insertion du travail.
- **Arrêt automatique** — machine coupée seule après 12 min de silence (`agent_muet`).
- **Rendu et style** — sur LWS *sans GPU*, Blender sort des PNG : filaire bleu
  émissif sur noir, conforme à la référence. Image témoin : `s1_0001.png`.
- **Dépense totale du chantier** : **0,19 $** (deux machines, 3,6 et 12,0 min).

## 4. Ce qui est CASSÉ, et ce qu'on en sait

### 4.1 Le rendu GPU — VERROU PRINCIPAL
Sur le pod : `aucune_image_produite`. Sur LWS sans GPU : des images sortent.
**Donc le défaut est dans le chemin GPU** (hypothèse : contexte EGL d'EEVEE),
**non établie** faute de trace.
**Pourquoi on ne sait pas** : le pod n'a ni sshd ni expédition de journaux ; la
sortie standard meurt avec la machine. Le correctif qui fait remonter la cause
dans `studio_jobs.erreur` est **écrit mais pas livré** (il est dans l'image).

### 4.2 Le cadrage — corrigé, NON VÉRIFIÉ
La caméra était à distance **constante** par intention. À 9 unités, une focale
50 mm sur cadre 9:16 ne montre que 3,6 unités de large ; l'IA avait écrit un
bécher de 6. L'image ne contenait que la paroi. Remplacé par
`academia3d.cadrer_sur()`, qui **mesure** la boîte englobante. **Jamais rendu.**

### 4.3 Ce que l'audit croisé a laissé en suspens
Audit des 6 verbes coupé par une limite de session : `revolutionner` et
`sculpter` conclus et corrigés ; **`silhouetter`, `extruder`, `napper`, `ecrire`
analysés mais non réfutés** — donc *non conclus*, pas *sains*.

## 5. Le verrou d'architecture : le moteur vit dans l'image

Corriger une ligne de Python du moteur exigeait : un poste allumé, Docker
démarré, 4,5 Go reconstruits, une publication. **Décision du 13/08 : on sépare.**

- l'**image** = Blender, Chromium, Node, ffmpeg, EGL — change quelques fois par an
- le **moteur** = les `.py` — tiré au démarrage depuis **Supabase Storage**

Écrit, non livré : `image/entree.sh` (tirage), `image/publier_moteur.sh` (dépôt).
**Reconstruction sur LWS**, qui a Docker 29.6.2 + buildx + 117 Go — **plus jamais
sur le poste de Jocelyn**.

## 6. Prochain pas, dans l'ordre

1. `docker login` **sur LWS** — par Jocelyn (1 fois). Sans lui, rien ne se publie.
2. Construire et publier l'image **1.3.0** depuis LWS.
3. Basculer `app.studio_config` (`image_pod`, `version_moteur`).
4. Relancer « Poussée d'Archimède » — la capsule est en base, **0 $ de génération**.
5. Lire la cause GPU dans `studio_jobs.erreur`, désormais remontée.
6. Vérifier le cadrage sur une image réelle.

## 7. Les règles qui ne se négocient pas

1. **Ne jamais déduire un état de ce qu'on ne voit pas.** Le 12/08, l'image du
   pod n'a pas pu être inspectée (Docker éteint) : ça a été **dit**, pas supposé.
2. **100 % CSS** pour les animations du Smart Whiteboard (`record_scene.js`).
3. **Aucun calcul d'IA sur le VPS.**
4. **Dégradation gracieuse** : on nettoie, on ne rejette pas.
5. **Interdit sans accord explicite de Jocelyn** : écriture en base de
   production, déploiement d'Edge Function, migration distante, `git commit`,
   `git push`, publication Facebook ou Canva.
6. **Ne jamais lire ni committer** `~/.ssh/id_ed25519`. **Ne pas toucher au pare-feu.**

## 8. Dettes ouvertes

| Dette | Depuis | Conséquence |
|---|---|---|
| **63 fichiers non commités**, rien depuis `a8a0b2f` | 07/08 | l'histoire ne garde **rien** de ce chantier ; une régression serait indiscernable |
| Deux jetons Docker Hub collés en conversation | 12/08 | **à révoquer** |
| `CLAUDE.md` annonce un chantier abandonné | 28/07 | corrigé le 13/08 : il pointe désormais ici |

---

## Comment on tient ce fichier à jour

- **Au début de chaque intervention** : le hook `etat_projet.py` en affiche
  l'essentiel. On le lit avant d'agir.
- **À chaque acte significatif** (déploiement, migration, image, mesure,
  décision) : une ligne dans `docs/JOURNAL_INTERVENTIONS.md`.
- **À la fin de chaque intervention** : §1, §3, §4 et §6 sont remis à jour.
  Le hook `fin_intervention.py` le rappelle si le dépôt a bougé sans que ce
  fichier ait été touché.
