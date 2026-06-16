import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reusable bottom sheet for reporting any content type.
/// Usage: ReportContentSheet.show(context, contentType: 'video', contentId: id)
class ReportContentSheet extends StatefulWidget {
  final String contentType;
  final String contentId;
  final String? targetUserId;
  final String? contentPreview;

  const ReportContentSheet({
    super.key,
    required this.contentType,
    required this.contentId,
    this.targetUserId,
    this.contentPreview,
  });

  static Future<void> show(
    BuildContext context, {
    required String contentType,
    required String contentId,
    String? targetUserId,
    String? contentPreview,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ReportContentSheet(
        contentType: contentType,
        contentId: contentId,
        targetUserId: targetUserId,
        contentPreview: contentPreview,
      ),
    );
  }

  @override
  State<ReportContentSheet> createState() => _ReportContentSheetState();
}

class _ReportContentSheetState extends State<ReportContentSheet> {
  String? _selectedReason;
  final _detailsController = TextEditingController();
  bool _sending = false;
  bool _sent = false;

  static const _reasons = [
    ('nudity', 'Nudite / Contenu sexuel', Icons.no_adult_content),
    ('violence', 'Violence', Icons.warning_amber),
    ('harassment', 'Harcelement', Icons.person_off),
    ('spam', 'Spam', Icons.mark_email_unread),
    ('scam', 'Arnaque / Escroquerie', Icons.money_off),
    ('inappropriate', 'Contenu inapproprie', Icons.block),
    ('fake_profile', 'Faux profil / Usurpation', Icons.person_search),
    ('hate_speech', 'Discours haineux', Icons.speaker_notes_off),
    ('other', 'Autre', Icons.more_horiz),
  ];

  String get _typeLabel {
    switch (widget.contentType) {
      case 'video': return 'la video';
      case 'image': return "l'image";
      case 'comment': return 'le commentaire';
      case 'post': return 'la publication';
      case 'live': return 'le live';
      case 'user': return "l'utilisateur";
      case 'message': return 'le message';
      default: return 'le contenu';
    }
  }

  Future<void> _submit() async {
    if (_selectedReason == null) return;
    setState(() => _sending = true);
    try {
      await Supabase.instance.client.rpc('app_student_report_content', params: {
        'p_content_type': widget.contentType,
        'p_content_id': widget.contentId,
        'p_reason': _selectedReason,
        'p_details': _detailsController.text.trim().isEmpty ? null : _detailsController.text.trim(),
        'p_target_user_id': widget.targetUserId,
      });
      if (!mounted) return;
      setState(() { _sent = true; _sending = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString().length > 80 ? e.toString().substring(0, 80) : e}'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 56),
              const SizedBox(height: 16),
              const Text('Signalement envoye',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Merci. Notre equipe examinera $_typeLabel dans les plus brefs delais.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.flag, color: Colors.red, size: 22),
                const SizedBox(width: 8),
                Text('Signaler $_typeLabel',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ],
            ),
            if (widget.contentPreview != null) ...[
              const SizedBox(height: 8),
              Text(widget.contentPreview!, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
            const SizedBox(height: 16),
            const Text('Motif du signalement', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...(_reasons.map((r) => RadioListTile<String>(
              value: r.$1,
              groupValue: _selectedReason,
              onChanged: (v) => setState(() => _selectedReason = v),
              title: Text(r.$2, style: const TextStyle(fontSize: 13)),
              secondary: Icon(r.$3, size: 20, color: Colors.grey[600]),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ))),
            const SizedBox(height: 8),
            TextField(
              controller: _detailsController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Details supplementaires (optionnel)',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedReason == null || _sending ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _sending
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Envoyer le signalement', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows block/mute options for a user.
class UserModerationSheet extends StatelessWidget {
  final String userId;
  final String? userName;

  const UserModerationSheet({super.key, required this.userId, this.userName});

  static Future<void> show(BuildContext context, {required String userId, String? userName}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => UserModerationSheet(userId: userId, userName: userName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = userName ?? 'cet utilisateur';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.flag, color: Colors.orange),
              title: const Text('Signaler'),
              subtitle: Text('Signaler $name pour comportement inapproprie'),
              onTap: () {
                Navigator.pop(context);
                ReportContentSheet.show(context, contentType: 'user', contentId: userId, targetUserId: userId);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.volume_off, color: Colors.blue),
              title: const Text('Mettre en sourdine'),
              subtitle: Text('Masquer le contenu de $name sans le bloquer'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await Supabase.instance.client.rpc('app_student_mute_user', params: {'p_muted_id': userId});
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$name mis en sourdine'), behavior: SnackBarBehavior.floating));
                  }
                } catch (_) {}
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('Bloquer'),
              subtitle: Text('Ne plus voir le contenu ni les messages de $name'),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Bloquer ?'),
                    content: Text('Vous ne verrez plus le contenu de $name et ne recevrez plus ses messages.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Bloquer', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  Navigator.pop(context);
                  try {
                    await Supabase.instance.client.rpc('app_student_block_user', params: {'p_blocked_id': userId});
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$name bloque'), behavior: SnackBarBehavior.floating));
                    }
                  } catch (_) {}
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable widget: Community Guidelines screen.
class CommunityGuidelinesScreen extends StatelessWidget {
  const CommunityGuidelinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Regles communautaires'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _GuidelineSection(
            icon: Icons.handshake,
            title: 'Respect mutuel',
            content: 'Traitez tous les membres avec respect. Les insultes, le harcelement et les menaces sont strictement interdits.',
          ),
          _GuidelineSection(
            icon: Icons.no_adult_content,
            title: 'Contenu interdit',
            content: 'La pornographie, la nudite, la violence graphique, les armes, les drogues et tout contenu illegal sont strictement interdits.',
          ),
          _GuidelineSection(
            icon: Icons.security,
            title: 'Securite',
            content: 'Ne partagez jamais vos informations personnelles sensibles (mot de passe, coordonnees bancaires). Signalez toute tentative d\'arnaque.',
          ),
          _GuidelineSection(
            icon: Icons.person_search,
            title: 'Authenticite',
            content: 'L\'usurpation d\'identite est interdite. Utilisez votre vrai nom et ne creez pas de faux profils.',
          ),
          _GuidelineSection(
            icon: Icons.school,
            title: 'Contenu educatif',
            content: 'Academia est une plateforme educative. Le contenu publie doit etre en rapport avec l\'apprentissage, la formation ou les concours.',
          ),
          _GuidelineSection(
            icon: Icons.gavel,
            title: 'Sanctions',
            content: 'Le non-respect de ces regles peut entrainer : avertissement, suspension temporaire (24h a 30 jours), ou bannissement permanent.',
          ),
          _GuidelineSection(
            icon: Icons.flag,
            title: 'Signalement',
            content: 'Si vous voyez un contenu ou un comportement qui enfreint ces regles, utilisez le bouton de signalement. Notre equipe examinera chaque signalement.',
          ),
        ],
      ),
    );
  }
}

class _GuidelineSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;

  const _GuidelineSection({required this.icon, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.blue[700], size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(content, style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
