import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OtpVerifyScreen extends StatefulWidget {
  final String phone;
  final String? firstName;
  final String? lastName;
  const OtpVerifyScreen({
    super.key,
    required this.phone,
    this.firstName,
    this.lastName,
  });

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  // Cooldown pour le renvoi OTP
  int _cooldown = 60;
  Timer? _cooldownTimer;
  bool get _canResend => _cooldown == 0;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldown = 60;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_cooldown > 0) {
          _cooldown--;
        } else {
          t.cancel();
        }
      });
    });
  }

  Future<void> _verify() async {
    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      setState(() => _error = 'Entrez le code à 6 chiffres reçu par SMS.');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      await Supabase.instance.client.auth.verifyOTP(
        phone: widget.phone,
        token: otp,
        type: OtpType.sms,
      );

      // Créer/assurer le profil étudiant (idempotent)
      try {
        await Supabase.instance.client.rpc('app_ensure_student_profile');
      } catch (_) {}

      // Mettre à jour nom/prénom si fournis (inscription par téléphone)
      if (widget.firstName != null && widget.lastName != null) {
        final fullName = '${widget.lastName} ${widget.firstName}'.trim();
        try {
          final uid = Supabase.instance.client.auth.currentUser?.id;
          if (uid != null) {
            await Supabase.instance.client
                .from('students')
                .update({'full_name': fullName})
                .eq('id', uid);
          }
        } catch (_) {}
      }

      // AuthWrapper gère la redirection automatiquement via onAuthStateChange.
      // On dépile simplement vers la racine pour laisser AuthWrapper prendre le relais.
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on AuthException catch (e) {
      setState(() => _error = _friendlyError(e.message));
    } catch (e) {
      setState(() => _error = 'Erreur réseau. Vérifiez votre connexion.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;
    setState(() { _isLoading = true; _error = null; });

    try {
      await Supabase.instance.client.auth.signInWithOtp(phone: widget.phone);
      _startCooldown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Code renvoyé ! Vérifiez vos SMS.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on AuthException catch (e) {
      setState(() => _error = _friendlyError(e.message));
    } catch (e) {
      setState(() => _error = 'Erreur lors du renvoi. Réessayez.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(String msg) {
    if (msg.contains('expired')) return 'Code expiré. Demandez un nouveau code.';
    if (msg.contains('invalid') || msg.contains('Token')) return 'Code incorrect. Vérifiez et réessayez.';
    if (msg.contains('rate')) return 'Trop de tentatives. Attendez quelques minutes.';
    return msg;
  }

  @override
  Widget build(BuildContext context) {
    final maskedPhone = widget.phone.length > 4
        ? '${widget.phone.substring(0, widget.phone.length - 4)}****'
        : widget.phone;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérification OTP'),
        backgroundColor: const Color(0xFF1EA75C),
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
                  child: Image.asset('assets/Academia.0.png', fit: BoxFit.contain),
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
                      BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 8)),
                    ],
                  ),
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.sms_outlined, size: 48, color: Color(0xFF1EA75C)),
                      const SizedBox(height: 16),
                      const Text(
                        'Code envoyé !',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Entrez le code à 6 chiffres envoyé au\n$maskedPhone',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 28),
                      // Champ OTP centré, grande taille
                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 12,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '------',
                          hintStyle: TextStyle(
                            fontSize: 32,
                            letterSpacing: 12,
                            color: Colors.grey.shade300,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF1EA75C), width: 2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF1EA75C), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        onChanged: (_) => setState(() => _error = null),
                        onSubmitted: (_) => _verify(),
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
                            style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _verify,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(_isLoading ? 'Vérification...' : 'Valider le code'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1EA75C),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Renvoi avec cooldown
                      Center(
                        child: _canResend
                            ? TextButton.icon(
                                onPressed: _isLoading ? null : _resendOtp,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Renvoyer le code'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF1EA75C),
                                ),
                              )
                            : Text(
                                'Renvoyer dans $_cooldown s',
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Le code expire dans 5 minutes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Colors.grey),
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
