enum VoicePhase { idle, recording, transcribing, preview }

class VoiceState {
  final VoicePhase phase;
  final String? transcript;
  const VoiceState([this.phase = VoicePhase.idle, this.transcript]);

  VoiceState start() {
    if (phase != VoicePhase.idle) {
      throw StateError('Voice operation already active');
    }
    return const VoiceState(VoicePhase.recording);
  }

  VoiceState stop() {
    if (phase != VoicePhase.recording) {
      throw StateError('No active recording');
    }
    return const VoiceState(VoicePhase.transcribing);
  }

  VoiceState preview(String text) {
    if (phase != VoicePhase.transcribing) {
      throw StateError('Not transcribing');
    }
    if (text.trim().isEmpty) {
      throw ArgumentError('Empty transcription');
    }
    return VoiceState(VoicePhase.preview, text);
  }

  VoiceState reset() => const VoiceState();
}
