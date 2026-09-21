# Phase 3 — Messagerie de candidature

## État

Changements locaux préparés. **Accord utilisateur reçu le 20/09/2026 ; tentative de déploiement bloquée par les permissions Storage. Migration non appliquée.** Aucun message réel n'a été envoyé pendant les tests.

Le contrôle préalable a validé les 14 fonctions sauvegardées, les 30 politiques existantes, les colonnes et l'absence du bucket. L'appel atomique à `admin_execute_sql` a retourné `42501: must be owner of table objects` lors de la création des politiques Storage. Un nouveau contrôle a confirmé le retour à l'état initial : aucune migration partielle persistée.

Diagnostic : `storage.objects` et `storage.buckets` appartiennent à `supabase_storage_admin`. Les RPC `admin_execute_sql`, `execute_ddl` et `execute_sql` appartiennent toutes à `postgres`, non superutilisateur, invoqué via la session `authenticator`. Aucun jeton Management ni mot de passe/URL de connexion PostgreSQL n'est configuré dans l'environnement `.windsurf`. La reprise nécessite un accès approuvé capable de gérer ces politiques (par exemple API Management ou SQL Editor du projet). Ne pas changer les propriétaires des tables système ni élargir les droits pour contourner ce refus.

Migration à examiner : `supabase/migrations/20260920140000_application_messages_media.sql`.
Les définitions SQL de production originales sont conservées en commentaire au début de ce fichier. Les audits locaux supplémentaires sont dans `.windsurf/phase3_application_*_before_20260920.json`.

## Comportement préparé

- Pièces jointes dans les trois écrans : administrateur, étudiant, université.
- Images, audio et vidéos existants ; enregistrement vocal PCM/WAV jusqu'à deux minutes. Fichiers limités à 25 Mo.
- Confirmation d'envoi avec destinataire et légende facultative ; une sélection ou un enregistrement n'envoie rien automatiquement.
- Images affichées, audio avec lecture/pause, vidéo avec lecteur. Les liens privés expirent après cinq minutes ; une nouvelle tentative de lecture peut en obtenir un autre.
- Accusés « envoyé » / « lu ». Les dates individuelles commencent avec cette migration, sans inventer de date historique. Rafraîchissement en tirant la liste vers le bas ou en rouvrant la conversation.
- Aucun abonnement Realtime : il reste optionnel et désactivé.

## Changements Supabase proposés

1. Colonnes additives `type`, `media_url`, `media_mime`, `read_at` dans `app.application_messages`, et index unique sur les chemins médias.
2. Bucket **privé** `application-media`, types MIME autorisés et limite 25 Mo. Le chemin comprend candidature, canal, auteur et identifiant unique.
3. Quatre surcharges RPC à **cinq paramètres obligatoires**, sans valeurs par défaut. Les signatures texte à deux paramètres sont conservées pour les clients déjà distribués. Le serveur contrôle rôle, candidature, canal, présence du fichier et métadonnées.
4. Listings enrichis, mêmes formes de réponse : tableau JSON côté étudiant, objet avec `success` et `messages` pour admin/université. Les RPC de lecture marquent seulement les messages reçus dans le canal autorisé.
5. Rôles et rattachement université lus depuis `raw_app_meta_data`, protégé côté serveur. Les données auditées confirment que les rattachements université correspondent aux anciennes métadonnées. L'accès université exige un dossier transmis.
6. Restrictions de lecture par canal et écritures directes interdites dans la table de messages (écriture via RPC). Cela resserre une policy existante qui permettait à un étudiant de lire tous les messages de sa candidature, sans distinction de canal.
7. Policies Storage dédiées, avec gardes restrictives limitées au nouveau bucket. Les autres buckets restent hors de ces restrictions. Les fichiers envoyés ne sont ni remplaçables ni supprimables via le client ; seuls les fichiers non liés de leur auteur peuvent être nettoyés.

