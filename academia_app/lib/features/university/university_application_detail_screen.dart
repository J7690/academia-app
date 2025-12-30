import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/university_application_messages_provider.dart';
import '../../providers/university_application_detail_provider.dart';
import '../../providers/university_programs_provider.dart';
import '../../providers/university_applications_provider.dart';
import '../../providers/university_application_payments_provider.dart';

enum UniversityDetailTab {
  dossier,
  documents,
  messages,
  offers,
}

class UniversityApplicationDetailScreen extends StatelessWidget {
  final Map<String, dynamic> application;

  const UniversityApplicationDetailScreen({super.key, required this.application});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Candidature - Université'),
      ),
      body: UniversityApplicationDetailPanel(application: application),
    );
  }
}

class _NotificationDot extends StatelessWidget {
  const _NotificationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
    );
  }
}

class UniversityApplicationDetailPanel extends StatefulWidget {
  final Map<String, dynamic> application;
  final UniversityDetailTab? forcedTab;

  const UniversityApplicationDetailPanel({
    super.key,
    required this.application,
    this.forcedTab,
  });

  @override
  State<UniversityApplicationDetailPanel> createState() => _UniversityApplicationDetailPanelState();
}

class _UniversityApplicationDetailPanelState extends State<UniversityApplicationDetailPanel> {
  final TextEditingController _messageController = TextEditingController();
  String? _currentApplicationId;
  bool _hasUnreadMessages = false;
  bool _messagesLoaded = false;

