# Instructions Windsurf — Vision v2, étape 1 : filmer au lieu de photographier

**Date** : 25 juillet 2026
**Serveur** : `lws-nexiom` **UNIQUEMENT**.

## Contexte

Remotion est abandonné : mesuré à 4-5× le temps réel sur cette machine (12 à 20 minutes
pour 2 min 30 de vidéo), écriture manuscrite ou non. Le moteur **Vision**, lui, tourne à
1,0-1,4× le temps réel — mais il ne prend qu'**une capture d'écran par scène**, d'où un
diaporama.

**Étape 1 du remplacement** : enregistrer la page HTML *pendant* que les animations CSS se
jouent, au lieu de la photographier une fois figée. Le coût du rendu devient proportionnel
à la durée de la vidéo, et non plus au nombre d'images à reconstruire.

Deux fichiers nouveaux, **aucun fichier existant modifié** : le moteur actuel continue de
fonctionner exactement comme avant. Cette étape ne change encore rien pour les étudiants,
elle installe et valide la brique de base.

## Garde-fou intégré

Un enregistrement en temps réel peut perdre des images si la machine est chargée. Le code
compare donc la durée obtenue à la durée demandée (tolérance 8 %) et **échoue
explicitement** en cas d'écart, plutôt que de livrer une vidéo saccadée.

## RÈGLES ABSOLUES

1. Agis **uniquement** sur `lws-nexiom`.
2. **Ne modifie AUCUN fichier du dépôt Git**, ne committe rien.
3. **Ne touche pas à Supabase**, n'ajoute aucun secret.
4. Ne supprime rien, ne désinstalle rien — le moteur actuel doit continuer de tourner.
5. **Rapporte la sortie brute, sans interpréter.** Si un bloc ne renvoie rien, écris
   « aucune sortie ».
6. **Va jusqu'au bout des 4 étapes.**

---

## ÉTAPE 1 — Copier les deux nouveaux fichiers

```powershell
scp academia_bobodo_backend/whiteboard_vision/record_scene.js ^
    academia_bobodo_backend/whiteboard_vision/whiteboard_video_capture.py ^
    lws-nexiom:/opt/whiteboard-worker/vision_engine/
```

## ÉTAPE 2 — Vérifier que Playwright sait enregistrer

```bash
ssh lws-nexiom "cd /opt/whiteboard-worker/vision_engine
node --check record_scene.js && echo 'SYNTAXE JS OK'
python3 -c \"import ast; ast.parse(open('whiteboard_video_capture.py',encoding='utf-8').read()); print('SYNTAXE PY OK')\"
NODE_PATH=/opt/whiteboard-worker/node_modules node -e \"const {chromium}=require('playwright'); console.log('playwright present');\""
```

## ÉTAPE 3 — Test décisif : enregistrer une page animée de 10 secondes

On fabrique une page de test minimale avec une animation CSS continue, on la filme
10 secondes, et on vérifie que la vidéo dure bien 10 secondes (donc que les animations ont
tourné et qu'aucune image n'a été perdue).

```bash
ssh lws-nexiom "cd /opt/whiteboard-worker/vision_engine
cat > /tmp/anim_test.html <<'HTMLEOF'
<!doctype html><html><head><meta charset=utf-8><style>
  body{margin:0;background:#fffdf7;font-family:sans-serif;overflow:hidden}
  .bar{position:absolute;top:40%;left:0;height:80px;width:0;background:#1aa179}
  body.recording .bar{animation:grow 10s linear forwards}
  @keyframes grow{from{width:0}to{width:100%}}
  .txt{position:absolute;top:55%;width:100%;text-align:center;font-size:64px;color:#20303f}
</style></head><body>
  <div class=bar></div><div class=txt>Vision v2</div>
</body></html>
HTMLEOF
echo '=== enregistrement 10 s ==='
time NODE_PATH=/opt/whiteboard-worker/node_modules node record_scene.js /tmp/anim_test.html /tmp/anim_test.webm 10000 25
echo '=== duree reelle du fichier ==='
ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1 /tmp/anim_test.webm
echo '=== une image a mi-parcours (la barre doit etre a ~50%) ==='
ffmpeg -y -v error -ss 5 -i /tmp/anim_test.webm -frames:v 1 /tmp/anim_mid.png && ls -la /tmp/anim_mid.png
echo '=== FIN ==='"
```

Puis rapatrie l'image de contrôle :
```powershell
scp lws-nexiom:/tmp/anim_mid.png .
```

**Ce qu'on attend** :
- `duration` proche de **10 s** (entre 9,2 et 10,8) ;
- le temps `real` de la commande `time` proche de 10-20 s (pas 60) ;
- sur `anim_mid.png`, la barre verte remplit **environ la moitié** de la largeur —
  ce qui prouve que l'animation a réellement tourné pendant l'enregistrement.

Si la barre est vide ou pleine, l'animation n'a pas joué : **STOP + rapport**.

## ÉTAPE 4 — Aucun redémarrage nécessaire

Ces fichiers ne sont pas encore appelés par le worker. Ne redémarre rien.

---

## RAPPORT À RENDRE

1. Étape 2 : les trois lignes de vérification.
2. **Étape 3 : la sortie JSON de `record_scene.js`, le `time` réel, la durée `ffprobe`**,
   et confirmation que `anim_mid.png` est rapatriée.
3. Statut final.

Puis **arrête-toi**. Claude examine l'image et décide de l'étape 2 (cahier continu).
