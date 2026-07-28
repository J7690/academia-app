# Instructions Windsurf — Révélation par mots (dernière optimisation avant arbitrage)

**Date** : 25 juillet 2026
**Serveur** : `lws-nexiom` **UNIQUEMENT**.

## Contexte — le problème est la VITESSE, plus la mémoire

Le découpage par tranches (déjà déployé) a résolu le crash mémoire : le rendu du cours
complet a dépassé les 18 minutes sans échouer, alors que les deux tentatives précédentes
mouraient à 12 minutes sur `heap out of memory`. **Ce point est acquis.**

Reste la lenteur, et les chiffres désignent la cause :

| | Durée vidéo | Temps de rendu |
|---|---|---|
| Ce cours, **avant** l'écriture manuscrite | 2 min 35 | **160 s** |
| Ce cours, **avec** écriture lettre par lettre | 2 min 35 | **> 18 min** |

Animer chaque lettre force le navigateur à recalculer la mise en page à chaque image.

**Correctif : révélation MOT PAR MOT.** À 20 caractères/seconde, un mot dure environ un
quart de seconde : l'œil perçoit toujours une main qui avance, mais le nombre d'éléments
animés est divisé par près de cinq (55 caractères → 12 mots sur une phrase type).

Projection : de plus de 18 minutes à **environ 3 minutes**.

## Critère d'arbitrage (annoncé au propriétaire)

Si le rendu du cours complet ne descend pas nettement — objectif sous 4-5 minutes — alors
le coût est structurel et le choix de Remotion sera abandonné au profit d'un moteur
Canvas (Revideo / Motion Canvas), qui ne recalcule pas de mise en page. **C'est le dernier
essai avant cet arbitrage.**

## RÈGLES ABSOLUES

1. Agis **uniquement** sur `lws-nexiom`.
2. **Ne modifie AUCUN fichier du dépôt Git**, ne committe rien.
3. **Ne touche pas à Supabase**, n'ajoute aucun secret.
4. Ne supprime rien, ne désinstalle rien.
5. **Rapporte la sortie brute, sans interpréter.** Si un bloc ne renvoie rien, écris
   « aucune sortie ».
6. **Va jusqu'au bout des 3 étapes** : elles sont courtes. Si une commande semble longue,
   laisse-la finir plutôt que de l'interrompre.

---

## ÉTAPE 1 — Copier le fichier

```powershell
scp whiteboard_engine_remotion/src/blocks.tsx lws-nexiom:/opt/whiteboard-engine-remotion/src/
```

## ÉTAPE 2 — Types

```bash
ssh lws-nexiom "cd /opt/whiteboard-engine-remotion && npx tsc --noEmit 2>&1 | head -30; echo '--- fin tsc ---'"
```
Attendu : aucune erreur.

## ÉTAPE 3 — Test court chronométré (référence : 103 s en lettre par lettre)

```bash
ssh lws-nexiom "cd /opt/whiteboard-engine-remotion
start=\$(date +%s)
timeout 900 node render.mjs --storyboard src/sample_storyboard.json --out /tmp/mots.mp4 2>&1 | grep -iE 'tranche|done|error|heap' | head -12
end=\$(date +%s)
echo \"TEMPS DE RENDU : \$((end-start)) s\"
ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1 /tmp/mots.mp4
echo '=== FIN ==='"
```

**La ligne `TEMPS DE RENDU` est le chiffre décisif.** Référence à battre : 103 s pour la
même vidéo de 29,5 s en lettre par lettre. On attend nettement moins.

---

## RAPPORT À RENDRE

1. Étape 2 : sortie de `tsc`.
2. **Étape 3 : le `TEMPS DE RENDU` et la durée `ffprobe`** — ce sont les deux seuls
   chiffres qui comptent.
3. Statut final.

Puis **arrête-toi**. Claude relance le cours complet et compare aux 18 minutes actuelles.
