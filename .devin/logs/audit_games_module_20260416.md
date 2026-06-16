# Audit Module Jeux — 16 Avril 2026

## Supabase

### 7 tables (schema app) — TOUTES VIDES (0 lignes)
- `tournaments` (22 cols): id, name, description, game_type, tournament_type, format, max/min/current_participants, status, registration_start/end, start/end_date, prize_pool, entry_fee, created_by, created_at, updated_at, settings(jsonb), is_featured, is_private, elo_min, elo_max, auto_start
- `tournament_participants` (8 cols): id, tournament_id, user_id, status, seed_number, elo_at_registration, joined_at, final_rank
- `tournament_matches` (11 cols): id, tournament_id, round, match_number, player1/2_id, player1/2_score, winner_id, status, played_at
- `tournament_rewards` (7 cols): id, tournament_id, rank_min/max, reward_type, reward_amount, reward_icon, created_at
- `leagues` (15 cols): id, name, description, game_type, league_type, division, season_number, max_players, min_elo, max_elo, start/end_date, status, created_by, created_at
- `league_participations` (8 cols): id, league_id, user_id, elo_rating, wins, losses, draws, joined_at
- `league_matches` (10 cols): id, league_id, player1/2_id, player1/2_score, winner_id, status, round, played_at

### 15 RPCs
tournament_create, tournament_list_available, tournament_register, tournament_get_details, tournament_get_standings, tournament_start, tournament_report_match_result, generate_tournament_bracket, league_create, league_list_available, league_join, league_get_standings, league_report_match_result, update_league_player_count (trigger fn), update_tournament_participant_count (trigger fn)

### 15 RLS policies
Toutes les tables ont SELECT public + gestion propre (ALL/INSERT/UPDATE/DELETE selon rôle)

### Tables MANQUANTES (référencées dans le code Flutter mais inexistantes)
- `economic_indicators` — 42P01 does not exist
- `african_market_scenarios` — 42P01 does not exist
- `adaptive_learning_profiles` — 42P01 does not exist
- Aucune table `game_sessions` ou `game_scores` pour le jeu solo

## Flutter (academia_app/lib/games/)

### 12 fichiers
**screens/** (4):
- `games_domain_hub_screen.dart` (211 lignes) — Hub multi-domaines, OK mobile (ListView + Wrap)
- `games_hub_screen.dart` (579 lignes) — Grille 4 jeux + GamePlayScreen + Flame
- `tournament_list_screen.dart` — Tournois + Ligues (utilise TournamentProvider)
- `leaderboard_screen.dart` — Placeholder "Coming Soon"

**core/** (5):
- `kellenge_game_engine.dart` (195 lignes) — Base Flame, camera fixe 800×600
- `market_master_game.dart` (669 lignes) — Offre/Demande, positions absolues 800×600
- `consumer_choice_game.dart` (645 lignes) — Choix consommateur, positions absolues
- `firm_tycoon_game.dart` — Gestion entreprise
- `market_structures_game.dart` — QCM structures de marché

**Autres**: game_session.dart, game_provider.dart, game_scoring_system.dart, gameplay_recorder_service.dart, game_constants.dart

### Navigation
Challenge tab → bottom bar "Jeux" → `Navigator.pushNamed('/games')` → `GamesDomainHubScreen`
→ Economie → `GamesHubScreen` → tap jeu → `GamePlayScreen(Flame)`
→ Tournois → `TournamentListScreen`

### Routes (main.dart)
- `/games` → GamesDomainHubScreen
- `/tournaments` → TournamentListScreen
- `/leaderboard` → LeaderboardScreen

## Problèmes d'overflow mobile identifiés

### P1 — GamePlayScreen score bar (CRITIQUE)
`Row` avec 3 `Text` (fontSize 20+18) sans Flexible/Expanded → overflow horizontal sur écrans < 400px

### P2 — Flame camera fixe 800×600 (CRITIQUE)
Tous les jeux Flame utilisent `CameraComponent.withFixedResolution(width: 800, height: 600)` avec des éléments UI à positions absolues (boutons à Vector2(500,150), textes à (50,150), etc.). Sur un téléphone 360px wide, le canvas est zoomé out → textes minuscules et illisibles, boutons trop petits pour être tapés.

### P3 — GamePlayScreen score bar padding fixe
`padding: EdgeInsets.all(16)` + `fontSize: 20` dans le Container noir → prend trop de place verticale sur petit écran

### P4 — TournamentListScreen
Utilise `Provider.of<TournamentProvider>` — fonctionnel mais les tabs + cards n'ont aucune adaptation mobile
