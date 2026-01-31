import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/student_profile_provider.dart';
import '../../providers/student_dossier_documents_provider.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/bobodo_state.dart';
import '../../widgets/bobodo_view.dart';
import 'student_dossier_documents_screen.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _bepcYearController = TextEditingController();
  final TextEditingController _bepcInstitutionController = TextEditingController();
  final TextEditingController _bepcCountryController = TextEditingController();
  final TextEditingController _bepcMentionController = TextEditingController();
  final TextEditingController _bacYearController = TextEditingController();
  final TextEditingController _bacSeriesController = TextEditingController();
  final TextEditingController _bacMentionController = TextEditingController();
  final TextEditingController _bacInstitutionController = TextEditingController();
  final TextEditingController _bacCountryController = TextEditingController();
  final TextEditingController _studyProjectController = TextEditingController();

  bool _initializedFromProfile = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentProfileProvider>().loadProfile();
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _dobController.dispose();
    _bepcYearController.dispose();
    _bepcInstitutionController.dispose();
    _bepcCountryController.dispose();
    _bepcMentionController.dispose();
    _bacYearController.dispose();
    _bacSeriesController.dispose();
    _bacMentionController.dispose();
    _bacInstitutionController.dispose();
    _bacCountryController.dispose();
    _studyProjectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil'),
      ),
      body: Consumer<StudentProfileProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.profile == null) {
            return const LoadingWidget(message: 'Chargement du profil...');
          }

          if (provider.error != null && provider.profile == null) {
            return CustomErrorWidget(
              error: provider.error!,
              onRetry: () => provider.loadProfile(),
            );
          }

          final profile = provider.profile ?? <String, dynamic>{};

          if (!_initializedFromProfile && profile.isNotEmpty) {
            _fullNameController.text = profile['full_name']?.toString() ?? '';
            _phoneController.text = profile['phone']?.toString() ?? '';
            _countryController.text = profile['country']?.toString() ?? '';
            _cityController.text = profile['city']?.toString() ?? '';
            final dobRaw = profile['date_of_birth'];
            if (dobRaw != null && dobRaw.toString().isNotEmpty) {
              final s = dobRaw.toString();
              _dobController.text = s.length >= 10 ? s.substring(0, 10) : s;
            }
            _bepcYearController.text =
                profile['bepc_year']?.toString() ?? '';
            _bepcInstitutionController.text =
                profile['bepc_institution']?.toString() ?? '';
            _bepcCountryController.text =
                profile['bepc_country']?.toString() ?? '';
            _bepcMentionController.text =
                profile['bepc_mention']?.toString() ?? '';
            _bacYearController.text =
                profile['bac_year']?.toString() ?? '';
            _bacSeriesController.text =
                profile['bac_series']?.toString() ?? '';
            _bacMentionController.text =
                profile['bac_mention']?.toString() ?? '';
            _bacInstitutionController.text =
                profile['bac_institution']?.toString() ?? '';
            _bacCountryController.text =
                profile['bac_country']?.toString() ?? '';
            _studyProjectController.text =
                profile['study_project_text']?.toString() ?? '';
            _initializedFromProfile = true;
          }

          final saving = provider.isLoading && provider.profile != null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Padding(
                      padding: EdgeInsets.only(right: 12.0),
                      child: BobodoView(
                        state: BobodoState.thinking,
                        size: 56,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Remplis tranquillement ton profil : plus il est complet, plus ton dossier est clair pour les universités. Je suis là pour t’aider à décrocher ton badge "Dossier prêt".',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _countryController,
                  decoration: const InputDecoration(
                    labelText: 'Pays',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: 'Ville',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _dobController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Date de naissance (YYYY-MM-DD)',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: () async {
                    final now = DateTime.now();
                    DateTime initialDate = DateTime(now.year - 18, now.month, now.day);
                    try {
                      if (_dobController.text.isNotEmpty) {
                        final parts = _dobController.text.split('-');
                        if (parts.length == 3) {
                          final year = int.parse(parts[0]);
                          final month = int.parse(parts[1]);
                          final day = int.parse(parts[2]);
                          initialDate = DateTime(year, month, day);
                        }
                      }
                    } catch (_) {}

                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initialDate,
                      firstDate: DateTime(1900),
                      lastDate: now,
                    );

                    if (picked != null) {
                      final y = picked.year.toString().padLeft(4, '0');
                      final m = picked.month.toString().padLeft(2, '0');
                      final d = picked.day.toString().padLeft(2, '0');
                      _dobController.text = '$y-$m-$d';
                    }
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Parcours scolaire',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _bepcYearController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Année du BEPC / Brevet',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bepcInstitutionController,
                  decoration: const InputDecoration(
                    labelText: 'Établissement (BEPC)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bepcCountryController,
                  decoration: const InputDecoration(
                    labelText: 'Pays (BEPC)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bepcMentionController,
                  decoration: const InputDecoration(
                    labelText: 'Mention (BEPC)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _bacYearController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Année du Baccalauréat',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bacSeriesController,
                  decoration: const InputDecoration(
                    labelText: 'Série du Baccalauréat',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bacMentionController,
                  decoration: const InputDecoration(
                    labelText: 'Mention du Baccalauréat',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bacInstitutionController,
                  decoration: const InputDecoration(
                    labelText: 'Établissement (Bac)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bacCountryController,
                  decoration: const InputDecoration(
                    labelText: 'Pays (Bac)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Projet d\'études',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _studyProjectController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Décrivez brièvement votre projet d\'études',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider.value(
                            value: context.read<StudentDossierDocumentsProvider>(),
                            child: const StudentDossierDocumentsScreen(),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.folder_shared_outlined),
                    label: const Text('Gérer mes documents de dossier'),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          final provider = context.read<StudentProfileProvider>();
                          final fullName = _fullNameController.text.trim();
                          final phone = _phoneController.text.trim();
                          final country = _countryController.text.trim();
                          final city = _cityController.text.trim();
                          final dobText = _dobController.text.trim();
                          final bepcYearText = _bepcYearController.text.trim();
                          final bepcInstitution =
                              _bepcInstitutionController.text.trim();
                          final bepcCountry =
                              _bepcCountryController.text.trim();
                          final bepcMention =
                              _bepcMentionController.text.trim();
                          final bacYearText = _bacYearController.text.trim();
                          final bacSeries = _bacSeriesController.text.trim();
                          final bacMention = _bacMentionController.text.trim();
                          final bacInstitution =
                              _bacInstitutionController.text.trim();
                          final bacCountry =
                              _bacCountryController.text.trim();
                          final studyProject =
                              _studyProjectController.text.trim();

                          final success = await provider.updateProfile(
                            fullName: fullName.isEmpty ? null : fullName,
                            phone: phone.isEmpty ? null : phone,
                            country: country.isEmpty ? null : country,
                            city: city.isEmpty ? null : city,
                            dateOfBirth: dobText.isEmpty ? null : dobText,
                            bepcYear: bepcYearText.isEmpty
                                ? null
                                : int.tryParse(bepcYearText),
                            bepcInstitution: bepcInstitution.isEmpty
                                ? null
                                : bepcInstitution,
                            bepcCountry:
                                bepcCountry.isEmpty ? null : bepcCountry,
                            bepcMention:
                                bepcMention.isEmpty ? null : bepcMention,
                            bacYear: bacYearText.isEmpty
                                ? null
                                : int.tryParse(bacYearText),
                            bacSeries:
                                bacSeries.isEmpty ? null : bacSeries,
                            bacMention:
                                bacMention.isEmpty ? null : bacMention,
                            bacInstitution: bacInstitution.isEmpty
                                ? null
                                : bacInstitution,
                            bacCountry:
                                bacCountry.isEmpty ? null : bacCountry,
                            studyProjectText: studyProject.isEmpty
                                ? null
                                : studyProject,
                          );

                          if (!mounted) return;

                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Profil mis à jour.')),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  provider.error ?? 'Erreur lors de la mise à jour du profil.',
                                ),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.save),
                  label: saving
                      ? const Text('Enregistrement...')
                      : const Text('Enregistrer'),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1EA75C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Retour'),
            ),
          ),
        ),
      ),
    );
  }
}
