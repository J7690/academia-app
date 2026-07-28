# Studio de live du conseiller d'orientation — état des lieux et plan

**Date :** 27 juillet 2026
**Objet :** ce qui est déjà en place, ce qui manque réellement, et dans quel ordre le construire.

---

## Partie I — Ce qui existe déjà

Avant de proposer quoi que ce soit : le studio **n'est pas** un bloc monolithique
qu'on aurait collé tel quel sur le conseiller. Il est déjà paramétrable.

### 1. Le studio se plie déjà à six drapeaux de capacité

`academia_classroom_screen.dart` lit six booléens portés par la session, et la
barre de contrôles ne montre que ce qui est autorisé :

| Capacité | Où c'est lu |
|---|---|
| chat, quiz, tableau blanc | lignes 680, 693, 709 — panneaux conditionnels |
| partage d'écran, main levée, enregistrement | barre de contrôles, lignes 102-125 |

### 2. La consultation d'orientation règle déjà ces six drapeaux

`app_orientation_book` ne crée pas une session générique. Elle écrit :

| Capacité | Valeur | Motif inscrit dans la fonction |
|---|---|---|
| Chat | **activé** | partager un lien, un nom d'établissement |
| Partage d'écran | **activé** | montrer un site d'établissement, un dossier |
| Quiz | désactivé | sans objet |
| Tableau blanc | **désactivé** | « sans objet » |
| Main levée | désactivée | sans objet en tête-à-tête |
| Enregistrement | **désactivé** | conversation personnelle |

Elle fixe aussi `max_participants = 2`, nomme la salle `orientation_<id>`,
place le conseiller comme hôte et inscrit l'élève comme participant.

### 3. Le reste du socle est en place

- Le conseiller entre en hôte (`isHost: true`) depuis son onglet Consultations.
- Profil LiveKit `classroom` : `adaptiveStream`, `dynacast`, `simulcast`.
- 17 RPC d'orientation, dont `app_orientation_student_file` et
  `app_orientation_upsert_record`, toutes vérifiées présentes.
- Tableau de bord conseiller à 5 onglets, fiche d'orientation structurée.
- L'architecture V1 (§8.5 et §9) avait décrit un mode `consultation` avec
  panneau contexte. **Décrit, jamais implémenté.**

**Conclusion de l'état des lieux :** le socle est bon, le paramétrage existe.
Ce qui manque n'est pas une refonte — ce sont sept pièces précises.

---

## Partie II — Les sept écarts réels

### É1. Le conseiller ne peut rien lancer — il ne fait qu'attendre

C'est l'écart que vous avez pointé, et c'est le plus structurant.

Le conseiller est **purement réactif** : une salle n'existe que si un élève a
réservé un créneau. L'enseignant, lui, dispose de
`teacher_live_sessions_screen.dart` pour créer, publier et démarrer une séance.
Le conseiller n'a aucun équivalent.

Conséquence : impossible d'animer une **séance collective d'orientation**
(« Choisir sa filière après le bac », « Les dossiers de bourse, mode d'emploi »),
impossible d'ouvrir une **consultation immédiate** pour un élève déjà en ligne,
impossible de **rouvrir** une salle après une coupure.

### É2. Le tableau blanc est désactivé alors que vous l'avez demandé

Vous aviez demandé que le conseiller ait accès au tableau. `app_orientation_book`
écrit `is_whiteboard_enabled = false`. Le bouton n'apparaît donc jamais dans la
salle. Or le tableau est utile ici : dessiner un arbre de filières, un calendrier
de concours, une trajectoire d'études.

### É3. En séance, le conseiller n'a pas le dossier de l'élève sous les yeux

`app_orientation_student_file` et `app_orientation_upsert_record` ne sont
appelées **que** depuis le tableau de bord, jamais depuis la salle. Le conseiller
doit sortir du studio, consulter, revenir.

C'est exactement ce que l'architecture V1 §9.2 voulait éviter : *« Le professeur
n'a rien à demander. La consultation commence à la minute 0 sur le fond. »*

### É4. Le résumé IA parle comme un professeur, pas comme un conseiller

Le prompt de `learning-session-summary` produit : *plan, concepts,
points de blocage, à retenir, pour aller plus loin*. Vocabulaire de cours.

Pour une orientation il faudrait : **pistes de filières évoquées, établissements
cités, échéances (dates de concours, dépôts de dossiers), prochaines étapes,
documents à réunir**. La fonction sélectionne pourtant déjà `session_type`
(ligne 141) — elle a l'information et ne s'en sert pas.

### É5. Aucun profil LiveKit adapté au tête-à-tête

Trois profils existent : `classroom`, `broadcast`, `gameplay`. Un entretien à
deux mérite une mise en page face-à-face, pas une grille conçue pour trente
vignettes.

### É6. Le consentement à l'enregistrement est un champ mort

`orientation_bookings.consent_recording` existe en base. **Il n'est ni lu ni
écrit nulle part.** L'architecture §9.4 exigeait un double consentement explicite
et un bandeau permanent à l'écran. Aujourd'hui l'enregistrement est simplement
coupé — ce qui est prudent, mais ferme la porte à l'usage légitime (l'élève qui
veut réécouter les conseils reçus).

### É7. Les séances collectives n'ont pas de modèle économique

Le circuit financier du conseiller (`actor_balances`) est branché sur les
consultations individuelles. Une séance collective payante n'a pas de règle de
facturation définie.

---

## Partie III — Plan d'implémentation

