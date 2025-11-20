import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'config/supabase_config.dart';
import 'providers/supabase_provider.dart';
import 'providers/student_offers_provider.dart';
import 'providers/student_applications_provider.dart';
import 'providers/student_application_files_provider.dart';
import 'providers/student_application_messages_provider.dart';
import 'providers/student_dossier_documents_provider.dart';
import 'providers/student_courses_provider.dart';
import 'providers/student_profile_provider.dart';
import 'providers/student_university_site_provider.dart';
import 'providers/university_site_provider.dart';
import 'providers/admin_applications_provider.dart';
import 'providers/admin_application_messages_provider.dart';
import 'providers/admin_programs_provider.dart';
import 'providers/admin_courses_provider.dart';
import 'providers/admin_universities_provider.dart';
import 'providers/admin_university_site_provider.dart';
import 'providers/admin_bobodo_conversations_provider.dart';
import 'providers/admin_bobodo_needs_provider.dart';
import 'providers/admin_bobodo_unanswered_provider.dart';
import 'providers/university_applications_provider.dart';
import 'providers/university_application_messages_provider.dart';
import 'providers/university_application_detail_provider.dart';
import 'providers/selected_university_application_provider.dart';
import 'providers/university_programs_provider.dart';
import 'providers/bobodo_provider.dart';
import 'providers/landing_content_provider.dart';
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
      ChangeNotifierProvider(create: (_) => LandingContentProvider()),
      ChangeNotifierProvider(create: (_) => StudentOffersProvider()),
      ChangeNotifierProvider(create: (_) => StudentApplicationsProvider()),
      ChangeNotifierProvider(create: (_) => StudentApplicationFilesProvider()),
      ChangeNotifierProvider(create: (_) => StudentApplicationMessagesProvider()),
      ChangeNotifierProvider(create: (_) => StudentCoursesProvider()),
      ChangeNotifierProvider(create: (_) => StudentProfileProvider()),
      ChangeNotifierProvider(create: (_) => StudentUniversitySiteProvider()),
      ChangeNotifierProvider(create: (_) => StudentDossierDocumentsProvider()),
      ChangeNotifierProvider(create: (_) => AdminApplicationsProvider()),
      ChangeNotifierProvider(create: (_) => AdminApplicationMessagesProvider()),
      ChangeNotifierProvider(create: (_) => AdminProgramsProvider()),
      ChangeNotifierProvider(create: (_) => AdminCoursesProvider()),
      ChangeNotifierProvider(create: (_) => AdminUniversitiesProvider()),
      ChangeNotifierProvider(create: (_) => AdminUniversitySiteProvider()),
      ChangeNotifierProvider(create: (_) => AdminBobodoConversationsProvider()),
      ChangeNotifierProvider(create: (_) => AdminBobodoNeedsProvider()),
      ChangeNotifierProvider(create: (_) => AdminBobodoUnansweredProvider()),
      ChangeNotifierProvider(create: (_) => UniversityApplicationsProvider()),
      ChangeNotifierProvider(create: (_) => UniversityApplicationMessagesProvider()),
      ChangeNotifierProvider(create: (_) => UniversityApplicationDetailProvider()),
      ChangeNotifierProvider(create: (_) => SelectedUniversityApplicationProvider()),
      ChangeNotifierProvider(create: (_) => UniversityProgramsProvider()),
      ChangeNotifierProvider(create: (_) => UniversitySiteProvider()),
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
