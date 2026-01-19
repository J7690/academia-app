import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_td_teachers_provider.dart';
import '../../providers/admin_user_invitations_provider.dart';

class AdminTdTeachersScreen extends StatefulWidget {
  const AdminTdTeachersScreen({super.key});

  @override
  State<AdminTdTeachersScreen> createState() => _AdminTdTeachersScreenState();
}

class _AdminTdTeachersScreenState extends State<AdminTdTeachersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AdminTdTeachersProvider>().loadTeachers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminTdTeachersProvider>();
    final teachers = provider.teachers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TD - Enseignants'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Créer un enseignant TD',
            onPressed: () => _promptCreateTeacher(context, provider),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: teachers.isEmpty
              ? const Center(child: Text('Aucun enseignant TD.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: teachers.length,
                  separatorBuilder: (_, __) => const Divider(height: 16),
                  itemBuilder: (context, index) {
                    final t = teachers[index];
                    final id = t['id']?.toString() ?? '';
                    final fullName = t['full_name']?.toString() ?? '';
                    final discipline = t['discipline']?.toString() ?? '';
                    final zone = t['zone']?.toString() ?? '';
                    final availability = t['availability']?.toString() ?? '';
                    final status = t['status']?.toString() ?? '';

                    Color statusColor;
                    if (status == 'active') {
                      statusColor = const Color(0xFF66BB6A);
                    } else if (status == 'suspended') {
                      statusColor = const Color(0xFFFFB74D);
                    } else if (status == 'removed') {
                      statusColor = const Color(0xFFE57373);
                    } else {
                      statusColor = Colors.grey;
                    }

                    return ListTile(
                      title: Text(fullName),
                      subtitle: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (discipline.isNotEmpty) Text('Discipline: $discipline'),
                          if (zone.isNotEmpty) Text('Zone: $zone'),
                          if (availability.isNotEmpty)
                            Text('Dispo: $availability'),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Statut: $status',
                        onSelected: (value) async {
                          final ok = await provider.updateTeacherStatus(
                            teacherId: id,
                            status: value,
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? 'Statut mis à jour.'
                                    : provider.error ?? 'Erreur lors de la mise à jour.',
                              ),
                            ),
                          );
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'active', child: Text('Actif')),
                          PopupMenuItem(value: 'suspended', child: Text('Suspendu')),
                          PopupMenuItem(value: 'removed', child: Text('Retiré')),
                        ],
                        child: Chip(
                          label: Text(status.isEmpty ? 'Inconnu' : status),
                          backgroundColor: statusColor.withOpacity(0.12),
                          labelStyle: TextStyle(color: statusColor),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _promptCreateTeacher(
    BuildContext context,
    AdminTdTeachersProvider provider,
  ) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final nameController = TextEditingController();
    final disciplineController = TextEditingController();
    final zoneController = TextEditingController();
    final availabilityController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nouvel enseignant TD'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Crée un nouveau compte enseignant TD (rôle "instructor") et sa fiche TD associée.\n'
                  'Un email de réinitialisation de mot de passe sera envoyé à l\'enseignant.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email utilisateur',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe provisoire',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: disciplineController,
                  decoration: const InputDecoration(
                    labelText: 'Discipline',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: zoneController,
                  decoration: const InputDecoration(
                    labelText: 'Zone géographique',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: availabilityController,
                  decoration: const InputDecoration(
                    labelText: 'Disponibilité',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Créer'),
            ),
          ],
        );
      },
    );

    if (result != true) return;
    final email = emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email utilisateur requis pour créer un enseignant TD.'),
        ),
      );
      return;
    }

    final password = passwordController.text;
    if (password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mot de passe provisoire requis pour créer un enseignant TD.'),
        ),
      );
      return;
    }

    final invitationsProvider = context.read<AdminUserInvitationsProvider>();

    final fullNameInput = nameController.text.trim();
    final teacherAccount = await invitationsProvider.createTeacherAccountDirect(
      email: email,
      password: password,
      fullName: fullNameInput.isEmpty ? null : fullNameInput,
    );

    if (!mounted) return;

    if (teacherAccount == null || teacherAccount['success'] != true) {
      final error = invitationsProvider.error ??
          'Erreur lors de la création du compte enseignant.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    final userId = teacherAccount['user_id']?.toString() ?? '';
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Compte enseignant créé, mais identifiant utilisateur manquant.',
          ),
        ),
      );
      return;
    }

    String fullName = fullNameInput;
    if (fullName.isEmpty) {
      fullName = email;
    }

    final ok = await provider.createTeacher(
      userId: userId,
      fullName: fullName,
      discipline: disciplineController.text.trim(),
      zone: zoneController.text.trim(),
      availability: availabilityController.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Enseignant TD créé.' : provider.error ?? 'Erreur lors de la création.',
        ),
      ),
    );
  }
}
