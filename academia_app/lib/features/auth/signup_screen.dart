import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _lastNameController.dispose();
    _firstNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final lastName = _lastNameController.text.trim();
    final firstName = _firstNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (lastName.isEmpty || firstName.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Veuillez renseigner nom, prnoms, email et mot de passe.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final fullName = '$firstName $lastName';
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'role': 'student',
          'full_name': fullName,
        },
      );
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
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
                    labelText: 'Prnoms',
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
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe',
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 24),
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
                    onPressed: _isLoading ? null : _submit,
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
    );
  }
}
