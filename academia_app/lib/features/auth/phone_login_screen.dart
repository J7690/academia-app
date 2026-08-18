import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'phone_rules.dart';
import 'phone_signup_screen.dart';

const Color _kGreen = Color(0xFF1EA75C);

/// Connexion par téléphone, sans SMS.
///
/// Remplace l'ancien parcours OTP (`signInWithOtp` puis `OtpVerifyScreen`),
/// inutilisable sans abonnement SMS : on authentifie désormais par
/// `signInWithPassword(phone:, password:)`, exactement comme le parcours email.
class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  PhoneCountry _country = kSupportedPhoneCountries.first;
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_isLoading) return false;
    if (_passwordController.text.trim().isEmpty) return false;
    return checkPhoneNumber(_phoneController.text, _country).isValid;
  }

  Future<void> _submit() async {
    final check = checkPhoneNumber(_phoneController.text, _country);
    if (!check.isValid) {
      setState(() => _error = check.error);
      return;
    }
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() => _error = 'Veuillez saisir votre mot de passe.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        phone: check.e164,
        password: password,
      );
      // AuthWrapper prend le relais via onAuthStateChange.
      if (mounted) Navigator.of(context).pop();
    } on AuthException catch (e) {
      setState(() => _error = _friendlyError(e.message));
    } catch (_) {
      setState(() => _error = 'Erreur réseau. Vérifiez votre connexion.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('invalid login credentials')) {
      return 'Numéro ou mot de passe incorrect.';
    }
    if (m.contains('not confirmed')) {
      return 'Ce compte n\'est pas encore activé. Contactez le support.';
    }
    if (m.contains('rate') || m.contains('too many')) {
      return 'Trop de tentatives. Réessayez dans quelques minutes.';
    }
    if (m.contains('phone')) {
      return 'Numéro de téléphone invalide.';
    }
    return msg;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connexion par téléphone'),
        backgroundColor: _kGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Center(
              child: Opacity(
                opacity: 0.08,
                child: FractionallySizedBox(
                  widthFactor: 0.7,
                  child: Image.asset(
                    'assets/Academia.0.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.phone_android, size: 48, color: _kGreen),
                      const SizedBox(height: 16),
                      const Text(
                        'Entrez votre numéro',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8),
                                bottomLeft: Radius.circular(8),
                              ),
                              color: Colors.grey.shade50,
                            ),
                            child: kSupportedPhoneCountries.length == 1
                                ? Text(
                                    '${_country.flag} ${_country.dialPrefix}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : DropdownButtonHideUnderline(
                                    child: DropdownButton<PhoneCountry>(
                                      value: _country,
                                      isDense: true,
                                      onChanged: (c) {
                                        if (c == null) return;
                                        setState(() {
                                          _country = c;
                                          _error = null;
                                        });
                                      },
                                      items: [
                                        for (final c
                                            in kSupportedPhoneCountries)
                                          DropdownMenuItem<PhoneCountry>(
                                            value: c,
                                            child: Text(
                                              '${c.flag} ${c.dialPrefix}',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(
                                  _country.nsnLength,
                                ),
                              ],
                              decoration: InputDecoration(
                                hintText: _country.hint,
                                border: OutlineInputBorder(
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(8),
                                    bottomRight: Radius.circular(8),
                                  ),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(8),
                                    bottomRight: Radius.circular(8),
                                  ),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                              ),
                              onChanged: (_) => setState(() => _error = null),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () => setState(
                              () => _isPasswordVisible = !_isPasswordVisible,
                            ),
                          ),
                        ),
                        onChanged: (_) => setState(() => _error = null),
                        onSubmitted: (_) => _canSubmit ? _submit() : null,
                      ),
                      const SizedBox(height: 16),
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _canSubmit ? _submit : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Se connecter'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const PhoneSignupScreen(),
                                    ),
                                  );
                                },
                          style: TextButton.styleFrom(foregroundColor: _kGreen),
                          child: const Text(
                            'Pas encore de compte ? Créer un compte',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