Quatre lots, ordonnés pour que chacun soit testable seul et qu'aucun ne dépende
d'un lot ultérieur.

---

### Lot A — Le conseiller peut lancer (traite É1, É2, É5)

**Base de données**

1. `app_orientation_create_session(p_titre, p_description, p_format, p_scheduled_at, p_duree, p_max, p_tableau, p_enregistrement)` — création d'une séance par le conseiller lui-même. Vérifie `app_is_orientation_counselor()`. Deux formats :
   - `individuelle` → `max_participants = 2`, mise en page face-à-face ;
   - `collective` → `max_participants` au choix (10 à 200), main levée activée.
2. `app_orientation_my_sessions()` — les séances créées par le conseiller, tous statuts.
3. Réutiliser `app_learning_set_session_status` pour le cycle brouillon → publiée → en cours → terminée. **Aucune RPC à réinventer.**
4. Corriger `app_orientation_book` : `is_whiteboard_enabled = true`.

**Flutter**

5. Nouvel onglet **« Mes séances »** dans `CounselorDashboardScreen` (6ᵉ onglet), calqué sur `teacher_live_sessions_screen.dart` mais avec les champs de l'orientation : format, thème (filières / bourses / concours / reconversion), niveau visé, places.
6. `AcademiaRoomOptions.consultation` — quatrième profil, réglé pour deux à quatre participants.
7. `AcademiaClassroomScreen` : mise en page face-à-face quand `maxParticipants <= 2`.

**Vérification :** le conseiller crée une séance collective, la publie, elle
apparaît dans l'onglet Lives des élèves, il la démarre, un élève la rejoint.

---

### Lot B — Le panneau contexte en séance (traite É3)

C'est le lot qui change le plus la valeur perçue du produit.

**Flutter, sans aucune migration**

8. Panneau latéral (desktop) / onglet (mobile) dans `AcademiaClassroomScreen`, affiché **uniquement** si `session.type == orientation` et `isHost`. Il présente :
   - le dossier de l'élève, via `app_orientation_student_file` — déjà en base ;
   - la fiche d'orientation en cours de rédaction, éditable pendant l'entretien via `app_orientation_upsert_record` — déjà en base ;
   - les fiches des séances précédentes, si l'élève en a autorisé le partage.
9. Réemployer `StudentFileSheet` et `OrientationRecordSheet` de `counselor_sheets.dart` : ils existent, ils sont adaptatifs, ils n'ont pas à être réécrits.
10. Sauvegarde automatique de la fiche toutes les 30 secondes, pour qu'une coupure réseau ne coûte pas les notes.

**Vérification :** le conseiller ouvre une consultation, voit le dossier sans
quitter la salle, écrit la fiche pendant l'entretien, la retrouve intacte dans
l'onglet Fiches.

---

### Lot C — Le résumé adapté à l'orientation (traite É4)

**Edge Function `learning-session-summary`**

11. Brancher le prompt sur `session_type`. Deux jeux de clés :
    - pédagogique (existant) : `plan, concepts, questions, points_de_blocage, a_retenir, pour_aller_plus_loin` ;
    - **orientation (nouveau)** : `synthese, pistes[] {filiere, etablissement, pourquoi}, echeances[] {quoi, quand}, documents_a_reunir[], prochaines_etapes[], points_de_vigilance[]`.
12. Fusionner le résumé généré avec la fiche rédigée à la main par le conseiller : l'IA propose, le conseiller garde la main.
13. Le PDF téléchargeable existe déjà (`session_summary_screen.dart`) — adapter la mise en page aux nouvelles clés.

**Vérification :** une consultation d'orientation produit une fiche parlant de
filières et d'échéances, pas de « concepts » ni de « points de blocage ».

---

### Lot D — Consentement, enregistrement, facturation (traite É6, É7)

14. Case de consentement à l'enregistrement au moment de la réservation (élève) et à l'ouverture de la salle (conseiller) → alimente `consent_recording`.
15. L'enregistrement ne devient possible que si **les deux** ont consenti ; bandeau rouge permanent à l'écran tant qu'il tourne.
16. Règle de facturation des séances collectives : tarif par place, crédité à la fin de la séance via `app_orientation_complete_booking`, sur le circuit `actor_balances` déjà en service.

---

## Partie IV — Ce que je ne propose délibérément pas

- **Aucune nouvelle table.** Les quatre tables d'orientation et `academia_sessions` suffisent. Le format de séance tient dans `metadata`.
- **Aucun second système financier.** `actor_balances` + `payout_queue` sont déjà branchés sur le conseiller et éprouvés.
- **Aucune réécriture du studio.** Les six drapeaux de capacité font déjà le travail ; il s'agit de les régler correctement et d'ajouter un panneau.
- **Pas de chiffrement de bout en bout** pour l'instant. L'architecture le réservait à `kind = 'psychologist'`. Tant que ce type n'est pas ouvert aux élèves, c'est une complexité sans contrepartie.

---

## Ordre d'exécution proposé

**A → B → C → D.**

Le lot A rend le conseiller autonome — c'est votre demande directe. Le lot B est
celui qui distingue vraiment Academia d'un simple Zoom. Le lot C soigne la trace
écrite. Le lot D sécurise juridiquement et ouvre les séances collectives payantes.

Chaque lot est auditable dans le même ordre que d'habitude : Flutter → Supabase →
LiveKit, avec un essai réel joué en base puis effacé.

Dites-moi si l'ordre vous convient, ou si un lot doit passer devant.