  Future<void> _openWebsite(String? url) async {
    if (url == null || url.trim().isEmpty) return;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'ouvrir le site.")),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors de l'ouverture du site.")),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _hasUnreadMessages = widget.application['has_unread_for_university'] == true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadForCurrentApplication();
      context.read<UniversityProgramsProvider>().loadPrograms();
      final appId = widget.application['id']?.toString();
      if (appId != null && appId.isNotEmpty) {
        try {
          context
              .read<UniversityApplicationPaymentsProvider>()
              .loadPaymentsForApplication(appId);
        } catch (_) {}
      }
    });
  }

  @override
  void didUpdateWidget(covariant UniversityApplicationDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.application['id'] != widget.application['id']) {
      _hasUnreadMessages = widget.application['has_unread_for_university'] == true;
      _messagesLoaded = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadForCurrentApplication();
        final appId = widget.application['id']?.toString();
        if (appId != null && appId.isNotEmpty) {
          try {
            context
                .read<UniversityApplicationPaymentsProvider>()
                .loadPaymentsForApplication(appId);
          } catch (_) {}
        }
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final forced = widget.forcedTab;

    if (forced != null) {
      switch (forced) {
        case UniversityDetailTab.dossier:
          return _buildDossierTab(context);
        case UniversityDetailTab.documents:
          return _buildDocumentsTab(context);
        case UniversityDetailTab.messages:
          return _buildMessagesTab(context);
        case UniversityDetailTab.offers:
          return _buildOffersTab(context);
      }
    }

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          TabBar(
            onTap: _handleTabTap,
            tabs: [
              const Tab(text: 'Synthèse'),
              const Tab(text: 'Documents'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Messages'),
                    if (_hasUnreadMessages) ...[
                      const SizedBox(width: 4),
                      const _NotificationDot(),
                    ],
                  ],
                ),
              ),
              const Tab(text: 'Programmes & mini-site'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                _buildDossierTab(context),
                _buildDocumentsTab(context),
                _buildMessagesTab(context),
                _buildOffersTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _loadForCurrentApplication() {
    final appId = widget.application['id']?.toString();
    if (appId == null || appId.isEmpty) {
      _currentApplicationId = null;
      return;
    }
    if (_currentApplicationId == appId) {
      return;
    }
    _currentApplicationId = appId;
    context.read<UniversityApplicationDetailProvider>().loadDetails(appId);
  }

  void _handleTabTap(int index) {
    // Index 2 = onglet "Messages"
    if (index != 2) {
      return;
    }
    final appId = widget.application['id']?.toString();
    if (appId == null || appId.isEmpty) {
      return;
    }
    if (!_messagesLoaded) {
      context.read<UniversityApplicationMessagesProvider>().loadMessages(appId);
      _messagesLoaded = true;
    }
    if (_hasUnreadMessages) {
      setState(() {
        _hasUnreadMessages = false;
      });
    }
    try {
      context.read<UniversityApplicationsProvider>().loadApplications();
    } catch (_) {}
  }

  Widget _buildDossierTab(BuildContext context) {
    final baseApp = widget.application;
    return Consumer<UniversityApplicationDetailProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.application == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null && provider.application == null) {
          return Center(child: Text(provider.error!));
        }

        final app = provider.application ?? baseApp;
        final appId = app['id']?.toString();
        final studentProfile = provider.studentProfile;
        final dossierStatus = provider.studentDossierStatus;
        final universityInfo = provider.universityInfo;
        final studentName = (app['student_full_name'] ?? studentProfile?['full_name'])?.toString() ?? '';
        final programTitle = app['program_title']?.toString() ?? provider.programInfo?['title']?.toString() ?? '';
        final status = app['status']?.toString() ?? '';
        final requestedDegree =
            (app['requested_degree_level']?.toString() ?? '').trim();
        final requestedMode =
            (app['requested_study_mode']?.toString() ?? '').trim();
        final requestedSchedule =
            (app['requested_schedule']?.toString() ?? '').trim();
        final discountRequested = app['discount_requested'] == true;
        final discountDetails =
            (app['discount_details']?.toString() ?? '').trim();
        final studentComment =
            (app['student_comment']?.toString() ?? '').trim();
        final hasPreferencesSection =
            requestedDegree.isNotEmpty ||
            requestedMode.isNotEmpty ||
            requestedSchedule.isNotEmpty ||
            discountRequested ||
            studentComment.isNotEmpty;

        final hasApplication = appId != null && appId.isNotEmpty;

        if (!hasApplication) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Sélectionnez une candidature dans la colonne de gauche pour voir le dossier détaillé.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(programTitle, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Étudiant : $studentName'),
              const SizedBox(height: 4),
              Text('Statut : $status'),
              const SizedBox(height: 8),
              _buildStatusActions(context, provider, appId, status),
              const SizedBox(height: 16),
              if (hasPreferencesSection) ...[
                Text('Préférences de candidature',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (requestedDegree.isNotEmpty)
                          Text('Niveau souhaité : $requestedDegree'),
                        if (requestedMode.isNotEmpty)
                          Text('Mode souhaité : $requestedMode'),
                        if (requestedSchedule.isNotEmpty)
                          Text('Horaires souhaités : $requestedSchedule'),
                        if (discountRequested) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Demande de réduction / échelonnement des frais',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (discountDetails.isNotEmpty)
                            Text(discountDetails),
                        ],
                        if (studentComment.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Commentaire de l\'étudiant',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(studentComment),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (universityInfo != null &&
                  (universityInfo['website_url']?.toString().trim().isNotEmpty ?? false))
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: () => _openWebsite(universityInfo['website_url']?.toString()),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text("Voir le site de l'université"),
                  ),
                ),
              const SizedBox(height: 16),
              if (studentProfile != null) ...[
                Text('Profil académique', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nom complet : ${studentProfile['full_name'] ?? ''}'),
                        if (studentProfile['date_of_birth'] != null)
                          Text('Date de naissance : ${studentProfile['date_of_birth']}'),
                        if (studentProfile['country'] != null || studentProfile['city'] != null)
                          Text('Localisation : ${studentProfile['city'] ?? ''} ${studentProfile['country'] ?? ''}'),
                        const SizedBox(height: 8),
                        Text('Parcours scolaire :'),
                        Text('- BEPC : ${studentProfile['bepc_year'] ?? ''} ${studentProfile['bepc_institution'] ?? ''} (${studentProfile['bepc_country'] ?? ''}) ${studentProfile['bepc_mention'] ?? ''}'),
                        Text('- BAC : ${studentProfile['bac_year'] ?? ''} ${studentProfile['bac_series'] ?? ''} ${studentProfile['bac_institution'] ?? ''} (${studentProfile['bac_country'] ?? ''}) ${studentProfile['bac_mention'] ?? ''}'),
                        const SizedBox(height: 8),
                        if (studentProfile['study_project_text'] != null &&
                            (studentProfile['study_project_text'] as String).isNotEmpty)
                          Text('Projet d\'études :\n${studentProfile['study_project_text']}'),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (dossierStatus != null) ...[
                Text('Complétude du dossier', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (dossierStatus['is_complete'] == true)
                              ? 'Dossier complet.'
                              : 'Dossier incomplet.',
                          style: TextStyle(
                            color: dossierStatus['is_complete'] == true
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (dossierStatus['missing_fields'] is List &&
                            (dossierStatus['missing_fields'] as List).isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Champs manquants :'),
                              const SizedBox(height: 4),
                              ...(dossierStatus['missing_fields'] as List)
                                  .map((f) => Text('- $f')),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDocumentsTab(BuildContext context) {
    return Consumer<UniversityApplicationDetailProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.applicationFiles.isEmpty && provider.dossierDocuments.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null && provider.application == null) {
          return Center(child: Text(provider.error!));
        }

        final appFiles = provider.applicationFiles;
        final dossierDocs = provider.dossierDocuments;

        if (appFiles.isEmpty && dossierDocs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Aucun document disponible pour cette candidature.'),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (appFiles.isNotEmpty) ...[
              Text('Documents de candidature', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...appFiles.map((f) => ListTile(
                    leading: const Icon(Icons.attach_file),
                    title: Text(f['file_type']?.toString() ?? ''),
                    subtitle: Text(f['storage_path']?.toString() ?? ''),
                  )),
              const SizedBox(height: 16),
            ],
            if (dossierDocs.isNotEmpty) ...[
              Text('Documents du dossier étudiant', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...dossierDocs.map((d) => ListTile(
                    leading: const Icon(Icons.description),
                    title: Text(d['document_type']?.toString() ?? ''),
                    subtitle: Text(d['storage_path']?.toString() ?? ''),
                    trailing: Text(d['status']?.toString() ?? ''),
                  )),
            ],
          ],
        );
      },
    );
  }

  Widget _buildMessagesTab(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Consumer<UniversityApplicationMessagesProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading && provider.messages.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (provider.error != null) {
                return Center(child: Text('Erreur : ${provider.error}'));
              }

              final messages = provider.messages;
              if (messages.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Aucun message pour le moment. Utilisez le champ ci-dessous pour répondre à l\'administration.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final senderRole = msg['sender_role']?.toString() ?? '';
                  final content = msg['content']?.toString() ?? '';
                  final createdAtMsg = msg['created_at']?.toString() ?? '';

                  final isUniversity = senderRole == 'university';
                  final alignment = isUniversity ? Alignment.centerRight : Alignment.centerLeft;
                  final color = isUniversity
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                      : Theme.of(context).colorScheme.surfaceVariant;
                  final label = isUniversity ? 'Vous (Université)' : 'Administration';

                  return Align(
                    alignment: alignment,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(content),
                          if (createdAtMsg.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              createdAtMsg,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Écrire un message à l\'administration...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () async {
                  final appId = widget.application['id']?.toString();
                  if (appId == null || appId.isEmpty) return;
                  final text = _messageController.text.trim();
                  if (text.isEmpty) return;

                  final provider = context.read<UniversityApplicationMessagesProvider>();
                  final ok = await provider.sendToAdmin(
                    applicationId: appId,
                    content: text,
                  );
                  if (!mounted) return;
                  if (ok) {
                    _messageController.clear();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          provider.error ?? 'Erreur lors de l\'envoi du message.',
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOffersTab(BuildContext context) {
    return Consumer2<UniversityProgramsProvider, UniversityApplicationDetailProvider>(
      builder: (context, programsProvider, detailProvider, child) {
        if (programsProvider.isLoading && programsProvider.programs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (programsProvider.error != null && programsProvider.programs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(programsProvider.error!),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: programsProvider.loadPrograms,
                  child: const Text('Recharger les programmes'),
                ),
              ],
            ),
          );
        }

        final programs = programsProvider.programs;
        final universityInfo = detailProvider.universityInfo;
        final websiteUrl = universityInfo?['website_url']?.toString();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (websiteUrl != null && websiteUrl.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: () => _openWebsite(websiteUrl),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text("Ouvrir le mini-site de l'université"),
                ),
              ),
            if (programs.isEmpty)
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Aucun programme configuré pour cette université pour le moment.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
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
                                  backgroundColor:
                                      isActive ? Colors.green.shade50 : Colors.red.shade50,
                                ),
                                if (highlighted)
                                  Chip(
                                    label: const Text('En vedette'),
                                    backgroundColor: Colors.orange.shade50,
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

  Widget _buildStatusActions(
    BuildContext context,
    UniversityApplicationDetailProvider provider,
    String? applicationId,
    String currentStatus,
  ) {
    final isLoading = provider.isLoading;

    if (applicationId == null || applicationId.isEmpty) {
      return const SizedBox.shrink();
    }

    Future<void> changeStatus(String target) async {
      final ok = await provider.updateStatus(
        applicationId: applicationId,
        newStatus: target,
      );
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.error ?? "Erreur lors de la mise à jour du statut.",
            ),
          ),
        );
        return;
      }
      await context.read<UniversityApplicationsProvider>().loadApplications();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        OutlinedButton.icon(
          onPressed:
              isLoading || currentStatus == 'under_review' ? null : () => changeStatus('under_review'),
          icon: const Icon(Icons.visibility),
          label: const Text('Marquer en étude'),
        ),
        OutlinedButton.icon(
          onPressed:
              isLoading || currentStatus == 'accepted' ? null : () => changeStatus('accepted'),
          icon: const Icon(Icons.check),
          label: const Text('Accepter'),
        ),
        OutlinedButton.icon(
          onPressed:
              isLoading || currentStatus == 'rejected' ? null : () => changeStatus('rejected'),
          icon: const Icon(Icons.close),
          label: const Text('Refuser'),
        ),
        OutlinedButton.icon(
          onPressed:
              isLoading || currentStatus == 'canceled' ? null : () => changeStatus('canceled'),
          icon: const Icon(Icons.cancel),
          label: const Text('Annuler'),
        ),
      ],
    );
  }
}
