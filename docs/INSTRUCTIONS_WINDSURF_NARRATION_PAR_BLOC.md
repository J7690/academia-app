# Instructions Windsurf — Narration par bloc : ce qui s'écrit est ce qui se dit

**Date** : 25 juillet 2026
**Serveur** : `lws-nexiom` **UNIQUEMENT**.

## Ce que dit la recherche, et ce qu'on en fait

Le défaut signalé — « l'audio et l'écriture ne disent pas la même chose au même moment »
— porte un nom en pédagogie : c'est une violation du **principe de contiguïté temporelle**
(Mayer). On apprend plus profondément quand le commentaire et le visuel correspondant
sont présentés **simultanément** plutôt que successivement. Formulé autrement par
3Blue1Brown : chaque élément visuel doit dire la même chose que la narration, au lieu de
rivaliser avec elle pour l'attention.

Sur le **rythme**, la recherche situe la compréhension optimale entre **100 et 130 mots
par minute** pour du contenu technique — contre environ 150 en parole courante, avec un
déclin marqué au-delà de 200. On retient **115 mots/minute** : un cours doit pouvoir être
suivi *et* retenu, pas seulement entendu.

## Le changement

Jusqu'ici : **une narration par scène**, alors qu'une scène contient trois ou quatre
blocs écrits successivement. La voix commentait l'ensemble pendant que des contenus
différents apparaissaient.

Désormais : **un segment de voix par bloc**, et la durée d'écriture d'un bloc **EST** la
durée de son segment. La synchronisation n'est plus approchée après coup, elle est
**exacte par construction** — vérifié : écart de 0,000 s.

Un repli est prévu : si la narration par bloc échoue, on retombe sur l'ancienne méthode
plutôt que de livrer une vidéo muette.

## RÈGLES ABSOLUES

1. Agis **uniquement** sur `lws-nexiom`.
2. **Ne modifie AUCUN fichier du dépôt Git**, ne committe rien.
3. **Ne touche pas à Supabase**, ne supprime rien.
4. **Rapporte la sortie brute, sans interpréter.**

---

## ÉTAPE 1 — Copier les trois fichiers

```powershell
scp academia_bobodo_backend/whiteboard_narration.py lws-nexiom:/opt/whiteboard-worker/
scp academia_bobodo_backend/whiteboard_render_worker.py lws-nexiom:/opt/whiteboard-worker/
scp academia_bobodo_backend/whiteboard_vision/whiteboard_page_builder.py lws-nexiom:/opt/whiteboard-worker/vision_engine/
```

Empreintes attendues :
```
c2b892cf223a9d4384ebfca6067ce8d8  whiteboard_narration.py
8207c920f031c50296e574fc03ee21fc  whiteboard_render_worker.py
6ac78c31e85547ae212ae1c3a053ff23  whiteboard_page_builder.py
```

## ÉTAPE 2 — Vérifier

```bash
ssh lws-nexiom "cd /opt/whiteboard-worker
export NODE_PATH=/opt/whiteboard-worker/node_modules
md5sum whiteboard_narration.py whiteboard_render_worker.py vision_engine/whiteboard_page_builder.py
python3 -c \"import ast; ast.parse(open('whiteboard_render_worker.py',encoding='utf-8').read()); print('WORKER OK')\"
python3 -c \"
import whiteboard_narration as n
print('NARRATION PAR BLOC :', hasattr(n, 'build_block_narration'))
print('RYTHME ACADEMIQUE :', n.ACADEMIC_WPM, 'mots/min')
print('TTS DISPONIBLE :', n.is_available())
\""
```

Attendu : `NARRATION PAR BLOC : True`, `RYTHME ACADEMIQUE : 115`, `TTS DISPONIBLE : True`.
Si le TTS est indisponible → **STOP + rapport**.

## ÉTAPE 3 — Redémarrer le worker

```bash
ssh lws-nexiom "systemctl restart whiteboard-worker && sleep 4 && systemctl is-active whiteboard-worker
journalctl -u whiteboard-worker -n 20 --no-pager | grep -v 'Found 0 queued' | grep -v httpx | tail -8"
```

Attendu : `active`, aucun `Traceback`.

---

## RAPPORT À RENDRE

1. Étape 2 : les empreintes et les trois lignes de vérification.
2. Étape 3 : `active` et le journal.
3. Statut final.

Puis **arrête-toi**. Claude lance un rendu réel et vérifie dans le journal la ligne
`Narration PAR BLOC prete (N scenes, M blocs, X s)` — c'est elle qui confirmera que
chaque bloc a bien sa propre voix.
