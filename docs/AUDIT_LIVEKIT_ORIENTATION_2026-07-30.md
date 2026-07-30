# Audit du Studio Live (LiveKit) — 30/07/2026

> Déclencheur : un entretien d'orientation conseiller ↔ étudiant. Côté conseiller,
> le studio s'ouvre et la caméra fonctionne. Côté étudiant : blocage sur l'écran
> d'ouverture, écho continu, et la voix du conseiller audible avec une forte latence.
> Méthode : remonter le flux (app → Edge Function → token → salle) sans rien supposer.

---

## Verdict en une phrase

L'étudiant d'un entretien recevait un token **en lecture seule**, mais l'application
tentait quand même d'activer son micro et sa caméra **avant** d'afficher la salle :
l'écran restait figé sur « Activation du micro et de la caméra… » pendant que l'audio
distant, lui, jouait déjà — d'où l'impression d'un studio mort mais bruyant.

---

## Le symptôme expliqué

Le détail décisif est que **l'étudiant entendait le conseiller**. En LiveKit, l'audio
distant est joué par la couche native dès que la connexion est établie : il ne dépend
**pas** de l'interface. Entendre du son tout en restant sur l'écran de chargement
prouve donc que la connexion avait réussi et que **seule l'interface était bloquée**.

Séquence réelle (`academia_classroom_screen.dart`) :

```dart
await room.connect(url, token);            // ✅ réussit — l'audio distant démarre
_step('Activation du micro et de la caméra…');   // ← écran vu par l'étudiant
await room.localParticipant?.setMicrophoneEnabled(_micEnabled);  // ⛔ n'aboutit jamais
await room.localParticipant?.setCameraEnabled(_cameraEnabled);
setState(() { _isConnecting = false; _isConnected = true; });    // jamais atteint
```

---

## Défaut 1 (Supabase) — un entretien traité comme un cours magistral ❌→✅

`livekit-token` accordait le droit de parole ainsi :

```typescript
canPublish: isHost,
```

Un entretien d'orientation est pourtant un **échange** : l'étudiant doit parler et être
vu. Avec `canPublish: false`, sa publication était refusée par le serveur.

**Subtilité qui rendait le défaut difficile à voir** : quand la session vient de la table
unifiée, la variable `sessionType` vaut `'academia'` — le vrai format
(`orientation` | `td` | `course`) se trouve dans `sessionData.session_type`.

**Correctif (déployé v64)** — le droit de parole suit le format de la séance :

```typescript
const BIDIRECTIONAL_KINDS = ['orientation', 'td', 'consultation', 'workshop', 'atelier', 'tutoring'];
const canPublish = isHost || isBidirectional;
```

`course` reste réservé à l'hôte (un intervenant, N spectateurs). La réponse expose
désormais **`can_publish`**, pour que l'application sache ce qu'elle a le droit de faire
au lieu de le deviner.

## Défaut 2 (Flutter) — l'affichage dépendait de la publication ❌→✅

La salle n'était affichée qu'**après** l'activation du micro et de la caméra. Toute
défaillance de publication gelait donc l'écran.

**Correctif** : la salle s'affiche **dès la connexion établie**, et l'activation du média
part en arrière-plan (`unawaited(_activerMediaLocal(room))`). Le média est un **confort** ;
la présence en salle est l'**essentiel**. C'est la règle de dégradation gracieuse du
projet, appliquée ici au Studio Live.

## Défaut 3 (Flutter) — aucune demande de permission ❌→✅

`AndroidManifest.xml` déclare bien `CAMERA` et `RECORD_AUDIO`, mais depuis Android 6
ce sont des permissions **d'exécution** : les déclarer ne suffit pas. Or `permission_handler`
n'était appelé **nulle part** dans le Studio Live (il l'est ailleurs, ex. Bobodo).
Sans permission accordée, la capture native peut échouer — ou rester en attente.

