# Runbook — Bascule LiveKit self-hosted → LiveKit Cloud (Option A)

**Date** : 13 juillet 2026
**Contexte** : suite à `ACADEMIA_LIVE_CLASSROOM_PROPOSAL.md`, ce document décrit les étapes pour migrer le SFU LiveKit du VPS Kamatera partagé (185.167.97.144) vers LiveKit Cloud, sans changement de code applicatif.

## Pourquoi c'est une bascule sans code

Audit du code confirmé (13 juillet 2026) : `supabase/functions/livekit-token/index.ts` et `supabase/functions/livekit-recording/index.ts` lisent déjà `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` exclusivement depuis les secrets d'environnement Supabase — aucune URL ni clé n'est codée en dur. Le nouvel Edge Function `livekit-admin/index.ts` (ajouté avec cette bascule, pour les contrôles hôte) suit exactement le même principe. Le client Flutter (`AcademiaClassroomScreen`) se connecte avec l'URL renvoyée dynamiquement par `livekit-token` — il ne connaît jamais l'adresse du serveur à l'avance. **Changer de fournisseur LiveKit = changer 3 secrets Supabase, rien d'autre.**

## Ce que je ne peux pas faire à ta place

Je n'ai pas accès à ton compte Kamatera, ton dashboard Supabase, ni la possibilité de créer un compte tiers en ton nom (création de compte = action que je ne dois jamais effectuer). Les étapes ci-dessous sont donc à réaliser par toi (ou à me déléguer si tu me donnes un accès explicite au dashboard Supabase).

## Étapes

1. **Créer un compte LiveKit Cloud** sur https://cloud.livekit.io (offre gratuite pour démarrer, facturation à l'usage ensuite).
2. **Créer un projet** dans LiveKit Cloud → noter l'**URL WebSocket** du projet (format `wss://<projet>.livekit.cloud`) et générer une paire **API Key / API Secret**.
3. **Mettre à jour les secrets Supabase** (Dashboard Supabase → Project Settings → Edge Functions → Secrets, ou `supabase secrets set` en CLI) :
   ```bash
   supabase secrets set LIVEKIT_URL="wss://<projet>.livekit.cloud"
   supabase secrets set LIVEKIT_API_KEY="<nouvelle clé>"
   supabase secrets set LIVEKIT_API_SECRET="<nouveau secret>"
   ```
4. **Redéployer les 3 Edge Functions** (elles relisent les secrets au déploiement) :
   ```bash
   supabase functions deploy livekit-token
   supabase functions deploy livekit-recording
   supabase functions deploy livekit-admin
   ```
5. **Tester** : lancer une session live de test (rôle enseignant → onglet "Mes classes en direct" → créer une session provider=livekit → Démarrer) et vérifier côté étudiant que la connexion, le chat, l'enregistrement et la coupure de micro à distance fonctionnent.
6. **Libérer le VPS Kamatera existant** : une fois la bascule validée, le conteneur Docker `livekit-server` sur 185.167.97.144 peut être arrêté (`docker stop livekit-server`). Le CPU/RAM ainsi libéré profite immédiatement au worker Smart Whiteboard, à Bobodo vocal et à la compression vidéo qui tournaient sur la même machine — c'était le principal risque identifié dans l'audit infra.
7. **Mettre à jour la documentation permanente du projet** (`docs/ACADEMIA_DEPLOYMENT_STATUS.md`, `docs/ACADEMIA_ARCHITECTURE_DECISIONS.md` avec un nouvel ADR) pour refléter ce changement d'infrastructure, conformément au protocole de gouvernance documentaire déjà en place dans le projet.

## Rollback

Si un problème survient, il suffit de restaurer les 3 anciens secrets (URL/clé/secret du VPS Kamatera d'origine) et de redéployer les mêmes 3 fonctions — retour à l'état antérieur en quelques minutes, sans redéploiement Flutter.

## Ce qui a été livré dans le cadre de cette même bascule (code déjà en place)

- `supabase/functions/livekit-admin/index.ts` : nouvelle fonction permettant à l'hôte de couper à distance le micro d'un participant et de l'exclure de la session (RoomService LiveKit — fonctionne identiquement sur self-hosted et LiveKit Cloud).
- Panneau "Participants" dans `AcademiaClassroomScreen` (icône 👥 dans la barre du haut) : liste des participants, coupure micro à distance (hôte), export CSV du registre de présence.
- Bouton "Accéder au TD" branché côté étudiant (`TdEnrollmentAccessScreen`) sur le moteur de session unifié (`session_type = 'td'`).
- Fusion des onglets enseignant "Lives" (Prépa-Concours) et "Sessions" (Cours) en un seul onglet "Mes classes en direct" avec sélecteur interne.
- Formulaire de planification de session enseignant : LiveKit devient l'option par défaut, le lien Zoom/Meet manuel est déplacé dans une section "Options avancées" pour décourager son usage (perte de chat/présence/replay Academia).
