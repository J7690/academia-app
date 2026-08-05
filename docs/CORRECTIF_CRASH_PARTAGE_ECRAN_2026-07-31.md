# Correctif — l'application se ferme au partage d'écran (31/07/2026)

> Symptôme : « L'application s'est fermée automatiquement » au moment du partage
> d'écran. Pas de message d'erreur, pas de ralentissement : une fermeture nette.

---

## Verdict en une phrase

L'ordre des opérations était **inversé** : le service de premier plan était démarré
**avant** que l'autorisation de capture ne soit accordée. Depuis Android 14, cet ordre
est interdit et le système **tue l'application** — sans exception rattrapable.

---

## La règle Android 14 (celle qui décide de tout)

> **L'autorisation MediaProjection doit être accordée AVANT le démarrage d'un service
> de premier plan de type `mediaProjection`.**

En cas de violation : `SecurityException`, et le processus est terminé. **Aucune reprise,
aucun repli.** C'est pourquoi le `try/catch` autour de la capture ne servait à rien : le
crash se produisait *avant*, dans le démarrage du service.

Ce qui rendait le défaut difficile à voir : **le même code fonctionnait jusqu'à
Android 13**. Avant Android 14, la capture était peu contrôlée — on pouvait démarrer le
service puis demander l'autorisation. La contrainte ne s'applique qu'à partir d'API 34,
et le projet cible `targetSdk 35`.

---

## Ce que faisait le code (fatal)

```dart
// ❌ Ordre pré-Android 14 — ferme l'application sur API 34+
await _startForegroundService();          // 1. service SANS jeton de projection
await participant.setScreenShareEnabled(true);  // 2. autorisation demandée après
```

Le commentaire du fichier documentait même cet ordre comme étant le bon — c'était la
règle d'avant Android 14, restée en place.

## Ce que fait le code maintenant

```dart
// ✅ Ordre imposé par Android 14+
final granted = await Helper.requestCapturePermission();  // 1. boîte système → jeton
if (!granted) return 'Partage annulé…';
await _startForegroundService();                          // 2. service, jeton en main
await Future.delayed(const Duration(milliseconds: 300));  // 3. laisser le service démarrer
await participant.setScreenShareEnabled(true);            // 4. capture
```

Les 300 ms ne sont pas cosmétiques : Android exige `startForeground()` dans les
5 secondes, et enchaîner la capture trop tôt peut la déclencher avant que le service ne
soit réellement au premier plan — ce qui rejouerait l'erreur qu'on vient d'éliminer.

---

## Dépendance ajoutée

`flutter_webrtc: ^1.3.0` passe de **transitive** à **directe** dans `pubspec.yaml`.
Elle était déjà résolue en 1.3.0 via `livekit_client 2.6.4` : aucun risque de conflit de
version. Elle est déclarée pour utiliser `Helper.requestCapturePermission()`, seule API
qui demande l'autorisation et produit le jeton.

> À noter : `flutter_webrtc` expose `getDisplayMedia()` mais **ne démarre aucun service
> de premier plan** — il suppose qu'il existe déjà. C'est cette hypothèse, valable
> avant Android 14, qui a fait basculer beaucoup d'applications.

---

## Enchaînement complet, et pourquoi il satisfait aussi Google Play

| # | Étape | Origine de l'exigence |
|---|---|---|
| 1 | Appui sur « Écran » | — |
| 2 | **Divulgation dans l'application** : quoi, pour qui, comment arrêter | Règle Play (divulgation préalable) |
| 3 | **Boîte système** de capture → jeton | Android 14 |
| 4 | Service de premier plan `mediaProjection` | Android 14 |
| 5 | Capture + notification persistante | Android 14 |

Les deux contraintes convergent : la règle Play impose la divulgation **avant** la boîte
système, et Android 14 impose la boîte système **avant** le service. L'ordre est donc
entièrement déterminé — il n'y a qu'une seule séquence correcte.

C'est aussi exactement la séquence à filmer pour la déclaration Play Console
(`PLAY_STORE_DECLARATION_MEDIA_PROJECTION.md`, section 4).

