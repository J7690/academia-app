import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../providers/student_profile_provider.dart';
import 'dossier_fields.dart';

/// Ouvre le formulaire de complétion du dossier, sans quitter l'écran courant.
///
/// Rend `true` quand l'étudiant peut poursuivre sa candidature, c'est-à-dire
/// si le SERVEUR confirme que le dossier est complet — ou si la vérification
/// n'a pas pu aboutir, auquel cas c'est l'envoi qui tranchera. Rend `false`
/// si l'étudiant a refermé le formulaire.
///
/// [profileProvider] est passé explicitement plutôt que lu depuis le contexte
/// de la feuille : celle-ci vit dans une route à part, et une dépendance
/// nommée vaut mieux qu'une résolution implicite qui casserait en silence.
Future<bool> showDossierCompletionSheet(
  BuildContext context, {
  required StudentProfileProvider profileProvider,
  required List<String> missingFields,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _DossierCompletionSheet(
      profileProvider: profileProvider,
      missingFields: missingFields,
    ),
  );
  return result ?? false;
}

class _DossierCompletionSheet extends StatefulWidget {
  final StudentProfileProvider profileProvider;
  final List<String> missingFields;

  const _DossierCompletionSheet({
    required this.profileProvider,
    required this.missingFields,
  });

  @override
  State<_DossierCompletionSheet> createState() =>
      _DossierCompletionSheetState();
}

class _DossierCompletionSheetState extends State<_DossierCompletionSheet> {
  static const Color _primary = Color(0xFF3275D0);
  static const Color _ink = Color(0xFF0A2540);
  static const Color _muted = Color(0xFF6B7280);

  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  final Map<String, String> _choices = <String, String>{};

  List<DossierStep> _steps = const <DossierStep>[];
  List<String> _unsupported = const <String>[];
  int _index = 0;
  bool _saving = false;
  String? _stepError;
  String? _banner;