**Correctif** : permissions demandées au moment utile (à l'entrée en salle, quand
l'utilisateur comprend pourquoi), puis chaque activation encapsulée dans son propre
`try/catch` avec un message explicite (« Micro refusé : vous entendez la séance mais ne
pouvez pas parler »).

## Défaut 4 (Flutter) — traitement audio laissé implicite ❌→✅

`AcademiaRoomOptions` configurait finement la **vidéo** (simulcast, dynacast,
adaptiveStream) mais ne disait **rien de l'audio**. Aucune configuration de session VoIP
n'existe non plus dans l'application (`setSpeakerphoneOn`, mode communication : absents).

**Correctif** : `echoCancellation`, `noiseSuppression` et `autoGainControl` sont désormais
**explicites** sur tous les profils de salle. C'est la défense contre l'effet Larsen quand
un participant écoute au haut-parleur — le cas normal sur téléphone.

> ✅ **Écho — cause confirmée par le test** : les deux appareils se trouvaient **dans la
> même pièce**. C'était donc un effet Larsen acoustique classique (haut-parleur de l'un
> capté par le micro de l'autre), pas un défaut logiciel. Les filtres explicites ajoutés
> ci-dessus restent utiles, mais la vérification à faire est simplement de **tester depuis
> deux pièces différentes**, ou au casque.
>
> Reste une piste connue si un écho apparaissait en conditions réelles : l'application ne
> force nulle part le mode audio Android en « communication » (`setSpeakerphoneOn`,
> absent). Sans lui, l'annuleur d'écho **matériel** n'est pas engagé. Non traité —
> configuration native, à ouvrir seulement si le besoin est constaté.

---

## Cohérence des rôles

| Rôle | Format de séance | Droit de parole | Statut |
|---|---|---|---|
| Conseiller d'orientation | `orientation` | hôte → publie | ✅ fonctionnait déjà |
| Étudiant (entretien) | `orientation` | **publie désormais** | ✅ corrigé |
| Enseignant | `course` / `td` | hôte → publie | ✅ inchangé |
| Étudiant (cours magistral) | `course` | spectateur | ✅ inchangé, message explicite |
| Étudiant (TD) | `td` | **publie désormais** | ✅ corrigé |

---

## Supervision administrateur (ajout du 30/07/2026)

Besoin exprimé : *« l'administrateur doit pouvoir rejoindre n'importe quelle séance,
invité ou non, intervenir, suspendre, retirer, arrêter, modérer. »*

### Ce qui a été mis en place

**Rôle** — lu depuis `auth.users` (`raw_app_meta_data` / `raw_user_meta_data`, valeurs
`admin` ou `super_admin`), même source de vérité que `public.app_is_admin_user()`. Il est
extrait du jeton déjà vérifié : aucun aller-retour supplémentaire vers la base.

**Token (`livekit-token` v65)** — un administrateur :
- **entre dans n'importe quelle séance**, y compris hors des statuts autorisés (il doit
  pouvoir superviser ou arrêter une séance en dérive) ;
- obtient **`canPublish: true`** : il intervient, il n'observe pas seulement ;
- **n'est pas enregistré comme participant** quand il n'est pas l'hôte — sa présence ne
  doit pas fausser les statistiques de fréquentation ;
- reçoit `is_admin` et `is_moderator` pour que l'application affiche les commandes.

**Modération (`livekit-moderate`, nouvelle fonction)** — actions `list`, `mute`,
`unmute`, `revoke_publish`, `grant_publish`, `remove`, `end_session`.

> **Choix de sécurité important** : le token client ne porte **jamais** la permission
> `roomAdmin`. Couper un micro ou retirer quelqu'un exige la clé secrète LiveKit ; elle
> ne quitte pas le serveur. L'application *demande* l'action, l'Edge Function *revérifie
> le droit* puis l'exécute. Un token client, même intercepté, ne donne donc aucun pouvoir
> d'administration.

**Droits** : administrateur → toutes les séances ; hôte → sa séance uniquement.
Garde-fou : on ne peut pas se retirer soi-même (le bouton « Quitter » existe pour ça).

**Application** — service `AcademiaModerationService`, badge **SUPERVISION** quand un
admin rejoint une séance dont il n'est pas l'hôte, et panneau de modération (icône
bouclier) listant les participants avec : couper le micro, suspendre la parole, rendre la
parole, retirer — plus « Arrêter la séance pour tous », sous confirmation.

### Limites assumées
- **Couper ≠ interdire** : LiveKit permet au serveur de couper une piste, mais le
  participant peut se réactiver. Pour retirer durablement la parole, utiliser
  **« Suspendre la parole »** (`revoke_publish`), qui retire le droit de publier.
- **Accès à la liste des séances** : l'administrateur peut techniquement rejoindre
  n'importe quelle séance, mais l'écran d'administration ne propose pas encore de
  parcourir les séances en cours pour y entrer. C'est le complément naturel à prévoir.

---

## Dette repérée, non corrigée

`livekit_token_service.dart` contient le **code mort** déjà identifié le 27/07 :

```dart
if (response.status != 200) { ... }   // jamais atteint : invoke() lève une exception
```

Même motif que le défaut n° 1 de l'audit du 27/07, et il reste présent dans plusieurs
services (`academia_livekit_service`, `livekit_recording_service`…). Conséquence : les
erreurs LiveKit s'affichent en vidage technique au lieu d'un message utile. **À traiter**,
mais hors du périmètre de ce blocage.

---

## À vérifier au prochain test

1. **L'étudiant entre en salle** et voit la vidéo du conseiller (plus de blocage).
2. Il peut **parler et être vu** (entretien bidirectionnel).
3. La **demande de permission** apparaît à l'entrée en salle.
4. **L'écho** : tester les deux appareils dans des pièces différentes. S'il persiste,
   traiter la piste du mode audio natif (voir avertissement ci-dessus).
5. Le **cours magistral** (`course`) : l'étudiant reste spectateur, avec le message
   « Vous suivez la séance en spectateur. »

Commande utile :
```bash
cd academia_app && flutter analyze
```
