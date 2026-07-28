import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/admin_user_invitations_provider.dart';
import '../../providers/admin_universities_provider.dart';
import '../../providers/admin_users_overview_provider.dart';
import '../../providers/admin_td_teachers_provider.dart';
import '../../providers/admin_support_provider.dart';
import '../../utils/responsive.dart';
import '../../widgets/adaptive_dialog.dart';
import 'admin_support_chat_screen.dart';
import '../orientation/orientation_theme.dart';

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
    _tabCtrl = TabController(length: 7, vsync: this);
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
        final nCounselors = counts['orientation_counselor'] ?? 0;

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
                  Tab(text: 'Conseillers ($nCounselors)'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: const [
                  _MaxWidth(child: _AllUsersTab()),
                  _MaxWidth(child: _StudentsTab()),
                  _MaxWidth(child: _CommercialsTab()),
                  _MaxWidth(child: _InstructorsTab()),
                  _MaxWidth(child: _UniversitiesTab()),
                  _MaxWidth(child: _MerchantsTab()),
                  _MaxWidth(child: _OrientationCounselorsTab()),
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

/// Sur téléphone : occupe toute la largeur.
/// Sur ordinateur / tablette large : centre le contenu et plafonne la
/// largeur de lecture pour éviter des lignes interminables.
class _MaxWidth extends StatelessWidget {
  const _MaxWidth({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= AppBreakpoints.tablet) return child;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppBreakpoints.tablet),
            child: child,
          ),
        );
      },
    );
  }
}

String _fmtDate(String iso) {
  try {
    final dt = DateTime.parse(iso);
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return iso;
  }
}

/// Affiche un texte long non sécable (email, code, lien) sans jamais le
/// laisser se réduire à une colonne d'une lettre par ligne.
///
/// C'était le défaut de l'ancienne mise en page : le bloc d'actions occupait
/// la quasi-totalité de la largeur sur téléphone, il ne restait que quelques
/// points pour l'email, et Flutter le coupait caractère par caractère.
/// Ici le texte reçoit toujours la largeur complète de la carte.
class _SelectableValue extends StatelessWidget {
  const _SelectableValue(
    this.value, {
    this.style,
    this.copyLabel,
  });

  final String value;
  final TextStyle? style;
  final String? copyLabel;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onLongPress: () async {
          await Clipboard.setData(ClipboardData(text: value));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${copyLabel ?? 'Valeur'} copié(e).')),
          );
        },
        child: Text(
          value,
          style: style,
          softWrap: true,
          // Sur les toutes petites largeurs on préfère couper proprement
          // plutôt que d'empiler les caractères.
          overflow: TextOverflow.visible,
        ),
      ),
    );
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

  final actions = <Widget>[
    // Suspendre / Réactiver
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
      child: Text(isSuspended ? 'Réactiver' : 'Suspendre', style: const TextStyle(fontSize: 11)),
    ),
    // Supprimer
    if (!isDeleted)
      TextButton(
        onPressed: usersP.isUpdating
            ? null
            : () async {
                final id = user['id']?.toString();
                if (id == null) return;
                final confirm = await _confirmDialog(
                  context: context,
                  title: 'Supprimer le compte',
                  message: 'Ce compte sera supprimé. Continuer ?',
                  confirmLabel: 'Supprimer',
                  destructive: true,
                );
                if (confirm != true || !context.mounted) return;
                final ok = await usersP.hardDeleteUserAccount(userId: id);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? 'Supprimé.' : (usersP.error ?? 'Erreur'))),
                );
              },
        child: const Text('Supprimer', style: TextStyle(fontSize: 11)),
      ),
    // Historique
    TextButton(
      onPressed: () => _showHistory(context, usersP, user['id']?.toString() ?? ''),
      child: const Text('Historique', style: TextStyle(fontSize: 11)),
    ),
    ...extraActions,
  ];

  // Carte fluide : le bloc d'identité occupe toute la largeur disponible,
  // les actions passent en dessous et se replient sur plusieurs lignes.
  // Plus aucune largeur figée, donc plus d'email écrit à la verticale.
  return LayoutBuilder(
    builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 620;

      final identity = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5, right: 8),
                child: Icon(Icons.circle,
                    size: 10,
                    color: isOnline ? const Color(0xFF16A34A) : Colors.grey),
              ),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                  softWrap: true,
                ),
              ),
            ],
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 2),
            _SelectableValue(
              email,
              copyLabel: 'Email',
              style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
            ),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (showRole) _metaChip('Rôle : ${role.isEmpty ? '–' : role}'),
              _metaChip(
                isDeleted
                    ? 'Supprimé'
                    : (isSuspended ? 'Suspendu' : 'Actif'),
                color: (isDeleted || isSuspended)
                    ? Colors.red
                    : const Color(0xFF16A34A),
              ),
              _metaChip(
                isOnline ? 'En ligne' : 'Hors ligne',
                color: isOnline ? const Color(0xFF16A34A) : Colors.grey,
              ),
              if (createdAt.isNotEmpty) _metaChip('Créé : ${_fmtDate(createdAt)}'),
              if (lastActivity.isNotEmpty)
                _metaChip('Activité : ${_fmtDate(lastActivity)}'),
            ],
          ),
          if (isSuspended && suspendedReason != null && suspendedReason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Raison : $suspendedReason',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
          if (isDeleted && deletedReason != null && deletedReason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Raison : $deletedReason',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ],
      );

      final actionBar = Wrap(
        spacing: 4,
        runSpacing: 0,
        alignment: isNarrow ? WrapAlignment.start : WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: actions,
      );

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: isNarrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  identity,
                  const SizedBox(height: 4),
                  actionBar,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 12),
                  // Le bloc d'actions ne peut plus dépasser 45 % de la carte :
                  // le bloc identité garde toujours de quoi s'afficher.
                  ConstrainedBox(
                    constraints:
                        BoxConstraints(maxWidth: constraints.maxWidth * 0.45),
                    child: actionBar,
                  ),
                ],
              ),
      );
    },
  );
}

