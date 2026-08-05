# Audit — notifications reçues par le compte manager

**Date :** 4 août 2026
**Compte audité :** `nassiroumaiga@outlook.com` — Nassirou Maiga — rôle `manager` — id `d611c916-8ade-4e1c-91e8-2f1756c0b893`
**Nature :** lecture seule, aucune modification.

> Je n'ai pas pu visionner la vidéo (`.mp4` non lisible par mes outils). Ce rapport
> établit ce que son téléphone a **prouvablement** reçu. Une capture d'écran
> permettrait de rattacher au libellé exact ce qui est décrit ci-dessous.

---

## 1. Réponse : ce n'est pas son compte qui reçoit, c'est son téléphone

Le compte `manager` n'a reçu, **en tout et pour tout, 2 notifications** depuis sa création (3 janvier 2026) :

| Domaine | Type | Date |
|---|---|---|
| `student_home` | `new_content` | 13 mars 2026 |
| `student_opportunities` | `new_opportunity` | 2 mars 2026 |

Deux notifications d'**étudiant**, vieilles de cinq mois, résidus de l'époque où ce compte n'était pas encore manager. **Aucune notification de paiement n'a jamais été adressée à ce compte.**

Ce qu'il voit ne lui est pas destiné : **son téléphone est enregistré comme appareil de réception d'un compte administrateur.**

---

## 2. Le mécanisme, prouvé

Son téléphone porte le jeton FCM `fCsTqP9IwheJYGP41i…`. Ce même jeton — **le même appareil physique** — est enregistré et **actif** pour quatre comptes :

| Compte | Rôle | Actif | Enregistré | Mis à jour |
|---|---|---|---|---|
| `nassiroumaiga@outlook.com` | manager | ✅ | 22/07 | 22/07 |
| `nassiroumaiga@outlook.com` | manager | ✅ | 22/07 | 24/07 |
| `kayadejule@gmail.com` | commercial | ✅ | 30/07 | 30/07 |
| **`wendenkoote@gmail.com`** | **admin** | ✅ | **24/07** | **30/07** |

Quand un déclencheur met un événement en file pour l'administrateur `wendenkoote@gmail.com`, `send-push-notifications` cherche « les jetons actifs de cet utilisateur » — et trouve **le téléphone de Nassirou**. Firebase livre au jeton, pas au compte. Le téléphone sonne.

Noter aussi que le compte de Nassirou apparaît **deux fois** pour le même jeton : chaque notification qui lui est destinée lui parvient donc en double.

---

## 3. Ce que son téléphone a réellement reçu

Via le compte administrateur, depuis que le jeton est actif (24 juillet) :

| Domaine | Type | Volume | Dernier |
|---|---|---|---|
| `admin_audience` | digest d'activité | **186** | 3 août 15:00 |
| `admin_accounts` | nouveau compte | **175** | 3 août 11:44 |
| `admin_support` | nouvelle conversation | 16 | 25 juillet |
| `admin_applications` | nouvelle candidature | 11 | 3 août 12:44 |
| `admin_applications` | message | 17 | 23 juillet |
| **`admin_payments`** | **paiement** | **68** | **19 juillet** |

**Précision importante et honnête** : les 68 notifications de paiement portent des dates allant jusqu'au **19 juillet**, soit *avant* que son téléphone ne soit enregistré pour le compte admin (24 juillet). Aucun paiement n'a bougé en base depuis le 19 juillet — il n'y a donc eu aucune notification de paiement à distribuer depuis.

Deux lectures possibles de ce qu'il a montré :
- des notifications **encore présentes dans le volet Android**, antérieures ;
- ou des notifications **d'un autre type** lues comme des paiements — `admin_accounts` (« 👤 Nouveau compte créé ») et surtout `admin_audience` (« 📊 Activité sur Academia »), qui arrive **toutes les 15 minutes**, 186 fois.

Dans tous les cas, la conclusion structurelle ne change pas : **dès qu'un paiement bougera, la notification partira sur son téléphone.** Le canal est ouvert aujourd'hui.

---

## 4. Les deux défauts qui produisent cela

### a) L'enregistrement n'exclut personne

`app_register_device_token` :

```sql
ON CONFLICT (user_id, fcm_token) DO UPDATE SET is_active = TRUE, ...
```

