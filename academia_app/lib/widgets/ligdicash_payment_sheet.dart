import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/ligdicash_provider.dart';

/// Bottom sheet réutilisable pour paiement LigdiCash OTP.
///
/// Usage :
/// ```dart
/// LigdiCashPaymentSheet.show(
///   context: context,
///   paymentType: 'application',
///   paymentId: paymentUuid,
///   amount: 25000,
///   description: 'Frais de dossier',
///   onSuccess: (receiptNumber) { /* reload, navigate, etc. */ },
/// );
/// ```
class LigdiCashPaymentSheet extends StatefulWidget {
  final String paymentType;
  final String paymentId;
  final double amount;
  final String currency;
  final String description;
  final VoidCallback? onSuccess;

  const LigdiCashPaymentSheet({
    super.key,
    required this.paymentType,
    required this.paymentId,
    required this.amount,
    this.currency = 'XOF',
    required this.description,
    this.onSuccess,
  });

  /// Ouvre le bottom sheet de paiement.
  static Future<void> show({
    required BuildContext context,
    required String paymentType,
    required String paymentId,
    required double amount,
    String currency = 'XOF',
    required String description,
    VoidCallback? onSuccess,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider(
        create: (_) => LigdiCashProvider(),
        child: LigdiCashPaymentSheet(
          paymentType: paymentType,
          paymentId: paymentId,
          amount: amount,
          currency: currency,
          description: description,
          onSuccess: onSuccess,
        ),
      ),
    );
  }

  @override
  State<LigdiCashPaymentSheet> createState() => _LigdiCashPaymentSheetState();
}

class _LigdiCashPaymentSheetState extends State<LigdiCashPaymentSheet> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  String _selectedOperator = '';

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Consumer<LigdiCashProvider>(
      builder: (context, provider, _) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: 16 + bottomInset,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1EA75C).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.payment, color: Color(0xFF1EA75C), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Paiement sécurisé',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          Text(widget.description,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Amount card
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1EA75C), Color(0xFF16A34A)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${widget.amount.toStringAsFixed(0)} ${widget.currency}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Content based on state
                if (provider.state == LigdiCashState.success)
                  _buildSuccessView(provider)
                else if (provider.state == LigdiCashState.waitingOtp)
                  _buildOtpView(provider)
                else
                  _buildPhoneView(provider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhoneView(LigdiCashProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Choisir l\'opérateur',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(
          children: [
            _operatorChip('Orange Money', 'orange', const Color(0xFFFF6600)),
            const SizedBox(width: 8),
            _operatorChip('Moov Money', 'moov', const Color(0xFF0066CC)),
            const SizedBox(width: 8),
            _operatorChip('Telecel', 'telecel', const Color(0xFF00AA44)),
          ],
        ),
        const SizedBox(height: 16),

        const Text('Numéro mobile money',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: '226 7X XX XX XX',
            prefixIcon: const Icon(Icons.phone_android),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 8),
        Text(
          'Entrez votre numéro avec l\'indicatif pays (226)',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),

        if (provider.error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(provider.error!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
          ),
        ],

        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: provider.isLoading
                ? null
                : () {
                    final phone = _phoneController.text.trim();
                    if (phone.length < 10) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Numéro invalide. Min 10 chiffres.')),
                      );
                      return;
                    }
                    provider.initiatePayment(
                      paymentType: widget.paymentType,
                      paymentId: widget.paymentId,
                      phoneNumber: phone,
                    );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1EA75C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: provider.state == LigdiCashState.sendingOtp
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Envoyer le code OTP',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 12),
        _securityBadge(),
      ],
    );
  }

  Widget _buildOtpView(LigdiCashProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.sms, color: Color(0xFF16A34A), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  provider.message ?? 'Un code OTP a été envoyé à votre téléphone.',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF166534)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text('Saisissez le code reçu par SMS',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 12),
          decoration: InputDecoration(
            hintText: '• • • • • •',
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),

        if (provider.error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(provider.error!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: provider.isLoading
                ? null
                : () {
                    final otp = _otpController.text.trim();
                    if (otp.length < 4) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Saisissez le code OTP complet.')),
                      );
                      return;
                    }
                    provider.confirmOtp(otp);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1EA75C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: provider.state == LigdiCashState.confirming
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Confirmer le paiement',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: provider.isLoading ? null : () => provider.retryOtp(),
          child: const Text('Renvoyer le code', style: TextStyle(fontSize: 13)),
        ),
        _securityBadge(),
      ],
    );
  }

  Widget _buildSuccessView(LigdiCashProvider provider) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: Color(0xFFDCFCE7),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 48),
        ),
        const SizedBox(height: 16),
        const Text('Paiement confirmé !',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF166534))),
        const SizedBox(height: 8),
        Text(
          '${widget.amount.toStringAsFixed(0)} ${widget.currency}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(widget.description,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        if (provider.receiptNumber != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Reçu : ${provider.receiptNumber}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
            ),
          ),
        ],
        if (provider.mode == 'mock') ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('Mode test',
                style: TextStyle(fontSize: 11, color: Color(0xFFB45309))),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onSuccess?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1EA75C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text('Continuer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _operatorChip(String label, String key, Color color) {
    final isSelected = _selectedOperator == key;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedOperator = key);
          // Auto-prefix le numéro selon l'opérateur
          if (_phoneController.text.isEmpty) {
            _phoneController.text = '226';
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(Icons.phone_android, color: isSelected ? color : Colors.grey, size: 20),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? color : Colors.grey.shade700,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _securityBadge() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Text('Paiement sécurisé par LigdiCash',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