Widget _metaChip(String label, {Color? color}) {
  final c = color ?? const Color(0xFF6B7280);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10.5, color: c, fontWeight: FontWeight.w500),
    ),
  );
}

/// Confirmation compacte et adaptative (boutons jamais coupés).
Future<bool?> _confirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirmer',
  String cancelLabel = 'Annuler',
  bool destructive = false,
}) {
  return showDialog<bool>(
    context: context,
    useSafeArea: true,
    builder: (d) => AdaptiveDialog(
      maxWidth: 420,
      title: Text(title),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(d).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: Colors.red)
              : null,
          onPressed: () => Navigator.of(d).pop(true),
          child: Text(confirmLabel),
        ),
      ],
      child: Text(message),
    ),
  );
}

Future<void> _showHistory(BuildContext context, AdminUsersOverviewProvider usersP, String userId) async {
  await showDialog<void>(
    context: context,
    useSafeArea: true,
    builder: (d) => AdaptiveDialog(
      title: const Text('Historique des actions'),
      actions: [TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Fermer'))],
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: usersP.fetchUserActionLogs(userId),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final logs = snap.data ?? [];
          if (logs.isEmpty) return const Text('Aucune action enregistrée.', style: TextStyle(fontSize: 13));
          // Plus de hauteur figée : le contenu s'inscrit dans la zone
          // scrollable de la boîte, qui s'adapte à l'écran.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: logs.map((l) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${l['action']}',
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600)),
                    Text(
                      '${l['reason'] ?? ''} — ${_fmtDate(l['created_at']?.toString() ?? '')}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
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
    useSafeArea: true,
    builder: (d) => AdaptiveDialog(
      title: const Text('Détail commercial'),
      actions: [TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Fermer'))],
      child: FutureBuilder<Map<String, dynamic>?>(
        future: usersP.fetchCommercialDetail(userId),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final data = snap.data;
          if (data == null) return const Text('Aucune donnée.', style: TextStyle(fontSize: 13));
          final commercial = (data['commercial'] as Map?) ?? {};
          final referrals = (data['referrals'] as List?) ?? [];
          final commissions = (data['commissions'] as List?) ?? [];
          // Plus de SizedBox 360 de haut : la boîte adaptative gère la
          // hauteur et le défilement selon l'écran réel.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _SelectableValue(
                '${commercial['email'] ?? ''}',
                copyLabel: 'Email',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              _SelectableValue(
                'Code : ${commercial['ref_code'] ?? ''}',
                copyLabel: 'Code',
                style: const TextStyle(fontSize: 12),
              ),
              if (commercial['commission_rate'] != null)
                Text('Taux : ${commercial['commission_rate']}%', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              Text('Étudiants référés (${referrals.length})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              if (referrals.isEmpty) const Text('Aucun.', style: TextStyle(fontSize: 11)),
              ...referrals.map((r) {
                final ref = r as Map;
                return Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _SelectableValue(
                    '${ref['student_id']} — ${ref['attributed_at'] ?? ''}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                );
              }),
              const SizedBox(height: 12),
              Text('Commissions (${commissions.length})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              if (commissions.isEmpty) const Text('Aucune.', style: TextStyle(fontSize: 11)),
              ...commissions.map((c) {
                final cm = c as Map;
                final pending = cm['status'] == 'pending';
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${cm['commission_amount']} ${cm['currency'] ?? 'XOF'} — ${cm['status']}',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      if (pending)
                        // Wrap : sur téléphone les deux boutons passent à la
                        // ligne au lieu d'écraser le montant.
                        Wrap(
                          spacing: 4,
                          children: [
                            TextButton(
                              onPressed: () async {
                                final ok = await usersP.updateReferralCommissionStatus(commissionId: cm['id'].toString(), newStatus: 'paid');
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Payée.' : (usersP.error ?? 'Erreur'))));
                                if (ok && d.mounted) Navigator.of(d).pop();
                              },
                              child: const Text('Payer', style: TextStyle(fontSize: 11)),
                            ),
                            TextButton(
                              onPressed: () async {
                                final ok = await usersP.updateReferralCommissionStatus(commissionId: cm['id'].toString(), newStatus: 'rejected');
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Rejetée.' : (usersP.error ?? 'Erreur'))));
                                if (ok && d.mounted) Navigator.of(d).pop();
                              },
                              child: const Text('Rejeter', style: TextStyle(fontSize: 11, color: Colors.red)),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
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
              useSafeArea: true,
              builder: (d) => AdaptiveDialog(
                maxWidth: 420,
                title: const Text('Promouvoir'),
                child: const Text('Rôle cible ?'),
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
                // Row + Expanded : l'email garde toute la largeur restante,
                // il ne peut plus se replier lettre par lettre.
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _SelectableValue(
                              email,
                              copyLabel: 'Email',
                              style: const TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Rôle : ${role.isEmpty ? '–' : role}  •  Statut : $status'
                              '${token.isNotEmpty ? '\nCode : $token' : ''}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      if (token.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          tooltip: 'Copier le code',
                          visualDensity: VisualDensity.compact,
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: token));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copié.')));
                          },
                        ),
                    ],
                  ),
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
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SelectableValue(
                        email,
                        copyLabel: 'Email',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      Text('$role — ${_fmtDate(deletedAt)}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
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
                                return AdaptiveDialog(
                                  maxWidth: 460,
                                  title: const Text('Nom de l\'université'),
                                  child: TextField(controller: c, autofocus: true, decoration: const InputDecoration(labelText: 'Nom')),
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
                        TextButton(
                          onPressed: () async {
                            final id = u['id']?.toString();
                            if (id == null) return;
                            final config = await showDialog<Map<String, dynamic>>(
                              context: context,
                              builder: (d) => _PromoteToCounselorDialog(
                                suggestedName:
                                    u['full_name']?.toString() ??
                                        u['email']?.toString() ??
                                        '',
                              ),
                            );
                            if (config == null || !context.mounted) return;
                            final ok = await usersP.promoteToOrientationCounselor(
                              userId: id,
                              fullName: config['full_name'] as String?,
                              kind: config['kind'] as String,
                              specialites:
                                  (config['specialites'] as List).cast<String>(),
                              langues: (config['langues'] as List).cast<String>(),
                              dureeMinutes: config['duree'] as int,
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(ok
                                  ? 'Promu conseiller d\'orientation. Ajoutez ses créneaux pour qu\'il soit réservable.'
                                  : (usersP.error ?? 'Promotion impossible.')),
                            ));
                          },
                          child: const Text('→ Conseiller',
                              style: TextStyle(fontSize: 9)),
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
                          useSafeArea: true,
                          builder: (d) => AdaptiveDialog(
                            maxWidth: 420,
                            title: const Text('Taux de commission'),
                            child: TextField(controller: ctrl, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Taux (%)')),
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
                // Le nom/email occupe toute la largeur, les actions passent
                // dessous : plus de texte compressé en colonne.
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SelectableValue(
                        '$name — $label $bonus $currency',
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (status == 'pending')
                        Wrap(
                          spacing: 4,
                          children: [
                            TextButton(
                              onPressed: () async {
                                final ok = await usersP.updateMilestoneClaimStatus(claimId: claimId, newStatus: 'paid');
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Payé.' : 'Erreur')));
                              },
                              child: const Text('Payer', style: TextStyle(fontSize: 11, color: Color(0xFF16A34A))),
                            ),
                            TextButton(
                              onPressed: () async {
                                final ok = await usersP.updateMilestoneClaimStatus(claimId: claimId, newStatus: 'rejected');
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Rejeté.' : 'Erreur')));
                              },
                              child: const Text('Rejeter', style: TextStyle(fontSize: 11, color: Colors.red)),
                            ),
                          ],
                        )
                      else
                        Text(status, style: TextStyle(fontSize: 11, color: status == 'paid' ? const Color(0xFF16A34A) : Colors.red)),
                    ],
                  ),
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

// ─── Conseillers d'orientation ────────────────────────────────────────

/// L'orientation n'est pas une matière : elle a son propre rôle, son propre
/// studio et son propre livrable. Ce panneau permet à l'administrateur de
/// créer un conseiller comme il crée un enseignant ou un marchand — le rôle
/// est ensuite reconnu automatiquement à la connexion, comme les autres.
class _OrientationCounselorsTab extends StatefulWidget {
  const _OrientationCounselorsTab();

  @override
  State<_OrientationCounselorsTab> createState() =>
      _OrientationCounselorsTabState();
}

class _OrientationCounselorsTabState extends State<_OrientationCounselorsTab> {
  List<Map<String, dynamic>> _fiches = const [];
  bool _loading = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  /// Le compte d'authentification ne dit rien de l'état métier du conseiller.
  /// On interroge donc le profil d'orientation : c'est lui qui détermine si
  /// l'élève verra ce conseiller apparaître dans sa recherche.
  Future<void> _charger() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _erreur = null;
    });
    try {
      final res = await Supabase.instance.client
          .rpc('app_admin_list_orientation_counselors');
      final liste = (res as List?) ?? const [];
      if (!mounted) return;
      setState(() {
        _fiches = liste
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _basculerActivation(Map<String, dynamic> fiche) async {
    final actif = fiche['is_active'] == true;
    final nom = fiche['full_name']?.toString() ?? 'Ce conseiller';
    final confirme = await showDialog<bool>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => AdaptiveDialog(
        maxWidth: 460,
        title: Text(actif ? 'Désactiver $nom ?' : 'Réactiver $nom ?'),
        child: Text(
          actif
              ? 'Il disparaîtra de la recherche des élèves. Ses rendez-vous '
                  'déjà pris et ses fiches sont conservés.'
              : 'Il réapparaîtra dans la recherche des élèves, à condition '
                  'qu\'il ait posé des créneaux.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(actif ? 'Désactiver' : 'Réactiver'),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    try {
      await Supabase.instance.client
          .rpc('app_admin_set_orientation_counselor_active', params: {
        'p_user_id': fiche['user_id'],
        'p_is_active': !actif,
      });
      await _charger();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(actif ? '$nom a été désactivé.' : '$nom a été réactivé.'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Échec : $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await context.read<AdminUsersOverviewProvider>().loadUsers();
        await _charger();
      },
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            Text(
              '${_fiches.length} conseiller${_fiches.length > 1 ? 's' : ''} '
              'd\'orientation',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (_erreur != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_erreur!,
                    style: const TextStyle(fontSize: 12.5, color: Colors.red)),
              ),
            if (_fiches.isEmpty && _erreur == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucun conseiller pour le moment. Créez-en un ci-dessous : '
                  'il apparaîtra dans la recherche des élèves dès qu\'il aura '
                  'posé ses créneaux depuis son propre compte.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ..._fiches.map(_carteConseiller),
          ],
          const SizedBox(height: 16),
          _CreateOrientationCounselorForm(),
        ],
      ),
    );
  }

  Widget _carteConseiller(Map<String, dynamic> f) {
    final actif = f['is_active'] == true;
    final roleOk = f['role_ok'] == true;
    final creneaux = (f['nb_creneaux'] as num?)?.toInt() ?? 0;
    final reservable = actif && roleOk && creneaux > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f['full_name']?.toString() ?? 'Sans nom',
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      f['email']?.toString() ?? '',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF5C6270)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _etiquette(
                reservable ? 'Réservable' : 'Non réservable',
                reservable ? const Color(0xFF12B886) : const Color(0xFFF0A020),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Un Wrap plutôt qu'une Row : sur un écran étroit les compteurs
          // passent à la ligne au lieu de déborder.
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _compteur('$creneaux créneau${creneaux > 1 ? 'x' : ''}'),
              _compteur('${f['nb_rdv'] ?? 0} rdv'),
              _compteur('${f['nb_rdv_a_venir'] ?? 0} à venir'),
              _compteur('${f['nb_fiches'] ?? 0} fiche(s)'),
              _compteur('${f['tarif_fcfa'] ?? 0} FCFA'),
              _compteur('${f['solde_fcfa'] ?? 0} FCFA de solde'),
              if (!roleOk) _etiquette('Rôle absent du compte', Colors.red),
              if (!actif) _etiquette('Désactivé', const Color(0xFFE14D4D)),
            ],
          ),
          if (reservable == false && roleOk && actif && creneaux == 0) ...[
            const SizedBox(height: 8),
            const Text(
              'Il doit poser ses créneaux depuis son compte pour devenir '
              'visible des élèves.',
              style: TextStyle(
                  fontSize: 12, height: 1.4, color: Color(0xFF8A6100)),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _basculerActivation(f),
              icon: Icon(actif ? Icons.block : Icons.check_circle_outline,
                  size: 17),
              label: Text(actif ? 'Désactiver' : 'Réactiver',
                  style: const TextStyle(fontSize: 12.5)),
              style: TextButton.styleFrom(
                foregroundColor:
                    actif ? const Color(0xFFE14D4D) : const Color(0xFF12B886),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compteur(String texte) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F3F6),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(texte,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF5C6270))),
      );

  Widget _etiquette(String texte, Color couleur) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          texte,
          style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w600, color: couleur),
        ),
      );
}

class _CreateOrientationCounselorForm extends StatefulWidget {
  @override
  State<_CreateOrientationCounselorForm> createState() =>
      _CreateOrientationCounselorFormState();
}

class _CreateOrientationCounselorFormState
    extends State<_CreateOrientationCounselorForm> {
  final _emailC = TextEditingController();
  final _passwordC = TextEditingController();
  final _nameC = TextEditingController();
  final _bioC = TextEditingController();
  final _tarifC = TextEditingController(text: '0');

  String _kind = 'orientation';
  int _duree = 45;
  final Set<String> _specialites = {};
  final Set<String> _langues = {'fr'};
  bool _creating = false;




  @override
  void dispose() {
    _emailC.dispose();
    _passwordC.dispose();
    _nameC.dispose();
    _bioC.dispose();
    _tarifC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _createAccountCard(
      title: 'Créer un conseiller d\'orientation',
      fields: [
        TextField(
          controller: _emailC,
          decoration: const InputDecoration(labelText: 'Email', isDense: true),
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameC,
          decoration:
              const InputDecoration(labelText: 'Nom complet', isDense: true),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordC,
          decoration: const InputDecoration(
              labelText: 'Mot de passe temporaire (8 caractères minimum)',
              isDense: true),
          obscureText: true,
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 12),
        const Text('Type de conseil',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: OrientationLabels.kinds.entries
              .map((e) => ChoiceChip(
                    label: Text(e.value, style: const TextStyle(fontSize: 12)),
                    selected: _kind == e.key,
                    onSelected: (_) => setState(() => _kind = e.key),
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),
        const Text('Spécialités',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: OrientationLabels.specialites.entries
              .map((e) => FilterChip(
                    label: Text(e.value, style: const TextStyle(fontSize: 12)),
                    selected: _specialites.contains(e.key),
                    onSelected: (v) => setState(() =>
                        v ? _specialites.add(e.key) : _specialites.remove(e.key)),
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),
        const Text('Langues parlées',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: OrientationLabels.langues.entries
              .map((e) => FilterChip(
                    label: Text(e.value, style: const TextStyle(fontSize: 12)),
                    selected: _langues.contains(e.key),
                    onSelected: (v) => setState(() {
                      v ? _langues.add(e.key) : _langues.remove(e.key);
                      if (_langues.isEmpty) _langues.add('fr');
                    }),
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tarifC,
                decoration: const InputDecoration(
                    labelText: 'Tarif (FCFA, 0 = gratuit)', isDense: true),
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _duree,
                decoration: const InputDecoration(
                    labelText: 'Durée', isDense: true),
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                items: const [30, 45, 60, 90]
                    .map((m) =>
                        DropdownMenuItem(value: m, child: Text('$m minutes')))
                    .toList(),
                onChanged: (v) => setState(() => _duree = v ?? 45),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _bioC,
          maxLines: 3,
          decoration: const InputDecoration(
              labelText: 'Présentation (visible des élèves)', isDense: true),
          style: const TextStyle(fontSize: 13),
        ),
      ],
      isLoading: _creating,
      buttonLabel: 'Créer le conseiller',
      onSubmit: () async {
        if (_emailC.text.trim().isEmpty ||
            _passwordC.text.isEmpty ||
            _nameC.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Email, nom complet et mot de passe requis.')));
          return;
        }
        setState(() => _creating = true);
        final invP = context.read<AdminUserInvitationsProvider>();
        final created = await invP.createOrientationCounselorAccount(
          email: _emailC.text.trim(),
          password: _passwordC.text,
          fullName: _nameC.text.trim(),
          kind: _kind,
          specialites: _specialites.toList(),
          langues: _langues.toList(),
          bio: _bioC.text.trim().isEmpty ? null : _bioC.text.trim(),
          tarifFcfa: int.tryParse(_tarifC.text.trim()) ?? 0,
          dureeMinutes: _duree,
        );
        if (!mounted) return;
        setState(() => _creating = false);
        if (created == null) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(invP.error ?? 'Erreur')));
          return;
        }
        _emailC.clear();
        _passwordC.clear();
        _nameC.clear();
        _bioC.clear();
        _tarifC.text = '0';
        setState(() => _specialites.clear());
        context.read<AdminUsersOverviewProvider>().loadUsers();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Conseiller créé. Ajoutez ses créneaux pour qu\'il soit réservable.'),
        ));
      },
    );
  }
}

/// Boîte de dialogue de promotion d'un compte en conseiller d'orientation.
///
/// On demande le minimum utile plutôt que rien : un conseiller sans spécialité
/// ni langue n'est trouvable par aucun filtre de recherche côté élève. Le nom
/// est pré-rempli avec celui déjà connu du compte.
class _PromoteToCounselorDialog extends StatefulWidget {
  final String suggestedName;
  const _PromoteToCounselorDialog({required this.suggestedName});

  @override
  State<_PromoteToCounselorDialog> createState() =>
      _PromoteToCounselorDialogState();
}

class _PromoteToCounselorDialogState extends State<_PromoteToCounselorDialog> {
  late final TextEditingController _nameC =
      TextEditingController(text: widget.suggestedName);
  String _kind = 'orientation';
  int _duree = 45;
  final Set<String> _specialites = {};
  final Set<String> _langues = {'fr'};




  @override
  void dispose() {
    _nameC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AdaptiveDialog : hauteur bornée à l'écran réel (clavier déduit),
    // contenu scrollable, et les boutons Annuler / Promouvoir restent
    // toujours atteignables en bas.
    return AdaptiveDialog(
      title: const Text('Promouvoir en conseiller'),
      child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Le compte gardera son historique. Il basculera vers l\'espace '
                'conseiller à sa prochaine connexion.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nameC,
                decoration: const InputDecoration(
                    labelText: 'Nom affiché aux élèves', isDense: true),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              const Text('Type de conseil',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: OrientationLabels.kinds.entries
                    .map((e) => ChoiceChip(
                          label:
                              Text(e.value, style: const TextStyle(fontSize: 11)),
                          selected: _kind == e.key,
                          onSelected: (_) => setState(() => _kind = e.key),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 14),
              const Text('Spécialités',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: OrientationLabels.specialites.entries
                    .map((e) => FilterChip(
                          label:
                              Text(e.value, style: const TextStyle(fontSize: 11)),
                          selected: _specialites.contains(e.key),
                          onSelected: (v) => setState(() => v
                              ? _specialites.add(e.key)
                              : _specialites.remove(e.key)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 14),
              const Text('Langues parlées',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: OrientationLabels.langues.entries
                    .map((e) => FilterChip(
                          label:
                              Text(e.value, style: const TextStyle(fontSize: 11)),
                          selected: _langues.contains(e.key),
                          onSelected: (v) => setState(() {
                            v ? _langues.add(e.key) : _langues.remove(e.key);
                            if (_langues.isEmpty) _langues.add('fr');
                          }),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: _duree,
                decoration: const InputDecoration(
                    labelText: 'Durée d\'une consultation', isDense: true),
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                items: const [30, 45, 60, 90]
                    .map((m) =>
                        DropdownMenuItem(value: m, child: Text('$m minutes')))
                    .toList(),
                onChanged: (v) => setState(() => _duree = v ?? 45),
              ),
            ],
          ),
        ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(<String, dynamic>{
            'full_name': _nameC.text.trim(),
            'kind': _kind,
            'specialites': _specialites.toList(),
            'langues': _langues.toList(),
            'duree': _duree,
          }),
          child: const Text('Promouvoir'),
        ),
      ],
    );
  }
}
