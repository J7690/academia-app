# Instructions Windsurf — Caméra + annotations visibles (Remotion, LWS) — v5

**Date** : 25 juillet 2026
**Serveur cible** : `lws-nexiom` (root@31.207.38.60) — **uniquement**. Ne touche pas à Kamatera.
**Nature** : copier 3 fichiers + rendu de test + images. Aucun secret, aucune installation.

## Contexte — retours du propriétaire sur le rendu complet

1. « Je ne vois pas d'effet animé : souligner, encadrer, encercler. »
2. « Il faut tout rendre à la manuscrite. » (les titres restaient en police machine)
3. Demande d'un travail de caméra « précis, efficace et stylé ».

## Ce qui a été corrigé, et pourquoi les annotations étaient invisibles

**Cause trouvée** : les blocs apparaissaient à intervalles **réguliers** dans la scène,
sans lien avec le temps réel d'écriture. Une annotation, déclenchée à la fin de
l'écriture d'un bloc, tombait donc souvent **après que la caméra soit déjà partie
ailleurs** — le geste avait lieu hors champ. Sur la scène « correction » du storyboard
réel, il fallait 23,8 s pour tout écrire et annoter, alors que la scène n'en durait que
20 : les deux dernières annotations n'avaient littéralement pas le temps d'exister.

**Correctif — séquencement réel** : chaque bloc s'écrit, **puis la caméra s'immobilise**
pendant l'annotation, **puis** on avance au bloc suivant. La durée de la scène est
maintenant calculée à partir de ce plan (écriture + annotation + respiration), et non
plus d'une valeur fixe.

**Correctif — géométrie des annotations** : elles étaient positionnées en pourcentage de
la hauteur du bloc. Sur un bloc long, le souligné partait très bas et le cercle devenait
un ovale démesuré. Elles sont désormais en **pixels** : le geste garde la même taille
quel que soit le bloc, comme un vrai stylo. Traits légèrement épaissis pour être lisibles
en vidéo verticale.

**Travail de caméra** (d'après les bonnes pratiques de montage) :
- **Accélération/décélération progressive** (`Easing.inOut(cubic)`) au lieu d'un
  défilement linéaire : le linéaire fait « machine », l'adouci imite un opérateur.
- **La caméra se pose avant qu'on ait à lire, et ne bouge plus pendant qu'on interprète
  un détail** — d'où l'immobilité totale pendant écriture + annotation.

**Tout en manuscrit** : les titres passent aussi en police Caveat (64 px).

## RÈGLES ABSOLUES

1. Agis **uniquement** sur `lws-nexiom`. Ne touche pas à Kamatera (185.167.97.144).
2. **Ne modifie AUCUN fichier du dépôt Git**, ne committe rien.
3. **Ne touche pas à Supabase**, n'ajoute aucun secret.
4. **Ne désinstalle PAS le moteur Vision**, **ne bascule pas l'app**.
5. **N'installe PAS `@remotion/google-fonts`**.
6. À la moindre erreur → **STOP + rapport** intégral.

---

## ÉTAPE 1 — Copier les 3 fichiers

```powershell
scp whiteboard_engine_remotion/src/SmartWhiteboard.tsx ^
    whiteboard_engine_remotion/src/Annotation.tsx ^
    whiteboard_engine_remotion/src/blocks.tsx ^
    lws-nexiom:/opt/whiteboard-engine-remotion/src/
```

## ÉTAPE 2 — Types

```bash
ssh lws-nexiom "cd /opt/whiteboard-engine-remotion && npx tsc --noEmit 2>&1 | head -30; echo '--- fin tsc ---'"
```
Attendu : aucune erreur. Sinon → copie tout et **arrête-toi**.

## ÉTAPE 3 — Rendu de test

```bash
ssh lws-nexiom "cd /opt/whiteboard-engine-remotion
timeout 900 node render.mjs --storyboard src/sample_storyboard.json --out /tmp/manuscrit5.mp4 2>&1 | tail -15
ffprobe -v error -show_entries stream=width,height -show_entries format=duration -of default=noprint_wrappers=1 /tmp/manuscrit5.mp4"
```
⚠️ **La durée va AUGMENTER** par rapport aux 28 s précédentes : c'est normal et voulu —
les scènes durent maintenant le temps réel d'écrire *et* d'annoter. Note la durée exacte.

## ÉTAPE 4 — Images de contrôle (nombreuses, pour attraper les annotations)

Les annotations durent ~2,7 s chacune. On échantillonne donc **toutes les 2 secondes**
sur les 40 premières secondes, pour être sûr d'en capter au moins une en cours de tracé.

```bash
ssh lws-nexiom "cd /tmp
rm -f /tmp/v5_frame_*.png
DUR=\$(ffprobe -v error -show_entries format=duration -of csv=p=0 /tmp/manuscrit5.mp4 | cut -d. -f1)
echo \"duree = \$DUR s\"
for t in \$(seq 2 2 \$((DUR-1))); do ffmpeg -y -v error -ss \$t -i /tmp/manuscrit5.mp4 -frames:v 1 /tmp/v5_frame_\$t.png; done
ls /tmp/v5_frame_*.png | wc -l"
```
Puis rapatrie **tout** à la racine du dépôt :
```powershell
scp lws-nexiom:/tmp/v5_frame_*.png .
```

## ÉTAPE 5 — Redémarrer le worker

```bash
ssh lws-nexiom "systemctl restart whiteboard-worker && sleep 3 && systemctl is-active whiteboard-worker"
```

---

## RAPPORT À RENDRE

1. Étape 2 : sortie complète de `tsc`.
2. Étape 3 : sortie `ffprobe` (**la nouvelle durée**).
3. Étape 4 : nombre de PNG créés + confirmation qu'ils sont rapatriés à la racine.
4. Étape 5 : `active` ou non.
5. Statut final.

Puis **arrête-toi**. Claude parcourt les images pour vérifier qu'on voit bien un
souligné et un encerclage en cours de tracé, et que le titre est manuscrit.
