# Déclaration Play Console — service de premier plan `mediaProjection`

**Date** : 26 juillet 2026 — **mis à jour le 30 juillet 2026**
**Application** : `com.academia.nexiomgroup.app`
**À faire avant** : la prochaine publication sur la piste de production

> **Mise à jour du 30/07/2026** — deux manques ont été corrigés :
> 1. le partage d'écran n'était accessible qu'à l'**hôte** (les contrôles élève
>    n'avaient aucun bouton), ce qui rendait la fonctionnalité indémontrable pour
>    un entretien d'orientation ;
> 2. il n'existait **aucune divulgation préalable dans l'application** avant la
>    boîte de dialogue système — c'est une exigence explicite de Google Play
>    (« Best practices for prominent disclosure and consent »), et une cause
>    fréquente de rejet.
>
> Voir la nouvelle **section 3 bis**.

---

## 1. Pourquoi cette déclaration est nécessaire

Deux permissions ont été restaurées dans `AndroidManifest.xml` le 26 juillet 2026 :

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION"/>
```

accompagnées d'un service :

```xml
<service
    android:name="de.julianassmann.flutter_background.IsolateHolderService"
    android:foregroundServiceType="mediaProjection" />
```

Depuis 2024, Google Play exige une **déclaration d'usage** pour tout service de premier plan, avec une justification écrite et une vidéo de démonstration. Sans elle, la version est rejetée à la soumission.

Ces permissions avaient été retirées par `tools:node="remove"`, ce qui rendait inopérants le partage d'écran du Studio Live **et** l'enregistrement de gameplay des Challenges. L'audit des permissions du 4 juin 2026 les listait pourtant comme actives et à conserver.

---

## 2. Où le déclarer

Play Console → votre application → **Règles et programmes** → **Contenu de l'application** → **Autorisations d'accès aux services de premier plan**.

Une entrée par type de service. Ici, un seul type : `mediaProjection`.

---

## 3. Texte de déclaration à saisir

Réponse à « Décrivez l'utilisation principale du type de service de premier plan » :

> Academia est une application éducative destinée aux étudiants et aux
> enseignants du Burkina Faso. Le service de premier plan de type
> mediaProjection est utilisé pour deux fonctionnalités visibles de
> l'utilisateur, toutes deux déclenchées manuellement par lui.
>
> Premièrement, le partage d'écran pendant une séance de cours en direct. Un
> enseignant peut diffuser son écran aux étudiants connectés afin de montrer un
> document, une procédure ou un logiciel pendant son explication. Le partage
> est démarré par un appui explicite sur le bouton « Écran » dans la barre de
> contrôle de la salle de classe, et s'arrête par un second appui ou à la fin
> de la séance.
>
> Deuxièmement, l'enregistrement de la partie pendant les défis pédagogiques.
> L'étudiant peut enregistrer son écran pendant qu'il joue à un jeu éducatif
> afin de publier sa performance dans le fil de défis de l'application.
> L'enregistrement est démarré par l'utilisateur et s'arrête à la fin de la
> partie.
>
> Dans les deux cas, le service ne s'exécute que pendant la durée de la capture
> et est arrêté immédiatement après. Il ne démarre jamais automatiquement, ne
> tourne jamais en arrière-plan à l'insu de l'utilisateur, et une notification
> persistante indique explicitement que l'écran est en cours de partage.
> Aucune capture n'est possible sans que l'utilisateur ait accepté la boîte de
> dialogue système d'autorisation d'enregistrement de l'écran.

---

## 3 bis. Divulgation préalable dans l'application (obligatoire)

### La règle

Google Play impose, **en plus** de la boîte de dialogue système, une divulgation
**dans l'application**, présentée **juste avant** la demande d'autorisation. Motif :
la boîte système dit « enregistrer l'écran », mais ne dit ni **à qui** le contenu sera
diffusé, ni **pourquoi**. Une mention dans la description du Store ou dans la politique
de confidentialité ne satisfait **pas** l'exigence : elle doit être dans le parcours.

### Ce qui a été implémenté (30/07/2026)

`_demanderConsentementPartage()` dans `academia_classroom_screen.dart`, appelée **avant**
`ScreenShareService.start()`. Elle énonce les trois informations attendues :

| Exigence | Formulation retenue |
|---|---|
| **Ce qui** est capté | « Tout ce qui s'affiche sur votre écran […] y compris vos notifications et le contenu de vos autres applications » |
| **Qui** le voit | « visible en direct aux N autres participants de cette séance » (le nombre réel est affiché) |
| **Comment l'arrêter** | « Vous pouvez arrêter le partage à tout moment, depuis le même bouton » |
| Ce qui n'est **pas** fait | « Rien n'est enregistré à votre insu : un enregistrement éventuel est signalé par un bandeau rouge » |

Points de conformité :
- le refus est le **choix par défaut** (`barrierDismissible: false`, bouton « Annuler » à gauche) ;
- aucune case n'est pré-cochée, l'action positive est explicite (« Partager mon écran ») ;
- la boîte annonce l'étape suivante : « Votre téléphone vous demandera ensuite de confirmer ».

### Portée : tous les rôles

La divulgation est dans `_toggleScreenShare()`, **point de passage unique** de tout partage
d'écran de la salle. Elle s'applique donc identiquement à l'enseignant, au conseiller
d'orientation, à l'élève et à l'administrateur — aucun rôle ne peut la contourner.

### Qui peut partager

| Rôle | Format | Bouton visible | Motif |
|---|---|---|---|
| Enseignant (hôte) | tous | ✅ | Anime la séance |
| Conseiller (hôte) | `orientation` | ✅ | Montre une fiche, un dossier |
| Élève | `orientation`, `td` | ✅ | Montre son exercice, son erreur |
| Élève | `course` | ❌ | Spectateur : n'a pas le droit de publier |

Le bouton élève est conditionné par `features.isScreenShareEnabled && canShareScreen`,
où `canShareScreen` reflète le `can_publish` du token. Un bouton qui échouerait
systématiquement ne doit pas être montré.

---

## 4. Vidéo de démonstration à fournir

Google demande une vidéo courte montrant le parcours utilisateur. Deux séquences suffisent, 60 à 90 secondes au total.

**Séquence 1 — partage d'écran en séance**

1. Ouvrir l'application, se connecter en tant qu'enseignant (ou conseiller d'orientation)
2. Ouvrir « Mes classes en direct » → « Studio unifié » → démarrer une séance
3. Montrer la barre de contrôle en bas de l'écran
4. **Appuyer sur le bouton « Écran »**
5. ⚠️ **Filmer la divulgation dans l'application** — la boîte « Partager votre écran ? »
   qui explique ce qui est capté, qui le verra et comment l'arrêter. **C'est la séquence
   que Google cherche en priorité** : elle prouve le consentement éclairé, en amont du
   système. L'omettre est la première cause de rejet.
6. Appuyer sur « Partager mon écran » — filmer ensuite la boîte de dialogue **système**
   « Academia va commencer à capturer tout ce qui s'affiche sur votre écran »
7. Accepter, montrer la notification persistante « Partage d'écran en cours »
8. Appuyer de nouveau sur « Écran » pour arrêter, montrer la disparition de la notification

> Filmer les **deux** boîtes, dans cet ordre : d'abord celle de l'application, puis celle
> du système. C'est la démonstration littérale de la règle de divulgation préalable.

**Séquence 2 — enregistrement de partie**

1. Onglet Challenges → lancer un jeu
2. Montrer le bouton d'enregistrement et l'appui de l'utilisateur
3. Montrer la boîte de dialogue système, puis l'arrêt à la fin de la partie

Hébergez la vidéo en non répertorié sur YouTube ou Google Drive avec accès par lien, et collez l'URL dans le formulaire.

---

## 5. Points sur lesquels Google est attentif

| Attente | Comment nous y répondons |
|---|---|
| **Divulgation préalable dans l'application** | Boîte « Partager votre écran ? » affichée **avant** la demande système : quoi, pour qui, comment arrêter (section 3 bis) |
| Le service doit être visible de l'utilisateur | Notification persistante « Partage d'écran en cours » pendant toute la capture |
| Déclenchement uniquement par l'utilisateur | Le service ne démarre que sur appui du bouton, jamais au lancement de l'application |
| Consentement à **chaque** session | Aucun jeton de capture n'est réutilisé : la divulgation et la boîte système reviennent à chaque partage (imposé par Android 14+, et conforme à la règle) |
| Durée limitée à la tâche | `ScreenShareService.stop()` coupe la capture puis le service ; l'arrêt est aussi déclenché à la sortie de la salle |
| Pas d'alternative moins intrusive | La capture d'écran Android **impose** ce type de service depuis l'API 34 ; aucune API alternative n'existe |
| Cohérence avec la description du Store | Ajouter « partage d'écran pendant les cours en direct » à la description de la fiche |

---

## 6. À vérifier avant de soumettre

- [ ] `flutter pub get` passe et résout `flutter_background`
- [ ] `flutter analyze` propre
- [ ] Build release installé sur un appareil **Android 14 ou 15** — c'est là que la contrainte s'applique
- [ ] **La divulgation « Partager votre écran ? » s'affiche AVANT la boîte système**
- [ ] « Annuler » n'ouvre pas la boîte système et ne démarre aucune capture
- [ ] Le partage d'écran démarre sans plantage et affiche la notification
- [ ] L'arrêt du partage fait disparaître la notification
- [ ] **Conseiller d'orientation** : le bouton « Écran » est présent et fonctionne
- [ ] **Élève en entretien / TD** : le bouton « Écran » est présent et fonctionne
- [ ] **Élève en cours magistral** : le bouton est absent (pas de droit de publication)
- [ ] L'enregistrement de gameplay des Challenges fonctionne de nouveau
- [ ] Vidéo de démonstration enregistrée et hébergée (avec les **deux** boîtes)
- [ ] Déclaration saisie en Play Console

---

## 7. Si la déclaration est refusée

Le refus le plus fréquent vient d'une vidéo qui ne montre pas la boîte de dialogue système d'autorisation. Google veut voir que l'utilisateur consent explicitement.

Le repli, en cas de refus persistant, serait de conserver le partage d'écran sur le web et le bureau uniquement, et de le masquer sur Android. Le code le permet déjà : `ScreenShareService` détecte la plateforme et le bouton peut être conditionné. Mais on perdrait aussi l'enregistrement de gameplay, qui est en production.

---

## 8. Note sur `flutter_background`

La dépendance a été ajoutée en `^1.3.0`. Elle n'était pas présente dans `pubspec.lock` — le premier `flutter pub get` la téléchargera.

Si la résolution échoue, l'alternative est d'écrire un petit service Kotlin natif de type `mediaProjection` dans le module Android, et de le piloter par `MethodChannel`. Le manifeste est déjà prêt : il suffirait de remplacer `de.julianassmann.flutter_background.IsolateHolderService` par le nom de la classe locale.
