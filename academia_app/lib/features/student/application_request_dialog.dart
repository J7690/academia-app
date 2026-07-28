import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

import '../../widgets/adaptive_dialog.dart';

class ApplicationRequestData {
  final String? requestedDegreeLevel;
  final String? requestedStudyMode;
  final String? requestedSchedule;
  final bool discountRequested;
  final String? discountDetails;
  final String? studentComment;

  const ApplicationRequestData({
    this.requestedDegreeLevel,
    this.requestedStudyMode,
    this.requestedSchedule,
    required this.discountRequested,
    this.discountDetails,
    this.studentComment,
  });
}

Future<ApplicationRequestData?> showApplicationRequestDialog(
  BuildContext context, {
  String? programTitle,
  String? initialDegreeLevel,
  String? initialStudyMode,
}) {
  return showDialog<ApplicationRequestData>(
    context: context,
    useSafeArea: true,
    builder: (context) {
      return _ApplicationRequestDialog(
        programTitle: programTitle,
        initialDegreeLevel: initialDegreeLevel,
        initialStudyMode: initialStudyMode,
      );
    },
  );
}

class _ApplicationRequestDialog extends StatefulWidget {
  final String? programTitle;
  final String? initialDegreeLevel;
  final String? initialStudyMode;

  const _ApplicationRequestDialog({
    this.programTitle,
    this.initialDegreeLevel,
    this.initialStudyMode,
  });

  @override
  State<_ApplicationRequestDialog> createState() => _ApplicationRequestDialogState();
}

class _ApplicationRequestDialogState extends State<_ApplicationRequestDialog> {
  late final TextEditingController _degreeController;
  late final TextEditingController _modeController;
  final TextEditingController _scheduleController = TextEditingController();
  final TextEditingController _discountDetailsController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  bool _discountRequested = false;

  @override
  void initState() {
    super.initState();
    _degreeController = TextEditingController(text: widget.initialDegreeLevel ?? '');
    _modeController = TextEditingController(text: widget.initialStudyMode ?? '');
  }

  @override
  void dispose() {
    _degreeController.dispose();
    _modeController.dispose();
    _scheduleController.dispose();
    _discountDetailsController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    final degree = _degreeController.text.trim();
    final mode = _modeController.text.trim();
    final schedule = _scheduleController.text.trim();
    final discountDetails = _discountDetailsController.text.trim();
    final comment = _commentController.text.trim();

    if (degree.isEmpty && mode.isEmpty && schedule.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Merci d\'indiquer au moins un élément parmi le niveau, le mode ou les horaires souhaités.',
          ),
        ),
      );
      return;
    }

    if (_discountRequested && discountDetails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Merci de détailler votre demande de réduction / échelonnement des frais.',
          ),
        ),
      );
      return;
    }

    final data = ApplicationRequestData(
      requestedDegreeLevel: degree.isEmpty ? null : degree,
      requestedStudyMode: mode.isEmpty ? null : mode,
      requestedSchedule: schedule.isEmpty ? null : schedule,
      discountRequested: _discountRequested,
      discountDetails: discountDetails.isEmpty ? null : discountDetails,
      studentComment: comment.isEmpty ? null : comment,
    );

    Navigator.of(context).pop(data);
  }

  @override
  Widget build(BuildContext context) {
    // AdaptiveDialog remplace l'ancien Dialog à largeur fixe (90% écran) sans
    // limite de hauteur : sur petit téléphone avec clavier ouvert, les
    // boutons Annuler / Envoyer devenaient inatteignables. Ici la hauteur
    // s'adapte à l'espace réellement disponible et le contenu défile.
    return FadeInUp(
      duration: const Duration(milliseconds: 300),
      child: AdaptiveDialog(
        maxWidth: 520,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3275D0).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.edit_document,
                color: Color(0xFF3275D0),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.programTitle ?? 'Demande de candidature',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0A2540),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Merci de préciser quelques informations pour votre candidature.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Un seul élément d'action contenant les deux boutons : les
          // `Expanded` ont besoin d'un parent Row/Column direct. Le socle
          // AdaptiveDialog place les actions dans un `Wrap` (grand écran) qui
          // ne fournit pas cette contrainte — les mettre ici, dans notre
          // propre Row, évite le crash tout en gardant les deux boutons à
          // largeur égale.
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop(null);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      vertical: 16, horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  side: const BorderSide(
                    color: Color(0xFFE5E7EB),
                    width: 1.5,
                  ),
                ),
                child: const Text(
                  'Annuler',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      vertical: 16, horizontal: 20),
                  backgroundColor: const Color(0xFF3275D0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Envoyer la candidature',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
        child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInputField(
                  controller: _degreeController,
                  label: "Niveau d'étude souhaité",
                  icon: Icons.school_outlined,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _modeController,
                  label: "Mode d'étude souhaité (présentiel, en ligne, etc.)",
                  icon: Icons.access_time_outlined,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _scheduleController,
                  label: 'Disponibilités / horaires préférés',
                  icon: Icons.calendar_today_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3275D0).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF3275D0).withOpacity(0.15),
                    ),
                  ),
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _discountRequested,
                    onChanged: (value) {
                      setState(() {
                        _discountRequested = value ?? false;
                      });
                    },
                    title: const Text(
                      'Je souhaite demander une réduction ou un échelonnement des frais',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0A2540),
                      ),
                    ),
                  ),
                ),
                if (_discountRequested) ...[
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _discountDetailsController,
                    label: 'Détail de votre demande de réduction / échelonnement (situation, montant, etc.)',
                    icon: Icons.payments_outlined,
                    maxLines: 3,
                  ),
                ],
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _commentController,
                  label: "Commentaire pour l'université / l'équipe",
                  icon: Icons.comment_outlined,
                  maxLines: 3,
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          labelStyle: const TextStyle(
            color: Color(0xFF9CA3AF),
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
