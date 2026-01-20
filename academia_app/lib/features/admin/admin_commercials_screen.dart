import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/admin_users_overview_provider.dart';

class AdminCommercialsScreen extends StatefulWidget {
  const AdminCommercialsScreen({super.key});

  @override
  State<AdminCommercialsScreen> createState() => _AdminCommercialsScreenState();
}

class _AdminCommercialsScreenState extends State<AdminCommercialsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AdminUsersOverviewProvider>();
      provider.loadUsers();
      provider.loadCommercialsOverview();
    });
  }

  Future<void> _showEditCommissionRateDialog(
    BuildContext context,
    String userId,
    double? currentRate,
  ) async {
    final controller = TextEditingController(
      text: currentRate?.toString() ?? '',
    );
    final usersProvider = context.read<AdminUsersOverviewProvider>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Modifier le taux de commission'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Taux (%)',
              hintText: 'Ex: 5.0',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () async {
                final text = controller.text.trim().replaceAll(',', '.');
                final parsed = double.tryParse(text);
                if (parsed == null || parsed < 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Taux invalide. Veuillez saisir un nombre positif.'),
                    ),
                  );
                  return;
                }
                final ok = await usersProvider.updateCommercialCommissionRate(
                  userId: userId,
                  rate: parsed,
                );
                if (!dialogContext.mounted) return;
                if (!ok) {
                  final error = usersProvider.error ??
                      'Mise à jour du taux de commission échouée.';
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(error)),
                  );
                } else {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text('Taux de commission mis à jour à ${parsed.toString()}%.'),
                    ),
                  );
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showShareReferralDialog(BuildContext context, String link) async {
    final encodedLink = Uri.encodeComponent(link);
    final message = 'Rejoins Academia avec ce lien de parrainage : $link';
    final encodedMessage = Uri.encodeComponent(message);

    Future<void> launchShare(Uri uri) async {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir l\'application de partage.'),
          ),
        );
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Partager le lien commercial'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.chat, color: Colors.green),
                title: const Text('WhatsApp'),
                onTap: () async {
                  await launchShare(
                    Uri.parse('https://wa.me/?text=$encodedMessage'),
                  );
                  Navigator.of(dialogContext).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.facebook, color: Colors.blue),
                title: const Text('Facebook'),
                onTap: () async {
                  await launchShare(
                    Uri.parse(
                      'https://www.facebook.com/sharer/sharer.php?u=$encodedLink',
                    ),
                  );
                  Navigator.of(dialogContext).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.send, color: Colors.blueAccent),
                title: const Text('Telegram'),
                onTap: () async {
                  await launchShare(
                    Uri.parse(
                      'https://t.me/share/url?url=$encodedLink&text=$encodedMessage',
                    ),
                  );
                  Navigator.of(dialogContext).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.purple),
                title: const Text('Instagram'),
                onTap: () async {
                  await launchShare(Uri.parse(link));
                  Navigator.of(dialogContext).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.ondemand_video, color: Colors.red),
                title: const Text('YouTube'),
                onTap: () async {
                  await launchShare(Uri.parse(link));
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
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

  Future<void> _showUserActionHistory(
    BuildContext context,
    String userId,
  ) async {
    final usersProvider = context.read<AdminUsersOverviewProvider>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Historique des actions'),
          content: FutureBuilder<List<Map<String, dynamic>>>(
            future: usersProvider.fetchUserActionLogs(userId),
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
                      'Erreur lors du chargement de l\'historique.',
                  style: const TextStyle(color: Colors.red),
                );
              }
              final logs = snapshot.data ?? const [];
              if (logs.isEmpty) {
                return const Text(
                  'Aucune action enregistrée pour ce compte.',
                  style: TextStyle(fontSize: 13),
                );
              }

              return SizedBox(
                width: 400,
                height: 240,
                child: ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final action = log['action']?.toString() ?? '';
                    final reason = log['reason']?.toString() ?? '';
                    final createdAt = log['created_at']?.toString() ?? '';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Action : $action',
                        style: const TextStyle(
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (reason.isNotEmpty)
                            Text(
                              'Raison : $reason',
                              style: const TextStyle(
                                fontSize: 12,
                              ),
                            ),
                          if (createdAt.isNotEmpty)
                            Text(
                              'Le : $createdAt',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
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
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminUsersOverviewProvider>(
      builder: (context, usersProvider, child) {
        final users = usersProvider.users;
        final commercials = users.where((user) {
          final role = user['role']?.toString() ?? '';
          return role == 'commercial';
        }).toList(growable: false);

        final overview = usersProvider.commercialsOverview ?? const [];
        int totalCommercials = overview.length;
        int totalStudents = 0;
        num totalPending = 0;
        num totalPaid = 0;

        for (final item in overview) {
          final studentsCount = item['students_count'] as num? ?? 0;
          final pending = item['total_commission_pending'] as num? ?? 0;
          final paid = item['total_commission_paid'] as num? ?? 0;
          totalStudents += studentsCount.toInt();
          totalPending += pending;
          totalPaid += paid;
        }

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
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
                              'Commerciaux',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: usersProvider.isLoading
                                  ? null
                                  : () {
                                      usersProvider.loadUsers();
                                      usersProvider.loadCommercialsOverview();
                                    },
                              icon: const Icon(Icons.refresh),
                              tooltip: 'Actualiser les commerciaux',
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
                        else if (usersProvider.error != null)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              usersProvider.error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          )
                        else if (commercials.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Aucun compte commercial détecté pour le moment.',
                              style: TextStyle(fontSize: 13),
                            ),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (totalCommercials > 0)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
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
                              ListView.builder(
                                shrinkWrap: true,
                                physics:
                                    const NeverScrollableScrollPhysics(),
                                itemCount: commercials.length,
                                itemBuilder: (context, index) {
                                  final user = commercials[index];
                                  final email =
                                      user['email']?.toString() ?? '';
                                  final role =
                                      user['role']?.toString() ?? '';
                                  final fullName =
                                      user['full_name']?.toString();
                                  final refCode =
                                      user['ref_code']?.toString() ?? '';
                                  final refLink =
                                      user['ref_link']?.toString() ?? '';
                                  final createdAt = user['created_at']
                                          ?.toString() ??
                                      '';
                                  final lastActivity =
                                      user['last_activity_at']
                                              ?.toString() ??
                                          '';
                                  final isOnline =
                                      user['is_online'] == true;
                                  final isSuspended =
                                      user['is_suspended'] == true;
                                  final suspendedReason = user[
                                          'suspended_reason']
                                      ?.toString();
                                  final isDeleted =
                                      user['is_deleted'] == true;
                                  final deletedReason = user['deleted_reason']
                                      ?.toString();
                                  // Stats par commercial depuis l'overview
                                  final overviewItem = overview.firstWhere(
                                    (item) =>
                                        (item['user_id']?.toString() ?? '') ==
                                        (user['id']?.toString() ?? ''),
                                    orElse: () => const <String, dynamic>{},
                                  );
                                  final perStudentsCount =
                                      overviewItem['students_count'] as num? ??
                                          0;
                                  final perPending =
                                      overviewItem['total_commission_pending']
                                              as num? ??
                                          0;
                                  final perPaid =
                                      overviewItem['total_commission_paid']
                                              as num? ??
                                          0;
                                  final perRate =
                                      overviewItem['commission_rate'] as num?;
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
                                        if (refCode.isNotEmpty)
                                          Text(
                                            'Code commercial : $refCode',
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        if (refLink.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          SelectableText(
                                            'Lien : $refLink',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
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
                                        if (perStudentsCount > 0 ||
                                            perPending > 0 ||
                                            perPaid > 0)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 4),
                                            child: Text(
                                              'Étudiants référés : ${perStudentsCount.toInt()}  •  En attente : $perPending  •  Payées : $perPaid',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: Wrap(
                                      spacing: 8,
                                      children: [
                                        if (refLink.isNotEmpty)
                                          TextButton(
                                            onPressed: () async {
                                              await Clipboard.setData(
                                                ClipboardData(text: refLink),
                                              );
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Lien commercial copié.',
                                                  ),
                                                ),
                                              );
                                            },
                                            child: const Text('Copier le lien'),
                                          ),
                                        if (refLink.isNotEmpty)
                                          TextButton(
                                            onPressed: () {
                                              _showShareReferralDialog(
                                                context,
                                                refLink,
                                              );
                                            },
                                            child: const Text('Partager'),
                                          ),
                                        if (!isDeleted)
                                          TextButton(
                                            onPressed:
                                                usersProvider.isUpdating
                                                    ? null
                                                    : () async {
                                                        final targetId =
                                                            user['id']
                                                                ?.toString();
                                                        if (targetId == null ||
                                                            targetId.isEmpty) {
                                                          return;
                                                        }

                                                        await _showEditCommissionRateDialog(
                                                          context,
                                                          targetId,
                                                          perRate
                                                              ?.toDouble(),
                                                        );
                                                      },
                                            child: const Text(
                                              'Taux commission',
                                            ),
                                          ),
                                        TextButton(
                                          onPressed: usersProvider.isUpdating ||
                                                  isDeleted
                                              ? null
                                              : () async {
                                                  final targetId = user['id']
                                                      ?.toString();
                                                  if (targetId == null ||
                                                      targetId.isEmpty) {
                                                    return;
                                                  }

                                                  final suspend = !isSuspended;
                                                  final ok = await usersProvider
                                                      .updateUserStatus(
                                                    userId: targetId,
                                                    suspend: suspend,
                                                  );
                                                  if (!context.mounted) {
                                                    return;
                                                  }
                                                  if (!ok) {
                                                    final error =
                                                        usersProvider.error ??
                                                            'Action admin échouée.';
                                                    ScaffoldMessenger.of(context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          error,
                                                        ),
                                                      ),
                                                    );
                                                  } else {
                                                    ScaffoldMessenger.of(context)
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
                                        if (!isDeleted)
                                          TextButton(
                                            onPressed: () async {
                                              final targetId =
                                                  user['id']?.toString();
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
                                        TextButton(
                                          onPressed: usersProvider.isUpdating ||
                                                  isDeleted
                                              ? null
                                              : () async {
                                                  final targetId = user['id']
                                                      ?.toString();
                                                  if (targetId == null ||
                                                      targetId.isEmpty) {
                                                    return;
                                                  }
                                                  if (!context.mounted) {
                                                    return;
                                                  }

                                                  final confirm =
                                                      await showDialog<bool>(
                                                    context: context,
                                                    builder: (dialogContext) {
                                                      return AlertDialog(
                                                        title: const Text(
                                                          'Supprimer le compte utilisateur',
                                                        ),
                                                        content: const Text(
                                                          'Cette action marque le compte comme supprimé et suspend l\'accès. Voulez-vous continuer ?',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () {
                                                              Navigator.of(
                                                                dialogContext,
                                                              ).pop(false);
                                                            },
                                                            child: const Text(
                                                              'Annuler',
                                                            ),
                                                          ),
                                                          TextButton(
                                                            onPressed: () {
                                                              Navigator.of(
                                                                dialogContext,
                                                              ).pop(true);
                                                            },
                                                            child: const Text(
                                                              'Supprimer',
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  );

                                                  if (confirm != true) {
                                                    return;
                                                  }

                                                  final ok = await usersProvider
                                                      .deleteUserAccount(
                                                    userId: targetId,
                                                  );
                                                  if (!context.mounted) {
                                                    return;
                                                  }
                                                  if (!ok) {
                                                    final error =
                                                        usersProvider.error ??
                                                            'Suppression du compte échouée.';
                                                    ScaffoldMessenger.of(context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          error,
                                                        ),
                                                      ),
                                                    );
                                                  } else {
                                                    ScaffoldMessenger.of(context)
                                                        .showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Compte utilisateur supprimé.',
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
                                                user['id']?.toString();
                                            if (targetId == null ||
                                                targetId.isEmpty) {
                                              return;
                                            }
                                            if (!context.mounted) {
                                              return;
                                            }

                                            await _showUserActionHistory(
                                              context,
                                              targetId,
                                            );
                                          },
                                          child: const Text(
                                            'Historique',
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
