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
  final String phone;
  final String whatsappPhone;

  const ApplicationRequestData({
    this.requestedDegreeLevel,
    this.requestedStudyMode,
    this.requestedSchedule,
    required this.discountRequested,
    this.discountDetails,
    this.studentComment,
    required this.phone,
    required this.whatsappPhone,
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
    barrierDismissible: false,
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
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _whatsappPhoneController = TextEditingController();

  // La demande de courtage est cochée par défaut : toute candidature passe
  // par le courtage, et le taux de réduction est un champ attendu par
  // l'administrateur pour négocier avec l'université.
  bool _discountRequested = true;

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
    _phoneController.dispose();
    _whatsappPhoneController.dispose();
    super.dispose();
  }

  void _submit() {
    final degree = _degreeController.text.trim();
    final mode = _modeController.text.trim();
    final schedule = _scheduleController.text.trim();
    final discountDetails = _discountDetailsController.text.trim();
    final comment = _commentController.text.trim();
    final phone = _phoneController.text.trim();
    final whatsappPhone = _whatsappPhoneController.text.trim();

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
            'Merci d\'indiquer le pourcentage de réduction souhaité (ex : 30%).',
          ),
        ),
      );
      return;
    }

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merci d\'indiquer votre numéro de téléphone.'),
        ),
      );
      return;
    }

    if (_digitsOf(phone).length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Le numéro de téléphone doit contenir au moins 8 chiffres.',
          ),
        ),
      );
      return;
    }

    if (whatsappPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merci d\'indiquer votre numéro WhatsApp.'),
        ),
      );
      return;
    }

    if (_digitsOf(whatsappPhone).length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Le numéro WhatsApp doit contenir au moins 8 chiffres.',
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
      phone: phone,
      whatsappPhone: whatsappPhone,
    );

    Navigator.of(context).pop(data);
  }

  String _digitsOf(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

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
                    'Précise tes préférences pour cette candidature.',
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
                  hint: 'Ex : Licence 1, Master 2, BTS',
                  label: 'Niveau souhaité (Licence, Master, BTS…)',
                  icon: Icons.school_outlined,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _modeController,
                  hint: 'Ex : Présentiel, En ligne, Hybride',
                  label: 'Mode de suivi (présentiel, en ligne ou hybride)',
                  icon: Icons.access_time_outlined,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _scheduleController,
                  hint: 'Ex : Lundi-vendredi, matinée 8h-12h',
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
                      'Demande de réduction des frais de scolarité',
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
                    hint: 'Ex : 25%, 30%, 50%',
                    label: 'Pourcentage de réduction souhaité (Obligatoire)',
                    icon: Icons.payments_outlined,
                    maxLines: 2,
                  ),
                ],
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _commentController,
                  hint: 'Ex : Je souhaite commencer à la rentrée de janvier',
                  label: 'Message ou précision (facultatif)',
                  icon: Icons.comment_outlined,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _phoneController,
                  label: 'Numéro de téléphone (Obligatoire)',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _whatsappPhoneController,
                  label: 'Numéro WhatsApp (Obligatoire)',
                  icon: Icons.chat_outlined,
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
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
        keyboardType: keyboardType,
        scrollPadding: const EdgeInsets.only(bottom: 140),
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
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
