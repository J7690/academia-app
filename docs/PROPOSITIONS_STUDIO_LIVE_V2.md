# Studio Live — audit d'approfondissement et propositions

**Date** : 26 juillet 2026
**Objet** : caméra, partage d'écran, synthèse IA, rôle conseiller d'orientation, et modernisation
**Méthode** : audit du code et de la base, puis recherche sur l'état de l'art 2026

---

## 1. Votre demande, telle que je la comprends

| # | Demande | Ce que j'en retiens |
|---|---|---|
| 1 | Rendre le Studio plus abouti et plus moderne | Chercher l'état de l'art 2026 et proposer ce qui manque |
| 2 | La caméra n'offre que « couper » et « caméra avant » | Les grandes plateformes proposent-elles la caméra arrière ? |
| 3 | Le partage d'écran façon Teams | Est-il en place ? Et le renforcer avec plus d'options |
| 4 | Brancher OpenRouter pour une synthèse de séance | Résumé de ce qu'a dit l'enseignant et des questions posées, téléchargeable en PDF, par l'enseignant **et** les participants |
| 5 | Sortir l'orientation du Studio actuel | Créer un rôle conseiller d'orientation, avec un studio aux champs et outils différents — le modèle « cours » et « prépa concours » ne convient pas |

---

## 2. Audit — ce qui existe vraiment

### 2.1 Caméra — vous avez raison, et le manque est total

Recherche dans tout le code : **zéro occurrence** de `switchCamera`, `CameraPosition` ou `cameraPosition`. Il n'existe que `setCameraEnabled(true/false)`. L'utilisateur est donc bloqué sur la caméra frontale, sans aucun moyen de basculer.

**Ce que font les autres** : Zoom propose la bascule avant/arrière depuis des années, d'un seul appui sur une icône en haut à gauche de l'écran mobile. C'est un geste attendu, pas une option avancée.

**Pourquoi c'est plus important chez vous qu'ailleurs.** Dans un contexte où beaucoup d'enseignants travaillent au papier et au stylo, la caméra arrière n'est pas un confort : c'est la **caméra-document**. Elle permet de filmer un exercice manuscrit, une copie corrigée, une manipulation, un tableau de salle physique. Sans elle, un professeur qui veut montrer sa résolution écrite n'a aucun moyen de le faire — ni caméra arrière, ni partage d'écran fonctionnel (voir ci-dessous).

C'est aujourd'hui le plus gros trou fonctionnel du Studio, et il se corrige en peu de code.

### 2.2 Partage d'écran — le code existe, mais il est cassé sur Android

Le code applicatif est là et bien fait : `setScreenShareEnabled()`, une vue dédiée `AcademiaScreenShareView` qui détecte la piste `TrackSource.screenShareVideo` locale ou distante, et bascule l'affichage en mode focus.

**Mais il ne peut pas fonctionner sur Android.** Trois éléments manquent, tous obligatoires :

| Élément requis | État |
|---|---|
| `FOREGROUND_SERVICE` | **explicitement retiré** — `tools:node="remove"` |
| `FOREGROUND_SERVICE_MEDIA_PROJECTION` | **explicitement retiré** — `tools:node="remove"` |
| Service avec `foregroundServiceType="mediaProjection"` | absent du manifeste |
| Paquet `flutter_background` (ou équivalent) | absent de `pubspec.yaml` |

Depuis Android 14 (API 34), lancer une capture d'écran sans service de premier plan de type `mediaProjection` lève une `SecurityException` et fait planter l'application. Votre `targetSdk` est **35**. Le partage d'écran ne peut donc pas démarrer — au mieux il échoue en silence, au pire il fait tomber l'app.

**Et il y a plus gênant.** L'audit des permissions Play Store du 4 juin 2026 listait ces deux permissions avec la mention explicite :

> `FOREGROUND_SERVICE` — Utilisée : ✅ OUI — Screen recording gameplay capture — À retirer : ❌ NON (feature active)

