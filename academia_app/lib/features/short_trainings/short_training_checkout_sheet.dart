import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/ligdicash_payment_sheet.dart';
import '../auth/phone_rules.dart';
import 'short_training_links.dart';

const Color _kGreen = Color(0xFF1EA75C);
const Color _kNavy = Color(0xFF0A2540);
const Color _kGrey = Color(0xFF6B7280);

/// Numéro Mobile Money de Nexiom Group, affiché sur les affiches (Jocelyn, 27/10).
const String kNexiomMobileMoney = '66 66 05 38';
const String kNexiomPhone = '73 93 43 92';

/// « Payer, c'est s'inscrire » — le formulaire UNIQUE des formations courtes.
///
/// Le même composant sert la page publique (sans compte), l'accueil connecté et
/// la rangée mobile. Trois étapes :
///   1. identité — seulement sans session : nom, téléphone et un code à 6
///      chiffres qui devient le mot de passe du compte, créé dans la foulée par
///      `signUp(phone:, password:)` (même parcours que [PhoneSignupScreen]) ;
///      un numéro déjà inscrit bascule sur la connexion ;
///   2. paiement — LigdiCash tout de suite, ou Mobile Money déjà envoyé au
///      66 66 05 38 avec sa référence, ou espèces au siège ;
///   3. résultat — place confirmée (reçu dans Documents) ou en vérification.
///
/// Rien n'est réservé sans paiement : `app_short_training_checkout` ne tient la
/// place que le temps du paiement (30 min LigdiCash, 48 h Mobile Money déclaré),
/// et lit le montant côté serveur.
///
/// Le changement de session ne ferme pas la feuille : `AuthWrapper` ne fait que
/// reconstruire l'écran du dessous, la route modale reste au-dessus.
class ShortTrainingCheckoutSheet extends StatefulWidget {
  const ShortTrainingCheckoutSheet({
    super.key,
    required this.session,
    this.onChanged,
  });

  /// Une ligne de `app_list_public_short_training_sessions` (ou de
  /// `app_list_my_short_trainings` : seuls `session_id`, `title`, `price`,
  /// les dates et les lieux sont lus).
  final Map<String, dynamic> session;

  /// Appelé après toute inscription ou paiement, pour rafraîchir les listes.
  final VoidCallback? onChanged;

  static Future<void> show(
    BuildContext context,
    Map<String, dynamic> session, {
    VoidCallback? onChanged,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShortTrainingCheckoutSheet(session: session, onChanged: onChanged),
    );
  }

  @override
  State<ShortTrainingCheckoutSheet> createState() => _ShortTrainingCheckoutSheetState();
}

enum _Etape { identite, paiement, mobileMoney, especes, resultat }

class _ShortTrainingCheckoutSheetState extends State<ShortTrainingCheckoutSheet> {
  final _client = Supabase.instance.client;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _codeConfirmController = TextEditingController();
  final _txController = TextEditingController();

  late _Etape _etape;
  bool _compteExistant = false;
  bool _busy = false;
  String? _error;
  String? _info;
  String _operator = 'orange_money';

  // Résultat
  bool _confirme = false;
  String? _resultMessage;

  Map<String, dynamic> get _s => widget.session;
  String get _sessionId => _s['session_id']?.toString() ?? '';
  String get _title => _s['title']?.toString() ?? 'Formation';
  num get _price => (_s['price'] is num) ? _s['price'] as num : num.tryParse('${_s['price']}') ?? 0;

  @override
  void initState() {
    super.initState();
    _etape = _client.auth.currentUser == null ? _Etape.identite : _Etape.paiement;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _codeConfirmController.dispose();
    _txController.dispose();
    super.dispose();
  }

  // ─── Identité ────────────────────────────────────────────────────────────

