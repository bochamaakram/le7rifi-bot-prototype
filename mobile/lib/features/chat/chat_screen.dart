import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/api/api_client.dart';
import '../voice/voice_state.dart';
import 'chat_controller.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final input = TextEditingController();
  final recorder = AudioRecorder();
  final player = AudioPlayer();
  final scroll = ScrollController();
  VoiceState voice = const VoiceState();
  Timer? timer;
  CancelToken? upload;
  String? recordingPath, playbackPath, error, playing;
  bool speech = true;
  bool starting = false;
  int seconds = 0;
  int voiceGeneration = 0;

  @override
  void initState() {
    super.initState();
    loadPreferences();
    player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && mounted) {
        setState(() => playing = null);
      }
    });
  }

  Future<void> loadPreferences() async {
    try {
      final data = await ref.read(apiProvider).get('/memory/preferences');
      if (mounted)
        ref.read(scriptProvider.notifier).select(data['script'] ?? 'arabic');
    } catch (_) {
      /* Chat remains usable if preferences are offline. */
    }
  }

  Future<void> removeFile(String? path) async {
    if (path == null) return;
    final file = File(path);
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      /* Cleanup can race with cancellation. */
    }
  }

  Future<void> microphone() async {
    if (voice.phase == VoicePhase.recording) {
      await stop();
      return;
    }
    if (starting ||
        voice.phase != VoicePhase.idle ||
        ref.read(chatProvider).busy)
      return;
    starting = true;
    final generation = ++voiceGeneration;
    try {
      if (!await recorder.hasPermission()) {
        throw StateError('خاصنا الإذن باش نستعملو الميكروفون');
      }
      await player.stop();
      final directory = await getTemporaryDirectory();
      recordingPath =
          '${directory.path}/voice-${DateTime.now().microsecondsSinceEpoch}.wav';
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: recordingPath!,
      );
      if (!mounted || generation != voiceGeneration) {
        await recorder.cancel();
        return;
      }
      setState(() {
        voice = voice.start();
        seconds = 0;
        error = null;
      });
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => seconds++);
        if (seconds >= 60) {
          timer?.cancel();
          unawaited(stop());
        }
      });
    } catch (e) {
      if (mounted)
        setState(
          () =>
              error = e is StateError ? e.message.toString() : friendlyError(e),
        );
      await removeFile(recordingPath);
    } finally {
      starting = false;
    }
  }

  Future<void> stop() async {
    if (voice.phase != VoicePhase.recording) return;
    timer?.cancel();
    final generation = voiceGeneration;
    final pathToDelete = recordingPath;
    setState(() => voice = voice.stop());
    try {
      final path = await recorder.stop();
      if (path == null) throw StateError('No recording');
      upload = CancelToken();
      final data = await ref
          .read(apiProvider)
          .post(
            '/speech/transcribe',
            FormData.fromMap({
              'file': await MultipartFile.fromFile(
                path,
                filename: 'recording.wav',
                contentType: DioMediaType('audio', 'wav'),
              ),
            }),
            upload,
          );
      if (!mounted || generation != voiceGeneration) return;
      setState(() {
        voice = voice.preview(data['text']);
        input.text = data['text'];
      });
    } catch (e) {
      if (mounted && generation == voiceGeneration) {
        setState(() {
          voice = voice.reset();
          error = friendlyError(e);
        });
      }
    } finally {
      await removeFile(pathToDelete);
    }
  }

  Future<void> cancelVoice() async {
    if (voice.phase == VoicePhase.preview) input.clear();
    voiceGeneration++;
    timer?.cancel();
    upload?.cancel();
    await recorder.cancel();
    await removeFile(recordingPath);
    if (mounted)
      setState(() {
        voice = voice.reset();
        error = null;
      });
  }

  Future<void> send([String? retry]) async {
    final text = retry ?? input.text;
    if (text.trim().isEmpty) return;
    input.clear();
    setState(() {
      voice = voice.reset();
      error = null;
    });
    await ref
        .read(chatProvider.notifier)
        .send(text, speech: speech, script: ref.read(scriptProvider));
    if (mounted && scroll.hasClients) {
      await scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> play(ChatMessage message) async {
    try {
      if (playing == message.text && player.playing) {
        await player.pause();
        setState(() => playing = null);
        return;
      }
      await player.stop();
      await removeFile(playbackPath);
      final directory = await getTemporaryDirectory();
      playbackPath =
          '${directory.path}/answer-${DateTime.now().microsecondsSinceEpoch}.mp3';
      await File(playbackPath!).writeAsBytes(message.audio!);
      await player.setFilePath(playbackPath!);
      if (mounted) setState(() => playing = message.text);
      unawaited(player.play());
    } catch (e) {
      if (mounted) setState(() => error = 'تعذر تشغيل الصوت');
    }
  }

  @override
  void dispose() {
    voiceGeneration++;
    timer?.cancel();
    upload?.cancel();
    unawaited(recorder.dispose());
    unawaited(player.dispose());
    unawaited(removeFile(recordingPath));
    unawaited(removeFile(playbackPath));
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);
    final colors = Theme.of(context).colorScheme;
    final recording = voice.phase == VoicePhase.recording;
    final transcribing = voice.phase == VoicePhase.transcribing;
    ref.listen(chatProvider, (previous, next) {
      if (next.messages.length > (previous?.messages.length ?? 0) &&
          speech &&
          next.messages.last.audio != null)
        unawaited(play(next.messages.last));
    });
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الحريفي AI'),
            Text('المعاون ديالك بالدارجة', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'محادثة جديدة',
            onPressed: state.busy
                ? null
                : () {
                    ref.read(chatProvider.notifier).fresh();
                  },
            icon: const Icon(Icons.add_comment_outlined),
          ),
          IconButton(
            tooltip: 'المحادثات',
            onPressed: state.busy ? null : () => context.push('/history'),
            icon: const Icon(Icons.history),
          ),
          IconButton(
            tooltip: 'الإعدادات',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: colors.secondaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Text(
                'نسخة تجريبية • معلومات الحرفة أمثلة فقط',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ),
            Expanded(
              child: state.messages.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.waving_hand_outlined,
                              size: 54,
                              color: colors.primary,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'السلام! كيفاش نعاونك؟',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'هضر معايا على خدمتك، ونوجدو أفكار مع بعضياتنا.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            for (final suggestion in [
                              'عاونّي نوجد فيديو على خدمتي',
                              'بغيت نكتب منشور للفيسبوك',
                              'كيفاش نحسن الموقع ديالي؟',
                            ])
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: OutlinedButton(
                                  onPressed:
                                      state.busy || recording || transcribing
                                      ? null
                                      : () => setState(
                                          () => input.text = suggestion,
                                        ),
                                  child: Text(suggestion),
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: state.messages.length,
                      itemBuilder: (context, index) {
                        final message = state.messages[index];
                        return Align(
                          alignment: message.role == 'user'
                              ? AlignmentDirectional.centerEnd
                              : AlignmentDirectional.centerStart,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 500),
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: message.role == 'user'
                                  ? colors.primaryContainer
                                  : colors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SelectableText(message.text),
                                if (message.audio != null)
                                  IconButton(
                                    tooltip: playing == message.text
                                        ? 'وقف الصوت'
                                        : 'سمع الجواب',
                                    onPressed: () => play(message),
                                    icon: Icon(
                                      playing == message.text
                                          ? Icons.pause
                                          : Icons.volume_up_outlined,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (state.busy || transcribing) const LinearProgressIndicator(),
            if (state.busy || transcribing)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  transcribing ? 'كنحولو الصوت للنص…' : 'كنوجدو الجواب…',
                ),
              ),
            if ((error ?? state.error) != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        error ?? state.error!,
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                    if (state.retryText != null)
                      TextButton(
                        onPressed: state.busy
                            ? null
                            : () => send(state.retryText),
                        child: const Text('عاود'),
                      ),
                  ],
                ),
              ),
            if (voice.phase == VoicePhase.preview)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('راجع النص وصححو قبل ما تصيفطو'),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: input,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 4000,
                          enabled: !state.busy && !recording && !transcribing,
                          decoration: const InputDecoration(
                            hintText: 'كتب الرسالة ديالك…',
                            counterText: '',
                          ),
                          onSubmitted: (_) => send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'صيفط',
                        onPressed: state.busy || recording || transcribing
                            ? null
                            : () => send(),
                        icon: const Icon(Icons.arrow_upward),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: speech ? 'حيد الصوت' : 'شعل الصوت',
                        onPressed: () => setState(() => speech = !speech),
                        icon: Icon(
                          speech
                              ? Icons.volume_up_outlined
                              : Icons.volume_off_outlined,
                        ),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(180, 60),
                          backgroundColor: recording ? colors.error : null,
                        ),
                        onPressed:
                            state.busy ||
                                transcribing ||
                                voice.phase == VoicePhase.preview
                            ? null
                            : microphone,
                        icon: Icon(
                          recording ? Icons.stop_rounded : Icons.mic_rounded,
                          size: 28,
                        ),
                        label: Text(
                          recording ? 'وقف • $seconds ثانية' : 'ضغط وهضر',
                        ),
                      ),
                      voice.phase != VoicePhase.idle
                          ? IconButton(
                              tooltip: 'إلغاء التسجيل',
                              onPressed: cancelVoice,
                              icon: const Icon(Icons.close),
                            )
                          : const SizedBox(width: 48),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
