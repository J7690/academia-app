import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/student_profile_provider.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart';

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
            _initializedFromProfile = true;
          }

          final saving = provider.isLoading && provider.profile != null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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

                          final success = await provider.updateProfile(
                            fullName: fullName.isEmpty ? null : fullName,
                            phone: phone.isEmpty ? null : phone,
                            country: country.isEmpty ? null : country,
                            city: city.isEmpty ? null : city,
                            dateOfBirth: dobText.isEmpty ? null : dobText,
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
    );
  }
}
