# 03 — Application Flutter : l'aperçu instantané

> Dossier concerné : `academia_app/lib/features/challenge/smart_whiteboard/`.
> Trois fichiers modifiés : le service de rendu, le provider, l'écran de prévisualisation.

---

## 1. Le besoin exprimé

> « la possibilité que la vidéo soit prête 10 à 15 secondes après le clic »

Un cours de 90 secondes demande environ 130 secondes de rendu, même après toutes les
optimisations du VPS. L'exigence est donc **arithmétiquement hors de portée** si l'on entend
« la vidéo complète ».

**Reformulation retenue** : ce qui compte n'est pas que tout soit fini, c'est que l'étudiant
**voie quelque chose** tout de suite. On lui donne les 15 premières secondes en 15 secondes,
et la suite arrive pendant qu'il regarde.

C'est le même principe que le streaming progressif : la perception de rapidité vaut mieux
qu'une rapidité absolue.

---

## 2. Le contrat de chemin — sans toucher à la base

Le serveur dépose l'aperçu à un emplacement **conventionnel** :

```
bucket : whiteboard-renders
objet  : renders/<renderId>/preview.mp4
```

```dart
/// Ce chemin est un CONTRAT partagé avec le serveur
/// (`whiteboard_upload_renderer.preview_object_key`) : il ne doit pas changer d'un
/// côté sans l'autre. Ce choix évite d'ajouter une colonne en base et de modifier
/// `whiteboard_get_render_status`.
static String _previewObjectKey(String renderId) => 'renders/$renderId/preview.mp4';
```

**Pourquoi ce choix.** L'alternative propre aurait été d'ajouter une colonne `preview_url` à
la table des jobs et de modifier la RPC `whiteboard_get_render_status`. Cela impliquait une
migration SQL, une modification de RPC, et une désynchronisation possible entre l'app publiée
et la base. Un chemin conventionnel documenté des deux côtés atteint le même résultat sans
toucher au schéma.

**La contrepartie, assumée** : c'est un couplage implicite. D'où le commentaire explicite dans
le code, des deux côtés.

---

## 3. La détection par sonde HEAD — et pourquoi pas `list`

**Première tentative** : appeler `storage.list()` sur le dossier du rendu pour voir si
`preview.mp4` existe. **Échec** : la liste d'un bucket est soumise aux policies RLS, et
l'utilisateur n'a pas ce droit.

**Solution retenue** : une requête **HEAD sur l'URL publique**.

```dart
/// On sonde l'URL publique par un HEAD plutôt que d'appeler `list` : la lecture
/// d'un bucket public ne passe pas par les policies RLS, la détection ne peut donc
/// pas échouer pour une question de droits. C'est aussi une requête très légère,
/// répétée toutes les deux secondes pendant le rendu.
///
/// Toute erreur (réseau, timeout) renvoie null : l'aperçu est un confort, son
/// absence ne doit jamais interrompre l'attente de la vidéo complète.
Future<String?> previewUrlIfReady(String renderId) async {
  final url = previewUrlFor(renderId);
  try {
    final response = await http.head(Uri.parse(url)).timeout(const Duration(seconds: 5));
    return response.statusCode == 200 ? url : null;
  } catch (e) {
    return null;
  }
}
```

Trois qualités de cette approche :
- **Insensible aux policies** — un bucket public se lit sans RLS.
- **Très légère** — un HEAD ne transfère aucun octet de contenu, ce qui autorise une
  répétition toutes les 2 secondes.
- **Silencieuse en cas d'échec** — timeout ou erreur réseau renvoie `null`, l'attente de la
  vidéo complète continue normalement.

---

## 4. Le polling accéléré

`waitForRenderCompletion()` accepte désormais un callback et interroge plus souvent :

```dart
Future<Map<String, dynamic>> waitForRenderCompletion(
  String renderId, {
  Duration timeout = const Duration(minutes: 5),
  Duration pollingInterval = const Duration(seconds: 2),   // était plus long
  void Function(String previewUrl)? onPreview,             // nouveau
}) async {
```