---

## À vérifier sur appareil réel

Le test n'a de valeur que sur **Android 14 ou 15** — sur Android 13 et avant, l'ancien
code fonctionnait déjà.

- [ ] `cd academia_app && flutter pub get` (résout `flutter_webrtc` en direct)
- [ ] `flutter analyze`
- [ ] Build **release** installé sur un appareil Android 14/15
- [ ] Appui sur « Écran » → la divulgation s'affiche
- [ ] « Partager mon écran » → la boîte **système** s'affiche
- [ ] Accepter → **l'application ne se ferme pas**, la notification apparaît
- [ ] Refuser → message « Partage annulé », l'application reste ouverte et la séance continue
- [ ] Arrêter le partage → la notification disparaît

---

## Si un crash subsiste

Récupérer la trace exacte, elle nomme la cause :
```bash
adb logcat -c && adb logcat | grep -iE "SecurityException|mediaProjection|FOREGROUND_SERVICE|AndroidRuntime"
```
Deux messages à distinguer :
- `Media projections require a foreground service of type…` → le service n'était pas actif
  au moment de la capture : augmenter le délai de l'étape 3.
- `Starting FGS with type mediaProjection… requires a MediaProjection token` → l'ordre est
  de nouveau inversé quelque part.

---

## Second défaut, découvert au test suivant — l'effet « couloir de miroirs »

### Symptôme
Une fois le partage démarré sans crash, l'écran de celui qui partage se remplit
d'une **cascade de vignettes de plus en plus petites**, chacune contenant l'écran
précédent, jusqu'au fond de l'image.

### Cause
`academia_screen_share_view.dart` cherchait la piste de partage en commençant par le
participant **local**, puis la rendait avec `VideoTrackRenderer`.

Or une capture d'écran filme **l'écran**. Afficher sa propre capture revient donc à
filmer l'affichage de ce qu'on est en train de filmer :

```
capture de l'écran → affichée à l'écran → recapturée → réaffichée → …
```

Ce n'est ni un défaut de fluidité ni un problème de réseau : c'est une **boucle de
rétroaction visuelle**, l'équivalent optique du Larsen audio.

### Correction
On n'affiche **jamais** son propre partage. C'est la règle appliquée par tous les
outils de visioconférence :

| Qui | Ce qu'il voit |
|---|---|
| Celui qui partage | Un bandeau « Vous partagez votre écran » + bouton d'arrêt |
| Les autres | Le flux vidéo réel, avec le nom du présentateur |

Bénéfice secondaire : on cesse de décoder et d'afficher une vidéo dont on possède
déjà la source — travail inutile pour le processeur et la batterie, sur des appareils
qui n'en ont pas de trop.

Le même défaut existait dans l'écran hérité `livekit_room_screen.dart`
(`_findScreenShareTrack` parcourait tous les participants, local compris) : corrigé
également, pour qu'il ne resurgisse pas si cet écran est réutilisé.

### À vérifier
- [ ] Celui qui partage voit le **bandeau**, pas son écran — aucune cascade
- [ ] Le bouton « Arrêter le partage » du bandeau fonctionne
- [ ] L'autre participant voit bien **le contenu réel** de l'écran partagé
- [ ] Le nom du présentateur s'affiche côté récepteur

---

## Sources
- [Media projection — Android Developers](https://developer.android.com/media/grow/media-projection)
- [Types de services de premier plan — Android 14](https://developer.android.com/about/versions/14/changes/fgs-types-required)
- [Flutter WebRTC Screen Sharing on Android 14+ (guide, janv. 2026)](https://medium.com/@owinojumahjerome/flutter-webrtc-screen-sharing-on-android-14-the-missing-guide-4f45391055f3)
- [flutter-webrtc #1813 — crash FGS mediaProjection API 34+](https://github.com/flutter-webrtc/flutter-webrtc/issues/1813)
- [livekit/client-sdk-flutter #582 — SecurityException mediaProjection](https://github.com/livekit/client-sdk-flutter/issues/582)
