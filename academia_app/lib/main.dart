import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'services/push_notification_service.dart';

import 'web_update_stub.dart' if (dart.library.html) 'web_update_html.dart' as web_update;

import 'config/supabase_config.dart';
import 'providers/supabase_provider.dart';
import 'providers/student_offers_provider.dart';
import 'providers/student_profile_provider.dart';
import 'providers/student_weather_provider.dart';
import 'providers/student_marketplace_listings_provider_v1.dart';
import 'providers/student_marketplace_categories_provider_v1.dart';
import 'providers/student_marketplace_bookmarked_listings_provider_v1.dart';
import 'providers/student_marketplace_cart_provider_v1.dart';
import 'providers/home_formations_provider.dart';
import 'providers/student_opportunities_provider.dart';
import 'providers/university_programs_provider.dart';
import 'providers/student_application_messages_provider.dart';
import 'providers/student_dossier_documents_provider.dart';
import 'providers/student_courses_provider.dart';
import 'providers/student_course_library_provider.dart';
import 'providers/online_courses_catalog_provider.dart';
import 'providers/student_announcements_provider.dart';
import 'providers/student_academic_calendar_provider.dart';
import 'providers/student_communities_provider.dart';
import 'providers/student_direct_messages_provider.dart';
import 'providers/student_challenges_provider.dart';
import 'providers/student_applications_provider.dart';
import 'providers/student_application_files_provider.dart';
import 'providers/student_online_courses_provider.dart';
import 'providers/online_course_detail_provider.dart';
import 'providers/online_course_live_sessions_provider.dart';
import 'providers/online_course_forum_provider.dart';
import 'providers/student_live_sessions_provider.dart';
import 'providers/student_university_site_provider.dart';
import 'providers/university_site_provider.dart';
import 'providers/admin_applications_provider.dart';
import 'providers/admin_application_messages_provider.dart';
import 'providers/admin_programs_provider.dart';
import 'providers/admin_courses_provider.dart';
import 'providers/admin_course_library_provider.dart';
import 'providers/admin_online_courses_provider.dart';
import 'providers/admin_live_sessions_provider.dart';
import 'providers/instructor_online_courses_provider.dart';
import 'providers/instructor_online_course_live_sessions_provider.dart';
import 'providers/instructor_online_course_forum_provider.dart';
import 'providers/admin_universities_provider.dart';
import 'providers/admin_user_invitations_provider.dart';
import 'providers/admin_users_overview_provider.dart';
import 'providers/admin_university_site_provider.dart';
import 'providers/admin_bobodo_conversations_provider.dart';
import 'providers/admin_bobodo_needs_provider.dart';
import 'providers/admin_bobodo_unanswered_provider.dart';
import 'providers/university_applications_provider.dart';
import 'providers/university_application_messages_provider.dart';
import 'providers/university_application_detail_provider.dart';
import 'providers/selected_university_application_provider.dart';
import 'providers/bobodo_provider.dart';
import 'providers/landing_content_provider.dart';
import 'providers/student_home_content_provider.dart';
import 'providers/student_home_slots_provider.dart';
import 'providers/student_short_trainings_provider.dart';
import 'providers/student_short_training_messages_provider.dart';
import 'providers/student_online_course_messages_provider.dart';
import 'providers/admin_short_trainings_provider.dart';
import 'providers/admin_short_training_messages_provider.dart';
import 'providers/admin_online_course_messages_provider.dart';
import 'providers/admin_academic_announcements_provider.dart';
import 'providers/admin_academic_events_provider.dart';
import 'providers/admin_student_home_slots_provider.dart';
import 'providers/opportunity_reactions_provider.dart';
import 'providers/opportunity_comments_provider.dart';
import 'providers/listing_reviews_provider.dart';
import 'providers/admin_communities_provider.dart';
import 'providers/admin_challenges_provider.dart';
import 'providers/admin_prep_concours_provider.dart';
import 'providers/prep_concours_provider.dart';
import 'providers/admin_td_catalog_provider.dart';
import 'providers/admin_td_teachers_provider.dart';
import 'providers/admin_td_student_requests_provider.dart';
import 'providers/student_td_catalog_provider.dart';
import 'providers/student_td_enrollments_provider.dart';
import 'providers/student_td_requests_provider.dart';
import 'providers/teacher_td_assignments_provider.dart';
import 'providers/teacher_prep_assignments_provider.dart';
import 'providers/teacher_prep_live_sessions_provider.dart';
import 'providers/admin_td_enrollments_provider.dart';
import 'providers/td_messages_provider.dart';
import 'providers/commercial_dashboard_provider.dart';
import 'providers/subscription_provider.dart';
import 'features/share/share_mode_provider.dart';
import 'providers/prep_quiz_provider.dart';
import 'providers/prep_flashcard_provider.dart';
import 'providers/td_gamification_provider.dart';
import 'providers/community_stories_provider.dart';
import 'games/providers/tournament_provider.dart';
import 'games/screens/tournament_list_screen.dart';
import 'games/screens/leaderboard_screen.dart';
import 'games/screens/games_domain_hub_screen.dart';
import 'features/auth/auth_wrapper.dart';
import 'features/auth/auth_callback_screen.dart';

