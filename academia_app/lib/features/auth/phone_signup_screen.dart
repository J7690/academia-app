import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'phone_rules.dart';

const Color _kGreen = Color(0xFF1EA75C);

/// Longueur minimale imposée par Supabase sur le mot de passe.
const int _kMinPasswordLength = 6;

/// Inscription par téléphone, sans SMS.
///
/// Remplace l'ancien parcours OTP (`PhoneLoginScreen(isSignup: true)` puis
/// `OtpVerifyScreen`), inutilisable sans abonnement SMS. Ici le compte est créé
/// par `signUp(phone:, password:)` : lorsque « Confirm phone » est désactivé
/// côté Supabase, le serveur confirme le numéro lui-même et ouvre la session
/// immédiatement, sans qu'aucun SMS ne soit émis.
///
/// Le nom complet part dans les métadonnées : le déclencheur
/// `app_handle_new_auth_user` le lit et crée la fiche `app.students`. Aucun
/// appel supplémentaire n'est donc nécessaire côté client.
class PhoneSignupScreen extends StatefulWidget {
  const PhoneSignupScreen({super.key});

  @override
  State<PhoneSignupScreen> createState() => _PhoneSignupScreenState();
}

class _PhoneSignupScreenState extends State<PhoneSignupScreen> {
  final _lastNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  PhoneCountry _country = kSupportedPhoneCountries.first;
  bool _acceptedTerms = false;
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _lastNameController.dispose();
    _firstNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_isLoading || !_acceptedTerms) return false;
    if (_lastNameController.text.trim().isEmpty) return false;
    if (_firstNameController.text.trim().isEmpty) return false;
    if (_passwordController.text.trim().length < _kMinPasswordLength) {
      return false;
    }
    return checkPhoneNumber(_phoneController.text, _country).isValid;
  }

  Future<void> _submit() async {
    final lastName = _lastNameController.text.trim();
    final firstName = _firstNameController.text.trim();
    final password = _passwordController.text.trim();

    final check = checkPhoneNumber(_phoneController.text, _country);
    if (!check.isValid) {
      setState(() => _error = check.error);
      return;
    }
    if (lastName.isEmpty || firstName.isEmpty) {
      setState(() => _error = 'Veuillez renseigner votre nom et votre prénom.');
      return;
    }
    if (password.length < _kMinPasswordLength) {
      setState(
        () => _error =
            'Le mot de passe doit contenir au moins $_kMinPasswordLength caractères.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Même convention que l'inscription par email : « Prénom Nom ».
      final fullName = '$firstName $lastName';
      final signUpData = <String, dynamic>{
        'role': 'student',
        'full_name': fullName,
      };

      // Attribution marketing (?src=), isolée du référencement commercial.
      String? mktRef;
      try {
        final s = Uri.base.queryParameters['src'];
        if (s != null && s.trim().isNotEmpty) mktRef = s.trim();
      } catch (_) {}
      if (mktRef != null && mktRef.isNotEmpty) {
        signUpData['mkt_ref'] = mktRef;
      }

      final response = await Supabase.instance.client.auth.signUp(
        phone: check.e164,
        password: password,
        data: signUpData,
      );

      if (mktRef != null && mktRef.isNotEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('pending_marketing_ref_v1', mktRef);
        } catch (_) {}
      }

      if (!mounted) return;

      if (response.session == null) {
        // Cas unique : « Confirm phone » est resté actif côté Supabase, donc le
        // serveur attend une vérification par SMS qui n'arrivera jamais.
        debugPrint(
          'PhoneSignup: compte créé sans session. '
          'Vérifier que « Confirm phone » est désactivé (Authentication → Providers → Phone).',
        );
        setState(
          () => _error =
              'Votre compte a été créé, mais la connexion automatique n\'a pas '
              'abouti. Connectez-vous avec votre numéro et votre mot de passe.',
        );
        return;
      }

      // LE NOM, ÉCRIT PAR NOUS — parce que `data:` ne survit pas.
      //
      // Mesure du 04/09/2026 : sur 58 inscriptions par téléphone, **57 ont un
      // nom FABRIQUÉ** par le déclencheur (`'Etudiant ' || 4 derniers chiffres`),
      // et une seule un vrai nom. Le défaut vaut aussi pour les comptes créés
      // depuis que cet écran existe (18/08) : 17 sur 17. Le `full_name` envoyé
      // dans `data` ci-dessus n'arrive donc jamais dans `raw_user_meta_data` —
      // la cause est dans le service Auth, hors de portée du dépôt.
      //
      // On ne dépend plus de lui : la session est ouverte, on écrit le nom
      // nous-mêmes. Si cette écriture échoue, le compte reste utilisable avec
      // le nom fabriqué — on ne bloque pas une inscription réussie pour ça,
      // mais on le trace pour ne pas répéter l'erreur du symptôme muet.
      // On passe par la RPC que l'application utilise déjà pour le profil,
      // plutôt qu'un accès direct à la table : elle porte les contrôles et les
      // règles d'accès. Tous ses autres paramètres sont optionnels.
      try {
        await Supabase.instance.client.rpc(
          'app_student_update_full_profile',
          params: {'p_full_name': fullName},
        );
      } catch (e) {
        debugPrint('PhoneSignup: nom non enregistré ($e) — compte créé malgré tout.');
      }

      if (!mounted) return;

      // AuthWrapper prend le relais via onAuthStateChange.
      Navigator.of(context).pop();
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
    if (m.contains('already registered') ||
        m.contains('already been registered')) {
      return 'Ce numéro a déjà un compte. Connectez-vous plutôt.';
    }
    if (m.contains('password')) {
      return 'Mot de passe trop court : au moins $_kMinPasswordLength caractères.';
    }
    if (m.contains('rate') || m.contains('too many')) {
      return 'Trop de tentatives. Réessayez dans quelques minutes.';
    }
    if (m.contains('sms') || m.contains('twilio') || m.contains('provider')) {
      return 'L\'inscription par téléphone est momentanément indisponible. '
          'Essayez par email.';
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
        title: const Text('Inscription par téléphone'),
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
                        'Créer votre compte',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Aucun code par SMS. Votre mot de passe suffit.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _lastNameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: _fieldDecoration(label: 'Nom'),
                              onChanged: (_) => setState(() => _error = null),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _firstNameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: _fieldDecoration(label: 'Prénom'),
                              onChanged: (_) => setState(() => _error = null),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _PhoneField(
                        controller: _phoneController,
                        country: _country,
                        onCountryChanged: (c) => setState(() {
                          _country = c;
                          _error = null;
                        }),
                        onChanged: () => setState(() => _error = null),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        decoration: _fieldDecoration(
                          label: 'Mot de passe',
                          helper:
                              'Au moins $_kMinPasswordLength caractères. '
                              'Un code à 6 chiffres convient.',
                          suffix: IconButton(
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
                      ),
                      const SizedBox(height: 16),
                      _TermsCheckbox(
                        value: _acceptedTerms,
                        onChanged: (v) => setState(() => _acceptedTerms = v),
                      ),
                      const SizedBox(height: 20),
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
                              : const Text('Créer le compte'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(foregroundColor: _kGreen),
                          child: const Text('J\'ai déjà un compte'),
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

InputDecoration _fieldDecoration({
  required String label,
  String? helper,
  String? hint,
  Widget? suffix,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: 2,
    suffixIcon: suffix,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  );
}

/// Indicatif + numéro. Le sélecteur n'apparaît que si plusieurs pays sont
/// ouverts : avec un seul, un menu déroulant serait un clic pour rien.
class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.controller,
    required this.country,
    required this.onCountryChanged,
    required this.onChanged,
  });

  final TextEditingController controller;
  final PhoneCountry country;
  final ValueChanged<PhoneCountry> onCountryChanged;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final border = BoxDecoration(
      border: Border.all(color: Colors.grey.shade300),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(8),
        bottomLeft: Radius.circular(8),
      ),
      color: Colors.grey.shade50,
    );

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: border,
          child: kSupportedPhoneCountries.length == 1
              ? Text(
                  '${country.flag} ${country.dialPrefix}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<PhoneCountry>(
                    value: country,
                    isDense: true,
                    onChanged: (c) {
                      if (c != null) onCountryChanged(c);
                    },
                    items: [
                      for (final c in kSupportedPhoneCountries)
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
            controller: controller,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(country.nsnLength),
            ],
            decoration: InputDecoration(
              hintText: country.hint,
              border: OutlineInputBorder(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
      ],
    );
  }
}

/// Acceptation des conditions. Texte et liens identiques à l'inscription par
/// email, pour que les deux parcours engagent exactement la même chose.
class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
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
                const TextSpan(text: 'En créant un compte, vous acceptez les '),
                TextSpan(
                  text: 'Conditions d\'utilisation',
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
                  text: 'Politique de confidentialité',
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
                const TextSpan(text: ' de Nexiom Group.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
