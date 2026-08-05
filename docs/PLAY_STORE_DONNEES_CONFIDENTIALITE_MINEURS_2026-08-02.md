# Play Store — sécurité des données, confidentialité, mineurs (02/08/2026)

> Complète, sans les répéter, deux documents existants :
> - `PLAY_STORE_DECLARATION_MEDIA_PROJECTION.md` — déclaration d'usage du partage d'écran ;
> - `PLAY_CONSOLE_BLOCAGES_RELEASE_2026-07-31.md` — APK obsolètes, `AD_ID`, vidéo de démonstration.
>
> Ce document traite les **trois points qui n'étaient couverts nulle part** :
> le formulaire *Sécurité des données*, la politique de confidentialité, et la
> position sur les mineurs.

---

## 1. Ce que l'application envoie réellement à un tiers

C'est le point de départ, parce que les deux sections suivantes en découlent, et
parce que l'ampleur en a été sous-estimée jusqu'ici.

**22 fonctions Edge de production transmettent du contenu utilisateur à
OpenRouter**, qui le relaie lui-même vers des fournisseurs de modèles
(Anthropic, OpenAI, Google…) :

| Fonction | Ce qui part |
|---|---|
| `bobodo-chat`, `prep-tutor-chat`, `td-tutor-chat` | conversations de l'élève avec le tuteur |
| `prep-grade-assignment` | **le travail rendu par l'élève et sa correction** |
| `learning-session-summary` | chat de séance, déroulé, **notes du conseiller** |
| `orientation-analyser` | profil d'orientation, objectifs, situation |
| `prep-*`, `td-*` (ingestion, génération, analyse) | documents pédagogiques déposés |
| `whiteboard-generate-storyboard`, `whiteboard-tts` | sujet demandé, texte de narration |
| `bobodo-generate-embeddings`, `prep-embed-chunks` | contenus vectorisés |

Aucun autre prestataire d'inférence n'est appelé — vérifié le 02/08/2026 :
aucune référence à `api.openai.com`, `api.anthropic.com`,
`generativelanguage`, `deepgram` ou `elevenlabs` en direct.

> **Conséquence** : ce n'est pas « la synthèse de séance envoie du texte à une
> IA ». C'est **le cœur pédagogique de l'application** qui repose sur un
> sous-traitant tiers. La politique de confidentialité doit le dire ainsi.

---

## 2. Formulaire *Sécurité des données*

À remplir dans **Play Console → Règles → Contenu de l'application → Sécurité des données**.

### Types de données à déclarer

| Catégorie | Collecté | Partagé avec un tiers | Obligatoire ? | Finalité |
|---|---|---|---|---|
| **Audio** (micro en séance) | Oui | Non | Non — lié à une fonctionnalité | Fonctionnalité de l'app |
| **Vidéo** (caméra, partage d'écran) | Oui | Non | Non — lié à une fonctionnalité | Fonctionnalité de l'app |
| **Enregistrements de séance** | Oui, **si activé** | Non | **Non — double consentement** | Fonctionnalité de l'app |
| **Messages de chat** | Oui | **Oui — OpenRouter** | Non | Fonctionnalité, personnalisation |
| **Documents déposés** (copies, devoirs) | Oui | **Oui — OpenRouter** | Non | Fonctionnalité de l'app |
| **Nom, e-mail, téléphone** | Oui | Non | Oui | Gestion du compte |
| **Identifiants de paiement** | Non (LigdiCash gère) | — | — | — |
| **Position** | **Non** | — | — | `ACCESS_FINE_LOCATION` retiré |
| **Identifiant publicitaire** | **Non** | — | — | `AD_ID` retiré |

### Le point qui joue en notre faveur

Google demande si la collecte est **facultative**. Pour l'audio et la vidéo
d'enregistrement, la réponse est oui, et l'application peut le prouver :

- l'élève donne son accord **à la réservation** (`OrientationBookingSheet`,
  case décochée par défaut, → `app_orientation_book(p_consent_recording)`) ;
- le conseiller donne le sien **en séance** ;
- **il faut les deux** pour que l'enregistrement démarre ;
- un bandeau reste affiché pendant toute la durée
  (`OrientationRecordingBanner`).

C'est un argument de conformité, pas un détail d'interface. **Le documenter
dans le formulaire, captures à l'appui.**

