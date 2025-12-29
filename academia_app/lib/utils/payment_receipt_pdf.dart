import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

Future<void> generateAndSharePaymentReceiptPdf({
  required Map<String, dynamic> payment,
  required Map<String, dynamic> receipt,
}) async {
  final doc = pw.Document();
  final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  String _string(dynamic value) => value?.toString() ?? '';

  final receiptNumber = _string(receipt['receipt_number']);
  final issuedAtRaw = receipt['issued_at'];
  String issuedAtStr;
  if (issuedAtRaw is DateTime) {
    issuedAtStr = dateFormat.format(issuedAtRaw);
  } else {
    final parsed = DateTime.tryParse(_string(issuedAtRaw));
    issuedAtStr = parsed != null ? dateFormat.format(parsed) : _string(issuedAtRaw);
  }

  final amountDue = _string(payment['amount_due']);
  final amountPaid = _string(payment['amount_paid']);
  final currency = _string(payment['currency'].toString().isEmpty ? 'XOF' : payment['currency']);
  final channel = _string(payment['channel']);
  final refCode = _string(payment['reference_code']);
  final extRef = _string(payment['external_reference']);
  final programTitle = _string(payment['program_title']);
  final universityName = _string(payment['university_name']);
  final studentId = _string(payment['student_id']);

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Reçu de paiement',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text('Reçu n° $receiptNumber'),
            pw.Text('Émis le $issuedAtStr'),
            pw.SizedBox(height: 16),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text(
              'Informations établissement',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            if (programTitle.isNotEmpty)
              pw.Text('Programme : $programTitle'),
            if (universityName.isNotEmpty)
              pw.Text('Université : $universityName'),
            pw.SizedBox(height: 12),
            pw.Text(
              'Informations étudiant',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            if (studentId.isNotEmpty)
              pw.Text('Identifiant étudiant : $studentId'),
            pw.SizedBox(height: 12),
            pw.Text(
              'Détails du paiement',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            if (amountDue.isNotEmpty)
              pw.Text('Montant dû : $amountDue $currency'),
            if (amountPaid.isNotEmpty)
              pw.Text('Montant payé : $amountPaid $currency'),
            if (channel.isNotEmpty)
              pw.Text('Canal : $channel'),
            if (refCode.isNotEmpty)
              pw.Text('Référence paiement : $refCode'),
            if (extRef.isNotEmpty)
              pw.Text('Référence opérateur : $extRef'),
            pw.SizedBox(height: 24),
            pw.Text(
              'Ce reçu a été généré automatiquement par la plateforme Academia.',
              style: pw.TextStyle(fontSize: 10),
            ),
            pw.Text(
              'Il sert de justificatif de paiement et ne peut pas être modifié.',
              style: pw.TextStyle(fontSize: 10),
            ),
          ],
        );
      },
    ),
  );

  final Uint8List bytes = await doc.save();

  await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => bytes,
    name: 'recu_$receiptNumber.pdf',
  );
}
