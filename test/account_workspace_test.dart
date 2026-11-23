import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keeptang/main.dart';
import 'package:keeptang/screens/account_screen.dart';
import 'package:keeptang/services/slip_inbox_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('switching to password reset retains the typed email',
      (tester) async {
    final language = languageNotifier.value;
    languageNotifier.value = 'en';
    addTearDown(() => languageNotifier.value = language);
    await tester.pumpWidget(const MaterialApp(home: AccountScreen()));
    await tester.enterText(
        find.byType(TextFormField).first, 'person@example.com');
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('Reset password'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('person@example.com'), findsOneWidget);
    expect(find.text('Send reset link'), findsOneWidget);
  });

  testWidgets('registration rejects passwords that do not match',
      (tester) async {
    final language = languageNotifier.value;
    languageNotifier.value = 'en';
    addTearDown(() => languageNotifier.value = language);
    await tester.pumpWidget(const MaterialApp(home: AccountScreen()));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Create account'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'person@example.com');
    await tester.enterText(fields.at(1), 'sample-password');
    await tester.enterText(fields.at(2), 'different-password');
    final submit = find.widgetWithText(FilledButton, 'Create account');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('The passwords do not match.'), findsOneWidget);
  });

  test('only the saved Guest keeps access to old local slip drafts', () async {
    final draft = SlipInboxDraft(
      id: 'draft-1',
      imagePath: 'slip.jpg',
      title: 'Test slip',
      amount: 10,
      date: DateTime(2026, 11, 23),
      category: 'Other',
      paymentMethod: 'Cash',
      isExpense: true,
      selected: false,
      assetId: 'example-image',
    );
    SharedPreferences.setMockInitialValues({
      'slip_inbox_drafts': jsonEncode([draft.toJson()]),
      'slip_inbox_processed_assets': ['used-image'],
    });

    const guest = SlipInboxService('guest:G-1111');
    const secondGuest = SlipInboxService('guest:G-2222');
    const member = SlipInboxService('member:example-uid');
    await SlipInboxService.migrateLegacy(guest.scope);
    await SlipInboxService.migrateLegacy(secondGuest.scope);

    expect((await guest.loadDrafts()).single.id, draft.id);
    expect(await guest.loadProcessedAssetIds(), {'used-image'});
    expect(await secondGuest.loadDrafts(), isEmpty);
    expect(await member.loadDrafts(), isEmpty);
    expect(await member.loadProcessedAssetIds(), isEmpty);
    await member.saveDrafts([draft.copyWith(title: 'Member draft')]);
    expect((await guest.loadDrafts()).single.title, 'Test slip');
    expect((await member.loadDrafts()).single.title, 'Member draft');
  });
}
