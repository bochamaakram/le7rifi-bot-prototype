import '../mobile/lib/features/voice/voice_state.dart';

void main() {
  final state = const VoiceState().start().stop().preview('Bghit video');
  if (state.phase != VoicePhase.preview || state.transcript != 'Bghit video') {
    throw StateError('Transcription preview broken');
  }
  if (state.reset().transcript != null)
    throw StateError('Cancellation retained text');
  var rejected = false;
  try {
    const VoiceState().stop();
  } on StateError {
    rejected = true;
  }
  if (!rejected) throw StateError('Invalid transition accepted');
  rejected = false;
  try {
    const VoiceState().start().stop().preview(' ');
  } on ArgumentError {
    rejected = true;
  }
  if (!rejected) throw StateError('Silence accepted');
  print('Voice state smoke: 4 checks passed');
}
