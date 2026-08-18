import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Bannière globale « hors ligne » qui écoute la connectivité de l'appareil.
///
/// Envelopper le contenu d'un dashboard :
/// ```dart
/// OfflineBanner(child: monContenu)
/// ```
/// Quand l'appareil perd le réseau, une bannière orange apparaît en haut ;
/// quand la connexion revient, une confirmation verte s'affiche 3 secondes.
class OfflineBanner extends StatefulWidget {
  final Widget child;

  const OfflineBanner({super.key, required this.child});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _backOnlineTimer;
  bool _isOffline = false;
  bool _showBackOnline = false;

  @override
  void initState() {
    super.initState();
    _checkInitial();
    _subscription =
        Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
  }

  Future<void> _checkInitial() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (!mounted) return;
      setState(() {
        _isOffline = results.every((r) => r == ConnectivityResult.none);
      });
    } catch (_) {}
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final offline = results.every((r) => r == ConnectivityResult.none);
    if (!mounted || offline == _isOffline) return;
    setState(() {
      final wasOffline = _isOffline;
      _isOffline = offline;
      if (wasOffline && !offline) {
        _showBackOnline = true;
        _backOnlineTimer?.cancel();
        _backOnlineTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showBackOnline = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _backOnlineTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _isOffline
              ? _buildBanner(
                  key: const ValueKey('offline'),
                  color: const Color(0xFFB45309),
                  icon: Icons.wifi_off_rounded,
                  text:
                      'Mode hors ligne — certaines fonctionnalités sont indisponibles',
                )
              : _showBackOnline
                  ? _buildBanner(
                      key: const ValueKey('online'),
                      color: const Color(0xFF15803D),
                      icon: Icons.wifi_rounded,
                      text: 'Connexion rétablie',
                    )
                  : const SizedBox.shrink(key: ValueKey('none')),
        ),
        Expanded(child: widget.child),
      ],
    );
  }

  Widget _buildBanner({
    required Key key,
    required Color color,
    required IconData icon,
    required String text,
  }) {
    return Material(
      key: key,
      color: color,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
