import 'package:flutter/material.dart';

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
    return AlertDialog(
      title: Text(widget.programTitle ?? 'Demande de candidature'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Merci de préciser quelques informations pour votre candidature.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _degreeController,
              decoration: const InputDecoration(
                labelText: "Niveau d'étude souhaité",
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _modeController,
              decoration: const InputDecoration(
                labelText: "Mode d'étude souhaité (présentiel, en ligne, etc.)",
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _scheduleController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Disponibilités / horaires préférés',
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _discountRequested,
              onChanged: (value) {
                setState(() {
                  _discountRequested = value ?? false;
                });
              },
              title: const Text(
                'Je souhaite demander une réduction ou un échelonnement des frais',
              ),
            ),
            if (_discountRequested) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _discountDetailsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText:
                      'Détail de votre demande de réduction / échelonnement (situation, montant, etc.)',
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Commentaire pour l'université / l'équipe",
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(null);
          },
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Envoyer la candidature'),
        ),
      ],
    );
  }
}
