import 'dart:convert';
import 'dart:typed_data';

import 'package:academia_app/services/application_media_service.dart';
import 'package:academia_app/widgets/application_attachment_button.dart';
import 'package:academia_app/widgets/application_message_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
      'refuse les fichiers vides, trop volumineux et formats non pris en charge',
      () {
    expect(() => ApplicationMediaFile.fromBytes(Uint8List(0), 'test.jpg'),
        throwsFormatException);
    expect(
        () => ApplicationMediaFile.fromBytes(
            Uint8List(ApplicationMediaFile.maxBytes + 1), 'test.mp4'),
        throwsFormatException);
    expect(() => ApplicationMediaFile.fromBytes(Uint8List(1), 'test.html'),
        throwsFormatException);
    expect(() => ApplicationMediaFile.fromBytes(Uint8List(1), 'test.svg'),
        throwsFormatException);
    expect(ApplicationMediaFile.fromBytes(Uint8List(1), 'TEST.JPG').mime,
        'image/jpeg');
    expect(
        ApplicationMediaFile.fromBytes(Uint8List(1), 'test.m4a').type, 'audio');
  });

  test('le WAV conserve tous les échantillons et indique le bon format PCM',
      () {
    final pcm = Uint8List.fromList([0, 1, 2, 3]);
    final wav = applicationVoiceWav(pcm);
    final header = ByteData.sublistView(wav);
    expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
    expect(ascii.decode(wav.sublist(8, 12)), 'WAVE');
    expect(header.getUint32(4, Endian.little), wav.length - 8);
    expect(header.getUint32(24, Endian.little), 16000);
    expect(header.getUint16(22, Endian.little), 1);
    expect(header.getUint16(34, Endian.little), 16);
    expect(header.getUint32(40, Endian.little), pcm.length);
    expect(wav.sublist(44), pcm);
  });

  test('les quatre envois utilisent le bon RPC et un chemin privé', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient('https://example.invalid', 'test-key',
        httpClient: MockClient((request) async {
      requests.add(request);
      return http.Response('{"success":true}', 200,
          headers: {'content-type': 'application/json'}, request: request);
    }));
    addTearDown(client.dispose);
    final service = ApplicationMediaService(client: client);
    final file = ApplicationMediaFile.fromBytes(Uint8List(2), 'vocal.wav');
    for (final pair in [
      ('admin', 'student'),
      ('admin', 'university'),
      ('student', 'student'),
      ('university', 'university')
    ]) {
      await service.send(
          applicationId: 'application',
          sender: pair.$1,
          channel: pair.$2,
          file: file,
          path: 'application/${pair.$2}/owner/vocal.wav',
          caption: '  Bonjour  ');
    }
    expect(requests.map((r) => r.url.path.split('/').last), [
      'app_add_application_message_from_admin_to_student',
      'app_add_application_message_from_admin_to_university',
      'app_add_application_message_from_student',
      'app_add_application_message_from_university',
    ]);
    for (final request in requests) {
      final body = jsonDecode(request.body) as Map;
      expect(body['p_content'], 'Bonjour');
      expect(body['p_type'], 'audio');
      expect(body['p_media_mime'], 'audio/wav');
      expect(body['p_media_url'], isNot(contains('https://')));
    }
    expect(() => service.signedUrl('https://public.example/file'),
        throwsFormatException);
    await expectLater(
        service.upload('application', 'student', file), throwsStateError);
  });

  test('une erreur métier ne devient pas un succès d’envoi', () async {
    final client = SupabaseClient('https://example.invalid', 'test-key',
        httpClient: MockClient((request) async => http.Response(
            '{"success":false,"error":"forbidden"}', 200,
            headers: {'content-type': 'application/json'}, request: request)));
    addTearDown(client.dispose);
    await expectLater(
        ApplicationMediaService(client: client).send(
            applicationId: 'a',
            sender: 'student',
            channel: 'student',
            file: ApplicationMediaFile.fromBytes(Uint8List(1), 'image.jpg'),
            path: 'a/student/u/test.jpg',
            caption: ''),
        throwsStateError);
  });

  testWidgets(
      'les accusés distinguent envoyé et lu sans marquer les messages reçus',
      (tester) async {
    Future<void> show(bool outgoing, String? readAt) =>
        tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: ApplicationMessageContent(
                    message: {'content': 'Bonjour', 'read_at': readAt},
                    outgoing: outgoing))));
    await show(true, null);
    expect(find.byIcon(Icons.check), findsOneWidget);
    await show(true, '2026-09-20T12:00:00Z');
    expect(find.byIcon(Icons.done_all), findsOneWidget);
    await show(false, '2026-09-20T12:00:00Z');
    expect(find.byIcon(Icons.done_all), findsNothing);
    expect(find.text('Bonjour'), findsOneWidget);
  });

  testWidgets(
      'annuler une pièce jointe n’envoie rien et conserve le destinataire',
      (tester) async {
    var sends = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ApplicationAttachmentButton(
                applicationId: 'test',
                sender: 'admin',
                channel: 'university',
                onSent: () async {
                  sends++;
                }))));
    if (!applicationMessageMediaEnabled) {
      expect(find.byIcon(Icons.attach_file), findsNothing);
      return;
    }
    await tester.tap(find.byIcon(Icons.attach_file));
    await tester.pumpAndSettle();
    expect(find.text('Pièce jointe → Université'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Envoyer la pièce jointe'))
            .onPressed,
        isNull);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(sends, 0);
    expect(tester.takeException(), isNull);
  });
}