const String kAppVersion = '1.0.1';

Future<void> _checkWebVersion() async {
  if (!kIsWeb) {
    return;
  }

  try {
    final uri = Uri.parse('/app_version.json');
    final response = await http.get(uri).timeout(
          const Duration(seconds: 5),
        );

    if (response.statusCode != 200) {
      return;
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return;
    }

    final remoteVersion =
        (decoded['version'] ?? '').toString().trim();
    final required = decoded['required'] != false;

    if (remoteVersion.isEmpty) {
      return;
    }

    if (remoteVersion != kAppVersion && required) {
      await web_update.showUpdateAndReload();
    }
  } catch (_) {
    // En cas d'erreur réseau ou de parsing, on laisse l'application démarrer normalement.
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation des données de locale pour Intl (dates, jours en fr_FR)
  // Nécessaire avant toute utilisation de DateFormat('EEEE', 'fr_FR') etc.
  await initializeDateFormatting('fr_FR');

  await _checkWebVersion();

  // Initialisation Supabase avec configuration validée
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  // Initialisation du transport de notifications push (FCM via Firebase)
  // La logique métier et les compteurs restent gérés dans Supabase.
  try {
    await PushNotificationService.instance.init();
  } catch (_) {}
  
  runApp(const AcademiaApp());
}

class AcademiaApp extends StatelessWidget {
  const AcademiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final providers = <SingleChildWidget>[
      ChangeNotifierProvider(create: (_) => LandingContentProvider()),
      ChangeNotifierProvider(create: (_) => StudentHomeContentProvider()),
      ChangeNotifierProvider(create: (_) => StudentHomeSlotsProvider()),
      ChangeNotifierProvider(create: (_) => StudentAnnouncementsProvider()),
      ChangeNotifierProvider(create: (_) => StudentAcademicCalendarProvider()),
      ChangeNotifierProvider(create: (_) => StudentWeatherProvider()),
      ChangeNotifierProvider(create: (_) => StudentOffersProvider()),
      ChangeNotifierProvider(create: (_) => HomeFormationsProvider()),
      ChangeNotifierProvider(create: (_) => StudentOpportunitiesProvider()),
      ChangeNotifierProvider(create: (_) => StudentMarketplaceListingsProviderV1()),
      ChangeNotifierProvider(create: (_) => StudentMarketplaceCategoriesProviderV1()),
      ChangeNotifierProvider(create: (_) => StudentMarketplaceBookmarkedListingsProviderV1()),
      ChangeNotifierProvider(create: (_) => StudentMarketplaceCartProviderV1()),
      ChangeNotifierProvider(create: (_) => OpportunityReactionsProvider()),
      ChangeNotifierProvider(create: (_) => OpportunityCommentsProvider()),
      ChangeNotifierProvider(create: (_) => ListingReviewsProvider()),
      ChangeNotifierProvider(create: (_) => StudentCommunitiesProvider()),
      ChangeNotifierProvider(create: (_) => StudentDirectMessagesProvider()),
      ChangeNotifierProvider(create: (_) => StudentChallengesProvider()),
      ChangeNotifierProvider(create: (_) => StudentApplicationsProvider()),
      ChangeNotifierProvider(create: (_) => StudentApplicationFilesProvider()),
      ChangeNotifierProvider(create: (_) => StudentApplicationMessagesProvider()),
      ChangeNotifierProvider(create: (_) => StudentCoursesProvider()),
      ChangeNotifierProvider(create: (_) => StudentCourseLibraryProvider()),
      ChangeNotifierProvider(create: (_) => OnlineCoursesCatalogProvider()),
      ChangeNotifierProvider(create: (_) => StudentOnlineCoursesProvider()),
      ChangeNotifierProvider(create: (_) => OnlineCourseDetailProvider()),
      ChangeNotifierProvider(create: (_) => OnlineCourseLiveSessionsProvider()),
      ChangeNotifierProvider(create: (_) => OnlineCourseForumProvider()),
      ChangeNotifierProvider(create: (_) => StudentLiveSessionsProvider()),
      ChangeNotifierProvider(create: (_) => StudentProfileProvider()),
      ChangeNotifierProvider(create: (_) => StudentUniversitySiteProvider()),
      ChangeNotifierProvider(create: (_) => StudentDossierDocumentsProvider()),
      ChangeNotifierProvider(create: (_) => StudentShortTrainingsProvider()),
      ChangeNotifierProvider(create: (_) => StudentShortTrainingMessagesProvider()),
      ChangeNotifierProvider(create: (_) => StudentOnlineCourseMessagesProvider()),
      ChangeNotifierProvider(create: (_) => AdminApplicationsProvider()),
      ChangeNotifierProvider(create: (_) => AdminApplicationMessagesProvider()),
      ChangeNotifierProvider(create: (_) => AdminProgramsProvider()),
      ChangeNotifierProvider(create: (_) => AdminAcademicAnnouncementsProvider()),
      ChangeNotifierProvider(create: (_) => AdminAcademicEventsProvider()),
      ChangeNotifierProvider(create: (_) => AdminStudentHomeSlotsProvider()),
      ChangeNotifierProvider(create: (_) => AdminCommunitiesProvider()),
      ChangeNotifierProvider(create: (_) => AdminChallengesProvider()),
      ChangeNotifierProvider(create: (_) => AdminPrepConcoursProvider()),
      ChangeNotifierProvider(create: (_) => AdminCoursesProvider()),
      ChangeNotifierProvider(create: (_) => AdminCourseLibraryProvider()),
      ChangeNotifierProvider(create: (_) => AdminOnlineCoursesProvider()),
      ChangeNotifierProvider(create: (_) => AdminLiveSessionsProvider()),
      ChangeNotifierProvider(create: (_) => AdminOnlineCourseMessagesProvider()),
      ChangeNotifierProvider(create: (_) => AdminTdCatalogProvider()),
      ChangeNotifierProvider(create: (_) => AdminTdTeachersProvider()),
      ChangeNotifierProvider(create: (_) => AdminTdStudentRequestsProvider()),
      ChangeNotifierProvider(create: (_) => InstructorOnlineCoursesProvider()),
      ChangeNotifierProvider(create: (_) => InstructorOnlineCourseLiveSessionsProvider()),
      ChangeNotifierProvider(create: (_) => InstructorOnlineCourseForumProvider()),
      ChangeNotifierProvider(create: (_) => AdminUniversitiesProvider()),
      ChangeNotifierProvider(create: (_) => AdminUserInvitationsProvider()),
      ChangeNotifierProvider(create: (_) => AdminUsersOverviewProvider()),
      ChangeNotifierProvider(create: (_) => AdminUniversitySiteProvider()),
      ChangeNotifierProvider(create: (_) => AdminShortTrainingsProvider()),
      ChangeNotifierProvider(create: (_) => AdminShortTrainingMessagesProvider()),
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
      ChangeNotifierProvider(create: (_) => PrepConcoursProvider()),
      ChangeNotifierProvider(create: (_) => StudentTdCatalogProvider()),
      ChangeNotifierProvider(create: (_) => StudentTdEnrollmentsProvider()),
      ChangeNotifierProvider(create: (_) => StudentTdRequestsProvider()),
      ChangeNotifierProvider(create: (_) => TeacherTdAssignmentsProvider()),
      ChangeNotifierProvider(create: (_) => TeacherPrepAssignmentsProvider()),
      ChangeNotifierProvider(create: (_) => TeacherPrepLiveSessionsProvider()),
      ChangeNotifierProvider(create: (_) => AdminTdEnrollmentsProvider()),
      ChangeNotifierProvider(create: (_) => TdMessagesProvider()),
      ChangeNotifierProvider(create: (_) => CommercialDashboardProvider()),
      ChangeNotifierProvider(create: (_) => ShareModeProvider()),
      ChangeNotifierProvider(create: (_) => PrepQuizProvider()),
      ChangeNotifierProvider(create: (_) => PrepFlashcardProvider()),
      ChangeNotifierProvider(create: (_) => TdGamificationProvider()),
      ChangeNotifierProvider(create: (_) => CommunityStoriesProvider()),
      ChangeNotifierProvider(create: (_) => TournamentProvider()),
      ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
    ];

    if (kDebugMode) {
      providers.insert(0, ChangeNotifierProvider(create: (_) => SupabaseProvider()));
    }

    return MultiProvider(
      providers: providers,
      child: MaterialApp(
        title: 'Academia - Projet Supabase',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
        routes: {
          '/auth/callback': (_) => const AuthCallbackScreen(),
          '/games': (_) => const GamesDomainHubScreen(),
          '/tournaments': (_) => const TournamentListScreen(),
          '/leaderboard': (_) => const LeaderboardScreen(),
        },
      ),
    );
  }
}
