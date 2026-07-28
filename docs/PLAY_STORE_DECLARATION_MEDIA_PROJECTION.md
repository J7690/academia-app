# Déclaration Play Console — service de premier plan `mediaProjection`

**Date** : 26 juillet 2026
**Application** : `com.academia.nexiomgroup.app`
**À faire avant** : la prochaine publication sur la piste de production

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

## 4. Vidéo de démonstration à fournir

Google demande une vidéo courte montrant le parcours utilisateur. Deux séquences suffisent, 60 à 90 secondes au total.

**Séquence 1 — partage d'écran en séance**

1. Ouvrir l'application, se connecter en tant qu'enseignant
2. Ouvrir « Mes classes en direct » → « Studio unifié » → démarrer une séance
3. Montrer la barre de contrôle en bas de l'écran
4. **Appuyer sur le bouton « Écran »** — filmer la boîte de dialogue système « Academia va commencer à capturer tout ce qui s'affiche sur votre écran »
5. Accepter, montrer la notification persistante « Partage d'écran en cours »
6. Appuyer de nouveau sur « Écran » pour arrêter, montrer la disparition de la notification

**Séquence 2 — enregistrement de partie**

1. Onglet Challenges → lancer un jeu
2. Montrer le bouton d'enregistrement et l'appui de l'utilisateur
3. Montrer la boîte de dialogue système, puis l'arrêt à la fin de la partie

Hébergez la vidéo en non répertorié sur YouTube ou Google Drive avec accès par lien, et collez l'URL dans le formulaire.

---

## 5. Points sur lesquels Google est attentif

| Attente | Comment nous y répondons |
|---|---|
| Le service doit être visible de l'utilisateur | Notification persistante « Partage d'écran en cours » pendant toute la capture |
| Déclenchement uniquement par l'utilisateur | Le service ne démarre que sur appui du bouton, jamais au lancement de l'application |
| Durée limitée à la tâche | `ScreenShareService.stop()` coupe la capture puis le service ; l'arrêt est aussi déclenché à la sortie de la salle |
| Pas d'alternative moins intrusive | La capture d'écran Android **impose** ce type de service depuis l'API 34 ; aucune API alternative n'existe |
| Cohérence avec la description du Store | Ajouter « partage d'écran pendant les cours en direct » à la description de la fiche |

---

## 6. À vérifier avant de soumettre

- [ ] `flutter pub get` passe et résout `flutter_background`
- [ ] `flutter analyze` propre
- [ ] Build release installé sur un appareil **Android 14 ou 15** — c'est là que la contrainte s'applique
- [ ] Le partage d'écran démarre sans plantage et affiche la notification
- [ ] L'arrêt du partage fait disparaître la notification
- [ ] L'enregistrement de gameplay des Challenges fonctionne de nouveau
- [ ] Vidéo de démonstration enregistrée et hébergée
- [ ] Déclaration saisie en Play Console

---

## 7. Si la déclaration est refusée

Le refus le plus fréquent vient d'une vidéo qui ne montre pas la boîte de dialogue système d'autorisation. Google veut voir que l'utilisateur consent explicitement.

Le repli, en cas de refus persistant, serait de conserver le partage d'écran sur le web et le bureau uniquement, et de le masquer sur Android. Le code le permet déjà : `ScreenShareService` détecte la plateforme et le bouton peut être conditionné. Mais on perdrait aussi l'enregistrement de gameplay, qui est en production.

---

## 8. Note sur `flutter_background`

La dépendance a été ajoutée en `^1.3.0`. Elle n'était pas présente dans `pubspec.lock` — le premier `flutter pub get` la téléchargera.

Si la résolution échoue, l'alternative est d'écrire un petit service Kotlin natif de type `mediaProjection` dans le module Android, et de le piloter par `MethodChannel`. Le manifeste est déjà prêt : il suffirait de remplacer `de.julianassmann.flutter_background.IsolateHolderService` par le nom de la classe locale.
