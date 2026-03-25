import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import 'config/supabase_config.dart';
import 'providers/supabase_provider.dart';
import 'screens/home_screen.dart';
import 'screens/data_screen.dart';
import 'games/providers/game_provider.dart';
import 'games/screens/games_hub_screen.dart';
import 'games/screens/multiplayer_hub_screen.dart';
import 'games/providers/tournament_provider.dart';
import 'games/screens/tournament_list_screen.dart';
import 'games/screens/leaderboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialisation Supabase avec configuration validée
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  
  runApp(const AcademiaApp());
}

class AcademiaApp extends StatelessWidget {
  const AcademiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SupabaseProvider()),
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider(create: (_) => TournamentProvider()),
      ],
      child: MaterialApp(
        title: 'Academia - Projet Supabase',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const HomeScreen(),
        routes: {
          '/data': (context) => const DataScreen(),
          '/games': (context) => const GamesHubScreen(),
          '/multiplayer': (context) => const MultiplayerHubScreen(),
          '/tournaments': (context) => const TournamentListScreen(),
          '/leaderboard': (context) => const LeaderboardScreen(),
        }
      ),
    );
  }
}
