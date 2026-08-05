# Play Console — les 3 blocages de la release de production (31/07/2026)

> Contexte : la création de la release de production est refusée. Trois erreurs
> distinctes, sans rapport entre elles. Traitées ici de la plus simple à la plus
> longue.

---

## Blocage 1 — APK obsolètes dans la release (le plus simple)

### Le message
> « Ce fichier APK ne sera pas distribué aux utilisateurs, car il est complètement
> occulté par un ou plusieurs fichiers APK avec un code de version supérieur. »
> — pour les **codes de version 20 et 21**.

### Ce qui se passe
La release contient **plusieurs artefacts** : les versions 20, 21 et une plus
récente. Les deux anciennes sont intégralement couvertes par la plus récente : elles
ne seraient jamais installées par personne. Play refuse de publier du code mort.

### Correction
Dans l'écran de la release, **retirer les APK 20 et 21** ; ne garder que l'artefact
le plus récent.

### Recommandation de fond
Publier **un seul Android App Bundle (`.aab`)** plutôt que des APK :
```bash
cd academia_app
flutter build appbundle --release
```
C'est le format attendu par Play depuis 2021 ; il évite par construction ce type de
conflit, et Google génère lui-même les APK adaptés à chaque appareil.

---

## Blocage 2 — Identifiant publicitaire (AD_ID)

### Le message
> « D'après la déclaration d'identifiant publicitaire de la Play Console, votre appli
> utilise un identifiant publicitaire. Un fichier manifeste dans vos artefacts actifs
> n'inclut pas l'autorisation `com.google.android.gms.permission.AD_ID`. »

### La cause : une incohérence, pas un manque
La **déclaration** en Play Console affirme que l'application utilise un identifiant
publicitaire, alors que les artefacts ne le confirment pas. Vérification faite dans le
projet :

| Vérification | Résultat |
|---|---|
| SDK publicitaire (`google_mobile_ads`, AdMob…) | **Aucun** |
| `firebase_analytics` | **Absent** |
| Collecte analytics dans le manifeste | Explicitement **désactivée** |
| Attribution (AppsFlyer, Adjust, Facebook) | **Aucune** |

**Academia n'utilise donc réellement aucun identifiant publicitaire.** La permission
apparaissait pour deux raisons : elle était déclarée en dur dans le manifeste, et
`firebase_messaging` embarque `play-services-ads-identifier`, qui la fait entrer par
fusion de manifeste même sans publicité.

### Correction (code — déjà appliquée)
`AndroidManifest.xml` : la permission est désormais **retirée**, y compris celle
héritée de la dépendance :
```xml
<uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:node="remove"/>
```

### Correction (Play Console — à faire)
Play Console → **Contenu de l'application** → **Identifiant publicitaire** →
répondre **« Non, mon application n'utilise pas d'identifiant publicitaire »**.

> ⚠️ Les deux doivent rester **cohérents**. Déclarer « non » tout en laissant la
> permission dans le manifeste reproduirait l'erreur en sens inverse. Si un jour la
> publicité ou la mesure d'audience devenait nécessaire, il faudrait remettre la
> permission **et** modifier la déclaration.

Effet secondaire à connaître, sans gravité ici : sans AD_ID, l'identifiant
publicitaire de l'appareil est réinitialisé pour l'application. Aucune conséquence
puisque rien ne l'exploite.

---

## Blocage 3 — Vidéo de démonstration `FOREGROUND_SERVICE_MEDIA_PROJECTION`

### Le message
Case « Projection de contenus multimédias et autres, streaming » cochée, puis :
> « Fournissez une vidéo montrant comment votre appli utilise l'autorisation
> FOREGROUND_SERVICE_MEDIA_PROJECTION » — champ **Lien de la vidéo** obligatoire.

### Pourquoi c'est le plus long
C'est le seul blocage qui exige que la fonctionnalité **marche réellement** pour être
filmée. C'était précisément le problème : le partage d'écran n'était accessible qu'à
l'hôte, et sans divulgation préalable. **Corrigé le 30/07/2026** — voir
`PLAY_STORE_DECLARATION_MEDIA_PROJECTION.md`, sections 3 bis et 4.

### Ordre des opérations
1. `cd academia_app && flutter analyze` (rien n'a encore été compilé depuis les correctifs).
2. Construire un build **release** et l'installer sur un appareil **Android 14 ou 15** —
   c'est là que la contrainte du service de premier plan s'applique.
3. Filmer la séquence (script détaillé dans l'autre document). Le point décisif :
   **filmer les deux boîtes de dialogue, dans l'ordre** — d'abord celle de
   l'application (« Partager votre écran ? »), puis celle du système Android.
   L'absence de la première est la cause de rejet la plus fréquente.
4. Héberger la vidéo sur YouTube en **non répertorié**, coller le lien dans le champ.

### Contenu de la vidéo (60–90 s)
- Connexion en **conseiller d'orientation** (ou enseignant), ouverture d'une séance.
- Appui sur le bouton **« Écran »**.
- **Divulgation de l'application** : ce qui est capté, qui le voit, comment l'arrêter.
- Boîte **système** Android, acceptation.
- **Notification persistante** « Partage d'écran en cours ».
- Arrêt du partage, disparition de la notification.

---

## Ordre conseillé

1. **Blocage 1** — retirer les APK 20 et 21 (immédiat).
2. **Blocage 2** — répondre « Non » à l'identifiant publicitaire, puis reconstruire
   pour que le nouveau manifeste soit dans l'artefact.
3. **Blocage 3** — vérifier le partage d'écran sur un appareil réel, filmer, publier
   le lien.

Un seul nouvel artefact (`.aab`) reconstruit **après** le correctif AD_ID règle les
blocages 1 et 2 en même temps.
