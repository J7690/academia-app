import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/supabase_config.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _lastNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _invitationCodeController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _isPasswordVisible = false;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _lastNameController.dispose();
    _firstNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _invitationCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final lastName = _lastNameController.text.trim();
    final firstName = _firstNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final invitationCode = _invitationCodeController.text.trim();

    if (lastName.isEmpty || firstName.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Veuillez renseigner nom, prénoms, email et mot de passe.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final fullName = '$firstName $lastName';
      final client = Supabase.instance.client;
      final signUpData = <String, dynamic>{
        'role': 'student',
        'full_name': fullName,
      };
      // Attribution marketing (campagnes Facebook/Claude), ISOLÉE du référencement
      // commercial. Lue depuis le paramètre URL ?src= (ex. src=fb-claude-vac2026-reel-a).
      // N'affecte ni user_referrals ni les commissions.
      String? mktRef;
      try {
        final s = Uri.base.queryParameters['src'];
        if (s != null && s.trim().isNotEmpty) mktRef = s.trim();
      } catch (_) {}
      if (mktRef != null && mktRef.isNotEmpty) {
        signUpData['mkt_ref'] = mktRef;
      }
      await client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: kIsWeb ? SupabaseConfig.authCallbackUrl : SupabaseConfig.mobileAuthCallbackUrl,
        data: signUpData,
      );

      // Persister l'attribution marketing pour rattachement après login (auth_wrapper).
      if (mktRef != null && mktRef.isNotEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('pending_marketing_ref_v1', mktRef);
        } catch (_) {}
      }

      if (invitationCode.isNotEmpty) {
        try {
          final dynamic response = await client.rpc(
            'app_accept_user_invitation',
            params: {
              'p_token': invitationCode,
              'p_full_name': fullName,
            },
          );
          if (response is Map && response['success'] != true) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    response['error']?.toString() ??
                        'Erreur lors de la validation de l\'invitation.',
                  ),
                ),
              );
            }
          }
        } catch (_) {}
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on AuthException catch (e) {
      setState(() {
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inscription'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Center(
              child: Opacity(
                opacity: 0.18,
                child: FractionallySizedBox(
                  widthFactor: 0.8,
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
                    color: Colors.white.withOpacity(0.64),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'Prénoms',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                        obscureText: !_isPasswordVisible,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _invitationCodeController,
                        decoration: const InputDecoration(
                          labelText: 'Code d\'invitation (optionnel)',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _acceptedTerms,
                              onChanged: (v) {
                                setState(() => _acceptedTerms = v ?? false);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                  height: 1.4,
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'En cr\u00e9ant un compte, vous acceptez les ',
                                  ),
                                  TextSpan(
                                    text: "Conditions d'utilisation",
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        launchUrl(
                                          Uri.parse('https://nexiomgroup.space/terms'),
                                          mode: LaunchMode.externalApplication,
                                        );
                                      },
                                  ),
                                  const TextSpan(text: ' et la '),
                                  TextSpan(
                                    text: 'Politique de confidentialit\u00e9',
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        launchUrl(
                                          Uri.parse('https://nexiomgroup.space/privacy'),
                                          mode: LaunchMode.externalApplication,
                                        );
                                      },
                                  ),
                                  const TextSpan(
                                    text: ' de Nexiom Group.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: (_isLoading || !_acceptedTerms) ? null : _submit,
                          child: _isLoading
                              ? const CircularProgressIndicator(strokeWidth: 2)
                              : const Text('Créer le compte'),
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
