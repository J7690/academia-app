# Correctifs appliqués — notifications (04/08/2026)

Suite de `AUDIT_NOTIFICATIONS_VOLUME_ET_DECLENCHEURS_2026-08-04.md`.
Tout ce qui suit est **appliqué en production** et vérifié.

---

## N1 — Le canal de fuite est refermé

**Correctif de fond.** `app_register_device_token` désactive désormais le même
`fcm_token` chez tout autre utilisateur avant de l'enregistrer. L'unicité portait
sur le couple *(utilisateur, jeton)* : un téléphone pouvait appartenir à un
nombre illimité de comptes, tous actifs. Firebase livrant au jeton et non au
compte, un commercial recevait les notifications d'administration.

**Nettoyage de l'existant**, en deux gestes distincts :

1. *Un appareil, une inscription active* — la plus récente gagne.
2. *Purge des installations dormantes* — plus revues depuis 60 jours. Elles se
   réactivent seules à la prochaine ouverture de l'application, qui appelle
   `app_register_device_token` à chaque démarrage à froid.

| | Avant | Après |
|---|---|---|
| Inscriptions actives | 209 | **55** |
| Appareils partagés entre comptes | 35 | **0** |
| `wendenkoote@gmail.com` (admin) | 61 | **6** |
| `kayadejule@gmail.com` (commercial) | 7 | **1** |
| `nassiroumaiga@outlook.com` (manager) | 3 | **2** |

> **Précision** : les 61 inscriptions de l'administrateur n'étaient pas des
> doublons mais **61 installations distinctes**, dont 54 inutilisées depuis plus
> de 30 jours. C'est la purge, non la déduplication, qui les a réduites. Ma
> première estimation « 61 → 1 » était fausse : le compte conserve 6 appareils
> réellement actifs.

**Côté application.** `PushNotificationService.unregisterTokenBeforeLogout()`
ajouté et appelé avant les trois `signOut()` — déconnexion volontaire, compte
bloqué, suppression de compte. La RPC `app_unregister_device_token` existait
depuis toujours et n'était appelée nulle part.

---

## N2 — On notifie des encaissements, plus des intentions

`app_notify_admin_payment_declared` et `app_notify_university_payment` ne se
déclenchent plus que sur **`declared_by_student`** et **`confirmed`**.

`pending`, `processing` et `failed` sont des étapes techniques : elles restent
visibles dans les écrans de suivi, elles ne réveillent plus personne. **Appuyer
sur « Payer » n'envoie plus rien.**

Le libellé `credit_purchase` → « Achat de crédits » a été ajouté aux deux
fonctions, qui affichaient « Paiement » par défaut.

---

## N3 — Le digest d'activité passe au quotidien

Tâche `admin-audience-digest` : **toutes les 15 minutes → une fois par jour à
07h00 UTC** (heure locale du Burkina Faso).

À elle seule, cette tâche produisait **385 des 463 notifications hebdomadaires,
soit 83 % du volume**, pour annoncer quelques visiteurs. La fonction ignorait
déjà les fenêtres sans activité : c'était bien le rythme, pas le contenu.

---

## N4 — Création de compte : ni doublon, ni notification vide

**Doublon supprimé.** `app_manager_create_commercial` empilait une notification
explicite par-dessus celle du déclencheur. Les administrateurs recevaient deux
fois la même information à quelques secondes d'écart. L'envoi explicite est
retiré ; le rattachement au manager reste inscrit dans
`commercial_profiles.manager_user_id`.

**Notifications vides supprimées.** Le déclencheur se déclenchait à l'INSERT sur
`auth.users`, avant que l'identifiant soit renseigné pour une inscription par
téléphone : 175 messages « 👤 Nouveau compte créé — student — » en 30 jours.

Il annonce désormais le compte **au moment où il devient identifiable**
(e-mail, à défaut téléphone), et une seule fois. Le déclencheur écoute
`INSERT OR UPDATE` avec une garde sur la transition « sans identifiant → avec » :
sans cela, se taire à l'INSERT aurait rendu ces comptes **définitivement muets**
— on aurait troqué des notifications inutiles contre des notifications
manquantes. Vérifié : les 25 comptes concernés ont tous un téléphone.

---

## Effet attendu

| | Avant | Après |
|---|---|---|
| Événements / semaine | 463 | **~25** |
| Envois par événement (admin) | jusqu'à 61 | **6** |
| Notification à la pression sur « Payer » | oui | **non** |
| Notifications « compte créé » vides | 175 / mois | **0** |
| Doublons à la création d'un commercial | systématique | **0** |
| Un commercial voit l'administration | oui | **non** |

---

## Un point resté en suspens — assumé

`send-push-notifications` a été **corrigée dans le dépôt** (table de libellés
complétée : `processing`, `pending`, `failed`, `cancelled` ne peuvent plus
atteindre un humain en anglais brut) mais **non redéployée**.

Raison : le correctif N2 empêche désormais ces statuts d'entrer dans la file.
Le code générique est devenu inatteignable pour `admin_payments`. Redéployer
supposait de retranscrire 742 lignes, avec un risque d'erreur sur une fonction
qui marche — pour un bénéfice aujourd'hui nul.

**Le dépôt est donc en avance sur la production, pas en retard.** C'est le sens
sûr : un futur `supabase functions deploy send-push-notifications` appliquera
l'amélioration sans rien régresser.

---

## Ce qui n'a pas été touché

- **La chaîne des commissions reste cassée** (cf.
  `AUDIT_MANAGER_COMMERCIAUX_GAINS_2026-08-04.md`). Aucun gain n'est généré,
  le manager ne voit donc toujours rien. Sa réparation attend votre décision
  sur les motifs de paiement rémunérateurs — vous avez déjà tranché que
  `credit_purchase` n'en fait pas partie.
- **Les trois failles critiques de paiement** (confirmation sans encaissement,
  reversement arbitraire, webhook non vérifié) décrites dans
  `AUDIT_PAIEMENT_ET_NOTIFICATIONS_2026-08-04.md` restent ouvertes.
- **L'éventuel encaissement LigdiCash non enregistré** : toujours en attente de
  la référence du SMS pour être tracé.
