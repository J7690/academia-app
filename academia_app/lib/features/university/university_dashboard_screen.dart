import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../widgets/bouton_deconnexion.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/university_applications_provider.dart';
import '../../providers/selected_university_application_provider.dart';
import '../../providers/university_site_provider.dart';
import '../../providers/university_programs_provider.dart';
import '../../providers/university_payments_provider.dart';
import 'university_payments_screen.dart';
import '../../widgets/mini_site_hero_video.dart';
import 'university_application_detail_screen.dart';
import '../../services/notification_sound_service.dart';
import '../student/student_settings_screen.dart';
import '../../widgets/support_fab.dart';
import '../../services/push_trigger_service.dart';
import '../../services/analytics_tracking_service.dart';

class UniversityDashboardScreen extends StatefulWidget {
  const UniversityDashboardScreen({super.key});

  @override
  State<UniversityDashboardScreen> createState() => _UniversityDashboardScreenState();
}

class _UniversityDashboardScreenState extends State<UniversityDashboardScreen> {
  Timer? _pollingTimer;
  int _lastUniversityUnreadCount = 0;
  bool _universityUnreadInitialized = false;

  @override
  void initState() {
    super.initState();
    AnalyticsTrackingService.instance.init();
    AnalyticsTrackingService.instance.trackScreen('university_dashboard');
    _pollingTimer = Timer.periodic(const Duration(seconds: 45), (_) async {
      if (!mounted) return;
      try {
        await context.read<UniversityApplicationsProvider>().loadApplications();
        await _checkUniversityUnreadChange();
      } catch (_) {}
      PushTriggerService.instance.triggerPendingPush();
    });
  }


  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkUniversityUnreadChange() async {
    if (!mounted) return;
    final provider = context.read<UniversityApplicationsProvider>();
    final current = provider.unreadTotal;
    if (!_universityUnreadInitialized) {
      _universityUnreadInitialized = true;
      _lastUniversityUnreadCount = current;
      return;
    }
    if (current > _lastUniversityUnreadCount && current > 0) {
      _lastUniversityUnreadCount = current;
      try {
        await NotificationSoundService.instance.playIfEnabled();
      } catch (_) {}
    } else {
      _lastUniversityUnreadCount = current;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? '';

    return DefaultTabController(
      length: 3,
      child: Consumer2<UniversityApplicationsProvider, UniversitySiteProvider>(
        builder: (context, applicationsProvider, siteProvider, child) {
          final unread = applicationsProvider.unreadTotal;
          final universityName =
              siteProvider.university?['name']?.toString().trim();
          final appBarTitle =
              (universityName != null && universityName.isNotEmpty)
                  ? universityName
                  : 'Dashboard Université';
          return Scaffold(
            backgroundColor: const Color(0xFFF3F4F6),
            floatingActionButton: const SupportFab(),
            appBar: AppBar(
              elevation: 0,
              centerTitle: true,
              title: Text(
                appBarTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              foregroundColor: Colors.white,
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFA3D65C), Color(0xFF1EA75C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              actions: [
                // Hors du menu « Options du compte » : la déconnexion se voit,
                // elle ne se cherche pas. Elle reste aussi dans les paramètres.
                const BoutonDeconnexion(),
                PopupMenuButton<_UniversityDashboardMenuAction>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Options du compte',
                  onSelected: (value) {
                    switch (value) {
                      case _UniversityDashboardMenuAction.settings:
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const StudentSettingsScreen(
                              showDeleteAccount: false,
                              showProfile: false,
                            ),
                          ),
                        );
                        break;
                      case _UniversityDashboardMenuAction.changePassword:
                        _showChangePasswordDialog(context);
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<_UniversityDashboardMenuAction>(
                      value: _UniversityDashboardMenuAction.settings,
                      child: ListTile(
                        leading: Icon(Icons.settings),
                        title: Text('Paramètres'),
                      ),
                    ),
                    PopupMenuItem<_UniversityDashboardMenuAction>(
                      value: _UniversityDashboardMenuAction.changePassword,
                      child: ListTile(
                        leading: Icon(Icons.lock_outline),
                        title: Text('Changer le mot de passe'),
                      ),
                    ),
                  ],
                ),
              ],
              bottom: TabBar(
                isScrollable: false,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: const Color(0xFF1EA75C),
                  borderRadius: BorderRadius.circular(999),
                ),
                indicatorPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                labelPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withOpacity(0.85),
                tabs: [
                  Tab(child: _UniversityTabLabel(text: 'Candidatures', count: unread)),
                  const Tab(text: 'Paiements'),
                  const Tab(text: 'Mini-site & offres'),
                ],
              ),
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4F46E5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.school_outlined,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                universityName ?? 'Compte université',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.email_outlined,
                                    size: 14,
                                    color: Color(0xFF6B7280),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      email,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6B7280),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.mark_unread_chat_alt,
                                    size: 14,
                                    color: Color(0xFF1EA75C),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$unread candidature(s) avec nouveautés',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      const _UniversityCandidaturesWorkspace(),
                      ChangeNotifierProvider(
                        create: (_) => UniversityPaymentsProvider(),
                        child: const UniversityPaymentsScreen(),
                      ),
                      const _UniversitySiteWorkspace(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

enum _UniversityDashboardMenuAction {
  settings,
  changePassword,
}

Future<void> _showChangePasswordDialog(BuildContext context) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  final email = user?.email;

  if (email == null || email.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session expirée. Veuillez vous reconnecter.'),
      ),
    );
    return;
  }

  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final updated = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      String? errorMessage;
      bool isLoading = false;

      Future<void> submit() async {
        final current = currentPasswordController.text.trim();
        final next = newPasswordController.text.trim();
        final confirm = confirmPasswordController.text.trim();

        if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
          errorMessage = 'Merci de remplir tous les champs.';
          (dialogContext as Element).markNeedsBuild();
          return;
        }

        if (next.length < 8) {
          errorMessage = 'Le nouveau mot de passe doit contenir au moins 8 caractères.';
          (dialogContext as Element).markNeedsBuild();
          return;
        }

        if (next != confirm) {
          errorMessage = 'La confirmation ne correspond pas au nouveau mot de passe.';
          (dialogContext as Element).markNeedsBuild();
          return;
        }

        isLoading = true;
        errorMessage = null;
        (dialogContext as Element).markNeedsBuild();

        try {
          await client.auth.signInWithPassword(email: email, password: current);
        } on AuthException {
          isLoading = false;
          errorMessage = 'Mot de passe actuel incorrect.';
          (dialogContext as Element).markNeedsBuild();
          return;
        } catch (_) {
          isLoading = false;
          errorMessage = 'Erreur réseau. Veuillez réessayer.';
          (dialogContext as Element).markNeedsBuild();
          return;
        }

        try {
          await client.auth.updateUser(UserAttributes(password: next));
          if (Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop(true);
          }
        } on AuthException catch (e) {
          isLoading = false;
          errorMessage = e.message ?? 'Impossible de mettre à jour le mot de passe.';
          (dialogContext as Element).markNeedsBuild();
        } catch (_) {
          isLoading = false;
          errorMessage = 'Erreur inattendue. Veuillez réessayer.';
          (dialogContext as Element).markNeedsBuild();
        }
      }

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Changer le mot de passe'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe actuel',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nouveau mot de passe',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirmer le nouveau mot de passe',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (errorMessage != null) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading
                    ? null
                    : () {
                        Navigator.of(dialogContext).pop(false);
                      },
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: isLoading ? null : submit,
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Mettre à jour'),
              ),
            ],
          );
        },
      );
    },
  );

  if (updated == true) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mot de passe mis à jour avec succès.'),
      ),
    );
  }
}