L'audit disait donc **de ne pas les retirer**. Elles l'ont été quand même. Cela n'a pas seulement cassé le partage d'écran : l'enregistrement de gameplay des Challenges repose sur le même mécanisme et est probablement inopérant lui aussi.

### 2.3 OpenRouter — déjà entièrement câblé

Bonne nouvelle, et elle change l'estimation d'effort. `OPENROUTER_API_KEY`, `OPENROUTER_MODEL` et `OPENROUTER_FALLBACK_MODEL` sont en place, avec bascule automatique sur le modèle de repli, et déjà consommés par **dix Edge Functions** : `academia-ai-assistant`, `bobodo-chat`, `prep-generate-questions`, `prep-grade-assignment`, `prep-compose-exam-blanc`, et d'autres.

La synthèse de séance n'est donc pas une plomberie à monter. C'est **une fonction à écrire** au-dessus d'une tuyauterie qui tourne déjà en production.

### 2.4 Orientation — un module existe déjà, mais hors du Studio et hors du dépôt

Deux tables sont en base, vides pour l'instant :

- `app.orientation_leads` — nom, téléphone, canal préféré, message, statut, commercial assigné, consentement
- `app.orientation_responses` — profil, objectif, recommandation, meilleure piste, score, modèle IA utilisé

Et **trois Edge Functions déployées** : `orientation-analyser`, `orientation-result`, `orientation-lead`.

Or ces trois fonctions **n'existent pas dans le dépôt Git**. Elles ont été déployées depuis ailleurs — probablement le site vitrine. C'est une nouvelle dérive du même type que celles trouvées en vague 0 : du code en production que le dépôt ignore.

Par ailleurs, le module Prépa dispose de `prep_psychotech_profiles` et `prep_psychotech_results` — un test psychotechnique déjà construit, qui est exactement la matière première d'une consultation d'orientation.

**Votre intuition est juste** : l'orientation existe comme parcours d'acquisition (un test en ligne qui génère un contact commercial), mais pas du tout comme accompagnement humain. Et la plaquer dans un studio conçu pour un cours de mathématiques n'a effectivement aucun sens.

---

## 3. Proposition 1 — La caméra

### 3.1 Bascule avant / arrière

Un bouton dans la barre de contrôle, qui appelle `setCameraPosition` sur la piste vidéo locale. Icône `Icons.flip_camera_ios`, geste d'un appui.

Sur mobile uniquement — masqué sur desktop et web, où la notion n'a pas de sens.

### 3.2 Mode caméra-document

C'est la proposition qui a le plus de valeur pédagogique pour votre contexte.

Un mode dédié, activable par l'hôte, qui en un geste :

- bascule sur la caméra arrière
- passe la résolution au maximum disponible plutôt qu'au débit adaptatif habituel — on veut lire une écriture manuscrite, pas voir un visage
- désactive la symétrie horizontale de l'aperçu (sinon le texte s'affiche à l'envers pour l'enseignant)
- épingle automatiquement ce flux en grand pour tous les participants, comme un partage d'écran
- affiche un repère de cadrage pour aider à poser le téléphone au-dessus de la feuille

Aucune plateforme grand public ne propose exactement cela. Zoom laisse basculer la caméra, mais ne fait rien de plus : ni verrouillage de la mise au point, ni épinglage, ni résolution privilégiée.

Pour un enseignant burkinabè qui corrige un exercice au stylo, **c'est la fonctionnalité la plus utile de tout le Studio**.

### 3.3 Sélecteur de caméra sur ordinateur

Sur desktop, une liste déroulante des périphériques disponibles — webcam intégrée, webcam externe, caméra USB de document. `Hardware.instance.enumerateDevices()` du SDK le permet.

---

## 4. Proposition 2 — Le partage d'écran

### 4.1 D'abord le réparer

