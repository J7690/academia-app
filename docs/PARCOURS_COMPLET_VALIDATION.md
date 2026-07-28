# Smart Whiteboard — terminer le chantier : du sujet tapé à la publication

**Date** : 26 juillet 2026
**Objet** : ce qui reste pour que **tout le parcours** soit validé, pas seulement le rendu.

---

## Le point aveugle à nommer d'abord

Tous les rendus validés jusqu'ici ont été déclenchés par **injection directe d'un job en
base**. C'est un raccourci de test légitime, mais il court-circuite la moitié du parcours
réel :

```
                         ┌─── VALIDÉ (par injection SQL) ───┐
étudiant tape un sujet → génération IA → projet → job → rendu → vidéo → publication
└──── JAMAIS TESTÉ ────┘                                          └── JAMAIS TESTÉ ──┘
```

Autrement dit : **on sait que le moteur produit une belle vidéo, on ne sait pas encore
qu'un étudiant peut en obtenir une.** C'est la dernière chose à établir.

---

## Ce qui est en place

| Maillon | État |
|---|---|
| Générateur IA (v36) | ✅ déployé — cibles d'annotation, vitesse d'écriture, style |
| Base : 12 RPC, 168 projets, 67 rendus réussis | ✅ |
| Verrou de la file (1 worker inscrit) | ✅ |
| Moteur Vision v2 | ✅ écriture manuscrite, cahier continu, annotations, rappels |
| Voix synchronisée par bloc, rythme académique | ✅ |
| Stockage vidéo (bucket `whiteboard-renders`) | ✅ |
| Application : code à jour (`engine: vision2`) | ⚠️ **pas recompilée** |

---

## Les 6 étapes qui restent, dans l'ordre

### 1. Le générateur doit produire une narration PAR BLOC ⚠️ *bloquant pour la qualité*
Aujourd'hui le générateur écrit **une** narration par scène. Le moteur, faute de mieux,
fait donc **lire le contenu écrit** — ce qui est synchrone, mais redondant : la voix
répète ce que l'œil lit déjà.

Un professeur ne lit pas son tableau, il **commente** ce qu'il écrit. Il faut donc une
version v37 du générateur : un champ `narration` sur **chaque bloc**, qui explique au
lieu de répéter.

*C'est ce qui fera passer la vidéo de « correcte » à « pédagogique ».*

### 2. Recompiler l'application ⚠️ *bloquant pour la mise en service*
Le code demande `vision2`, mais l'application installée demande encore l'ancien moteur.
Tant qu'elle n'est pas recompilée, **aucun étudiant ne verra ces vidéos**.

### 3. Valider le parcours réel de bout en bout
Depuis l'application, avec un vrai compte étudiant : taper un sujet, générer, lancer le
rendu, voir la vidéo apparaître. C'est ce test qui vérifie les maillons jamais éprouvés —
crédits, autorisations, création du job par l'app, affichage.

### 4. Vérifier la publication
La vidéo doit pouvoir partir vers les réseaux (TikTok, Reels, Shorts, YouTube), avec le
filigrane. Ce chemin existe dans le code mais n'a jamais été essayé avec une vidéo issue
de Vision v2.

### 5. Retirer Remotion et Vision v1
Un seul moteur, plus d'ambiguïté possible. À faire **après** validation du parcours, pas
avant : c'est le filet de sécurité.

### 6. Finir la mise en scène
Le changement de page quand la feuille est pleine (jamais implémenté), et le choix
manuscrit / machine exposé dans l'écran de création (le champ existe déjà de bout en
bout).

---

## Ce que je propose

Attaquer **l'étape 1** maintenant : c'est le seul point qui touche encore la **qualité
pédagogique** du produit, et il est entièrement de mon côté (une Edge Function à
redéployer). Les étapes 2 et 3 demandent une recompilation et un compte étudiant, donc
une action de ta part.

Ensuite 3, 4, puis le nettoyage et les finitions.
