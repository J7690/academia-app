# Instructions Windsurf — Rythme académique et prononciation française

**Date** : 26 juillet 2026
**Serveur** : `lws-nexiom` **UNIQUEMENT**.

## Trois corrections, après recherche

### 1. Le rythme — la cause n'était pas où je l'avais cherchée

J'avais ralenti la vitesse d'**écriture**. Or depuis la synchronisation par bloc,
l'écriture ne fait que **suivre la voix** : c'est donc la voix qui imposait le rythme, et
elle parlait à sa vitesse naturelle (~150 mots/minute).

La recherche situe la meilleure rétention entre **100 et 135 mots par minute** pour du
contenu pédagogique — la rétention augmente à mesure que le rythme ralentit.

La synthèse vocale reçoit désormais une consigne de vitesse : **0,80×**, soit environ
**120 mots/minute**. Réglable sans redéploiement via le secret `OPENROUTER_TTS_SPEED`.

| Vitesse | Rythme obtenu |
|---|---|
| 1,00× (avant) | ~150 mots/min |
| **0,80× (retenu)** | **~120 mots/min** |
| 0,75× | ~112 mots/min |

### 2. Les pauses entre les idées

Respiration entre deux blocs portée de **0,6 à 1,1 seconde**. Les pauses marquent les
transitions entre idées et réduisent la charge cognitive — les blocs s'enchaînaient sans
laisser le temps de digérer. Sur un cours de 25 blocs, cela ajoute 12 secondes de
respiration.

### 3. La prononciation française

| Écrit | Avant | Après |
|---|---|---|
| `0.6` | « zéro **point** six » | « zéro **virgule** six » |
| `3,14159` | mal découpé | « 3 virgule 1 4 1 5 9 » |
| `1.` en début de ligne | « un » | « **étape un**, » |
| `2.` | « deux » | « **étape deux**, » |
| `- ` (puce) | lu ou ignoré au hasard | simple respiration |

En français, le séparateur décimal **se prononce** « virgule » : c'est une règle, pas une
préférence. Et un professeur annonce ses étapes, il ne récite pas des nombres nus.

## RÈGLES ABSOLUES

1. Agis **uniquement** sur `lws-nexiom`.
2. **Ne modifie AUCUN fichier du dépôt Git**, ne committe rien.
3. **Ne touche pas à Supabase** (l'Edge Function a déjà été redéployée par Claude).
4. **Rapporte la sortie brute, sans interpréter.**

---

## ÉTAPE 1 — Copier les deux fichiers

```powershell
scp academia_bobodo_backend/whiteboard_narration.py lws-nexiom:/opt/whiteboard-worker/
scp academia_bobodo_backend/math_speech_fr.py lws-nexiom:/opt/whiteboard-worker/
```

Empreintes attendues :
```
a6c544a4a119d987edc1c613336d692f  whiteboard_narration.py
b8f23c2b8fa1fcdf034cf4d9674fcfa9  math_speech_fr.py
```

## ÉTAPE 2 — Vérifier la prononciation

```bash
ssh lws-nexiom "cd /opt/whiteboard-worker
md5sum whiteboard_narration.py math_speech_fr.py
python3 -c \"
from math_speech_fr import verbalize
for t in ['La respiration est de 0.6 seconde.',
          'Pi vaut environ 3,14159.',
          '1. f(1) existe ? Oui, f(1) = 3.',
          '2. La limite de f(x) quand x tend vers 1 existe ?',
          '- Limite a gauche : la valeur tend vers 2.']:
    print(' ', t)
    print('   ->', verbalize(t))
\"
python3 -c \"
import whiteboard_narration as n
print('VITESSE VOIX :', n.TTS_SPEED)
print('RESPIRATION  :', n.BLOCK_BREATH_SEC, 's')
\""
```

Attendu : `zéro virgule six`, `3 virgule 1 4 1 5 9`, `étape un,`, `étape deux,`,
puis `VITESSE VOIX : 0.8` et `RESPIRATION : 1.1 s`.

## ÉTAPE 3 — Redémarrer

```bash
ssh lws-nexiom "systemctl restart whiteboard-worker && sleep 4 && systemctl is-active whiteboard-worker"
```

---

## RAPPORT À RENDRE

1. Étape 2 : les empreintes, les cinq phrases converties, la vitesse et la respiration.
2. Étape 3 : `active`.
3. Statut final.

Puis **arrête-toi**. Claude relance un rendu : la vidéo sera plus longue, c'est voulu —
la longueur n'est pas un problème, la compréhension oui.