L'unicité porte sur le **couple** utilisateur + jeton. Un même appareil peut donc appartenir à un nombre illimité de comptes, **tous actifs simultanément**. La fonction ne désactive jamais ce jeton pour les autres comptes.

Il manque une ligne : lors de l'enregistrement, désactiver le même `fcm_token` partout ailleurs. Un appareil n'appartient qu'à une session à la fois.

### b) La déconnexion ne nettoie rien

`app_unregister_device_token` **existe** et fait exactement ce qu'il faut… **et n'est appelée par aucun fichier Dart.** Vérifié sur l'ensemble du code.

Les trois `signOut()` de l'application ([auth_wrapper.dart:306](academia_app/lib/features/auth/auth_wrapper.dart:306), [student_settings_screen.dart:130](academia_app/lib/features/student/student_settings_screen.dart:130), [student_delete_account_screen.dart:110](academia_app/lib/features/student/student_delete_account_screen.dart:110)) déconnectent la session **sans désenregistrer l'appareil**. Le jeton reste actif pour le compte quitté, indéfiniment.

L'application ne fait que `reRegisterTokenAfterLogin()` — elle ajoute, elle ne retire jamais.

---

## 5. Ampleur : ce n'est pas un cas isolé

| Mesure | Valeur |
|---|---|
| Lignes dans `user_device_tokens` | 338 |
| dont actives | 209 |
| Appareils physiques distincts | 235 |
| **Appareils actifs partagés entre plusieurs comptes** | **35** |
| Appareils actifs partagés entre plusieurs **rôles** | 33 |
| **Appareils portant une inscription admin active à côté d'un non-admin** | **24** |

Un appareil détient le record : **8 comptes** enregistrés, couvrant les rôles admin, commercial, instructor, merchant, student et university — dont 5 encore actifs.

---

## 6. Pourquoi c'est sérieux

Ce n'est pas un défaut de confort, c'est une **fuite de données**. Le contenu des notifications administrateur porte :

- `admin_payments` → **nom de l'étudiant, montant, motif, programme** ;
- `admin_applications` → nom de l'étudiant et programme visé ;
- `admin_support` → **extrait du message de support** (`content_preview`) ;
- `admin_accounts` → **rôle et adresse e-mail** de chaque compte créé — 175 depuis le 24 juillet.

Ces informations partent aujourd'hui vers des téléphones dont le porteur n'est pas le destinataire prévu, et qui n'ont pas les droits correspondants. **24 appareils sont dans ce cas avec un compte administrateur.**

C'est aussi un point à traiter avant la soumission Play Store : le formulaire *Sécurité des données* engage sur qui reçoit quoi.

---

## 7. Ce que je recommande

**Immédiat — refermer le canal.** Désactiver les inscriptions d'appareil en doublon : pour chaque `fcm_token`, ne garder active que la plus récente. Une requête, effet immédiat, aucune version d'application à publier. Les utilisateurs légitimes se réenregistrent seuls à la prochaine ouverture.

**Correctif de fond — deux gestes.**
1. Dans `app_register_device_token` : avant l'`INSERT`, passer `is_active = FALSE` sur toutes les lignes portant le même `fcm_token` pour un autre `user_id`. Un appareil, une session.
2. Appeler `app_unregister_device_token` **avant** chaque `signOut()`, aux trois endroits concernés.

**Hygiène.** Purger les jetons inactifs de plus de 90 jours, et ajouter une contrainte d'unicité sur `fcm_token` seul plutôt que sur le couple — la base refuserait alors structurellement ce que le code a laissé passer.

**Sans rapport avec ce défaut mais toujours valable** : le déclencheur `app_notify_admin_payment_declared` notifie sur chaque changement de statut sans filtrer (cf. `AUDIT_PAIEMENT_ET_NOTIFICATIONS_2026-08-04.md`, §1). Les deux corrections sont indépendantes et se cumulent : l'une réduit le bruit, l'autre le fait cesser d'arriver chez la mauvaise personne.

---

## 8. Limites

- La vidéo n'a pas pu être lue. Le rattachement entre ce qui y est montré et les événements listés au §3 reste à confirmer par une capture d'écran.
- Le contenu exact des notifications déjà affichées sur son téléphone n'est pas conservé côté serveur : `notification_events` garde le `payload`, pas le libellé rendu. Le §3 liste ce qui a été **envoyé**, pas ce qui reste visible dans son volet.
