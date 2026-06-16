import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_user_invitations_provider.dart';
import '../../providers/admin_universities_provider.dart';
import '../../providers/admin_users_overview_provider.dart';
import '../../providers/admin_td_teachers_provider.dart';
import '../../providers/admin_support_provider.dart';
import 'admin_support_chat_screen.dart';

/// Écran unifié "Comptes" avec 6 sous-onglets :
/// Tous | Étudiants | Commerciaux | Enseignants | Universités | Marchands
class AdminAccountsScreen extends StatefulWidget {
  const AdminAccountsScreen({super.key});

  @override
  State<AdminAccountsScreen> createState() => _AdminAccountsScreenState();
}

class _AdminAccountsScreenState extends State<AdminAccountsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 6, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final usersP = context.read<AdminUsersOverviewProvider>();
      final invP = context.read<AdminUserInvitationsProvider>();
      final uniP = context.read<AdminUniversitiesProvider>();
      usersP.loadUsers();
      usersP.loadCommercialsOverview();
      usersP.loadDeletedUsers();
      usersP.loadMilestoneClaims();
      invP.loadInvitations();
      uniP.loadUniversities();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Map<String, int> _countByRole(List<Map<String, dynamic>> users) {
    final m = <String, int>{};
    for (final u in users) {
      final r = u['role']?.toString() ?? 'unknown';
      m[r] = (m[r] ?? 0) + 1;
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AdminUsersOverviewProvider, AdminUserInvitationsProvider>(
      builder: (context, usersP, invP, _) {
        final users = usersP.users;
        final counts = _countByRole(users);
        final total = users.length;
        final nStudents = counts['student'] ?? 0;
        final nCommercials = counts['commercial'] ?? 0;
        final nInstructors = counts['instructor'] ?? 0;
        final nUniversities = counts['university'] ?? 0;
        final nMerchants = counts['merchant'] ?? 0;

        return Column(
          children: [
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: TabBar(
                controller: _tabCtrl,
                isScrollable: true,
                labelColor: const Color(0xFF1EA75C),
                unselectedLabelColor: const Color(0xFF6B7280),
                indicatorColor: const Color(0xFF1EA75C),
                labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                tabs: [
                  Tab(text: 'Tous ($total)'),
                  Tab(text: 'Étudiants ($nStudents)'),
                  Tab(text: 'Commerciaux ($nCommercials)'),
                  Tab(text: 'Enseignants ($nInstructors)'),
                  Tab(text: 'Universités ($nUniversities)'),
                  Tab(text: 'Marchands ($nMerchants)'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: const [
                  _AllUsersTab(),
                  _StudentsTab(),
                  _CommercialsTab(),
                  _InstructorsTab(),
                  _UniversitiesTab(),
                  _MerchantsTab(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// SHARED HELPERS
// ════════════════════════════════════════════════════════════════════

String _fmtDate(String iso) {
  try {
    final dt = DateTime.parse(iso);
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return iso;
  }
}

Widget _userTile({
  required BuildContext context,
  required Map<String, dynamic> user,
  required AdminUsersOverviewProvider usersP,
  List<Widget> extraActions = const [],
  bool showRole = true,
}) {
  final email = user['email']?.toString() ?? '';
  final role = user['role']?.toString() ?? '';
  final fullName = user['full_name']?.toString();
  final createdAt = user['created_at']?.toString() ?? '';
  final lastActivity = user['last_activity_at']?.toString() ?? '';
  final isOnline = user['is_online'] == true;
  final isSuspended = user['is_suspended'] == true;
  final suspendedReason = user['suspended_reason']?.toString();
  final isDeleted = user['is_deleted'] == true;
  final deletedReason = user['deleted_reason']?.toString();
  final title = (fullName != null && fullName.isNotEmpty) ? fullName : email;

  return ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(Icons.circle, size: 10, color: isOnline ? const Color(0xFF16A34A) : Colors.grey),
    title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (email.isNotEmpty) Text(email, style: const TextStyle(fontSize: 11)),
        if (showRole) Text('Rôle : ${role.isEmpty ? '–' : role}', style: const TextStyle(fontSize: 11)),
        Text(
          isDeleted ? 'Compte : supprimé' : (isSuspended ? 'Compte : suspendu' : 'Compte : actif'),
          style: TextStyle(fontSize: 10, color: (isDeleted || isSuspended) ? Colors.red : const Color(0xFF16A34A)),
        ),
        Text(isOnline ? 'En ligne' : 'Hors ligne', style: TextStyle(fontSize: 10, color: isOnline ? const Color(0xFF16A34A) : Colors.grey)),
        if (createdAt.isNotEmpty) Text('Créé : ${_fmtDate(createdAt)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
        if (lastActivity.isNotEmpty) Text('Activité : ${_fmtDate(lastActivity)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
        if (isSuspended && suspendedReason != null && suspendedReason.isNotEmpty)
          Text('Raison : $suspendedReason', style: const TextStyle(fontSize: 10, color: Colors.grey)),
        if (isDeleted && deletedReason != null && deletedReason.isNotEmpty)
          Text('Raison : $deletedReason', style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    ),
    trailing: Wrap(
      spacing: 4,
      children: [
        // Suspend/Reactivate
        TextButton(
          onPressed: usersP.isUpdating || isDeleted
              ? null
              : () async {
                  final id = user['id']?.toString();
                  if (id == null) return;
                  final ok = await usersP.updateUserStatus(userId: id, suspend: !isSuspended);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? (isSuspended ? 'Réactivé.' : 'Suspendu.') : (usersP.error ?? 'Erreur'))),
                  );
                },
          child: Text(isSuspended ? 'Réactiver' : 'Suspendre', style: const TextStyle(fontSize: 10)),
        ),
        // Delete
        if (!isDeleted)
          TextButton(
            onPressed: usersP.isUpdating
                ? null
                : () async {
                    final id = user['id']?.toString();
                    if (id == null) return;
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (d) => AlertDialog(
                        title: const Text('Supprimer le compte'),
                        content: const Text('Ce compte sera supprimé. Continuer ?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Annuler')),
                          TextButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('Supprimer')),
                        ],
                      ),
                    );
                    if (confirm != true || !context.mounted) return;
                    final ok = await usersP.hardDeleteUserAccount(userId: id);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ok ? 'Supprimé.' : (usersP.error ?? 'Erreur'))),
                    );
                  },
            child: const Text('Supprimer', style: TextStyle(fontSize: 10)),
          ),
        // History
        TextButton(
          onPressed: () => _showHistory(context, usersP, user['id']?.toString() ?? ''),
          child: const Text('Historique', style: TextStyle(fontSize: 10)),
        ),
        ...extraActions,
      ],
    ),
  );
}

Future<void> _showHistory(BuildContext context, AdminUsersOverviewProvider usersP, String userId) async {
  await showDialog<void>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Historique des actions'),
      content: FutureBuilder<List<Map<String, dynamic>>>(
        future: usersP.fetchUserActionLogs(userId),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
          }
          final logs = snap.data ?? [];
          if (logs.isEmpty) return const Text('Aucune action enregistrée.', style: TextStyle(fontSize: 13));
          return SizedBox(
            width: 400,
            height: 240,
            child: ListView.builder(
              itemCount: logs.length,
              itemBuilder: (ctx, i) {
                final l = logs[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${l['action']}', style: const TextStyle(fontSize: 12)),
                  subtitle: Text('${l['reason'] ?? ''} — ${_fmtDate(l['created_at']?.toString() ?? '')}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                );
              },
            ),
          );
        },
      ),
      actions: [TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Fermer'))],
    ),
  );
}

Future<void> _initiateSupportChat(BuildContext context, String email) async {
  try {
    final usersP = context.read<AdminUsersOverviewProvider>();
    final existingId = await usersP.checkSupportConversationExists(email);
    String? convId = existingId ?? await usersP.createSupportConversation(email: email);
    if (!context.mounted) return;
    if (convId != null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => AdminSupportProvider(),
          child: AdminSupportChatScreen(conversationId: convId, requesterName: email, requesterRole: 'student', status: 'open'),
        ),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur conversation support.')));
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
  }
}

Future<void> _showCommercialDetail(BuildContext context, AdminUsersOverviewProvider usersP, String userId) async {
  await showDialog<void>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Détail commercial'),
      content: FutureBuilder<Map<String, dynamic>?>(
        future: usersP.fetchCommercialDetail(userId),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
          }
          final data = snap.data;
          if (data == null) return const Text('Aucune donnée.', style: TextStyle(fontSize: 13));
          final commercial = (data['commercial'] as Map?) ?? {};
          final referrals = (data['referrals'] as List?) ?? [];
          final commissions = (data['commissions'] as List?) ?? [];
          return SizedBox(
            width: 420,
            height: 360,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${commercial['email'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Code : ${commercial['ref_code'] ?? ''}', style: const TextStyle(fontSize: 12)),
                  if (commercial['commission_rate'] != null) Text('Taux : ${commercial['commission_rate']}%', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 12),
                  Text('Étudiants référés (${referrals.length})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  if (referrals.isEmpty) const Text('Aucun.', style: TextStyle(fontSize: 11)),
                  ...referrals.map((r) {
                    final ref = r as Map;
                    return Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('${ref['student_id']} — ${ref['attributed_at'] ?? ''}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    );
                  }),
                  const SizedBox(height: 12),
                  Text('Commissions (${commissions.length})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  if (commissions.isEmpty) const Text('Aucune.', style: TextStyle(fontSize: 11)),
                  ...commissions.map((c) {
                    final cm = c as Map;
                    return Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Expanded(child: Text('${cm['commission_amount']} ${cm['currency'] ?? 'XOF'} — ${cm['status']}', style: const TextStyle(fontSize: 11))),
                          if (cm['status'] == 'pending') ...[
                            TextButton(
                              onPressed: () async {
                                final ok = await usersP.updateReferralCommissionStatus(commissionId: cm['id'].toString(), newStatus: 'paid');
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Payée.' : (usersP.error ?? 'Erreur'))));
                                if (ok) Navigator.of(d).pop();
                              },
                              child: const Text('Payer', style: TextStyle(fontSize: 10)),
                            ),
                            TextButton(
                              onPressed: () async {
                                final ok = await usersP.updateReferralCommissionStatus(commissionId: cm['id'].toString(), newStatus: 'rejected');
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Rejetée.' : (usersP.error ?? 'Erreur'))));
                                if (ok) Navigator.of(d).pop();
                              },
                              child: const Text('Rejeter', style: TextStyle(fontSize: 10, color: Colors.red)),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
      actions: [TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Fermer'))],
    ),
  );
}

Widget _createAccountCard({
  required String title,
  required List<Widget> fields,
  required VoidCallback? onSubmit,
  required bool isLoading,
  required String buttonLabel,
}) {
  return Card(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...fields,
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: isLoading ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1EA75C),
                foregroundColor: Colors.white,
              ),
              child: isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(buttonLabel, style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════
// TAB 1: TOUS
// ════════════════════════════════════════════════════════════════════
class _AllUsersTab extends StatelessWidget {
  const _AllUsersTab();

  @override
  Widget build(BuildContext context) {
    return Consumer2<AdminUsersOverviewProvider, AdminUserInvitationsProvider>(
      builder: (context, usersP, invP, _) {
        final users = usersP.users;
        return RefreshIndicator(
          onRefresh: () async {
            await Future.wait([usersP.loadUsers(), usersP.loadDeletedUsers(), invP.loadInvitations()]);
          },
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${users.length} comptes', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: () => usersP.refresh()),
                ],
              ),
              if (usersP.isLoading && users.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2)))
              else
                ...users.map((u) => _userTile(
                      context: context,
                      user: u,
                      usersP: usersP,
                      showRole: true,
                      extraActions: _allTabExtraActions(context, u, usersP),
                    )),
              const SizedBox(height: 16),
              // Invitations
              _InvitationsSection(invP: invP),
              const SizedBox(height: 16),
              // Deleted
              _DeletedUsersSection(usersP: usersP),
              const SizedBox(height: 16),
              // Create admin
              _CreateAdminForm(),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _allTabExtraActions(BuildContext context, Map<String, dynamic> user, AdminUsersOverviewProvider usersP) {
    final role = user['role']?.toString() ?? '';
    final isDeleted = user['is_deleted'] == true;
    final email = user['email']?.toString() ?? '';
    return [
      if (!isDeleted && role == 'student') ...[
        TextButton(
          onPressed: () async {
            final id = user['id']?.toString();
            if (id == null) return;
            final confirm = await showDialog<bool>(
              context: context,
              builder: (d) => AlertDialog(
                title: const Text('Promouvoir'),
                content: const Text('Rôle cible ?'),
                actions: [
                  TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Annuler')),
                  TextButton(
                    onPressed: () async {
                      Navigator.of(d).pop(true);
                    },
                    child: const Text('Admin'),
                  ),
                ],
              ),
            );
            if (confirm == true && context.mounted) {
              final ok = await usersP.promoteUserRole(userId: id, targetRole: 'admin');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Promu admin.' : (usersP.error ?? 'Erreur'))));
              }
            }
          },
          child: const Text('Promouvoir', style: TextStyle(fontSize: 10)),
        ),
      ],
      // Support chat
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 16),
        onSelected: (v) async {
          if (v == 'support') await _initiateSupportChat(context, email);
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'support', child: Text('Support', style: TextStyle(fontSize: 12))),
        ],
      ),
    ];
  }
}

class _InvitationsSection extends StatelessWidget {
  final AdminUserInvitationsProvider invP;
  const _InvitationsSection({required this.invP});

  @override
  Widget build(BuildContext context) {
    final invitations = invP.invitations;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invitations (${invitations.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (invitations.isEmpty)
              const Text('Aucune invitation.', style: TextStyle(fontSize: 12, color: Colors.grey))
            else
              ...invitations.map((inv) {
                final email = inv['email']?.toString() ?? '';
                final role = inv['role']?.toString() ?? '';
                final status = inv['status']?.toString() ?? '';
                final token = inv['token']?.toString() ?? '';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text('$email ($role)', style: const TextStyle(fontSize: 12)),
                  subtitle: Text('Statut : $status${token.isNotEmpty ? ' — Code : $token' : ''}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  trailing: token.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.copy, size: 14),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: token));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copié.')));
                          },
                        )
                      : null,
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _DeletedUsersSection extends StatelessWidget {
  final AdminUsersOverviewProvider usersP;
  const _DeletedUsersSection({required this.usersP});

  @override
  Widget build(BuildContext context) {
    final deleted = usersP.deletedUsers;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Supprimés (${deleted.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                IconButton(icon: const Icon(Icons.refresh, size: 16), onPressed: () => usersP.loadDeletedUsers()),
              ],
            ),
            if (deleted.isEmpty)
              const Text('Aucun.', style: TextStyle(fontSize: 12, color: Colors.grey))
            else
              ...deleted.map((du) {
                final email = du['email']?.toString() ?? '';
                final role = du['role']?.toString() ?? '';
                final deletedAt = du['deleted_at']?.toString() ?? '';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(email, style: const TextStyle(fontSize: 12)),
                  subtitle: Text('$role — ${_fmtDate(deletedAt)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _CreateAdminForm extends StatefulWidget {
  @override
  State<_CreateAdminForm> createState() => _CreateAdminFormState();
}

class _CreateAdminFormState extends State<_CreateAdminForm> {
  final _emailC = TextEditingController();
  final _passwordC = TextEditingController();
  final _nameC = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _emailC.dispose();
    _passwordC.dispose();
    _nameC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _createAccountCard(
      title: 'Créer un compte administrateur',
      fields: [
        TextField(controller: _emailC, decoration: const InputDecoration(labelText: 'Email', isDense: true), keyboardType: TextInputType.emailAddress, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        TextField(controller: _nameC, decoration: const InputDecoration(labelText: 'Nom complet (optionnel)', isDense: true), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        TextField(controller: _passwordC, decoration: const InputDecoration(labelText: 'Mot de passe temporaire', isDense: true), obscureText: true, style: const TextStyle(fontSize: 13)),
      ],
      isLoading: _creating,
      buttonLabel: 'Créer admin',
      onSubmit: () async {
        if (_emailC.text.trim().isEmpty || _passwordC.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email et mot de passe requis.')));
          return;
        }
        setState(() => _creating = true);
        final invP = context.read<AdminUserInvitationsProvider>();
        final resp = await invP.createAdminAccountDirect(email: _emailC.text.trim(), password: _passwordC.text, fullName: _nameC.text.trim().isEmpty ? null : _nameC.text.trim());
        if (mounted) setState(() => _creating = false);
        if (!mounted) return;
        if (resp != null) {
          _emailC.clear(); _passwordC.clear(); _nameC.clear();
          context.read<AdminUsersOverviewProvider>().loadUsers();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compte admin créé.')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(invP.error ?? 'Erreur')));
        }
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// TAB 2: ÉTUDIANTS
// ════════════════════════════════════════════════════════════════════
class _StudentsTab extends StatelessWidget {
  const _StudentsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminUsersOverviewProvider>(
      builder: (context, usersP, _) {
        final students = usersP.users.where((u) => u['role']?.toString() == 'student').toList();
        return RefreshIndicator(
          onRefresh: () => usersP.loadUsers(),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text('${students.length} étudiants', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (usersP.isLoading && students.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2)))
              else if (students.isEmpty)
                const Padding(padding: EdgeInsets.all(24), child: Text('Aucun étudiant.', style: TextStyle(color: Colors.grey)))
              else
                ...students.map((u) => _userTile(
                      context: context,
                      user: u,
                      usersP: usersP,
                      showRole: false,
                      extraActions: [
                        TextButton(
                          onPressed: () async {
                            final id = u['id']?.toString();
                            if (id == null) return;
                            await usersP.promoteUserRole(userId: id, targetRole: 'commercial');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Promu commercial.')));
                            }
                          },
                          child: const Text('→ Commercial', style: TextStyle(fontSize: 9)),
                        ),
                        TextButton(
                          onPressed: () async {
                            final id = u['id']?.toString();
                            if (id == null) return;
                            await usersP.promoteUserRole(userId: id, targetRole: 'merchant');
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Promu marchand.')));
                          },
                          child: const Text('→ Marchand', style: TextStyle(fontSize: 9)),
                        ),
                        TextButton(
                          onPressed: () async {
                            final id = u['id']?.toString();
                            if (id == null) return;
                            final name = await showDialog<String>(
                              context: context,
                              builder: (d) {
                                final c = TextEditingController();
                                return AlertDialog(
                                  title: const Text('Nom de l\'université'),
                                  content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Nom')),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Annuler')),
                                    TextButton(onPressed: () => Navigator.of(d).pop(c.text.trim()), child: const Text('Valider')),
                                  ],
                                );
                              },
                            );
                            if (name == null || name.isEmpty || !context.mounted) return;
                            await usersP.promoteUserRole(userId: id, targetRole: 'university', universityName: name);
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Promu université.')));
                          },
                          child: const Text('→ Université', style: TextStyle(fontSize: 9)),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 14),
                          onSelected: (v) async {
                            if (v == 'support') await _initiateSupportChat(context, u['email']?.toString() ?? '');
                          },
                          itemBuilder: (_) => [const PopupMenuItem(value: 'support', child: Text('Support', style: TextStyle(fontSize: 12)))],
                        ),
                      ],
                    )),
              const SizedBox(height: 16),
              // Note: Students self-register, no admin creation form needed — but user asked for one
              _CreateStudentForm(),
            ],
          ),
        );
      },
    );
  }
}

class _CreateStudentForm extends StatefulWidget {
  @override
  State<_CreateStudentForm> createState() => _CreateStudentFormState();
}

class _CreateStudentFormState extends State<_CreateStudentForm> {
  final _emailC = TextEditingController();
  final _passwordC = TextEditingController();
  final _nameC = TextEditingController();
  bool _creating = false;

  @override
  void dispose() { _emailC.dispose(); _passwordC.dispose(); _nameC.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return _createAccountCard(
      title: 'Créer un compte étudiant',
      fields: [
        TextField(controller: _emailC, decoration: const InputDecoration(labelText: 'Email', isDense: true), keyboardType: TextInputType.emailAddress, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        TextField(controller: _nameC, decoration: const InputDecoration(labelText: 'Nom complet (optionnel)', isDense: true), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        TextField(controller: _passwordC, decoration: const InputDecoration(labelText: 'Mot de passe temporaire', isDense: true), obscureText: true, style: const TextStyle(fontSize: 13)),
      ],
      isLoading: _creating,
      buttonLabel: 'Créer étudiant',
      onSubmit: () async {
        if (_emailC.text.trim().isEmpty || _passwordC.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email et mot de passe requis.')));
          return;
        }
        setState(() => _creating = true);
        final invP = context.read<AdminUserInvitationsProvider>();
        // Use invitation system with role 'student' — creates account via Edge Function
        final resp = await invP.createInvitation(email: _emailC.text.trim(), role: 'student', fullName: _nameC.text.trim().isEmpty ? null : _nameC.text.trim());
        if (mounted) setState(() => _creating = false);
        if (!mounted) return;
        if (resp != null) {
          _emailC.clear(); _passwordC.clear(); _nameC.clear();
          context.read<AdminUsersOverviewProvider>().loadUsers();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invitation étudiant créée.')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(invP.error ?? 'Erreur')));
        }
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// TAB 3: COMMERCIAUX
// ════════════════════════════════════════════════════════════════════
class _CommercialsTab extends StatelessWidget {
  const _CommercialsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminUsersOverviewProvider>(
      builder: (context, usersP, _) {
        final commercials = usersP.users.where((u) => u['role']?.toString() == 'commercial').toList();
        final overview = usersP.commercialsOverview ?? [];
        int totalStudents = 0;
        num totalPending = 0, totalPaid = 0;
        for (final item in overview) {
          totalStudents += (item['students_count'] as num? ?? 0).toInt();
          totalPending += (item['total_commission_pending'] as num?) ?? 0;
          totalPaid += (item['total_commission_paid'] as num?) ?? 0;
        }

        return RefreshIndicator(
          onRefresh: () async {
            await usersP.loadUsers();
            await usersP.loadCommercialsOverview();
            await usersP.loadMilestoneClaims();
          },
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // KPI header
              Text('${commercials.length} commerciaux', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              if (overview.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Text(
                    'Étudiants référés : $totalStudents  •  En attente : $totalPending  •  Payées : $totalPaid',
                    style: const TextStyle(fontSize: 11, color: Colors.black87),
                  ),
                ),
              // List
              ...commercials.map((u) {
                final userId = u['id']?.toString() ?? '';
                final ov = overview.firstWhere((o) => o['user_id']?.toString() == userId, orElse: () => <String, dynamic>{});
                final refCode = ov['ref_code']?.toString() ?? '';
                final refLink = ov['ref_link']?.toString() ?? '';
                final perRate = ov['commission_rate'] as num?;
                final perStudents = (ov['students_count'] as num?) ?? 0;
                final perPending = (ov['total_commission_pending'] as num?) ?? 0;
                final perPaid = (ov['total_commission_paid'] as num?) ?? 0;
                final tier = (ov['tier'] ?? '').toString();
                final tierLabel = {'bronze': '🥉', 'silver': '🥈', 'gold': '🥇', 'diamond': '💎'}[tier] ?? '';

                return _userTile(
                  context: context,
                  user: u,
                  usersP: usersP,
                  showRole: false,
                  extraActions: [
                    if (refCode.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('$tierLabel Code: $refCode  Réf: ${perStudents.toInt()}  Att: $perPending  Payé: $perPaid', style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280))),
                      ),
                    if (refLink.isNotEmpty)
                      TextButton(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: refLink));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lien copié.')));
                        },
                        child: const Text('Copier lien', style: TextStyle(fontSize: 9)),
                      ),
                    TextButton(
                      onPressed: () => _showCommercialDetail(context, usersP, userId),
                      child: const Text('Détail', style: TextStyle(fontSize: 9)),
                    ),
                    TextButton(
                      onPressed: () async {
                        final ctrl = TextEditingController(text: perRate?.toString() ?? '');
                        await showDialog<void>(
                          context: context,
                          builder: (d) => AlertDialog(
                            title: const Text('Taux de commission'),
                            content: TextField(controller: ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Taux (%)')),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Annuler')),
                              TextButton(
                                onPressed: () async {
                                  final parsed = double.tryParse(ctrl.text.replaceAll(',', '.'));
                                  if (parsed == null) return;
                                  final ok = await usersP.updateCommercialCommissionRate(userId: userId, rate: parsed);
                                  if (!d.mounted) return;
                                  Navigator.of(d).pop();
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Taux mis à jour.' : (usersP.error ?? 'Erreur'))));
                                },
                                child: const Text('Enregistrer'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const Text('Taux', style: TextStyle(fontSize: 9)),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 16),
              // Milestone claims
              _MilestoneClaimsSection(usersP: usersP),
              const SizedBox(height: 16),
              // Create commercial
              _CreateCommercialForm(),
            ],
          ),
        );
      },
    );
  }
}

class _MilestoneClaimsSection extends StatelessWidget {
  final AdminUsersOverviewProvider usersP;
  const _MilestoneClaimsSection({required this.usersP});

  @override
  Widget build(BuildContext context) {
    final claims = usersP.milestoneClaims;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Bonus palier (${claims.length})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                IconButton(icon: const Icon(Icons.refresh, size: 16), onPressed: () => usersP.loadMilestoneClaims()),
              ],
            ),
            if (claims.isEmpty)
              const Text('Aucun bonus en attente.', style: TextStyle(fontSize: 11, color: Colors.grey))
            else
              ...claims.map((c) {
                final claimId = c['claim_id']?.toString() ?? '';
                final name = c['commercial_name']?.toString() ?? c['commercial_email']?.toString() ?? '';
                final label = c['milestone_label']?.toString() ?? '';
                final bonus = c['bonus_amount'];
                final currency = c['currency']?.toString() ?? 'XOF';
                final status = c['status']?.toString() ?? '';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text('$name — $label $bonus $currency', style: const TextStyle(fontSize: 11)),
                  trailing: status == 'pending'
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () async {
                                final ok = await usersP.updateMilestoneClaimStatus(claimId: claimId, newStatus: 'paid');
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Payé.' : 'Erreur')));
                              },
                              child: const Text('Payer', style: TextStyle(fontSize: 10, color: Color(0xFF16A34A))),
                            ),
                            TextButton(
                              onPressed: () async {
                                final ok = await usersP.updateMilestoneClaimStatus(claimId: claimId, newStatus: 'rejected');
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Rejeté.' : 'Erreur')));
                              },
                              child: const Text('Rejeter', style: TextStyle(fontSize: 10, color: Colors.red)),
                            ),
                          ],
                        )
                      : Text(status, style: TextStyle(fontSize: 10, color: status == 'paid' ? const Color(0xFF16A34A) : Colors.red)),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _CreateCommercialForm extends StatefulWidget {
  @override
  State<_CreateCommercialForm> createState() => _CreateCommercialFormState();
}

class _CreateCommercialFormState extends State<_CreateCommercialForm> {
  final _emailC = TextEditingController();
  final _passwordC = TextEditingController();
  final _nameC = TextEditingController();
  final _rateC = TextEditingController();
  bool _creating = false;

  @override
  void dispose() { _emailC.dispose(); _passwordC.dispose(); _nameC.dispose(); _rateC.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return _createAccountCard(
      title: 'Créer un compte commercial',
      fields: [
        TextField(controller: _emailC, decoration: const InputDecoration(labelText: 'Email', isDense: true), keyboardType: TextInputType.emailAddress, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        TextField(controller: _nameC, decoration: const InputDecoration(labelText: 'Nom complet (optionnel)', isDense: true), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        TextField(controller: _rateC, decoration: const InputDecoration(labelText: 'Taux commission % (optionnel)', isDense: true), keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))], style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        TextField(controller: _passwordC, decoration: const InputDecoration(labelText: 'Mot de passe temporaire', isDense: true), obscureText: true, style: const TextStyle(fontSize: 13)),
      ],
      isLoading: _creating,
      buttonLabel: 'Créer commercial',
      onSubmit: () async {
        if (_emailC.text.trim().isEmpty || _passwordC.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email et mot de passe requis.')));
          return;
        }
        double? rate;
        if (_rateC.text.trim().isNotEmpty) {
          rate = double.tryParse(_rateC.text.trim().replaceAll(',', '.'));
        }
        setState(() => _creating = true);
        final invP = context.read<AdminUserInvitationsProvider>();
        final resp = await invP.createCommercialAccountDirect(email: _emailC.text.trim(), password: _passwordC.text, fullName: _nameC.text.trim().isEmpty ? null : _nameC.text.trim(), commissionRate: rate);
        if (mounted) setState(() => _creating = false);
        if (!mounted) return;
        if (resp != null) {
          _emailC.clear(); _passwordC.clear(); _nameC.clear(); _rateC.clear();
          context.read<AdminUsersOverviewProvider>().loadUsers();
          context.read<AdminUsersOverviewProvider>().loadCommercialsOverview();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compte commercial créé.')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(invP.error ?? 'Erreur')));
        }
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// TAB 4: ENSEIGNANTS
// ════════════════════════════════════════════════════════════════════
class _InstructorsTab extends StatelessWidget {
  const _InstructorsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminUsersOverviewProvider>(
      builder: (context, usersP, _) {
        final instructors = usersP.users.where((u) => u['role']?.toString() == 'instructor').toList();
        return RefreshIndicator(
          onRefresh: () => usersP.loadUsers(),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text('${instructors.length} enseignants', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (instructors.isEmpty)
                const Padding(padding: EdgeInsets.all(24), child: Text('Aucun enseignant.', style: TextStyle(color: Colors.grey)))
              else
                ...instructors.map((u) => _userTile(context: context, user: u, usersP: usersP, showRole: false)),
              const SizedBox(height: 16),
              _CreateTeacherForm(),
            ],
          ),
        );
      },
    );
  }
}

class _CreateTeacherForm extends StatefulWidget {
  @override
  State<_CreateTeacherForm> createState() => _CreateTeacherFormState();
}

class _CreateTeacherFormState extends State<_CreateTeacherForm> {
  final _emailC = TextEditingController();
  final _passwordC = TextEditingController();
  final _nameC = TextEditingController();
  final _disciplineC = TextEditingController();
  final _zoneC = TextEditingController();
  final _availC = TextEditingController();
  bool _creating = false;

  @override
  void dispose() { _emailC.dispose(); _passwordC.dispose(); _nameC.dispose(); _disciplineC.dispose(); _zoneC.dispose(); _availC.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return _createAccountCard(
      title: 'Créer un compte enseignant TD',
      fields: [
        TextField(controller: _emailC, decoration: const InputDecoration(labelText: 'Email', isDense: true), keyboardType: TextInputType.emailAddress, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        TextField(controller: _nameC, decoration: const InputDecoration(labelText: 'Nom complet (optionnel)', isDense: true), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        TextField(controller: _passwordC, decoration: const InputDecoration(labelText: 'Mot de passe temporaire', isDense: true), obscureText: true, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        TextField(controller: _disciplineC, decoration: const InputDecoration(labelText: 'Discipline TD', isDense: true), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        TextField(controller: _zoneC, decoration: const InputDecoration(labelText: 'Zone géographique', isDense: true), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        TextField(controller: _availC, decoration: const InputDecoration(labelText: 'Disponibilité', isDense: true), style: const TextStyle(fontSize: 13)),
      ],
      isLoading: _creating,
      buttonLabel: 'Créer enseignant',
      onSubmit: () async {
        if (_emailC.text.trim().isEmpty || _passwordC.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email et mot de passe requis.')));
          return;
        }
        setState(() => _creating = true);
        final invP = context.read<AdminUserInvitationsProvider>();
        final teacherAccount = await invP.createTeacherAccountDirect(email: _emailC.text.trim().toLowerCase(), password: _passwordC.text, fullName: _nameC.text.trim().isEmpty ? null : _nameC.text.trim());
        if (!mounted) return;
        if (teacherAccount == null || teacherAccount['success'] != true) {
          setState(() => _creating = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(invP.error ?? 'Erreur')));
          return;
        }
        final userId = teacherAccount['user_id']?.toString() ?? '';
        if (userId.isNotEmpty) {
          final tdP = context.read<AdminTdTeachersProvider>();
          await tdP.createTeacher(
            userId: userId,
            fullName: _nameC.text.trim().isEmpty ? _emailC.text.trim() : _nameC.text.trim(),
            discipline: _disciplineC.text.trim().isEmpty ? null : _disciplineC.text.trim(),
            zone: _zoneC.text.trim().isEmpty ? null : _zoneC.text.trim(),
            availability: _availC.text.trim().isEmpty ? null : _availC.text.trim(),
          );
        }
        if (mounted) setState(() => _creating = false);
        if (!mounted) return;
        _emailC.clear(); _passwordC.clear(); _nameC.clear(); _disciplineC.clear(); _zoneC.clear(); _availC.clear();
        context.read<AdminUsersOverviewProvider>().loadUsers();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compte enseignant créé.')));
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// TAB 5: UNIVERSITÉS
// ════════════════════════════════════════════════════════════════════
class _UniversitiesTab extends StatelessWidget {
  const _UniversitiesTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminUsersOverviewProvider>(
      builder: (context, usersP, _) {
        final unis = usersP.users.where((u) => u['role']?.toString() == 'university').toList();
        return RefreshIndicator(
          onRefresh: () => usersP.loadUsers(),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text('${unis.length} universités', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (unis.isEmpty)
                const Padding(padding: EdgeInsets.all(24), child: Text('Aucune université.', style: TextStyle(color: Colors.grey)))
              else
                ...unis.map((u) => _userTile(context: context, user: u, usersP: usersP, showRole: false)),
              const SizedBox(height: 16),
              _CreateUniversityForm(),
            ],
          ),
        );
      },
    );
  }
}

class _CreateUniversityForm extends StatefulWidget {
  @override
  State<_CreateUniversityForm> createState() => _CreateUniversityFormState();
}

class _CreateUniversityFormState extends State<_CreateUniversityForm> {
  final _emailC = TextEditingController();
  final _passwordC = TextEditingController();
  final _nameC = TextEditingController();
  bool _creating = false;

  @override
  void dispose() { _emailC.dispose(); _passwordC.dispose(); _nameC.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return _createAccountCard(
      title: 'Créer un compte université',
      fields: [
        TextField(controller: _emailC, decoration: const InputDecoration(labelText: 'Email', isDense: true), keyboardType: TextInputType.emailAddress, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        TextField(controller: _nameC, decoration: const InputDecoration(labelText: 'Nom de l\'université', isDense: true), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        TextField(controller: _passwordC, decoration: const InputDecoration(labelText: 'Mot de passe temporaire', isDense: true), obscureText: true, style: const TextStyle(fontSize: 13)),
      ],
      isLoading: _creating,
      buttonLabel: 'Créer université',
      onSubmit: () async {
        if (_emailC.text.trim().isEmpty || _passwordC.text.isEmpty || _nameC.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email, nom et mot de passe requis.')));
          return;
        }
        setState(() => _creating = true);
        final invP = context.read<AdminUserInvitationsProvider>();
        final resp = await invP.createUniversityAccountDirect(email: _emailC.text.trim(), password: _passwordC.text, universityName: _nameC.text.trim());
        if (mounted) setState(() => _creating = false);
        if (!mounted) return;
        if (resp != null) {
          _emailC.clear(); _passwordC.clear(); _nameC.clear();
          context.read<AdminUsersOverviewProvider>().loadUsers();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compte université créé.')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(invP.error ?? 'Erreur')));
        }
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// TAB 6: MARCHANDS
// ════════════════════════════════════════════════════════════════════
class _MerchantsTab extends StatelessWidget {
  const _MerchantsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminUsersOverviewProvider>(
      builder: (context, usersP, _) {
        final merchants = usersP.users.where((u) => u['role']?.toString() == 'merchant').toList();
        return RefreshIndicator(
          onRefresh: () => usersP.loadUsers(),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text('${merchants.length} marchands', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (merchants.isEmpty)
                const Padding(padding: EdgeInsets.all(24), child: Text('Aucun marchand.', style: TextStyle(color: Colors.grey)))
              else
                ...merchants.map((u) => _userTile(context: context, user: u, usersP: usersP, showRole: false)),
              const SizedBox(height: 16),
              _CreateMerchantForm(),
            ],
          ),
        );
      },
    );
  }
}

class _CreateMerchantForm extends StatefulWidget {
  @override
  State<_CreateMerchantForm> createState() => _CreateMerchantFormState();
}

class _CreateMerchantFormState extends State<_CreateMerchantForm> {
  final _emailC = TextEditingController();
  final _passwordC = TextEditingController();
  final _nameC = TextEditingController();
  final _countryC = TextEditingController();
  final _cityC = TextEditingController();
  bool _creating = false;

  @override
  void dispose() { _emailC.dispose(); _passwordC.dispose(); _nameC.dispose(); _countryC.dispose(); _cityC.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return _createAccountCard(
      title: 'Créer un compte marchand',
      fields: [
        TextField(controller: _emailC, decoration: const InputDecoration(labelText: 'Email', isDense: true), keyboardType: TextInputType.emailAddress, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        TextField(controller: _nameC, decoration: const InputDecoration(labelText: 'Nom du marchand', isDense: true), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        TextField(controller: _passwordC, decoration: const InputDecoration(labelText: 'Mot de passe temporaire', isDense: true), obscureText: true, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: TextField(controller: _countryC, decoration: const InputDecoration(labelText: 'Pays (opt.)', isDense: true), style: const TextStyle(fontSize: 13))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _cityC, decoration: const InputDecoration(labelText: 'Ville (opt.)', isDense: true), style: const TextStyle(fontSize: 13))),
          ],
        ),
      ],
      isLoading: _creating,
      buttonLabel: 'Créer marchand',
      onSubmit: () async {
        if (_emailC.text.trim().isEmpty || _passwordC.text.isEmpty || _nameC.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email, nom et mot de passe requis.')));
          return;
        }
        setState(() => _creating = true);
        final invP = context.read<AdminUserInvitationsProvider>();
        final resp = await invP.createMerchantAccountDirect(
          email: _emailC.text.trim(),
          password: _passwordC.text,
          displayName: _nameC.text.trim(),
          country: _countryC.text.trim().isEmpty ? null : _countryC.text.trim(),
          city: _cityC.text.trim().isEmpty ? null : _cityC.text.trim(),
        );
        if (mounted) setState(() => _creating = false);
        if (!mounted) return;
        if (resp != null) {
          _emailC.clear(); _passwordC.clear(); _nameC.clear(); _countryC.clear(); _cityC.clear();
          context.read<AdminUsersOverviewProvider>().loadUsers();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compte marchand créé.')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(invP.error ?? 'Erreur')));
        }
      },
    );
  }
}
