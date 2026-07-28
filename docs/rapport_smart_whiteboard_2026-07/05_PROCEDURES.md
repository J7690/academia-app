# 05 — Procédures : déployer, valider, diagnostiquer

> Toutes les commandes sont données depuis la racine `c:\Users\fasop\AndroidStudioProjects\academia`
> en PowerShell. Alias SSH : `lws-nexiom`.

---

## 1. Déployer un fichier du moteur sur le VPS

```powershell
# Moteur de rendu (dossier vision_engine)
scp academia_bobodo_backend\whiteboard_vision\<fichier>.py root@31.207.38.60:/opt/whiteboard-worker/vision_engine/

# Worker et modules de narration (racine du worker)
scp academia_bobodo_backend\<fichier>.py root@31.207.38.60:/opt/whiteboard-worker/
```

Puis redémarrer le service :

```powershell
ssh lws-nexiom "systemctl restart whiteboard-worker && systemctl is-active whiteboard-worker"
```

Réponse attendue : `active`.

> ⚠️ Le redémarrage du service est une action à ne faire qu'avec l'accord explicite de
> l'utilisateur : un job en cours de rendu serait interrompu.

---

## 2. Déployer l'Edge Function du storyboard

Depuis la racine `academia/` (et **non** depuis `academia_app/`) :

```powershell
supabase functions deploy whiteboard-generate-storyboard --use-api
```

Projet : `thevdfcwlcqzdoybfvgs`.

---

## 3. Validation visuelle de la mise en scène

C'est la procédure qui a servi à valider la vague F.

### 3.1 Générer la page HTML de test sur le VPS

Le storyboard de test au format v3 est déjà sur le serveur :
`/opt/whiteboard-worker/vision_engine/test_storyboard_v3.json`

### 3.2 Capturer des images fixes aux instants clés

```powershell
scp academia_bobodo_backend\whiteboard_vision\snap_frames.sh root@31.207.38.60:/opt/whiteboard-worker/vision_engine/

ssh lws-nexiom "sed -i 's/\r$//' /opt/whiteboard-worker/vision_engine/snap_frames.sh && bash /opt/whiteboard-worker/vision_engine/snap_frames.sh /tmp/cours_f.html 1500 21500 40000 82000 85300"
```

Les instants sont en **millisecondes**. Ceux utilisés pour la validation de la vague F :

| Instant | Ce qu'on vérifie |
|---|---|
| 1 500 ms | Générique : carte-titre, titre lettre par lettre |
| 21 500 ms | Plaquette de scène + numéro de chapitre « 02 » + mot-clé en rouge |
| 40 000 ms | Écriture en cours, main + stylo, défilement |
| 82 000 ms | Tampon ✓ de correction + première coche de récap |
| 85 300 ms | Carte récap complète, barre de progression avancée |

### 3.3 Rapatrier les captures

```powershell
scp root@31.207.38.60:/tmp/v3_1500.png root@31.207.38.60:/tmp/v3_21500.png root@31.207.38.60:/tmp/v3_82000.png $env:TEMP\
```

