import 'package:flutter/material.dart';

import '../services/notification_sound_service.dart';

class NotificationSoundSettingsDialog extends StatefulWidget {
  const NotificationSoundSettingsDialog({super.key});

  static Future<void> show(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => const NotificationSoundSettingsDialog(),
    );
  }

  @override
  State<NotificationSoundSettingsDialog> createState() => _NotificationSoundSettingsDialogState();
}

class _NotificationSoundSettingsDialogState extends State<NotificationSoundSettingsDialog> {
  bool _loading = true;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await NotificationSoundService.instance.isEnabled();
      if (!mounted) return;
      setState(() {
        _enabled = value;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _onChanged(bool value) async {
    setState(() {
      _enabled = value;
    });
    try {
      await NotificationSoundService.instance.setEnabled(value);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Paramètres des notifications'),
      content: _loading
          ? const SizedBox(
              height: 48,
              child: Center(child: CircularProgressIndicator()),
            )
          : SwitchListTile.adaptive(
              title: const Text('Sons de notification'),
              subtitle: const Text('Activer un son léger quand de nouvelles notifications arrivent.'),
              value: _enabled,
              onChanged: _onChanged,
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}
