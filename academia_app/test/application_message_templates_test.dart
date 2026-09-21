import 'dart:async';

import 'package:academia_app/features/admin/admin_application_detail_screen.dart';
import 'package:academia_app/features/admin/application_message_templates.dart';
import 'package:academia_app/providers/admin_application_messages_provider.dart';
import 'package:academia_app/providers/admin_application_payments_provider.dart';
import 'package:academia_app/providers/admin_applications_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const application = <String, dynamic>{
  'id': 'application-test',
  'student_full_name': 'Aminata',
  'program_title': 'Informatique',
  'university_name': 'Université test',
  'requested_degree_level': 'Licence 1',
};

// Doubles sans client Supabase : aucun message réel ne peut être envoyé.
class Messages extends ChangeNotifier
    implements AdminApplicationMessagesProvider {
  final sent = <String>[];
  final pending = Completer<bool>();
  @override
  bool get isLoading => false;
  @override
  String? get error => null;
  @override
  List<Map<String, dynamic>> get messages => [];
  @override
  Future<void> loadMessages(String applicationId) async {}
  @override
  Future<bool> sendToStudent({
    required String applicationId,
    required String content,
  }) {
    sent.add('student:$content');
    return pending.future;
  }

  @override
  Future<bool> sendToUniversity({
    required String applicationId,
    required String content,
  }) {
    sent.add('university:$content');
    return pending.future;
  }
}

class Payments extends ChangeNotifier
    implements AdminApplicationPaymentsProvider {
  @override
  bool get isLoading => false;
  @override
  String? get error => null;
  @override
  List<Map<String, dynamic>> get payments => [];
  @override
  Future<void> loadPaymentsForApplication(String applicationId) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Applications extends ChangeNotifier implements AdminApplicationsProvider {
  @override
  Future<void> loadApplications() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<Messages> openComposer(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final messages = Messages();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<AdminApplicationMessagesProvider>(
        create: (_) => messages,
      ),
      ChangeNotifierProvider<AdminApplicationPaymentsProvider>(
        create: (_) => Payments(),
      ),
      ChangeNotifierProvider<AdminApplicationsProvider>(
        create: (_) => Applications(),
      ),
    ],
    child: const MaterialApp(
      home: AdminApplicationDetailScreen(application: application),
    ),
  ));
  await tester.pumpAndSettle();
  return messages;
}

Future<void> target(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

String draft(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  test('les sept modèles interpolent les données et tolèrent un profil partiel',
      () {
    expect(applicationMessageTemplates, hasLength(7));
    for (final template in applicationMessageTemplates) {
      final text = template.render(application);
      expect(text, contains('Aminata'));
      expect(text, contains('Informatique (Licence 1)'));
      expect(text, contains('Université test'));
      expect(text, isNot(contains(RegExp(r'\{(nom|filiere|universite)\}'))));
      final partial = template.render({'program_title': '  '});
      expect(partial, isNot(contains('null')));
      expect(partial, isNot(contains('()')));
    }
    final literalName = applicationMessageTemplates.first.render({
      ...application,
      'student_full_name': '{universite}',
    });
    expect(literalName, startsWith('Bonjour {universite},'));
  });

  for (final size in [const Size(390, 844), const Size(1200, 900)]) {
    testWidgets('le modèle reste éditable et seul Envoyer envoie ($size)',
        (tester) async {
      final messages = await openComposer(tester, size);
      await tester.tap(find.widgetWithText(ActionChip, 'Candidature reçue'));
      await tester.pumpAndSettle();
      expect(draft(tester), contains('Bonjour Aminata'));
      expect(messages.sent, isEmpty);
      expect(tester.takeException(), isNull);

      await tester.enterText(find.byType(TextField), 'Message personnalisé');
      await tester.tap(find.byTooltip('Envoyer'));
      await tester.pump();
      expect(messages.sent, ['student:Message personnalisé']);
      expect(tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>),
      ).onChanged, isNull);
      messages.pending.complete(true);
      await tester.pumpAndSettle();
      expect(draft(tester), isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('les destinataires conservent des brouillons séparés',
      (tester) async {
    final messages = await openComposer(tester, const Size(390, 844));
    await tester.tap(find.widgetWithText(ActionChip, 'Candidature reçue'));
    await tester.pumpAndSettle();
    final studentDraft = draft(tester);
    await target(tester, '→ Université');
    expect(draft(tester), isEmpty);
    expect(find.widgetWithText(ActionChip, 'Candidature reçue'), findsNothing);
    await tester.tap(find.widgetWithText(ActionChip, 'Transmettre le dossier'));
    await tester.pumpAndSettle();
    final universityDraft = draft(tester);
    await target(tester, '→ Étudiant');
    expect(draft(tester), studentDraft);
    await target(tester, '→ Université');
    expect(draft(tester), universityDraft);
    expect(messages.sent, isEmpty);
    await tester.tap(find.byTooltip('Envoyer'));
    await tester.pump();
    expect(messages.sent, ['university:$universityDraft']);
    messages.pending.complete(true);
    await tester.pumpAndSettle();
    await target(tester, '→ Étudiant');
    expect(draft(tester), studentDraft);
    await target(tester, '→ Université');
    expect(draft(tester), isEmpty);
  });

  testWidgets('un brouillon existant ne disparaît pas sans confirmation',
      (tester) async {
    final messages = await openComposer(tester, const Size(390, 844));
    await tester.enterText(find.byType(TextField), 'À conserver');
    await tester.tap(find.widgetWithText(ActionChip, 'Candidature reçue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conserver le brouillon'));
    await tester.pumpAndSettle();
    expect(draft(tester), 'À conserver');
    await tester.tap(find.widgetWithText(ActionChip, 'Candidature reçue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remplacer'));
    await tester.pumpAndSettle();
    expect(draft(tester), contains('Bonjour Aminata'));
    expect(messages.sent, isEmpty);
  });

  testWidgets('le compositeur reste accessible sur petit écran avec clavier',
      (tester) async {
    await openComposer(tester, const Size(360, 640));
    await tester.tap(find.widgetWithText(ActionChip, 'Candidature reçue'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Envoyer').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Modèles de messages'));
    await tester.pumpAndSettle();
    expect(find.text('Acceptation et paiement'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
