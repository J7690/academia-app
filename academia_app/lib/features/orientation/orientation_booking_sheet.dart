import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/orientation_provider.dart';

/// Feuille de réservation d'un créneau d'orientation.
///
/// Extraite de `orientation_screen.dart` le 02/08/2026. Elle y cohabitait avec
/// `OrientationScreen`, écran devenu inatteignable — `auth_wrapper` route le
/// conseiller vers `CounselorDashboardScreen`, et l'étudiant vers
/// `StudentOrientationTab`. Supprimer le fichier aurait donc emporté cette
/// feuille, seule porte de réservation encore utilisée, et avec elle la case
/// de consentement à l'enregistrement.
///
/// C'est elle qui porte l'accord de l'élève : `consentRecording` remonte
/// jusqu'à `app_orientation_book(p_consent_recording)`. Sans cette case,
/// l'enregistrement d'un entretien ne peut jamais s'activer — le conseiller a
/// beau donner le sien, il en faut deux.
class OrientationBookingSheet extends StatefulWidget {
  final Map<String, dynamic> counselor;
  const OrientationBookingSheet({super.key, required this.counselor});

  @override
  State<OrientationBookingSheet> createState() => _OrientationBookingSheetState();
}

class _OrientationBookingSheetState extends State<OrientationBookingSheet> {
  final _motifCtrl = TextEditingController();
  DateTime? _selected;
  bool _accepteEnregistrement = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<OrientationProvider>()
          .loadSlots(widget.counselor['user_id'].toString());
    });
  }

  @override
  void dispose() {
    _motifCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_selected == null) return;
    final p = context.read<OrientationProvider>();
    final sessionId = await p.book(
      counselorId: widget.counselor['user_id'].toString(),
      slot: _selected!,
      motif: _motifCtrl.text.trim().isEmpty ? null : _motifCtrl.text.trim(),
      consentRecording: _accepteEnregistrement,
    );
    if (!mounted) return;
    if (sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(p.error ?? 'Réservation impossible.'),
          backgroundColor: const Color(0xFFE14D4D),
        ),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OrientationProvider>();
    final parJour = <String, List<DateTime>>{};
    for (final s in p.slots) {
      final local = s.toLocal();
      final key = '${local.year}-${local.month}-${local.day}';
      parJour.putIfAbsent(key, () => []).add(local);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F6F8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Choisir un créneau',
                            style: TextStyle(
                                fontSize: 16.5, fontWeight: FontWeight.w600)),
                        Text(
                          '${widget.counselor['full_name']} · ${p.slotDuration} min',
                          style: const TextStyle(
                              fontSize: 12.5, color: Color(0xFF5C6270)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
            Expanded(
              child: p.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : parJour.isEmpty
                      ? const _EmptyState(
                          icon: Icons.event_busy_outlined,
                          title: 'Aucun créneau disponible',
                          body: 'Ce conseiller n\'a pas de disponibilité sur '
                              'les deux prochaines semaines.',
                        )
                      : ListView(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: [
                            ...parJour.entries.map((e) {
                              final jour = e.value.first;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _Heading(_jourLabel(jour)),
                                  Wrap(
                                    spacing: 7,
                                    runSpacing: 7,
                                    children: e.value.map((s) {
                                      final sel = _selected == s;
                                      return ChoiceChip(
                                        label: Text(
                                            '${s.hour.toString().padLeft(2, '0')}h'
                                            '${s.minute.toString().padLeft(2, '0')}'),
                                        selected: sel,
                                        onSelected: (_) =>
                                            setState(() => _selected = s),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 6),
                                ],
                              );
                            }),
                            const _Heading('Votre question'),
                            _Card(
                              child: TextField(
                                controller: _motifCtrl,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText:
                                      'Décrivez ce qui vous préoccupe. Le conseiller '
                                      'préparera l\'entretien à partir de cela.',
                                  hintStyle: TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Accord préalable à l'enregistrement. Coupé par
                            // défaut : l'entretien reste privé tant que
                            // l'élève n'a rien accordé, et le conseiller doit
                            // de toute façon donner le sien.
                            CheckboxListTile(
                              value: _accepteEnregistrement,
                              onChanged: (v) => setState(
                                  () => _accepteEnregistrement = v ?? false),
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              activeColor: const Color(0xFF6C5CE7),
                              title: const Text(
                                'J\'accepte que l\'entretien soit enregistré',
                                style: TextStyle(fontSize: 13),
                              ),
                              subtitle: const Text(
                                'Pour pouvoir le réécouter. L\'enregistrement '
                                'ne démarrera que si le conseiller donne aussi '
                                'son accord, et un bandeau restera visible '
                                'pendant tout l\'entretien.',
                                style: TextStyle(fontSize: 11.5, height: 1.4),
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF6C5CE7),
                                minimumSize: const Size.fromHeight(48),
                              ),
                              onPressed: (_selected == null || p.isBooking)
                                  ? null
                                  : _confirm,
                              child: p.isBooking
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Text('Confirmer le rendez-vous'),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _accepteEnregistrement
                                  ? 'La consultation reste privée : seuls vous '
                                      'et le conseiller y avez accès.'
                                  : 'La consultation est privée et ne sera pas '
                                      'enregistrée.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF8A90A0)),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  static String _jourLabel(DateTime d) {
    const jours = [
      'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'
    ];
    const mois = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    return '${jours[d.weekday - 1]} ${d.day} ${mois[d.month - 1]}';
  }
}

// ─── Petits éléments de présentation ──────────────────────────────────
// Repris à l'identique de `orientation_screen.dart`, dont ils partageaient le
// fichier. Volontairement privés : ce sont des détails de cette feuille, pas
// une bibliothèque à réutiliser.

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                fontSize: 10.5,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8A90A0))),
      );
}

class _Card extends StatelessWidget {
  final Widget child;
  // `margin` et `border` existaient dans l'original pour d'autres appelants,
  // restés dans `orientation_screen.dart`. Ici la feuille n'en use pas : les
  // reprendre aurait laissé deux paramètres morts.
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E5EA)),
        ),
        child: child,
      );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _EmptyState(
      {required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, size: 40, color: const Color(0xFF8A90A0)),
            const SizedBox(height: 13),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, height: 1.5, color: Color(0xFF5C6270))),
          ],
        ),
      );
}
