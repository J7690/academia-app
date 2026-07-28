# Smart Whiteboard — état réel au 25 juillet 2026, fin de journée

Réponse honnête à trois questions : ce qui était attendu, ce qui est réellement en place,
et le sort de Remotion.

---

## 1. Le produit attendu, point par point

| # | Attendu (exprimé au fil de la journée) | État réel | Vérifié comment |
|---|---|---|---|
| 1 | **Écriture manuscrite progressive**, comme un prof qui écrit | ✅ en place | Vu sur images : texte en cours d'écriture, police Caveat |
| 2 | **Choix manuscrit / machine** par l'étudiant | ⚠️ **moitié** | Le champ existe de bout en bout (générateur → moteur), mais **aucune interface dans l'app** pour le choisir |
| 3 | **Cahier continu qui défile**, rien ne s'efface | ✅ en place | Vu sur images : caméra descend, contenu précédent conservé |
| 4 | **Changement de page** quand la feuille est pleine | ❌ **PAS FAIT** | C'est un rouleau infini. Jamais implémenté, ni en Remotion ni en Vision v2 |
| 5 | **Encercler / souligner** puis effacer l'annotation | ⚠️ **codé, JAMAIS VU** | Le storyboard de test ne contient **aucune** annotation : le code n'a pas pu être vérifié à l'image |
| 6 | **Surligner** (qui reste) | ⚠️ **codé, JAMAIS VU** | idem |
| 7 | **Annotations ciblées sur des mots** | ⚠️ **codé, JAMAIS VU en v2** | Validé en Remotion (image v6), pas encore en Vision v2 |
| 8 | **Rappel pédagogique** (remonter, ré-annoter, redescendre) | ⚠️ **codé, JAMAIS VU en v2** | Validé en Remotion (image v5), pas encore en Vision v2 |
| 9 | **Voix naturelle** | ✅ en place | Validé à l'écoute par toi |
| 10 | **Lecture scientifique des maths** (« f de x », intégrales…) | ✅ en place | Testé sur 9 expressions |
| 11 | **Rythme calé sur la voix**, sans temps morts | ✅ en place | ~30 s de silence supprimées sur un cours |
| 12 | **Formules mathématiques propres** | ✅ en place | KaTeX, affichage unique |
| 13 | **Générateur qui décrit la mise en scène** | ✅ en place | v36 déployé : `emphasis_target`, `write_speed`, `writing_style` |
| 14 | **Vitesse de rendu acceptable** | ✅ atteint | 1,48× le temps réel (objectif < 2×) |
| 15 | **Un seul moteur, pas d'ambiguïté** | ❌ **PAS FAIT** | Trois moteurs cohabitent sur le serveur (voir §3) |

### Ce qu'il faut retenir
- **Le socle est là** : écriture, défilement, voix, formules, rythme, vitesse.
- **Trois fonctions sont codées mais n'ont jamais été vues fonctionner dans Vision v2** :
  les annotations, le surlignage et le rappel. Raison : le storyboard de test utilisé
  pour tous les essais ne contient **ni annotation ni rappel**. C'est un angle mort de ma
  méthode de test, pas un problème connu du code.
- **Le changement de page n'a jamais été implémenté**, dans aucun moteur.

---

## 2. Remotion : écarté, mais PAS supprimé

**Décision** : abandonné (mesuré à 4-5× le temps réel, échecs mémoire répétés).

**État réel au moment d'écrire ces lignes :**

| Élément | État |
|---|---|
| Moteur Remotion sur le serveur (`/opt/whiteboard-engine-remotion`) | **toujours installé** |
| Branche `engine=remotion` dans le worker | **toujours présente** |
| Sources React (`whiteboard_engine_remotion/`) dans le dépôt | **toujours là** |
| Application : moteur demandé | **corrigé à l'instant** — était encore `remotion`, passé à `vision2` |

⚠️ **Point grave que je viens de corriger** : l'application demandait encore `remotion`.
Ce réglage datait de l'après-midi, avant l'abandon. Si tu avais recompilé l'app ce soir,
**toutes les vidéos des étudiants seraient parties sur un moteur abandonné** — donc 12 à
20 minutes de rendu, ou un échec mémoire. La valeur est maintenant `vision2`.

**Pourquoi je n'ai pas encore supprimé Remotion** : Vision v2 n'a pas encore produit un
seul rendu en conditions réelles (8 scènes, voix, annotations, rappels). Supprimer le
filet avant d'avoir vérifié que le nouveau moteur tient serait imprudent — c'est
exactement l'erreur qu'on a évitée ce matin avec Vision v1.

**Quand le supprimer** : après un rendu complet réussi et validé visuellement par toi.
La suppression est alors simple et je la ferai proprement (archive, retrait de la branche
du worker, mise à jour de la documentation).

---

## 3. Trois moteurs cohabitent encore

| Moteur | Rôle actuel | Sort prévu |
|---|---|---|
| **Vision v1** (une image par scène) | moteur de production actuel | à retirer après validation de v2 |
| **Vision v2** (cahier filmé) | prêt, jamais utilisé en production | devient le seul moteur |
| **Remotion** | abandonné | à supprimer après validation de v2 |

C'est une situation transitoire assumée, mais elle ne doit pas durer : c'est
précisément cette ambiguïté qui a fait perdre une journée.

---

## 4. Ce qu'il reste à faire, dans l'ordre

1. **Déployer Vision v2 sur le worker** (brief prêt).
2. **Rendre le cours complet « la continuité »** — 8 scènes, voix, annotations ciblées,
   2 rappels. C'est ce rendu qui vérifiera enfin les points 5 à 8 du tableau.
3. **Validation visuelle par le propriétaire.**
4. **Implémenter le changement de page** (point 4, jamais fait).
5. **Exposer le choix manuscrit / machine dans l'app** (point 2).
6. **Supprimer Remotion et Vision v1**, mettre à jour la documentation.
7. Recompiler l'application.
