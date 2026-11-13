import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le7rayfi_ai/core/api/api_client.dart';
import 'package:le7rayfi_ai/core/auth/session.dart';
import 'package:le7rayfi_ai/features/chat/chat_controller.dart';

class FakeApi extends ApiClient {
  bool fail = false;
  FakeApi() : super(const SessionStore());
  @override
  Future<dynamic> post(String path, [dynamic data, dynamic cancel]) async {
    if (fail) throw StateError('offline');
    if (path == '/conversations') return {'id': 'conversation-1'};
    return {
      'answer': {'text': 'نقدرو نوجدو فيديو'},
      'audio_base64': null,
      'speech_error': 'unavailable',
    };
  }
}

void main() {
  test('TTS failure preserves answer and failed text can be retried', () async {
    final api = FakeApi();
    final container = ProviderContainer(
      overrides: [apiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    final controller = container.read(chatProvider.notifier);
    await controller.send('بغيت فيديو');
    expect(container.read(chatProvider).messages.length, 2);
    expect(container.read(chatProvider).error, isNotNull);
    api.fail = true;
    await controller.send('رسالة ثانية');
    expect(container.read(chatProvider).messages.length, 2);
    expect(container.read(chatProvider).retryText, 'رسالة ثانية');
    controller.fresh();
    expect(container.read(chatProvider).messages, isEmpty);
  });
}