Références techniques utilisées : [contrôles Storage Supabase](https://supabase.com/docs/guides/storage/security/access-control) et [policies restrictives PostgreSQL](https://www.postgresql.org/docs/current/sql-createpolicy.html).

## Validation locale

- Tests SQL sur PostgreSQL local isolé, données fictives : les quatre anciens appels texte et quatre nouveaux envois médias, répétition sans doublon, séparation des canaux, refus d'un autre étudiant/d'une autre université, refus d'une usurpation de rôle via les métadonnées utilisateur, accusés de lecture, blocage de la suppression d'un média envoyé et de l'écriture directe.
- Accès anonyme refusé même en présence d'une policy permissive globale simulée.
- Migration complète également exécutée localement à travers le corps exact de `admin_execute_sql` sauvegardé depuis la production, puis tests de permissions rejoués avec succès. Instance PostgreSQL locale arrêtée après les tests.
- Douze tests Flutter : format/limites de fichiers, WAV, routage des quatre RPC, erreurs métier, accusés, annulation, et non-régression des modèles administrateur sur téléphone/bureau/clavier ouvert.
- APK debug compilé avec les médias activés. Analyse des nouveaux composants et de leurs tests : aucune erreur ni remarque ; les écrans existants conservent leurs avertissements préexistants.
- Aucun nouveau package, aucune montée de version des dépendances.
- Permission microphone iOS ajoutée ; **compilation iOS et capture/lecture sur appareils physiques non effectuées**. Les flux Storage réels et codecs doivent encore être validés après autorisation de la migration, sur des comptes de test dédiés.

## Activation et contrôle de production

Par défaut, les boutons de pièces jointes sont désactivés à la compilation. L'APK debug de validation est construit avec :

```powershell
flutter build apk --debug --no-pub --dart-define=APPLICATION_MESSAGE_MEDIA_ENABLED=true
```

Cet APK ne doit pas être distribué avant validation du serveur et des parcours sur appareils.

Après accord explicite :

1. Via `.windsurf/env_loader.py`, relire les définitions et vérifier qu'elles correspondent à la sauvegarde ; contrôler l'absence du nouveau bucket et des nouvelles colonnes. Si la production a changé, réexaminer le différentiel.
2. Appliquer **uniquement la migration**, atomiquement, depuis un accès capable de gérer les politiques Storage. La tentative via `admin_execute_sql` a été annulée pour droits insuffisants : ne pas la relancer sans résoudre le contexte d'accès. Ne pas envoyer `BEGIN`/`COMMIT` à cette RPC. Ne jamais appliquer les fichiers de fixtures/tests à Supabase.
3. Vérifier les définitions, signatures, permissions, bucket privé, policies et absence d'exposition Realtime. Tester l'accès avec des sessions de test ordinaires : une clé administrateur contourne RLS et ne prouve donc pas l'isolation Storage.
4. Tester image, vocal, vidéo, annulation, échec réseau, répétition, expiration du lien et accusés dans chaque canal. Vérifier que l'étudiant ne peut pas télécharger une pièce université, et inversement.
5. Activer le paramètre de compilation uniquement pour les builds destinés à cette fonctionnalité, après validation.

Retour arrière prudent : désactiver le paramètre de compilation et conserver les données/colonnes/bucket. Ne pas supprimer les médias ou retirer les restrictions d'accès pour revenir au texte seul. Toute restauration SQL nécessite une revue séparée ; les anciens corps de fonctions sont archivés, mais restaureraient aussi leurs anciens contrôles de rôles.

Des uploads interrompus avant publication peuvent laisser des objets non liés. Ils restent privés ; aucune purge automatique n'est ajoutée dans cette phase.

## Rejouer les tests SQL

Les fixtures refusent une base dont le nom ne commence pas par `academia_phase3_test`. Utiliser exclusivement une instance locale isolée, avec un rôle de test administrateur PostgreSQL.

```powershell
psql -h 127.0.0.1 -p 55439 -U postgres -d academia_phase3_test_validation -v ON_ERROR_STOP=1 -1 `
  -f supabase/tests/application_messages_media_bootstrap.sql `
  -f supabase/migrations/20260920140000_application_messages_media.sql `
  -f supabase/tests/application_messages_media_security.sql
```

La base doit être vide au début ; ces fixtures ne sont pas une migration réexécutable.