Rien ne sert d'ajouter des options tant que la base ne démarre pas. Trois actions :

1. Restaurer les deux permissions dans le manifeste — en retirant les `tools:node="remove"`
2. Déclarer un service de premier plan `foregroundServiceType="mediaProjection"`
3. Ajouter `flutter_background`, demander `Helper.requestCapturePermission()` avant de lancer la capture, et n'appeler `setScreenShareEnabled(true)` que si elle est accordée

**Point d'attention Play Store** : depuis 2024, Google exige une déclaration justifiant l'usage d'un service de premier plan `mediaProjection` dans la Play Console, avec une vidéo de démonstration. Ce n'est pas bloquant, mais c'est une étape administrative à ne pas découvrir la veille d'une publication. C'est vraisemblablement pour éviter cette contrainte que les permissions ont été retirées — au prix de deux fonctionnalités.

Ce point mérite votre arbitrage explicite avant que je touche au manifeste.

### 4.2 Ensuite l'enrichir, façon Teams

| Option | Ce que fait Teams | Proposition Academia |
|---|---|---|
| Portée du partage | Écran entier, une fenêtre, un onglet | Idem sur desktop ; sur mobile, écran entier ou une application |
| **Annotation sur le contenu partagé** | Depuis mars 2026, y compris sur une fenêtre seule | Réutiliser le moteur de tableau blanc **déjà écrit**, en surcouche du flux partagé |
| Donner le contrôle | Le présentateur cède la main | Version pédagogique : l'enseignant invite un étudiant à annoter, pas à piloter la machine |
| Modes présentateur | Standout, côte à côte, reporter | Vignette de l'enseignant incrustée sur le contenu partagé |
| Épingler | Mettre un flux en avant | L'hôte épingle un participant ou le partage pour tous |
| Partage audio | Son de l'ordinateur inclus | Nécessaire dès qu'on projette une vidéo |

**L'annotation collaborative est le meilleur rapport valeur/effort du lot** : le tableau blanc existe déjà, avec sa synchronisation par canal de données. Il suffit de le rendre transparent et de le superposer au flux partagé. Deux jours de travail pour une fonctionnalité que Teams n'a livrée qu'en mars 2026.

---

## 5. Proposition 3 — La synthèse IA et le PDF

### 5.1 Le problème de la matière première

Pour résumer ce qui a été dit, il faut d'abord le capter. Deux voies, très différentes en coût.

**Voie A — transcription en temps réel.** Un agent LiveKit rejoint la salle, transcrit en continu, publie les sous-titres et alimente le transcript. Complet, mais **~0,01 $/minute d'agent**, soit vingt fois le coût d'un participant humain. Une séance de 90 minutes coûte 0,90 $ d'agent, à quoi s'ajoute le modèle de langue.

**Voie B — synthèse sans transcription.** On résume à partir de ce qu'on a déjà et qui ne coûte rien :

- le chat persistant, qui contient les questions des étudiants (livré en vague 0)
- les quiz posés et leurs résultats
- les instantanés du tableau blanc
- le titre, la description, la matière, le chapitre rattaché
- les événements de séance : qui a levé la main, quand, sur quoi

**Ma recommandation : commencer par la voie B.** Elle produit déjà un document utile — les questions posées, les points travaillés, les résultats de quiz, le contenu du tableau — pour un coût d'inférence de quelques centimes par séance. La transcription vocale s'ajoutera en option activable par l'enseignant, une fois le circuit du PDF rodé.

Cela évite d'engager 0,90 $ par séance avant même de savoir si le document produit sert à quelqu'un.

### 5.2 Ce que contient la fiche de séance

Structure proposée, générée par OpenRouter sur le modèle déjà configuré :

