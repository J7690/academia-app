# Instructions Windsurf — Correctif mémoire de l'écriture manuscrite

**Date** : 25 juillet 2026
**Serveur** : `lws-nexiom` **UNIQUEMENT**. N'essaie pas Kamatera (accès refusé, acquis).

## Contexte — ce qui a échoué

Le rendu du cours complet « la continuité » (8 scènes, 1 647 caractères) a échoué après
12 minutes : `FATAL ERROR: Reached heap limit — JavaScript heap out of memory`, 6 092 Mo
consommés.

**Cause : l'implémentation de l'écriture manuscrite, pas le moteur.** Pour animer chaque
lettre, chaque caractère recevait son propre élément. Le cahier étant continu, les 1 647
caractères des huit scènes coexistaient en mémoire dès la première image. Sur le
storyboard de test (3 scènes, 300 caractères) cela passait ; sur un cours réel, non.

**Correctif — fenêtre d'écriture.** À un instant donné, seuls quelques caractères sont en
train d'apparaître, sous la « pointe du stylo ». Les autres sont soit déjà écrits, soit
pas encore écrits : ils n'ont aucun besoin d'être individualisés. On ne découpe donc plus
que la fenêtre active (12 caractères) ; le reste est rendu en deux blocs de texte simples.
Le texte à venir reste présent mais invisible, pour que la mise en page ne saute pas.

| | Avant | Après |
|---|---|---|
| Éléments animés simultanément | 1 647 | 87 |
| Réduction | — | **×19** |

Le rendu visuel est **strictement identique**.

## RÈGLES ABSOLUES

1. Agis **uniquement** sur `lws-nexiom`.
2. **Ne modifie AUCUN fichier du dépôt Git**, ne committe rien.
3. **Ne touche pas à Supabase**, n'ajoute aucun secret.
4. Ne supprime rien, ne désinstalle rien.
5. **Rapporte la sortie brute, sans interpréter**, et sans conclure quelle machine a fait
   quoi. Si un bloc ne renvoie rien, écris « aucune sortie ».
6. À la moindre erreur → **STOP + rapport** intégral.

---

## ÉTAPE 1 — Copier le fichier corrigé

```powershell
scp whiteboard_engine_remotion/src/blocks.tsx lws-nexiom:/opt/whiteboard-engine-remotion/src/
```

## ÉTAPE 2 — Types

```bash
ssh lws-nexiom "cd /opt/whiteboard-engine-remotion && npx tsc --noEmit 2>&1 | head -30; echo '--- fin tsc ---'"
```
Attendu : aucune erreur.

## ÉTAPE 3 — Rendu de test AVEC SURVEILLANCE MÉMOIRE

C'est l'étape décisive : on veut voir la mémoire ne PAS s'envoler.

```bash
ssh lws-nexiom "cd /opt/whiteboard-engine-remotion
echo '=== memoire avant ==='
free -m | head -2
echo '=== rendu ==='
/usr/bin/time -v timeout 1200 node render.mjs --storyboard src/sample_storyboard.json --out /tmp/manuscrit7.mp4 2>&1 | grep -iE 'Maximum resident|Elapsed|done|error|heap' | head -15
echo '=== memoire apres ==='
free -m | head -2
echo '=== ffprobe ==='
ffprobe -v error -show_entries stream=width,height -show_entries format=duration -of default=noprint_wrappers=1 /tmp/manuscrit7.mp4
echo '=== FIN ==='"
```

La ligne `Maximum resident set size` est la valeur qui nous intéresse : elle doit être
**très inférieure** aux 6 Go du crash précédent.

## ÉTAPE 4 — Redémarrer le worker

```bash
ssh lws-nexiom "systemctl restart whiteboard-worker && sleep 3 && systemctl is-active whiteboard-worker"
```

---

## RAPPORT À RENDRE

1. Étape 2 : sortie complète de `tsc`.
2. **Étape 3 : la sortie complète**, en particulier `Maximum resident set size` et le
   temps écoulé.
3. Étape 4 : `active` ou non.
4. Statut final.

Puis **arrête-toi**. Claude relancera le rendu du cours complet (8 scènes) via Supabase —
c'est ce rendu-là qui avait fait tomber le moteur, c'est lui qui prouvera le correctif.