> ⚠️ **Utiliser `snap_still.js`** (c'est ce que fait `snap_frames.sh`). **Ne pas utiliser
> `proto_capture_bf.js`** : il rend des images **blanches** pour les captures fixes et fait
> croire à tort que les animations ne fonctionnent pas.

---

## 4. Tester le sound design

```powershell
scp academia_bobodo_backend\whiteboard_vision\test_sfx.py root@31.207.38.60:/opt/whiteboard-worker/vision_engine/

ssh lws-nexiom "cd /opt/whiteboard-worker/vision_engine && python3 test_sfx.py test_storyboard_v3.json 2>&1 | tail -4"
```

Sortie attendue :
```
[sfx] mixage : 16 evenements, 12 grattes, musique=False
RESULT: /tmp/narration_sfx.m4a
duree: 88.900000 s (attendu ~ 88.9 )
```

**Contrôles à faire** : la durée doit correspondre au centième, et le nombre d'événements doit
être cohérent avec le nombre de blocs du storyboard.

### Rapatrier un extrait d'écoute

```powershell
ssh lws-nexiom "ffmpeg -y -v error -ss 18 -t 14 -i /tmp/narration_sfx.m4a -c:a libmp3lame -q:a 4 /tmp/extrait_sfx.mp3"
scp root@31.207.38.60:/tmp/extrait_sfx.mp3 academia_bobodo_backend\extrait_sound_design.mp3
```

---

## 5. Ajouter un lit musical

Le sound design fonctionne sans musique. Pour en ajouter une :

```powershell
scp <mon_morceau_libre>.mp3 root@31.207.38.60:/opt/whiteboard-worker/vision_engine/sfx/music_bed.mp3
```

C'est tout. Au prochain rendu, la musique sera :
- bouclée sur la durée du cours,
- mise à volume 0,10,
- avec fondus d'entrée (1,5 s) et de sortie (2,5 s),
- **compressée en sidechain sous la voix** — elle s'efface quand le professeur parle.

Pour la retirer : supprimer le fichier.

> ⚠️ **Licence** : n'utiliser qu'un morceau libre de droits pour un usage commercial. Les
> bruitages, eux, sont **synthétisés** par ffmpeg — aucune question de licence.

---

## 6. Diagnostiquer un rendu

### Suivre les logs du worker en direct
```powershell
ssh lws-nexiom "journalctl -u whiteboard-worker -f -n 50"
```

### Lignes de log à repérer

| Ligne | Signification |
|---|---|
| `[vision2] %d blocs mesures dans le navigateur` | Passe 1 réussie — la caméra sera juste |
| `[vision2] mesure indisponible — positions estimees` | ⚠️ Passe 1 échouée, rendu dégradé mais fonctionnel |
| `[vision2] page construite : %.1f s a filmer` | Durée totale planifiée |
| `APERCU publie (%.1f s) -> %s` | L'aperçu est en ligne, l'app peut le lire |
| `[capture] apercu non publie` | ⚠️ Aperçu manqué, rendu complet en cours |
| `[sfx] mixage : N evenements, M grattes, musique=X` | Sound design appliqué |
| `[sfx] mixage echoue` / `[sfx] banque indisponible` | ⚠️ Narration seule |
| `[vision2] collage audio impossible` | ⚠️ Vidéo muette livrée |

Toutes les lignes marquées ⚠️ signalent une **dégradation gracieuse** : la vidéo est livrée,
mais un enrichissement manque. Elles méritent une investigation sans être des urgences.

### Inspecter les animations d'une page générée
```powershell
ssh lws-nexiom "cd /opt/whiteboard-worker/vision_engine && node debug_page.js /tmp/cours_f.html"
ssh lws-nexiom "cd /opt/whiteboard-worker/vision_engine && python3 inspect_delays.py /tmp/cours_f.html"
```

---

## 7. Régler la voix

Tout se passe dans `/opt/whiteboard-worker/whiteboard_narration.py` :

| Paramètre | Valeur actuelle | Effet |
|---|---|---|
| `TTS_SPEED` | **0.88** | Débit de parole (~150 mots/min). Plus bas = plus lent |
| Rembourrage de scène | actif | Silence après chaque bloc |
| Durée minimale de scène | active | Empêche un défilement trop rapide |

> ⚠️ **Ne pas** chercher à régler la vitesse via l'Edge Function TTS : elle **ignore** le
> paramètre `speed`. Le ralenti est appliqué par ffmpeg `atempo` dans le worker.

---

## 8. Régler le rendu vidéo

Dans `/opt/whiteboard-worker/vision_engine/` :

| Paramètre | Fichier | Valeur | Effet |
|---|---|---|---|
| `PARALLEL_SLICES` | `whiteboard_video_capture.py` | 3 | Nombre de tranches simultanées. Au-delà de 4, les vCPU se concurrencent |
| `PREVIEW_SEC` | `whiteboard_video_capture.py` | 15.0 | Durée de l'aperçu |
| `MIN_DURATION_FOR_PREVIEW` | `whiteboard_video_capture.py` | 60.0 | En dessous, pas d'aperçu (inutile) |
| `INTRO_SEC` | `whiteboard_page_builder.py` | 3.2 | Durée du générique |

> ⚠️ Si vous modifiez `INTRO_SEC`, vérifiez que le décalage `adelay` de la narration dans
> `whiteboard_render_worker.py` suit — sinon la voix se désynchronise de 100 % du cours.

---

## 9. Régler le sound design

Dans `/opt/whiteboard-worker/vision_engine/whiteboard_sound_design.py` :

| Constante | Valeur | Effet |
|---|---|---|
| `VOL_WHOOSH` | 0.32 | Balayages (générique, plaquettes) |
| `VOL_POP` | 0.26 | Badges, formules, coches |
| `VOL_STAMP` | 0.40 | Tampon de correction |
| `VOL_SCRATCH` | 0.10 | Gratté du stylo pendant l'écriture |
| `VOL_MUSIC` | 0.10 | Lit musical |
| `MAX_EVENTS` | 120 | Plafond d'événements sonores par cours |

Pour **régénérer** la banque de bruitages après avoir modifié une recette `_RECIPES` :

```powershell
ssh lws-nexiom "rm -f /opt/whiteboard-worker/vision_engine/sfx/pop.wav"
```

Le son sera re-synthétisé au prochain rendu. (Ne pas supprimer `music_bed.mp3`, qui n'est pas
synthétisé.)

---

## 10. Inventaire disque

```powershell
ssh lws-nexiom "df -h / ; du -sh /opt/whiteboard-worker /tmp/whiteboard* 2>/dev/null"
```

Les dossiers de travail temporaires des rendus s'accumulent dans `/tmp`. À surveiller.