1. **Résumé** en dix lignes
2. **Plan de la séance** avec minutages
3. **Concepts clés et définitions** énoncés
4. **Questions posées par les participants**, avec les réponses apportées — c'est la partie que vous demandez explicitement, et c'est la plus précieuse à la relecture
5. **Résultats des quiz**, avec les questions les moins réussies mises en avant
6. **Instantanés du tableau blanc** insérés en images
7. **Quiz de révision auto-généré** — 5 questions ; `prep-generate-questions` existe déjà et sait le faire
8. **Exercices recommandés** depuis la banque TD ou prépa

### 5.3 Deux versions du même document

C'est un point que les plateformes généralistes ratent, et qui compte en pédagogie.

| Destinataire | Ce qu'il reçoit |
|---|---|
| **Étudiant** | Résumé, plan, concepts, questions et réponses, quiz de révision, ses propres notes. Rien sur les autres. |
| **Enseignant** | Tout ce qui précède, plus : taux de présence, courbe de participation, questions restées sans réponse, nombre de « je n'ai pas compris » par moment de la séance, résultats de quiz par question |

Le même transcript, deux lectures. L'étudiant révise, l'enseignant ajuste son cours suivant.

### 5.4 Fabrication et distribution

- Nouvelle Edge Function `learning-session-summary`, sur le patron de `academia-ai-assistant`
- Déclenchée à la clôture de la séance, ou à la demande
- Résultat rangé dans `academia_session_summaries`, en JSON structuré — pas en texte figé, pour pouvoir régénérer le PDF sans rappeler le modèle
- PDF produit côté application, déposé dans Supabase Storage, lien de téléchargement dans la fiche de séance et notifié par push
- L'enseignant peut **relire et corriger** le résumé avant publication aux étudiants. Un résumé IA erroné diffusé sous l'autorité d'un professeur, c'est un problème pédagogique — le contrôle humain n'est pas optionnel.

### 5.5 Coût réel

Sur le modèle de repli économique déjà configuré, une séance de 90 minutes en voie B coûte de l'ordre de **quelques centimes**. Même à cent séances par mois, on reste sous les 5 $. La voie A avec transcription porterait cela à environ 90 $ pour cent séances.

---

## 6. Proposition 4 — Le rôle conseiller d'orientation

Votre analyse est la bonne : l'orientation n'est pas une matière. Elle n'a ni chapitre, ni exercice, ni quiz, ni tableau blanc. La forcer dans le moule « cours » produit un formulaire dont trois quarts des champs sont vides.

### 6.1 Ce qui change par rapport à une séance de cours

| | Séance de cours | Consultation d'orientation |
|---|---|---|
| Format | 1 enseignant → 25 étudiants | 1 conseiller → 1 élève, ou une famille |
| Champs à saisir | matière, chapitre, cours rattaché | niveau scolaire, filières envisagées, contraintes |
| Outils en séance | tableau blanc, quiz, exercices | comparateur de filières, calendrier des concours, fiche de synthèse |
| Enregistrement | optionnel | **désactivé par défaut**, consentement explicite requis |
| Confidentialité | séance collective | conversation privée, chiffrement de bout en bout |
| Livrable | fiche de révision | **fiche d'orientation personnalisée** |
| Accès | inscription au cours | rendez-vous réservé |

### 6.2 Le rôle

Nouveau rôle `orientation_counselor`, distinct de `instructor` et de `td_teacher`, avec sa propre table de profil :

```
app.orientation_counselors
  user_id, full_name, specialites[], niveaux_couverts[],
  langues[], bio, tarif, note_moyenne, est_actif
```

Spécialités : filières scientifiques, filières littéraires, concours de la fonction publique, études à l'étranger, reconversion, écoles professionnelles.

### 6.3 Le studio en mode orientation

Le même `AcademiaClassroomScreen`, reconfiguré par la matrice de capacités — pas un second écran.

Ce qui disparaît : quiz, tableau blanc, exercices, réactions emoji, main levée, compteur de spectateurs.

Ce qui apparaît, dans le panneau latéral :