  Future<void> _submitIdentite() async {
    final phoneCheck = checkPhoneNumber(_phoneController.text, kBurkinaFaso);
    final code = _codeController.text.trim();
    if (!phoneCheck.isValid) {
      setState(() => _error = phoneCheck.error);
      return;
    }

    if (_compteExistant) {
      if (code.isEmpty) {
        setState(() => _error = 'Saisissez votre code ou votre mot de passe.');
        return;
      }
      setState(() { _busy = true; _error = null; _info = null; });
      try {
        await _client.auth.signInWithPassword(phone: phoneCheck.e164!, password: code);
        if (!mounted) return;
        setState(() => _etape = _Etape.paiement);
      } on AuthException catch (_) {
        setState(() => _error = 'Numéro ou code incorrect.');
      } catch (_) {
        setState(() => _error = 'Erreur réseau. Vérifiez votre connexion.');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    if (firstName.isEmpty || lastName.isEmpty) {
      setState(() => _error = 'Saisissez votre prénom et votre nom.');
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Le code doit compter exactement 6 chiffres.');
      return;
    }
    if (code != _codeConfirmController.text.trim()) {
      setState(() => _error = 'Les deux codes ne sont pas identiques.');
      return;
    }

    setState(() { _busy = true; _error = null; _info = null; });
    final fullName = '$firstName $lastName';
    try {
      final data = <String, dynamic>{'role': 'student', 'full_name': fullName};
      try {
        final src = Uri.base.queryParameters['src'];
        if (src != null && src.trim().isNotEmpty) data['mkt_ref'] = src.trim();
      } catch (_) {}

      final response = await _client.auth.signUp(
        phone: phoneCheck.e164!,
        password: code,
        data: data,
      );
      if (response.session == null) {
        setState(() {
          _compteExistant = true;
          _error = 'Votre compte a été créé, mais la connexion automatique n\'a pas '
              'abouti. Saisissez votre code pour vous connecter.';
        });
        return;
      }
      // Le nom envoyé dans `data` n'arrive pas (mesuré le 04/09, cf.
      // PhoneSignupScreen) : on l'écrit nous-mêmes, sans bloquer si ça échoue.
      try {
        await _client.rpc('app_student_update_full_profile', params: {'p_full_name': fullName});
      } catch (e) {
        debugPrint('[FormationCourte] nom non enregistré ($e) — compte créé malgré tout.');
      }
      if (!mounted) return;
      setState(() => _etape = _Etape.paiement);
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('already') || m.contains('registered') || m.contains('exists')) {
        setState(() {
          _compteExistant = true;
          _codeController.clear();
          _info = 'Ce numéro a déjà un compte Academia. Saisissez votre code '
              'ou votre mot de passe pour continuer.';
        });
      } else if (m.contains('password')) {
        setState(() => _error = 'Code refusé : choisissez 6 chiffres moins simples.');
      } else {
        setState(() => _error = 'Création du compte impossible : ${e.message}');
      }
    } catch (_) {
      setState(() => _error = 'Erreur réseau. Vérifiez votre connexion.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ─── Paiement ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _checkout(String method, {String? operator, String? tx}) async {
    setState(() { _busy = true; _error = null; _info = null; });
    try {
      final res = await _client.rpc('app_short_training_checkout', params: {
        'p_session_id': _sessionId,
        'p_method': method,
        'p_operator': operator,
        'p_transaction_ref': tx,
      });
      final data = res is Map ? Map<String, dynamic>.from(res) : null;
      if (data == null) {
        setState(() => _error = 'Réponse inattendue du serveur.');
        return null;
      }
      if (data['success'] != true) {
        setState(() => _error = data['message']?.toString() ?? 'Inscription impossible (${data['error']}).');
        return null;
      }
      return data;
    } catch (e) {
      debugPrint('[FormationCourte] checkout $method : $e');
      setState(() => _error = 'Erreur réseau. Vérifiez votre connexion et réessayez.');
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _payerLigdiCash() async {
    final data = await _checkout('ligdicash');
    if (data == null || !mounted) return;
    if (data['deja_inscrit'] == true) {
      _terminer(true, data['message']?.toString());
      return;
    }
    final paymentId = data['payment_id']?.toString() ?? '';
    final amount = (data['amount'] is num) ? (data['amount'] as num).toDouble() : _price.toDouble();
    widget.onChanged?.call();

    await LigdiCashPaymentSheet.show(
      context: context,
      paymentType: 'short_training',
      paymentId: paymentId,
      amount: amount,
      description: 'Formation : $_title',
    );
    if (!mounted) return;
    await _relireStatut();
  }

  /// Après la feuille LigdiCash : la confirmation est faite par le serveur
  /// (déclencheur sur le paiement) ; on se contente de LIRE où on en est.
  Future<void> _relireStatut() async {
    setState(() => _busy = true);
    try {
      final res = await _client.rpc('app_list_my_short_trainings');
      final list = (res as List?) ?? const [];
      final reg = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => e['session_id']?.toString() == _sessionId)
          .cast<Map<String, dynamic>?>()
          .firstWhere((_) => true, orElse: () => null);
      widget.onChanged?.call();
      if (reg != null && reg['status'] == 'confirmed') {
        final recu = reg['receipt_number']?.toString();
        _terminer(true, recu == null ? null : 'Reçu n° $recu');
      } else if (reg != null && reg['payment_status'] == 'processing') {
        _terminer(false,
            'Votre paiement est en cours de traitement par l\'opérateur. '
            'Votre place sera confirmée dès réception — vous serez notifié(e).');
      } else {
        setState(() => _info = 'Le paiement n\'a pas abouti. Vous pouvez réessayer.');
      }
    } catch (_) {
      _terminer(false, 'Nous vérifions votre paiement. Revenez dans quelques minutes.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _declarerMobileMoney() async {
    final tx = _txController.text.trim();
    if (tx.length < 6) {
      setState(() => _error = 'Saisissez la référence de transaction reçue par SMS.');
      return;
    }
    final data = await _checkout('mobile_money', operator: _operator, tx: tx);
    if (data == null || !mounted) return;
    widget.onChanged?.call();
    if (data['deja_inscrit'] == true) {
      _terminer(true, data['message']?.toString());
      return;
    }
    _terminer(false,
        'Paiement déclaré. L\'équipe Nexiom vérifie la transaction ; votre place '
        'est tenue pendant 48 h. Dès validation, votre reçu apparaît dans Documents.');
  }

  void _terminer(bool confirme, String? message) {
    setState(() {
      _confirme = confirme;
      _resultMessage = message;
      _etape = _Etape.resultat;
      _error = null;
      _info = null;
    });
  }

  // ─── Affichage ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                _entete(),
                const SizedBox(height: 16),
                if (_error != null) _bandeau(_error!, const Color(0xFFFEF2F2), const Color(0xFFB91C1C)),
                if (_info != null) _bandeau(_info!, const Color(0xFFEFF6FF), const Color(0xFF1D4ED8)),
                switch (_etape) {
                  _Etape.identite => _vueIdentite(),
                  _Etape.paiement => _vuePaiement(),
                  _Etape.mobileMoney => _vueMobileMoney(),
                  _Etape.especes => _vueEspeces(),
                  _Etape.resultat => _vueResultat(),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _entete() {
    final organizer = _s['organizer_name']?.toString() ?? 'Nexiom Group';
    final dates = formatShortTrainingDates(_s['start_at'], _s['end_at']);
    final accueil = (_s['welcome_location'] ?? _s['location'])?.toString() ?? '';
    final pratique = _s['practice_location']?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text(organizer.toUpperCase(),
                style: const TextStyle(fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w700, color: _kGreen)),
          ),
          if ((_s['slug'] ?? '').toString().isNotEmpty)
            IconButton(
              tooltip: 'Partager cette formation',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.ios_share_rounded, size: 20, color: _kNavy),
              onPressed: () => shareShortTraining(context, _s),
            ),
        ]),
        const SizedBox(height: 4),
        Text(_title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _kNavy)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            if (dates.isNotEmpty) _puce(Icons.event, dates),
            _puce(Icons.payments_outlined, formatFcfa(_price)),
            if (accueil.isNotEmpty) _puce(Icons.location_on_outlined, pratique.isEmpty ? accueil : 'Accueil : $accueil'),
            if (pratique.isNotEmpty) _puce(Icons.agriculture_outlined, 'Pratique : $pratique'),
          ],
        ),
      ],
    );
  }

  Widget _puce(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _kGrey),
          const SizedBox(width: 4),
          Flexible(child: Text(text, style: const TextStyle(fontSize: 13, color: _kNavy))),
        ],
      );

  Widget _bandeau(String text, Color bg, Color fg) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: TextStyle(fontSize: 13, color: fg)),
      );

  InputDecoration _champ(String label, {String? hint, String? prefix}) => InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
      );

  Widget _boutonPrincipal(String label, VoidCallback? onPressed) => SizedBox(
        height: 50,
        child: ElevatedButton(
          onPressed: _busy ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      );

  Widget _vueIdentite() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _compteExistant ? 'Connectez-vous pour continuer' : 'Vos coordonnées',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kNavy),
        ),
        const SizedBox(height: 4),
        Text(
          _compteExistant
              ? 'Votre reçu sera rattaché à votre compte Academia.'
              : 'Un compte Academia est créé avec votre numéro : vous y retrouverez votre reçu.',
          style: const TextStyle(fontSize: 12.5, color: _kGrey),
        ),
        const SizedBox(height: 14),
        if (!_compteExistant) ...[
          Row(children: [
            Expanded(child: TextField(controller: _firstNameController, textCapitalization: TextCapitalization.words, decoration: _champ('Prénom'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _lastNameController, textCapitalization: TextCapitalization.characters, decoration: _champ('Nom'))),
          ]),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]'))],
          decoration: _champ('Téléphone', hint: kBurkinaFaso.hint, prefix: '${kBurkinaFaso.dialPrefix} '),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _codeController,
          obscureText: true,
          keyboardType: _compteExistant ? TextInputType.visiblePassword : TextInputType.number,
          inputFormatters: _compteExistant ? null : [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          decoration: _champ(_compteExistant ? 'Code ou mot de passe' : 'Choisissez un code à 6 chiffres'),
        ),
        if (!_compteExistant) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _codeConfirmController,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            decoration: _champ('Confirmez le code'),
          ),
          const SizedBox(height: 6),
          const Text('Ce code vous servira à vous connecter à Academia avec votre numéro.',
              style: TextStyle(fontSize: 11.5, color: _kGrey)),
        ],
        const SizedBox(height: 16),
        _boutonPrincipal(_compteExistant ? 'Me connecter et continuer' : 'Continuer vers le paiement', _submitIdentite),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() { _compteExistant = !_compteExistant; _error = null; _info = null; }),
          child: Text(_compteExistant ? 'Je n\'ai pas de compte' : 'J\'ai déjà un compte Academia'),
        ),
      ],
    );
  }

  Widget _vuePaiement() {
    final benefits = (_s['benefits'] is List) ? (_s['benefits'] as List).map((e) => '$e').toList() : const <String>[];
    final seatsLeft = _s['seats_left'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (benefits.isNotEmpty) ...[
          const Text('Inclus après la formation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kNavy)),
          const SizedBox(height: 6),
          ...benefits.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.check_circle, size: 16, color: _kGreen),
                  const SizedBox(width: 6),
                  Expanded(child: Text(b, style: const TextStyle(fontSize: 13))),
                ]),
              )),
          const SizedBox(height: 12),
        ],
        if (seatsLeft is num && seatsLeft <= 10)
          _bandeau(seatsLeft <= 0 ? 'Session complète.' : 'Plus que ${seatsLeft.toInt()} place(s).',
              const Color(0xFFFFF7ED), const Color(0xFFC2410C)),
        const Text('Comment souhaitez-vous payer ?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kNavy)),
        const SizedBox(height: 10),
        _option(
          icon: Icons.phone_android,
          titre: 'Payer maintenant — ${formatFcfa(_price)}',
          detail: 'Orange Money ou Moov Money. Place confirmée et reçu immédiats.',
          mise: true,
          onTap: _payerLigdiCash,
        ),
        _option(
          icon: Icons.sms_outlined,
          titre: 'J\'ai envoyé l\'argent au $kNexiomMobileMoney',
          detail: 'Déclarez la référence reçue par SMS ; l\'équipe valide votre place.',
          onTap: () => setState(() { _etape = _Etape.mobileMoney; _error = null; }),
        ),
        _option(
          icon: Icons.storefront_outlined,
          titre: 'Payer en espèces au siège',
          detail: 'Siège de Nexiom Group à Tanghin.',
          onTap: () => setState(() { _etape = _Etape.especes; _error = null; }),
        ),
        const SizedBox(height: 6),
        const Text('Aucun remboursement après le début de la formation.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: _kGrey)),
      ],
    );
  }

  Widget _option({required IconData icon, required String titre, required String detail, required VoidCallback onTap, bool mise = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: mise ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _busy ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: mise ? _kGreen : const Color(0xFFE5E7EB), width: mise ? 1.6 : 1),
            ),
            child: Row(children: [
              Icon(icon, color: mise ? _kGreen : _kNavy),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(titre, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kNavy)),
                  const SizedBox(height: 2),
                  Text(detail, style: const TextStyle(fontSize: 12, color: _kGrey)),
                ]),
              ),
              if (_busy && mise)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              else
                const Icon(Icons.chevron_right, color: _kGrey),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _vueMobileMoney() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _bandeau(
          '1. Envoyez ${formatFcfa(_price)} au $kNexiomMobileMoney (Nexiom Group).\n'
          '2. Saisissez ci-dessous la référence de transaction reçue par SMS.',
          const Color(0xFFF0FDF4), const Color(0xFF166534),
        ),
        const Text('Opérateur utilisé', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          for (final op in const [('orange_money', 'Orange'), ('moov_money', 'Moov'), ('telecel_money', 'Telecel')])
            ChoiceChip(
              label: Text(op.$2),
              selected: _operator == op.$1,
              onSelected: (_) => setState(() => _operator = op.$1),
            ),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _txController,
          textCapitalization: TextCapitalization.characters,
          decoration: _champ('Référence de transaction', hint: 'Ex. PP231027.1234.A56789'),
        ),
        const SizedBox(height: 16),
        _boutonPrincipal('Déclarer mon paiement', _declarerMobileMoney),
        TextButton(
          onPressed: _busy ? null : () => setState(() { _etape = _Etape.paiement; _error = null; }),
          child: const Text('Retour'),
        ),
      ],
    );
  }

  Widget _vueEspeces() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _bandeau(
          'Présentez-vous au siège de Nexiom Group à Tanghin avec ${formatFcfa(_price)}. '
          'L\'équipe enregistre votre inscription sur place et vous remet votre reçu.',
          const Color(0xFFF8FAFC), _kNavy,
        ),
        OutlinedButton.icon(
          onPressed: () => launchUrl(Uri.parse('tel:+226${kNexiomPhone.replaceAll(' ', '')}')),
          icon: const Icon(Icons.call),
          label: const Text('Appeler le $kNexiomPhone'),
        ),
        TextButton(
          onPressed: () => setState(() => _etape = _Etape.paiement),
          child: const Text('Retour'),
        ),
      ],
    );
  }

  Widget _vueResultat() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(_confirme ? Icons.verified : Icons.hourglass_top,
            size: 56, color: _confirme ? _kGreen : const Color(0xFFEA580C)),
        const SizedBox(height: 10),
        Text(
          _confirme ? 'Votre place est confirmée' : 'Paiement en vérification',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _kNavy),
        ),
        const SizedBox(height: 8),
        Text(
          [
            if (_resultMessage != null) _resultMessage!,
            if (_confirme) 'Votre reçu est dans « Documents ». Présentez-le le jour de la formation.',
          ].join('\n'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13.5, color: _kGrey),
        ),
        const SizedBox(height: 18),
        _boutonPrincipal('Terminer', () => Navigator.of(context).pop()),
      ],
    );
  }
}

const List<String> _kMois = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

/// « 14 et 15 novembre 2026 », « du 30 novembre au 2 décembre 2026 », « 14 novembre 2026 ».
String formatShortTrainingDates(dynamic startRaw, dynamic endRaw) {
  final start = DateTime.tryParse(startRaw?.toString() ?? '')?.toLocal();
  if (start == null) return '';
  final end = DateTime.tryParse(endRaw?.toString() ?? '')?.toLocal();
  String jour(DateTime d) => '${d.day} ${_kMois[d.month - 1]}';
  if (end == null || DateUtils.isSameDay(start, end)) return '${jour(start)} ${start.year}';
  if (start.month == end.month && start.year == end.year) {
    final sep = end.day - start.day == 1 ? 'et' : 'au';
    return '${start.day} $sep ${end.day} ${_kMois[end.month - 1]} ${end.year}';
  }
  return 'du ${jour(start)} au ${jour(end)} ${end.year}';
}

/// 10000 → « 10 000 FCFA ».
String formatFcfa(num value) {
  final digits = value.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
    buf.write(digits[i]);
  }
  return '$buf FCFA';
}
