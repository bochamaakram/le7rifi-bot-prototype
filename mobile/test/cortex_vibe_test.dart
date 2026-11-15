import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le7rayfi_ai/core/api/api_client.dart';
import 'package:le7rayfi_ai/core/auth/session.dart';
import 'package:le7rayfi_ai/features/chat/chat_controller.dart';
import 'package:le7rayfi_ai/features/chat/chat_screen.dart';
import 'package:le7rayfi_ai/features/chat/widgets/app_sidebar.dart';
import 'package:le7rayfi_ai/features/chat/widgets/atmospheric_background.dart';
import 'package:le7rayfi_ai/features/chat/widgets/luminous_orb.dart';

class MockApi extends ApiClient {
  MockApi() : super(const SessionStore());

  @override
  Future<dynamic> get(String path) async {
    if (path == '/memory/preferences') {
      return {'script': 'arabic', 'enabled': true};
    }
    if (path == '/conversations') {
      return [
        {'id': 'conv-1', 'title': 'خطة تسويق لخدمة النجارة', 'created_at': '2026-11-15T12:00:00'},
        {'id': 'conv-2', 'title': 'دوفي إصلاح السباكة', 'created_at': '2026-11-14T10:00:00'},
      ];
    }
    return {};
  }
}

void main() {
  testWidgets('AtmosphericBackground renders child and gradients', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AtmosphericBackground(
          child: Text('Ambient vibe test'),
        ),
      ),
    );
    expect(find.text('Ambient vibe test'), findsOneWidget);
  });

  testWidgets('LuminousOrb renders without throwing and matches visual structure', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LuminousOrb(size: 110),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(LuminousOrb), findsOneWidget);
  });

  testWidgets('ChatScreen displays Cortex-inspired header, orb, prompt card, and action cards', (tester) async {
    final mockApi = MockApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(mockApi),
        ],
        child: const MaterialApp(
          home: ChatScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Top header elements
    expect(find.text('الحريفي AI'), findsAtLeastNWidgets(1));
    expect(find.text('تصدير المحادثة'), findsOneWidget);
    expect(find.text('النسخة الكاملة'), findsOneWidget);

    // Hero welcoming area
    expect(find.byType(LuminousOrb), findsOneWidget);
    expect(find.text('السلام عليكم، الحريفي'), findsOneWidget);
    expect(find.text('كيفاش نقدر نعاونك اليوم؟'), findsOneWidget);

    // Prompt Card tools
    expect(find.text('بحث متقدم'), findsOneWidget);
    expect(find.text('+ أفكار مسجلة'), findsOneWidget);
    expect(find.text('إرفاق ملف'), findsOneWidget);

    // 3 Quick Action Cards
    expect(find.text('تلخيص ومعلومات'), findsOneWidget);
    expect(find.text('عصف ذهني إبداعي'), findsOneWidget);
    expect(find.text('استشارة وحساب الثمن'), findsOneWidget);

    // Tapping suggestion card populates text
    await tester.ensureVisible(find.text('عصف ذهني إبداعي'));
    await tester.tap(find.text('عصف ذهني إبداعي'));
    await tester.pumpAndSettle();
    expect(find.textContaining('اقترح عليا 3 أفكار مبتكرة'), findsOneWidget);
  });

  testWidgets('Desktop view renders AppSidebar with new chat button and past conversations', (tester) async {
    final mockApi = MockApi();

    // Set large screen size to trigger wide layout (width >= 840)
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(mockApi),
        ],
        child: const MaterialApp(
          home: ChatScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppSidebar), findsOneWidget);
    expect(find.text('محادثة جديدة'), findsOneWidget);
    expect(find.text('استكشاف'), findsOneWidget);
    expect(find.text('المكتبة والتفضيلات'), findsOneWidget);
    expect(find.text('خطة تسويق لخدمة النجارة'), findsOneWidget);
  });
}
