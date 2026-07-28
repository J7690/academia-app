import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/orientation_provider.dart';

/// Bandeau de consentement à l'enregistrement, en consultation d'orientation.
///
/// Une consultation d'orientation est une conversation asymétrique et parfois
/// sensible. L'accord d'une seule partie ne suffit donc pas : tant que le
/// conseiller **et** l'élève n'ont pas consenti, l'enregistrement reste coupé.
///
/// Le bandeau est permanent — il ne se referme pas — pour deux raisons :
/// tant que l'accord manque, il faut pouvoir le donner ; et dès que
/// l'enregistrement tourne, personne ne doit pouvoir l'oublier.
class OrientationRecordingBanner extends StatefulWidget {
  final String sessionId;
  final bool isHost;

  const OrientationRecordingBanner({
    super.key,
    required this.sessionId,
    required this.isHost,
  });

  @override
  State<OrientationRecordingBanner> createState() =>
      _OrientationRecordingBannerState();
}

class _OrientationRecordingBannerState
    extends State<OrientationRecordingBanner> {
  Map<String, dynamic>? _etat;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _rafraichir());
  }

  Future<void> _rafraichir() async {
    final etat = await context
        .read<OrientationProvider>()
        .recordingState(widget.sessionId);
    if (!mounted) return;
    setState(() => _etat = etat);
  }

  Future<void> _consentir(bool accord) async {
    setState(() => _enCours = true);
    final etat = await context
        .read<OrientationProvider>()
        .setRecordingConsent(widget.sessionId, accord);
    if (!mounted) return;
    setState(() {
      _etat = etat ?? _etat;
      _enCours = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final etat = _etat;
    if (etat == null || etat['success'] != true) return const SizedBox.shrink();

    final autorise = etat['enregistrement_autorise'] == true;
    final monAccord = widget.isHost
        ? etat['accord_conseiller'] == true
        : etat['accord_eleve'] == true;

    // L'enregistrement tourne : le bandeau devient une alerte permanente.
    if (autorise) {
      return _cadre(
        couleur: const Color(0xFFE14D4D),
        contenu: Row(
          children: [
            const Icon(Icons.fiber_manual_record, size: 13, color: Colors.white),
            const SizedBox(width: 7),
            const Expanded(
              child: Text(
                'Cet entretien est enregistré, avec l\'accord des deux parties.',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: _enCours ? null : () => _consentir(false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Retirer mon accord',
                  style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      );
    }

    // Personne n'a rien demandé : on ne sollicite pas l'élève d'office.
    if (!widget.isHost && etat['accord_conseiller'] != true) {
      return const SizedBox.shrink();
    }

    if (monAccord) {
      return _cadre(
        couleur: const Color(0xFF5C6270),
        contenu: const Row(
          children: [
            Icon(Icons.hourglass_empty, size: 13, color: Colors.white70),
            SizedBox(width: 7),
            Expanded(
              child: Text(
                'Votre accord est enregistré. L\'enregistrement démarrera '
                'quand l\'autre partie aura donné le sien.',
                style: TextStyle(color: Colors.white70, fontSize: 11.5),
              ),
            ),
          ],
        ),
      );
    }

    return _cadre(
      couleur: const Color(0xFFF0A020),
      contenu: Row(
        children: [
          const Icon(Icons.mic_none, size: 14, color: Colors.white),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              widget.isHost
                  ? 'Enregistrer cet entretien ? L\'élève devra aussi donner '
                      'son accord.'
                  : 'Le conseiller souhaite enregistrer cet entretien. '
                      'Acceptez-vous ?',
              style: const TextStyle(color: Colors.white, fontSize: 11.5),
            ),
          ),
          TextButton(
            onPressed: _enCours ? null : () => _consentir(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('J\'accepte', style: TextStyle(fontSize: 11.5)),
          ),
        ],
      ),
    );
  }

  Widget _cadre({required Color couleur, required Widget contenu}) => Container(
        width: double.infinity,
        color: couleur,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: contenu,
      );
}
