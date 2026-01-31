import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/commercial_dashboard_provider.dart';

/// Tableau de bord minimal pour les comptes commerciaux.
/// Logique métier limitée : l'essentiel viendra des RPC côté Supabase.
class CommercialDashboardScreen extends StatefulWidget {
  const CommercialDashboardScreen({super.key});

  @override
  State<CommercialDashboardScreen> createState() => _CommercialDashboardScreenState();
}

class _CommercialDashboardScreenState extends State<CommercialDashboardScreen> {
  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CommercialDashboardProvider>().loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommercialDashboardProvider>();
    final profile = provider.profile;
    final summary = provider.summary;

    Widget body;

    if (provider.isLoading && profile == null && summary == null) {
      body = const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (provider.error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                provider.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: provider.isLoading
                    ? null
                    : () => provider.loadDashboard(),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    } else if (profile == null || summary == null) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Aucune donnée commerciale disponible pour le moment.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      final refCode = (profile['ref_code'] ?? '').toString();
      final refLink = (profile['ref_link'] ?? '').toString();
      final studentsCount = summary['students_count'] ?? 0;
      final paymentsConfirmedCount = summary['payments_confirmed_count'] ?? 0;
      final totalPending = summary['total_commission_pending'] ?? 0;
      final totalPaid = summary['total_commission_paid'] ?? 0;
      final referrals = provider.referrals;
      final commissions = provider.commissions;

      body = SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Votre lien de parrainage',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (refCode.isNotEmpty)
                      Text(
                        'Code : $refCode',
                        style: const TextStyle(fontSize: 14),
                      ),
                    if (refLink.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      SelectableText(
                        refLink,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: refLink));
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Lien de parrainage copié.'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copier le lien'),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              _showShareReferralDialog(context, refLink);
                            },
                            icon: const Icon(Icons.share, size: 16),
                            label: const Text('Partager'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Résumé des performances',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Étudiants référés'),
                              const SizedBox(height: 4),
                              Text(
                                studentsCount.toString(),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Paiements confirmés'),
                              const SizedBox(height: 4),
                              Text(
                                paymentsConfirmedCount.toString(),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Commissions en attente'),
                              const SizedBox(height: 4),
                              Text(
                                totalPending.toString(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Commissions payées'),
                              const SizedBox(height: 4),
                              Text(
                                totalPaid.toString(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Étudiants référés',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (referrals.isEmpty)
                      const Text(
                        'Aucun étudiant rattaché pour le moment.',
                        style: TextStyle(fontSize: 13),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: referrals.length,
                        itemBuilder: (context, index) {
                          final ref = referrals[index];
                          final studentId =
                              (ref['student_id'] ?? '').toString();
                          final attributedAt =
                              (ref['attributed_at'] ?? '').toString();
                          final expiresAt =
                              (ref['expires_at'] ?? '').toString();

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Étudiant : $studentId',
                              style: const TextStyle(fontSize: 13),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (attributedAt.isNotEmpty)
                                  Text(
                                    'Attribué le : $attributedAt',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                if (expiresAt.isNotEmpty)
                                  Text(
                                    'Expire le : $expiresAt',
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Commissions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (commissions.isEmpty)
                      const Text(
                        'Aucune commission générée pour le moment.',
                        style: TextStyle(fontSize: 13),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: commissions.length,
                        itemBuilder: (context, index) {
                          final c = commissions[index];
                          final studentId =
                              (c['student_id'] ?? '').toString();
                          final amount = c['commission_amount'] ?? 0;
                          final currency =
                              (c['currency'] ?? '').toString();
                          final status =
                              (c['status'] ?? '').toString();
                          final createdAt =
                              (c['created_at'] ?? '').toString();

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Étudiant : $studentId',
                              style: const TextStyle(fontSize: 13),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Montant : $amount $currency',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  'Statut : $status',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                if (createdAt.isNotEmpty)
                                  Text(
                                    'Créée le : $createdAt',
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
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Espace commercial'),
        actions: [
          PopupMenuButton<_CommercialDashboardMenuAction>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Options du compte',
            onSelected: (value) {
              switch (value) {
                case _CommercialDashboardMenuAction.changePassword:
                  _showCommercialChangePasswordDialog(context);
                  break;
                case _CommercialDashboardMenuAction.signOut:
                  _signOut();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<_CommercialDashboardMenuAction>(
                value: _CommercialDashboardMenuAction.changePassword,
                child: ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('Changer le mot de passe'),
                ),
              ),
              PopupMenuItem<_CommercialDashboardMenuAction>(
                value: _CommercialDashboardMenuAction.signOut,
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Se déconnecter'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: body,
    );
  }

  Future<void> _showShareReferralDialog(BuildContext context, String link) async {
    final encodedLink = Uri.encodeComponent(link);
    final message = 'Rejoins Academia avec mon lien de parrainage : $link';
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
          title: const Text('Partager le lien'),
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
}

enum _CommercialDashboardMenuAction {
  changePassword,
  signOut,
}

Future<void> _showCommercialChangePasswordDialog(BuildContext context) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  final email = user?.email;

  if (email == null || email.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session expirée. Veuillez vous reconnecter.'),
      ),
    );
    return;
  }

  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final updated = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      String? errorMessage;
      bool isLoading = false;

      Future<void> submit() async {
        final current = currentPasswordController.text.trim();
        final next = newPasswordController.text.trim();
        final confirm = confirmPasswordController.text.trim();

        if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
          errorMessage = 'Merci de remplir tous les champs.';
          (dialogContext as Element).markNeedsBuild();
          return;
        }

        if (next.length < 8) {
          errorMessage = 'Le nouveau mot de passe doit contenir au moins 8 caractères.';
          (dialogContext as Element).markNeedsBuild();
          return;
        }

        if (next != confirm) {
          errorMessage = 'La confirmation ne correspond pas au nouveau mot de passe.';
          (dialogContext as Element).markNeedsBuild();
          return;
        }

        isLoading = true;
        errorMessage = null;
        (dialogContext as Element).markNeedsBuild();

        try {
          await client.auth.signInWithPassword(email: email, password: current);
        } on AuthException {
          isLoading = false;
          errorMessage = 'Mot de passe actuel incorrect.';
          (dialogContext as Element).markNeedsBuild();
          return;
        } catch (_) {
          isLoading = false;
          errorMessage = 'Erreur réseau. Veuillez réessayer.';
          (dialogContext as Element).markNeedsBuild();
          return;
        }

        try {
          await client.auth.updateUser(UserAttributes(password: next));
          if (Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop(true);
          }
        } on AuthException catch (e) {
          isLoading = false;
          errorMessage = e.message ?? 'Impossible de mettre à jour le mot de passe.';
          (dialogContext as Element).markNeedsBuild();
        } catch (_) {
          isLoading = false;
          errorMessage = 'Erreur inattendue. Veuillez réessayer.';
          (dialogContext as Element).markNeedsBuild();
        }
      }

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Changer le mot de passe'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe actuel',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nouveau mot de passe',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirmer le nouveau mot de passe',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (errorMessage != null) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading
                    ? null
                    : () {
                        Navigator.of(dialogContext).pop(false);
                      },
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: isLoading ? null : submit,
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Mettre à jour'),
              ),
            ],
          );
        },
      );
    },
  );

  if (updated == true) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mot de passe mis à jour avec succès.'),
      ),
    );
  }
}
