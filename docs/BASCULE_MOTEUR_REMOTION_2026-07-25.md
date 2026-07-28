# Bascule du Smart Whiteboard sur le moteur Remotion — 25 juillet 2026

## Décision

L'application demande désormais le moteur **Remotion** (studio) au lieu de **Vision**
(diaporama). Décision prise après comparaison argumentée
(`docs/DECISION_MOTEUR_MISE_EN_SCENE.md`) : le moteur Vision ne prend qu'une capture
d'écran par scène et ne peut donc, par construction, animer ni l'écriture ni les
annotations.

## Ce que l'étudiant verra changer

| | Avant (Vision) | Après (Remotion) |
|---|---|---|
| Texte | apparaît d'un bloc | **s'écrit à la main**, caractère par caractère (Caveat) |
| Annotations | aucune | **cercle / souligné / surlignage ciblés sur les mots**, tracés à la main |
| Rappel pédagogique | aucun | la caméra **remonte** vers une notion vue plus haut, la ré-annote, **redescend** |
| Page | une image fixe par scène | **cahier continu** qui défile, mouvement adouci |
| Formules | KaTeX (corrigé le 25/07) | KaTeX |
| Voix | OpenRouter + lecture scientifique | idem |

## Ce qui a été modifié

### Application Flutter
- `lib/config/backend_hosts.dart` : nouveaux réglages `whiteboardEngine`
  (défaut `remotion`) et `whiteboardWritingStyle` (défaut `handwriting`).
- `lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart` :
  envoie `engine` et `writing_style` au générateur, depuis ce point unique.

**⚠️ Prend effet à la PROCHAINE COMPILATION de l'application.** Les storyboards déjà
créés conservent le moteur avec lequel ils ont été générés.

### Supabase
- Edge Function `whiteboard-generate-storyboard` **v36** : le générateur désigne
  désormais les mots à annoter (`emphasis_target`), choisit le geste selon l'intention,
  indique la vitesse d'écriture (`write_speed`), et transporte `writing_style`.
  Garde-fous serveur : cible inexistante → supprimée ; LaTeX résiduel dans la narration
  → nettoyé avant la synthèse vocale ; valeurs inconnues → supprimées.

### Moteur (LWS, `/opt/whiteboard-engine-remotion`)
Écriture manuscrite progressive, annotations ciblées en pixels, séquencement
écriture → immobilité → annotation → avance, défilement adouci, police en un seul
fichier (jamais `@remotion/google-fonts`, cause du crash mémoire de juillet).

## Validation effectuée avant bascule

Rendu réel en conditions de production (storyboard « la continuité », 8 scènes, voix off,
2 rappels, une cible d'annotation `n'est PAS continue` avec `write_speed: slow`) :

- statut `done`, **165 s de rendu pour 2 min 36 de vidéo**
- aucun `heap out of memory`
- vidéo : `renders/c1e27dd2-d12d-4dea-81c9-9a8715c1d902/9830b9f83fbf40888ca17af103771f82.mp4`

## Repli immédiat en cas de problème

Aucun retour arrière de code n'est nécessaire — le moteur Vision reste installé et
fonctionnel sur LWS :

```bash
flutter build --dart-define=WHITEBOARD_ENGINE=vision
```

Ou, pour un repli **sans recompiler l'application**, forcer le moteur sur un projet
donné directement en base :

```sql
update app.whiteboard_projects
set storyboard_json = jsonb_set(storyboard_json, '{engine}', '"vision"')
where id = '<project_id>';
```

**Important** : le worker ne dégrade jamais en silence. Si `remotion` est demandé mais
indisponible, le job échoue explicitement et l'erreur est lisible dans
`app.whiteboard_renders.error_message` — on ne rend jamais avec le mauvais moteur sans
le savoir.

## Reste à faire

1. **Recompiler l'application** pour que la bascule prenne effet côté étudiants.
2. Retirer le moteur Vision de LWS — **seulement après** quelques jours d'observation en
   production (décision du propriétaire : valider d'abord, désinstaller ensuite).
3. Exposer le choix manuscrit / machine dans l'écran de création (le champ est prêt de
   bout en bout, il ne manque que l'interface).
4. Changement de page quand la feuille est pleine (aujourd'hui : rouleau continu).
