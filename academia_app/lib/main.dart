import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'config/supabase_config.dart';
import 'providers/supabase_provider.dart';
import 'providers/student_offers_provider.dart';
import 'providers/student_applications_provider.dart';
import 'providers/student_courses_provider.dart';
import 'providers/student_profile_provider.dart';
import 'providers/bobodo_provider.dart';
import 'features/auth/auth_wrapper.dart';

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
    final providers = <SingleChildWidget>[
      ChangeNotifierProvider(create: (_) => StudentOffersProvider()),
      ChangeNotifierProvider(create: (_) => StudentApplicationsProvider()),
      ChangeNotifierProvider(create: (_) => StudentCoursesProvider()),
      ChangeNotifierProvider(create: (_) => StudentProfileProvider()),
      ChangeNotifierProvider(create: (_) => BobodoProvider()),
    ];

    if (kDebugMode) {
      providers.insert(0, ChangeNotifierProvider(create: (_) => SupabaseProvider()));
    }

    return MultiProvider(
      providers: providers,
      child: MaterialApp(
        title: 'Academia - Projet Supabase',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}
