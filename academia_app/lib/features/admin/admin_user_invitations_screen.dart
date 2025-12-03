import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_user_invitations_provider.dart';
import '../../providers/admin_universities_provider.dart';

class AdminUserInvitationsScreen extends StatefulWidget {
  const AdminUserInvitationsScreen({super.key});

  @override
  State<AdminUserInvitationsScreen> createState() => _AdminUserInvitationsScreenState();
}

class _AdminUserInvitationsScreenState extends State<AdminUserInvitationsScreen> {
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedRole = 'instructor';
  String? _selectedUniversityId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminUserInvitationsProvider>().loadInvitations();
      context.read<AdminUniversitiesProvider>().loadUniversities();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _fullNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _createInvitation(BuildContext context) async {
    final email = _emailController.text.trim();
    final fullName = _fullNameController.text.trim();
    final notes = _notesController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez renseigner un email.')),
      );
      return;
    }

    if (_selectedRole == 'university' && _selectedUniversityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une université.')),
      );
      return;
    }

    final provider = context.read<AdminUserInvitationsProvider>();
    final response = await provider.createInvitation(
      email: email,
      role: _selectedRole,
      universityId: _selectedRole == 'university' ? _selectedUniversityId : null,
      fullName: fullName.isEmpty ? null : fullName,
      notes: notes.isEmpty ? null : notes,
      expiresAt: null,
    );

    if (!mounted) return;

    if (response == null) {
      final error = provider.error ?? 'Erreur lors de la création de l\'invitation.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    _emailController.clear();
    _fullNameController.clear();
    _notesController.clear();

    final token = response['token']?.toString();
    if (token != null && token.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: token));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation créée et code copié dans le presse-papiers.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation créée.')),
      );
    }
  }

  String? _universityNameForId(
    List<Map<String, dynamic>> universities,
    String? id,
  ) {
    if (id == null) return null;
    for (final u in universities) {
      if (u['id']?.toString() == id) {
        return u['name']?.toString() ?? u['short_name']?.toString();
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        title: const Text('Invitations utilisateurs - Admin'),
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
      ),
      body: Consumer2<AdminUserInvitationsProvider, AdminUniversitiesProvider>(
        builder: (context, invitationsProvider, universitiesProvider, child) {
          final universities = universitiesProvider.universities;
          final isLoading = invitationsProvider.isLoading;
          final isSaving = invitationsProvider.isSaving;
          final invitations = invitationsProvider.invitations;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Créer une nouvelle invitation',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email de l\'utilisateur',
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _fullNameController,
                          decoration: const InputDecoration(
                            labelText: 'Nom complet (optionnel)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'Rôle',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'instructor',
                              child: Text('Formateur / CI'),
                            ),
                            DropdownMenuItem(
                              value: 'university',
                              child: Text('Université'),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('Admin'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedRole = value;
                              if (_selectedRole != 'university') {
                                _selectedUniversityId = null;
                              }
                            });
                          },
                        ),
                        if (_selectedRole == 'university') ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _selectedUniversityId,
                            decoration: const InputDecoration(
                              labelText: 'Université liée',
                            ),
                            items: universities
                                .map(
                                  (u) => DropdownMenuItem<String>(
                                    value: u['id']?.toString(),
                                    child: Text(
                                      u['name']?.toString() ??
                                          u['short_name']?.toString() ??
                                              'Université',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedUniversityId = value;
                              });
                            },
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Notes internes (optionnel)',
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () => _createInvitation(context),
                            child: isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Créer l\'invitation'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: isLoading && invitations.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : invitations.isEmpty
                        ? const Center(
                            child:
                                Text('Aucune invitation créée pour le moment.'),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: invitations.length,
                            itemBuilder: (context, index) {
                              final inv = invitations[index];
                              final email = inv['email']?.toString() ?? '';
                              final role = inv['role']?.toString() ?? '';
                              final status = inv['status']?.toString() ?? '';
                              final token = inv['token']?.toString() ?? '';
                              final universityId =
                                  inv['university_id']?.toString();
                              final universityName = _universityNameForId(
                                universities,
                                universityId,
                              );
                              final createdAt =
                                  inv['created_at']?.toString() ?? '';
                              final usedAt = inv['used_at']?.toString();

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                color: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  email,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Rôle : $role',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                if (universityName != null &&
                                                    universityName.isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                      top: 2,
                                                    ),
                                                    child: Text(
                                                      universityName,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  ),
                                                if (createdAt.isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                      top: 2,
                                                    ),
                                                    child: Text(
                                                      'Créée le : $createdAt',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  ),
                                                if (usedAt != null &&
                                                    usedAt.isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                      top: 2,
                                                    ),
                                                    child: Text(
                                                      'Utilisée le : $usedAt',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  ),
                                                if (token.isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                      top: 4,
                                                    ),
                                                    child: Text(
                                                      'Code : $token',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: status == 'pending'
                                                      ? const Color(0xFFFEF3C7)
                                                      : status == 'used'
                                                          ? const Color(
                                                              0xFFE5F9E7,
                                                            )
                                                          : const Color(
                                                              0xFFFEE2E2,
                                                            ),
                                                  borderRadius:
                                                      BorderRadius.circular(999),
                                                ),
                                                child: Text(
                                                  status,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: status == 'pending'
                                                        ? const Color(
                                                            0xFFF59E0B,
                                                          )
                                                        : status == 'used'
                                                            ? const Color(
                                                                0xFF1EA75C,
                                                              )
                                                            : const Color(
                                                                0xFFFF3B30,
                                                              ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              if (token.isNotEmpty)
                                                TextButton(
                                                  onPressed: () async {
                                                    await Clipboard.setData(
                                                      ClipboardData(text: token),
                                                    );
                                                    if (!mounted) return;
                                                    ScaffoldMessenger.of(context)
                                                        .showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Code copié dans le presse-papiers.',
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  child:
                                                      const Text('Copier le code'),
                                                ),
                                              if (status == 'pending')
                                                TextButton(
                                                  onPressed: invitationsProvider
                                                          .isSaving
                                                      ? null
                                                      : () async {
                                                          final id = inv['id']
                                                              ?.toString();
                                                          if (id == null ||
                                                              id.isEmpty) {
                                                            return;
                                                          }
                                                          await invitationsProvider
                                                              .cancelInvitation(
                                                            id,
                                                          );
                                                        },
                                                  child:
                                                      const Text('Annuler'),
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
      ),
    );
  }
}
