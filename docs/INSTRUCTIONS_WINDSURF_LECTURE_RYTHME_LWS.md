# Instructions Windsurf — Lecture scientifique + rythme (LWS)

**Date** : 25 juillet 2026
**Serveur cible** : `lws-nexiom` (root@31.207.38.60) — **uniquement**. Ne touche pas à Kamatera.
**Nature** : copier 2 fichiers + redémarrer. Aucun secret, aucune installation.

## Contexte — retours du propriétaire sur la vidéo Vision

1. **Ordre de lecture non scientifique.** `\lim_{x \to a} f(x) = f(a)` était dit
   « la limite, quand x tend vers a, f de x... ». Un professeur dit l'objet d'abord :
   **« la limite de f de x quand x tend vers a est égale à f de a »**. Corrigé.
2. **Apostrophes prises pour des dérivées.** « tend vers 'a' » devenait « a prime », et
   « la fonction 'vise' » devenait « vise prime ». Corrigé (l'apostrophe de citation est
   désormais distinguée du symbole de dérivée).
3. **`+\infty` mal lu** : donnait « plus appartient à fty » (la règle `\in` mangeait le
   début de `\infty`). Corrigé.
4. **Pauses entre les blocs** — « on a l'impression que la vidéo s'arrête ». Cause
   trouvée : la durée de scène était `max(durée annoncée par l'IA, durée de la voix)`.
   L'IA annonce 20 s par scène ; une narration de 7 s laissait donc **13 secondes de
   silence sur une image fixe**. Désormais **la voix mène le rythme**, avec un plancher
   de lisibilité proportionnel au texte affiché et un plafond à la durée annoncée.

Effet mesuré du correctif de rythme (simulation sur le storyboard réel) :

| Cas | Durée annoncée | Voix | Avant | Après | Silence évité |
|---|---|---|---|---|---|
| Narration courte | 20,0 s | 7,0 s | 20,0 s | 7,3 s | **12,7 s** |
| Narration moyenne | 20,0 s | 12,0 s | 20,0 s | 12,3 s | **7,7 s** |
| Narration longue | 20,0 s | 22,0 s | 22,8 s | 22,4 s | 0,4 s |

Exemples de lecture après correctif (testés) :

| Écrit | Prononcé |
|---|---|
| `\lim_{x \to a} f(x) = f(a)` | « la limite de f de x quand x tend vers a égale f de a » |
| `\lim_{n \to +\infty} u_n = 0` | « la limite de u indice n quand n tend vers plus l'infini égale 0 » |
| `f''(x)` | « f seconde de x » |
| « la fonction 'vise' en 'a' » | inchangé (plus de « prime » parasite) |

## RÈGLES ABSOLUES

1. Agis **uniquement** sur `lws-nexiom`. Ne touche pas à Kamatera (185.167.97.144).
2. **Ne modifie AUCUN fichier du dépôt Git**, ne committe rien. Tu ne fais que copier.
3. **Ne touche pas à Supabase**, n'ajoute **aucun secret**, ne modifie pas le `.env`.
4. Ne bascule aucune IP applicative.
5. À la moindre erreur → **STOP + rapport**.

---

## ÉTAPE 1 — Copier les 2 fichiers (depuis la racine du dépôt `academia/`)

```powershell
scp academia_bobodo_backend/math_speech_fr.py lws-nexiom:/opt/whiteboard-worker/
scp academia_bobodo_backend/whiteboard_narration.py lws-nexiom:/opt/whiteboard-worker/
```

## ÉTAPE 2 — Vérifier la lecture

```bash
ssh lws-nexiom "cd /opt/whiteboard-worker && python3 - <<'PYEOF'
from math_speech_fr import verbalize
for t in [
    r'\lim_{x \to a} f(x) = f(a)',
    r'\lim_{n \to +\infty} u_n = 0',
    r'\int_{a}^{b} f(x) dx',
    r\"On note f''(x) la derivee seconde\",
    \"En clair : ce que la fonction 'vise' en 'a' est ce qu'elle 'atteint' en 'a'.\",
]:
    print(t, '\n  ->', verbalize(t))
PYEOF"
```

Attendu, dans cet ordre :
- `la limite de f de x quand x tend vers a égale f de a`
- `la limite de u indice n quand n tend vers plus l'infini égale 0`
- `l'intégrale, de a à b, de f de x d x`
- `On note f seconde de x la derivee seconde`
- la dernière phrase **inchangée** (aucun « prime » ajouté)

Si une ligne diffère → STOP + rapport.

## ÉTAPE 3 — Vérifier le nouveau réglage de rythme

```bash
ssh lws-nexiom "cd /opt/whiteboard-worker
grep -n 'SCENE_PADDING_SEC =' whiteboard_narration.py
grep -n 'readable_floor' whiteboard_narration.py
python3 -c \"import whiteboard_narration as n; print('padding =', n.SCENE_PADDING_SEC)\""
```
Attendu : `padding = 0.35` et la présence de `readable_floor`.

## ÉTAPE 4 — Redémarrer le worker

```bash
ssh lws-nexiom "systemctl restart whiteboard-worker && sleep 3 && systemctl is-active whiteboard-worker"
```

---

## RAPPORT À RENDRE

Colle la sortie brute des étapes 2, 3 et 4. Précise le statut final (« terminé sans
erreur » ou « arrêté à l'étape X » avec l'erreur exacte). Puis **arrête-toi** : Claude
relance un rendu réel sur les deux moteurs pour faire écouter le résultat.
