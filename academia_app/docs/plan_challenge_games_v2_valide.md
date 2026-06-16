# Plan Challenge Games V2 — Validé le 18 Avril 2026

## Phase 1A ✅ FAIT
- Watermark Academia sur vidéos gameplay (FFmpeg overlay logo)
- Partage fichier vidéo watermarké via WhatsApp/Facebook (share_plus shareXFiles)
- Dialog "Publier dans le feed" ou "Partager en externe"

## Phase 1B — EN COURS
- Jeu 1 : Type de Cerveau (8 questions, 4 profils, résultat partageable)
- Jeu 2 : Défi 10 Secondes (chrono, leaderboard, streak)
- Jeu 3 : Quel Étudiant Es-Tu (profil, CTA Academia)

## Phase 2 — Duels
- Tables Supabase challenge_game_live_sessions + challenge_duel_rounds
- Mode duel "même question rapide" (Blooket-style)
- Mode duel "questions croisées" (Trivia Crack amélioré)
- Matchmaking par matière/niveau

## Phase 3 — Live dans le feed
- Joueur visible en live dans le feed Challenge (LiveKit existant)
- Spectateurs : commentaires, réactions emoji, encouragements
- Replay automatique + publication feed

## Phase 4 — Expansion
- Tournois par université
- Mode coach adaptatif
- Classements par ville/filière

## Types de live séparés (ne pas mélanger)
- prep_live_sessions → Prep Concours
- online_course_live_sessions → Cours en ligne
- TD via livekit_room_screen → TD
- challenge_game_live_sessions → Challenge Gaming (NOUVEAU)
