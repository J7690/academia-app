import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../student_profile_screen.dart';
import '../../../providers/student_profile_provider.dart';
import '../../../providers/student_offers_provider.dart';
import '../../../providers/student_applications_provider.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';

class StudentHomeTab extends StatefulWidget {
  const StudentHomeTab({super.key});

  @override
  State<StudentHomeTab> createState() => _StudentHomeTabState();
}

class _StudentHomeTabState extends State<StudentHomeTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentOffersProvider>().loadHomeOffers();
      context.read<StudentProfileProvider>().loadProfile();
      context.read<StudentApplicationsProvider>().loadApplications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentOffersProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.homeOffers.isEmpty) {
          return const LoadingWidget(message: 'Chargement des offres de formation...');
        }

        if (provider.error != null) {
          return CustomErrorWidget(
            error: provider.error!,
            onRetry: () => provider.loadHomeOffers(),
          );
        }

        final offers = provider.homeOffers;

        if (offers.isEmpty) {
          return Column(
            children: [
              _ProfileHeader(),
              const Expanded(
                child: Center(
                  child: Text('Aucune offre disponible pour le moment.'),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            _ProfileHeader(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: offers.length,
                itemBuilder: (context, index) {
                  final offer = offers[index];
                  return _OfferCard(offer: offer);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<StudentProfileProvider, StudentApplicationsProvider>(
      builder: (context, profileProvider, appsProvider, child) {
        final profile = profileProvider.profile;
        final fullName = profile?['full_name']?.toString() ?? '';
        final avatarUrl = profile?['avatar_url']?.toString() ?? '';
        final country = profile?['country']?.toString() ?? '';
        final city = profile?['city']?.toString() ?? '';
        final initial = (fullName.isNotEmpty ? fullName[0] : '?').toUpperCase();
        final title = fullName.isNotEmpty
            ? 'Bonjour, $fullName'
            : 'Bienvenue sur Academia';

        final apps = appsProvider.applications;
        final appsCount = apps.length;
        final appsText = appsProvider.isLoading && appsCount == 0
            ? 'Candidatures : chargement...'
            : 'Candidatures : $appsCount';

        final locationText = (country.isNotEmpty || city.isNotEmpty)
            ? [city, country].where((e) => e.isNotEmpty).join(', ')
            : 'Localisation non renseignée';

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceVariant,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage:
                        avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl.isEmpty
                        ? Text(
                            initial,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Chip(
                              label: Text(locationText),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            Chip(
                              label: Text(appsText),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider.value(
                            value: context.read<StudentProfileProvider>(),
                            child: const StudentProfileScreen(),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Mon profil'),
                  ),
                  IconButton(
                    tooltip: 'Se déconnecter',
                    icon: const Icon(Icons.logout),
                    onPressed: () async {
                      final client = Supabase.instance.client;
                      await client.auth.signOut();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;

  const _OfferCard({required this.offer});

  @override
  Widget build(BuildContext context) {
    final programId = offer['program_id']?.toString();
    final title = offer['program_title']?.toString() ?? '';
    final university = offer['university_name']?.toString() ?? '';
    final city = offer['city']?.toString() ?? '';
    final country = offer['country']?.toString() ?? '';
    final degree = offer['degree_level']?.toString() ?? '';
    final mode = offer['mode']?.toString() ?? '';
    final highlighted = (offer['highlighted'] == true);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (highlighted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'En vedette',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              university,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              '$city, $country',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (degree.isNotEmpty)
                  Chip(
                    label: Text(degree),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                if (mode.isNotEmpty)
                  Chip(
                    label: Text(mode),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: programId == null
                    ? null
                    : () async {
                        final applicationsProvider =
                            context.read<StudentApplicationsProvider>();
                        final success = await applicationsProvider
                            .createApplication(programId: programId);
                        if (!context.mounted) return;
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Candidature créée avec succès.'),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                applicationsProvider.error ??
                                    'Erreur lors de la création de la candidature.',
                              ),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.send),
                label: const Text('Candidater'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