  @override
  void initState() {
    super.initState();
    _applyMissingFields(widget.missingFields);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// (Re)construit le formulaire à partir de ce que le serveur signale.
  /// Appelé à l'ouverture, puis après chaque enregistrement encore incomplet.
  void _applyMissingFields(List<String> missingFields) {
    _steps = stepsForMissingFields(missingFields);
    _unsupported = unsupportedFields(missingFields);
    for (final step in _steps) {
      for (final field in step.fields) {
        if (field.kind != DossierFieldKind.mention) {
          _controllers.putIfAbsent(field.key, () => TextEditingController());
        }
      }
    }
    if (_index >= _steps.length) {
      _index = _steps.isEmpty ? 0 : _steps.length - 1;
    }
  }

  bool get _isLastStep => _index >= _steps.length - 1;

  String? _valueOf(DossierField field) {
    if (field.kind == DossierFieldKind.mention) {
      return _choices[field.key];
    }
    final text = _controllers[field.key]?.text.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  /// Ce que l'on transmet au serveur pour une colonne donnée.
  ///
  /// `null` si le champ n'est pas affiché : `app_student_update_full_profile`
  /// applique un COALESCE, une valeur nulle laisse donc l'existant intact.
  String? _text(String key) {
    final controller = _controllers[key];
    if (controller == null) return null;
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  int? _int(String key) {
    final text = _text(key);
    return text == null ? null : int.tryParse(text);
  }

  String? _choice(String key) => _choices[key];

  /// Vérifie l'étape courante avant de laisser avancer.
  ///
  /// Les années sont bornées : le profil s'enregistre en COALESCE, une faute
  /// de frappe ne peut plus être effacée ensuite, seulement écrasée.
  String? _validateCurrentStep() {
    final currentYear = DateTime.now().year;
    for (final field in _steps[_index].fields) {
      final value = _valueOf(field);
      if (value == null) {
        return 'Renseigne « ${field.label} » pour continuer.';
      }
      if (field.kind == DossierFieldKind.year) {
        final year = int.tryParse(value);
        if (year == null || year < 1950 || year > currentYear + 1) {
          return '« ${field.label} » doit être une année entre 1950 et ${currentYear + 1}.';
        }
      }
    }
    return null;
  }

  Future<void> _onPrimaryPressed() async {
    final error = _validateCurrentStep();
    if (error != null) {
      setState(() => _stepError = error);
      return;
    }
    setState(() => _stepError = null);

    if (!_isLastStep) {
      setState(() => _index += 1);
      return;
    }

    await _saveAndVerify();
  }

  Future<void> _saveAndVerify() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _banner = null;
    });

    final saved = await widget.profileProvider.updateProfile(
      fullName: _text('full_name'),
      dateOfBirth: _text('date_of_birth'),
      bepcYear: _int('bepc_year'),
      bepcInstitution: _text('bepc_institution'),
      bepcCountry: _text('bepc_country'),
      bepcMention: _choice('bepc_mention'),
      bacYear: _int('bac_year'),
      bacSeries: _text('bac_series'),
      bacMention: _choice('bac_mention'),
      bacInstitution: _text('bac_institution'),
      bacCountry: _text('bac_country'),
      studyProjectText: _text('study_project_text'),
    );
    if (!mounted) return;

    if (!saved) {
      setState(() {
        _saving = false;
        _banner = widget.profileProvider.error ??
            "Impossible d'enregistrer pour le moment. Réessaie.";
      });
      return;
    }

    // Enregistrer ne veut pas dire complet : `app_student_update_full_profile`
    // répond « succès » même s'il manque encore des champs. On redemande donc
    // au seul juge de la complétude avant de laisser passer.
    final status = await widget.profileProvider.checkDossier();
    if (!mounted) return;

    if (!status.verified || status.isComplete) {
      // Vérification impossible : on laisse avancer, l'envoi tranchera.
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _saving = false;
      _applyMissingFields(status.missingFields);
      _index = 0;
      _banner = _steps.isEmpty
          ? 'Ton dossier reste incomplet. Ouvre « Mon profil » pour le terminer.'
          : 'Il manque encore quelques informations.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = _steps.length;
    final canGoBack = _index > 0 && !_saving;

    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(total),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_banner != null) _buildBanner(_banner!),
                      if (_unsupported.isNotEmpty)
                        _buildBanner(
                          'Information supplémentaire demandée : '
                          '${_unsupported.map(dossierFieldLabel).join(', ')}. '
                          'Ouvre « Mon profil » pour la renseigner.',
                        ),
                      if (total > 0) ..._buildFields(),
                    ],
                  ),
                ),
              ),
              _buildActions(canGoBack: canGoBack, total: total),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int total) {
    final step = total > 0 ? _steps[_index] : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Avant de candidater',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Une seule fois : ces informations constituent ton dossier pour '
            "l'université. Tu n'auras pas à les redonner.",
            style: TextStyle(fontSize: 13, color: _muted),
          ),
          if (step != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    step.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ),
                Text(
                  'Étape ${_index + 1}/$total',
                  style: const TextStyle(fontSize: 13, color: _muted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (_index + 1) / total,
                minHeight: 6,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor: const AlwaysStoppedAnimation<Color>(_primary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 13, color: Color(0xFF92400E)),
      ),
    );
  }

  List<Widget> _buildFields() {
    final widgets = <Widget>[];
    for (final field in _steps[_index].fields) {
      widgets.add(const SizedBox(height: 12));
      widgets.add(_buildField(field));
    }
    if (_stepError != null) {
      widgets.add(const SizedBox(height: 12));
      widgets.add(Text(
        _stepError!,
        style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626)),
      ));
    }
    return widgets;
  }

  Widget _buildField(DossierField field) {
    switch (field.kind) {
      case DossierFieldKind.mention:
        return DropdownButtonFormField<String>(
          // `_choices` reste la source de vérité pour la validation ; le
          // champ n'a besoin que de sa valeur d'entrée, qu'il conserve
          // ensuite lui-même au fil des allers-retours entre étapes.
          key: ValueKey<String>(field.key),
          initialValue: _choices[field.key],
          isExpanded: true,
          decoration: InputDecoration(
            labelText: field.label,
            border: const OutlineInputBorder(),
          ),
          items: kMentionOptions
              .map((option) => DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  ))
              .toList(),
          onChanged: _saving
              ? null
              : (value) {
                  setState(() {
                    if (value == null) {
                      _choices.remove(field.key);
                    } else {
                      _choices[field.key] = value;
                    }
                  });
                },
        );

      case DossierFieldKind.date:
        return TextField(
          controller: _controllers[field.key],
          readOnly: true,
          enabled: !_saving,
          decoration: InputDecoration(
            labelText: field.label,
            hintText: 'AAAA-MM-JJ',
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.calendar_today),
          ),
          onTap: () => _pickDate(field),
        );

      case DossierFieldKind.year:
        return TextField(
          controller: _controllers[field.key],
          enabled: !_saving,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.hint,
            border: const OutlineInputBorder(),
          ),
        );

      case DossierFieldKind.longText:
        return TextField(
          controller: _controllers[field.key],
          enabled: !_saving,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.hint,
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        );

      case DossierFieldKind.text:
        return TextField(
          controller: _controllers[field.key],
          enabled: !_saving,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.hint,
            border: const OutlineInputBorder(),
          ),
        );
    }
  }

  Future<void> _pickDate(DossierField field) async {
    final controller = _controllers[field.key];
    if (controller == null) return;

    final now = DateTime.now();
    DateTime initialDate = DateTime(now.year - 18, now.month, now.day);
    final existing = DateTime.tryParse(controller.text.trim());
    if (existing != null) {
      initialDate = existing;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: field.label,
    );
    if (picked == null || !mounted) return;

    final y = picked.year.toString().padLeft(4, '0');
    final m = picked.month.toString().padLeft(2, '0');
    final d = picked.day.toString().padLeft(2, '0');
    setState(() => controller.text = '$y-$m-$d');
  }

  Widget _buildActions({required bool canGoBack, required int total}) {
    // Aucun champ corrigeable ici : la seule issue honnête est de le dire.
    if (total == 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Fermer'),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: [
          if (canGoBack)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() {
                  _index -= 1;
                  _stepError = null;
                }),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                ),
                child: const Text(
                  'Retour',
                  style: TextStyle(fontWeight: FontWeight.w600, color: _muted),
                ),
              ),
            ),
          if (canGoBack) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _saving ? null : _onPrimaryPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _isLastStep ? 'Enregistrer et candidater' : 'Continuer',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
