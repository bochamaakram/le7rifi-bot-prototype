import 'package:flutter_test/flutter_test.dart';
import 'package:le7rayfi_ai/features/voice/voice_state.dart';

void main() {
  test('transcription must be previewed before submission', () {
    final state = const VoiceState().start().stop().preview('Bghit ndir video');
    expect(state.phase, VoicePhase.preview);
    expect(state.transcript, 'Bghit ndir video');
    expect(state.reset().transcript, isNull);
  });
  test('invalid recording transitions and silence are rejected', () {
    expect(() => const VoiceState().stop(), throwsStateError);
    expect(() => const VoiceState().start().start(), throwsStateError);
    expect(
      () => const VoiceState().start().stop().preview(' '),
      throwsArgumentError,
    );
  });
}
