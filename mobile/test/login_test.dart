import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le7rayfi_ai/core/auth/session.dart';
import 'package:le7rayfi_ai/features/chat/chat_controller.dart';
import 'package:le7rayfi_ai/features/onboarding/login_screen.dart';

class EmptySession extends SessionStore {
  @override
  Future<String?> read() async => null;
}

void main() {
  testWidgets('onboarding labels development data and masks the access token', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWithValue(EmptySession())],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('الحريفي AI'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isTrue,
    );
    expect(find.textContaining('بيانات الحرفة تجريبية'), findsOneWidget);
  });
}
