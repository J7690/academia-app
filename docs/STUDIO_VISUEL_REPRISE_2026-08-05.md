# Studio visuel — reprise du chantier

> **05/08/2026, après-midi.** Reprise après la mise en sommeil consignée dans
> `STUDIO_VISUEL_ETAT_2026-08-05.md`. Ce document dit ce qui a été **mesuré**,
> ce qui a été **éliminé**, ce qui a été **corrigé**, et ce qui reste ouvert.
>
> Point de reprise n°1 du document de mise en sommeil : *« Mesurer pourquoi
> `genere` rend du noir. Ne rien supposer. »*

---

## État à la reprise, relevé et non supposé

| | |
|---|---|
| `runpod-watchdog` (pg_cron) | **actif** — le filet, laissé exprès |
| `studio-orchestrateur` | **inactif** |
| `studio-reprise-orphelins` | **inactif** |
| Machines RunPod actives | 0 |
| Dépense de cette session | **0,00 $** |

Tout le travail décrit ici a été fait **sans louer une seule machine**.

---

## Ce qui a été éliminé par la mesure

La moitié aval de la chaîne `genere` a été reproduite en local avec les
**vrais modules** (`generateur_ia.mouvement_camera` puis `montage.assembler`),
en remplaçant la seule étape qui exige un GPU — `produire_image` — par une
image de synthèse vivement colorée.

**Résultat : luminosité 129,46/255, image visible.** Le mouvement de caméra et
le montage ne produisent pas de noir. La cause est donc **en amont**, dans la
génération elle-même.

C'est la moitié du champ de recherche éliminée pour zéro centime.

---

## Le vrai mécanisme de la livraison noire, mesuré

Une capsule de 4 scènes dont **2 noires** a été assemblée et contrôlée :

```
luminosité moyenne   64,74 / 255
image_visible        True          ← le contrôle DÉCLARE LA CAPSULE BONNE
secondes noires      11,0 s sur 22,6 s  (49 %)
```

`luminosite_moyenne` prend huit échantillons sur **toute** la capsule et les
**moyenne**. Une scène noire se cache donc derrière les scènes lumineuses qui
l'entourent — et plus la capsule est longue, mieux elle se cache.

Le contrôle ajouté le 05/08 au matin était **nécessaire mais jamais
suffisant**. C'est exactement le défaut n°7 sous une forme plus fine : il ne
regardait plus seulement la validité du fichier, mais il regardait encore le
mauvais agrégat.

---

## Quatre correctifs, tous vérifiés sans GPU

**1. `produire_image` mesure ce qu'elle a produit.** Un modèle de diffusion qui
rend du noir **ne lève pas d'exception** : il rend une image parfaitement
valide dont tous les pixels valent zéro — symptôme connu d'un débordement
numérique dans le VAE en demi-précision. `image.save()` réussissait, la
fonction renvoyait `True`, et le mouvement de caméra fabriquait
consciencieusement 120 images noires. **La dégradation gracieuse vers un
archétype procédural ne se déclenchait jamais, puisque rien n'avait échoué.**
Désormais une source sous 6/255 est rejetée et n'est même pas écrite.

**2. `scenes_sombres` mesure scène par scène.** Sur le cas de test, elle
identifie exactement `s2` et `s3` (luminosité 0,01) là où la moyenne globale
disait « bon ». `executer_capsule` refuse maintenant de déposer une capsule
dont une seule scène est noire, en nommant la scène, son instant et sa durée.

**3. L'image source sortait dans le dossier de montage.** `assembler` ramasse
les fichiers par préfixe `{id}_` : `s1_source.png` correspondait au même
filtre que `s1_0001.png`, et triait **en dernier** (`s` > `0`). Elle devenait
donc la dernière image de chaque scène générée — une image 528×960 étirée dans
une vidéo 1080×1920. Elle va maintenant dans un sous-dossier `_sources/`.

**4. Le compte d'images était faux.** `mouvement_camera` comptait les fichiers
par le même préfixe, donc incluait la source : **121 annoncées pour 120
demandées**. Corrigé par le même déplacement.

### Le seuil ne rejette pas les images légitimement sombres

Mesuré, parce que le style impose un fond *dark navy* et qu'un seuil trop haut
aurait cassé la chaîne entière :

| Image | Luminosité | Verdict |
|---|---|---|
| noire | 0,0 | rejetée |
| fond *dark navy* du style | **16,0** | **acceptée** |
| image lumineuse | 167,0 | acceptée |

Une capsule entièrement composée de fonds sombres légitimes ne déclenche
**aucune** alerte — vérifié.

---

## Ce qui reste ouvert

**La cause première du noir n'est pas établie.** Elle est maintenant cernée à
l'intérieur de `produire_image`, mais l'établir exige une machine avec GPU.
L'hypothèse la plus probable — débordement numérique du VAE en `bfloat16` avec
`enable_model_cpu_offload` — reste **une hypothèse**, et doit être mesurée, pas
supposée.

Ce qui a changé : à la prochaine location, la chaîne **le dira**. Le journal
portera `image NOIRE rejetée — luminosité x/255`, et la scène basculera sur un
archétype procédural au lieu de livrer du vide. Le défaut est devenu
observable ; c'est la condition pour le diagnostiquer.

**Les autres points du plan de reprise sont inchangés** : revoir visuellement
les dix archétypes (`comparaison` sort noir, `silhouette` jamais essayé avec un
vrai SVG), puis phase 5 (interface éditoriale) et phase 6 (image Docker).

---

## Méthode, et pourquoi elle a payé ici

Le document de mise en sommeil demandait de mesurer sans supposer. Appliqué à
la lettre, cela a donné : une moitié de chaîne éliminée, un mécanisme de
livraison établi chiffres à l'appui, quatre défauts corrigés et vérifiés — pour
**0,00 $**, là où la réaction naturelle était de louer une machine pour
« voir ».

La prochaine location servira à établir une cause précise, sur une chaîne qui
sait enfin dire ce qu'elle voit.