- **Le dossier de l'élève** : niveau, série, résultats, et surtout **son profil psychotechnique** s'il a passé le test — `prep_psychotech_profiles` existe déjà et n'est exploité nulle part
- **Le comparateur de filières** : deux ou trois pistes côte à côte, avec débouchés, durée, coût, établissements
- **Le calendrier** des concours et dates d'admission pertinents
- **La fiche d'orientation** que le conseiller remplit pendant l'entretien et qui devient le livrable

### 6.4 La fiche d'orientation

C'est ce que l'élève et sa famille emportent. Générée en PDF, elle contient :

- la synthèse du profil, croisant le test psychotechnique et l'entretien
- trois pistes recommandées, argumentées, classées
- pour chacune : établissements, durée, coût estimé, débouchés, conditions d'admission
- le calendrier des échéances à ne pas manquer
- les prochaines étapes concrètes
- les notes du conseiller

Cette fiche est **le produit vendable** de l'orientation. Un entretien laisse un souvenir ; une fiche circule dans la famille, se relit, se compare.

### 6.5 Le parcours

```
Test psychotechnique en ligne  (existe déjà, prep_psychotech_*)
        ↓
Résultat + proposition de rendez-vous avec un conseiller
        ↓
Choix du conseiller selon spécialité, langue, disponibilité
        ↓
Consultation en Studio, mode orientation, dossier pré-chargé
        ↓
Fiche d'orientation en PDF
        ↓
Suivi : point d'étape à 3 mois
```

Le premier maillon existe. Le dernier est ce qui transforme une consultation en accompagnement — et en abonnement plutôt qu'en acte unique.

### 6.6 Et les tables existantes ?

`orientation_leads` et `orientation_responses` sont vides et servent l'acquisition depuis le site vitrine. Elles restent en place. Le nouveau dispositif les prolonge : un `orientation_lead` qualifié devient une demande de rendez-vous, puis une consultation.

**À traiter au passage** : les trois Edge Functions `orientation-*` déployées mais absentes du dépôt. Il faut les rapatrier dans Git, sinon un futur redéploiement les écrasera ou les perdra. C'est exactement le scénario qui a fait perdre trois mois à `livekit-token`.

---

## 7. Proposition 5 — Ce qui rendrait le Studio moderne

Trié par rapport valeur/effort, du meilleur au plus coûteux.

### Rang 1 — Effort faible, effet immédiat

| Fonctionnalité | Pourquoi |
|---|---|
| **Suppression de bruit** | Incluse dans LiveKit Cloud sur toutes les offres, y compris gratuite. C'est un réglage, pas un développement. Sur un fond de ventilateur, de rue ou de cour d'école, la différence est spectaculaire. |
| **Bascule avant/arrière** | Voir section 3 |
| **Indicateur de qualité réseau** | Une pastille par participant. Quand ça rame, savoir si c'est soi ou l'autre évite dix minutes perdues. |
| **Salle d'attente avant d'entrer** | Vérifier micro, caméra et son avant de débarquer dans le cours. Standard chez Zoom et Meet. |
| **Sous-titres en direct** | Compréhension en français académique pour des étudiants dont ce n'est pas la langue première, et secours quand l'audio décroche |

### Rang 2 — Effort moyen, forte différenciation

| Fonctionnalité | Pourquoi |
|---|---|
| **Mode caméra-document** | Voir 3.2. Personne ne le fait, et c'est ce dont vos enseignants ont le plus besoin. |
| **Annotation sur écran partagé** | Le moteur existe déjà. Teams ne l'a livré qu'en mars 2026. |
| **Bouton « je n'ai pas compris »** | Anonyme, agrégé en direct. Aucune plateforme grand public ne l'offre. |
| **Fiche de séance en PDF** | Voir section 5 |
| **Arrière-plan flouté** | Un enseignant qui donne cours depuis chez lui ne veut pas montrer sa chambre. Frein réel à l'adoption. |
| **Mode faible débit pédagogique** | Audio + tableau + sous-titres à 40 kb/s. Déjà décrit dans l'architecture. |

