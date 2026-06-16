import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/notification_sound_service.dart';
import 'student_delete_account_screen.dart';
import 'student_profile_screen.dart';
import '../../widgets/report_content_sheet.dart';

class StudentSettingsScreen extends StatefulWidget {
  final bool showDeleteAccount;
  final bool showProfile;
  const StudentSettingsScreen({
    super.key,
    this.showDeleteAccount = true,
    this.showProfile = true,
  });

  @override
  State<StudentSettingsScreen> createState() => _StudentSettingsScreenState();
}

class _StudentSettingsScreenState extends State<StudentSettingsScreen> {
  bool _soundEnabled = true;
  bool _pushEnabled = true;
  bool _loadingSound = true;
  String _appVersion = '';

  static const _privacyUrl = 'https://nexiomgroup.space/privacy';
  static const _termsUrl = 'https://nexiomgroup.space/terms';
  static const _deleteAccountUrl = 'https://nexiomgroup.space/delete-account';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadAppVersion();
  }

  Future<void> _loadPrefs() async {
    try {
      final sound = await NotificationSoundService.instance.isEnabled();
      if (!mounted) return;
      setState(() {
        _soundEnabled = sound;
        _loadingSound = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSound = false);
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersion = '${info.version} (${info.buildNumber})';
      });
    } catch (_) {}
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _showBlockedUsers(BuildContext ctx) async {
    try {
      final result = await Supabase.instance.client.rpc('app_student_list_blocked_users');
      final list = (result is List) ? result : [];
      if (!ctx.mounted) return;
      showModalBottomSheet(
        context: ctx,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Utilisateurs bloques', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                if (list.isEmpty)
                  const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucun utilisateur bloque', style: TextStyle(color: Colors.grey)))),
                ...list.map<Widget>((u) => ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(u['display_name']?.toString() ?? 'Utilisateur'),
                  trailing: TextButton(
                    onPressed: () async {
                      await Supabase.instance.client.rpc('app_student_unblock_user', params: {'p_blocked_id': u['user_id']});
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Debloquer', style: TextStyle(color: Colors.red)),
                  ),
                )),
              ],
            ),
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Se déconnecter',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: ListView(
        children: [
          // ===================== COMPTE =====================
          _SectionHeader(title: 'Compte'),
          if (widget.showProfile)
            _SettingsTile(
              icon: Icons.person_outline,
              title: 'Mon profil',
              subtitle: 'Modifier mes informations personnelles',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const StudentProfileScreen(),
                  ),
                );
              },
            ),
          if (widget.showDeleteAccount)
            _SettingsTile(
              icon: Icons.delete_forever,
              title: 'Supprimer mon compte',
              subtitle: 'Suppression définitive de votre compte et données',
              iconColor: Colors.red,
              titleColor: Colors.red,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const StudentDeleteAccountScreen(),
                  ),
                );
              },
            ),
          const Divider(height: 1),

          // ===================== NOTIFICATIONS =====================
          _SectionHeader(title: 'Notifications'),
          _loadingSound
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))),
                )
              : SwitchListTile.adaptive(
                  secondary: const Icon(Icons.volume_up_outlined),
                  title: const Text('Sons de notification'),
                  subtitle: const Text(
                      'Jouer un son lors de nouvelles notifications'),
                  value: _soundEnabled,
                  onChanged: (val) async {
                    setState(() => _soundEnabled = val);
                    try {
                      await NotificationSoundService.instance.setEnabled(val);
                    } catch (_) {}
                  },
                ),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications push'),
            subtitle: const Text(
                'Recevoir des alertes sur votre appareil'),
            value: _pushEnabled,
            onChanged: (val) {
              setState(() => _pushEnabled = val);
              if (!val) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Pour désactiver complètement les notifications, '
                      'allez dans les paramètres de votre appareil.',
                    ),
                  ),
                );
              }
            },
          ),
          const Divider(height: 1),

          // ===================== COMMUNAUTÉ =====================
          _SectionHeader(title: 'Communaut\u00e9'),
          _SettingsTile(
            icon: Icons.shield_outlined,
            title: 'R\u00e8gles communautaires',
            subtitle: 'Consultez les r\u00e8gles d\'utilisation',
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CommunityGuidelinesScreen())),
          ),
          _SettingsTile(
            icon: Icons.block,
            title: 'Utilisateurs bloqu\u00e9s',
            subtitle: 'G\u00e9rer vos utilisateurs bloqu\u00e9s',
            onTap: () => _showBlockedUsers(context),
          ),
          const Divider(height: 1),

          // ===================== LÉGAL =====================
          _SectionHeader(title: 'Informations l\u00e9gales'),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Politique de confidentialit\u00e9',
            onTap: () => _openUrl(_privacyUrl),
            trailing: const Icon(Icons.open_in_new, size: 18),
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: "Conditions d'utilisation",
            onTap: () => _openUrl(_termsUrl),
            trailing: const Icon(Icons.open_in_new, size: 18),
          ),
          _SettingsTile(
            icon: Icons.link,
            title: 'Suppression de compte (page web)',
            onTap: () => _openUrl(_deleteAccountUrl),
            trailing: const Icon(Icons.open_in_new, size: 18),
          ),
          const Divider(height: 1),

          // ===================== À PROPOS =====================
          _SectionHeader(title: 'À propos'),
          const _AboutInfoTile(
            label: 'Application',
            value: 'Academia',
          ),
          const _AboutInfoTile(
            label: 'Éditée par',
            value: 'Nexiom Group SARL',
          ),
          const _AboutInfoTile(
            label: 'Contact',
            value: 'contact@nexiomgroup.space',
          ),
          const _AboutInfoTile(
            label: 'Téléphone',
            value: '+226 54 78 98 18',
          ),
          _AboutInfoTile(
            label: 'Version',
            value: _appVersion.isNotEmpty ? _appVersion : '...',
          ),
          const SizedBox(height: 24),

          // ===================== DÉCONNEXION =====================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: _confirmSignOut,
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Se déconnecter',
                  style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? iconColor;
  final Color? titleColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title,
          style: titleColor != null ? TextStyle(color: titleColor) : null),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _AboutInfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _AboutInfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