L'intervalle est passé à **2 secondes**. La raison est directe : le serveur a gagné du temps
en publiant l'aperçu tôt ; il serait absurde de perdre ce gain dans un intervalle de polling
trop long. `onPreview` est appelé **une seule fois** (drapeau `previewAnnounced`).

---

## 5. Le provider — exposer l'aperçu comme un état à part

`SmartWhiteboardProvider` distingue maintenant deux URL :

| Champ | Signification |
|---|---|
| `previewVideoUrl` | L'aperçu court, disponible pendant le rendu |
| `videoUrl` | La vidéo complète, disponible à la fin |

**Points de remise à zéro** — chacun est nécessaire, l'oubli d'un seul provoquerait la lecture
d'un aperçu périmé :

| Méthode | Pourquoi remettre à zéro |
|---|---|
| `pollRenderJob` (à la complétion) | La vidéo complète remplace l'aperçu |
| `cancelRenderJob` | Le rendu annulé n'a plus d'aperçu valide |
| `deleteProject` | Le projet supprimé n'a plus de vidéo |
| `reset` | Nouvel état vierge |

---

## 6. L'écran de prévisualisation — la bascule

`_buildVideoPlayer` applique une règle de priorité simple :

1. Si `videoUrl` existe → jouer la **vidéo complète**.
2. Sinon si `previewVideoUrl` existe → jouer l'**aperçu**, avec une bannière « Aperçu ».
3. Sinon → afficher l'état de progression du rendu.

### Le détail qui compte : `ValueKey(url)`

```dart
AcademiaPlaybackView(key: ValueKey(url), ...)
```

**Pourquoi c'est indispensable.** Sans clé dépendante de l'URL, Flutter **réutiliserait** le
même élément de lecteur lors du passage de l'aperçu à la vidéo complète. Le contrôleur vidéo
interne resterait attaché à l'ancienne source : l'étudiant continuerait à voir l'aperçu de
15 secondes en boucle, alors que la vidéo complète est prête.

En donnant l'URL comme clé, on force Flutter à **détruire et recréer** le lecteur au moment de
la bascule. La transition est ainsi propre et fiable.

### La bannière « Aperçu »
Elle est nécessaire pour l'honnêteté de l'interface : sans elle, un étudiant qui voit la vidéo
s'arrêter au bout de 15 secondes croirait à un bug. La bannière transforme une limitation
apparente en information claire : *« ce que tu vois est un début, la suite arrive »*.

---

## 7. Fichiers modifiés — récapitulatif

| Fichier | Nature de la modification |
|---|---|
| `services/smart_whiteboard_render_service.dart` | Ajout de `_bucket`, `_previewObjectKey()`, `previewUrlFor()`, `previewUrlIfReady()` ; `waitForRenderCompletion()` reçoit `onPreview` et passe à 2 s de polling ; import de `package:http/http.dart` |
| `providers/smart_whiteboard_provider.dart` | Champ `_previewVideoUrl` + getter ; branchement du callback dans `pollRenderJob` ; remise à zéro dans 4 méthodes |
| `screens/smart_whiteboard_preview_screen.dart` | `_buildVideoPlayer` gère la priorité complet > aperçu > progression ; bannière « Aperçu » ; `ValueKey(url)` sur le lecteur |

---

## 8. Ce qui n'a **pas** été fait, et pourquoi

**L'aperçu par WebView** — l'idée était d'afficher la page HTML animée directement dans une
WebView, sans passer par la vidéo : l'aperçu serait alors quasi instantané.

**Écarté à ce stade.** Deux raisons :
1. La page HTML dépend de polices, de KaTeX et de mesures faites côté serveur ; la reproduire
   fidèlement dans une WebView mobile demanderait un travail important pour un résultat qui
   **différerait** du rendu final — donc un aperçu trompeur.
2. L'aperçu MP4 satisfait déjà le besoin exprimé, avec une garantie que l'aperçu est
   **exactement** le début de la vidéo finale.

Cette piste reste ouverte, voir `06_RESTE_A_FAIRE.md`.