### Rang 3 — Effort élevé, à réserver

| Fonctionnalité | Réserve |
|---|---|
| Sous-groupes et circulation entre eux | Utile en atelier, mais lourd et inutile tant que les effectifs sont faibles |
| Traduction en direct | Techniquement disponible chez LiveKit ; l'intérêt dépend d'un vrai besoin multilingue |
| Audio spatial | Effet marketing, gain pédagogique nul |
| Salle de classe en réalité virtuelle | Sans objet pour votre parc d'appareils |

### Sur le style

Trois choses feront plus pour la perception de modernité que n'importe quelle fonctionnalité :

1. **Un écran de connexion soigné** — animation de progression, nom de la séance, aperçu de sa caméra. Aujourd'hui il y a un indicateur de chargement nu. C'est le premier écran que voit l'utilisateur.
2. **Des transitions fluides** entre grille, focus et tableau blanc, au lieu d'un remplacement sec.
3. **Des états vides qui parlent** — « Le professeur n'a pas encore démarré, vous serez prévenu » plutôt qu'un écran gris.

---

## 8. Plan proposé

| Lot | Contenu | Durée |
|---|---|---|
| **L1 — Caméra** | Bascule avant/arrière, mode caméra-document, sélecteur desktop | 2 à 3 jours |
| **L2 — Partage d'écran** | Réparation Android, annotation, épinglage, partage audio | 4 à 5 jours ⚠️ arbitrage Play Store requis |
| **L3 — Fiche de séance** | Edge Function, PDF, deux versions, relecture enseignant | 4 à 5 jours |
| **L4 — Orientation** | Rôle, profils, disponibilités, mode studio, fiche d'orientation | 1,5 à 2 semaines |
| **L5 — Modernisation rang 1** | Bruit, qualité réseau, salle d'attente, sous-titres, écran de connexion | 3 à 4 jours |
| **L6 — Modernisation rang 2** | Arrière-plan flouté, « je n'ai pas compris », faible débit | 1 semaine |

Les lots L1, L3 et L5 sont indépendants et peuvent avancer en parallèle. L2 attend votre décision sur Play Store. L4 est le plus gros mais aussi le plus différenciant commercialement.

**Si je devais n'en faire qu'un** : L1. Le mode caméra-document débloque une pratique que vos enseignants ont aujourd'hui, sur papier, et qu'ils ne peuvent pas montrer.

---

## 9. Ce que je recommande de ne pas faire

- **La transcription temps réel dès maintenant.** Vingt fois le coût d'un participant. Commencer par la synthèse sans transcription, mesurer si le document sert, puis décider.
- **Les cadeaux virtuels et la monétisation du live** avant d'avoir des séances régulières. Le circuit économique existe, mais il n'a rien à monétiser tant qu'il n'y a pas d'audience.
- **Les sous-groupes** avant d'avoir dépassé la vingtaine de participants par séance.
- **Multiplier les modes de session.** Six suffisent. Chaque mode supplémentaire est une matrice de capacités à maintenir et un chemin de test de plus.

---

## 10. Deux points qui appellent votre décision

**Le partage d'écran et Play Store.** Restaurer les permissions implique une déclaration en Play Console avec vidéo de démonstration. C'est votre arbitrage : accepter cette contrainte administrative pour récupérer le partage d'écran **et** l'enregistrement de gameplay, ou renoncer aux deux. Je penche pour la restauration — l'enregistrement des Challenges est déjà en production et le partage d'écran est une attente de base d'un enseignant.

**Les trois Edge Functions orientation absentes du dépôt.** Elles tournent en production sans que Git en ait trace. C'est le même mécanisme qui a laissé `livekit-token` figée trois mois. Je peux les rapatrier — dites-moi si je le fais.
