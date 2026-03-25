import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentDeleteAccountScreen extends StatefulWidget {
  const StudentDeleteAccountScreen({super.key});

  @override
  State<StudentDeleteAccountScreen> createState() =>
      _StudentDeleteAccountScreenState();
}

class _StudentDeleteAccountScreenState
    extends State<StudentDeleteAccountScreen> {
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String? _error;

  static const _privacyUrl = 'https://nexiomgroup.space/privacy';
  static const _termsUrl = 'https://nexiomgroup.space/terms';
  static const _deleteAccountUrl = 'https://nexiomgroup.space/delete-account';

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _onDeletePressed() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() => _error = 'Veuillez saisir votre mot de passe.');
      return;
    }

    // Double confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmation finale'),
        content: const Text(
          'Cette action est irréversible.\n\n'
          'Votre compte sera désactivé immédiatement et toutes vos données '
          'personnelles seront définitivement supprimées dans un délai '
          'maximum de 60 jours.\n\n'
          'Voulez-vous vraiment supprimer votre compte ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;
      final email = client.auth.currentUser?.email;

      if (email == null) {
        setState(() => _error = 'Impossible de récupérer votre email.');
        return;
      }

      // Step 1: Verify password by re-authenticating
      try {
        await client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } on AuthException catch (e) {
        setState(() {
          _error = 'Mot de passe incorrect. Veuillez réessayer.';
          _isLoading = false;
        });
        debugPrint('DeleteAccount: auth verify failed: ${e.message}');
        return;
      }

      // Step 2: Call the deletion RPC
      final result = await client.rpc('app_student_request_account_deletion');

      if (result is Map && result['success'] == true) {
        // Step 3: Sign out
        await client.auth.signOut();

        if (!mounted) return;

        // Step 4: Show final screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => _AccountDeletedConfirmationScreen(
              purgeDate: result['purge_due_at']?.toString(),
            ),
          ),
          (route) => false,
        );
      } else {
        final errorMsg = result is Map
            ? (result['message']?.toString() ??
                result['error']?.toString() ??
                'Erreur inconnue')
            : 'Erreur lors de la suppression.';
        setState(() => _error = errorMsg);
      }
    } catch (e) {
      setState(() => _error = 'Erreur: ${e.toString()}');
      debugPrint('DeleteAccount: error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supprimer mon compte'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Warning icon
            const Icon(Icons.warning_amber_rounded,
                size: 56, color: Colors.red),
            const SizedBox(height: 16),

            // Title
            const Text(
              'Suppression de compte',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Explanation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'En supprimant votre compte :',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  SizedBox(height: 10),
                  _BulletPoint(
                    'Votre compte sera immédiatement désactivé et vous ne '
                    'pourrez plus vous connecter.',
                  ),
                  _BulletPoint(
                    'Vos données personnelles (nom, email, téléphone, '
                    'documents, messages) seront définitivement supprimées.',
                  ),
                  _BulletPoint(
                    'Le traitement complet de la suppression peut prendre '
                    'jusqu\'à 60 jours.',
                  ),
                  _BulletPoint(
                    'Cette action est irréversible.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Legal links
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _LinkChip(
                  label: 'Politique de confidentialité',
                  onTap: () => _openUrl(_privacyUrl),
                ),
                _LinkChip(
                  label: "Conditions d'utilisation",
                  onTap: () => _openUrl(_termsUrl),
                ),
                _LinkChip(
                  label: 'Suppression via le web',
                  onTap: () => _openUrl(_deleteAccountUrl),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Password field
            const Text(
              'Confirmez votre identité',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 8),
            const Text(
              'Saisissez votre mot de passe pour confirmer la suppression.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_isPasswordVisible
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () {
                    setState(
                        () => _isPasswordVisible = !_isPasswordVisible);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Error
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!,
                    style: TextStyle(color: Colors.red.shade700)),
              ),
              const SizedBox(height: 16),
            ],

            // Delete button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _onDeletePressed,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.delete_forever),
              label: Text(_isLoading
                  ? 'Suppression en cours...'
                  : 'Supprimer définitivement mon compte'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Cancel button
            OutlinedButton(
              onPressed:
                  _isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Confirmation screen shown after successful deletion
// ============================================================
class _AccountDeletedConfirmationScreen extends StatelessWidget {
  final String? purgeDate;
  const _AccountDeletedConfirmationScreen({this.purgeDate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 72, color: Colors.green),
                const SizedBox(height: 24),
                const Text(
                  'Demande prise en compte',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Votre demande de suppression de compte a bien été '
                  'enregistrée. Votre compte n\'est plus accessible.\n\n'
                  'Le traitement complet de vos données peut prendre '
                  'jusqu\'à 60 jours.\n\n'
                  'Pour toute question :\ncontact@nexiomgroup.space',
                  style: const TextStyle(fontSize: 15, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                if (purgeDate != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Purge prévue : ${purgeDate!.substring(0, 10)}',
                    style: const TextStyle(
                        fontSize: 13, color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const _RedirectToLanding(),
                      ),
                      (route) => false,
                    );
                  },
                  child: const Text('Fermer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RedirectToLanding extends StatelessWidget {
  const _RedirectToLanding();

  @override
  Widget build(BuildContext context) {
    // The auth_wrapper will automatically show AuthLandingScreen
    // since the user is now signed out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    });
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

// ============================================================
// Helper widgets
// ============================================================
class _BulletPoint extends StatelessWidget {
  final String text;
  const _BulletPoint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 8),
            child:
                Icon(Icons.circle, size: 6, color: Colors.red),
          ),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 14, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _LinkChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LinkChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.open_in_new, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
