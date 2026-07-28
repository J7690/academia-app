# Instructions Windsurf — Déployer la lecture vocale des mathématiques sur LWS

**Date** : 25 juillet 2026
**Serveur cible** : `lws-nexiom` (root@31.207.38.60) — **uniquement**. Ne touche pas à Kamatera.
**Nature** : copier 3 fichiers (dont 1 nouveau) + redémarrer. Aucun secret, aucune install.

## Contexte

La voix fonctionne, mais elle ne sait pas lire les mathématiques : `f(x)`, `\int_a^b`,
`\lim_{x \to 1^-}`, les lettres grecques... Claude a écrit un module de **verbalisation
française des maths** (`math_speech_fr.py`) et l'a branché sur les deux moteurs.

Exemples de conversion (testés) :

| Écrit | Prononcé |
|---|---|
| `f(x) = x^2 + 1` | « f de x égale x au carré plus 1 » |
| `\int_{a}^{b} f(x) dx` | « l'intégrale, de a à b, de f de x d x » |
| `\lim_{x \to 1^-} (x+1)` | « la limite, quand x tend vers 1 par valeurs inférieures, (x plus 1) » |
| `\theta \approx \frac{\pi}{4}` | « thêta environ égal à pi sur 4 » |
| `f'(x)` | « f prime de x » |

Second correctif inclus : le moteur **Vision** ignorait le champ `narration` rédigé par
l'IA (français naturel) et récitait le contenu brut des blocs, LaTeX compris. Il utilise
désormais `narration` en priorité — comme le fait déjà le moteur Remotion.

## RÈGLES ABSOLUES

1. Agis **uniquement** sur `lws-nexiom`. Ne touche pas à Kamatera (185.167.97.144).
2. **Ne modifie AUCUN fichier du dépôt Git**, ne committe rien. Tu ne fais que copier.
3. **Ne touche pas à Supabase**, n'ajoute **aucun secret**, ne modifie pas le `.env`.
4. Ne bascule aucune IP applicative.
5. À la moindre erreur → **STOP + rapport**.

---

## ÉTAPE 1 — Copier les fichiers (depuis la racine du dépôt `academia/`)

```powershell
scp academia_bobodo_backend/math_speech_fr.py lws-nexiom:/opt/whiteboard-worker/
scp academia_bobodo_backend/whiteboard_narration.py lws-nexiom:/opt/whiteboard-worker/
scp whiteboard_engine_remotion/narrate.py lws-nexiom:/opt/whiteboard-engine-remotion/
```

> `math_speech_fr.py` est **nouveau** et se place dans `/opt/whiteboard-worker/`.
> Le moteur Remotion l'importe depuis là (chemin ajouté automatiquement dans `narrate.py`).

## ÉTAPE 2 — Vérifier que la verbalisation fonctionne des deux côtés

```bash
ssh lws-nexiom "cd /opt/whiteboard-worker
echo '=== 2a. Module seul ==='
python3 math_speech_fr.py

echo
echo '=== 2b. Import depuis le worker (moteur Vision) ==='
python3 -c \"import whiteboard_narration as n; print('MATH_SPEECH actif :', n._HAS_MATH_SPEECH); print(n._clean_latex(r'\\\\int_{a}^{b} f(x) dx'))\"

echo
echo '=== 2c. Import depuis le moteur Remotion ==='
cd /opt/whiteboard-engine-remotion
python3 -c \"import narrate; print(narrate._speakable(r'La derivee f\\'(x) et \\\\lim_{x \\\\to 0} f(x)'))\""
```

Attendu :
- `2a` : le banc d'essai affiche les 8 exemples convertis en français.
- `2b` : `MATH_SPEECH actif : True`, puis `l'intégrale, de a à b, de f de x d x`.
- `2c` : `La derivee f prime de x et la limite, quand x tend vers 0, f de x`.

Si `2b` affiche `False` → le fichier `math_speech_fr.py` n'est pas au bon endroit → STOP + rapport.

## ÉTAPE 3 — Redémarrer le worker

```bash
ssh lws-nexiom "systemctl restart whiteboard-worker && sleep 3 && systemctl is-active whiteboard-worker"
```

---

## RAPPORT À RENDRE

Colle la sortie brute des étapes 2 et 3, en particulier :
1. `2a` : les exemples convertis (c'est ce qui permet à Claude de juger la qualité).
2. `2b` : la valeur de `MATH_SPEECH actif` (doit être `True`).
3. `2c` : la phrase convertie côté Remotion.
4. Étape 3 : `active` ou non.
5. Statut final : « terminé sans erreur » ou « arrêté à l'étape X » avec l'erreur exacte.

Puis **arrête-toi**. Claude relance un rendu réel sur chaque moteur et fait écouter le
résultat au propriétaire.
