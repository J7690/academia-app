import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Bandeau de la console : « aucun téléphone ne reçoit vos alertes ».
///
/// Du 10/09 au 29/10/2026, le compte administrateur n'avait plus aucun
/// téléphone relié — l'appareil avait été repris par un compte étudiant — et
/// les alertes support, comptes, candidatures partaient dans le vide sans que
/// rien ne le signale. Ce bandeau rend la panne visible le jour même.
///
/// Silencieux tant qu'un téléphone est relié et que le dernier courriel de
/// secours n'a pas échoué. Silencieux aussi si la lecture échoue : un
/// avertissement ne doit jamais bloquer la console.
///
/// VALEUR COUPLÉE : clés du jsonb renvoyé par `app_admin_etat_alertes`
/// (migration 20261029200000).
class AdminAlertesBandeau extends StatefulWidget {
  const AdminAlertesBandeau({super.key});

  @override
  State<AdminAlertesBandeau> createState() => _AdminAlertesBandeauState();
}

class _AdminAlertesBandeauState extends State<AdminAlertesBandeau> {
  Map<String, dynamic>? _etat;
  bool _masque = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final res =
          await Supabase.instance.client.rpc('app_admin_etat_alertes');
      if (!mounted || res is! Map) return;
      setState(() => _etat = Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('[ALERTES] état non lu : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final etat = _etat;
    if (etat == null || _masque) return const SizedBox.shrink();

    final telephones = (etat['telephones'] as num?)?.toInt() ?? 0;
    final courriel = etat['courriel'] as String?;
    final dernier = etat['dernier_courriel'] as Map?;
    final courrielEnEchec = dernier?['statut'] == 'echec';

    if (telephones > 0 && !courrielEnEchec) return const SizedBox.shrink();

    final lignes = <String>[
      if (telephones == 0)
        'Aucun téléphone ne reçoit vos alertes administrateur. '
            'Ouvrez l\'application mobile et connectez-vous avec ce compte.',
      if (telephones == 0 && courriel != null && dernier == null)
        'La copie par courriel ($courriel) n\'a encore jamais été envoyée.',
      if (courrielEnEchec)
        'Le dernier courriel d\'alerte a échoué : ${dernier?['erreur'] ?? 'raison inconnue'}',
    ];

    return Material(
      color: const Color(0xFFFFF4E5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.notifications_off_outlined,
                  color: Color(0xFFE02018)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                lignes.join('\n'),
                style: const TextStyle(color: Color(0xFF7A2E0E), height: 1.35),
              ),
            ),
            IconButton(
              tooltip: 'Masquer',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _masque = true),
            ),
          ],
        ),
      ),
    );
  }
}
