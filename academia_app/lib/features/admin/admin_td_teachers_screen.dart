import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_td_teachers_provider.dart';

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
}
