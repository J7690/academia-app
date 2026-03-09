import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentMerchantProfileScreenV1 extends StatefulWidget {
  final String merchantId;

  const StudentMerchantProfileScreenV1({
    super.key,
    required this.merchantId,
  });

  @override
  State<StudentMerchantProfileScreenV1> createState() =>
      _StudentMerchantProfileScreenV1State();
}

class _StudentMerchantProfileScreenV1State
    extends State<StudentMerchantProfileScreenV1> {
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;
      final response = await client.rpc(
        'app_get_public_merchant_profile',
        params: {
          'p_merchant_id': widget.merchantId,
        },
      );

      if (response is! Map<String, dynamic>) {
        setState(() {
          _error = 'Réponse invalide du serveur.';
        });
        return;
      }

      if (response['success'] != true) {
        setState(() {
          _error = response['error']?.toString() ?? 'Erreur serveur.';
        });
        return;
      }

      final p = response['profile'];
      setState(() {
        _profile = p is Map ? Map<String, dynamic>.from(p) : null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final displayName = profile?['display_name']?.toString() ?? 'Marchand';
    final logoUrl = profile?['logo_url']?.toString();
    final bio = profile?['bio']?.toString();
    final country = profile?['country']?.toString() ?? '';
    final city = profile?['city']?.toString() ?? '';
    final verificationLevel = profile?['verification_level']?.toString() ?? '';

    final location = [city, country].where((s) => s.trim().isNotEmpty).join(', ');

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Profil marchand'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              : profile == null
                  ? const Center(child: Text('Profil indisponible.'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              _Avatar(logoUrl: logoUrl, label: displayName),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    if (verificationLevel.trim().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Niveau: $verificationLevel',
                                        style: const TextStyle(
                                          color: Color(0xFF1EA75C),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                    if (location.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        location,
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (bio != null && bio.trim().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              bio,
                              style: const TextStyle(
                                color: Color(0xFF1F2937),
                                height: 1.4,
                              ),
                            ),
                          ),
                      ],
                    ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? logoUrl;
  final String label;

  const _Avatar({
    required this.logoUrl,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.trim().isNotEmpty;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF1EA75C), Color(0xFFA3D65C)],
        ),
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          image: hasLogo
              ? DecorationImage(
                  image: NetworkImage(logoUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: hasLogo
            ? null
            : Center(
                child: Text(
                  label.isNotEmpty ? label[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1EA75C),
                  ),
                ),
              ),
      ),
    );
  }
}
