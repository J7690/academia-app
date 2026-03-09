import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_user_invitations_provider.dart';
import '../../providers/admin_universities_provider.dart';
import '../../providers/admin_users_overview_provider.dart';
import '../../providers/admin_td_teachers_provider.dart';

class AdminUserInvitationsScreen extends StatefulWidget {
  const AdminUserInvitationsScreen({super.key});

  @override
  State<AdminUserInvitationsScreen> createState() => _AdminUserInvitationsScreenState();
}

class _AdminUserInvitationsScreenState extends State<AdminUserInvitationsScreen> {
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _notesController = TextEditingController();
  final _universityEmailController = TextEditingController();
  final _universityPasswordController = TextEditingController();
  final _universityNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _adminFullNameController = TextEditingController();
  final _commercialEmailController = TextEditingController();
  final _commercialPasswordController = TextEditingController();
  final _commercialFullNameController = TextEditingController();
  final _commercialCommissionRateController = TextEditingController();
  final _teacherEmailController = TextEditingController();
  final _teacherPasswordController = TextEditingController();
  final _teacherFullNameController = TextEditingController();
  final _teacherDisciplineController = TextEditingController();
  final _teacherZoneController = TextEditingController();
  final _teacherAvailabilityController = TextEditingController();
  final _merchantEmailController = TextEditingController();
  final _merchantPasswordController = TextEditingController();
  final _merchantDisplayNameController = TextEditingController();
  final _merchantCountryController = TextEditingController();
  final _merchantCityController = TextEditingController();
  String _selectedRole = 'instructor';
  String? _selectedUniversityId;
  bool _isCreatingMerchantDirect = false;
  bool _isCreatingUniversityDirect = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminUserInvitationsProvider>().loadInvitations();
      context.read<AdminUniversitiesProvider>().loadUniversities();
      context.read<AdminUsersOverviewProvider>().loadUsers();
      context.read<AdminUsersOverviewProvider>().loadCommercialsOverview();
      context.read<AdminUsersOverviewProvider>().loadDeletedUsers();
    });
  }

  Future<void> _createMerchantAccountDirect(BuildContext context) async {
    final email = _merchantEmailController.text.trim();
    final password = _merchantPasswordController.text;
    final displayName = _merchantDisplayNameController.text.trim();
    final country = _merchantCountryController.text.trim();
    final city = _merchantCityController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez renseigner un email.')),
      );
      return;
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez renseigner un mot de passe temporaire.')),
      );
      return;
    }

    if (displayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez renseigner un nom de marchand.')),
      );
      return;
    }

    setState(() {
      _isCreatingMerchantDirect = true;
    });
    final provider = context.read<AdminUserInvitationsProvider>();
    final response = await provider.createMerchantAccountDirect(
      email: email,
      password: password,
      displayName: displayName,
      country: country.isEmpty ? null : country,
      city: city.isEmpty ? null : city,
    );

    if (mounted) {
      setState(() {
        _isCreatingMerchantDirect = false;
      });
    }

    if (!mounted) return;

    if (response == null) {
      final error = provider.error ?? 'Erreur lors de la création du compte marchand.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    _merchantEmailController.clear();
    _merchantPasswordController.clear();
    _merchantDisplayNameController.clear();
    _merchantCountryController.clear();
    _merchantCityController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Compte marchand créé avec succès.')),
    );
  }

  Future<void> _promoteUserToMerchant(
    BuildContext context,
    String userId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Promouvoir en marchand'),
          content: const Text(
            'Ce compte passera au rôle marchand. Voulez-vous continuer ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Promouvoir'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final usersProvider = context.read<AdminUsersOverviewProvider>();
    final ok = await usersProvider.promoteUserRole(
      userId: userId,
      targetRole: 'merchant',
    );

    if (!mounted) return;

    if (!ok) {
      final error = usersProvider.error ?? 'Promotion en marchand échouée.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compte promu en marchand.')),
      );
    }
  }

  Future<void> _createCommercialAccountDirect(BuildContext context) async {
    final email = _commercialEmailController.text.trim();
    final password = _commercialPasswordController.text;
    final fullName = _commercialFullNameController.text.trim();
    final commissionText = _commercialCommissionRateController.text.trim();

    double? commissionRate;
    if (commissionText.isNotEmpty) {
      final normalized = commissionText.replaceAll(',', '.');
      commissionRate = double.tryParse(normalized);
      if (commissionRate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veuillez renseigner un taux de commission valide.'),
          ),
        );
        return;
      }
    }

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez renseigner un email.'),
        ),
      );
      return;
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez renseigner un mot de passe temporaire.'),
        ),
      );
      return;
    }

    final provider = context.read<AdminUserInvitationsProvider>();
    final response = await provider.createCommercialAccountDirect(
      email: email,
      password: password,
      fullName: fullName.isEmpty ? null : fullName,
      commissionRate: commissionRate,
    );

    if (!mounted) return;

    if (response == null) {
      final error = provider.error ??
          'Erreur lors de la création du compte commercial.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    _commercialEmailController.clear();
    _commercialPasswordController.clear();
    _commercialFullNameController.clear();
     _commercialCommissionRateController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Compte commercial créé avec succès.'),
      ),
    );
  }

  Future<void> _showCommercialDetail(
    BuildContext context,
    String userId,
  ) async {
    final usersProvider = context.read<AdminUsersOverviewProvider>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Détail commercial'),
          content: FutureBuilder<Map<String, dynamic>?>(
            future: usersProvider.fetchCommercialDetail(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 60,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Text(
                  snapshot.error?.toString() ??
                      'Erreur lors du chargement du détail commercial.',
                  style: const TextStyle(color: Colors.red),
                );
              }
              final data = snapshot.data;
              if (data == null) {
                return const Text(
                  'Aucune donnée commerciale disponible.',
                  style: TextStyle(fontSize: 13),
                );
              }

              final commercial =
                  (data['commercial'] as Map?) ?? const <String, dynamic>{};
              final referrals =
                  (data['referrals'] as List?) ?? const <Map<String, dynamic>>[];
              final commissions =
                  (data['commissions'] as List?) ?? const <Map<String, dynamic>>[];

              return SizedBox(
                width: 420,
                height: 360,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (commercial['email'] ?? '').toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Code : ${(commercial['ref_code'] ?? '').toString()}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      if (commercial['commission_rate'] != null)
                        Text(
                          'Taux de commission : ${commercial['commission_rate']}%',
                          style: const TextStyle(fontSize: 12),
                        ),
                      const SizedBox(height: 12),
                      const Text(
                        'Étudiants rattachés',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (referrals.isEmpty)
                        const Text(
                          'Aucun étudiant référé pour le moment.',
                          style: TextStyle(fontSize: 12),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: referrals.length,
                          itemBuilder: (context, index) {
                            final ref = referrals[index] as Map;
                            final studentId =
                                (ref['student_id'] ?? '').toString();
                            final attributedAt =
                                (ref['attributed_at'] ?? '').toString();
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'Étudiant : $studentId',
                                style: const TextStyle(fontSize: 12),
                              ),
                              subtitle: attributedAt.isEmpty
                                  ? null
                                  : Text(
                                      'Attribué le : $attributedAt',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                            );
                          },
                        ),
                      const SizedBox(height: 12),
                      const Text(
                        'Commissions',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (commissions.isEmpty)
                        const Text(
                          'Aucune commission pour le moment.',
                          style: TextStyle(fontSize: 12),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: commissions.length,
                          itemBuilder: (context, index) {
                            final c = commissions[index] as Map;
                            final studentId =
                                (c['student_id'] ?? '').toString();
                            final amount = c['commission_amount'] ?? 0;
                            final currency =
                                (c['currency'] ?? '').toString();
                            final status =
                                (c['status'] ?? '').toString();
                            final commissionId =
                                (c['id'] ?? '').toString();
                            final isPending = status == 'pending';

                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'Étudiant : $studentId',
                                style: const TextStyle(fontSize: 12),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Montant : $amount $currency – Statut : $status',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  if (isPending) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        TextButton(
                                          onPressed:
                                              usersProvider.isUpdating
                                                  ? null
                                                  : () async {
                                                      final ok =
                                                          await usersProvider
                                                              .updateReferralCommissionStatus(
                                                        commissionId:
                                                            commissionId,
                                                        newStatus: 'paid',
                                                      );
                                                      if (!mounted) return;
                                                      final msg = ok
                                                          ? 'Commission marquée comme payée.'
                                                          : (usersProvider.error ??
                                                              'Mise à jour de la commission échouée.');
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                          content: Text(msg),
                                                        ),
                                                      );
                                                      if (ok) {
                                                        Navigator.of(
                                                                dialogContext)
                                                            .pop();
                                                      }
                                                    },
                                          child: const Text(
                                            'Marquer payée',
                                            style:
                                                TextStyle(fontSize: 11),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        TextButton(
                                          onPressed:
                                              usersProvider.isUpdating
                                                  ? null
                                                  : () async {
                                                      final ok =
                                                          await usersProvider
                                                              .updateReferralCommissionStatus(
                                                        commissionId:
                                                            commissionId,
                                                        newStatus:
                                                            'rejected',
                                                      );
                                                      if (!mounted) return;
                                                      final msg = ok
                                                          ? 'Commission rejetée.'
                                                          : (usersProvider.error ??
                                                              'Mise à jour de la commission échouée.');
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                          content: Text(msg),
                                                        ),
                                                      );
                                                      if (ok) {
                                                        Navigator.of(
                                                                dialogContext)
                                                            .pop();
                                                      }
                                                    },
                                          child: const Text(
                                            'Rejeter',
                                            style:
                                                TextStyle(fontSize: 11),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _promoteUserToCommercial(
    BuildContext context,
    String userId,
  ) async {
    final usersProvider = context.read<AdminUsersOverviewProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Promouvoir en commercial'),
          content: const Text(
            'Ce compte passera au rôle commercial. Voulez-vous continuer ?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    final ok = await usersProvider.promoteUserRole(
      userId: userId,
      targetRole: 'commercial',
    );

    if (!mounted) return;

    if (!ok) {
      final error = usersProvider.error ?? 'Promotion en commercial échouée.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compte promu en commercial.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _fullNameController.dispose();
    _notesController.dispose();
    _universityEmailController.dispose();
    _universityPasswordController.dispose();
    _universityNameController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    _adminFullNameController.dispose();
    _commercialEmailController.dispose();
    _commercialPasswordController.dispose();
    _commercialFullNameController.dispose();
    _commercialCommissionRateController.dispose();
    _teacherEmailController.dispose();
    _teacherPasswordController.dispose();
    _teacherFullNameController.dispose();
    _teacherDisciplineController.dispose();
    _teacherZoneController.dispose();
    _teacherAvailabilityController.dispose();
    _merchantEmailController.dispose();
    _merchantPasswordController.dispose();
    _merchantDisplayNameController.dispose();
    _merchantCountryController.dispose();
    _merchantCityController.dispose();
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

  Future<void> _createUniversityAccountDirect(BuildContext context) async {
    final email = _universityEmailController.text.trim();
    final password = _universityPasswordController.text;
    final universityName = _universityNameController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez renseigner un email.'),
        ),
      );
      return;
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez renseigner un mot de passe temporaire.'),
        ),
      );
      return;
    }

    if (universityName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez renseigner le nom de l\'université.'),
        ),
      );
      return;
    }

    setState(() {
      _isCreatingUniversityDirect = true;
    });
    final provider = context.read<AdminUserInvitationsProvider>();
    final response = await provider.createUniversityAccountDirect(
      email: email,
      password: password,
      universityName: universityName,
    );

    if (mounted) {
      setState(() {
        _isCreatingUniversityDirect = false;
      });
    }

    if (!mounted) return;

    if (response == null) {
      final error =
          provider.error ?? 'Erreur lors de la création du compte université.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    _universityEmailController.clear();
    _universityPasswordController.clear();
    _universityNameController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Compte université créé avec succès.'),
      ),
    );
  }

  Future<void> _createAdminAccountDirect(BuildContext context) async {
    final email = _adminEmailController.text.trim();
    final password = _adminPasswordController.text;
    final fullName = _adminFullNameController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez renseigner un email.'),
        ),
      );
      return;
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez renseigner un mot de passe temporaire.'),
        ),
      );
      return;
    }

    final provider = context.read<AdminUserInvitationsProvider>();
    final response = await provider.createAdminAccountDirect(
      email: email,
      password: password,
      fullName: fullName.isEmpty ? null : fullName,
    );

    if (!mounted) return;

    if (response == null) {
      final error = provider.error ??
          'Erreur lors de la création du compte administrateur.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    _adminEmailController.clear();
    _adminPasswordController.clear();
    _adminFullNameController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Compte administrateur créé avec succès.'),
      ),
    );
  }

  Future<void> _createTeacherAccountDirect(BuildContext context) async {
    final email = _teacherEmailController.text.trim().toLowerCase();
    final password = _teacherPasswordController.text;
    final fullNameInput = _teacherFullNameController.text.trim();
    final discipline = _teacherDisciplineController.text.trim();
    final zone = _teacherZoneController.text.trim();
    final availability = _teacherAvailabilityController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez renseigner un email.'),
        ),
      );
      return;
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez renseigner un mot de passe temporaire.'),
        ),
      );
      return;
    }

    final invitationsProvider =
        context.read<AdminUserInvitationsProvider>();
    final teacherAccount =
        await invitationsProvider.createTeacherAccountDirect(
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

    final tdTeachersProvider = context.read<AdminTdTeachersProvider>();
    final ok = await tdTeachersProvider.createTeacher(
      userId: userId,
      fullName: fullName,
      discipline: discipline.isEmpty ? null : discipline,
      zone: zone.isEmpty ? null : zone,
      availability: availability.isEmpty ? null : availability,
    );

    if (!mounted) return;

    if (!ok) {
      final error = tdTeachersProvider.error ??
          'Compte enseignant créé, mais erreur lors de la création de la fiche TD.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    _teacherEmailController.clear();
    _teacherPasswordController.clear();
    _teacherFullNameController.clear();
    _teacherDisciplineController.clear();
    _teacherZoneController.clear();
    _teacherAvailabilityController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Compte enseignant TD créé avec succès.'),
      ),
    );
  }

  Future<void> _promoteUserToAdmin(BuildContext context, String userId) async {
    final usersProvider = context.read<AdminUsersOverviewProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Promouvoir en administrateur'),
          content: const Text(
            'Ce compte passera au rôle administrateur. Voulez-vous continuer ?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    final ok = await usersProvider.promoteUserRole(
      userId: userId,
      targetRole: 'admin',
    );

    if (!mounted) return;

    if (!ok) {
      final error = usersProvider.error ??
          'Promotion en administrateur échouée.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compte promu en administrateur.'),
        ),
      );
    }
  }

  Future<void> _promoteUserToUniversity(
    BuildContext context,
    String userId,
  ) async {
    final nameController = TextEditingController();

    final universityName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Promouvoir en université'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Nom de l\'université',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(nameController.text.trim());
              },
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );

    if (universityName == null || universityName.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nom de l\'université requis pour la promotion.',
          ),
        ),
      );
      return;
    }

    final usersProvider = context.read<AdminUsersOverviewProvider>();
    final ok = await usersProvider.promoteUserRole(
      userId: userId,
      targetRole: 'university',
      universityName: universityName.trim(),
    );

    if (!mounted) return;

    if (!ok) {
      final error = usersProvider.error ??
          'Promotion en université échouée.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compte promu en université.'),
        ),
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
        title: const Text('Gestion des comptes utilisateurs'),
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
          final usersProvider = context.watch<AdminUsersOverviewProvider>();
          final universities = universitiesProvider.universities;
          final isLoading = invitationsProvider.isLoading;
          final isSaving = invitationsProvider.isSaving;
          final invitations = invitationsProvider.invitations;
          final users = usersProvider.users;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Comptes utilisateurs',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  onPressed: usersProvider.isLoading
                                      ? null
                                      : () {
                                          usersProvider.refresh();
                                        },
                                  icon: const Icon(Icons.refresh),
                                  tooltip: 'Actualiser les comptes',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (usersProvider.isLoading && users.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            else if (usersProvider.error != null && users.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  usersProvider.error!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              )
                            else if (users.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'Aucun compte utilisateur détecté pour le moment.',
                                  style: TextStyle(fontSize: 13),
                                ),
                              )
                            else
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  // Largeurs adaptatives :
                                  // - Sur desktop / grands écrans : on garde la largeur disponible (table pleine largeur)
                                  // - Sur mobile : on reste plus large que l'écran pour autoriser un scroll horizontal,
                                  //   mais sans largeur fixe rigide de 700px.
                                  final double maxWidth = constraints.maxWidth;
                                  final double targetMinWidth =
                                      maxWidth < 700 ? (maxWidth * 1.3) : maxWidth;

                                  final commercials =
                                      usersProvider.commercialsOverview ?? const [];
                                  int totalCommercials = commercials.length;
                                  int totalStudents = 0;
                                  num totalPending = 0;
                                  num totalPaid = 0;

                                  for (final item in commercials) {
                                    final studentsCount =
                                        item['students_count'] as num? ?? 0;
                                    final pending =
                                        item['total_commission_pending'] as num? ?? 0;
                                    final paid =
                                        item['total_commission_paid'] as num? ?? 0;
                                    totalStudents += studentsCount.toInt();
                                    totalPending += pending;
                                    totalPaid += paid;
                                  }

                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: IntrinsicWidth(
                                      child: Column(
                                        children: [
                                          const SizedBox(height: 4),
                                          if (totalCommercials > 0)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(bottom: 8.0),
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  'Commerciaux actifs : $totalCommercials  • '
                                                  'Étudiants référés : $totalStudents  • '
                                                  'Commissions en attente : $totalPending  • '
                                                  'Commissions payées : $totalPaid',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ...users.map((user) {
                                            final email = user['email']?.toString() ?? '';
                                            final role = user['role']?.toString() ?? '';
                                            final fullName = user['full_name']?.toString();
                                            final refCode =
                                                user['ref_code']?.toString() ?? '';
                                            final refLink =
                                                user['ref_link']?.toString() ?? '';
                                            final createdAt =
                                                user['created_at']?.toString() ?? '';
                                            final lastActivity =
                                                user['last_activity_at']?.toString() ?? '';
                                            final isOnline = user['is_online'] == true;
                                            final isSuspended =
                                                user['is_suspended'] == true;
                                            final suspendedReason =
                                                user['suspended_reason']?.toString();
                                            final isDeleted = user['is_deleted'] == true;
                                            final deletedReason =
                                                user['deleted_reason']?.toString();
                                            final title =
                                                (fullName != null && fullName.isNotEmpty)
                                                    ? fullName
                                                    : email;

                                            return ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              leading: Icon(
                                                Icons.circle,
                                                size: 10,
                                                color: isOnline
                                                    ? const Color(0xFF16A34A)
                                                    : Colors.grey,
                                              ),
                                              title: Text(title),
                                              subtitle: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  if (email.isNotEmpty)
                                                    Text(
                                                      email,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  Text(
                                                    'Rôle : ${role.isEmpty ? '–' : role}',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  if (role == 'commercial' &&
                                                      refCode.isNotEmpty)
                                                    Text(
                                                      'Code commercial : $refCode',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  if (role == 'commercial' &&
                                                      refLink.isNotEmpty)
                                                    Text(
                                                      'Lien : $refLink',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  Text(
                                                    isDeleted
                                                        ? 'Compte : supprimé'
                                                        : (isSuspended
                                                            ? 'Compte : suspendu'
                                                            : 'Compte : actif'),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: isDeleted
                                                          ? Colors.red
                                                          : (isSuspended
                                                              ? Colors.red
                                                              : const Color(
                                                                  0xFF16A34A,
                                                                )),
                                                    ),
                                                  ),
                                                  Text(
                                                    isOnline
                                                        ? 'Statut : en ligne'
                                                        : 'Statut : hors ligne',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: isOnline
                                                          ? const Color(0xFF16A34A)
                                                          : Colors.grey,
                                                    ),
                                                  ),
                                                  if (createdAt.isNotEmpty)
                                                    Text(
                                                      'Créé le : $createdAt',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  if (lastActivity.isNotEmpty)
                                                    Text(
                                                      'Dernière activité : $lastActivity',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  if (isSuspended &&
                                                      suspendedReason != null &&
                                                      suspendedReason.isNotEmpty)
                                                    Text(
                                                      'Raison suspension : $suspendedReason',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  if (isDeleted &&
                                                      deletedReason != null &&
                                                      deletedReason.isNotEmpty)
                                                    Text(
                                                      'Raison suppression : $deletedReason',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              trailing: Wrap(
                                                spacing: 8,
                                                children: [
                                                  TextButton(
                                                    onPressed: usersProvider
                                                                .isUpdating ||
                                                            isDeleted
                                                        ? null
                                                        : () async {
                                                            final targetId =
                                                                user['id']
                                                                    ?.toString();
                                                            if (targetId ==
                                                                    null ||
                                                                targetId
                                                                    .isEmpty) {
                                                              return;
                                                            }

                                                            final suspend =
                                                                !isSuspended;
                                                            final ok = await usersProvider
                                                                .updateUserStatus(
                                                              userId: targetId,
                                                              suspend: suspend,
                                                            );
                                                            if (!context
                                                                .mounted) {
                                                              return;
                                                            }
                                                            if (!ok) {
                                                              final error =
                                                                  usersProvider
                                                                          .error ??
                                                                      'Action admin échouée.';
                                                              ScaffoldMessenger
                                                                      .of(context)
                                                                  .showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                    error,
                                                                  ),
                                                                ),
                                                              );
                                                            } else {
                                                              ScaffoldMessenger
                                                                      .of(context)
                                                                  .showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                    suspend
                                                                        ? 'Compte suspendu.'
                                                                        : 'Compte réactivé.',
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                          },
                                                    child: Text(
                                                      isSuspended
                                                          ? 'Réactiver'
                                                          : 'Suspendre',
                                                    ),
                                                  ),
                                                  if (!isDeleted &&
                                                      role == 'student')
                                                    TextButton(
                                                      onPressed: usersProvider
                                                              .isUpdating
                                                          ? null
                                                          : () async {
                                                              final targetId =
                                                                  user['id']
                                                                      ?.toString();
                                                              if (targetId ==
                                                                      null ||
                                                                  targetId
                                                                      .isEmpty) {
                                                                return;
                                                              }
                                                              await _promoteUserToAdmin(
                                                                context,
                                                                targetId,
                                                              );
                                                            },
                                                      child: const Text(
                                                        'Rendre admin',
                                                      ),
                                                    ),
                                                  if (!isDeleted &&
                                                      role == 'commercial')
                                                    TextButton(
                                                      onPressed: () async {
                                                        final targetId = user['id']
                                                            ?.toString();
                                                        if (targetId == null ||
                                                            targetId.isEmpty) {
                                                          return;
                                                        }
                                                        await _showCommercialDetail(
                                                          context,
                                                          targetId,
                                                        );
                                                      },
                                                      child: const Text(
                                                        'Détail commercial',
                                                      ),
                                                    ),
                                                  if (!isDeleted &&
                                                      role == 'student')
                                                    TextButton(
                                                      onPressed: usersProvider
                                                              .isUpdating
                                                          ? null
                                                          : () async {
                                                              final targetId =
                                                                  user['id']
                                                                      ?.toString();
                                                              if (targetId ==
                                                                      null ||
                                                                  targetId
                                                                      .isEmpty) {
                                                                return;
                                                              }
                                                              await _promoteUserToCommercial(
                                                                context,
                                                                targetId,
                                                              );
                                                            },
                                                      child: const Text(
                                                        'Rendre commercial',
                                                      ),
                                                    ),
                                                  if (!isDeleted &&
                                                      role == 'student')
                                                    TextButton(
                                                      onPressed: usersProvider
                                                              .isUpdating
                                                          ? null
                                                          : () async {
                                                              final targetId =
                                                                  user['id']
                                                                      ?.toString();
                                                              if (targetId ==
                                                                      null ||
                                                                  targetId
                                                                      .isEmpty) {
                                                                return;
                                                              }
                                                              await _promoteUserToMerchant(
                                                                context,
                                                                targetId,
                                                              );
                                                            },
                                                      child: const Text(
                                                        'Rendre marchand',
                                                      ),
                                                    ),
                                                  if (!isDeleted &&
                                                      role == 'student')
                                                    TextButton(
                                                      onPressed: usersProvider
                                                              .isUpdating
                                                          ? null
                                                          : () async {
                                                              final targetId =
                                                                  user['id']
                                                                      ?.toString();
                                                              if (targetId ==
                                                                      null ||
                                                                  targetId
                                                                      .isEmpty) {
                                                                return;
                                                              }
                                                              await _promoteUserToUniversity(
                                                                context,
                                                                targetId,
                                                              );
                                                            },
                                                      child: const Text(
                                                        'Rendre université',
                                                      ),
                                                    ),
                                                  TextButton(
                                                    onPressed: usersProvider
                                                                .isUpdating ||
                                                            isDeleted
                                                        ? null
                                                        : () async {
                                                            final targetId =
                                                                user['id']
                                                                    ?.toString();
                                                            if (targetId ==
                                                                    null ||
                                                                targetId
                                                                    .isEmpty) {
                                                              return;
                                                            }
                                                            if (!context
                                                                .mounted) {
                                                              return;
                                                            }

                                                            final confirm =
                                                                await showDialog<
                                                                    bool>(
                                                              context: context,
                                                              builder:
                                                                  (dialogContext) {
                                                                return AlertDialog(
                                                                  title:
                                                                      const Text(
                                                                    'Supprimer le compte utilisateur',
                                                                  ),
                                                                  content:
                                                                      const Text(
                                                                    'Ce compte sera définitivement supprimé et archivé dans l\'onglet "Comptes supprimés". Voulez-vous continuer ?',
                                                                  ),
                                                                  actions: [
                                                                    TextButton(
                                                                      onPressed:
                                                                          () {
                                                                        Navigator.of(
                                                                                dialogContext)
                                                                            .pop(
                                                                          false,
                                                                        );
                                                                      },
                                                                      child:
                                                                          const Text(
                                                                        'Annuler',
                                                                      ),
                                                                    ),
                                                                    TextButton(
                                                                      onPressed:
                                                                          () {
                                                                        Navigator.of(
                                                                                dialogContext)
                                                                            .pop(
                                                                          true,
                                                                        );
                                                                      },
                                                                      child:
                                                                          const Text(
                                                                        'Supprimer',
                                                                      ),
                                                                    ),
                                                                  ],
                                                                );
                                                              },
                                                            );

                                                            if (confirm !=
                                                                true) {
                                                              return;
                                                            }

                                                            final ok = await usersProvider
                                                                .hardDeleteUserAccount(
                                                              userId: targetId,
                                                            );
                                                            if (!context
                                                                .mounted) {
                                                              return;
                                                            }
                                                            if (!ok) {
                                                              final error =
                                                                  usersProvider
                                                                          .error ??
                                                                      'Suppression du compte échouée.';
                                                              ScaffoldMessenger
                                                                      .of(context)
                                                                  .showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                    error,
                                                                  ),
                                                                ),
                                                              );
                                                            } else {
                                                              ScaffoldMessenger
                                                                      .of(context)
                                                                  .showSnackBar(
                                                                const SnackBar(
                                                                  content: Text(
                                                                    'Compte supprimé et archivé.',
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                          },
                                                    child: const Text(
                                                      'Supprimer',
                                                    ),
                                                  ),
                                                  TextButton(
                                                    onPressed: () async {
                                                      final targetId =
                                                          user['id']
                                                              ?.toString();
                                                      if (targetId == null ||
                                                          targetId.isEmpty) {
                                                        return;
                                                      }
                                                      if (!context.mounted) {
                                                        return;
                                                      }

                                                      showDialog(
                                                        context: context,
                                                        builder:
                                                            (dialogContext) {
                                                          return AlertDialog(
                                                            title:
                                                                const Text(
                                                              'Historique des actions',
                                                            ),
                                                            content: FutureBuilder<
                                                                List<
                                                                    Map<String,
                                                                        dynamic>>>(
                                                              future: usersProvider
                                                                  .fetchUserActionLogs(
                                                                targetId,
                                                              ),
                                                              builder: (context,
                                                                  snapshot) {
                                                                if (snapshot
                                                                        .connectionState ==
                                                                    ConnectionState
                                                                        .waiting) {
                                                                  return const SizedBox(
                                                                    height: 60,
                                                                    child: Center(
                                                                      child:
                                                                          CircularProgressIndicator(
                                                                        strokeWidth:
                                                                            2,
                                                                      ),
                                                                    ),
                                                                  );
                                                                }
                                                                if (snapshot
                                                                    .hasError) {
                                                                  return Text(
                                                                    snapshot.error?.toString() ??
                                                                        'Erreur lors du chargement de l\'historique.',
                                                                    style:
                                                                        const TextStyle(
                                                                      color: Colors
                                                                          .red,
                                                                    ),
                                                                  );
                                                                }

                                                                final logs =
                                                                    snapshot.data ??
                                                                        const [];
                                                                if (logs
                                                                    .isEmpty) {
                                                                  return const Text(
                                                                    'Aucune action admin enregistrée pour ce compte.',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          13,
                                                                    ),
                                                                  );
                                                                }

                                                                return SizedBox(
                                                                  width: 400,
                                                                  height: 240,
                                                                  child:
                                                                      ListView.builder(
                                                                    itemCount:
                                                                        logs.length,
                                                                    itemBuilder:
                                                                        (context,
                                                                            index) {
                                                                      final log =
                                                                          logs[index];
                                                                      final action =
                                                                          log['action']
                                                                                  ?.toString() ??
                                                                              '';
                                                                      final reason =
                                                                          log['reason']
                                                                                  ?.toString() ??
                                                                              '';
                                                                      final createdAt =
                                                                          log['created_at']
                                                                                  ?.toString() ??
                                                                              '';
                                                                      return ListTile(
                                                                        contentPadding:
                                                                            EdgeInsets.zero,
                                                                        title:
                                                                            Text(
                                                                          'Action : $action',
                                                                          style:
                                                                              const TextStyle(
                                                                            fontSize:
                                                                                13,
                                                                          ),
                                                                        ),
                                                                        subtitle:
                                                                            Column(
                                                                          crossAxisAlignment:
                                                                              CrossAxisAlignment.start,
                                                                          children:
                                                                              [
                                                                            if (reason
                                                                                .isNotEmpty)
                                                                              Text(
                                                                                'Raison : $reason',
                                                                                style:
                                                                                    const TextStyle(
                                                                                  fontSize:
                                                                                      12,
                                                                                ),
                                                                              ),
                                                                            if (createdAt
                                                                                .isNotEmpty)
                                                                              Text(
                                                                                'Le : $createdAt',
                                                                                style:
                                                                                    const TextStyle(
                                                                                  fontSize:
                                                                                      11,
                                                                                  color:
                                                                                      Colors.grey,
                                                                                ),
                                                                              ),
                                                                          ],
                                                                        ),
                                                                      );
                                                                    },
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () {
                                                                  Navigator.of(
                                                                          dialogContext)
                                                                      .pop();
                                                                },
                                                                child:
                                                                    const Text(
                                                                  'Fermer',
                                                                ),
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      );
                                                    },
                                                    child: const Text(
                                                      'Historique',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                              'Créer un compte université',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _universityEmailController,
                              decoration: const InputDecoration(
                                labelText: 'Email du compte université',
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _universityPasswordController,
                              decoration: const InputDecoration(
                                labelText: 'Mot de passe temporaire',
                              ),
                              obscureText: true,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _universityNameController,
                              decoration: const InputDecoration(
                                labelText: 'Nom de l\'université',
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton(
                                onPressed: _isCreatingUniversityDirect
                                    ? null
                                    : () => _createUniversityAccountDirect(
                                          context,
                                        ),
                                child: _isCreatingUniversityDirect
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Créer le compte université'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                              'Créer un compte marchand (direct)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _merchantEmailController,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _merchantPasswordController,
                              decoration: const InputDecoration(
                                labelText: 'Mot de passe temporaire',
                              ),
                              obscureText: true,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _merchantDisplayNameController,
                              decoration: const InputDecoration(
                                labelText: 'Nom du marchand',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _merchantCountryController,
                                    decoration: const InputDecoration(
                                      labelText: 'Pays (optionnel)',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _merchantCityController,
                                    decoration: const InputDecoration(
                                      labelText: 'Ville (optionnel)',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton(
                                onPressed: _isCreatingMerchantDirect
                                    ? null
                                    : () => _createMerchantAccountDirect(
                                          context,
                                        ),
                                child: _isCreatingMerchantDirect
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Créer le compte marchand'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                              'Créer un compte administrateur',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _adminEmailController,
                              decoration: const InputDecoration(
                                labelText: 'Email du compte administrateur',
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _adminFullNameController,
                              decoration: const InputDecoration(
                                labelText: 'Nom complet (optionnel)',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _adminPasswordController,
                              decoration: const InputDecoration(
                                labelText: 'Mot de passe temporaire',
                              ),
                              obscureText: true,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton(
                                onPressed: isSaving
                                    ? null
                                    : () => _createAdminAccountDirect(context),
                                child: isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Créer le compte administrateur'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                              'Créer un compte commercial',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _commercialEmailController,
                              decoration: const InputDecoration(
                                labelText: 'Email du compte commercial',
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _commercialFullNameController,
                              decoration: const InputDecoration(
                                labelText: 'Nom complet (optionnel)',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _commercialCommissionRateController,
                              decoration: const InputDecoration(
                                labelText: 'Taux de commission (%) (optionnel)',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: false,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.,]'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _commercialPasswordController,
                              decoration: const InputDecoration(
                                labelText: 'Mot de passe temporaire',
                              ),
                              obscureText: true,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton(
                                onPressed: isSaving
                                    ? null
                                    : () => _createCommercialAccountDirect(
                                          context,
                                        ),
                                child: isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Créer le compte commercial'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                              'Créer un compte enseignant TD',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _teacherEmailController,
                              decoration: const InputDecoration(
                                labelText: 'Email du compte enseignant',
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _teacherFullNameController,
                              decoration: const InputDecoration(
                                labelText: 'Nom complet (optionnel)',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _teacherPasswordController,
                              decoration: const InputDecoration(
                                labelText: 'Mot de passe temporaire',
                              ),
                              obscureText: true,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _teacherDisciplineController,
                              decoration: const InputDecoration(
                                labelText: 'Discipline TD',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _teacherZoneController,
                              decoration: const InputDecoration(
                                labelText: 'Zone géographique',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _teacherAvailabilityController,
                              decoration: const InputDecoration(
                                labelText: 'Disponibilité',
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton(
                                onPressed: isSaving
                                    ? null
                                    : () => _createTeacherAccountDirect(
                                          context,
                                        ),
                                child: isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Créer le compte enseignant TD'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                              value: 'merchant',
                              child: Text('Marchand'),
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
              const SizedBox(height: 16),
              if (isLoading && invitations.isEmpty)
                const Center(child: CircularProgressIndicator())
              else if (invitations.isEmpty)
                const Center(
                  child: Text('Aucune invitation créée pour le moment.'),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
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
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Comptes supprimés',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  onPressed: usersProvider.isLoading
                                      ? null
                                      : () {
                                          usersProvider.loadDeletedUsers();
                                        },
                                  icon: const Icon(Icons.refresh),
                                  tooltip: 'Actualiser les comptes supprimés',
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Archive des comptes supprimés pour traçabilité.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (usersProvider.deletedUsers.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'Aucun compte supprimé pour le moment.',
                                  style: TextStyle(fontSize: 13),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: usersProvider.deletedUsers.length,
                                itemBuilder: (context, index) {
                                  final du = usersProvider.deletedUsers[index];
                                  final email = du['email']?.toString() ?? '';
                                  final role = du['role']?.toString() ?? '';
                                  final fullName = du['full_name']?.toString() ?? '';
                                  final deletedAt = du['deleted_at']?.toString() ?? '';
                                  final reason = du['deleted_reason']?.toString() ?? '';
                                  final userId = du['user_id']?.toString() ?? '';

                                  String roleLabel;
                                  switch (role) {
                                    case 'admin':
                                      roleLabel = 'Administrateur';
                                      break;
                                    case 'university':
                                      roleLabel = 'Université';
                                      break;
                                    case 'student':
                                      roleLabel = 'Étudiant';
                                      break;
                                    case 'commercial':
                                      roleLabel = 'Commercial';
                                      break;
                                    case 'teacher':
                                      roleLabel = 'Enseignant';
                                      break;
                                    case 'instructor':
                                      roleLabel = 'Formateur';
                                      break;
                                    default:
                                      roleLabel = role.isNotEmpty ? role : 'Inconnu';
                                  }

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    color: const Color(0xFFFEF2F2),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  email.isNotEmpty
                                                      ? email
                                                      : (fullName.isNotEmpty
                                                          ? fullName
                                                          : userId),
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFF3B30)
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(999),
                                                ),
                                                child: Text(
                                                  roleLabel,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFFFF3B30),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (fullName.isNotEmpty &&
                                              email.isNotEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 2),
                                              child: Text(
                                                fullName,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                          if (deletedAt.isNotEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 2),
                                              child: Text(
                                                'Supprimé le : $deletedAt',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                          if (reason.isNotEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 2),
                                              child: Text(
                                                'Raison : $reason',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