Future<void> _showEditConfigDialog(
  BuildContext context,
  UniversitySiteProvider provider,
) async {
  final current = provider.config ?? <String, dynamic>{};
  final titleController =
      TextEditingController(text: current['hero_title']?.toString() ?? '');
  final subtitleController =
      TextEditingController(text: current['hero_subtitle']?.toString() ?? '');
  final primaryColorController =
      TextEditingController(text: current['hero_primary_color']?.toString() ?? '');
  final secondaryColorController =
      TextEditingController(text: current['hero_secondary_color']?.toString() ?? '');
  final media = provider.media;
  final heroCandidates = media
      .where((m) {
        final type = m['media_type']?.toString().toLowerCase() ?? '';
        final isActive = m['is_active'] != false;
        final url = (m['url'] ?? '').toString().trim();
        final storagePath = (m['storage_path'] ?? '').toString().trim();
        final isVideo = type.contains('video');
        final isImage = type.contains('image');
        if (!isVideo && !isImage) return false;
        if (!isActive) return false;
        return url.isNotEmpty || storagePath.isNotEmpty;
      })
      .toList(growable: false);
  String? selectedHeroMediaId = current['hero_poster_media_id']?.toString();

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Configuration du hero'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Titre *',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: subtitleController,
                    decoration: const InputDecoration(
                      labelText: 'Sous-titre',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: primaryColorController,
                    decoration: const InputDecoration(
                      labelText: 'Couleur primaire (hex, optionnel)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: secondaryColorController,
                    decoration: const InputDecoration(
                      labelText: 'Couleur secondaire (hex, optionnel)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (heroCandidates.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: selectedHeroMediaId != null &&
                              heroCandidates
                                  .any((m) => m['id']?.toString() == selectedHeroMediaId)
                          ? selectedHeroMediaId
                          : null,
                      items: heroCandidates.map((m) {
                        final id = m['id']?.toString();
                        if (id == null) return null;
                        final title = m['title']?.toString() ?? '';
                        final type = m['media_type']?.toString() ?? '';
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text(
                            [title, type].where((e) => e.isNotEmpty).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).whereType<DropdownMenuItem<String>>().toList(),
                      decoration: const InputDecoration(
                        labelText: 'Média hero (affiche, optionnel)',
                      ),
                      onChanged: (value) {
                        setState(() {
                          selectedHeroMediaId = value;
                        });
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  final subtitle = subtitleController.text.trim();
                  final primaryColor = primaryColorController.text.trim();
                  final secondaryColor = secondaryColorController.text.trim();

                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Le titre du hero est obligatoire.'),
                      ),
                    );
                    return;
                  }

                  final ok = await provider.upsertConfig(
                    heroTitle: title,
                    heroSubtitle: subtitle.isNotEmpty ? subtitle : null,
                    heroPrimaryColor: primaryColor.isNotEmpty ? primaryColor : null,
                    heroSecondaryColor:
                        secondaryColor.isNotEmpty ? secondaryColor : null,
                    heroPosterMediaId: selectedHeroMediaId,
                  );
                  if (!context.mounted) return;
                  if (ok) {
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          provider.error ??
                              'Erreur lors de la sauvegarde de la configuration.',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      );
    },
  );
}

class _UniversityProgramCoursesSheet extends StatelessWidget {
  final String programId;
  final String programTitle;

  const _UniversityProgramCoursesSheet({
    required this.programId,
    required this.programTitle,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<UniversityProgramsProvider>();
    final allCourses = provider.courses;
    final programCourses = allCourses
        .where((c) => c['program_id']?.toString() == programId)
        .toList(growable: false);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cours du programme',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                if (programTitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    programTitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showEditCourseDialog(
                        context,
                        provider,
                        programId: programId,
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter un cours'),
                    ),
                    const SizedBox(width: 8),
                    if (provider.error != null)
                      Expanded(
                        child: Text(provider.error!),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (programCourses.isEmpty)
                  const Text('Aucun cours configuré pour ce programme.')
                else
                  ...programCourses.map((course) {
                    final title = course['title']?.toString() ?? '';
                    final description = course['description']?.toString() ?? '';
                    final credits = course['credits'];
                    final instructor = course['instructor']?.toString() ?? '';
                    final isActive = course['is_active'] != false;

                    final metaParts = <String>[];
                    if (credits is int) {
                      metaParts.add('$credits crédits');
                    } else if (credits is String && credits.isNotEmpty) {
                      metaParts.add('$credits crédits');
                    }
                    if (instructor.isNotEmpty) {
                      metaParts.add(instructor);
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Chip(
                                  label: Text(isActive ? 'Actif' : 'Inactif'),
                                ),
                              ],
                            ),
                            if (metaParts.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                metaParts.join(' • '),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                description,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _showEditCourseDialog(
                                  context,
                                  provider,
                                  programId: programId,
                                  course: course,
                                ),
                                icon: const Icon(Icons.edit),
                                label: const Text('Modifier'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showEditCourseDialog(
  BuildContext context,
  UniversityProgramsProvider provider, {
  required String programId,
  Map<String, dynamic>? course,
}) async {
  final titleController = TextEditingController(text: course?['title']?.toString() ?? '');
  final descriptionController =
      TextEditingController(text: course?['description']?.toString() ?? '');
  final creditsController =
      TextEditingController(text: course?['credits']?.toString() ?? '');
  final prerequisitesController =
      TextEditingController(text: course?['prerequisites']?.toString() ?? '');
  final instructorController =
      TextEditingController(text: course?['instructor']?.toString() ?? '');
  bool isActive = course?['is_active'] != false;

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(course == null ? 'Ajouter un cours' : 'Modifier le cours'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Titre du cours *',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: creditsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Crédits',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: prerequisitesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Prérequis',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: instructorController,
                    decoration: const InputDecoration(
                      labelText: 'Enseignant',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: isActive,
                        onChanged: (value) {
                          setState(() {
                            isActive = value ?? true;
                          });
                        },
                      ),
                      const Text('Cours actif'),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  final description = descriptionController.text.trim();
                  final creditsText = creditsController.text.trim();
                  final prerequisites = prerequisitesController.text.trim();
                  final instructor = instructorController.text.trim();

                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Le titre du cours est obligatoire.'),
                      ),
                    );
                    return;
                  }

                  final credits =
                      creditsText.isEmpty ? null : int.tryParse(creditsText);

                  final ok = await provider.upsertCourse(
                    courseId: course?['id']?.toString(),
                    programId: programId,
                    title: title,
                    description: description.isNotEmpty ? description : null,
                    credits: credits,
                    prerequisites:
                        prerequisites.isNotEmpty ? prerequisites : null,
                    instructor: instructor.isNotEmpty ? instructor : null,
                    isActive: isActive,
                  );
                  if (!context.mounted) return;
                  if (ok) {
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          provider.error ??
                              'Erreur lors de la sauvegarde du cours.',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _showEditEventDialog(
  BuildContext context,
  UniversitySiteProvider provider, {
  Map<String, dynamic>? event,
}) async {
  final titleController = TextEditingController(text: event?['title']?.toString() ?? '');
  final descriptionController =
      TextEditingController(text: event?['description']?.toString() ?? '');
  final typeController = TextEditingController(text: event?['event_type']?.toString() ?? '');
  final locationController = TextEditingController(text: event?['location']?.toString() ?? '');
  final startAtController =
      TextEditingController(text: event?['start_at']?.toString() ?? '');
  final endAtController = TextEditingController(text: event?['end_at']?.toString() ?? '');
  bool isHighlighted = event?['is_highlighted'] == true;
  bool isActive = event?['is_active'] != false;

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(event == null ? 'Ajouter un événement' : 'Modifier l\'événement'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Titre de l\'événement *',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: typeController,
                    decoration: const InputDecoration(
                      labelText: 'Type (portes ouvertes, webinaire...)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: 'Lieu (présentiel / en ligne...)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: startAtController,
                    decoration: const InputDecoration(
                      labelText: 'Début (ISO 8601, optionnel)',
                      hintText: '2025-03-15T09:00:00Z',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: endAtController,
                    decoration: const InputDecoration(
                      labelText: 'Fin (ISO 8601, optionnel)',
                      hintText: '2025-03-15T12:00:00Z',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: isHighlighted,
                        onChanged: (value) {
                          setState(() {
                            isHighlighted = value ?? false;
                          });
                        },
                      ),
                      const Text('Mettre en avant'),
                    ],
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: isActive,
                        onChanged: (value) {
                          setState(() {
                            isActive = value ?? true;
                          });
                        },
                      ),
                      const Text('Événement actif'),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  final description = descriptionController.text.trim();
                  final type = typeController.text.trim();
                  final location = locationController.text.trim();
                  final startText = startAtController.text.trim();
                  final endText = endAtController.text.trim();

                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Le titre de l\'événement est obligatoire.'),
                      ),
                    );
                    return;
                  }

                  DateTime? startAt;
                  DateTime? endAt;

                  if (startText.isNotEmpty) {
                    startAt = DateTime.tryParse(startText);
                    if (startAt == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Format de date de début invalide.'),
                        ),
                      );
                      return;
                    }
                  }

                  if (endText.isNotEmpty) {
                    endAt = DateTime.tryParse(endText);
                    if (endAt == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Format de date de fin invalide.'),
                        ),
                      );
                      return;
                    }
                  }

                  final ok = await provider.upsertEvent(
                    eventId: event?['id']?.toString(),
                    title: title,
                    description: description.isNotEmpty ? description : null,
                    eventType: type.isNotEmpty ? type : null,
                    startAt: startAt,
                    endAt: endAt,
                    location: location.isNotEmpty ? location : null,
                    isHighlighted: isHighlighted,
                    isActive: isActive,
                  );
                  if (!context.mounted) return;
                  if (ok) {
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          provider.error ??
                              'Erreur lors de la sauvegarde de l\'événement.',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _showEditNewsDialog(
  BuildContext context,
  UniversitySiteProvider provider, {
  Map<String, dynamic>? news,
}) async {
  final titleController = TextEditingController(text: news?['title']?.toString() ?? '');
  final slugController = TextEditingController(text: news?['slug']?.toString() ?? '');
  final summaryController =
      TextEditingController(text: news?['summary']?.toString() ?? '');
  final contentController =
      TextEditingController(text: news?['content']?.toString() ?? '');
  final publishedAtController =
      TextEditingController(text: news?['published_at']?.toString() ?? '');
  final heroMediaIdRaw = news?['hero_media_id']?.toString();
  String? selectedHeroMediaId = heroMediaIdRaw?.isNotEmpty == true ? heroMediaIdRaw : null;
  bool isActive = news?['is_active'] != false;

  await showDialog<void>(
    context: context,
    builder: (context) {
      final mediaItems = provider.media;

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(news == null ? 'Ajouter une actualité' : 'Modifier l\'actualité'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Titre de l\'actualité *',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: slugController,
                    decoration: const InputDecoration(
                      labelText: 'Slug (optionnel, unique)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: summaryController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Résumé (court)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: contentController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Contenu (détail)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: publishedAtController,
                    decoration: const InputDecoration(
                      labelText: 'Date de publication (ISO 8601, optionnel)',
                      hintText: '2025-03-15T10:00:00Z',
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (mediaItems.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: selectedHeroMediaId != null &&
                              mediaItems.any((m) => m['id']?.toString() == selectedHeroMediaId)
                          ? selectedHeroMediaId
                          : null,
                      items: mediaItems
                          .map((m) {
                            final id = m['id']?.toString();
                            if (id == null) return null;
                            final title = m['title']?.toString() ?? '';
                            final type = m['media_type']?.toString() ?? '';
                            return DropdownMenuItem<String>(
                              value: id,
                              child: Text(
                                [title, type].where((e) => e.isNotEmpty).join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          })
                          .whereType<DropdownMenuItem<String>>()
                          .toList(),
                      decoration: const InputDecoration(
                        labelText: 'Média hero (optionnel)',
                      ),
                      onChanged: (value) {
                        setState(() {
                          selectedHeroMediaId = value;
                        });
                      },
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: isActive,
                        onChanged: (value) {
                          setState(() {
                            isActive = value ?? true;
                          });
                        },
                      ),
                      const Text('Actualité publiée'),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  final slug = slugController.text.trim();
                  final summary = summaryController.text.trim();
                  final content = contentController.text.trim();
                  final publishedText = publishedAtController.text.trim();

                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Le titre de l\'actualité est obligatoire.'),
                      ),
                    );
                    return;
                  }

                  DateTime? publishedAt;
                  if (publishedText.isNotEmpty) {
                    publishedAt = DateTime.tryParse(publishedText);
                    if (publishedAt == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Format de date de publication invalide.'),
                        ),
                      );
                      return;
                    }
                  }

                  final ok = await provider.upsertNews(
                    newsId: news?['id']?.toString(),
                    title: title,
                    slug: slug.isNotEmpty ? slug : null,
                    summary: summary.isNotEmpty ? summary : null,
                    content: content.isNotEmpty ? content : null,
                    publishedAt: publishedAt,
                    heroMediaId: selectedHeroMediaId,
                    isActive: isActive,
                  );
                  if (!context.mounted) return;
                  if (ok) {
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          provider.error ??
                              'Erreur lors de la sauvegarde de l\'actualité.',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _showEditStaffDialog(
  BuildContext context,
  UniversitySiteProvider provider, {
  Map<String, dynamic>? staff,
}) async {
  final fullNameController =
      TextEditingController(text: staff?['full_name']?.toString() ?? '');
  final roleController = TextEditingController(text: staff?['role']?.toString() ?? '');
  final bioController = TextEditingController(text: staff?['bio']?.toString() ?? '');
  final emailController = TextEditingController(text: staff?['email']?.toString() ?? '');
  final phoneController = TextEditingController(text: staff?['phone']?.toString() ?? '');
  final sortOrderController =
      TextEditingController(text: staff?['sort_order']?.toString() ?? '');
  final photoMediaIdRaw = staff?['photo_media_id']?.toString();
  String? selectedPhotoMediaId =
      photoMediaIdRaw?.isNotEmpty == true ? photoMediaIdRaw : null;
  bool isActive = staff?['is_active'] != false;

  await showDialog<void>(
    context: context,
    builder: (context) {
      final mediaItems = provider.media;

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
                staff == null ? 'Ajouter un membre de l\'équipe' : 'Modifier le membre de l\'équipe'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom complet *',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: roleController,
                    decoration: const InputDecoration(
                      labelText: 'Rôle / fonction',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: bioController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Bio courte',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email (optionnel)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone (optionnel)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: sortOrderController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Ordre d\'affichage',
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (mediaItems.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: selectedPhotoMediaId != null &&
                              mediaItems.any((m) => m['id']?.toString() == selectedPhotoMediaId)
                          ? selectedPhotoMediaId
                          : null,
                      items: mediaItems
                          .map((m) {
                            final id = m['id']?.toString();
                            if (id == null) return null;
                            final title = m['title']?.toString() ?? '';
                            final type = m['media_type']?.toString() ?? '';
                            return DropdownMenuItem<String>(
                              value: id,
                              child: Text(
                                [title, type].where((e) => e.isNotEmpty).join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          })
                          .whereType<DropdownMenuItem<String>>()
                          .toList(),
                      decoration: const InputDecoration(
                        labelText: 'Média photo (optionnel)',
                      ),
                      onChanged: (value) {
                        setState(() {
                          selectedPhotoMediaId = value;
                        });
                      },
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: isActive,
                        onChanged: (value) {
                          setState(() {
                            isActive = value ?? true;
                          });
                        },
                      ),
                      const Text('Membre actif'),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () async {
                  final fullName = fullNameController.text.trim();
                  final role = roleController.text.trim();
                  final bio = bioController.text.trim();
                  final email = emailController.text.trim();
                  final phone = phoneController.text.trim();
                  final sortText = sortOrderController.text.trim();

                  if (fullName.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Le nom complet est obligatoire.'),
                      ),
                    );
                    return;
                  }

                  final sortOrder = sortText.isEmpty ? null : int.tryParse(sortText);

                  final ok = await provider.upsertStaff(
                    staffId: staff?['id']?.toString(),
                    fullName: fullName,
                    role: role.isNotEmpty ? role : null,
                    bio: bio.isNotEmpty ? bio : null,
                    photoMediaId: selectedPhotoMediaId,
                    email: email.isNotEmpty ? email : null,
                    phone: phone.isNotEmpty ? phone : null,
                    sortOrder: sortOrder,
                    isActive: isActive,
                  );
                  if (!context.mounted) return;
                  if (ok) {
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          provider.error ??
                              'Erreur lors de la sauvegarde du membre de l\'équipe.',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _showEditBannerDialog(
  BuildContext context,
  UniversitySiteProvider provider, {
  Map<String, dynamic>? banner,
  List<Map<String, dynamic>> media = const [],
}) async {
  final positionController =
      TextEditingController(text: banner?['position']?.toString() ?? 'top_carousel');
  final titleController =
      TextEditingController(text: banner?['title']?.toString() ?? '');
  final subtitleController =
      TextEditingController(text: banner?['subtitle']?.toString() ?? '');
  final sortOrderController = TextEditingController(
    text: banner?['sort_order']?.toString() ?? '',
  );
  bool isActive = banner?['is_active'] != false;
  String? selectedMediaId = banner?['media_id']?.toString();

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(banner == null ? 'Ajouter une bannière' : 'Modifier la bannière'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: positionController,
                    decoration: const InputDecoration(
                      labelText: 'Position (top_carousel, middle_strip, bottom_strip)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Titre *',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: subtitleController,
                    decoration: const InputDecoration(
                      labelText: 'Sous-titre',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: sortOrderController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Ordre d\'affichage',
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (media.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: selectedMediaId != null &&
                              media.any((m) => m['id']?.toString() == selectedMediaId)
                          ? selectedMediaId
                          : null,
                      items: media.map((m) {
                        final id = m['id']?.toString();
                        final title = m['title']?.toString() ?? '';
                        final type = m['media_type']?.toString() ?? '';
                        if (id == null) {
                          return null;
                        }
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text(
                            [title, type].where((e) => e.isNotEmpty).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).whereType<DropdownMenuItem<String>>().toList(),
                      decoration: const InputDecoration(
                        labelText: 'Média associé (optionnel)',
                      ),
                      onChanged: (value) {
                        setState(() {
                          selectedMediaId = value;
                        });
                      },
                    ),
                  Row(
                    children: [
                      Checkbox(
                        value: isActive,
                        onChanged: (value) {
                          setState(() {
                            isActive = value ?? true;
                          });
                        },
                      ),
                      const Text('Bannière active'),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () async {
                  final position = positionController.text.trim();
                  final title = titleController.text.trim();
                  final subtitle = subtitleController.text.trim();
                  final sortText = sortOrderController.text.trim();

                  if (position.isEmpty || title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('La position et le titre sont obligatoires.'),
                      ),
                    );
                    return;
                  }

                  final sortOrder =
                      sortText.isEmpty ? null : int.tryParse(sortText);

                  final ok = await provider.upsertBanner(
                    bannerId: banner?['id']?.toString(),
                    position: position,
                    title: title,
                    subtitle: subtitle.isNotEmpty ? subtitle : null,
                    mediaId: selectedMediaId,
                    sortOrder: sortOrder,
                    isActive: isActive,
                  );
                  if (!context.mounted) return;
                  if (ok) {
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          provider.error ??
                              'Erreur lors de la sauvegarde de la bannière.',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      );
    },
  );
}

class _UniversityTabLabel extends StatelessWidget {
  final String text;
  final int count;

  const _UniversityTabLabel({required this.text, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return Text(text);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFFF3B30),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            count > 9 ? '9+' : '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _ApplicationStatusBadge extends StatelessWidget {
  final String status;

  const _ApplicationStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _ApplicationStatusConfig.fromStatus(status);
    if (config == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: config.color.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: config.color,
        ),
      ),
    );
  }
}

class _ApplicationStatusConfig {
  final String label;
  final Color color;

  const _ApplicationStatusConfig({required this.label, required this.color});

  static _ApplicationStatusConfig? fromStatus(String raw) {
    final value = raw.toLowerCase().trim();
    switch (value) {
      case 'submitted':
        return const _ApplicationStatusConfig(
          label: 'Soumise',
          color: Color(0xFF2563EB),
        );
      case 'under_review':
        return const _ApplicationStatusConfig(
          label: 'En étude',
          color: Color(0xFFF59E0B),
        );
      case 'accepted':
        return const _ApplicationStatusConfig(
          label: 'Acceptée',
          color: Color(0xFF10B981),
        );
      case 'rejected':
        return const _ApplicationStatusConfig(
          label: 'Refusée',
          color: Color(0xFFEF4444),
        );
      case 'canceled':
        return const _ApplicationStatusConfig(
          label: 'Annulée',
          color: Color(0xFF6B7280),
        );
      default:
        return null;
    }
  }
}

class _UniversityCandidaturesWorkspace extends StatefulWidget {
  const _UniversityCandidaturesWorkspace();

  @override
  State<_UniversityCandidaturesWorkspace> createState() => _UniversityCandidaturesWorkspaceState();
}

class _UniversityCandidaturesWorkspaceState extends State<_UniversityCandidaturesWorkspace> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<UniversityApplicationsProvider>().loadApplications();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Consumer<UniversityApplicationsProvider>(
              builder: (context, provider, child) {
                final receivedCount = provider.unreadReceived;
                final treatedCount = provider.unreadTreated;
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5F3FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: TabBar(
                    isScrollable: false,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: const Color(0xFF1EA75C),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    indicatorPadding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 1,
                    ),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                    labelColor: Colors.white,
                    unselectedLabelColor: const Color(0xFF1F2937),
                    tabs: [
                      Tab(
                        child: _UniversityTabLabel(
                          text: 'Reçues',
                          count: receivedCount,
                        ),
                      ),
                      Tab(
                        child: _UniversityTabLabel(
                          text: 'Traitées',
                          count: treatedCount,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          const Expanded(
            child: TabBarView(
              children: [
                _UniversityApplicationsBucket(received: true),
                _UniversityApplicationsBucket(received: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UniversityApplicationsBucket extends StatelessWidget {
  final bool received;

  const _UniversityApplicationsBucket({required this.received});

  @override
  Widget build(BuildContext context) {
    return Consumer2<UniversityApplicationsProvider, SelectedUniversityApplicationProvider>(
      builder: (context, applicationsProvider, selectionProvider, child) {
        if (applicationsProvider.isLoading && applicationsProvider.applications.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (applicationsProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(applicationsProvider.error!),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: applicationsProvider.loadApplications,
                  child: const Text('Recharger'),
                ),
              ],
            ),
          );
        }

        final all = applicationsProvider.applications;
        final apps = all.where((app) {
          final status = app['status']?.toString();
          if (received) {
            return status == 'submitted';
          }
          return status == 'under_review' ||
              status == 'accepted' ||
              status == 'rejected' ||
              status == 'canceled';
        }).toList();

        if (apps.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                received
                    ? 'Aucune candidature reçue pour le moment.'
                    : 'Aucune candidature traitée pour le moment.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final selected = selectionProvider.selectedApplication;
        late Map<String, dynamic> effectiveSelected;
        if (selected != null && apps.any((a) => a['id'] == selected['id'])) {
          effectiveSelected = selected;
        } else {
          effectiveSelected = apps.first;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final appId = effectiveSelected['id']?.toString();
            if (appId != null && appId.isNotEmpty) {
              try {
                applicationsProvider.markApplicationSeen(appId);
              } catch (_) {}
            }
            selectionProvider.selectApplication(effectiveSelected);
          });
        }

        Widget buildList() {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: apps.length,
            itemBuilder: (context, index) {
              final app = apps[index];
              final isSelected = app['id'] == effectiveSelected['id'];
              final status = (app['status']?.toString() ?? '').trim();
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                shadowColor: const Color(0x0D000000),
                color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: isSelected
                      ? BorderSide(
                          color: const Color(0xFF1EA75C),
                          width: 1.5,
                        )
                      : const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    final appId = app['id']?.toString();
                    if (appId != null && appId.isNotEmpty) {
                      try {
                        applicationsProvider.markApplicationSeen(appId);
                      } catch (_) {}
                    }
                    selectionProvider.selectApplication(app);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => UniversityApplicationDetailScreen(
                          application: app,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                app['program_title']?.toString() ?? 'Programme inconnu',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0A2540),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (status.isNotEmpty)
                              _ApplicationStatusBadge(status: status),
                            if ((app['has_unread_for_university'] == true) ||
                                (app['has_unseen_for_university'] == true))
                              const Icon(
                                Icons.mark_unread_chat_alt,
                                size: 18,
                                color: Color(0xFFFF3B30),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Étudiant : ${app['student_full_name'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                        if (app['last_message_at'] != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Dernier message : ${app['last_message_at']}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }

        return buildList();
      },
    );
  }
}

class _UniversitySiteEventsTab extends StatelessWidget {
  const _UniversitySiteEventsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<UniversitySiteProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.events.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final events = provider.events;

        if (events.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showEditEventDialog(context, provider),
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter un événement'),
                    ),
                    const SizedBox(width: 8),
                    if (provider.error != null)
                      Expanded(child: Text(provider.error!)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Aucun événement configuré pour le moment.'),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showEditEventDialog(context, provider),
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un événement'),
                  ),
                  const SizedBox(width: 8),
                  if (provider.error != null)
                    Expanded(child: Text(provider.error!)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  final title = event['title']?.toString() ?? '';
                  final description = event['description']?.toString() ?? '';
                  final type = event['event_type']?.toString() ?? '';
                  final location = event['location']?.toString() ?? '';
                  final startAt = event['start_at']?.toString() ?? '';
                  final endAt = event['end_at']?.toString() ?? '';
                  final isHighlighted = event['is_highlighted'] == true;
                  final isActive = event['is_active'] != false;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (type.isNotEmpty) Chip(label: Text(type)),
                              const SizedBox(width: 8),
                              Chip(label: Text(isActive ? 'Actif' : 'Inactif')),
                              const SizedBox(width: 8),
                              if (isHighlighted)
                                const Chip(
                                  label: Text('En vedette'),
                                ),
                            ],
                          ),
                          if (location.isNotEmpty || startAt.isNotEmpty || endAt.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              [
                                if (location.isNotEmpty) location,
                                if (startAt.isNotEmpty) 'Début: $startAt',
                                if (endAt.isNotEmpty) 'Fin: $endAt',
                              ].join(' · '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => _showEditEventDialog(
                                  context,
                                  provider,
                                  event: event,
                                ),
                                icon: const Icon(Icons.edit),
                                label: const Text('Modifier'),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () async {
                                  final id = event['id']?.toString();
                                  if (id == null) return;
                                  final ok = await provider.deleteEvent(id);
                                  if (!context.mounted) return;
                                  if (!ok) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          provider.error ??
                                              'Erreur lors de la suppression de l\'événement.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Supprimer'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _UniversitySiteNewsTab extends StatelessWidget {
  const _UniversitySiteNewsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<UniversitySiteProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.news.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final news = provider.news;

        if (news.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showEditNewsDialog(context, provider),
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter une actualité'),
                    ),
                    const SizedBox(width: 8),
                    if (provider.error != null)
                      Expanded(child: Text(provider.error!)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Aucune actualité configurée pour le moment.'),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showEditNewsDialog(context, provider),
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter une actualité'),
                  ),
                  const SizedBox(width: 8),
                  if (provider.error != null)
                    Expanded(child: Text(provider.error!)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: news.length,
                itemBuilder: (context, index) {
                  final item = news[index];
                  final title = item['title']?.toString() ?? '';
                  final summary = item['summary']?.toString() ?? '';
                  final content = item['content']?.toString() ?? '';
                  final slug = item['slug']?.toString() ?? '';
                  final publishedAt = item['published_at']?.toString() ?? '';
                  final isActive = item['is_active'] != false;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Chip(label: Text(isActive ? 'Publiée' : 'Masquée')),
                            ],
                          ),
                          if (slug.isNotEmpty || publishedAt.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text([
                              if (slug.isNotEmpty) 'Slug: $slug',
                              if (publishedAt.isNotEmpty) 'Publié le: $publishedAt',
                            ].join(' · ')),
                          ],
                          if (summary.isNotEmpty || content.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              summary.isNotEmpty ? summary : content,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => _showEditNewsDialog(
                                  context,
                                  provider,
                                  news: item,
                                ),
                                icon: const Icon(Icons.edit),
                                label: const Text('Modifier'),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () async {
                                  final id = item['id']?.toString();
                                  if (id == null) return;
                                  final ok = await provider.deleteNews(id);
                                  if (!context.mounted) return;
                                  if (!ok) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          provider.error ??
                                              'Erreur lors de la suppression de l\'actualité.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Supprimer'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _UniversitySiteStaffTab extends StatelessWidget {
  const _UniversitySiteStaffTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<UniversitySiteProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.staff.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final staff = provider.staff;

        if (staff.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showEditStaffDialog(context, provider),
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter un membre de l\'équipe'),
                    ),
                    const SizedBox(width: 8),
                    if (provider.error != null)
                      Expanded(child: Text(provider.error!)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Aucun membre d\'équipe configuré pour le moment.'),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showEditStaffDialog(context, provider),
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un membre de l\'équipe'),
                  ),
                  const SizedBox(width: 8),
                  if (provider.error != null)
                    Expanded(child: Text(provider.error!)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: staff.length,
                itemBuilder: (context, index) {
                  final member = staff[index];
                  final fullName = member['full_name']?.toString() ?? '';
                  final role = member['role']?.toString() ?? '';
                  final bio = member['bio']?.toString() ?? '';
                  final sortOrder = member['sort_order']?.toString() ?? '';
                  final isActive = member['is_active'] != false;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  fullName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (role.isNotEmpty) Chip(label: Text(role)),
                              const SizedBox(width: 8),
                              Chip(label: Text(isActive ? 'Actif' : 'Inactif')),
                              if (sortOrder.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Chip(label: Text('Ordre $sortOrder')),
                              ],
                            ],
                          ),
                          if (bio.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              bio,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => _showEditStaffDialog(
                                  context,
                                  provider,
                                  staff: member,
                                ),
                                icon: const Icon(Icons.edit),
                                label: const Text('Modifier'),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () async {
                                  final id = member['id']?.toString();
                                  if (id == null) return;
                                  final ok = await provider.deleteStaff(id);
                                  if (!context.mounted) return;
                                  if (!ok) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          provider.error ??
                                              'Erreur lors de la suppression du membre de l\'équipe.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Supprimer'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _UniversitySiteWorkspace extends StatefulWidget {
  const _UniversitySiteWorkspace();

  @override
  State<_UniversitySiteWorkspace> createState() => _UniversitySiteWorkspaceState();
}

class _UniversitySiteWorkspaceState extends State<_UniversitySiteWorkspace> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<UniversitySiteProvider>().loadSite();
      } catch (_) {}
      try {
        context.read<UniversityProgramsProvider>().loadPrograms();
      } catch (_) {}
      try {
        context.read<UniversityProgramsProvider>().loadCourses();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return const _UniversitySitePreview();
  }
}

class _UniversitySiteEditorWorkspace extends StatelessWidget {
  const _UniversitySiteEditorWorkspace();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Configurer le mini-site',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Avancez étape par étape pour renseigner l\'identité, les contenus, les médias, les programmes, les événements, les actualités et l\'équipe de votre université.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          TabBar(
            isScrollable: true,
            indicatorSize: TabBarIndicatorSize.label,
            indicator: BoxDecoration(
              color: const Color(0xFF1EA75C),
              borderRadius: BorderRadius.circular(999),
            ),
            indicatorPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            labelPadding: const EdgeInsets.symmetric(horizontal: 12),
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0xFF4B5563),
            tabs: const [
              Tab(text: 'Identité & contact'),
              Tab(text: 'Pages & contenus'),
              Tab(text: 'Médias & ambiance'),
              Tab(text: 'Programmes & formations'),
              Tab(text: 'Événements'),
              Tab(text: 'Actualités'),
              Tab(text: 'Équipe'),
            ],
          ),
          const Divider(height: 1),
          const Expanded(
            child: TabBarView(
              children: [
                _UniversitySiteConfigTab(),
                _UniversitySiteBlocksTab(),
                _UniversitySiteMediaTab(),
                _UniversitySiteProgramsTab(),
                _UniversitySiteEventsTab(),
                _UniversitySiteNewsTab(),
                _UniversitySiteStaffTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UniversitySitePreview extends StatelessWidget {
  const _UniversitySitePreview();

  @override
  Widget build(BuildContext context) {
    return Consumer2<UniversitySiteProvider, UniversityProgramsProvider>(
      builder: (context, siteProvider, programsProvider, child) {
        if (siteProvider.isLoading && siteProvider.university == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (siteProvider.error != null && siteProvider.university == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(siteProvider.error!),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: siteProvider.loadSite,
                    child: const Text('Recharger le mini-site'),
                  ),
                ],
              ),
            ),
          );
        }

        final university = siteProvider.university;
        final config = siteProvider.config;
        final blocks = siteProvider.blocks;
        final allMedia = siteProvider.media;
        final media = allMedia
            .where((m) => m['is_active'] != false)
            .toList(growable: false);
        final banners = siteProvider.banners;
        final events = siteProvider.events;
        final news = siteProvider.news;
        final staff = siteProvider.staff;
        final allPrograms = programsProvider.programs;
        final programs = allPrograms
            .where((p) => p['is_active'] != false)
            .toList(growable: false);
        final courses = programsProvider.courses;

        if (university == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Mini-site non encore configuré pour cette université.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: siteProvider.loadSite,
                    child: const Text('Initialiser / recharger'),
                  ),
                ],
              ),
            ),
          );
        }

        final name = university['name']?.toString() ?? '';
        final city = university['city']?.toString() ?? '';
        final country = university['country']?.toString() ?? '';
        final description = university['description']?.toString() ?? '';
        final websiteUrl = university['website_url']?.toString() ?? '';
        final logoUrl = university['logo_url']?.toString() ?? '';
        final tagline = university['tagline']?.toString() ?? '';
        final mission = university['mission']?.toString() ?? '';
        final vision = university['vision']?.toString() ?? '';
        final contactEmail = university['contact_email']?.toString() ?? '';
        final contactPhone = university['contact_phone']?.toString() ?? '';
        final address = university['address']?.toString() ?? '';

        Map<String, dynamic> keyFigures = {};
        final rawKeyFigures = university['key_figures'];
        if (rawKeyFigures is Map) {
          keyFigures = Map<String, dynamic>.from(rawKeyFigures);
        }

        Map<String, dynamic> socialLinks = {};
        final rawSocialLinks = university['social_links'];
        if (rawSocialLinks is Map) {
          socialLinks = Map<String, dynamic>.from(rawSocialLinks);
        }

        final heroTitle = (config?['hero_title']?.toString() ?? '').trim();
        final heroSubtitle = (config?['hero_subtitle']?.toString() ?? '').trim();
        final heroPosterMediaId = config?['hero_poster_media_id']?.toString();

        final aboutBlocks = blocks
            .where((b) => (b['key']?.toString() ?? '').toLowerCase() == 'about')
            .toList(growable: false);
        final otherBlocks = blocks
            .where((b) => (b['key']?.toString() ?? '').toLowerCase() != 'about')
            .toList(growable: false);

        final highlightedPrograms =
            programs.where((p) => p['highlighted'] == true).toList(growable: false);
        final otherPrograms =
            programs.where((p) => p['highlighted'] != true).toList(growable: false);

        final topBanners = banners
            .where((b) => (b['position']?.toString() ?? '') == 'top_carousel')
            .toList(growable: false);
        final middleBanners = banners
            .where((b) => (b['position']?.toString() ?? '') == 'middle_strip')
            .toList(growable: false);
        final bottomBanners = banners
            .where((b) => (b['position']?.toString() ?? '') == 'bottom_strip')
            .toList(growable: false);

        final locationText = [city, country]
            .where((e) => e.trim().isNotEmpty)
            .join(', ');

        final heroTagline = tagline.isNotEmpty
            ? tagline
            : (mission.isNotEmpty
                ? mission
                : vision);

        return Container(
          color: const Color(0xFFF3F4F6),
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF006D3C),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  locationText,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                if (websiteUrl.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    websiteUrl,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Aperçu du mini-site',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFFE53935),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Zone Hero : toujours afficher, même si vide
                      if (media.isNotEmpty) ...[
                        MiniSiteHeroVideo(
                          media: media,
                          title: heroTitle.isNotEmpty ? heroTitle : name,
                          location: locationText,
                          tagline: heroTagline.isNotEmpty ? heroTagline : null,
                          logoUrl: logoUrl.isNotEmpty ? logoUrl : null,
                          heroPosterMediaId: heroPosterMediaId,
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        // Placeholder hero vide
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD1D5DB)),
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.photo_library_outlined, size: 48, color: Color(0xFF9CA3AF)),
                                SizedBox(height: 8),
                                Text(
                                  'Ajouter une image ou vidéo hero',
                                  style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Médias / Ambiance : toujours afficher le titre et le bouton
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Médias / ambiance du campus',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              _showMiniSiteMediaManager(context);
                            },
                            icon: const Icon(Icons.photo_library_outlined, size: 16),
                            label: const Text('Gérer les médias'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (media.isNotEmpty || topBanners.isNotEmpty) ...[
                        Card(
                          color: Colors.white,
                          elevation: 2,
                          shadowColor: const Color(0x0D000000),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: _MediaStrip(media: media),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        Card(
                          color: Colors.white,
                          elevation: 2,
                          shadowColor: const Color(0x0D000000),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: const Center(
                              child: Column(
                                children: [
                                  Icon(Icons.photo_library_outlined, size: 48, color: Color(0xFF9CA3AF)),
                                  SizedBox(height: 8),
                                  Text(
                                    'Aucun média pour le moment.\nCliquez sur « Gérer les médias » pour en ajouter.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Présentation de l\'université',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              _showMiniSiteConfigManager(context);
                            },
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('Configurer'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Card(
                        color: Colors.white,
                        elevation: 2,
                        shadowColor: const Color(0x0D000000),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (logoUrl.isNotEmpty)
                                Align(
                                  alignment: Alignment.topRight,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      logoUrl,
                                      height: 48,
                                      width: 48,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, _, __) =>
                                          const SizedBox.shrink(),
                                    ),
                                  ),
                                ),
                              Text(
                                heroTitle.isNotEmpty ? heroTitle : name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tagline.isNotEmpty
                                    ? tagline
                                    : (mission.isNotEmpty ? mission : vision),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                heroSubtitle.isNotEmpty
                                    ? heroSubtitle
                                    : description,
                              ),
                              if (keyFigures.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _KeyFiguresChips(keyFigures: keyFigures),
                              ],
                              if (aboutBlocks.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _BlocksList(blocks: aboutBlocks),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Programmes : toujours afficher le titre et le bouton
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Programmes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              _showMiniSiteProgramsManager(context);
                            },
                            icon: const Icon(Icons.school_outlined, size: 16),
                            label: const Text('Gérer les programmes'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (programs.isNotEmpty) ...[
                        Card(
                          color: Colors.white,
                          elevation: 2,
                          shadowColor: const Color(0x0D000000),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (highlightedPrograms.isNotEmpty) ...[
                                  const Text(
                                    'Programmes phares',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _ProgramsGrid(
                                    programs: highlightedPrograms,
                                    courses: courses,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (otherPrograms.isNotEmpty)
                                  _ProgramsGrid(
                                    programs: otherPrograms,
                                    courses: courses,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        Card(
                          color: Colors.white,
                          elevation: 2,
                          shadowColor: const Color(0x0D000000),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: const Center(
                              child: Column(
                                children: [
                                  Icon(Icons.school_outlined, size: 48, color: Color(0xFF9CA3AF)),
                                  SizedBox(height: 8),
                                  Text(
                                    'Aucun programme pour le moment.\nCliquez sur « Gérer les programmes » pour en ajouter.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Événements : toujours afficher le titre et le bouton
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Événements',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              _showMiniSiteEventsManager(context);
                            },
                            icon: const Icon(Icons.event, size: 16),
                            label: const Text('Gérer les événements'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (events.isNotEmpty) ...[
                        Card(
                          color: Colors.white,
                          elevation: 2,
                          shadowColor: const Color(0x0D000000),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: _EventsList(events: events),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        Card(
                          color: Colors.white,
                          elevation: 2,
                          shadowColor: const Color(0x0D000000),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: const Center(
                              child: Column(
                                children: [
                                  Icon(Icons.event_outlined, size: 48, color: Color(0xFF9CA3AF)),
                                  SizedBox(height: 8),
                                  Text(
                                    'Aucun événement pour le moment.\nCliquez sur « Gérer les événements » pour en ajouter.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Actualités : toujours afficher le titre et le bouton
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Actualités',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              _showMiniSiteNewsManager(context);
                            },
                            icon: const Icon(Icons.article_outlined, size: 16),
                            label: const Text('Gérer les actualités'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (news.isNotEmpty) ...[
                        Card(
                          color: Colors.white,
                          elevation: 2,
                          shadowColor: const Color(0x0D000000),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: _NewsList(news: news),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        Card(
                          color: Colors.white,
                          elevation: 2,
                          shadowColor: const Color(0x0D000000),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: const Center(
                              child: Column(
                                children: [
                                  Icon(Icons.article_outlined, size: 48, color: Color(0xFF9CA3AF)),
                                  SizedBox(height: 8),
                                  Text(
                                    'Aucune actualité pour le moment.\nCliquez sur « Gérer les actualités » pour en ajouter.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (middleBanners.isNotEmpty) ...[
                        const Text(
                          'Informations clés',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          color: Colors.white,
                          elevation: 2,
                          shadowColor: const Color(0x0D000000),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child:
                                _BannerStrips(banners: middleBanners, media: media),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (otherBlocks.isNotEmpty) ...[
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Informations complémentaires',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                _showMiniSiteBlocksManager(context);
                              },
                              icon: const Icon(Icons.notes, size: 16),
                              label: const Text('Gérer les contenus'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Card(
                          color: Colors.white,
                          elevation: 2,
                          shadowColor: const Color(0x0D000000),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: _BlocksList(blocks: otherBlocks),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Équipe : toujours afficher le titre et le bouton
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Équipe',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              _showMiniSiteStaffManager(context);
                            },
                            icon: const Icon(Icons.group_outlined, size: 16),
                            label: const Text('Gérer l\'équipe'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (staff.isNotEmpty) ...[
                        Card(
                          color: Colors.white,
                          elevation: 2,
                          shadowColor: const Color(0x0D000000),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: _StaffList(staff: staff),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        Card(
                          color: Colors.white,
                          elevation: 2,
                          shadowColor: const Color(0x0D000000),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: const Center(
                              child: Column(
                                children: [
                                  Icon(Icons.group_outlined, size: 48, color: Color(0xFF9CA3AF)),
                                  SizedBox(height: 8),
                                  Text(
                                    'Aucun membre d\'équipe configuré.\nCliquez sur « Gérer l\'équipe » pour en ajouter.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (bottomBanners.isNotEmpty) ...[
                        const Text(
                          'À ne pas manquer',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child:
                                _BannerStrips(banners: bottomBanners, media: media),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (contactEmail.isNotEmpty ||
                          contactPhone.isNotEmpty ||
                          address.isNotEmpty ||
                          socialLinks.isNotEmpty) ...[
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Contact & informations',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                _showMiniSiteConfigManager(context);
                              },
                              icon: const Icon(Icons.settings, size: 16),
                              label: const Text('Configurer le contact'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Card(
                          color: Colors.white,
                          elevation: 2,
                          shadowColor: const Color(0x0D000000),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: _ContactSection(
                              email: contactEmail,
                              phone: contactPhone,
                              address: address,
                              socialLinks: socialLinks,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UniversitySiteConfigTab extends StatelessWidget {
  const _UniversitySiteConfigTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<UniversitySiteProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.university == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final university = provider.university;
        final config = provider.config;
        final banners = provider.banners;

        if (university == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Mini-site non encore configuré pour cette université.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final name = university['name']?.toString() ?? '';
        final hasTopCarousel = banners.any((b) =>
            (b['position']?.toString() ?? '') == 'top_carousel' && b['is_active'] != false);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Configuration du mini-site pour $name',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hero',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Titre : ${config?['hero_title'] ?? '-'}'),
                    Text('Sous-titre : ${config?['hero_subtitle'] ?? '-'}'),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _showEditConfigDialog(context, provider),
                        icon: const Icon(Icons.edit),
                        label: const Text('Modifier la configuration'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!hasTopCarousel)
              Card(
                color: Colors.orange.withOpacity(0.08),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Aucune bannière de type "top_carousel" n\'est encore configurée. '
                          'Pour un mini-site complet, ajoutez au moins une bannière "En vedette".',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Bannières / carrousels',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () =>
                      _showEditBannerDialog(context, provider, media: provider.media),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter une bannière'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (banners.isEmpty)
              const Text('Aucune bannière configurée pour le moment.')
            else
              ...banners.map((b) {
                final position = b['position']?.toString() ?? '';
                final title = b['title']?.toString() ?? '';
                final subtitle = b['subtitle']?.toString() ?? '';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Chip(label: Text(position)),
                          ],
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(subtitle),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () =>
                                  _showEditBannerDialog(context, provider,
                                      banner: b, media: provider.media),
                              icon: const Icon(Icons.edit),
                              label: const Text('Modifier'),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () async {
                                final id = b['id']?.toString();
                                if (id == null) return;
                                final ok = await provider.deleteBanner(id);
                                if (!context.mounted) return;
                                if (!ok) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        provider.error ??
                                            'Erreur lors de la suppression de la bannière.',
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Supprimer'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _UniversitySiteBlocksTab extends StatelessWidget {
  const _UniversitySiteBlocksTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<UniversitySiteProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.blocks.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final blocks = provider.blocks;

        if (blocks.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showEditBlockDialog(context, provider),
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter un bloc'),
                    ),
                    const SizedBox(width: 8),
                    if (provider.error != null)
                      Expanded(child: Text(provider.error!)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Aucun bloc éditorial configuré pour le moment.'),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showEditBlockDialog(context, provider),
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un bloc'),
                  ),
                  const SizedBox(width: 8),
                  if (provider.error != null)
                    Expanded(child: Text(provider.error!)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: blocks.length,
                itemBuilder: (context, index) {
                  final block = blocks[index];
                  final title = block['title']?.toString() ?? '';
                  final key = block['key']?.toString() ?? '';
                  final content = block['content']?.toString() ?? '';
                  final isActive = block['is_active'] != false;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title.isNotEmpty ? title : key,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(isActive ? 'Actif' : 'Inactif'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            content,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => _showEditBlockDialog(
                                  context,
                                  provider,
                                  block: block,
                                ),
                                icon: const Icon(Icons.edit),
                                label: const Text('Modifier'),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () async {
                                  final id = block['id']?.toString();
                                  if (id == null) return;
                                  final ok = await provider.deleteBlock(id);
                                  if (!context.mounted) return;
                                  if (!ok) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          provider.error ??
                                              'Erreur lors de la suppression du bloc.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Supprimer'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _UniversitySiteMediaTab extends StatelessWidget {
  const _UniversitySiteMediaTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<UniversitySiteProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.media.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final media = provider.media
            .where((m) => m['is_active'] != false)
            .toList(growable: false);

        if (media.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showEditMediaDialog(context, provider),
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter un média'),
                    ),
                    const SizedBox(width: 8),
                    if (provider.error != null)
                      Expanded(child: Text(provider.error!)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Aucun média configuré pour le moment.'),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showEditMediaDialog(context, provider),
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un média'),
                  ),
                  const SizedBox(width: 8),
                  if (provider.error != null)
                    Expanded(child: Text(provider.error!)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: media.length,
                itemBuilder: (context, index) {
                  final m = media[index];
                  final title = m['title']?.toString() ?? '';
                  final description = m['description']?.toString() ?? '';
                  final url = m['url']?.toString() ?? '';
                  final mediaType = m['media_type']?.toString() ?? '';
                  final isActive = m['is_active'] != false;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title.isNotEmpty ? title : 'Média',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Chip(label: Text(mediaType.isNotEmpty ? mediaType : 'Type')),
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(isActive ? 'Actif' : 'Inactif'),
                              ),
                            ],
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (url.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              url,
                              style: const TextStyle(fontSize: 12, color: Colors.blue),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => _showEditMediaDialog(
                                  context,
                                  provider,
                                  media: m,
                                ),
                                icon: const Icon(Icons.edit),
                                label: const Text('Modifier'),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () async {
                                  final id = m['id']?.toString();
                                  if (id == null) return;
                                  final ok = await provider.deleteMedia(id);
                                  if (!context.mounted) return;
                                  if (!ok) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          provider.error ??
                                              'Erreur lors de la suppression du média.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Supprimer'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _UniversitySiteProgramsTab extends StatelessWidget {
  const _UniversitySiteProgramsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<UniversityProgramsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.programs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null && provider.programs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(provider.error!),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: provider.loadPrograms,
                  child: const Text('Recharger les programmes'),
                ),
              ],
            ),
          );
        }

        final programs = provider.programs
            .where((p) => p['is_active'] != false)
            .toList(growable: false);
        final courses = provider.courses;

        if (programs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showEditProgramDialog(context, provider),
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter un programme'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await provider.loadPrograms();
                        await provider.loadCourses();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Recharger'),
                    ),
                    const SizedBox(width: 8),
                    if (provider.error != null)
                      Expanded(child: Text(provider.error!)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Aucun programme configuré pour le moment.'),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showEditProgramDialog(context, provider),
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un programme'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await provider.loadPrograms();
                      await provider.loadCourses();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Recharger'),
                  ),
                  const SizedBox(width: 8),
                  if (provider.error != null)
                    Expanded(child: Text(provider.error!)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: programs.length,
                itemBuilder: (context, index) {
                  final program = programs[index];
                  final title = program['title']?.toString() ?? '';
                  final degree = program['degree_level']?.toString() ?? '';
                  final mode = program['mode']?.toString() ?? '';
                  final isActive = program['is_active'] == true;
                  final highlighted = program['highlighted'] == true;
                  final programId = program['id']?.toString();
                  final programCourses = programId == null
                      ? <Map<String, dynamic>>[]
                      : courses
                          .where((c) => c['program_id']?.toString() == programId)
                          .toList(growable: false);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (degree.isNotEmpty) Chip(label: Text(degree)),
                              if (mode.isNotEmpty) Chip(label: Text(mode)),
                              Chip(
                                label: Text(isActive ? 'Actif' : 'Inactif'),
                              ),
                              if (highlighted)
                                const Chip(
                                  label: Text('En vedette'),
                                ),
                              if (programCourses.isNotEmpty)
                                Chip(
                                  label: Text(
                                    '${programCourses.length} cours',
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                onPressed: programId == null
                                    ? null
                                    : () {
                                        showModalBottomSheet<void>(
                                          context: context,
                                          isScrollControlled: true,
                                          builder: (context) {
                                            return _UniversityProgramCoursesSheet(
                                              programId: programId,
                                              programTitle: title,
                                            );
                                          },
                                        );
                                      },
                                icon: const Icon(Icons.menu_book_outlined),
                                label: const Text('Gérer les cours'),
                              ),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _showEditProgramDialog(
                                      context,
                                      provider,
                                      program: program,
                                    ),
                                    icon: const Icon(Icons.edit),
                                    label: const Text('Modifier le programme'),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: programId == null
                                        ? null
                                        : () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (dialogContext) {
                                                return AlertDialog(
                                                  title: const Text('Supprimer le programme ?'),
                                                  content: const Text(
                                                    'Le programme sera marqué comme inactif et ne sera plus visible sur le mini-site.',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.of(dialogContext).pop(false),
                                                      child: const Text('Annuler'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.of(dialogContext).pop(true),
                                                      child: const Text('Supprimer'),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                            if (confirm != true) return;

                                            final rawDuration = program['duration_months'];
                                            int? duration;
                                            if (rawDuration is int) {
                                              duration = rawDuration;
                                            } else if (rawDuration is num) {
                                              duration = rawDuration.toInt();
                                            } else if (rawDuration is String &&
                                                rawDuration.isNotEmpty) {
                                              duration = int.tryParse(rawDuration);
                                            }

                                            final rawFees = program['tuition_fees'];
                                            num? fees;
                                            if (rawFees is num) {
                                              fees = rawFees;
                                            } else if (rawFees is String &&
                                                rawFees.isNotEmpty) {
                                              fees = num.tryParse(rawFees);
                                            }

                                            final ok = await provider.upsertProgram(
                                              programId: programId,
                                              title: title,
                                              description:
                                                  program['description']?.toString(),
                                              degreeLevel:
                                                  degree.isNotEmpty ? degree : null,
                                              mode: mode.isNotEmpty ? mode : null,
                                              durationMonths: duration,
                                              tuitionFees: fees,
                                              highlighted: highlighted,
                                              isActive: false,
                                            );
                                            if (!context.mounted) return;
                                            if (!ok) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    provider.error ??
                                                        'Erreur lors de la suppression du programme.',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Supprimer'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

Future<void> _showMiniSiteConfigManager(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.85,
          child: const _UniversitySiteConfigTab(),
        ),
      );
    },
  );
}

Future<void> _showMiniSiteBlocksManager(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.85,
          child: const _UniversitySiteBlocksTab(),
        ),
      );
    },
  );
}

Future<void> _showMiniSiteMediaManager(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.85,
          child: const _UniversitySiteMediaTab(),
        ),
      );
    },
  );
}

Future<void> _showMiniSiteProgramsManager(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.85,
          child: const _UniversitySiteProgramsTab(),
        ),
      );
    },
  );
}

Future<void> _showMiniSiteEventsManager(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.85,
          child: const _UniversitySiteEventsTab(),
        ),
      );
    },
  );
}

Future<void> _showMiniSiteNewsManager(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.85,
          child: const _UniversitySiteNewsTab(),
        ),
      );
    },
  );
}

Future<void> _showMiniSiteStaffManager(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.85,
          child: const _UniversitySiteStaffTab(),
        ),
      );
    },
  );
}

Future<void> _showEditBlockDialog(
  BuildContext context,
  UniversitySiteProvider provider, {
  Map<String, dynamic>? block,
}) async {
  final keyController = TextEditingController(text: block?['key']?.toString() ?? '');
  final titleController = TextEditingController(text: block?['title']?.toString() ?? '');
  final contentController = TextEditingController(text: block?['content']?.toString() ?? '');

  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(block == null ? 'Ajouter un bloc' : 'Modifier le bloc'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: keyController,
                decoration: const InputDecoration(
                  labelText: 'Clé (about, admission, campus...)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Titre',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: contentController,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Contenu',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              final key = keyController.text.trim();
              final title = titleController.text.trim();
              final content = contentController.text.trim();

              if (key.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('La clé du bloc est obligatoire.'),
                  ),
                );
                return;
              }

              final ok = await provider.upsertBlock(
                blockId: block?['id']?.toString(),
                key: key,
                title: title.isNotEmpty ? title : null,
                content: content.isNotEmpty ? content : null,
              );
              if (!context.mounted) return;
              if (ok) {
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      provider.error ?? 'Erreur lors de la sauvegarde du bloc.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      );
    },
  );
}

Future<void> _showEditMediaDialog(
  BuildContext context,
  UniversitySiteProvider provider, {
  Map<String, dynamic>? media,
}) async {
  final rawType = media?['media_type']?.toString() ?? 'video';
  final lowerInitialType = rawType.toLowerCase();
  String initialType;
  if (lowerInitialType.contains('image')) {
    initialType = 'image';
  } else if (lowerInitialType.contains('video') ||
      lowerInitialType.contains('vidéo')) {
    initialType = 'video';
  } else if (lowerInitialType.contains('brochure')) {
    initialType = 'brochure';
  } else if (lowerInitialType.contains('pdf')) {
    initialType = 'pdf';
  } else if (lowerInitialType.contains('doc')) {
    initialType = 'doc';
  } else if (lowerInitialType.contains('autre')) {
    initialType = 'autre';
  } else {
    initialType = 'video';
  }
  final titleController =
      TextEditingController(text: media?['title']?.toString() ?? '');
  final descriptionController =
      TextEditingController(text: media?['description']?.toString() ?? '');
  final urlController =
      TextEditingController(text: media?['url']?.toString() ?? '');
  bool isActive = media?['is_active'] != false;

  await showDialog<void>(
    context: context,
    builder: (context) {
      Uint8List? pickedBytes;
      String? pickedFileName;
      String? pickedMimeType;
      final existingStoragePath = media?['storage_path']?.toString();
      String selectedType = initialType;
      bool isSavingLocal = false;

      return StatefulBuilder(
        builder: (context, setState) {
          final lowerType = selectedType.toLowerCase();
          final isFileMedia = lowerType == 'video' ||
              lowerType == 'image' ||
              lowerType == 'brochure' ||
              lowerType == 'pdf' ||
              lowerType == 'doc';

          return AlertDialog(
            title: Text(media == null ? 'Ajouter un média' : 'Modifier le média'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    items: const [
                      DropdownMenuItem(
                        value: 'video',
                        child: Text('Vidéo (fichier Supabase)'),
                      ),
                      DropdownMenuItem(
                        value: 'image',
                        child: Text('Image (fichier Supabase)'),
                      ),
                      DropdownMenuItem(
                        value: 'brochure',
                        child: Text('Brochure (PDF, fichier)'),
                      ),
                      DropdownMenuItem(
                        value: 'pdf',
                        child: Text('Document PDF (fichier)'),
                      ),
                      DropdownMenuItem(
                        value: 'doc',
                        child: Text('Document (Word, fichier)'),
                      ),
                      DropdownMenuItem(
                        value: 'autre',
                        child: Text('Autre (URL externe)'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        selectedType = value;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Type de média',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Titre',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                    ),
                  ),
                  if (!isFileMedia) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: urlController,
                      decoration: const InputDecoration(
                        labelText: 'URL (pour les médias non fichiers, optionnel)',
                        hintText: 'https://...',
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: isActive,
                        onChanged: (value) {
                          setState(() {
                            isActive = value ?? true;
                          });
                        },
                      ),
                      const Text('Média actif'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              allowMultiple: false,
                              withData: true,
                              type: FileType.custom,
                              allowedExtensions: const [
                                'mp4',
                                'mov',
                                'webm',
                                'jpg',
                                'jpeg',
                                'png',
                              ],
                            );
                            if (result == null || result.files.isEmpty) {
                              return;
                            }
                            final file = result.files.first;
                            final bytes = file.bytes;
                            if (bytes == null) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Impossible de lire le contenu du fichier sélectionné.',
                                  ),
                                ),
                              );
                              return;
                            }
                            setState(() {
                              pickedBytes = bytes;
                              pickedFileName = file.name;
                              pickedMimeType = file.extension;
                            });
                          },
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Choisir un fichier (image/vidéo)'),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pickedFileName != null
                              ? 'Fichier sélectionné : $pickedFileName'
                              : (existingStoragePath != null &&
                                      existingStoragePath.isNotEmpty
                                  ? 'Un fichier est déjà associé à ce média.'
                                  : 'Aucun fichier sélectionné.'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: isSavingLocal
                    ? null
                    : () async {
                        final type = selectedType;
                        final title = titleController.text.trim();
                        final description = descriptionController.text.trim();
                        if (title.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Le titre du média est obligatoire.'),
                            ),
                          );
                          return;
                        }
                        final lowerTypeSave = type.toLowerCase();
                        final isFileMediaSave = lowerTypeSave == 'video' ||
                            lowerTypeSave == 'image' ||
                            lowerTypeSave == 'brochure' ||
                            lowerTypeSave == 'pdf' ||
                            lowerTypeSave == 'doc';

                        String? url;
                        if (!isFileMediaSave) {
                          final urlText = urlController.text.trim();
                          url = urlText.isNotEmpty ? urlText : null;
                        }

                        if (type.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Le type de média est obligatoire.'),
                            ),
                          );
                          return;
                        }

                        String? storagePath = existingStoragePath;

                        setState(() {
                          isSavingLocal = true;
                        });

                        try {
                          if (pickedBytes != null && pickedFileName != null) {
                            final uploadedPath = await provider.uploadMediaFile(
                              bytes: pickedBytes!,
                              fileName: pickedFileName!,
                              mimeType: pickedMimeType,
                            );
                            if (!context.mounted) return;
                            if (uploadedPath == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    provider.error ??
                                        'Erreur lors de l\'upload du fichier média.',
                                  ),
                                ),
                              );
                              return;
                            }
                            storagePath = uploadedPath;
                          }

                          if (isFileMediaSave) {
                            final pathTrim = (storagePath ?? '').trim();
                            if (pathTrim.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Pour les vidéos, images, brochures et documents, un fichier doit être uploadé via Supabase Storage.',
                                  ),
                                ),
                              );
                              return;
                            }
                          }

                          if (url != null &&
                              pickedBytes == null &&
                              pickedFileName == null) {
                            storagePath = null;
                          }

                          final ok = await provider.upsertMedia(
                            mediaId: media?['id']?.toString(),
                            mediaType: type,
                            title: title.isNotEmpty ? title : null,
                            description:
                                description.isNotEmpty ? description : null,
                            url: url,
                            storagePath: storagePath,
                            thumbnailUrl: null,
                            isActive: isActive,
                          );
                          if (!context.mounted) return;
                          if (ok) {
                            Navigator.of(context).pop();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  provider.error ??
                                      'Erreur lors de la sauvegarde du média.',
                                ),
                              ),
                            );
                          }
                        } finally {
                          if (context.mounted) {
                            setState(() {
                              isSavingLocal = false;
                            });
                          }
                        }
                      },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      );
    },
  );
}

class _MediaStrip extends StatelessWidget {
  final List<Map<String, dynamic>> media;

  const _MediaStrip({required this.media});

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: media.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final m = media[index];
          final title = m['title']?.toString() ?? '';
          final description = m['description']?.toString() ?? '';
          final mediaType = m['media_type']?.toString() ?? '';

          return Container(
            width: 260,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF006D3C).withOpacity(0.06),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.play_circle_fill,
                        size: 18, color: Color(0xFF006D3C)),
                    const SizedBox(width: 6),
                    Text(
                      mediaType.isNotEmpty ? mediaType : 'Média',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF006D3C),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title.isNotEmpty ? title : 'Titre du média',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _KeyFiguresChips extends StatelessWidget {
  final Map<String, dynamic> keyFigures;

  const _KeyFiguresChips({required this.keyFigures});

  @override
  Widget build(BuildContext context) {
    if (keyFigures.isEmpty) {
      return const SizedBox.shrink();
    }

    final entries = keyFigures.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entries.map((e) {
        final label = e.key.toString();
        final value = e.value?.toString() ?? '';
        return Chip(
          label: Text('$value $label'),
        );
      }).toList(),
    );
  }
}

class _BlocksList extends StatelessWidget {
  final List<Map<String, dynamic>> blocks;

  const _BlocksList({required this.blocks});

  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) {
      return const Text('Aucun contenu pour l\'instant.');
    }

    return Column(
      children: blocks.map((block) {
        final title = block['title']?.toString() ?? '';
        final key = block['key']?.toString() ?? '';
        final content = block['content']?.toString() ?? '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title.isNotEmpty ? title : key,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (key.isNotEmpty)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: const Color(0xFFE5E7EB),
                      ),
                      child: Text(
                        key,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
              if (content.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ProgramsGrid extends StatelessWidget {
  final List<Map<String, dynamic>> programs;
  final List<Map<String, dynamic>> courses;

  const _ProgramsGrid({
    required this.programs,
    required this.courses,
  });

  @override
  Widget build(BuildContext context) {
    if (programs.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: programs.map((program) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: _ProgramPreviewCard(
            program: program,
            courses: courses,
          ),
        );
      }).toList(),
    );
  }
}

class _ProgramPreviewCard extends StatelessWidget {
  final Map<String, dynamic> program;
  final List<Map<String, dynamic>> courses;

  const _ProgramPreviewCard({
    required this.program,
    required this.courses,
  });

  @override
  Widget build(BuildContext context) {
    final title = program['title']?.toString() ?? '';
    final degree = program['degree_level']?.toString() ?? '';
    final mode = program['mode']?.toString() ?? '';
    final isActive = program['is_active'] == true;
    final highlighted = program['highlighted'] == true;
    final programId = program['id']?.toString();
    final programCourses = programId == null
        ? <Map<String, dynamic>>[]
        : courses
            .where((c) => c['program_id']?.toString() == programId)
            .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            if (degree.isNotEmpty) Chip(label: Text(degree)),
            if (mode.isNotEmpty) Chip(label: Text(mode)),
            Chip(label: Text(isActive ? 'Actif' : 'Inactif')),
            if (highlighted)
              const Chip(
                label: Text('En vedette'),
              ),
            if (programCourses.isNotEmpty)
              Chip(
                label: Text('${programCourses.length} cours'),
              ),
          ],
        ),
      ],
    );
  }
}

class _EventsList extends StatelessWidget {
  final List<Map<String, dynamic>> events;

  const _EventsList({required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Text('Aucun événement à venir.');
    }

    return Column(
      children: events.map((event) {
        final title = event['title']?.toString() ?? '';
        final location = event['location']?.toString() ?? '';
        final startDate = event['start_date']?.toString() ?? '';
        final endDate = event['end_date']?.toString() ?? '';
        final rawType = event['event_type']?.toString() ?? '';
        final type = rawType.trim();

        final dateParts = <String>[];
        if (startDate.isNotEmpty) dateParts.add(startDate);
        if (endDate.isNotEmpty && endDate != startDate) {
          dateParts.add(endDate);
        }

        Color? badgeColor;
        IconData badgeIcon = Icons.event_note;
        String badgeLabel = type;

        switch (type.toLowerCase()) {
          case 'webinar':
          case 'conférence':
          case 'conference':
            badgeColor = const Color(0xFF3275D0);
            badgeLabel = 'Webinar';
            badgeIcon = Icons.videocam_outlined;
            break;
          case 'jpo':
          case 'portes_ouvertes':
          case 'open_day':
            badgeColor = const Color(0xFF1B8F5A);
            badgeLabel = 'Portes ouvertes';
            badgeIcon = Icons.meeting_room_outlined;
            break;
          case 'atelier':
          case 'workshop':
            badgeColor = const Color(0xFFF6A623);
            badgeLabel = 'Atelier';
            badgeIcon = Icons.psychology_outlined;
            break;
          default:
            if (type.isNotEmpty) {
              badgeColor = const Color(0xFF6B7280);
              badgeLabel = type;
              badgeIcon = Icons.event_note;
            }
            break;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (badgeColor != null) ...[
                    const SizedBox(width: 8),
                    _MiniSiteBadge(
                      label: badgeLabel,
                      color: badgeColor,
                      icon: badgeIcon,
                    ),
                  ],
                ],
              ),
              if (dateParts.isNotEmpty || location.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  [
                    if (dateParts.isNotEmpty) dateParts.join(' – '),
                    if (location.isNotEmpty) location,
                  ].join(' • '),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _NewsList extends StatelessWidget {
  final List<Map<String, dynamic>> news;

  const _NewsList({required this.news});

  @override
  Widget build(BuildContext context) {
    if (news.isEmpty) {
      return const Text('Aucune actualité pour le moment.');
    }

    return Column(
      children: news.map((item) {
        final title = item['title']?.toString() ?? '';
        final summary = item['summary']?.toString() ?? '';
        final publishedAt = item['published_at']?.toString() ?? '';

        final isPublished = publishedAt.isNotEmpty;
        final Color statusColor =
            isPublished ? const Color(0xFF1B8F5A) : const Color(0xFFF59E0B);
        final IconData statusIcon =
            isPublished ? Icons.check_circle_outline : Icons.edit_outlined;
        final String statusLabel = isPublished ? 'Publié' : 'Brouillon';

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _MiniSiteBadge(
                    label: statusLabel,
                    color: statusColor,
                    icon: statusIcon,
                  ),
                ],
              ),
              if (publishedAt.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  publishedAt,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _MiniSiteBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool compact;

  const _MiniSiteBadge({
    required this.label,
    required this.color,
    required this.icon,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    final background = color.withOpacity(0.08);
    final borderColor = color.withOpacity(0.3);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: compact ? 12 : 14,
            color: color,
          ),
          SizedBox(width: compact ? 4 : 6),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerStrips extends StatelessWidget {
  final List<Map<String, dynamic>> banners;
  final List<Map<String, dynamic>> media;

  const _BannerStrips({
    required this.banners,
    required this.media,
  });

  @override
  Widget build(BuildContext context) {
    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: banners.map((banner) {
        final title = banner['title']?.toString() ?? '';
        final subtitle = banner['subtitle']?.toString() ?? '';
        final mediaId = banner['media_id']?.toString();
        final mediaItem = mediaId == null
            ? null
            : media.firstWhere(
                (m) => m['id']?.toString() == mediaId,
                orElse: () => <String, dynamic>{},
              );

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF006D3C).withOpacity(0.04),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (mediaItem != null && mediaItem.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.link, size: 16, color: Color(0xFF006D3C)),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StaffList extends StatelessWidget {
  final List<Map<String, dynamic>> staff;

  const _StaffList({required this.staff});

  @override
  Widget build(BuildContext context) {
    if (staff.isEmpty) {
      return const Text('Aucun membre d\'équipe configuré.');
    }

    return Column(
      children: staff.map((member) {
        final fullName = member['full_name']?.toString() ?? '';
        final role = member['role']?.toString() ?? '';
        final isActive = member['is_active'] != false;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 14,
                child: Icon(
                  Icons.person,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (role.isNotEmpty)
                      Text(
                        role,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(isActive ? 'Actif' : 'Inactif'),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ContactSection extends StatelessWidget {
  final String email;
  final String phone;
  final String address;
  final Map<String, dynamic> socialLinks;

  const _ContactSection({
    required this.email,
    required this.phone,
    required this.address,
    required this.socialLinks,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (address.isNotEmpty) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 16, color: Color(0xFF006D3C)),
              const SizedBox(width: 8),
              Expanded(child: Text(address)),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (email.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.mail_outline,
                  size: 16, color: Color(0xFF006D3C)),
              const SizedBox(width: 8),
              Text(email),
            ],
          ),
          const SizedBox(height: 4),
        ],
        if (phone.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.phone_outlined,
                  size: 16, color: Color(0xFF006D3C)),
              const SizedBox(width: 8),
              Text(phone),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (socialLinks.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: socialLinks.entries.map((entry) {
              final platform = entry.key.toString();
              return Chip(
                avatar: const Icon(
                  Icons.link,
                  size: 16,
                ),
                label: Text(platform),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

Future<void> _showEditProgramDialog(
  BuildContext context,
  UniversityProgramsProvider provider, {
  Map<String, dynamic>? program,
}) async {
  final titleController = TextEditingController(text: program?['title']?.toString() ?? '');
  final descriptionController =
      TextEditingController(text: program?['description']?.toString() ?? '');
  final degreeController =
      TextEditingController(text: program?['degree_level']?.toString() ?? '');
  final modeController = TextEditingController(text: program?['mode']?.toString() ?? '');
  final durationController = TextEditingController(
    text: program?['duration_months']?.toString() ?? '',
  );
  final feesController = TextEditingController(
    text: program?['tuition_fees']?.toString() ?? '',
  );
  bool highlighted = program?['highlighted'] == true;
  bool isActive = program?['is_active'] != false;

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(program == null ? 'Ajouter un programme' : 'Modifier le programme'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Titre du programme *',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: degreeController,
                    decoration: const InputDecoration(
                      labelText: 'Niveau (Licence, Master...)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: modeController,
                    decoration: const InputDecoration(
                      labelText: 'Mode (présentiel, en ligne...)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: durationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Durée (mois)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: feesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Frais de scolarité',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: highlighted,
                        onChanged: (value) {
                          setState(() {
                            highlighted = value ?? false;
                          });
                        },
                      ),
                      const Text('Mettre en vedette'),
                    ],
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: isActive,
                        onChanged: (value) {
                          setState(() {
                            isActive = value ?? true;
                          });
                        },
                      ),
                      const Text('Programme actif'),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  final description = descriptionController.text.trim();
                  final degree = degreeController.text.trim();
                  final mode = modeController.text.trim();
                  final durationText = durationController.text.trim();
                  final feesText = feesController.text.trim();

                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Le titre du programme est obligatoire.'),
                      ),
                    );
                    return;
                  }

                  final duration =
                      durationText.isEmpty ? null : int.tryParse(durationText);
                  final fees = feesText.isEmpty ? null : num.tryParse(feesText);

                  final ok = await provider.upsertProgram(
                    programId: program?['id']?.toString(),
                    title: title,
                    description: description.isNotEmpty ? description : null,
                    degreeLevel: degree.isNotEmpty ? degree : null,
                    mode: mode.isNotEmpty ? mode : null,
                    durationMonths: duration,
                    tuitionFees: fees,
                    highlighted: highlighted,
                    isActive: isActive,
                  );
                  if (!context.mounted) return;
                  if (ok) {
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          provider.error ??
                              'Erreur lors de la sauvegarde du programme.',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      );
    },
  );
}