### Chiffrement et suppression

- ✅ « Les données sont chiffrées en transit » — HTTPS/WSS partout.
- ✅ « L'utilisateur peut demander la suppression de ses données » — la
  fonction `admin-hard-delete-user-account` et la tâche planifiée
  `purge_deleted_accounts` (quotidienne, 03h00) existent.

---

## 3. Politique de confidentialité

**C'est le motif de rejet le plus probable**, et le plus facile à éviter.

La politique doit mentionner explicitement :

1. **La communication de données personnelles à un sous-traitant tiers**
   — nommer OpenRouter, indiquer qu'il relaie vers des fournisseurs de modèles,
   et préciser quels contenus partent (cf. tableau du §1). Une politique qui
   parle vaguement d'« intelligence artificielle » sans nommer le destinataire
   ne satisfait pas l'exigence.
2. **Le transfert hors de la zone de résidence** — les serveurs d'inférence ne
   sont ni au Burkina Faso ni en Afrique de l'Ouest.
3. **L'enregistrement des séances** — sur double consentement, sa durée de
   conservation, et comment le retirer.
4. **Le partage d'écran** — ce qui est capturé, à qui c'est diffusé, et le fait
   que rien n'est conservé hors enregistrement explicite.
5. **Un contact** pour l'exercice des droits.

L'URL doit être **accessible publiquement, sans authentification**, et déclarée
à l'identique dans la fiche Play Store et dans l'application.

---

## 4. Contenu destiné aux enfants — la question à trancher avant de soumettre

Academia vise des collégiens et lycéens. **C'est une décision produit, pas une
case à cocher**, et elle doit être prise en connaissance de cause.

### Les deux voies

**A. Déclarer « Non destiné aux enfants »** (public 18+ ou 13+ selon le pays)
- Les règles *Families* ne s'appliquent pas.
- Mais il faut alors **empêcher réellement** l'inscription des mineurs —
  vérification d'âge à la création de compte. Déclarer 18+ tout en accueillant
  visiblement des lycéens est un motif de suspension, plus grave qu'un refus.

**B. Déclarer un public incluant les mineurs**
- Les règles *Families* s'appliquent : pas de publicité ciblée (déjà le cas —
  aucune régie), consentement parental vérifiable, et surtout…
- **La visioconférence ouverte adulte ↔ mineur est particulièrement scrutée.**

### Le point sensible : la consultation individuelle

Le mode **orientation individuelle** met un adulte et un mineur seuls dans une
salle audio/vidéo. C'est exactement la configuration que Google examine de près.

Éléments déjà en place à faire valoir :
- le conseiller est un **compte créé par un administrateur**
  (`admin-create-orientation-counselor`), pas un inscrit libre ;
- l'entretien naît d'une **réservation tracée** (`orientation_bookings`) ;
- l'enregistrement exige **un double consentement** ;
- la modération serveur permet de couper ou d'exclure à distance
  (`livekit-moderate`).

Éléments **absents**, à décider :
- aucun consentement parental n'est demandé avant une consultation individuelle ;
- aucune vérification d'âge à l'inscription ;
- aucune option « un parent assiste à l'entretien ».

> **Recommandation** : trancher cette question **avant** de soumettre, pas après
> un refus. Un rejet sur le motif « Families » entraîne un réexamen manuel long,
> et un second rejet sur le même motif peut suspendre le compte développeur.

---

## 5. Ordre de traitement

1. **Politique de confidentialité** — la réécrire avec le §1 sous les yeux.
   C'est le préalable : le formulaire *Sécurité des données* doit y correspondre.
2. **Formulaire Sécurité des données** — le remplir d'après le §2.
3. **Position sur les mineurs** — trancher le §4, ajuster l'inscription si voie A.
4. **Vidéo de démonstration** et **déclaration media projection** — voir
   `PLAY_STORE_DECLARATION_MEDIA_PROJECTION.md`.

---

## 6. Ce que ce document ne traite pas

- La rédaction juridique de la politique elle-même : le §3 en donne le contenu
  obligatoire, pas la formulation. Elle engage l'entreprise.
- Les conditions d'utilisation.
- Le contrat de sous-traitance avec OpenRouter, si le RGPD s'applique à une
  partie du public (diaspora en Europe).
